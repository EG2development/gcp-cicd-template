#!/usr/bin/env bash
# Pre-flight checks for this repository's CI/CD.
#
#   ./scripts/preflight.sh [ENVIRONMENT]   check your machine, GCP access and CI/CD
#   ./scripts/preflight.sh --ci            run inside Cloud Build (first build step)
#
# Every failure says what failed, why, and how to fix it. Exit status is the
# number of failures (0 means ready). scripts/bootstrap.sh sources this file
# for its helper functions. Works with bash 3.2 (macOS) and later.
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FAILURES=0

pass() { printf 'PASS  %-20s %s\n' "$1" "${2:-}"; }
info() { printf 'INFO  %-20s %s\n' "$1" "$2"; }
warn() { printf 'WARN  %-20s %s\n' "$1" "$2"; }
fail() { # NAME WHAT WHY FIX
  FAILURES=$((FAILURES + 1))
  printf 'FAIL  %-20s %s\n      Why: %s\n      Fix: %s\n' "$1" "$2" "$3" "$4"
}

# The single YAML file per environment is the only required configuration.
# Terraform's own YAML parser reads it, so no extra tools are needed.
load_config() { # ENVIRONMENT
  CONFIG_ENV=$1
  CONFIG_FILE="$REPO_ROOT/environments/$CONFIG_ENV.yaml"
  [[ -f $CONFIG_FILE ]] || return 1
  local empty values expression
  expression="can(yamldecode(file(\"$CONFIG_FILE\"))) ? join(\"|\", [for key in [\"project.id\", \"project.region\", \"environment.name\"] : try(tostring(yamldecode(file(\"$CONFIG_FILE\"))[split(\".\", key)[0]][split(\".\", key)[1]]), \"\")]) : \"INVALID\""
  empty=$(mktemp -d)
  values=$(printf '%s\n' "$expression" | terraform -chdir="$empty" console 2>/dev/null) || values=INVALID
  rm -rf "$empty"
  values=${values#\"}
  values=${values%\"}
  [[ $values != INVALID ]] || return 2
  IFS='|' read -r PROJECT_ID REGION ENV_NAME <<EOF
$values
EOF
  REGION=${REGION:-europe-west2}
  export STATE_BUCKET="$PROJECT_ID-tfstate"
}

default_environment() {
  local files
  files=$(ls -1 "$REPO_ROOT"/environments/*.yaml 2>/dev/null || true)
  if [[ $(printf '%s\n' "$files" | grep -c .) == 1 ]]; then
    files=${files##*/}
    printf '%s\n' "${files%.yaml}"
  else
    printf 'dev\n'
  fi
}

# Derived from the git remote, so nobody types the repository name twice.
github_repository() {
  local url
  url=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null) || return 1
  url=${url%.git}
  case $url in
    git@github.com:*) printf '%s\n' "${url#git@github.com:}" ;;
    https://github.com/*) printf '%s\n' "${url#https://github.com/}" ;;
    ssh://git@github.com/*) printf '%s\n' "${url#ssh://git@github.com/}" ;;
    *) return 1 ;;
  esac
}

terraform_image() {
  sed -n 's/^ *_TF_IMAGE: *"\{0,1\}\([^" ]*\)"\{0,1\} *$/\1/p' "$REPO_ROOT/cloudbuild/ci.yaml" | head -1
}

