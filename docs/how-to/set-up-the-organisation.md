# How to set up the organisation for the template

Platform Engineering does these tasks once for the `EG2development` GitHub
organisation and the central Terraform image. They are not part of onboarding
a project. Do them before anyone follows the
[tutorial](../tutorials/create-a-repository.md).

GitHub facts on this page were checked on 18 and 19 October 2026, when
`EG2development` was on GitHub Free.

## Before you start

- You are an owner of `EG2development`.
- `gh` has the `admin:org` scope: `gh auth refresh --scopes admin:org`.
- You can change IAM on the Artifact Registry repository `terraform-runtime` in
  project `gcp-cicd-template`, for example with `roles/artifactregistry.admin`.

## Create the platform-engineering team

`.github/CODEOWNERS` names `@EG2development/platform-engineering`, and
bootstrap gives that team write access to each new repository. Code owners must
be a visible team with write access, so create it as `closed` (visible):

```bash
gh api -X POST orgs/EG2development/teams -f name=platform-engineering -f privacy=closed \
  -f description="Reviews CI/CD changes in repositories created from gcp-cicd-template"
gh api -X PUT orgs/EG2development/teams/platform-engineering/memberships/USERNAME -f role=member
```

Check it: `gh api orgs/EG2development/teams/platform-engineering --jq '{slug, privacy}'`
shows `"privacy":"closed"`. The API default is `secret`, which CODEOWNERS
cannot use.

## Install the Developer Connect GitHub App

Install the app on the organisation once, before the first bootstrap. In the
first pilot, the owner authorised with a second GitHub account, and GitHub's
installation picker installed the app on that personal account. The repository
link then failed. Installing on the organisation first avoids this.

Lookalike apps exist, for example `google-developer-connect`,
`google-developerconnect` and `gcp-developer-connect`. None of them belongs to
Google. Reach the app only through the installation page that Developer Connect
links to, never through a search.

1. From Developer Connect's installation page, go to the app's page,
   <https://github.com/apps/google-cloud-developer-connect>.
2. Check the owner before you install:

   ```bash
   gh api apps/google-cloud-developer-connect --jq '{id, owner: .owner.login}'
   ```

   It must show ID `865529` and owner `GoogleCloudDeveloperConnect`.

3. Select **Install**, choose `EG2development`, then choose **All
   repositories**. No repository then needs its own step, but the app can read
   every repository in the organisation.
4. Find the installation ID:

   ```bash
   gh api orgs/EG2development/installations --jq '.installations[] | {id, app_id, app_slug, repository_selection}'
   ```

   `EG2development`'s installation, made on 19 October 2026 for all
   repositories, is `172925456`.

5. In the template, set that ID as the default of
   `github_app_installation_id` in `cicd/variables.tf`, then merge the change:

   ```hcl
   variable "github_app_installation_id" {
     # ...
     default = 172925456
   }
   ```

   With the default set, the browser step in bootstrap only asks for
   **Authorize**. Every bootstrap also points the connection back at this
   installation, even if someone picks a personal account in the browser.

If you choose **Only select repositories** instead, add each new repository to
the installation before its bootstrap:

```bash
gh api -X PUT user/installations/INSTALLATION_ID/repositories/$(gh api repos/EG2development/REPOSITORY --jq .id)
```

### What the authorisation step shows

The link that bootstrap prints opens the Developer Connect finish-setup page in
the Google Cloud console, at `console.cloud.google.com/developer-connect/finish-setup`.
That page sends you to GitHub's OAuth **Authorize** page, and then, if GitHub
needs one, to GitHub's installation picker. Nothing is configured in the
console.

### Authorise with a machine user in production

The connection keeps the token of the GitHub account that authorised it. If that
person leaves the organisation, the connection stops working. The console's own
hint says to "log in to GitHub using a robot account". For production
organisations, authorise with a dedicated machine user that belongs to the
organisation.

### The app that posts the check

The `main` ruleset requires the pull-request check from GitHub App `865529`
(`DEVELOPER_CONNECT_APP_ID` in `scripts/bootstrap.sh`). Both pilots confirmed
it: the check `dev-ci (PROJECT_ID)` is posted by `google-cloud-developer-connect`,
ID `865529`. Merges also get a `dev-deploy (PROJECT_ID)` check on the commit on
`main`. To check a repository again:

```bash
gh api repos/EG2development/REPOSITORY/commits/COMMIT_SHA/check-runs --jq '.check_runs[] | {name, app_id: .app.id}'
```

If the app ID ever differs, change `DEVELOPER_CONNECT_APP_ID` in the template.

## Grant read access to the central Terraform image

Every build step runs the image
`europe-west2-docker.pkg.dev/gcp-cicd-template/terraform-runtime/terraform`.
Each project's build identities need `roles/artifactregistry.reader` on the
`terraform-runtime` repository. Grant it once, at the widest scope you have:

