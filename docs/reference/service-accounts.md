# Service accounts

The identities that CI/CD uses in each environment's project. Bootstrap
creates no service account keys, and nothing in the template uses one.

## Build identities

`cicd/main.tf` creates two service accounts per environment.

| Field | CI identity | Deploy identity |
|---|---|---|
| Account ID | `tf-ci-<env>` | `tf-deploy-<env>` |
| Email | `tf-ci-<env>@PROJECT_ID.iam.gserviceaccount.com` | `tf-deploy-<env>@PROJECT_ID.iam.gserviceaccount.com` |
| Display name | `Terraform CI (<env>)` | `Terraform deploy (<env>)` |
| Description | `Pull-request checks and plans for <owner>/<repository>. Read-only.` | `Applies Terraform from main for <owner>/<repository>.` |
| Used by | Trigger `<env>-ci` (`cloudbuild/ci.yaml`); bootstrap's smoke build | Trigger `<env>-deploy` (`cloudbuild/deploy.yaml`) |
| Project roles | `roles/logging.logWriter`, `roles/developerconnect.readTokenAccessor`, `roles/viewer` | The same three, plus `deploy.roles` |
| State bucket role | `roles/storage.objectViewer` | `roles/storage.objectAdmin` |
| Central image | `roles/artifactregistry.reader`, granted by Platform Engineering | The same |
| Can act as the other | No | No |
| Keys | None | None |
| Terraform output | `ci_service_account` | `deploy_service_account` |

A trigger always runs as the account named in its `service_account` field. A
`serviceAccount` in a build YAML file is ignored. See
[IAM](iam.md) for the reason behind each role.

## Google-managed service agents

Google creates and owns these. The template grants a role to one of them.

| Field | Developer Connect service agent | Cloud Build service agent |
|---|---|---|
| Email | `service-PROJECT_NUMBER@gcp-sa-devconnect.iam.gserviceaccount.com` | `service-PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com` |
| Created by | `google_project_service_identity` in `cicd/github.tf` (google-beta provider) | Google, when the Cloud Build API is enabled |
| Role granted by the template | `roles/secretmanager.admin` on the project | None |
| Role granted by Google | Not covered here | `roles/cloudbuild.serviceAgent` |
| Why it needs it | Stores the GitHub OAuth token in Secret Manager when the connection is authorised | Runs builds; its role contains `developerconnect.gitRepositoryLinks.fetchReadToken` |

`cicd/` creates the Developer Connect service agent before the connection, so
that the agent's role exists when the browser authorisation stores the token.

## Accounts the template does not use

| Account | Status |
|---|---|
| Compute Engine default service account (`PROJECT_NUMBER-compute@developer.gserviceaccount.com`) | Never used. Every trigger and the smoke build name their own account. |
| Cloud Build legacy service account (`PROJECT_NUMBER@cloudbuild.gserviceaccount.com`) | Never used. Projects without an organisation cannot use it. |
| Log sink writer identity | Not needed. The `cicd-<env>` sink writes to a log bucket in its own project. |

Sources, checked 18 October 2026:
[Developer Connect access control](https://docs.cloud.google.com/developer-connect/docs/access-control),
[Cloud Build IAM roles](https://docs.cloud.google.com/iam/docs/roles-permissions/cloudbuild),
[Cloud Build service account changes](https://docs.cloud.google.com/build/docs/cloud-build-service-account-updates),
[Configure user-specified service accounts](https://docs.cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts).

## Related

- [IAM](iam.md)
- [Triggers](triggers.md)
- [About the security model](../explanation/security-model.md)
- Back to the [documentation index](../../README.md#documentation)
