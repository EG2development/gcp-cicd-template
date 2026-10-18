## What this changes

<!-- One or two sentences. Link the issue if there is one. -->

## Checks

- [ ] Cloud Build CI passed, and I read the `plan` step output.
- [ ] The plan only changes what I expect. It deletes or replaces nothing by accident.
- [ ] If the deploy identity needs a new role, I added it to `environments/<env>.yaml` and re-ran `./scripts/bootstrap.sh`.
- [ ] I updated `.terraform.lock.hcl` if I changed provider versions.
