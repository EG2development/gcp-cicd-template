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

1. Select **Use this template** and create your repository in `eg2development`.
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
   Open it, select **Authorize**, and bootstrap carries on.

4. Commit `environments/dev.yaml`, push a branch and open a pull request.
   Cloud Build runs the checks and posts the result on the pull request.
5. Merge. Cloud Build deploys to your project.

The [tutorial](docs/tutorials/create-a-repository.md) walks through the same
steps with the output you should see.

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

- Tutorial: [Create a GCP CI/CD repository in under 15 minutes](docs/tutorials/create-a-repository.md)
- How-to guides: [docs/how-to](docs/how-to/)
- Reference: [docs/reference](docs/reference/)
- Explanation: [docs/explanation](docs/explanation/)