check_terraform() {
  local wanted actual
  wanted=$(tr -d '[:space:]' < "$REPO_ROOT/.terraform-version")
  if ! command -v terraform >/dev/null; then
    fail "Terraform version" "terraform is not installed" \
      "bootstrap and the checks below run Terraform locally" \
      "install Terraform $wanted (brew install tfenv && tfenv install), or use Cloud Shell"
    return
  fi
  actual=$(terraform version -json | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p')
  if [[ $actual == "$wanted" ]]; then
    pass "Terraform version" "$actual"
  elif [[ ${actual%.*} == "${wanted%.*}" ]]; then
    warn "Terraform version" "$actual locally; Cloud Build uses $wanted (same minor version, so this works)"
  else
    fail "Terraform version" "found $actual, this repository uses $wanted" \
      "versions.tf only accepts the $wanted minor line, so init and plan would fail" \
      "run 'tfenv install' in the repository root (reads .terraform-version), or install $wanted"
  fi
}

check_provider_locks() {
  local dir lock version platforms before=$FAILURES
  for dir in . cicd; do
    lock="$REPO_ROOT/$dir/.terraform.lock.hcl"
    if [[ ! -f $lock ]]; then
      fail "Provider lock file" "$dir/.terraform.lock.hcl is missing" \
        "without it Cloud Build would install unreviewed provider builds" \
        "run: terraform -chdir=$dir providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64 -platform=linux_arm64, then commit it"
      continue
    fi
    version=$(awk '/provider "registry.terraform.io\/hashicorp\/google"/ {f=1} f && /version/ {gsub(/[" ]/, "", $3); print $3; exit}' "$lock")
    platforms=$(grep -c '"h1:' "$lock" || true)
    if [[ -z $version ]]; then
      fail "Google provider" "$dir/.terraform.lock.hcl does not lock hashicorp/google" \
        "the provider version would float between runs" \
        "run terraform -chdir=$dir init -upgrade, then refresh the lock (docs/how-to/refresh-the-lock-file.md)"
    elif ((platforms < 4)); then
      warn "Provider lock file" "$dir lock covers only $platforms platform hash(es); see docs/how-to/refresh-the-lock-file.md"
    else
      pass "Google provider" "$version ($dir)"
    fi
  done
  [[ $FAILURES -gt $before ]] || pass "Provider lock file" "root and cicd/ committed"
}

check_config() { # ENVIRONMENT
  local status=0
  load_config "$1" || status=$?
  if [[ $status == 1 ]]; then
    fail "Configuration" "environments/$1.yaml not found" \
      "each environment needs one small YAML file" \
      "copy environments/dev.yaml to environments/$1.yaml and edit project.id"
    return 1
  elif [[ $status != 0 ]]; then
    fail "Configuration" "environments/$1.yaml is not valid YAML" \
      "Terraform could not parse it" \
      "compare it with the example in docs/reference/configuration.md"
    return 1
  fi
  if [[ $PROJECT_ID == my-gcp-project || -z $PROJECT_ID ]]; then
    fail "Configuration" "project.id is still the placeholder" \
      "bootstrap needs the GCP project this environment deploys to" \
      "set project.id in environments/$1.yaml"
  elif ! [[ $PROJECT_ID =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    fail "Configuration" "project.id '$PROJECT_ID' is not a GCP project ID" \
      "project IDs are 6-30 lowercase letters, digits or hyphens" \
      "use the ID, not the display name or number (gcloud projects list)"
  elif ! [[ $REGION =~ ^[a-z]+-[a-z]+[0-9]+$ ]]; then
    fail "Configuration" "project.region '$REGION' is not a region" \
      "Cloud Build, Developer Connect and state need one region" \
      "use a region such as europe-west2"
  elif [[ $ENV_NAME != "$1" ]] || ! [[ $ENV_NAME =~ ^[a-z][a-z0-9]{1,9}$ ]]; then
    fail "Configuration" "environment.name '$ENV_NAME' does not match the file name '$1'" \
      "names derive identities and triggers, so they must agree (2-10 lowercase letters or digits)" \
      "set environment.name: $1 in environments/$1.yaml"
  else
    pass "Configuration" "$PROJECT_ID, $REGION, $ENV_NAME"
  fi
}

check_gcp_auth() {
  local account
  if ! command -v gcloud >/dev/null; then
    fail "GCP authentication" "gcloud is not installed" \
      "bootstrap uses gcloud for the state bucket and checks" \
      "install the Google Cloud CLI, or use Cloud Shell"
    return 1
  fi
  account=$(gcloud config get-value account 2>/dev/null || true)
  if [[ -z $account ]] || ! gcloud auth print-access-token >/dev/null 2>&1; then
    fail "GCP authentication" "gcloud has no active login" \
      "every GCP call needs your identity" "run: gcloud auth login"
    return 1
  fi
  if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    fail "GCP authentication" "no application-default credentials" \
      "Terraform authenticates with application-default credentials, not gcloud's login" \
      "run: gcloud auth application-default login"
    return 1
  fi
  pass "GCP authentication" "$account"
}

check_project() {
  local state
  state=$(gcloud projects describe "$PROJECT_ID" --format='value(lifecycleState)' 2>/dev/null || true)
  if [[ $state == ACTIVE ]]; then
    pass "Target project" "$PROJECT_ID"
  else
    fail "Target project" "cannot read project $PROJECT_ID" \
      "it does not exist, is being deleted, or you have no role on it" \
      "check the ID with 'gcloud projects list'; ask the project owner for access"
    return 1
  fi
}

# Permissions bootstrap needs, with the predefined role that grants each one.
REQUIRED_PERMISSIONS="serviceusage.services.enable:roles/serviceusage.serviceUsageAdmin
iam.serviceAccounts.create:roles/iam.serviceAccountAdmin
iam.serviceAccounts.actAs:roles/iam.serviceAccountUser
resourcemanager.projects.setIamPolicy:roles/resourcemanager.projectIamAdmin
storage.buckets.create:roles/storage.admin
cloudbuild.builds.create:roles/cloudbuild.builds.editor
monitoring.alertPolicies.create:roles/monitoring.editor"

check_iam() {
  local permissions body granted missing="" roles="" line
  permissions=$(printf '%s\n' "$REQUIRED_PERMISSIONS" | cut -d: -f1 | sed 's/.*/"&"/' | paste -sd, -)
  body="{\"permissions\":[$permissions]}"
  granted=$(curl -sS -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H 'Content-Type: application/json' -d "$body" \
    "https://cloudresourcemanager.googleapis.com/v1/projects/$PROJECT_ID:testIamPermissions" 2>/dev/null || true)
  while IFS= read -r line; do
    if [[ $granted != *"\"${line%%:*}\""* ]]; then
      missing="$missing ${line%%:*}"
      roles="$roles ${line#*:}"
    fi
  done <<EOF
$REQUIRED_PERMISSIONS
EOF
  if [[ -z $missing ]]; then
    pass "IAM" "you can create the CI/CD resources in $PROJECT_ID"
  else
    fail "IAM" "missing:$missing" \
      "bootstrap creates service accounts, IAM bindings, triggers and the state bucket as you" \
      "ask a project owner for roles/owner on $PROJECT_ID, or for:$roles"
  fi
  if ! gcloud services list --project "$PROJECT_ID" --enabled --filter='config.name=developerconnect.googleapis.com' --format='value(config.name)' 2>/dev/null | grep -q .; then
    return 0
  fi
  if ! curl -sS -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H 'Content-Type: application/json' \
    -d '{"permissions":["developerconnect.connections.create"]}' \
    "https://cloudresourcemanager.googleapis.com/v1/projects/$PROJECT_ID:testIamPermissions" | grep -q connections.create; then
    fail "IAM" "missing developerconnect.connections.create" \
      "bootstrap connects this project to GitHub through Developer Connect" \
      "ask a project owner for roles/developerconnect.admin on $PROJECT_ID"
  fi
}

check_image() {
  local image
  image=$(terraform_image)
  if [[ -z $image ]]; then
    fail "Terraform image" "cloudbuild/ci.yaml has no _TF_IMAGE substitution" \
      "every build step runs in the approved Terraform image" \
      "restore the substitutions block from the template"
  elif [[ $image != *@sha256:* ]]; then
    fail "Terraform image" "$image is not pinned by digest" \
      "a tag such as latest can change under you" \
      "use the approved image digest from docs/reference/versions.md"
  elif gcloud artifacts docker images describe "$image" --format='value(image_summary.digest)' >/dev/null 2>&1; then
    pass "Terraform image" "${image##*/}"
  else
    fail "Terraform image" "cannot read ${image%%@*}" \
      "the image or your read access to the central registry is missing" \
      "ask Platform Engineering for roles/artifactregistry.reader on the registry (docs/how-to/troubleshoot-iam.md)"
  fi
  if [[ $(sed -n 's/^ *_TF_IMAGE:.*@\(sha256:[0-9a-f]*\).*/\1/p' "$REPO_ROOT/cloudbuild/deploy.yaml" | head -1) != "${image#*@}" ]]; then
    fail "Terraform image" "ci.yaml and deploy.yaml use different images" \
      "pull requests must be checked with the image that deploys" \
      "set the same _TF_IMAGE in both files"
  fi
}

check_cloudbuild() {
  local triggers
  triggers=$(gcloud builds triggers list --project "$PROJECT_ID" --region "$REGION" --format='value(name)' 2>/dev/null || true)
  if printf '%s\n' "$triggers" | grep -qx "$ENV_NAME-ci" && printf '%s\n' "$triggers" | grep -qx "$ENV_NAME-deploy"; then
    pass "Cloud Build" "triggers $ENV_NAME-ci and $ENV_NAME-deploy in $REGION"
  else
    info "Cloud Build" "triggers not created yet; ./scripts/bootstrap.sh $ENV_NAME creates them"
  fi
}

check_validate() {
  local dir out
  for dir in . cicd; do
    if out=$(terraform -chdir="$REPO_ROOT/$dir" init -backend=false -input=false -lockfile=readonly 2>&1 &&
      terraform -chdir="$REPO_ROOT/$dir" validate -no-color 2>&1); then
      pass "terraform validate" "$dir"
    else
      fail "terraform validate" "$dir does not validate" \
        "$(printf '%s\n' "$out" | grep -m1 -E 'Error|error' || printf 'see terraform output')" \
        "run: terraform -chdir=$dir init -backend=false && terraform -chdir=$dir validate"
    fi
  done
}

check_ci() {
  local tool wanted actual
  for tool in terraform tflint trivy; do
    command -v "$tool" >/dev/null || fail "Terraform image" "$tool is missing from the image" \
      "every CI stage needs it" "ask Platform Engineering to check the approved image"
  done
  wanted=$(tr -d '[:space:]' < "$REPO_ROOT/.terraform-version")
  actual=$(terraform version -json | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p')
  if [[ $actual == "$wanted" ]]; then
    pass "Terraform version" "$actual"
  else
    fail "Terraform version" "image has $actual, .terraform-version says $wanted" \
      "the repository and the approved image disagree" \
      "update _TF_IMAGE in cloudbuild/*.yaml or .terraform-version (docs/how-to/update-terraform.md)"
  fi
  check_provider_locks
  check_config "${TF_VAR_environment:-}" || return 0
  if [[ $PROJECT_ID != "${TF_VAR_project_id:-}" || $REGION != "${TF_VAR_region:-}" ]]; then
    fail "Configuration" "environments/$ENV_NAME.yaml says $PROJECT_ID/$REGION, the trigger says ${TF_VAR_project_id:-?}/${TF_VAR_region:-?}" \
      "the file changed after bootstrap, so the triggers and identities are out of date" \
      "run ./scripts/bootstrap.sh $ENV_NAME, then re-run this build"
  fi
}

main() {
  local env
  if [[ ${1:-} == --ci ]]; then
    check_ci
  else
    env=${1:-$(default_environment)}
    check_terraform
    check_provider_locks
    if check_config "$env" && check_gcp_auth && check_project; then
      check_iam
      check_image
      check_cloudbuild
    fi
    command -v terraform >/dev/null && check_validate
    if repo=$(github_repository); then
      pass "GitHub repository" "$repo"
    else
      fail "GitHub repository" "origin is not a github.com remote" \
        "triggers are created for the repository behind origin" \
        "clone the repository you created from the template, then run this again"
    fi
  fi
  if [[ $FAILURES == 0 ]]; then
    printf '\nAll checks passed.\n'
  else
    printf '\n%s check(s) failed. Fix them in order, then run this again.\n' "$FAILURES"
  fi
  return "$FAILURES"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
