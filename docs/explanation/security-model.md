# About the security model

This page explains which threats the template is built against, which control
answers each one, and what is left over. It assumes you know the
[architecture](architecture.md).

## The core idea

The trust boundary is the build identity, not the build file. Cloud Build reads
`cloudbuild/ci.yaml` from the pull request's own commit, so whoever writes a
pull request controls the steps that run on it. What they cannot control is the
identity those steps run as. So the template makes the pull-request identity
unable to change anything, and gives write access only to the identity that
runs from `main`.

## Threats and controls

| Threat | Controls | What is left |
|---|---|---|
| A pull request runs hostile code in CI | Someone without write access needs a writer to comment `/gcbrun`. The CI identity has `roles/viewer` and read-only state access. Its plan runs with `-lock=false`, so it cannot hold the lock. | It can read what `roles/viewer` can read, and the state, which can hold sensitive values. |
| A change reaches `main` without review | The `main - protected` ruleset requires a pull request, an approval of the last push by someone else, code owner review and the Cloud Build check. Code owners cover `cloudbuild/`, `cicd/`, `scripts/` and `.github/`. | GitHub Free enforces none of this on private repositories. |
| The pipeline widens its own access | Only bootstrap, run by a person, applies `cicd/`. Neither identity holds IAM, trigger or service account admin roles. `deploy.roles` rejects `roles/owner` and `roles/editor`. | Roles in `deploy.roles` can be broad. `environments/` has no code owner. |
| A long-lived credential leaks | No service account keys. Builds run as attached identities. The GitHub token stays in Secret Manager in the project. People use their own `gcloud` sign-in. Bootstrap turns on secret scanning and push protection where GitHub allows it. | The GitHub token can read every repository the app installation can see, and belongs to the person who authorised it; it stops working if they leave. Private repositories on GitHub Free get no secret scanning. |
| The build tools change under you | The image is pinned by digest, and pre-flight fails without one. Lock files pin provider hashes, and every `init` uses `-lockfile=readonly`. | The image is as trustworthy as its build. |
| Insecure infrastructure is merged | Trivy scans the code at `HIGH,CRITICAL` on every build, and scans the plan again before `apply`. TFLint runs with the Google ruleset. | Scanners only find what their checks describe. |
| An accidental production change | Approval is on by default for `prod` and `production`. Only listed approvers get the approver role. | Every deploy trigger starts on the same merge. Approvers must check the earlier environment first. |
| State is lost or corrupted | Versioned bucket, old versions kept 90 days, `prevent_destroy`, public access prevention, uniform access, native locking. | Restoring an old version is a manual task. |

## Untrusted pull requests

The pull-request trigger uses `COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY`.
Authors with write access get builds automatically; anyone else waits for a
writer's `/gcbrun` comment. That keeps outsiders from spending your build
minutes and reading your project. It is not a strong gate on its own: Google
fixed an authorisation flaw in comment control, CVE-2026-19410, on 24 August
2026. The read-only CI identity is what limits the damage if comment control
fails.

Planning with `-lock=false` is a deliberate trade. A plan without the lock can
race with a deployment and show a stale result. In return, the CI identity
needs no write access at all, and no pull request can block a deployment by
holding the lock.

## Main, code owners and GitHub Free

The repository ruleset and `.github/CODEOWNERS` are the GitHub half of the
model. On GitHub Free they only take effect in public repositories:

| Feature | Public repository | Private repository |
|---|---|---|
| Rulesets and branch protection | Enforced | Not available |
| Required code owner review | Enforced | Not available |
| Required status checks | Enforced | Not available; the check is advisory |
| Secret scanning and push protection | Yes | Not available |
| Dependabot alerts and version updates | Yes | Yes |

On a private repository, anyone with write access can push to `main`, and the
push deploys. There, Cloud Build approval is the only gate that GitHub cannot
bypass, which is one reason it defaults to on for production. The other options
are a public repository or a paid GitHub plan. The tutorial and onboarding guide
use public repositories for this reason.

Dependabot cannot raise security alerts for Terraform providers on any plan:
the GitHub Advisory Database has no Terraform ecosystem.

## No long-lived keys

Nothing in the template creates or reads a service account key. The builds
authenticate as their trigger's identity. The person running bootstrap uses
their own application-default credentials. GitHub talks to Google through the
Developer Connect app, whose token Google stores. There is no workload identity
federation to configure, because no GitHub-hosted runner ever calls Google.

## The project-wide Developer Connect role

Both identities hold `roles/developerconnect.readTokenAccessor` on the project.
Two facts make this a caveat:

- It is a Beta role.
- It cannot be narrowed to one repository link. Developer Connect links have no
  IAM methods, and IAM Conditions do not list Developer Connect.

In a project with several links, any build identity could fetch a read token for
any linked repository. The template avoids that by giving each project exactly
one link. Cloud Build repositories (2nd gen) would allow connection-level IAM,
but still not per repository.

## Build logs

Logs go to Cloud Logging in the project, readable by people with
`roles/logging.viewer`. The triggers do not publish logs to GitHub, so a
plan's output is not visible to everyone who can read the repository.

## Sources

Checked 18 October 2026:

- [Cloud Build release notes](https://docs.cloud.google.com/build/docs/release-notes) (CVE-2026-19410, 24 August 2026)
- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [About secret scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning)
- [About the GitHub Advisory Database](https://docs.github.com/en/code-security/security-advisories/working-with-global-security-advisories-from-the-github-advisory-database/about-the-github-advisory-database)
- [Developer Connect IAM roles](https://docs.cloud.google.com/iam/docs/roles-permissions/developerconnect)
- [IAM Conditions resource attributes](https://docs.cloud.google.com/iam/docs/conditions-resource-attributes)

## Related

- [IAM](../reference/iam.md)
- [Set up the organisation](../how-to/set-up-the-organisation.md)
- [Design decisions](design-decisions.md)
- Back to the [documentation index](../../README.md#documentation)
