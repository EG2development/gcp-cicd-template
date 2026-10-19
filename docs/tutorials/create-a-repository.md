# Create a GCP CI/CD repository in under 15 minutes

<!--
Test record. The transcript below is from a pilot run on 19 October 2026
(template with commit aaccb61, Terraform 1.16.6 on macOS darwin_arm64), with
the project, repository and account names replaced and Terraform's own output
shortened to "...". The state bucket and init steps come from the first
bootstrap run of the same pilot, which created the bucket; the second, complete
run found it already there. Pilot timings: repository created to first
successful pull-request check 7 min 51 s, to first deployment 9 min 42 s,
including about 2 minutes lost to a template defect fixed during the run.
-->

In this tutorial, we will create a repository from the GCP CI/CD template,
connect it to a GCP project and deploy it with Cloud Build. At the end, a merge
to `main` will have run a deployment build in our project.

We will call the repository `my-service` and the project `my-service-dev`.
Use your own names wherever these appear. In the pilot, it took about 8 minutes
from creating the repository to the first deployment.

## Before we start

We need:

- a GCP project that already exists, with billing, where we have the Owner
  role, used only for experiments;
- membership of the `EG2development` GitHub organisation;
- Terraform 1.16.6, the Google Cloud CLI (`gcloud`), the GitHub CLI (`gh`) and
  `git`, on macOS or Linux;
- `gh` signed in to GitHub. `gh auth status` shows our account.

Platform Engineering must have finished
[Set up the organisation](../how-to/set-up-the-organisation.md). If our project
is not in a GCP organisation, they must also have given it read access to the
central Terraform image. If you are not sure, ask them before you start.

## Create the repository

1. Open <https://github.com/EG2development/gcp-cicd-template>.
2. Select **Use this template**, then **Create a new repository**.
3. Set **Owner** to `EG2development` and **Repository name** to `my-service`.
4. Select **Public**, then **Create repository**.

GitHub opens the new repository. Notice that it has a single commit: a
repository created from a template starts with its own history.

## Clone it

```bash
gh repo clone EG2development/my-service
cd my-service
```

We now have the template's files on our machine. Bootstrap reads the
repository name from the `origin` remote, so we never type it again.

## Set the project

Open `environments/dev.yaml` and replace `my-gcp-project` with our project ID:

```yaml
project:
  id: my-service-dev # the GCP project this environment deploys to
  region: europe-west2 # where Cloud Build runs and Terraform state is stored

environment:
  name: dev # must match this file's name
```

This is the only file we edit.

## Sign in to Google Cloud

```bash
gcloud auth login
gcloud auth application-default login
```

Each command opens a browser window. Sign in with the account that has Owner on
the project. Notice that there are two sign-ins: `gcloud` uses the first and
Terraform uses the second.

## Run bootstrap

```bash
./scripts/bootstrap.sh
```

Bootstrap picks `dev` because it is the only file in `environments/`. It runs
pre-flight checks, creates the state bucket, and then waits for us:

```text
==> Pre-flight (dev)
PASS  Terraform version    1.16.6
PASS  Google provider      8.7.0 (.)
PASS  Google provider      8.7.0 (cicd)
PASS  Provider lock file   root and cicd/ committed
PASS  Configuration        my-service-dev, europe-west2, dev
PASS  GCP authentication   you@example.com
PASS  Target project       my-service-dev
PASS  IAM                  you can create the CI/CD resources in my-service-dev
PASS  Terraform image      terraform@sha256:8fff2a67f0d00ffbb8df2859a862ba8952e9d9cd96af7ae58be8dd743d5e3b17
INFO  Cloud Build          triggers not created yet; ./scripts/bootstrap.sh dev creates them
PASS  terraform validate   .
PASS  terraform validate   cicd
PASS  GitHub repository    EG2development/my-service

All checks passed.
    done in 10s

==> Terraform state bucket gs://my-service-dev-tfstate
Creating gs://my-service-dev-tfstate/...

Updating gs://my-service-dev-tfstate/...
...
    done in 4s

==> Terraform init (cicd/)
    done in 2s

==> Connect my-service-dev to GitHub
...
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

    One-time step for this project: authorise Developer Connect on GitHub.
    Open this link, sign in to Google as you@example.com and to GitHub as a member of EG2development:

    https://accounts.google.com/AccountChooser?continue=https%3A%2F%2Fconsole.cloud.google.com%2Fdeveloper-connect%2Ffinish-setup%3Fstate%3D%257B%2522connection%2522%253A%2B%2522projects%252Fmy-service-dev%252Flocations%252Feurope-west2%252Fconnections%252Fgithub%2522%257D

    Then select Authorize. If GitHub asks where to install the app, choose EG2development.
    Waiting up to 15 minutes; bootstrap carries on by itself.
```

Terraform's own output is shortened to `...` here.

## Authorise the GitHub connection

On a Mac, bootstrap opens the link in the browser. Otherwise, copy the link into
a browser.

1. Sign in to Google with the same account as `gcloud`. The link opens the
   Developer Connect finish-setup page in the Google Cloud console.
