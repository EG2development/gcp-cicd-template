# About minimal configuration

A repository's whole CI/CD configuration is one small YAML file per
environment, and most of it is optional. This page explains why the file is so
small, what is derived instead, and how the defaults were chosen.

## Ask only for what only you know

Onboarding needs three facts that nobody else can supply: which GCP project an
environment deploys to, in which region, and what the environment is called.
Everything else can follow from those facts and from fixed naming rules. So
the file asks for the project ID and, if you need it, the region. The
environment name must match the file name, which makes it impossible for the
two to disagree.

The repository name is not in the file at all. Bootstrap reads it from the
`origin` remote of your clone. A value you never type is a value you cannot
mistype.

## Derived names

From the project and environment, the template derives every other name:

- the state bucket, `<project>-tfstate`;
- the identities, `tf-ci-<env>` and `tf-deploy-<env>`;
- the triggers, `<env>-ci` and `<env>-deploy`;
- the check on pull requests, `<env>-ci (<project>)`.

Fixed rules make every repository look the same. A troubleshooting guide, an
alert or a colleague can name the exact trigger or identity without looking it
up. The rules assume each environment has its own project, because the state
bucket and the GitHub connection belong to a project. `cicd/` enforces this:
it stops if another environment file names the same project.

The cost is rigidity. The state bucket name, for example, cannot be changed.
Project IDs are globally unique, so a clash means another project has created
a bucket with your project's name. There is no setting to work around it. [Configuration](../reference/configuration.md) lists every
derived value.

## One parser, no extra tools

The scripts read the file with Terraform's own YAML decoder, through
`terraform console`, and `cicd/` reads it with `yamldecode`. Nobody needs to
install a separate YAML tool, and the scripts and Terraform cannot read the
file differently.

Cloud Build does not read the file to decide where to deploy. Bootstrap copies
the values into the triggers. The `preflight` step in each build then compares
the file with what the trigger says. A file that changed after bootstrap stops
the build instead of deploying somewhere unexpected.

## The defaults

**Region.** `europe-west2` unless you set another. Cloud Build, Developer
Connect and the state bucket all use the one region, because Google requires a
trigger and its repository link to be in the same region.

**Approval.** On for environments named `prod` or `production`, off for every
other name. Approval on a development environment slows every merge for little
benefit; approval on production catches a mistake before it lands. Basing the
default on the name gives the safer choice without anyone having to remember
it. The limit is that the rule only knows those two names. An environment
called `live` gets no approval unless you set `deploy.approval: true`.

**Roles.** None beyond the base roles. Until you list roles in `deploy.roles`,
the deploy identity can read your project and write its state, but change no
resources. Its access grows only by deliberate, reviewable steps.

## What is deliberately not in the file

Some settings could be exposed in the file but are kept in code instead: the CI
identity's roles, the trigger branch, the build steps and timeouts, and the
image. These decide what runs with which rights. Keeping them in `cicd/` and
`cloudbuild/` means a change to them goes through Platform Engineering's code
review, rather than through a file that every team edits.

## Related

- [Configuration](../reference/configuration.md)
- [Add an environment](../how-to/add-an-environment.md)
- [About the CI/CD architecture](architecture.md)
- Back to the [documentation index](../../README.md#documentation)
