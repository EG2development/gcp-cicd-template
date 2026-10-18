#!/usr/bin/env bash
# Set up CI/CD for one environment of this repository.
#
#   ./scripts/bootstrap.sh [ENVIRONMENT]     (default: the only file in environments/)
#
# Runs pre-flight, creates the Terraform state bucket, applies cicd/ (APIs,
# identities, IAM, GitHub connection, triggers, alerting), proves the CI identity
# can pull the approved image, protects main on GitHub and re-runs pre-flight.
# Safe to re-run: every step is idempotent. No prompts; the only manual action
# is a one-time GitHub authorisation link the first time a project connects.
set -Eeuo pipefail
# shellcheck source=scripts/preflight.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/preflight.sh"

DEVELOPER_CONNECT_APP_ID=865529 # GitHub App id of "Google Cloud Developer Connect"
CONNECTION_ID=github

started=$SECONDS
step_started=$SECONDS
step() {
  printf '\n==> %s\n' "$1"
  step_started=$SECONDS
}
step_done() { printf '    done in %ss\n' $((SECONDS - step_started)); }
stop() { # WHAT FIX
  printf '\nFAIL  %s\n      Fix: %s\n' "$1" "$2" >&2
  printf 'Bootstrap stopped after %ss. Re-run ./scripts/bootstrap.sh %s once fixed.\n' $((SECONDS - started)) "$ENVIRONMENT" >&2
  exit 1
}
tf() { terraform -chdir="$REPO_ROOT/cicd" "$@"; }

ENVIRONMENT=${1:-$(default_environment)}

step "Pre-flight ($ENVIRONMENT)"
main "$ENVIRONMENT" || stop "pre-flight found problems" "fix each FAIL above in order"
REPOSITORY=$(github_repository)
export TF_VAR_environment=$ENVIRONMENT TF_VAR_github_repository=$REPOSITORY TF_IN_AUTOMATION=1
step_done

step "Terraform state bucket gs://$STATE_BUCKET"
if gcloud storage buckets describe "gs://$STATE_BUCKET" --format='value(name)' >/dev/null 2>&1; then
  printf '    already exists\n'
else
  # Created here because Terraform needs the bucket before it can store state.
  # cicd/ then adopts it with an import block and manages its settings.
  gcloud storage buckets create "gs://$STATE_BUCKET" --project "$PROJECT_ID" --location "$REGION" \
    --uniform-bucket-level-access --public-access-prevention --quiet >/dev/null ||
    stop "could not create gs://$STATE_BUCKET" \
      "check storage.buckets.create on $PROJECT_ID; if the name is taken, see docs/how-to/troubleshoot-iam.md"
  gcloud storage buckets update "gs://$STATE_BUCKET" --versioning --quiet >/dev/null
fi
step_done

step "Terraform init (cicd/)"
tf init -input=false -reconfigure -lockfile=readonly \
  -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=cicd/$ENVIRONMENT" >/dev/null ||
  stop "terraform init failed for cicd/" "run the same command without >/dev/null to see the error: terraform -chdir=cicd init -backend-config=bucket=$STATE_BUCKET -backend-config=prefix=cicd/$ENVIRONMENT"
step_done

step "Connect $PROJECT_ID to GitHub"
tf apply -input=false -auto-approve -compact-warnings -target=google_developer_connect_connection.github ||
  stop "could not create the Developer Connect connection" "see docs/how-to/troubleshoot-cloud-build.md#connection"
connection_stage() {
  gcloud developer-connect connections describe "$CONNECTION_ID" --project "$PROJECT_ID" --location "$REGION" \
    --format="value(installationState.stage)" 2>/dev/null || true
}
stage=$(connection_stage)
if [[ $stage != COMPLETE ]]; then
  link=$(gcloud developer-connect connections describe "$CONNECTION_ID" --project "$PROJECT_ID" --location "$REGION" \
    --format="value(installationState.actionUri)")
  printf '\n    One-time step for this project: authorise Developer Connect on GitHub.\n'
  printf '    Open this link while signed in to GitHub, then return here:\n\n    %s\n\n' "$link"
  if command -v open >/dev/null; then open "$link" 2>/dev/null || true; fi
  for _ in $(seq 1 180); do
    sleep 5
    stage=$(connection_stage)
    [[ $stage == COMPLETE ]] && break
  done
  [[ $stage == COMPLETE ]] || stop "the GitHub connection is still $stage after 15 minutes" \
    "open the link above; if GitHub says the app is not installed, ask Platform Engineering (docs/how-to/set-up-the-organisation.md)"
fi
printf '    connection %s is ready\n' "$CONNECTION_ID"
step_done

