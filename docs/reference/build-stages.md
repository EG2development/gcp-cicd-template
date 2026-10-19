# Build stages

The steps in `cloudbuild/ci.yaml` and `cloudbuild/deploy.yaml`. Steps run in the
order listed, one at a time. The first failure stops the build.

## Build settings

| Setting | `ci.yaml` | `deploy.yaml` |
|---|---|---|
| Trigger | `<env>-ci`, pull requests to `main` | `<env>-deploy`, pushes to `main` |
| Identity | `tf-ci-<env>` | `tf-deploy-<env>` |
| Build timeout | `1200s` | `3600s` |
| Step timeouts | None set | None set |
| Logging | `CLOUD_LOGGING_ONLY` | `CLOUD_LOGGING_ONLY` |
| Image for every step | `${_TF_IMAGE}` | `${_TF_IMAGE}` |
| Entrypoint for every step | `bash` | `bash` |
| Failure alert | No | Yes |

Both files set these environment variables for every step:

| Variable | Value |
|---|---|
| `TF_IN_AUTOMATION` | `1` |
| `TF_INPUT` | `0` |
| `TF_CLI_ARGS_init`, `TF_CLI_ARGS_validate`, `TF_CLI_ARGS_plan`, `TF_CLI_ARGS_apply`, `TF_CLI_ARGS_test` | `-no-color`, so the Cloud Build log is plain text |
| `TF_VAR_project_id` | `${_PROJECT_ID}` |
| `TF_VAR_region` | `${_REGION}` |
| `TF_VAR_environment` | `${_ENVIRONMENT}` |

Substitutions: `_TF_IMAGE` is set in each YAML file. The trigger supplies
`_ENVIRONMENT`, `_PROJECT_ID`, `_REGION` and `_STATE_BUCKET`. See
[Triggers](triggers.md).

## Pull-request build (`ci.yaml`)

| Step | Runs | On failure prints |
|---|---|---|
| `preflight` | `scripts/preflight.sh --ci` | Pre-flight `FAIL` lines. See [Commands](commands.md#checks-in---ci-mode). |
| `fmt` | `terraform fmt -check -recursive -diff` | `FAIL fmt: run 'terraform fmt -recursive' and push the result.` |
| `init` | `terraform init -lockfile=readonly -backend-config=bucket=${_STATE_BUCKET} -backend-config=prefix=env/${_ENVIRONMENT}` | `FAIL init: check .terraform.lock.hcl matches versions.tf (docs/how-to/refresh-the-lock-file.md).` |
| `validate` | `terraform validate`, then `terraform -chdir=cicd init -backend=false -lockfile=readonly` and `terraform -chdir=cicd validate` | `FAIL validate: fix the errors above; run 'terraform validate' locally.` |
| `tflint` | `tflint --recursive --format compact` | `FAIL tflint: fix the findings above; run 'tflint --init && tflint --recursive' locally.` |
| `security` | `trivy config --quiet --exit-code 1 --severity HIGH,CRITICAL .` | `FAIL security: fix the HIGH or CRITICAL findings above (docs/how-to/troubleshoot-cloud-build.md).` |
| `test` | `terraform test`, if `tests/*.tftest.hcl` exists | `FAIL test: a test in tests/ failed; run 'terraform test' locally.` Prints `SKIP test: no tests/*.tftest.hcl files.` when there are none. |
| `plan` | `terraform plan -lock=false -input=false` | `FAIL plan: read the error above; missing read access is in docs/how-to/troubleshoot-iam.md.` |

The pull-request build changes nothing. Its identity can read the project and
the state but cannot write either. `-lock=false` means it never takes the state
lock.

## Deployment build (`deploy.yaml`)

| Step | Runs | On failure prints |
|---|---|---|
| `preflight` | `scripts/preflight.sh --ci` | Pre-flight `FAIL` lines |
| `fmt` | `terraform fmt -check -recursive` | `FAIL fmt: main is not formatted; run 'terraform fmt -recursive' in a pull request.` |
| `init` | `terraform init -lockfile=readonly -backend-config=bucket=${_STATE_BUCKET} -backend-config=prefix=env/${_ENVIRONMENT}` | `FAIL init: check state bucket access (docs/how-to/troubleshoot-iam.md) and the lock file.` |
| `validate` | `terraform validate` | `FAIL validate: fix the errors above in a pull request.` |
| `tflint` | `tflint --recursive --format compact` | `FAIL tflint: fix the findings above in a pull request.` |
| `security` | `trivy config --quiet --exit-code 1 --severity HIGH,CRITICAL .` | `FAIL security: fix the HIGH or CRITICAL findings above in a pull request.` |
| `test` | `terraform test`, if `tests/*.tftest.hcl` exists | `FAIL test: a test in tests/ failed; fix it in a pull request.` Prints `SKIP test: no tests/*.tftest.hcl files.` when there are none. |
| `plan` | `terraform plan -input=false -lock-timeout=300s -out=tfplan` | `FAIL plan: read the error above; a missing role goes in deploy.roles (docs/how-to/troubleshoot-iam.md).` |
| `policy` | `terraform show -json tfplan > tfplan.json`, then `trivy config --quiet --exit-code 1 --severity HIGH,CRITICAL tfplan.json` | `FAIL policy: the planned change breaks a HIGH or CRITICAL check; nothing was applied.` |
| `apply` | `terraform apply -input=false -lock-timeout=300s tfplan` | `FAIL apply: some or all changes were not applied. An Error 403 means the deploy identity needs a role: add it to deploy.roles in environments/${_ENVIRONMENT}.yaml, run ./scripts/bootstrap.sh ${_ENVIRONMENT}, then re-run this build (docs/how-to/recover-a-failed-deployment.md).` |
| `post` | `terraform plan -input=false -lock-timeout=300s -detailed-exitcode` | `FAIL post: the plan after apply is not empty, so something changed outside Terraform or a resource is not stable.` |

Differences from `ci.yaml`: `fmt` has no `-diff`; `validate` checks the root
module only; `plan` takes the lock and saves the plan; `policy`, `apply` and
`post` run only here.

## Logs

| Item | Value |
|---|---|
| Log name | `projects/PROJECT_ID/logs/cloudbuild` |
| Monitored resource | `build` |
| Default retention | 30 days, in the `_Default` log bucket |
| Long retention | 365 days, in the `cicd-<env>` log bucket, through the `cicd-<env>` sink |
| Read with | `gcloud builds log BUILD_ID --project PROJECT_ID --region REGION` |
| Role to read | `roles/logging.viewer` |

## Deployment-failure alert

| Item | Value |
|---|---|
| Policy | `Deployment failed: <owner>/<repository> (<env>)` |
| Matches | Log lines from the `<env>-deploy` trigger that match `FAIL ` or `ERROR: build step` |
| Notification rate | At most one per 300 seconds |
| Auto-close | 1800 seconds |
| Channel | Email, only when `alerts.email` is set |
| Pull-request builds | Never alert |

Both the step lines (`FAIL <step>:`) and the pre-flight lines (`FAIL  <check>`)
match. In the pilot of 19 October 2026, the condition's filter matched both the
`FAIL apply` line and Cloud Build's `ERROR: build step 9 ... failed` line in a
failed deployment's log. Email delivery was not tested, because no channel was
configured, and a build timeout was not tested.

## Related

- [Troubleshoot Cloud Build](../how-to/troubleshoot-cloud-build.md)
- [Triggers](triggers.md)
- [About the security model](../explanation/security-model.md)
- Back to the [documentation index](../../README.md#documentation)
