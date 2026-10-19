# How to update Terraform

Use this guide to move a repository to a new Terraform version. The version is
set in five places, and they must agree:

| File | What to change |
|---|---|
| `.terraform-version` | The exact version, for example `1.16.7` |
| `versions.tf` | `required_version` |
| `cicd/versions.tf` | `required_version` |
| `cloudbuild/ci.yaml` | `_TF_IMAGE` digest |
| `cloudbuild/deploy.yaml` | `_TF_IMAGE` digest |

## Before you start

- Platform Engineering has published an approved Terraform image that contains
  the new version. You need its full name with the `@sha256:` digest. Never use
  a tag such as `latest`, and never use a release candidate.
- [Versions](../reference/versions.md) shows the current values.

## Change the version

1. Show the current values:

   ```bash
   cat .terraform-version
   grep -n -e required_version -e '_TF_IMAGE:' versions.tf cicd/versions.tf cloudbuild/ci.yaml cloudbuild/deploy.yaml
   ```

2. Write the new version to `.terraform-version`:

   ```bash
   echo 1.16.7 > .terraform-version
   ```

3. In `versions.tf` and `cicd/versions.tf`, change `required_version`:

   - For a new patch, such as 1.16.7: `required_version = "~> 1.16.7"`.
   - For a new minor, such as 1.17.0: `required_version = "~> 1.17.0"`.

4. In `cloudbuild/ci.yaml` and `cloudbuild/deploy.yaml`, set `_TF_IMAGE` to the
   new approved image. Use the same value in both files:

   ```yaml
   _TF_IMAGE: europe-west2-docker.pkg.dev/gcp-cicd-template/terraform-runtime/terraform@sha256:NEW_DIGEST
   ```

5. Install the new version on your machine. With tfenv, run this in the
   repository root; it reads `.terraform-version`:

   ```bash
   tfenv install
   ```

## Check the change

Run pre-flight:

```bash
./scripts/preflight.sh
```

Look for these results:

| Check | What it compares |
|---|---|
| `Terraform version` | Your local Terraform with `.terraform-version`. Passes if equal, warns for a later patch of the same minor, fails otherwise. |
| `Terraform image` | The image is pinned by digest, readable, and the same in both YAML files |
| `terraform validate` | Runs `init` and `validate` in both roots, so a `required_version` that excludes your Terraform fails here |

In Cloud Build, the `preflight` step also compares the image's Terraform with
`.terraform-version`. If they differ, it fails with
`FAIL  Terraform version    image has X, .terraform-version says Y`.

## Open the pull request

Commit the five files on a branch and open a pull request. Platform Engineering
reviews it, because `.github/CODEOWNERS` assigns them `cloudbuild/` and `cicd/`.

The pull-request build runs the new image, because Cloud Build reads
`cloudbuild/ci.yaml` from the pull request. After the merge, deployments use
the new image too.

You do not need to re-run bootstrap.

## After a minor-version change

Everyone who runs Terraform locally must install the new version. Pre-flight
fails for an older patch or a different minor version, because
`required_version` accepts only the new version and later patches of its
minor line.

## Related

- [Update the Google provider](update-the-google-provider.md)
- [About the approved Terraform image](../explanation/terraform-image.md)
- [Build stages](../reference/build-stages.md)
- Back to the [documentation index](../../README.md#documentation)
