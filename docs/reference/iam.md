# IAM

Every role the template grants, every role it needs from people, and what it
deliberately does not grant. All grants are in the environment's own project
unless stated otherwise. Checked on 18 October 2026.

## Build identities: project roles

Granted in `cicd/main.tf` to `tf-ci-<env>` and `tf-deploy-<env>`.

| Role | CI | Deploy | Purpose |
|---|---|---|---|
| `roles/logging.logWriter` | Yes | Yes | Write build logs. Builds use `CLOUD_LOGGING_ONLY`, which a user-specified service account needs. |
| `roles/developerconnect.readTokenAccessor` | Yes | Yes | Clone the repository through the Developer Connect link. A Beta role. It can only be granted on the project or above. |
| `roles/viewer` | Yes | Yes | Read resources during `terraform plan` refresh. |
| Each role in `deploy.roles` | No | Yes | Manage the resources in your Terraform. |

## Build identities: state bucket roles

Granted in `cicd/main.tf` on the bucket `PROJECT_ID-tfstate` only.

| Role | CI | Deploy | Purpose |
|---|---|---|---|
| `roles/storage.objectViewer` | Yes | No | Read state to plan. Cannot write state or take the lock. |
| `roles/storage.objectAdmin` | No | Yes | Read, lock and write state. |

## Central Terraform image

| Role | Member | Resource | Granted by |
|---|---|---|---|
| `roles/artifactregistry.reader` | A principal set that includes the build identities: organisation, folder or project `.../type/ServiceAccount` | Repository `terraform-runtime`, project `gcp-cicd-template`, `europe-west2` | Platform Engineering, outside the template |
| `roles/artifactregistry.reader` | Optional: the people who run bootstrap, through a group | The same repository | Platform Engineering |

See [Set up the organisation](../how-to/set-up-the-organisation.md#grant-read-access-to-the-central-terraform-image).

## Developer Connect service agent

| Role | Member | Granted in | Purpose |
|---|---|---|---|
| `roles/secretmanager.admin` | `service-PROJECT_NUMBER@gcp-sa-devconnect.iam.gserviceaccount.com` | `cicd/github.tf` | The agent creates the secret that holds the GitHub OAuth token when the connection is authorised. |

## People who approve deployments

| Role | Member | Granted in | When |
|---|---|---|---|
| `roles/cloudbuild.builds.approver` | Each entry in `deploy.approvers` | `cicd/main.tf` | Only when approval is on for the environment |

`roles/cloudbuild.editor` and `roles/cloudbuild.admin` also contain
`cloudbuild.builds.approve`. Anyone who holds them can approve deployments.

## The person who runs bootstrap

Bootstrap creates everything as the person who runs it. Project Owner covers
every project-level permission. Without Owner, a person needs these roles on the
project:

| Permission | Role | Checked by pre-flight |
|---|---|---|
| `serviceusage.services.enable` | `roles/serviceusage.serviceUsageAdmin` | Yes |
| `iam.serviceAccounts.create` | `roles/iam.serviceAccountAdmin` | Yes |
| `iam.serviceAccounts.actAs` | `roles/iam.serviceAccountUser` | Yes |
| `resourcemanager.projects.setIamPolicy` | `roles/resourcemanager.projectIamAdmin` | Yes |
| `storage.buckets.create` | `roles/storage.admin` | Yes |
| `cloudbuild.builds.create` | `roles/cloudbuild.builds.editor` | Yes |
| `logging.buckets.create` | `roles/logging.configWriter` | Yes |
| `logging.sinks.create` | `roles/logging.configWriter` | Yes |
| `monitoring.alertPolicies.create` | `roles/monitoring.editor` | Yes |
| `developerconnect.connections.create` | `roles/developerconnect.admin` | Yes, once the Developer Connect API is enabled |

The permissions come from `REQUIRED_PERMISSIONS` and `check_iam` in
`scripts/preflight.sh`. `cicd/monitoring.tf` creates the log bucket and sink.

Read access to the central Terraform image is optional for the person. Without
it, pre-flight warns, and bootstrap's smoke build checks the CI identity's
access instead. Owner on the target project does not give this access.

`roles/iam.serviceAccountUser` on the project lets the holder act as every
service account in the project, including `tf-deploy-<env>`.

## What is deliberately not granted

| Not granted | Reason |
|---|---|
| `roles/owner` or `roles/editor` to the deploy identity | A precondition in `cicd/main.tf` rejects them in `deploy.roles`. |
| Any role that lets one build identity act as the other (`roles/iam.serviceAccountTokenCreator`, `roles/iam.serviceAccountUser`) | Pull-request code would otherwise become the deploy identity. |
| `roles/iam.serviceAccountUser` on the project to either identity | Same reason. Google's provider example grants it; the template does not. |
| State write access to the CI identity | Pull requests can plan but never change state. The plan runs with `-lock=false`. |
| IAM, trigger or service account admin roles to either identity | The pipeline cannot change its own identities or triggers. Only bootstrap, run by a person, applies `cicd/`. |
| Service account keys | Builds run as the trigger's attached identity. |

Roles you add to `deploy.roles` widen what a merge to `main` can change. A role
that includes `setIamPolicy` permissions lets the deploy identity change access.

## Sources

Checked 18 October 2026:

- [Developer Connect IAM roles](https://docs.cloud.google.com/iam/docs/roles-permissions/developerconnect)
- [Cloud Build IAM roles](https://docs.cloud.google.com/iam/docs/roles-permissions/cloudbuild)
- [Gate builds on approval](https://docs.cloud.google.com/build/docs/securing-builds/gate-builds-on-approval)
- [Configure user-specified service accounts](https://docs.cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts)
- [Artifact Registry access control](https://docs.cloud.google.com/artifact-registry/docs/access-control)
- [Principal identifiers](https://docs.cloud.google.com/iam/docs/principal-identifiers)

## Related

- [Service accounts](service-accounts.md)
- [Troubleshoot IAM](../how-to/troubleshoot-iam.md)
- [About the security model](../explanation/security-model.md)
- Back to the [documentation index](../../README.md#documentation)
