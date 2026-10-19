# Configuration

`environments/<env>.yaml` is the only CI/CD configuration. There is one file per
environment, and the file name is the environment name. `scripts/preflight.sh`,
`scripts/bootstrap.sh`, `cicd/` and both Cloud Build files read it.

## Example with every key

```yaml
project:
  id: my-service-prod
  region: europe-west2

environment:
  name: prod

deploy:
  roles:
    - roles/storage.admin
  approval: true
  approvers:
    - group:release-approvers@example.com
alerts:
  email: team@example.com
```

## Keys

| Key | Type | Required | Default | Rules | Used for |
|---|---|---|---|---|---|
| `project.id` | string | Yes | none | Matches `^[a-z][a-z0-9-]{4,28}[a-z0-9]$`. Not `my-gcp-project`. Not used by another environment file. | Target project; state bucket name |
| `project.region` | string | No | `europe-west2` | Matches `^[a-z]+-[a-z]+[0-9]+$` | Cloud Build triggers, Developer Connect connection, state bucket, log bucket |
| `environment.name` | string | Yes | none | Equals the file name. Matches `^[a-z][a-z0-9]{1,9}$`. | Identity, trigger, log bucket and sink names |
| `deploy.roles` | list of strings | No | `[]` | Project role names. Not `roles/owner` or `roles/editor`. | Extra project roles for `tf-deploy-<env>` |
| `deploy.approval` | boolean | No | `true` if `environment.name` is `prod` or `production`, otherwise `false` | Not checked | Cloud Build approval on the deploy trigger |
| `deploy.approvers` | list of strings | No | `[]` | IAM members with a prefix, such as `user:` or `group:` | `roles/cloudbuild.builds.approver` on the project, granted only when approval is on |
| `alerts.email` | string | No | `""` | Not checked | Email notification channel for the deployment-failure alert |

Without `alerts.email`, the alert policy still exists but sends no
notification.

## Where each rule is checked

| Rule | Pre-flight (local) | Pre-flight `--ci` | Terraform (`cicd/`) |
|---|---|---|---|
| File exists and is valid YAML | Yes | Yes | Yes (`yamldecode`) |
| `project.id` is set and well formed | Yes | Yes | No |
| `project.region` is well formed | Yes | Yes | No |
| `environment.name` matches the file name and pattern | Yes | Yes | Yes (`var.environment` validation and a precondition) |
| No `roles/owner` or `roles/editor` in `deploy.roles` | No | No | Yes (precondition) |
| No other environment file uses the same `project.id` | No | No | Yes (precondition) |
| `project.id` and `project.region` match the trigger | No | Yes | No |

The root module's `variables.tf` applies the same patterns to `project_id`,
`region` and `environment` during every plan.

## Changing values after bootstrap

| Change | Effect |
|---|---|
| `deploy.roles`, `deploy.approval`, `deploy.approvers`, `alerts.email` | Takes effect when you re-run `./scripts/bootstrap.sh ENV`. |
| `project.id` or `project.region` | Builds fail in `preflight` until bootstrap runs again, because the trigger still passes the old values. After a `project.id` change, the old project's triggers stay and keep failing; bootstrap does not remove them, so delete them by hand. |
| `project.region` | Bootstrap cannot move the state bucket, which has `prevent_destroy`. A Developer Connect connection's region cannot change after creation. |
| `environment.name` | Must still equal the file name. |

## Derived values

Nothing below is configured. Each value comes from the file, the git remote or
a fixed rule.

| Value | Rule | Example (`dev`, `my-service-dev`) | Source |
|---|---|---|---|
| GitHub repository | `owner/name` from `git remote get-url origin` (`git@github.com:`, `https://github.com/` or `ssh://git@github.com/`) | `EG2development/my-service` | `scripts/preflight.sh` `github_repository` |
| Repository link ID | Repository name in lowercase, other characters replaced by `-`, at most 63 characters | `my-service` | `cicd/main.tf` `link_id` |
| State bucket | `<project.id>-tfstate` | `my-service-dev-tfstate` | `scripts/preflight.sh`, `cicd/main.tf` |
| Workload state prefix | `env/<env>` | `env/dev` | `cloudbuild/*.yaml`, `scripts/bootstrap.sh` |
| `cicd/` state prefix | `cicd/<env>` | `cicd/dev` | `scripts/bootstrap.sh` |
| CI identity | `tf-ci-<env>` | `tf-ci-dev@my-service-dev.iam.gserviceaccount.com` | `cicd/main.tf` |
| Deploy identity | `tf-deploy-<env>` | `tf-deploy-dev@my-service-dev.iam.gserviceaccount.com` | `cicd/main.tf` |
| Triggers | `<env>-ci`, `<env>-deploy` | `dev-ci`, `dev-deploy` | `cicd/github.tf` |
| Check name | `<env>-ci (<project.id>)` | `dev-ci (my-service-dev)` | `cicd/outputs.tf` |
| Developer Connect connection | `github` | `github` | `cicd/github.tf` |
| Log bucket and sink | `cicd-<env>` | `cicd-dev` | `cicd/monitoring.tf` |
| Labels on `cicd/` resources | `managed-by=terraform`, `environment=<env>`, `repository=<link ID>` | | `cicd/main.tf` |

The check name was confirmed from real check runs in two pilots on 18 and
19 October 2026.

## Defaults in the scripts

| Setting | Default |
|---|---|
| Environment for `bootstrap.sh` and `preflight.sh` | The only file in `environments/`; `dev` if there are several or none |

## Variables of `cicd/`

Bootstrap sets `environment` and `github_repository`, and sets `connect_only`
for its first, targeted apply. You can set `iam_propagation_seconds` as
`TF_VAR_iam_propagation_seconds` before you run bootstrap.

| Variable | Type | Default | Set by | Rules |
|---|---|---|---|---|
| `environment` | string | none | Bootstrap (`TF_VAR_environment`) | `^[a-z][a-z0-9]{1,9}$` |
| `github_repository` | string | none | Bootstrap (`TF_VAR_github_repository`) | `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$` |
| `github_app_installation_id` | number | `172925456` (`EG2development`, all repositories) | Platform Engineering, in the template | The Developer Connect app's installation on the organisation. `null` lets the browser step choose. |
| `connect_only` | bool | `false` | Bootstrap (`-var=connect_only=true` while it creates the connection) | When `true`, the connection is created without an installation. Developer Connect rejects a new connection that names an installation before anyone has authorised it. |
| `iam_propagation_seconds` | number | `60` | You, optionally | Wait after the first IAM grants |

## Variables of the root module

Cloud Build sets these from the file as `TF_VAR_project_id`, `TF_VAR_region` and
`TF_VAR_environment`. For local runs, use `terraform.tfvars`.

| Variable | Type | Rules |
|---|---|---|
| `project_id` | string | `^[a-z][a-z0-9-]{4,28}[a-z0-9]$` |
| `region` | string | `^[a-z]+-[a-z]+[0-9]+$` |
| `environment` | string | `^[a-z][a-z0-9]{1,9}$` |

## Related

- [Add an environment](../how-to/add-an-environment.md)
- [About minimal configuration](../explanation/minimal-configuration.md)
- Back to the [documentation index](../../README.md#documentation)
