# GCP CI/CD template

Start a Terraform repository for a GCP project with Cloud Build CI/CD already
wired up. Pull requests run checks and a read-only plan. Merges to `main`
plan, check and apply. Setup takes one config file and one command.

```text
Use this template → set project.id → ./scripts/bootstrap.sh → pull request → merge → deployed
```

## Quick start

You need: Owner on the target GCP project (or the roles in
[IAM](docs/reference/iam.md)), Terraform 1.16.6 or a later 1.16 release, the
gcloud CLI and the GitHub CLI.

1. Select **Use this template** and create a **Public** repository in
   `EG2development`. On GitHub Free, only public repositories get the `main`
   protection and secret scanning that bootstrap sets up.
2. Clone it and set your project in `environments/dev.yaml`:

   ```yaml
   project:
     id: my-gcp-project
     region: europe-west2
   environment:
     name: dev
   ```

3. Log in and bootstrap:

   ```bash
   gcloud auth login && gcloud auth application-default login
   ./scripts/bootstrap.sh
   ```

   The first time a project connects to GitHub, bootstrap prints a link.
   Open it, select **Authorize** (choose `EG2development` if GitHub asks
   where), and bootstrap carries on.

4. Commit `environments/dev.yaml`, push a branch and open a pull request.
   Cloud Build runs the checks and posts the result on the pull request.
5. A teammate approves. Merge. Cloud Build deploys to your project.

The [tutorial](docs/tutorials/create-a-repository.md) walks through the same
steps with the output you should see. In the pilot, it took about 8 minutes
from creating the repository to the first deployment.

## What is in the repository

| Path | What it is | Who changes it |
|---|---|---|
| `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `versions.tf` | Your infrastructure (starts empty) | You |
| `environments/<env>.yaml` | The only CI/CD configuration: project, region, environment | You |
| `tests/` | `terraform test` files, run on every pull request | You |
| `cloudbuild/ci.yaml`, `cloudbuild/deploy.yaml` | Pull-request and deployment pipelines | Platform Engineering reviews |
| `cicd/` | Terraform for the CI/CD itself: identities, IAM, triggers, alerts | Platform Engineering reviews |
| `scripts/bootstrap.sh`, `scripts/preflight.sh` | Set up and check CI/CD | Platform Engineering reviews |
| `.terraform.lock.hcl`, `cicd/.terraform.lock.hcl` | Provider lock files, committed | You, through a pull request |

## Documentation

**Tutorial:** [Create a GCP CI/CD repository in under 15 minutes](docs/tutorials/create-a-repository.md)

**How-to guides:**
[onboard a repository](docs/how-to/onboard-a-repository.md) ·
[add an environment](docs/how-to/add-an-environment.md) ·
[update Terraform](docs/how-to/update-terraform.md) ·
[update the Google provider](docs/how-to/update-the-google-provider.md) ·
[refresh the lock file](docs/how-to/refresh-the-lock-file.md) ·
[troubleshoot Cloud Build](docs/how-to/troubleshoot-cloud-build.md) ·
[troubleshoot IAM](docs/how-to/troubleshoot-iam.md) ·
[recover a failed deployment](docs/how-to/recover-a-failed-deployment.md) ·
[run Terraform locally](docs/how-to/run-terraform-locally.md) ·
[set up the organisation](docs/how-to/set-up-the-organisation.md) (Platform Engineering, once)

**Reference:**
[repository structure](docs/reference/repository-structure.md) ·
[versions](docs/reference/versions.md) ·
[configuration](docs/reference/configuration.md) ·
[build stages](docs/reference/build-stages.md) ·
[service accounts](docs/reference/service-accounts.md) ·
[IAM](docs/reference/iam.md) ·
[triggers](docs/reference/triggers.md) ·
[commands](docs/reference/commands.md)

**Explanation:**
[architecture](docs/explanation/architecture.md) ·
[security model](docs/explanation/security-model.md) ·
[central Terraform image](docs/explanation/terraform-image.md) ·
[template model](docs/explanation/template-model.md) ·
[why Cloud Build](docs/explanation/why-cloud-build.md) ·
[why configuration is minimal](docs/explanation/minimal-configuration.md) ·
[design decisions](docs/explanation/design-decisions.md)
