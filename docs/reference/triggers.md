# Triggers

Each environment has two Cloud Build triggers, defined in `cicd/github.tf` and
created by `scripts/bootstrap.sh`. Both are in the environment's project and
region, and both use the project's Developer Connect repository link.

## Fields

| Field | Pull-request trigger | Deploy trigger |
|---|---|---|
| Name | `<env>-ci` | `<env>-deploy` |
| Description | `Checks and plan for pull requests to main (<owner>/<repository>, <env>). Read-only.` | `Plan, check and apply main (<owner>/<repository>, <env>).` |
| Location | `project.region` | `project.region` |
| Event | Pull request (`developer_connect_event_config.pull_request`) | Push (`developer_connect_event_config.push`) |
| Branch regex | `^main$` (the pull request's base branch) | `^main$` |
| Comment control | `COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY` | Not applicable |
| Build file | `cloudbuild/ci.yaml`, read from the pull request's commit | `cloudbuild/deploy.yaml`, read from the pushed commit on `main` |
| Service account | `tf-ci-<env>` | `tf-deploy-<env>` |
| Approval | None | `approval_required` from `deploy.approval` |
| Tags | `terraform`, `ci`, `<env>` | `terraform`, `deploy`, `<env>` |
| Repository link | `google_developer_connect_git_repository_link.repository` | The same |
| Created after | The IAM wait and the CI identity's state bucket grant | The IAM wait and the deploy identity's state bucket grant |

## Substitutions

Both triggers pass the same values:

| Substitution | Value | Example |
|---|---|---|
| `_ENVIRONMENT` | `environment.name` | `dev` |
| `_PROJECT_ID` | `project.id` | `my-service-dev` |
| `_REGION` | `project.region` | `europe-west2` |
| `_STATE_BUCKET` | The state bucket name | `my-service-dev-tfstate` |

`_TF_IMAGE` is not a trigger substitution. Each YAML file sets it.

## Comment control values

The pull-request trigger uses the middle value.

| Value | Builds start when |
|---|---|
| `COMMENTS_ENABLED` | The author has write access and `/gcbrun` is in the pull request description, or someone with write access comments `/gcbrun` |
| `COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY` | Automatically for authors with write access; for anyone else, when someone with write access comments `/gcbrun` |
| `COMMENTS_DISABLED` | Automatically; a `/gcbrun` comment from someone with write access also starts one |

Pull-request builds run on each change to the pull request. Closing the pull
request cancels running builds; merging does not.

Source: [Cloud Build REST: BuildTrigger](https://docs.cloud.google.com/build/docs/api/reference/rest/v1/projects.locations.triggers),
checked 18 October 2026.

## Approval

| Item | Value |
|---|---|
| Applies to | The deploy trigger only |
| Default | On for `prod` and `production`, off otherwise |
| Who can approve | Holders of `roles/cloudbuild.builds.approver` (from `deploy.approvers`), `roles/cloudbuild.editor` or `roles/cloudbuild.admin` |
| Time limit | Builds pending for more than two months cannot be approved |
| After rejection | The build never starts |

Source: [Gate builds on approval](https://docs.cloud.google.com/build/docs/securing-builds/gate-builds-on-approval),
updated 13 October 2026.

## GitHub check

| Item | Pull-request trigger | Deploy trigger |
|---|---|---|
| Check name | `<env>-ci (<project.id>)`, for example `dev-ci (my-service-dev)` | `<env>-deploy (<project.id>)`, for example `dev-deploy (my-service-dev)` |
| Appears on | The pull request's head commit | The commit on `main` |
| Posted by | GitHub App `google-cloud-developer-connect`, ID `865529` | The same |
| Required by the `main - protected` ruleset | Yes, when GitHub enforces it | No |
| App ID in the ruleset | `865529` (`DEVELOPER_CONNECT_APP_ID` in `scripts/bootstrap.sh`) | Not applicable |

Google does not document the check name or the posting app for Developer
Connect triggers. Both were confirmed from real check runs in two pilots on
18 and 19 October 2026.

## Related

- [Build stages](build-stages.md)
- [Service accounts](service-accounts.md)
- [Troubleshoot Cloud Build](../how-to/troubleshoot-cloud-build.md)
- Back to the [documentation index](../../README.md#documentation)
