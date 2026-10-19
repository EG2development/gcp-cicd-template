# Versions

The Terraform, provider, image and tool versions this repository uses, and
where each is pinned. Checked on 18 October 2026.

## Terraform

| Item | Value | Pinned in |
|---|---|---|
| Version | `1.16.6` | `.terraform-version` |
| Constraint | `~> 1.16.6` | `versions.tf` line 2, `cicd/versions.tf` line 2 |
| Accepted | 1.16.6 and later 1.16 patches | |
| Rejected | 1.16.5 and earlier, 1.17.0 and later | |
| Released | 14 October 2026 | |

`~>` lets only the right-most version part increase
([Version constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints),
checked 18 October 2026). Terraform 1.17.0 was a release candidate (rc2) on
18 October 2026 and is not supported. To change the version, see
[Update Terraform](../how-to/update-terraform.md).

## Google providers

| Provider | Locked version | Constraint | Pinned in | Released |
|---|---|---|---|---|
| `hashicorp/google` | `8.7.0` | `~> 8.7` | `versions.tf` line 7, `cicd/versions.tf` line 7, both lock files | 13 October 2026 |
| `hashicorp/google-beta` | `8.7.0` | `~> 8.7` | `cicd/versions.tf` line 14, `cicd/.terraform.lock.hcl` | 13 October 2026 |

`~> 8.7` accepts 8.7 and every later 8.x release, and rejects 9.0. The lock
files fix the exact version. `google-beta` is used only by
`google_project_service_identity` in `cicd/github.tf`, which is beta-only in
8.7.0. To change versions, see
[Update the Google provider](../how-to/update-the-google-provider.md).

## Lock file platforms

Both lock files hold hashes for four platforms:

| Platform | Used by |
|---|---|
| `linux_amd64` | Cloud Build workers |
| `linux_arm64` | Linux containers on Apple silicon |
| `darwin_arm64` | macOS on Apple silicon |
| `darwin_amd64` | macOS on Intel |

See [Refresh the lock file](../how-to/refresh-the-lock-file.md).

## Approved Terraform image

| Item | Value |
|---|---|
| Image | `europe-west2-docker.pkg.dev/gcp-cicd-template/terraform-runtime/terraform` |
| Digest | `sha256:8fff2a67f0d00ffbb8df2859a862ba8952e9d9cd96af7ae58be8dd743d5e3b17` |
| Pinned in | `_TF_IMAGE` in `cloudbuild/ci.yaml` line 10 and `cloudbuild/deploy.yaml` line 11 |
| Registry | Artifact Registry repository `terraform-runtime`, project `gcp-cicd-template`, location `europe-west2` |

Every build step and the bootstrap smoke build run this image. Pre-flight fails
if the image is not pinned by digest, or if the two files differ.

## Tools in the approved image

| Tool | Version | Released | Also pinned in |
|---|---|---|---|
| Terraform | 1.16.6 | 14 October 2026 | `.terraform-version` |
| TFLint | 0.64.0 | 17 July 2026 | |
| tflint-ruleset-google | 0.40.0 | 23 September 2026 | `.tflint.hcl` line 10 |
| Trivy | 0.76.0 | 14 October 2026 | |

Source: Platform Engineering's image Dockerfile, which pins
`TERRAFORM_VERSION=1.16.6`, `TFLINT_VERSION=0.64.0`,
`TFLINT_GOOGLE_VERSION=0.40.0` and `TRIVY_VERSION=0.76.0`, each with a SHA256
checked at build time. The build log of 18 October 2026 printed Terraform
v1.16.6, TFLint 0.64.0 and Trivy 0.76.0.

In Cloud Build, pre-flight fails if `terraform`, `tflint` or `trivy` is missing
from the image, or if the image's Terraform differs from `.terraform-version`.

## Release status on 18 October 2026

| Component | Latest stable | Status of this repository's pin |
|---|---|---|
| Terraform | 1.16.6 | Current |
| `hashicorp/google` | 8.7.0 | Current |
| `hashicorp/google-beta` | 8.7.0 | Current |
| TFLint | 0.64.0 | Current |
| tflint-ruleset-google | 0.40.0 | Current |
| Trivy | 0.76.0 | Current |

Sources, checked 18 October 2026:
[Terraform releases](https://releases.hashicorp.com/terraform/1.16.6/),
[google provider](https://registry.terraform.io/v1/providers/hashicorp/google),
[google-beta provider](https://registry.terraform.io/v1/providers/hashicorp/google-beta),
[TFLint](https://github.com/terraform-linters/tflint/releases/tag/v0.64.0),
[tflint-ruleset-google](https://github.com/terraform-linters/tflint-ruleset-google/releases/tag/v0.40.0),
[Trivy](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0).

## Local tools

| Tool | Needed for | Version |
|---|---|---|
| Terraform | Pre-flight, bootstrap, local plans | Accepted by `~> 1.16.6`. Pre-flight passes on 1.16.6, warns on a later 1.16 patch, and fails on anything else. |
| Google Cloud CLI (`gcloud`) | Pre-flight, bootstrap | A release with the GA `gcloud developer-connect` command group |
| GitHub CLI (`gh`) | Bootstrap's ruleset and team steps | Not pinned |
| bash | Both scripts | 3.2 (macOS) or later |
| TFLint, Trivy | Optional local checks | Match the image to get the same results |

## Related

- [About the approved Terraform image](../explanation/terraform-image.md)
- [Design decisions](../explanation/design-decisions.md)
- Back to the [documentation index](../../README.md#documentation)
