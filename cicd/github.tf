# GitHub to Cloud Build: one Developer Connect connection per project, one link
# for this repository and two triggers that run the YAML in cloudbuild/.

# The Developer Connect service agent stores the GitHub OAuth token in Secret
# Manager when the connection is authorised, so it needs to manage secrets.
resource "google_project_service_identity" "developer_connect" {
  provider   = google-beta
  project    = local.project_id
  service    = "developerconnect.googleapis.com"
  depends_on = [google_project_service.cicd]
}

resource "google_project_iam_member" "developer_connect_secrets" {
  project = local.project_id
  role    = "roles/secretmanager.admin"
  member  = google_project_service_identity.developer_connect.member
}

resource "google_developer_connect_connection" "github" {
  project       = local.project_id
  location      = local.region
  connection_id = "github"

  github_config {
    github_app          = "DEVELOPER_CONNECT"
    app_installation_id = var.github_app_installation_id
  }

  # The browser authorisation fills in the credential afterwards.
  lifecycle {
    ignore_changes = [github_config[0].authorizer_credential, github_config[0].app_installation_id]
  }

  depends_on = [google_project_iam_member.developer_connect_secrets]
}

resource "google_developer_connect_git_repository_link" "repository" {
  project                = local.project_id
  location               = local.region
  parent_connection      = google_developer_connect_connection.github.connection_id
  git_repository_link_id = local.link_id
  clone_uri              = "https://github.com/${var.github_repository}.git"
}

# Cloud Build checks the trigger identity's access when it creates a trigger,
# and new IAM grants take a short time to apply. Waits on first creation only.
resource "terraform_data" "iam_propagation" {
  input = [for grant in concat(values(google_project_iam_member.ci), values(google_project_iam_member.deploy)) : grant.id]

  provisioner "local-exec" {
    command = "sleep ${var.iam_propagation_seconds}"
  }
}

locals {
  substitutions = {
    _ENVIRONMENT  = local.environment
    _PROJECT_ID   = local.project_id
    _REGION       = local.region
    _STATE_BUCKET = google_storage_bucket.state.name
  }
}

# Pull requests into main. The pull request's own cloudbuild/ci.yaml runs as
# the read-only CI identity. Writers' pull requests build automatically;
# anyone else's waits for a writer to comment /gcbrun.
resource "google_cloudbuild_trigger" "ci" {
  project         = local.project_id
  location        = local.region
  name            = "${local.environment}-ci"
  description     = "Checks and plan for pull requests to main (${var.github_repository}, ${local.environment}). Read-only."
  service_account = google_service_account.ci.id
  filename        = "cloudbuild/ci.yaml"
  substitutions   = local.substitutions
  tags            = ["terraform", "ci", local.environment]

  developer_connect_event_config {
    git_repository_link = google_developer_connect_git_repository_link.repository.id
    pull_request {
      branch          = "^main$"
      comment_control = "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"
    }
  }

  depends_on = [terraform_data.iam_propagation, google_storage_bucket_iam_member.state_ci]
}

# Merges to main. Runs cloudbuild/deploy.yaml from main as the deploy
# identity, after a Cloud Build approval when the environment requires one.
resource "google_cloudbuild_trigger" "deploy" {
  project         = local.project_id
  location        = local.region
  name            = "${local.environment}-deploy"
  description     = "Plan, check and apply main (${var.github_repository}, ${local.environment})."
  service_account = google_service_account.deploy.id
  filename        = "cloudbuild/deploy.yaml"
  substitutions   = local.substitutions
  tags            = ["terraform", "deploy", local.environment]

  developer_connect_event_config {
    git_repository_link = google_developer_connect_git_repository_link.repository.id
    push {
      branch = "^main$"
    }
  }

  approval_config {
    approval_required = local.approval_required
  }

  depends_on = [terraform_data.iam_propagation, google_storage_bucket_iam_member.state_deploy]
}
