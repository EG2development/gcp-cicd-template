# About the approved Terraform image

Every Cloud Build step, in every repository made from the template, runs in one
container image from a central Artifact Registry repository. This page explains
why there is one image, why it is pinned by digest, and how it divides the work
with the repository.

## Why one image

Each build needs Terraform, TFLint with the Google ruleset, and Trivy. A build
could download them at run time. Then every build would depend on several
download sites, and the versions could differ between a pull request and the
deployment that follows it. One image holds all the tools, so the pull-request
build and the deployment run exactly the same programs. `.tflint.hcl` notes
that the image already ships the TFLint plugin, so builds never download one.

## Why a digest, not a tag

A tag such as `latest` or `1.16` is a pointer that someone can move. A digest
(`@sha256:...`) names the exact image contents. Pinning by digest means a build
runs the image that was reviewed, and nothing else. Pre-flight refuses an image
without a digest. It also refuses `ci.yaml` and `deploy.yaml` if they name
different images, because a pull request must be checked with the image that
will deploy it.

## What the image owns and what the repository owns

| The image provides | The repository provides |
|---|---|
| The Terraform binary | `required_version` and `.terraform-version` |
| TFLint, its Google ruleset, Trivy | `.tflint.hcl` settings |
| | Provider constraints in `versions.tf` |
| | Provider lock files with hashes |

The split means a provider update needs no new image, and a new image changes
no provider. Terraform downloads providers during `init` and checks them
against the lock file. The two halves meet at one point: in Cloud Build,
pre-flight fails if the image's Terraform differs from `.terraform-version`.

## Why `~> 1.16.6` for Terraform

HashiCorp promises that upgrades within Terraform 1.x need no configuration
changes. In practice, only the newest minor line gets patches. The last 1.15
patch, 1.15.9, came out on 19 August 2026. None has followed since 1.16.0 was
released on 26 August 2026. So the repository accepts one minor line and takes
its patches. The floor, 1.16.6, is the version in the image, so nobody
runs an older patch locally than the pipeline runs. A move to 1.17 is a
deliberate change, after its general release.

## Why `~> 8.7` for the Google providers

The Google providers release a minor version about every week. A constraint of
`~> 8.7.0` would need a pull request to change `versions.tf` every week.
`~> 8.7` accepts every 8.x minor and leaves the lock file as the gate: nothing
changes until a reviewed pull request updates the lock. The trade-off is that
the constraint alone no longer tells you the exact version. The lock file does.

## How the image is built and updated

Platform Engineering builds the image with Cloud Build in the project
`gcp-cicd-template`, as the service account `runtime-image-builder`. That
account is the only one that can write to the `terraform-runtime` repository,
so no other identity can publish an image there.

The Dockerfile pins each tool's version and downloads it. The build fails
unless the download's SHA256 matches the value pinned from the vendor's
checksums file. A changed or corrupted download therefore stops the build
rather than reaching the image.

The image sets `TRIVY_SKIP_CHECK_UPDATE=true`, so Trivy scans with the checks
shipped inside the image and never downloads newer ones during a build. The
same image gives the same scan results every time. New checks arrive only with
a new image.

A new digest reaches teams as a template change to both `cloudbuild/*.yaml`
files. Dependabot does not update it. Each repository takes the change in its
own pull request; see [Update Terraform](../how-to/update-terraform.md) and
[About the GitHub template model](template-model.md#how-template-changes-reach-existing-repositories).
Repositories keep the old image until they choose to move, so one bad image
cannot break every pipeline at once.

## Why not a registry in each project

Each project could build and host its own image. That means as many image
builds, scans and update cycles as there are projects, and no single approved
version. A central repository with read grants keeps one reviewed build. The
cost is a dependency: every project needs read access to the central
repository, granted once by Platform Engineering. Bootstrap's smoke build proves
that grant works before the first real build.

Google shut down Container Registry on 18 March 2025, so Artifact Registry is
the place to host it.

## Sources

Checked 18 October 2026:

- [Terraform v1.x compatibility promises](https://developer.hashicorp.com/terraform/language/v1-compatibility-promises)
- [Terraform releases API](https://api.releases.hashicorp.com/v1/releases/terraform)
- [Google provider on the Terraform Registry](https://registry.terraform.io/v1/providers/hashicorp/google)
- [Artifact Registry image names](https://docs.cloud.google.com/artifact-registry/docs/docker/names)
- [Transition from Container Registry](https://docs.cloud.google.com/container-registry/docs/deprecations/container-registry-deprecation)

## Related

- [Versions](../reference/versions.md)
- [Update Terraform](../how-to/update-terraform.md)
- [Update the Google provider](../how-to/update-the-google-provider.md)
- Back to the [documentation index](../../README.md#documentation)
