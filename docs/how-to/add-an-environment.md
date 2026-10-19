# How to add an environment

Use this guide to deploy the same repository to another GCP project, for
example a `prod` environment next to `dev`. Each environment has its own
project, state bucket, build identities and triggers.

## Before you start

- The repository already deploys one environment. See
  [Onboard a repository](onboard-a-repository.md).
- You have Owner on the new project, or the roles in
  [IAM: the person who runs bootstrap](../reference/iam.md#the-person-who-runs-bootstrap).
- The new project can pull the central Terraform image. See
  [Set up the organisation](set-up-the-organisation.md#grant-read-access-to-the-central-terraform-image).

## Create the environment file

1. Copy the existing file. The file name is the environment name:

   ```bash
   cp environments/dev.yaml environments/prod.yaml
   ```

   Names are 2 to 10 lowercase letters or digits, starting with a letter.

2. Edit `environments/prod.yaml`. Set a different project and the new name:

   ```yaml
   project:
     id: my-service-prod
     region: europe-west2

   environment:
     name: prod
   ```

   `environment.name` must match the file name. Pre-flight fails otherwise.
   Each environment needs its own project: bootstrap stops with
   `Give each environment its own project.` if another file uses the same
   `project.id`.

## Decide on approval

Deployments wait for a Cloud Build approval when `deploy.approval` is on. It
defaults to on for `prod` and `production`, and off for every other name.

- To keep the default, leave `deploy.approval` out.
- To change it, set `deploy.approval: true` or `deploy.approval: false`.
- To name who can approve, list IAM members under `deploy.approvers`. Bootstrap
  grants them `roles/cloudbuild.builds.approver`, but only when approval is on.

```yaml
deploy:
  approval: true
  approvers:
    - group:release-approvers@example.com
    - user:alice@example.com
```

Each approver needs the `user:` or `group:` prefix. Do not give approvers
`roles/cloudbuild.editor` for other reasons: it also contains the approve
permission.

## Add the roles your Terraform needs

If Terraform manages resources in the new project, list the project roles the
deploy identity needs under `deploy.roles`. Bootstrap rejects `roles/owner` and
`roles/editor`.

```yaml
deploy:
  roles:
    - roles/storage.admin
```

Keep `roles`, `approval` and `approvers` under one `deploy:` key.

## Run bootstrap for the new environment

Pass the environment name. Bootstrap only picks one by itself when
`environments/` holds a single file.

```bash
./scripts/bootstrap.sh prod
```

The new project needs its own GitHub connection, so bootstrap prints the
authorisation link once more. Open it and select **Authorize**.

On a public repository, bootstrap adds the new check to the `main` ruleset and
keeps the existing ones. It prints, for example:

```text
    ruleset "main - protected" requires: dev-ci (my-service-dev),prod-ci (my-service-prod)
```

## Commit the file

Commit `environments/prod.yaml` on a branch and open a pull request. From now
on, every pull request runs `dev-ci` and `prod-ci`, each in its own project.

## Check that it worked

- `./scripts/preflight.sh prod` shows
  `PASS  Cloud Build          triggers prod-ci and prod-deploy in europe-west2`.
- After you merge, `gcloud builds list --project my-service-prod --region europe-west2 --limit 1`
  shows a new build. With approval on, it waits until someone approves it.

## Approve a deployment

Every merge to `main` starts `dev-deploy` and `prod-deploy` at the same time.
Nothing orders them, so check that `dev-deploy` succeeded before you approve
`prod-deploy`.

```bash
gcloud builds list --project my-service-prod --region europe-west2 --limit 5
gcloud alpha builds approve BUILD_ID --location europe-west2 --project my-service-prod
```

Only the alpha command works: the GA `gcloud builds` group has no `approve`, and
the beta command rejected a build's full name in the pilot. Bootstrap's summary
prints the same alpha command. You can also approve the build on the Cloud
Build History page in the Google Cloud console.

Pending builds older than two months cannot be approved
([Gate builds on approval](https://docs.cloud.google.com/build/docs/securing-builds/gate-builds-on-approval),
updated 13 October 2026).

## Use different values per environment

Cloud Build passes the environment name to Terraform as `var.environment`. Keep
per-environment values in one `locals` map keyed by that name:

```hcl
locals {
  # One entry for each file in environments/.
  settings = {
    dev = {
      log_retention_days = 30
    }
    prod = {
      log_retention_days = 365
    }
  }

  env = local.settings[var.environment]
}
```

Then refer to `local.env.log_retention_days`. Add an entry for every
environment file. A missing entry fails the plan with `Invalid index`.

## Related

- [Configuration](../reference/configuration.md) lists every key.
- [Triggers](../reference/triggers.md) describes the two triggers per
  environment.
- [About minimal configuration](../explanation/minimal-configuration.md)
  explains the defaults.
- Back to the [documentation index](../../README.md#documentation)
