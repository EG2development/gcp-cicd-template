# About the CI/CD architecture

This page explains how a change travels from GitHub into a GCP project, who is
trusted at each step, and why the pipeline can never change its own setup.

## The trust path

```text
GitHub repository  EG2development/my-service
  │  pull request to main, or push to main
  ▼
Developer Connect GitHub App   installed once on the organisation
  │  OAuth token from one browser authorisation, kept in Secret Manager
  ▼
Developer Connect connection "github"     one per project and region
  └─ repository link "my-service"          one per repository
  │
  ▼
Cloud Build triggers, in the project's region
  ├─ <env>-ci      cloudbuild/ci.yaml      runs as tf-ci-<env>      read-only
  └─ <env>-deploy  cloudbuild/deploy.yaml  runs as tf-deploy-<env>  approval for prod
  │
  ▼
Terraform, inside the approved image pulled by digest from the central registry
  │
  ▼
The project's resources, and its state in gs://<project>-tfstate
```

Every box below GitHub lives in the environment's own project, except the
central image. Each environment is a separate copy of this path.

## GitHub to Developer Connect

GitHub only lets an installed app see a repository. Platform Engineering
installs Google's Developer Connect app on the organisation once. After that,
each project needs one person to authorise the app in a browser. Developer
Connect stores the resulting token in Secret Manager in that project, through
its service agent.

That browser step is the one manual action in onboarding. Google's API can
reuse the token stored by another connection instead. That would make every
project depend on a secret in one other project, and its service agent would
need access to it. The template keeps the browser step and makes it a link
that bootstrap prints and waits for. The link opens the Developer Connect
finish-setup page in the Google Cloud console and then GitHub's **Authorize**
page; nothing is configured in the console.

The connection is created in two passes. Developer Connect rejects a new
connection that names an app installation before anyone has authorised it. So
bootstrap first creates the connection without one, waits for the browser
step, and then lets the full apply set the organisation's installation. That
apply also corrects the connection if someone picked a personal account in the
browser, because the installation stays under Terraform's control.

## One connection per project, one link per repository

Developer Connect connections and repository links belong to a project and a
region. No Google page documents a trigger in one project using a link from
another. So each project gets its own connection, named `github`, and one link
for its repository. All the connections reuse the same organisation
installation.

This shape matters for security. The build identities need
`roles/developerconnect.readTokenAccessor` to clone. Google offers no way to
grant it on a single link: links have no IAM, and IAM Conditions do not support
Developer Connect. Granted on a project that holds only one link, it exposes
only that repository.

## Triggers and identities

A Cloud Build build runs as the service account attached to its trigger, and
that account is the only identity in the build. The template uses that fact
directly. Pull requests and merges use different triggers, so they use
different identities:

- `tf-ci-<env>` can read the project and the state, and nothing more.
- `tf-deploy-<env>` can write state and holds the roles in `deploy.roles`.

Neither can act as the other. There is no impersonation inside a build, so
there is no token exchange to get wrong. Google does support switching identity
inside one build, but a second trigger gives the same separation with less to
configure.

## The approved image

Every step runs in one Terraform image from a central Artifact Registry
repository, pinned by digest. The project's build identities only need read
access to it. [About the approved Terraform image](terraform-image.md) covers
why.

## Why a person applies cicd/

`cicd/` creates the identities, their IAM, the connection, the link and the
triggers. Bootstrap applies it, as the person who runs it. Cloud Build never
does.

The first reason is order. The pipeline cannot create the triggers that start
it, or the state bucket that holds its own state.

The second reason is more important. If the pipeline could apply `cicd/`, a
merged change could give the deploy identity more roles, or point a trigger at
a different file. The pipeline would be able to widen its own power. Keeping
`cicd/` out of the pipeline means every change to identities, IAM or triggers
needs someone with IAM admin rights on the project to run bootstrap. Code
owners also review `cicd/`, `cloudbuild/`, `scripts/` and `.github/`.

The cost is a manual step. Adding a role to `deploy.roles` does nothing until
someone re-runs bootstrap. The `preflight` step in every build catches the
most likely drift: a changed project or region that the triggers do not know
about yet.

## Alternatives

A central platform project could own the triggers and identities for every
repository. Cross-project build service accounts need a GCP organisation,
though, and the projects here may have none. It would also put every project's
deploy rights in one place. A per-project copy keeps the blast radius to one
project.

GitHub Actions could run the same steps. [About the choice of Cloud
Build](why-cloud-build.md) explains why it does not.

## Sources

Checked 18 October 2026:

- [Developer Connect: connect to GitHub](https://docs.cloud.google.com/developer-connect/docs/connect-github-repo)
- [Developer Connect IAM roles](https://docs.cloud.google.com/iam/docs/roles-permissions/developerconnect)
- [Service account impersonation](https://docs.cloud.google.com/iam/docs/service-account-impersonation)
- [Configure user-specified service accounts](https://docs.cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts)

## Related

- [Triggers](../reference/triggers.md)
- [Service accounts](../reference/service-accounts.md)
- [About the security model](security-model.md)
- Back to the [documentation index](../../README.md#documentation)