- **Projects in a GCP organisation**: grant it to all service accounts in the
  organisation.

  ```bash
  gcloud artifacts repositories add-iam-policy-binding terraform-runtime \
    --project gcp-cicd-template --location europe-west2 \
    --role roles/artifactregistry.reader \
    --member principalSet://cloudresourcemanager.googleapis.com/organizations/ORG_ID/type/ServiceAccount
  ```

  Find `ORG_ID` with `gcloud organizations list`.

- **Projects in one folder**: use
  `principalSet://cloudresourcemanager.googleapis.com/folders/FOLDER_ID/type/ServiceAccount`.
  Find `FOLDER_ID` with `gcloud resource-manager folders list --organization=ORG_ID`.

- **Projects with no organisation**: grant it per project, with the project
  number. Bootstrap prints this command when the grant is missing.

  ```bash
  gcloud artifacts repositories add-iam-policy-binding terraform-runtime \
    --project gcp-cicd-template --location europe-west2 \
    --role roles/artifactregistry.reader \
    --member principalSet://cloudresourcemanager.googleapis.com/projects/PROJECT_NUMBER/type/ServiceAccount
  ```

  Find it with `gcloud projects describe PROJECT_ID --format='value(projectNumber)'`.

These principal sets include every service account in the scope, not only the
build identities. Moving a project into or out of a folder or organisation
changes who is included
([Principal identifiers](https://docs.cloud.google.com/iam/docs/principal-identifiers),
updated 13 October 2026).

Optional: pre-flight also tries to read the image as the person who runs it,
and only warns if it cannot. To make that check pass, grant read access to a
group that contains those people:

```bash
gcloud artifacts repositories add-iam-policy-binding terraform-runtime \
  --project gcp-cicd-template --location europe-west2 \
  --role roles/artifactregistry.reader --member group:GROUP_EMAIL
```

Check the grants with
`gcloud artifacts repositories get-iam-policy terraform-runtime --project gcp-cicd-template --location europe-west2`.

## Apply the GitHub recommended security configuration

Make it the default for new repositories, and attach it to existing ones:

```bash
gh api "orgs/EG2development/code-security/configurations?target_type=global" --jq '.[] | {id, name}'
gh api -X PUT orgs/EG2development/code-security/configurations/CONFIG_ID/defaults -f default_for_new_repos=all
gh api -X POST orgs/EG2development/code-security/configurations/CONFIG_ID/attach -f scope=all
```

Use the `id` of `GitHub recommended`. On GitHub Free, secret scanning and push
protection work on public repositories only. Private repositories get the free
features, such as Dependabot alerts.

Bootstrap also turns on secret scanning and push protection for each repository
it sets up. The default configuration covers repositories that bootstrap has
not reached, and repositories that never use the template.

## Protect main on GitHub Team or Enterprise

On GitHub Free there are no organisation rulesets, and repository rulesets are
enforced on public repositories only. Bootstrap therefore writes a repository
ruleset, `main - protected`, from `.github/ruleset-main.json`:

| Rule | Setting | Why |
|---|---|---|
| Target | The default branch | `main` is what deploys. |
| Bypass | Organisation admins, through a pull request only | Owners can unblock a merge but cannot push directly. |
| `deletion` | On | Nobody can delete `main`. |
| `non_fast_forward` | On | Nobody can rewrite deployed history. |
| `required_linear_history` | On | One commit per change; reverts stay simple. |
| `pull_request` | Squash only, 1 approval, code owner review, approval of the last push, stale reviews dismissed, threads resolved | Someone other than the author approves exactly what merges. |
| `required_status_checks` | Each environment's `ENV-ci (PROJECT_ID)` check from the Developer Connect app | Nothing merges without a passing plan. |

If the organisation moves to Team or Enterprise:

- Repository rulesets also apply to private repositories.
- Create an organisation ruleset with every rule above except
  `required_status_checks`, targeting repositories created from the template.
- Keep the repository ruleset for the status checks. The check name includes
  the project ID, so an organisation ruleset cannot name it.

## Require two-factor authentication

When you require it, outside collaborators without 2FA, including bot accounts,
are removed from the organisation. Members without 2FA keep their membership
but lose access until they enable it. Check first:

```bash
gh api "orgs/EG2development/members?filter=2fa_disabled" --jq '.[].login'
gh api "orgs/EG2development/outside_collaborators?filter=2fa_disabled" --jq '.[].login'
```

Then, in the organisation's **Settings**, select **Authentication security**.
Under "Two-factor authentication", select **Require two-factor authentication
for everyone in your organization**, then **Save**.

## Set the base permission

Base permission applies to every member, but not to outside collaborators. Set
it to **No permission**, and give each team access to its own repositories:

```bash
gh api -X PATCH orgs/EG2development -f default_repository_permission=none
```

Or, in **Settings**, select **Member privileges** and change "Base
permissions".

Base permission does not affect the template. `gcp-cicd-template` is public,
so everyone can see it, members and non-members alike.

## Related

- [About the security model](../explanation/security-model.md)
- [About the GitHub template model](../explanation/template-model.md)
- [IAM](../reference/iam.md)
- Back to the [documentation index](../../README.md#documentation)
