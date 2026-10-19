# How to troubleshoot IAM

Use this guide when pre-flight, bootstrap or a build fails because an identity
is missing a permission. [IAM](../reference/iam.md) lists every role the
template grants and needs.

## Pre-flight shows an IAM failure

```text
FAIL  IAM                  missing: iam.serviceAccounts.create logging.buckets.create logging.sinks.create
      Why: bootstrap creates service accounts, IAM bindings, triggers and the state bucket as you
      Fix: ask a project owner for roles/owner on PROJECT_ID, or for: roles/iam.serviceAccountAdmin roles/logging.configWriter
```

The `Fix:` line names each role that grants a missing permission, once. Ask a
project owner to grant either `roles/owner` or those roles:

```bash
gcloud projects add-iam-policy-binding PROJECT_ID --member=user:YOU@example.com --role=roles/iam.serviceAccountAdmin
```

Once the Developer Connect API is enabled, pre-flight also checks
`developerconnect.connections.create`. If that fails, ask for
`roles/developerconnect.admin`.

[IAM: the person who runs bootstrap](../reference/iam.md#the-person-who-runs-bootstrap)
lists every permission and role.

## Pre-flight warns that you cannot read the Terraform image

```text
WARN  Terraform image      you cannot read europe-west2-docker.pkg.dev/gcp-cicd-template/terraform-runtime/terraform; bootstrap's smoke build checks the CI identity instead
```

This is a warning, not a failure. Builds pull the image as the build identity,
not as you, and bootstrap's smoke build proves that access. If you want the
check to pass, ask Platform Engineering for read access; see
[Set up the organisation](set-up-the-organisation.md#grant-read-access-to-the-central-terraform-image).

## The state bucket cannot be created

Bootstrap stops with:

```text
FAIL  could not create gs://PROJECT_ID-tfstate
      Fix: check storage.buckets.create on PROJECT_ID; bucket names are global, so if another project owns PROJECT_ID-tfstate, see docs/how-to/troubleshoot-iam.md
```

1. Check that pre-flight shows `PASS  IAM`. If not, fix that first.
2. Check whether the bucket already exists somewhere else:

   ```bash
   gcloud storage buckets describe gs://PROJECT_ID-tfstate --format='value(name)'
   ```

   Bucket names are global. If the bucket exists in a project you cannot read,
   the command returns a permission error.

3. If another project owns the bucket, ask Platform Engineering. The name is
   fixed by design as `<project>-tfstate`, because project IDs are globally
   unique. The template has no setting to choose another name.

## Terraform apply fails for cicd/

Bootstrap stops with `FAIL  terraform apply failed for cicd/`. Read the
Terraform error above it.

| Error mentions | Cause | What to do |
|---|---|---|
| A trigger, and the service account's permission | The new IAM grants have not taken effect yet. | Wait a few minutes and re-run bootstrap. |
| `Do not give the deploy identity roles/owner or roles/editor.` | `deploy.roles` lists one of them. | List the specific roles instead. |
| `environment.name in environments/ENV.yaml must be ENV.` | The name in the file does not match the file name. | Fix `environment.name`. |
| `... also use project PROJECT_ID. Give each environment its own project.` | Another environment file uses the same `project.id`. | Use a separate project for each environment. |

If the app cannot see the repository, bootstrap stops with
`the Developer Connect GitHub App cannot see OWNER/REPOSITORY` instead. See
[Troubleshoot Cloud Build](troubleshoot-cloud-build.md#the-app-cannot-see-the-repository).

Bootstrap is safe to re-run. Every step skips what already exists.

## A deployment fails with Error 403

The deploy identity holds only its base roles and the roles in `deploy.roles`.
A pull request can pass, because the CI identity only plans, and the
deployment then fails at `plan` or `apply` with `Error 403`. The deploy build
prints:

```text
FAIL apply: some or all changes were not applied. An Error 403 means the deploy identity needs a role: add it to deploy.roles in environments/ENV.yaml, run ./scripts/bootstrap.sh ENV, then re-run this build (docs/how-to/recover-a-failed-deployment.md).
```

In the pilot, a pull request added a storage bucket to `main.tf`. Its check
passed with `Plan: 1 to add`. The deployment then failed at `apply` with
`Error 403: tf-deploy-dev@my-service-dev.iam.gserviceaccount.com does not have storage.buckets.create access ...`,
and GitHub showed the `dev-deploy` check as failed. The steps below recovered
it in 4 minutes 46 seconds.

1. Find a predefined role that contains the permission in the error. For
   `storage.buckets.create`, the pilot used `roles/storage.admin`.
2. In your copy of `main`, add the role to `deploy.roles` in
   `environments/ENV.yaml`:

   ```yaml
   deploy:
     roles:
       - roles/storage.admin
   ```

3. Grant it by running bootstrap. It took 98 seconds in the pilot.

   ```bash
   ./scripts/bootstrap.sh ENV
   ```

4. Re-run the deployment:

   ```bash
   gcloud builds triggers run ENV-deploy --branch=main --project PROJECT_ID --region REGION
   ```

   If approval is on, approve the build; see
   [Add an environment](add-an-environment.md#approve-a-deployment).
5. Commit the change to `environments/ENV.yaml` in a pull request. Until it
   merges, anyone who runs bootstrap from `main` removes the role again.

To avoid the failure, add the role in the same pull request that adds the
resource. Run `./scripts/bootstrap.sh ENV` from that branch before you merge.
Do this only if the branch changes nothing in `cicd/`, because bootstrap
applies `cicd/` from your working copy without review. The pull request
template asks you to confirm that you re-ran bootstrap.

Bootstrap refuses `roles/owner` and `roles/editor`.

## A pull-request plan fails with permission denied

The CI identity can read the project (`roles/viewer`) and the state bucket
(`roles/storage.objectViewer`). It cannot read secret values or anything else
outside `roles/viewer`.

- If your Terraform reads secret values or other protected data during the
  plan, change it so the plan does not need them.
- If the CI identity needs another read-only role, ask Platform Engineering.
  CI roles are set in `ci_roles` in `cicd/main.tf`, not in the environment
  file, and need their review.

## A build cannot pull the Terraform image

Bootstrap's smoke build stops with
`FAIL  the CI identity could not run a build with the approved Terraform image`.
Builds can also fail before the first step with an image pull error.

The project's build identities need `roles/artifactregistry.reader` on the
central repository. Bootstrap prints the exact command for Platform Engineering.
It grants read access to every service account in this project:

```bash
gcloud artifacts repositories add-iam-policy-binding terraform-runtime \
  --project gcp-cicd-template --location europe-west2 \
  --role roles/artifactregistry.reader \
  --member principalSet://cloudresourcemanager.googleapis.com/projects/PROJECT_NUMBER/type/ServiceAccount
```

If your projects belong to a GCP organisation or folder, Platform Engineering
can grant it once for all of them instead. See
[Set up the organisation](set-up-the-organisation.md#grant-read-access-to-the-central-terraform-image).
Then re-run bootstrap.

## A grant does not seem to work yet

New IAM grants take a short time to apply. `cicd/` waits 60 seconds after the
first grants before it creates the triggers (`iam_propagation_seconds` in
`cicd/variables.tf`). If a step still fails with a permission error soon after a
grant, wait a few minutes and re-run it. The wait only happens when the grants
change, so a re-run does not wait again.

## Related

- [IAM](../reference/iam.md)
- [Service accounts](../reference/service-accounts.md)
- [About the security model](../explanation/security-model.md)
- Back to the [documentation index](../../README.md#documentation)
