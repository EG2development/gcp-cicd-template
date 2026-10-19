# Commands

The two scripts in `scripts/`. Both run with bash 3.2 (macOS) or later.

## bootstrap.sh

```text
./scripts/bootstrap.sh [ENVIRONMENT]
```

| Item | Value |
|---|---|
| `ENVIRONMENT` | Name of a file in `environments/`, without `.yaml`. Default: the only file there; `dev` if there are several. |
| Prompts | None. The first run for a project prints one GitHub authorisation link. |
| Re-runs | Safe. Each step skips or updates what exists. |
| Exit status | `0` on success, `1` when a step stops |
| Sets | `TF_VAR_environment`, `TF_VAR_github_repository` (from the `origin` remote), `TF_IN_AUTOMATION=1` |
| Reads if set | `TF_VAR_github_app_installation_id`, `TF_VAR_iam_propagation_seconds` |
| Passes | `-var=connect_only=true` to the first, targeted apply only |

### Steps

Each step prints `==> <heading>` and, when it finishes, `    done in <n>s`.

| Heading | What it does | Stops with |
|---|---|---|
| `Pre-flight (<env>)` | Runs every check in [preflight.sh](#preflightsh). | `pre-flight found problems` |
| `Terraform state bucket gs://<bucket>` | Creates the bucket with uniform access, public access prevention and versioning, in `project.region`. Prints `already exists` if it does. | `could not create gs://<bucket>` |
| `Terraform init (cicd/)` | `terraform init` in `cicd/` with `-lockfile=readonly`, state prefix `cicd/<env>`. | `terraform init failed for cicd/` |
| `Connect <project> to GitHub` | Applies the Developer Connect connection only, with `-var=connect_only=true`, so the connection has no installation yet. If it is not `COMPLETE`, prints the authorisation link with the Google account and GitHub organisation to sign in with, opens it with `open` where available, and checks every 5 seconds for up to 15 minutes. Prints `connection github is ready`. | `could not create the Developer Connect connection`; `the GitHub connection is still <stage> after 15 minutes` |
| `Apply cicd/ (identities, IAM, repository link, triggers, alerting)` | `terraform apply -auto-approve` in `cicd/`. This apply also sets the connection's installation to `github_app_installation_id`. | `the Developer Connect GitHub App cannot see <owner>/<repository>`, with the connection's installation address, when the apply reports that the repository is not accessible to the installation; otherwise `terraform apply failed for cicd/` |
| `Initialise workload state gs://<bucket>/env/<env>` | `terraform init` and `terraform state list` in the root, as you, so the CI identity never has to write state. | `could not initialise the workload state` |
| `Smoke build: the CI identity pulls the approved Terraform image` | `gcloud builds submit --no-source` as `tf-ci-<env>`, running `terraform version` in `_TF_IMAGE`. | `the CI identity could not run a build with the approved Terraform image` |
| `Protect main and turn on secret scanning (GitHub)` | Creates or updates the `main - protected` ruleset with this environment's check added to any existing ones, gives `platform-engineering` write access, and turns on secret scanning and push protection. Prints `ruleset "main - protected" requires: <checks>` and `secret scanning and push protection are on`. Skipped, with a WARN, if `gh` is missing or signed out. | Never stops; prints `WARN  GitHub protection` or `WARN  GitHub security` instead |
| `Post-bootstrap pre-flight` | Runs pre-flight again. | `post-bootstrap checks failed` |

When a step stops, bootstrap prints to standard error:

```text
FAIL  <what failed>
      Fix: <what to do>
Bootstrap stopped after <n>s. Re-run ./scripts/bootstrap.sh <env> once fixed.
```

### Output when it finishes

```text
Bootstrap of <env> finished in <n>s.
Repository:       <owner>/<repository>
Environment:      <env> in <project> (<region>)
Pull requests:    trigger <env>-ci, runs cloudbuild/ci.yaml as <CI identity email>
Merges to main:   trigger <env>-deploy, runs cloudbuild/deploy.yaml as <deploy identity email>
Approval needed:  <no | yes, gcloud alpha builds approve BUILD_ID --location <region> --project <project>>
Terraform state:  gs://<bucket>/env/<env>
Build logs:       gcloud builds list --project <project> --region <region>

Next: create a branch, change something, push it and open a pull request.
```


## preflight.sh

```text
./scripts/preflight.sh [ENVIRONMENT]
./scripts/preflight.sh --ci
```

| Item | Value |
|---|---|
| `ENVIRONMENT` | As for bootstrap |
| `--ci` | Cloud Build mode, the first step of both builds. Reads `TF_VAR_environment`, `TF_VAR_project_id` and `TF_VAR_region`. |
| Exit status | The number of `FAIL` results; `0` means ready |
| Last line | `All checks passed.` or `<n> check(s) failed. Fix them in order, then run this again.` |

### Result types

| Result | Meaning | Counts towards exit status |
|---|---|---|
| `PASS` | The check succeeded. | No |
| `FAIL` | The check failed. Followed by `Why:` and `Fix:` lines. | Yes |
| `WARN` | It works, but something should change. | No |
| `INFO` | Information only. | No |

### Checks in local mode

Checks run in this order, with these conditions:

- `GCP authentication` runs only if `Configuration` passes.
- `Target project` runs only if authentication passes.
- `IAM`, `Terraform image` and `Cloud Build` run only if the project is readable.
- `terraform validate` runs whenever Terraform is installed.

| Check | Result | Message |
|---|---|---|
| `Terraform version` | PASS | `<version>` |
| | WARN | `<actual> locally; Cloud Build uses <wanted> (versions.tf accepts both)`, for a later patch of the same minor version |
| | FAIL | `terraform is not installed` |
| | FAIL | `found <actual>, this repository uses <wanted>`, for an earlier patch or another minor version |
| `Google provider` | PASS | `<version> (<dir>)`, once for `.` and once for `cicd` |
| | FAIL | `<dir>/.terraform.lock.hcl does not lock hashicorp/google` |
| `Provider lock file` | PASS | `root and cicd/ committed` |
| | WARN | `<dir> lock covers only <n> platform hash(es); see docs/how-to/refresh-the-lock-file.md` |
| | FAIL | `<dir>/.terraform.lock.hcl is missing` |
| `Configuration` | PASS | `<project>, <region>, <env>` |
| | FAIL | `environments/<env>.yaml not found` |
| | FAIL | `environments/<env>.yaml is not valid YAML` |
| | FAIL | `project.id is still the placeholder` |
| | FAIL | `project.id '<id>' is not a GCP project ID` |
| | FAIL | `project.region '<region>' is not a region` |
| | FAIL | `environment.name '<name>' does not match the file name '<env>'` |
| `GCP authentication` | PASS | `<account>` |
| | FAIL | `gcloud is not installed` |
| | FAIL | `gcloud has no active login` |
| | FAIL | `no application-default credentials` |
| `Target project` | PASS | `<project>` |
| | FAIL | `cannot read project <project>` |
| `IAM` | PASS | `you can create the CI/CD resources in <project>` |
| | FAIL | `missing: <permissions>`; the `Fix:` line names each role once |
| | FAIL | `missing developerconnect.connections.create`, checked only once the Developer Connect API is enabled |
| `Terraform image` | PASS | `<image>@sha256:<digest>`, the last part of the image name |
| | FAIL | `cloudbuild/ci.yaml has no _TF_IMAGE substitution` |
| | FAIL | `<image> is not pinned by digest` |
| | WARN | `you cannot read <image>; bootstrap's smoke build checks the CI identity instead` |
| | FAIL | `ci.yaml and deploy.yaml use different images` |
| `Cloud Build` | PASS | `triggers <env>-ci and <env>-deploy in <region>` |
| | INFO | `triggers not created yet; ./scripts/bootstrap.sh <env> creates them` |
| `terraform validate` | PASS | `<dir>`, once for `.` and once for `cicd` |
| | FAIL | `<dir> does not validate` |
| `GitHub repository` | PASS | `<owner>/<repository>` |
| | FAIL | `origin is not a github.com remote` |

The `Provider lock file` WARN replaces that root's `Google provider` PASS. `<n>`
is the smallest number of `h1:` hashes held by any provider in the file, one
per platform.

### Checks in `--ci` mode

| Check | Result | Message |
|---|---|---|
| `Terraform image` | FAIL | `<tool> is missing from the image`, for `terraform`, `tflint` and `trivy` |
| `Terraform version` | PASS | `<version>` |
| | FAIL | `image has <actual>, .terraform-version says <wanted>` |
| `Google provider`, `Provider lock file` | | As in local mode |
| `Configuration` | | As in local mode, for `TF_VAR_environment` |
| | FAIL | `environments/<env>.yaml says <project>/<region>, the trigger says <project>/<region>` |

## Related

- [Onboard a repository](../how-to/onboard-a-repository.md)
- [Troubleshoot Cloud Build](../how-to/troubleshoot-cloud-build.md)
- [Configuration](configuration.md)
- Back to the [documentation index](../../README.md#documentation)
