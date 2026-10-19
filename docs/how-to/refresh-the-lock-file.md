# How to refresh the lock file

Use this guide when a provider lock file is missing hashes or no longer matches
`versions.tf`. The repository has two lock files, and you refresh both:
`.terraform.lock.hcl` and `cicd/.terraform.lock.hcl`.

<!--
Test record: commands run on 18 October 2026 with Terraform 1.16.6 on macOS
darwin_arm64, in a scratch copy of the template (commit c3f3b78), with
hashicorp/google and google-beta 8.7.0. Output trimmed with "...".
-->

## When you need this

- Pre-flight shows `WARN  Provider lock file   DIR lock covers only N platform hash(es)`.
- Pre-flight shows `FAIL  Provider lock file   DIR/.terraform.lock.hcl is missing`.
- The `init` step in Cloud Build fails with
  `FAIL init: check .terraform.lock.hcl matches versions.tf (docs/how-to/refresh-the-lock-file.md).`
- You changed a provider version. See
  [Update the Google provider](update-the-google-provider.md) first.

Cloud Build runs `terraform init -lockfile=readonly`. It never updates the lock
file, so a lock that does not match `versions.tf` fails the build.

## Refresh both lock files

1. On a branch, in the repository root, run:

   ```bash
   terraform providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64 -platform=darwin_amd64
   terraform -chdir=cicd providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64 -platform=darwin_amd64
   ```

   You do not need `terraform init` first. Each command prints a line per
   platform and ends with a summary. When nothing was missing, it looks like
   this:

   ```text
   - Fetching hashicorp/google 8.7.0 for linux_amd64...
   ...
   - Obtained hashicorp/google checksums for linux_arm64; All checksums for this platform were already tracked in the lock file

   Success! Terraform has validated the lock file and found no need for changes.
   ```

2. Run pre-flight:

   ```bash
   ./scripts/preflight.sh
   ```

   It shows `PASS  Google provider      8.7.0 (.)`, the same for `(cicd)`, and
   `PASS  Provider lock file   root and cicd/ committed`.

3. Commit both lock files and open a pull request.

## Why four platforms

Cloud Build workers use `linux_amd64`. People run Terraform on macOS (Apple
silicon and Intel) and in Linux containers, which use `linux_arm64` on Apple
silicon. Hashes for all four mean nobody's `terraform init` adds new hashes
later. HashiCorp recommends locking every platform you intend to use
([`terraform providers lock`](https://developer.hashicorp.com/terraform/cli/commands/providers/lock),
checked 18 October 2026).

## Check the result

Each provider gets one `h1:` hash per platform. Count them:

```bash
grep -c '"h1:' .terraform.lock.hcl cicd/.terraform.lock.hcl
```

With the current providers the counts are:

```text
.terraform.lock.hcl:4
cicd/.terraform.lock.hcl:8
```

`cicd/` locks two providers, so it has eight.

Pre-flight looks at the provider with the fewest `h1:` hashes in each file. It
warns unless every provider covers four platforms.

## Related

- [Versions](../reference/versions.md)
- [Troubleshoot Cloud Build](troubleshoot-cloud-build.md)
- Back to the [documentation index](../../README.md#documentation)
