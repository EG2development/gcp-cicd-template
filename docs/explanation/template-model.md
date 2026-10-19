# About the GitHub template model

Repositories start as copies of `EG2development/gcp-cicd-template`, a GitHub
template repository. This page explains what that copy contains, what it does
not, how template changes reach existing repositories, and why bootstrap sets
up GitHub protection itself.

## What a template copy is

When you select **Use this template**, GitHub creates a new repository with the
same files and folders as the template's default branch. The new repository
starts with a single commit. Its history is unrelated to the template's, so
GitHub cannot open a pull request or merge between them.

GitHub copies files, not settings. Rulesets, branch protection, team access,
topics, security settings and Actions settings stay behind. Files that hold
settings, such as `.github/CODEOWNERS` and `.github/dependabot.yml`, do come
across, because they are files. GitHub's own documentation lists only files,
folders and branches as copied, and the organisation's existing template
repositories behave the same way.

## The copy is independent

Once created, your repository owes nothing to the template. It keeps working if
the template changes or disappears. You can read and review everything that
runs, because it is all in your repository: the pipelines, the CI/CD Terraform
and the scripts. At build time the only outside dependency is the approved
Terraform image.

The other side of independence is drift. A fix in the template does not reach
your repository on its own.

## How template changes reach existing repositories

They do not arrive automatically. Because the histories are unrelated, there is
no merge to run. Platform Engineering announces template changes as releases
on the template repository, and teams watch those releases.

To take a change, a team adds the template as a second remote and compares
the CI/CD files with it:

```bash
git remote add template https://github.com/EG2development/gcp-cicd-template.git
git fetch template
git diff HEAD template/main -- cloudbuild cicd scripts .github .terraform-version
```

`git diff` compares the two trees, so the unrelated histories do not matter.
The team copies the changes it wants into a branch and opens a pull request,
which the code owners review. The second pilot took a template fix this way, in
three files, while it was running.

Those paths are the ones Platform Engineering reviews, and the ones most
likely to change. A change to `cicd/` also needs someone to re-run
`./scripts/bootstrap.sh` for each environment, because the pipeline never
applies `cicd/` itself.

## Why bootstrap writes the GitHub protection

Settings do not travel with the template, so something must apply them to
each new repository. Bootstrap does: it creates the `main - protected` ruleset
from `.github/ruleset-main.json`, gives the `platform-engineering` team write
access so that code owner review can work, and turns on secret scanning and
push protection where GitHub allows it.

An organisation ruleset would avoid a per-repository step, but two things rule
it out:

- On GitHub Free, organisation rulesets are not available. They need GitHub
  Team or Enterprise.
- The required check is named after the trigger and the project, for example
  `dev-ci (my-service-dev)`. Only the repository knows its own project, so an
  organisation-wide rule cannot name the check.

Repository rulesets themselves are enforced on public repositories only, on
GitHub Free. [About the security model](security-model.md) covers what that
means for private repositories.

## Why a template, rather than a central pipeline

A central pipeline, or a shared configuration that every repository points at,
would update everywhere at once. It would also need a control plane that owns
every repository's triggers and identities, and a change there would affect
every project at the same moment. A template keeps each repository
self-contained, at the cost of updates that each team takes deliberately.
[About the CI/CD architecture](architecture.md) discusses the central option
further.

## Sources

Checked 18 October 2026:

- [Creating a repository from a template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)
- [Creating a template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository)
- [Creating rulesets for repositories in your organization](https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization)
- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

## Related

- [Repository structure](../reference/repository-structure.md)
- [Set up the organisation](../how-to/set-up-the-organisation.md)
- Back to the [documentation index](../../README.md#documentation)
