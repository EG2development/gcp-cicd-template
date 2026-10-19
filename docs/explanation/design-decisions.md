# About the design decisions

This page records why the template looks the way it does: how each option from
the October 2026 research was classified, what was left out on purpose, and
the limits that remain. The research was checked against official sources on
18 October 2026. Dates in the table are the sources' own.

## How the research was classified

| Item | Class | Date | Used | Source |
|---|---|---|---|---|
| Developer Connect connection, repository link and triggers | Current, recommended for this design | GA 30 Sep 2024; triggers GA, with Terraform, 29 Sep 2025 | Yes | [Cloud Build release notes](https://docs.cloud.google.com/build/docs/release-notes) |
| A user-specified service account on every trigger | Current, recommended by Google | | Yes | [Default Cloud Build service account](https://docs.cloud.google.com/build/docs/cloud-build-service-account) |
| `CLOUD_LOGGING_ONLY` with `roles/logging.logWriter` | Current | | Yes | [User-specified service accounts](https://docs.cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts) |
| Build approval (`approval_config`) | Current, GA | | Yes | [Gate builds on approval](https://docs.cloud.google.com/build/docs/securing-builds/gate-builds-on-approval) |
| Artifact Registry image pinned by digest | Current | | Yes | [Image names](https://docs.cloud.google.com/artifact-registry/docs/docker/names) |
| Log-based alert policy (no build-status metric exists) | Current | | Yes | [Log-based alerts](https://docs.cloud.google.com/logging/docs/alerting/log-based-alerts) |
| Secret Manager API enabled explicitly | Required since Developer Connect stopped enabling it | 22 Sep 2026 | Yes | [Developer Connect release notes](https://docs.cloud.google.com/developer-connect/docs/release-notes) |
| GCS backend, native locking, versioned bucket | Current, unchanged | | Yes | [GCS backend](https://developer.hashicorp.com/terraform/language/backend/gcs) |
| `terraform test` with `mock_provider` | Current, GA | | Yes | [Tests](https://developer.hashicorp.com/terraform/language/tests) |
| Terraform 1.16.6 | Current | 14 Oct 2026 | Yes | [Releases](https://releases.hashicorp.com/terraform/1.16.6/) |
| `hashicorp/google` and `google-beta` 8.7.0 | Current | 13 Oct 2026 | Yes | [Registry](https://registry.terraform.io/v1/providers/hashicorp/google) |
| Trivy 0.76.0 | Current | 14 Oct 2026 | Yes | [Release](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0) |
| TFLint 0.64.0, tflint-ruleset-google 0.40.0 | Current | 17 Jul 2026; 23 Sep 2026 | Yes | [TFLint release](https://github.com/terraform-linters/tflint/releases/tag/v0.64.0) |
| Lock files for four platforms | Current, recommended | | Yes | [`providers lock`](https://developer.hashicorp.com/terraform/cli/commands/providers/lock) |
| Cloud Build repositories, 1st gen | Legacy: superseded, no end date announced | | No | [Repositories overview](https://docs.cloud.google.com/build/docs/repositories) |
| Cloud Build legacy service account | Legacy; not offered to projects without an organisation | May to Jun 2024 | No | [Service account changes](https://docs.cloud.google.com/build/docs/cloud-build-service-account-updates) |
| tfsec | Legacy: superseded by Trivy | Last release 2 May 2025 | No | [tfsec README](https://github.com/aquasecurity/tfsec) |
| Terraform 1.15 and earlier; Google provider 7.x and earlier | Legacy | Last 1.15 patch 19 Aug 2026; provider 8.0.0 on 26 Aug 2026 | No | [Releases API](https://api.releases.hashicorp.com/v1/releases/terraform) |
| Container Registry | Deprecated: shut down | 18 Mar 2025 | No | [Transition from Container Registry](https://docs.cloud.google.com/container-registry/docs/deprecations/container-registry-deprecation) |
| Triggers through Cloud Source Repositories mirroring | Deprecated: closed to new customers | 17 Jun 2024 | No | [Triggers overview](https://docs.cloud.google.com/build/docs/triggers) |
| Service Account User toggle on the Cloud Build permissions page | Removed | 9 Oct 2025 | No | [Cloud Build release notes](https://docs.cloud.google.com/build/docs/release-notes) |
| `google_project_service_identity` | Beta: only in `google-beta` 8.7.0 | | Yes, one resource | [Provider docs v8.7.0](https://github.com/hashicorp/terraform-provider-google/tree/v8.7.0/website/docs/r) |
| `roles/developerconnect.readTokenAccessor` | Beta role | | Yes | [Developer Connect roles](https://docs.cloud.google.com/iam/docs/roles-permissions/developerconnect) |
| `gcloud builds approve`; Developer Connect form of `gcloud builds triggers create` | Alpha and beta tracks only; only the alpha `approve` worked in the pilot | Reference of 27 May 2026; pilot 19 Oct 2026 | Alpha `approve` | [gcloud alpha builds approve](https://docs.cloud.google.com/sdk/gcloud/reference/alpha/builds/approve) |
| Terraform 1.17.0-rc2 | Pre-release | 14 Oct 2026 | No | [Release](https://github.com/hashicorp/terraform/releases/tag/v1.17.0-rc2) |
| Cloud Build repositories, 2nd gen | Supported, GA 20 Jul 2023; unnecessary here | | No | [Repositories overview](https://docs.cloud.google.com/build/docs/repositories) |
| Private pools | Unnecessary: no private networking needed | | No | [Private pools](https://docs.cloud.google.com/build/docs/private-pools/private-pools-overview) |
| Workload identity federation | Unnecessary: no GitHub runner calls GCP | | No | [Federation for pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines) |
| Pub/Sub build notifications and notifiers | Unnecessary for a first version | | No | [Build notifications](https://docs.cloud.google.com/build/docs/subscribe-build-notifications) |
| Developer Connect Git proxy, account connectors, insights | Unnecessary | GA 18 Apr 2025; 1 Sep 2026; 14 Aug 2026 | No | [Developer Connect release notes](https://docs.cloud.google.com/developer-connect/docs/release-notes) |
| Worker release channels (`options.workerRelease`) | Optional; the default moves from legacy to `regular` after 28 Mar 2027 | 12 Oct 2026 | No | [Release channels](https://docs.cloud.google.com/build/docs/release-channels) |
| Checkov 3.3.29 | Current; unnecessary alongside Trivy | 13 Oct 2026 | No | [Release](https://github.com/bridgecrewio/checkov/releases/tag/3.3.29) |

## Things deliberately not implemented

- **Private pools.** They exist for builds that need private networking. The
  default regional pool is enough to run Terraform against public Google APIs.
- **GitHub Actions.** Cloud Build already runs every check, and Actions would
  add a second identity and a second place to look. See
  [About the choice of Cloud Build](why-cloud-build.md).
- **Workload identity federation.** It is how a GitHub-hosted job reaches GCP.
  Here, no GitHub-hosted job does.
- **Service account impersonation.** Two triggers with two identities give the
  separation between plan and apply without granting token creation.
- **Organisation rulesets.** Not available on GitHub Free, and they could not
  name a check that includes each repository's project ID.
- **Policy engines such as OPA.** Trivy already blocks HIGH and CRITICAL
  findings on the code and on the plan. A policy language is another thing to
  write, test and maintain.
- **Terragrunt.** Each repository has one Terraform root and selects its
  environment with `var.environment`. Terragrunt would add a tool and a layer
  without removing anything.
- **Cloud Build repositories (2nd gen).** Supported, but its Terraform path
  relies on a classic personal access token. Developer Connect ties the
  credential to the GitHub App.
- **A central multi-repository platform.** Cross-project build identities need
  a GCP organisation, and a central project would hold every project's deploy
  rights. See [About the CI/CD architecture](architecture.md).
- **Tag or release triggers.** A merge to `main` is the release. Nothing needs a
  second event.
- **Secret Manager secrets for the workload.** The empty template needs none.
  When a workload does, grant `roles/secretmanager.secretAccessor` on each
  secret to the deploy identity only, and set secret values with the provider's
  write-only `secret_data_wo` (with `secret_data_wo_version`) so they never
  reach state.
- **Pub/Sub build notifications.** Accurate build status, but it needs a topic
  and a subscriber service. A log-based alert on deploy failures needs neither.
- **Publishing build logs to GitHub.** Logs would become readable by anyone who
  can read the repository.

## Known limitations

Pilot results are from two pilots on 18 and 19 October 2026.

1. **GitHub Free.** Rulesets, branch protection and required code owner review
   apply to public repositories only. On a private repository, the Cloud Build
   check is advisory, anyone with write access can push to `main`, and Cloud
   Build approval is the only enforced gate.
2. **Dependabot and Terraform 1.16.** Dependabot documents Terraform support
   for `>= 0.13, <= 1.15.x`, and this repository requires `~> 1.16.6`. In the
   pilot, Dependabot opened no pull requests on the template or the pilot
   repositories in about 10 hours. Both providers were already at the latest
   version, 8.7.0, so this neither confirms nor rules out support. GitHub
   returned 404 for the dependency graph SBOM on these repositories.
3. **The required check's app.** Google does not document which GitHub App posts
   the check for Developer Connect triggers. Both pilots showed
   `dev-ci (PROJECT_ID)` from `google-cloud-developer-connect`, ID `865529`,
   which is what the ruleset requires. If Google ever changes the app, GitHub
   waits for a check that never arrives.
4. **The Developer Connect role.** `roles/developerconnect.readTokenAccessor` is
   a Beta role, granted on the whole project because links have no IAM. One link
   per project keeps the exposure to one repository. Google's pages do not
   state the role is required. The template keeps it; the pilots did not
   re-test without it.
5. **A beta provider resource.** `google_project_service_identity` exists only
   in `google-beta` 8.7.0, so `cicd/` depends on that provider for one resource.
6. **One Authorize click per project, in the console.** Each new project needs a
   person to open bootstrap's link and select **Authorize** once. The link opens
   the Developer Connect finish-setup page on `console.cloud.google.com`; this
   is the only browser step, and nothing is configured in the console. The
   connection then keeps that person's GitHub token, so it stops if they leave;
   Google recommends a robot account.
7. **Local Terraform.** Everyone who runs bootstrap or a local plan needs
   Terraform 1.16.6 or a later 1.16 patch. Pre-flight fails on anything else.
8. **Approving from the command line.** Only
   `gcloud alpha builds approve BUILD_ID --location REGION --project PROJECT_ID`
   works. The GA track has no `approve`, and in the pilot the beta command failed
   on a build's full name with `Error parsing [build]`. Alpha commands can change
   without notice; the Cloud Build History page in the console is the
   alternative.
9. **Alerts.** The deployment alert matches `FAIL ` lines, from the steps and
   from pre-flight, and Cloud Build's `ERROR: build step` text, which Google
   does not document. In the pilot, the filter matched both in a failed
   deployment's log. Email delivery and build timeouts were not tested.
   Log-based alert policies send at most 20 notifications a day.
10. **Data residency.** Developer Connect connections created through the API
    or gcloud, as Terraform does, are not data-residency compliant. Only the
    console option creates a per-connection GitHub App
    ([Connect to GitHub](https://docs.cloud.google.com/developer-connect/docs/connect-github-repo),
    checked 18 October 2026).
11. **Environments deploy together.** Every merge starts every environment's
    deploy trigger at once. There is no promotion order; approvers must check
    the earlier environment.
12. **Fixed state bucket name.** `<project>-tfstate` is fixed by design, because
    project IDs are globally unique. If another project owns the name,
    bootstrap cannot continue.
13. **Changing `project.id` leaves old triggers.** Bootstrap sets up the new
    project but never removes anything from the old one. The old project's
    triggers keep firing on pull requests and fail their pre-flight step.
    Delete them by hand.

## Related

- [About the security model](security-model.md)
- [Versions](../reference/versions.md)
- Back to the [documentation index](../../README.md#documentation)
