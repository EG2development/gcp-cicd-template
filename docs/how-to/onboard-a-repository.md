# How to onboard a repository to Cloud Build CI/CD

Use this guide to give a GCP project a Terraform repository with Cloud Build
CI/CD. It covers a new repository and an existing one. For a guided first run
with the output you should see, follow the
[tutorial](../tutorials/create-a-repository.md) instead.

## Before you start

- Platform Engineering has completed
  [Set up the organisation](set-up-the-organisation.md).
- The target project exists and has billing.
- You have Owner on the target project, or every role in
  [IAM: the person who runs bootstrap](../reference/iam.md#the-person-who-runs-bootstrap).
- If the project is not in a GCP organisation, Platform Engineering has given it
  read access to the central Terraform image. See
  [Set up the organisation](set-up-the-organisation.md#grant-read-access-to-the-central-terraform-image).
- You have Terraform 1.16.6 or a later 1.16 patch, `gcloud`, `gh` and `git`.
  See [Versions](../reference/versions.md).

## Onboard a new repository

1. Create the repository from the template and clone it:

   ```bash
   gh repo create EG2development/my-service --template EG2development/gcp-cicd-template --public --clone
   cd my-service
   ```

   Use `--private` only if the code must not be public. On GitHub Free, a
   private repository gets no ruleset, no required code owner review and no
   secret scanning; those need GitHub Team.

2. In `environments/dev.yaml`, set `project.id`. Set `project.region` if the
   project should not use `europe-west2`. Add optional keys from
   [Configuration](../reference/configuration.md) if you need them.

3. Sign in:

   ```bash
   gcloud auth login
   gcloud auth application-default login
   gh auth status
   ```

4. Run pre-flight and fix each `FAIL` in order:

   ```bash
   ./scripts/preflight.sh
   ```

   [Commands](../reference/commands.md) lists every check.

5. Run bootstrap:

   ```bash
   ./scripts/bootstrap.sh
   ```

   The first time a project connects to GitHub, bootstrap prints a link. Open
   it and sign in to Google as your `gcloud` account; the link opens the
   Developer Connect finish-setup page in the Google Cloud console. Sign in to
   GitHub as a member of `EG2development`, then select **Authorize**. If GitHub
   asks where to install the app, choose `EG2development`, not a personal
   account. Never install or authorise the app from a search result; lookalike
   apps exist.

   In the pilot, bootstrap took 221 seconds, including the authorisation.

6. Commit the environment file on a branch and open a pull request:

   ```bash
   git switch -c configure-dev
   git add environments/dev.yaml
   git commit -m "Configure the dev environment"
   git push -u origin configure-dev
   gh pr create --fill
   ```

7. Ask a teammate to approve the pull request; the ruleset does not let you
   approve your own. Wait for the `dev-ci (PROJECT_ID)` check to pass, then
   merge:

   ```bash
   gh pr checks --watch
   gh pr merge --squash --delete-branch
   ```

8. Set your team as the default code owner. In `.github/CODEOWNERS`, uncomment
   the `*` line and replace `your-team` with your team's slug. The team must be
   visible and have write access to the repository.

## Check that it worked

- `./scripts/preflight.sh` shows
  `PASS  Cloud Build          triggers dev-ci and dev-deploy in REGION`.
- The newest build in
  `gcloud builds list --project PROJECT_ID --region REGION --limit 1` has
  `STATUS` `SUCCESS` after the merge.
- Bootstrap printed `ruleset "main - protected" requires: dev-ci (PROJECT_ID)`
  and `secret scanning and push protection are on`.

## If bootstrap printed a WARN for GitHub

| WARN text | Cause | What to do |
|---|---|---|
| `could not write the ruleset (needs repository admin; ...)` | The repository is private on GitHub Free, or you are not a repository admin. | Accept advisory checks, or make the repository public and re-run bootstrap. |
| `could not turn on secret scanning (on GitHub Free it needs a public repository)` | The repository is private on GitHub Free, or you are not a repository admin. | Accept it, or make the repository public and re-run bootstrap. |
| `could not give @EG2development/platform-engineering write access; ...` | The team does not exist, or you cannot see it. | Ask Platform Engineering. Code owner review cannot work without the team. |
| `gh is not installed or not logged in; ...` | `gh` is missing or signed out. | Run `gh auth login`, then re-run bootstrap. |

## If bootstrap says the GitHub App cannot see the repository

The `Apply cicd/` step stops with
`the Developer Connect GitHub App cannot see EG2development/my-service` and
prints the installation the connection uses. See
[Troubleshoot Cloud Build: the app cannot see the repository](troubleshoot-cloud-build.md#the-app-cannot-see-the-repository).

## Onboard an existing repository

The pipeline runs Terraform in the repository root. Before you copy the
template in, check that your repository can meet these conditions:

- The Terraform root module is the repository root, not a subfolder.
- It declares the variables `project_id`, `region` and `environment`. Cloud
  Build sets them as `TF_VAR_*` from `environments/<env>.yaml`.
- It uses `backend "gcs" {}` with no settings. Cloud Build supplies `bucket` and
  `prefix`.
- `required_version` is `~> 1.16.6` and the Google provider constraint is
  `~> 8.7`.
- It passes `terraform fmt`, `terraform validate`, TFLint with
  [`.tflint.hcl`](../../.tflint.hcl) and Trivy at `HIGH,CRITICAL`.
- No other pipeline applies the same infrastructure.

Then:

1. On a branch, copy these from the template: `cloudbuild/`, `cicd/`,
   `scripts/`, `environments/`, `.github/`, `.terraform-version`, `.tflint.hcl`
   and the `.gitignore` entries. Merge `.github/CODEOWNERS` with yours.
2. Refresh the lock files for four platforms. See
   [Refresh the lock file](refresh-the-lock-file.md).
3. List the roles your Terraform needs in `deploy.roles`. See
   [Configuration](../reference/configuration.md).
4. Run `./scripts/bootstrap.sh` from the branch. Bootstrap creates an empty
   workload state at `gs://PROJECT_ID-tfstate/env/ENV`.
5. Move your existing state into that location before you merge.
   `terraform init -migrate-state` must replace the empty state that bootstrap
   created. This has not been tested.
6. Run a plan locally and confirm it shows no unexpected changes. See
   [Run Terraform locally](run-terraform-locally.md).
7. Open the pull request, check the `plan` step output, then merge.

## Related

- [Add an environment](add-an-environment.md)
- [Troubleshoot Cloud Build](troubleshoot-cloud-build.md)
- [Troubleshoot IAM](troubleshoot-iam.md)
- [About the architecture](../explanation/architecture.md)
- Back to the [documentation index](../../README.md#documentation)