step "Apply cicd/ (identities, IAM, repository link, triggers, alerting)"
tf apply -input=false -auto-approve -compact-warnings ||
  stop "terraform apply failed for cicd/" "read the error above; docs/how-to/troubleshoot-iam.md lists the common causes"
ci_account=$(tf output -raw ci_service_account)
ci_check=$(tf output -raw ci_check_name)
step_done

step "Initialise workload state gs://$STATE_BUCKET/env/$ENVIRONMENT"
# Terraform writes an empty state the first time it opens a workspace. Do it
# now, as you, so the read-only CI identity never needs to write state.
if ! terraform -chdir="$REPO_ROOT" init -input=false -reconfigure -lockfile=readonly \
  -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=env/$ENVIRONMENT" >/dev/null ||
  ! terraform -chdir="$REPO_ROOT" state list >/dev/null; then
  stop "could not initialise the workload state" "run: terraform init -backend-config=bucket=$STATE_BUCKET -backend-config=prefix=env/$ENVIRONMENT"
fi
step_done

step "Smoke build: the CI identity pulls the approved Terraform image"
smoke=$(mktemp)
cat > "$smoke" <<EOF
steps:
  - name: $(terraform_image)
    entrypoint: terraform
    args: [version]
options:
  logging: CLOUD_LOGGING_ONLY
timeout: 600s
EOF
if ! gcloud builds submit --no-source --config "$smoke" --project "$PROJECT_ID" --region "$REGION" \
  --service-account "projects/$PROJECT_ID/serviceAccounts/$ci_account" >/dev/null 2>&1; then
  rm -f "$smoke"
  project_number=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
  image=$(terraform_image)
  stop "the CI identity could not run a build with the approved Terraform image" \
    "usually the central registry has not granted this project read access. Ask Platform Engineering to run:
      gcloud artifacts repositories add-iam-policy-binding $(printf '%s' "$image" | cut -d/ -f3) \\
        --project $(printf '%s' "$image" | cut -d/ -f2) --location $(printf '%s' "$image" | cut -d- -f1-2) \\
        --role roles/artifactregistry.reader \\
        --member principalSet://cloudresourcemanager.googleapis.com/projects/$project_number/type/ServiceAccount
      Then re-run bootstrap. Build logs: gcloud builds list --project $PROJECT_ID --region $REGION --limit 1"
fi
rm -f "$smoke"
step_done

step "Protect main on GitHub"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  # Repository ruleset: pull requests, one approval, code owners, and this
  # environment's Cloud Build check. Organisation rulesets cannot name it
  # because the check name includes the project ID.
  existing=$(gh api "repos/$REPOSITORY/rulesets" --jq '.[] | select(.name == "main - protected") | .id' 2>/dev/null || true)
  checks=""
  if [[ -n $existing ]]; then
    checks=$(gh api "repos/$REPOSITORY/rulesets/$existing" \
      --jq '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' 2>/dev/null || true)
  fi
  checks=$(printf '%s\n%s\n' "$checks" "$ci_check" | grep . | sort -u)
  contexts=$(printf '%s\n' "$checks" | sed "s/.*/{\"context\":\"&\",\"integration_id\":$DEVELOPER_CONNECT_APP_ID}/" | paste -sd, -)
  ruleset=$(sed "s/\"__CHECKS__\"/[$contexts]/" "$REPO_ROOT/.github/ruleset-main.json")
  if [[ -n $existing ]]; then
    method=(-X PUT "repos/$REPOSITORY/rulesets/$existing")
  else
    method=(-X POST "repos/$REPOSITORY/rulesets")
  fi
  if printf '%s' "$ruleset" | gh api "${method[@]}" --input - >/dev/null 2>&1; then
    printf '    ruleset "main - protected" requires: %s\n' "$(printf '%s' "$checks" | paste -sd, -)"
  else
    warn "GitHub protection" "could not write the ruleset (needs repository admin; GitHub Free enforces rulesets on public repositories only)"
  fi
  org=${REPOSITORY%%/*}
  gh api -X PUT "orgs/$org/teams/platform-engineering/repos/$REPOSITORY" -f permission=push >/dev/null 2>&1 ||
    warn "GitHub protection" "could not give @$org/platform-engineering write access; CODEOWNERS needs it"
else
  warn "GitHub protection" "gh is not installed or not logged in; run 'gh auth login' and re-run bootstrap to protect main"
fi
step_done

step "Post-bootstrap pre-flight"
FAILURES=0
main "$ENVIRONMENT" || stop "post-bootstrap checks failed" "fix each FAIL above, then re-run bootstrap"

printf '\nBootstrap of %s finished in %ss.\n' "$ENVIRONMENT" $((SECONDS - started))
tf output -raw summary
printf '\nNext: create a branch, change something, push it and open a pull request.\n'
