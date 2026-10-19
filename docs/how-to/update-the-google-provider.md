# How to update the Google provider

Use this guide to take a new version of the `hashicorp/google` and
`hashicorp/google-beta` providers. The repository has two Terraform roots, and
both must move together:

| Root | Constraint | Providers |
|---|---|---|
| `.` (`versions.tf`) | `~> 8.7` | `google` |
| `cicd/` (`cicd/versions.tf`) | `~> 8.7` | `google`, `google-beta` |

`~> 8.7` accepts any 8.x release from 8.7 upwards. The lock files decide the
exact version.

## Review a Dependabot pull request (minor and patch versions)

Dependabot checks both roots weekly. It opens one grouped pull request titled
with the prefix `chore(deps)`. It ignores major versions
([`.github/dependabot.yml`](../../.github/dependabot.yml)).

1. Read the provider release notes that the pull request links to.
2. If no Cloud Build check starts, comment `/gcbrun` on the pull request.
3. In the build log, read the `preflight` step. If it shows
   `WARN  Provider lock file   ... covers only N platform hash(es)`, refresh the
   lock files on the Dependabot branch. See
   [Refresh the lock file](refresh-the-lock-file.md).
4. Read the pull request's file changes. It may change `versions.tf`, the lock
   files or both.
5. Read the `plan` step. Check that it changes only what you expect.
6. Merge.

Dependabot's documented Terraform support ends at 1.15.x, and this repository
requires 1.16.6. If no Dependabot pull requests appear, update by hand as
below.

## Update a minor or patch version by hand

`~> 8.7` already accepts every 8.x release from 8.7 upwards, so only the lock
files change.

1. On a branch, select the newest allowed version in both roots:

   ```bash
   terraform init -backend=false -upgrade
   terraform -chdir=cicd init -backend=false -upgrade
   ```

2. Add hashes for all four platforms. See
   [Refresh the lock file](refresh-the-lock-file.md).
3. Run `./scripts/preflight.sh`. It shows the new version for each root.
4. Open a pull request, then read the `plan` step before you merge.

## Upgrade to a new major version

Dependabot does not open these. Do the upgrade by hand.

1. Read the provider's upgrade guide for the new major version, for example the
   [version 8 upgrade guide](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/version_8_upgrade).
2. On a branch, change the constraint in both roots. Use the same constraint
   for `google` and `google-beta`:

   - `versions.tf`: `google`, for example `version = "~> 9.0"`.
   - `cicd/versions.tf`: `google` and `google-beta`.

3. Select the new version in both lock files:

   ```bash
   terraform init -backend=false -upgrade
   terraform -chdir=cicd init -backend=false -upgrade
   ```

4. Add hashes for all four platforms. See
   [Refresh the lock file](refresh-the-lock-file.md).
5. Run `./scripts/preflight.sh`. It shows the new version for each root:
   `PASS  Google provider      9.0.0 (.)` and `... (cicd)`.
6. Plan the workload locally for each environment and look for replacements.
   See [Run Terraform locally](run-terraform-locally.md).
7. Plan `cicd/` for each environment, as yourself:

   ```bash
   terraform -chdir=cicd init -reconfigure -backend-config=bucket=PROJECT_ID-tfstate -backend-config=prefix=cicd/ENV
   TF_VAR_environment=ENV TF_VAR_github_repository=EG2development/REPOSITORY terraform -chdir=cicd plan
   ```

8. Open a pull request. Platform Engineering reviews it, because it changes
   `cicd/`.
9. After the merge, run `./scripts/bootstrap.sh ENV` for each environment.
   Bootstrap applies `cicd/` without asking, so run it only if step 7 showed
   the changes you expect.

## When to use google-beta

`google-beta` is in `cicd/` for one resource only:
`google_project_service_identity` in `cicd/github.tf`. It creates the Developer
Connect service agent before the connection exists. The resource is beta-only
in provider 8.7.0.

- Do not use `google-beta` for anything else without Platform Engineering.
- Do not add it to the root module.
- When a release moves `google_project_service_identity` into `google`, ask
  Platform Engineering to remove `google-beta`.

## Related

- [Versions](../reference/versions.md)
- [Update Terraform](update-terraform.md)
- [About the approved Terraform image](../explanation/terraform-image.md)
- Back to the [documentation index](../../README.md#documentation)
