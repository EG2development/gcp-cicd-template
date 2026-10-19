# How to recover a failed deployment

Use this guide when the deploy build for `main` fails, and especially when the
`apply` step stopped part-way. The deployment alert links here.

## Before you start

- Find the failed build and its `FAIL` line. See
  [Troubleshoot Cloud Build](troubleshoot-cloud-build.md#find-the-build-and-its-log).
- For the state tasks below, you need `roles/storage.objectAdmin` on the state
  bucket `PROJECT_ID-tfstate`, or Owner on the project.

## Decide what happened

| Failed step | What changed in the project | Go to |
|---|---|---|
| `preflight` to `policy` | Nothing. Terraform did not apply. | Fix the cause in a pull request. |
| `apply`, with `Error 403` in the log | Some or none of the changes. The deploy identity lacks a role. | [Troubleshoot IAM: a deployment fails with Error 403](troubleshoot-iam.md#a-deployment-fails-with-error-403), a worked example from the pilot |
| `apply`, any other error | Some changes may have been applied. Terraform saved state for what it created. | [After a partial apply](#after-a-partial-apply) |
| `post` | The apply finished, but a new plan is not empty. | Fix the drift in a pull request. See [Troubleshoot Cloud Build](troubleshoot-cloud-build.md#fix-a-failed-step). |
| Any step, with `Error acquiring the state lock` | Nothing. Another run holds the lock. | [Release a stuck state lock](#release-a-stuck-state-lock) |

## After a partial apply

The state bucket keeps every version of the state for 90 days, so nothing is
lost. Choose one way forward.

### Fix forward

1. Read the Terraform error above `FAIL apply:`.
2. Fix the cause. For a missing permission, see
   [Troubleshoot IAM](troubleshoot-iam.md#a-deployment-fails-with-error-403).
3. Merge the fix through a pull request. The merge starts a new deploy build,
   which plans from the saved state and applies the rest.

### Re-run the deployment without a code change

If the cause was outside the code, such as a missing role, a quota or a short
outage, re-run the deploy trigger on `main`:

```bash
gcloud builds triggers run ENV-deploy --branch=main --project PROJECT_ID --region REGION
```

This works on the template's Developer Connect push triggers, by trigger name;
the pilot used it on 19 October 2026. If approval is on, the new build waits
for it; see [Add an environment](add-an-environment.md#approve-a-deployment).

### Revert the change

To undo the pull request, revert its commit on a branch and merge the revert.
`main` uses squash merges, so each pull request is one commit:

```bash
git switch main && git pull
git switch -c revert-change
git revert --no-edit COMMIT_SHA
git push -u origin revert-change
gh pr create --fill
```

Read the revert's `plan` step before you merge. Terraform destroys what the
reverted change created.

## Release a stuck state lock

Deploy steps wait up to 300 seconds for the lock. If a build was cancelled or
timed out during `plan` or `apply`, the lock can stay behind.

1. Make sure no build is running. This must show no builds:

   ```bash
   gcloud builds list --project PROJECT_ID --region REGION --ongoing
   ```

2. Find the lock ID. It is the `ID` in the Terraform lock error. It is also the
   generation of the lock object:

   ```bash
   gcloud storage objects describe gs://PROJECT_ID-tfstate/env/ENV/default.tflock --format='value(generation)'
   ```

3. Initialise the workload state as yourself, then release the lock:

   ```bash
   terraform init -reconfigure -backend-config=bucket=PROJECT_ID-tfstate -backend-config=prefix=env/ENV
   terraform force-unlock LOCK_ID
   ```

   Terraform asks you to confirm. Answer `yes`.

4. Re-run the deployment. See
   [Re-run the deployment](#re-run-the-deployment-without-a-code-change).

Never release a lock while a build is running. Two writers can corrupt the
state.

## Restore a previous state version

Do this only when the current state is wrong, for example corrupt or written
by mistake. An older state does not know about resources created since then,
so the next plan tries to create them again.

1. Make sure no build is running, as in
   [Release a stuck state lock](#release-a-stuck-state-lock).
2. List the versions of the state object. Each name ends in `#GENERATION`:

   ```bash
   gcloud storage ls --all-versions --long gs://PROJECT_ID-tfstate/env/ENV/default.tfstate
   ```

3. Copy the version you want over the live object. Quote the source, because
   some shells treat `#` as special:

   ```bash
   gcloud storage cp "gs://PROJECT_ID-tfstate/env/ENV/default.tfstate#GENERATION" gs://PROJECT_ID-tfstate/env/ENV/default.tfstate
   ```

   The copy becomes the live version. The version it replaced stays in the
   bucket as a noncurrent version for 90 days.

4. Run a [local plan](run-terraform-locally.md) and check that it matches what
   exists in the project.
5. Merge a pull request, or re-run the deploy trigger, to continue.

Source: [Use versioned objects](https://docs.cloud.google.com/storage/docs/using-versioned-objects),
updated 13 October 2026.

## Never edit state by hand

Do not download, edit and upload a state file. Do not run `terraform apply`
from your machine against an environment that Cloud Build deploys. Make every
change through a pull request.

## Related

- [Run Terraform locally](run-terraform-locally.md)
- [Build stages](../reference/build-stages.md)
- [About the architecture](../explanation/architecture.md)
- Back to the [documentation index](../../README.md#documentation)