2. Sign in to GitHub with our `EG2development` account. GitHub asks us to
   authorise Google's Developer Connect app. Select **Authorize**.
3. If GitHub asks where to install the app, choose `EG2development`, not a
   personal account.

This is the only time we use the console, and we configure nothing there. Open
only the link that bootstrap printed. Do not search GitHub for the app:
lookalike apps exist.

Back in the terminal, bootstrap notices the authorisation within a few seconds
and carries on. In the pilot, the whole bootstrap took 221 seconds, 43 of them
for this step:

```text
    connection github is ready
    done in 43s

==> Apply cicd/ (identities, IAM, repository link, triggers, alerting)
...
Apply complete! Resources: 1 imported, 17 added, 1 changed, 0 destroyed.

Outputs:
...
    done in 97s

==> Initialise workload state gs://my-service-dev-tfstate/env/dev
    done in 1s

==> Smoke build: the CI identity pulls the approved Terraform image
    done in 54s

==> Protect main and turn on secret scanning (GitHub)
    ruleset "main - protected" requires: dev-ci (my-service-dev)
    secret scanning and push protection are on
    done in 3s

==> Post-bootstrap pre-flight
PASS  Terraform version    1.16.6
PASS  Google provider      8.7.0 (.)
PASS  Google provider      8.7.0 (cicd)
PASS  Provider lock file   root and cicd/ committed
PASS  Configuration        my-service-dev, europe-west2, dev
PASS  GCP authentication   you@example.com
PASS  Target project       my-service-dev
PASS  IAM                  you can create the CI/CD resources in my-service-dev
PASS  Terraform image      terraform@sha256:8fff2a67f0d00ffbb8df2859a862ba8952e9d9cd96af7ae58be8dd743d5e3b17
PASS  Cloud Build          triggers dev-ci and dev-deploy in europe-west2
PASS  terraform validate   .
PASS  terraform validate   cicd
PASS  GitHub repository    EG2development/my-service

All checks passed.

Bootstrap of dev finished in 221s.
Repository:       EG2development/my-service
Environment:      dev in my-service-dev (europe-west2)
Pull requests:    trigger dev-ci, runs cloudbuild/ci.yaml as tf-ci-dev@my-service-dev.iam.gserviceaccount.com
Merges to main:   trigger dev-deploy, runs cloudbuild/deploy.yaml as tf-deploy-dev@my-service-dev.iam.gserviceaccount.com
Approval needed:  no
Terraform state:  gs://my-service-dev-tfstate/env/dev
Build logs:       gcloud builds list --project my-service-dev --region europe-west2

Next: create a branch, change something, push it and open a pull request.
```

Notice the `Cloud Build` line: the two triggers now exist. Notice also the
ruleset line. GitHub now protects `main`: a change needs a pull request, an
approval and a passing `dev-ci` check. On GitHub Free this only works in public
repositories, which is why we chose **Public**.
[About the security model](../explanation/security-model.md) explains more.

## Open a pull request

```bash
git switch -c configure-dev
git add environments/dev.yaml
git commit -m "Configure the dev environment"
git push -u origin configure-dev
gh pr create --fill
```

`gh` prints the address of the new pull request.

## Watch the pull-request check

```bash
gh pr checks --watch
```

A check named `dev-ci (my-service-dev)` appears within a few seconds; in the
pilot it was queued 8 seconds after the pull request opened. Google Cloud
Developer Connect posts it. The build runs for about 1.5 minutes.

To read the build log, find the build ID in the `ID` column, then print the log:

```bash
gcloud builds list --project my-service-dev --region europe-west2 --limit 1
gcloud builds log BUILD_ID --project my-service-dev --region europe-west2
```

Notice the `plan` step near the end. It creates no resources, because
`main.tf` is still empty. It only adds the `project_id` output.

## Merge

With the ruleset on, someone other than the author must approve the pull
request, so ask a teammate to approve it; that wait is not part of the 15
minutes. Without an approval, GitHub refuses the merge. When the check has
passed and the pull request is approved, merge it:

```bash
gh pr merge --squash --delete-branch
```

## Watch the deployment

The merge starts the `dev-deploy` trigger within a few seconds. List the newest
build again:

```bash
gcloud builds list --project my-service-dev --region europe-west2 --limit 1
```

After about 1.5 minutes the `STATUS` column shows `SUCCESS`. Print its log with
`gcloud builds log`, as before. Notice the `apply` step, then the `post` step,
which plans again and finds nothing left to change. On GitHub, the merge commit
on `main` now has a `dev-deploy (my-service-dev)` check.

## What we did

We created a repository from the template and set one value in one file.
Bootstrap created the Terraform state bucket, two build identities, the GitHub
connection and two Cloud Build triggers in our project. A pull request ran the
checks and a read-only plan. A merge deployed to the project.

## Next steps

- Add infrastructure to `main.tf`, then repeat the pull request and merge.
- [Add an environment](../how-to/add-an-environment.md), such as `prod`.
- [About the architecture](../explanation/architecture.md) explains how the
  pieces connect.
- Back to the [documentation index](../../README.md#documentation).
