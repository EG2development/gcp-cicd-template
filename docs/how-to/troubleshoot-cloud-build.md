# How to troubleshoot Cloud Build

Use this guide when a pull-request check or a deployment fails, or when a build
does not start. For permission errors, see [Troubleshoot IAM](troubleshoot-iam.md).

## Read the FAIL line first

Every build step prints one line that starts with `FAIL <step>:` and says what
to do. The `preflight` step prints `FAIL  <check>` followed by `Why:` and `Fix:`
lines. Fix the first failure first; later ones are often caused by it.

## Find the build and its log

```bash
gcloud builds list --project PROJECT_ID --region REGION --limit 5
gcloud builds log BUILD_ID --project PROJECT_ID --region REGION | grep -n FAIL
```

Take `BUILD_ID` from the `ID` column. To find the newest failed build:

```bash
gcloud builds list --project PROJECT_ID --region REGION --filter='status=FAILURE' --limit 1
```

Reading logs needs `roles/logging.viewer` or a role that contains it, such as
Owner.

## Fix a failed step

`ci.yaml` runs on pull requests. `deploy.yaml` runs on merges to `main`.
[Build stages](../reference/build-stages.md) lists every step in full.

| Step | Build | FAIL line | What to do |
|---|---|---|---|
| `preflight` | both | `FAIL  <check> ...` | See [Pre-flight failures in Cloud Build](#pre-flight-failures-in-cloud-build). |
| `fmt` | ci | `FAIL fmt: run 'terraform fmt -recursive' and push the result.` | Run `terraform fmt -recursive`, commit, push. |
| `fmt` | deploy | `FAIL fmt: main is not formatted; ...` | Something reached `main` without the pull-request check. Fix it in a pull request. |
| `init` | ci | `FAIL init: check .terraform.lock.hcl matches versions.tf ...` | [Refresh the lock file](refresh-the-lock-file.md). |
| `init` | deploy | `FAIL init: check state bucket access ... and the lock file.` | Check the lock file, then [state bucket access](troubleshoot-iam.md). |
| `validate` | both | `FAIL validate: fix the errors above ...` | Run `terraform validate` locally. In `ci.yaml` this step also validates `cicd/`. |
| `tflint` | both | `FAIL tflint: fix the findings above ...` | Run `tflint --init && tflint --recursive` locally. |
| `security` | both | `FAIL security: fix the HIGH or CRITICAL findings above ...` | See [Security findings](#security-findings). |
| `test` | both | `FAIL test: a test in tests/ failed; ...` | Run `terraform test` locally. |
| `plan` | ci | `FAIL plan: read the error above; missing read access is in ...` | Read the Terraform error. For `403` or permission errors, see [Troubleshoot IAM](troubleshoot-iam.md#a-pull-request-plan-fails-with-permission-denied). |
| `plan` | deploy | `FAIL plan: ... a missing role goes in deploy.roles ...` | [Add the role to `deploy.roles`](troubleshoot-iam.md#a-deployment-fails-with-error-403). |
| `policy` | deploy | `FAIL policy: the planned change breaks a HIGH or CRITICAL check; nothing was applied.` | See [Security findings](#security-findings). |
| `apply` | deploy | `FAIL apply: some or all changes were not applied. An Error 403 means the deploy identity needs a role: ...` | For `Error 403`, see [Troubleshoot IAM](troubleshoot-iam.md#a-deployment-fails-with-error-403). Otherwise, [Recover a failed deployment](recover-a-failed-deployment.md). |
| `post` | deploy | `FAIL post: the plan after apply is not empty, ...` | Something changed outside Terraform, or a resource is not stable. Run a [local plan](run-terraform-locally.md) and fix the drift in a pull request. |

## Pre-flight failures in Cloud Build

| FAIL line | What to do |
|---|---|
| `FAIL  Terraform version    image has X, .terraform-version says Y` | Make them agree. See [Update Terraform](update-terraform.md). |
| `FAIL  Configuration        environments/ENV.yaml says P/R, the trigger says P2/R2` | The file changed after bootstrap. Run `./scripts/bootstrap.sh ENV`, then push a new commit to re-run the build. |
| `FAIL  Terraform image      TOOL is missing from the image` | Ask Platform Engineering to check the approved image. |
| `FAIL  Provider lock file   ...` or `FAIL  Google provider      ...` | [Refresh the lock file](refresh-the-lock-file.md). |

## Security findings

The `security` step runs Trivy on the code. The deploy build's `policy` step
runs Trivy again on the plan. Run the same scans locally:

```bash
trivy config --severity HIGH,CRITICAL .
terraform plan -lock=false -out=tfplan && terraform show -json tfplan > tfplan.json
trivy config --severity HIGH,CRITICAL tfplan.json
```

The plan needs an initialised backend; see
[Run Terraform locally](run-terraform-locally.md). The image runs Trivy 0.76.0.
An older local Trivy can report different findings.

Fix each finding in your Terraform. If you think a finding is wrong, ask
Platform Engineering before you change the scan.

## Connection

Bootstrap stops here with `could not create the Developer Connect connection`
or `the GitHub connection is still STAGE after 15 minutes`. Check the stage:

```bash
gcloud developer-connect connections describe github --project PROJECT_ID --location REGION \
  --format="value(installationState.stage,installationState.message)"
```

| Stage | Meaning (Developer Connect API) | What to do |
|---|---|---|
| `PENDING_USER_OAUTH` | "User needs to authorize the GitHub (or Enterprise) App via OAuth." | Open the link bootstrap printed, select **Authorize**, then re-run bootstrap. |
| `PENDING_INSTALL_APP` | "User needs to follow the link to install the GitHub (or Enterprise) App." | The app is not installed on the organisation. Ask Platform Engineering; see [Set up the organisation](set-up-the-organisation.md). Do not install it yourself from a search. |
| `PENDING_CREATE_APP` | "Only for GitHub Enterprise." | Not expected here. Ask Platform Engineering. |
| `COMPLETE` | "Installation process has been completed." | The connection works. Look at the error above the `FAIL` line. |

Source: [Developer Connect REST: connections](https://docs.cloud.google.com/developer-connect/docs/api/reference/rest/v1/projects.locations.connections),
updated 6 February 2026.

To print the authorisation link again:

```bash
gcloud developer-connect connections describe github --project PROJECT_ID --location REGION \
  --format="value(installationState.actionUri)"
```

### The connection could not be created

Read the Terraform error above the `FAIL` line. If it is a permission error,
pre-flight on a re-run shows
`FAIL  IAM                  missing developerconnect.connections.create`.
Ask a project owner for `roles/developerconnect.admin`, then re-run bootstrap.

### The app cannot see the repository

The `Apply cicd/` step stops with:

```text
FAIL  the Developer Connect GitHub App cannot see EG2development/my-service
      Fix: the connection uses the app installation at INSTALLATION_URI, which must be on EG2development
      with access to this repository, not on a personal account. See docs/how-to/troubleshoot-cloud-build.md#connection
```

Look at the installation address in the `Fix:` line:

| Address | Meaning | What to do |
|---|---|---|
| `https://github.com/settings/installations/ID` | A personal installation. Someone chose a personal account in the browser. | Check that `github_app_installation_id` in `cicd/variables.tf` is the organisation's installation, then re-run bootstrap. The next apply points the connection back at it. |
| `https://github.com/organizations/EG2development/settings/installations/ID` | The organisation's installation, without access to this repository. | Ask Platform Engineering to add the repository, or to give the app access to all repositories. Then re-run bootstrap. |

### Error 400 about PENDING_INSTALL_APP

If the connection step fails with
`To reach the PENDING_INSTALL_APP stage, the following fields must be provided: app_installation_id, authorizer_credential.`,
the repository has a template version from before 19 October 2026. Developer
Connect rejects a new connection that names an installation before anyone has
authorised it. Take the template's fix to `cicd/github.tf`, `cicd/variables.tf`
and `scripts/bootstrap.sh`, as described in
[About the GitHub template model](../explanation/template-model.md#how-template-changes-reach-existing-repositories),
then re-run bootstrap.

### The wrong GitHub account authorised it

The connection uses the token of the account that authorised it. If that person
leaves the organisation, the connection stops working. Google recommends a
robot account rather than a person's account. To see which account it is:

```bash
gcloud developer-connect connections describe github --project PROJECT_ID --location REGION \
  --format="value(githubConfig.authorizerCredential.username)"
```

No procedure to re-authorise a connection with a different account is
documented here. Bootstrap ignores later changes to the credential
(`ignore_changes` in `cicd/github.tf`). Ask Platform Engineering. This has not
been tested.

## A pull request from someone without write access

The pull-request trigger builds automatically when the author has write access
to the repository. For anyone else, the build waits until someone with write
access comments `/gcbrun` on the pull request.

Read the change before you comment. The pull request's own
`cloudbuild/ci.yaml` and Terraform code run as the CI identity. That identity
cannot change anything, but it can read the project and the state.

## The check does not appear

Work through these in order:

1. The pull request targets `main`. The trigger only matches `^main$`.
2. The author has write access, or someone has commented `/gcbrun`.
3. The triggers exist. `./scripts/preflight.sh ENV` shows `PASS  Cloud Build`,
   not `INFO  Cloud Build          triggers not created yet; ...`.
4. The connection is `COMPLETE`. See [Connection](#connection).
5. The Developer Connect app can see the repository. See
   [The app cannot see the repository](#the-app-cannot-see-the-repository).

If `gcloud builds list` shows a build but GitHub shows no check, compare the
check runs on the commit:

```bash
gh api repos/EG2development/REPOSITORY/commits/COMMIT_SHA/check-runs --jq '.check_runs[] | {name, app_id: .app.id}'
```

The check should be named `ENV-ci (PROJECT_ID)` with app ID `865529`, the
Google Cloud Developer Connect app; both pilots confirmed this. The ruleset
requires that name from that app (`DEVELOPER_CONNECT_APP_ID` in
`scripts/bootstrap.sh`). If either differs, GitHub keeps waiting. Tell Platform
Engineering.

## The merge is blocked

GitHub refuses the merge and says the base branch policy prohibits it. The
`main - protected` ruleset needs an approval from someone other than the
author, and every required check to pass. Ask a teammate to review the pull
request. Organisation owners can bypass the ruleset through the pull request,
which the pilots did because no second person was available.

## A deployment waits for approval

With approval on, the deploy build waits as pending until someone approves it.
Approvers need `roles/cloudbuild.builds.approver`, granted through
`deploy.approvers`.

```bash
gcloud alpha builds approve BUILD_ID --location REGION --project PROJECT_ID
```

Or approve it on the Cloud Build History page in the Google Cloud console. Only
the alpha command works; see
[Add an environment](add-an-environment.md#approve-a-deployment). Builds pending
for more than two months cannot be approved.

## A build times out

`ci.yaml` stops after 1200 seconds and `deploy.yaml` after 3600 seconds. Find
the slow step in the log. Changing a timeout means changing `cloudbuild/`, which
Platform Engineering reviews.

## Related

- [Build stages](../reference/build-stages.md)
- [Triggers](../reference/triggers.md)
- [About the architecture](../explanation/architecture.md)
- Back to the [documentation index](../../README.md#documentation)
