# Repository structure

Every file and folder in a repository created from the template. "Platform
Engineering reviews" means `.github/CODEOWNERS` assigns the path to
`@EG2development/platform-engineering`; GitHub enforces that review only where
the `main` ruleset applies.

## Your infrastructure

| Path | What it is | Who changes it |
|---|---|---|
| `main.tf` | Your resources. Starts with comments only. | You |
| `variables.tf` | `project_id`, `region` and `environment`, with validation. Cloud Build sets them as `TF_VAR_*`. | You |
| `outputs.tf` | Outputs. Starts with `project_id`. | You |
| `providers.tf` | The `google` provider, with `environment` and `managed-by` default labels. | You |
| `versions.tf` | `required_version`, the `google` provider constraint and an empty `backend "gcs" {}`. | You, through a pull request |
| `.terraform.lock.hcl` | Provider lock file for the root module, four platforms. | You or Dependabot, through a pull request |
| `tests/` | `terraform test` files. `tests/variables.tftest.hcl` is an example with a mock provider. | You |
| `terraform.tfvars.example` | Example variables for local runs. Copy to `terraform.tfvars`, which git ignores. | You |

## CI/CD configuration

| Path | What it is | Who changes it |
|---|---|---|
| `environments/<env>.yaml` | One file per environment: project, region, name and optional settings. See [Configuration](configuration.md). | You |
| `.terraform-version` | The exact Terraform version, read by tfenv and by pre-flight. | You; see [Update Terraform](../how-to/update-terraform.md) |
| `.tflint.hcl` | TFLint plugins: `terraform` (recommended preset) and `google` 0.40.0, matching the approved image. | You, only to match a new image. Not in CODEOWNERS. |
| `.gitignore` | Ignores Terraform working files, plans, `*.tfvars` (except the example), keys and editor files. | You |

## Pipelines

| Path | What it is | Who changes it |
|---|---|---|
| `cloudbuild/ci.yaml` | Pull-request build. See [Build stages](build-stages.md). | Platform Engineering reviews |
| `cloudbuild/deploy.yaml` | Deployment build for `main`. | Platform Engineering reviews |

## CI/CD infrastructure (`cicd/`)

A separate Terraform root, applied only by `scripts/bootstrap.sh`. Its state is
at `gs://PROJECT_ID-tfstate/cicd/ENV`.

| Path | What it is | Who changes it |
|---|---|---|
| `cicd/main.tf` | APIs, state bucket, the two build identities and their IAM, approvers. | Platform Engineering reviews |
| `cicd/github.tf` | Developer Connect service agent, connection, repository link, IAM wait, both triggers. | Platform Engineering reviews |
| `cicd/monitoring.tf` | Log bucket and sink for build logs, email channel, deployment-failure alert. | Platform Engineering reviews |
| `cicd/outputs.tf` | Identity emails, check name, state bucket and the summary bootstrap prints. | Platform Engineering reviews |
| `cicd/variables.tf` | `environment`, `github_repository`, `github_app_installation_id`, `connect_only`, `iam_propagation_seconds`. | Platform Engineering reviews |
| `cicd/versions.tf` | `required_version`, `google` and `google-beta` constraints, providers, empty `backend "gcs" {}`. | Platform Engineering reviews |
| `cicd/.terraform.lock.hcl` | Provider lock file for `cicd/`, four platforms, two providers. | Platform Engineering reviews |

## Scripts

| Path | What it is | Who changes it |
|---|---|---|
| `scripts/bootstrap.sh` | Sets up CI/CD for one environment. See [Commands](commands.md). | Platform Engineering reviews |
| `scripts/preflight.sh` | Checks your machine, GCP access and CI/CD; also the first step of every build. | Platform Engineering reviews |

## GitHub settings

| Path | What it is | Who changes it |
|---|---|---|
| `.github/CODEOWNERS` | Code owners. Platform Engineering for `cloudbuild/`, `cicd/`, `scripts/` and `.github/`; a commented `*` line for your team. | You set your team; Platform Engineering reviews |
| `.github/dependabot.yml` | Weekly grouped provider updates for `/` and `/cicd`, majors ignored. | Platform Engineering reviews |
| `.github/pull_request_template.md` | Pull-request checklist. | Platform Engineering reviews |
| `.github/ruleset-main.json` | The `main - protected` ruleset. Bootstrap replaces `"__CHECKS__"` with the required checks. | Platform Engineering reviews |

## Documentation

| Path | What it is |
|---|---|
| `README.md` | Quick start and links to the documentation. |
| `docs/tutorials/` | Learning by doing. |
| `docs/how-to/` | Task guides. |
| `docs/reference/` | Facts to look up, such as this page. |
| `docs/explanation/` | Background and design reasons. |

## Created locally, never committed

| Path | Created by |
|---|---|
| `.terraform/`, `cicd/.terraform/` | `terraform init` |
| `tfplan`, `tfplan.json` | The deploy build's `plan` and `policy` steps, or a local plan |
| `terraform.tfvars` | You, from the example |

## Related

- [About the GitHub template model](../explanation/template-model.md)
- Back to the [documentation index](../../README.md#documentation)
