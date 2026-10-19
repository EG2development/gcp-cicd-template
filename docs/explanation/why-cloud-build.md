# About the choice of Cloud Build

The template runs its pipelines in Cloud Build, started by GitHub events through
Developer Connect. It does not use GitHub Actions. This page explains why, and
where Actions could still help.

## Where the identity lives

A pipeline that deploys to GCP needs a GCP identity. The question is where that
identity starts.

With GitHub Actions, the job runs on GitHub's runners. To reach GCP, the job
presents a GitHub OIDC token, and GCP exchanges it for access through workload
identity federation. Someone has to create the identity pool and provider,
write attribute conditions that admit only the right repository and branch,
and keep those conditions correct as repositories change. A mistake in a
condition can let another repository deploy. Google's guide to federation for
deployment pipelines covers GitHub Actions, GitLab, Azure DevOps and HCP
Terraform.

With Cloud Build, the build runs inside the project, as a service account in
that project. There is no token exchange and no federation to configure. The
trigger names its service account, and that account is the build's only
identity. Build history and logs sit in the same project as the resources they
change, so the audit trail is in one place.

## Cloud Build is managed by Terraform here

Everything about the pipeline is Terraform in `cicd/`: the Developer Connect
connection, the repository link, both triggers, their identities and the
approval setting. These resources are in the stable Google provider. Developer
Connect has been generally available since 30 September 2024, and Cloud Build
triggers that use it since 29 September 2025, including through Terraform.

The deployment approval is native too. Cloud Build holds the build before it
starts until an approver releases it. In GitHub, the equivalent gate would rely
on GitHub-side protection, which GitHub Free does not enforce in private
repositories.

## Why Developer Connect, of Cloud Build's GitHub options

Cloud Build offers three ways to connect to GitHub:

- **Repositories (1st gen)** are superseded and kept as a legacy option. Their
  mirrored variant needs Cloud Source Repositories, which projects without an
  organisation can no longer enable.
- **Repositories (2nd gen)** are generally available and supported. They are the
  only option with manual, Pub/Sub and webhook triggers, and they allow IAM on
  a connection. Their documented Terraform path uses a classic personal access
  token with `repo` scope; Cloud Build does not support fine-grained tokens.
- **Developer Connect** is the newest path. Its credential is an OAuth token
  tied to the GitHub App, not a personal token, and its resources are in the
  stable provider.

Google does not name one of these as the recommendation. The template chose
Developer Connect for the credential model and the Terraform support. The cost
is the missing trigger types; see
[Design decisions](design-decisions.md#known-limitations).

## Where GitHub Actions would add value

Actions could run small checks that need no cloud credentials, such as a pull
request title lint, `terraform fmt` and `validate` without a backend, or a
release tool. Those would give fast feedback on GitHub without any GCP access.

The template does not use them, for three reasons:

- Cloud Build already runs `fmt`, `validate`, TFLint, Trivy and the tests on
  every pull request. A second system would split results across two places.
- Running plan or apply in Actions as well would add a second cloud identity,
  through federation, and split the audit trail.
- Workflow files in a template also run on the template repository itself, so
  each one needs a guard against running there.

Dependabot needs no workflow, so it still runs.

## What Cloud Build costs in flexibility

- Developer Connect triggers have no manual, Pub/Sub or webhook types. Google
  does not document re-running a push trigger by hand, although
  `gcloud builds triggers run` worked in the pilot.
- The GA `gcloud builds triggers create` has no Developer Connect form; only the
  alpha and beta tracks do. The template creates triggers in Terraform, so this
  does not affect it, but it limits ad hoc work from the command line.
- Which GitHub App posts the pull-request check is not documented. The pilots
  confirmed it from real check runs, but a change on Google's side would leave
  the ruleset waiting.
- Approving a build from the command line needs the alpha `gcloud` track.

## Sources

Checked 18 October 2026:

- [Cloud Build release notes](https://docs.cloud.google.com/build/docs/release-notes)
- [Developer Connect release notes](https://docs.cloud.google.com/developer-connect/docs/release-notes)
- [Cloud Build repositories overview](https://docs.cloud.google.com/build/docs/repositories)
- [Connect to GitHub (2nd gen)](https://docs.cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen)
- [Workload identity federation with deployment pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
- [Gate builds on approval](https://docs.cloud.google.com/build/docs/securing-builds/gate-builds-on-approval)

## Related

- [About the CI/CD architecture](architecture.md)
- [About the security model](security-model.md)
- Back to the [documentation index](../../README.md#documentation)
