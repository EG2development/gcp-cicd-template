# How to run Terraform locally

Use this guide to plan, test and lint from your own machine before you push.
Cloud Build owns every apply. Never run `terraform apply` locally against an
environment that Cloud Build deploys.

## Before you start

- Terraform 1.16.6 or a later 1.16 patch. `versions.tf` rejects anything else.
  Pre-flight warns about a later 1.16 patch and fails anything else.
- Application-default credentials: `gcloud auth application-default login`.
  Terraform uses these, not your `gcloud auth login` session.
- To plan, read access to the project and to objects in the state bucket
  `PROJECT_ID-tfstate`. Owner has both.

## Set the variables

Copy the example file. Git ignores `terraform.tfvars`.

```bash
cp terraform.tfvars.example terraform.tfvars
```

Set the same values as `environments/ENV.yaml`:

```hcl
project_id  = "my-service-dev"
region      = "europe-west2"
environment = "dev"
```

## Connect to the environment's state

```bash
terraform init -reconfigure -lockfile=readonly -backend-config=bucket=my-service-dev-tfstate -backend-config=prefix=env/dev
```

These are the bucket and prefix Cloud Build uses. `-lockfile=readonly` stops
`init` from changing the lock file, as in Cloud Build.

## Plan as yourself

```bash
terraform plan -lock=false
```

`-lock=false` matches the pull-request build. Your plan does not hold the state
lock, so it never blocks a deployment.

Your plan runs with your permissions, not the CI identity's. A plan that works
for you can still fail in Cloud Build if it reads something `roles/viewer`
cannot. See
[Troubleshoot IAM](troubleshoot-iam.md#a-pull-request-plan-fails-with-permission-denied).

## Switch to another environment

Run `init` again with the other environment's bucket and prefix, and change
`terraform.tfvars` to match:

```bash
terraform init -reconfigure -lockfile=readonly -backend-config=bucket=my-service-prod-tfstate -backend-config=prefix=env/prod
```

## Run the other checks

These match the pull-request build's steps:

```bash
terraform fmt -recursive
terraform validate
tflint --init && tflint --recursive
trivy config --severity HIGH,CRITICAL .
terraform test
```

`terraform test` uses a mock provider, so it needs no credentials and no state.
`tflint --init` downloads the plugin version pinned in `.tflint.hcl`; the
approved image already contains it. Local TFLint and Trivy versions can differ
from the image's. See [Versions](../reference/versions.md).

## Check everything at once

```bash
./scripts/preflight.sh ENV
```

Pre-flight checks your tools, configuration, GCP access, image and both
Terraform roots. See [Commands](../reference/commands.md).

## Related

- [Recover a failed deployment](recover-a-failed-deployment.md) covers the few
  tasks you do run locally, such as releasing a stuck lock.
- [Build stages](../reference/build-stages.md)
- Back to the [documentation index](../../README.md#documentation)
