# CI/CD for one environment of this repository, created in that environment's
# own GCP project. Apply it with ./scripts/bootstrap.sh, never from Cloud Build:
# the pipeline must not be able to change its own identities or triggers.

locals {
  config      = yamldecode(file("${path.module}/../environments/${var.environment}.yaml"))
  project_id  = local.config.project.id
  region      = try(local.config.project.region, "europe-west2")
  environment = local.config.environment.name
  deploy      = try(local.config.deploy, {})
  alert_email = try(local.config.alerts.email, "")

  # Approval is on by default only where the environment's risk needs it.
  approval_required = try(local.deploy.approval, contains(["prod", "production"], local.environment))
  approvers         = toset(try(local.deploy.approvers, []))
  deploy_roles      = toset(try(local.deploy.roles, []))

  # Each environment needs its own project: the state bucket and the GitHub
  # connection are per project, so two cicd/ states would fight over them.
  shared_project = [
    for file in fileset("${path.module}/../environments", "*.yaml") : trimsuffix(file, ".yaml")
    if trimsuffix(file, ".yaml") != var.environment && try(yamldecode(file("${path.module}/../environments/${file}")).project.id, "") == local.project_id
  ]

  repository   = split("/", var.github_repository)[1]
  link_id      = substr(trim(replace(lower(local.repository), "/[^a-z0-9-]+/", "-"), "-"), 0, 63)
  state_bucket = "${local.project_id}-tfstate"
  labels = {
    managed-by  = "terraform"
    environment = local.environment
    repository  = local.link_id
  }

  # Build identities hold only what their trigger needs. Neither can act as
  # the other, and neither can change IAM, triggers or this configuration.
  ci_roles = toset([
    "roles/logging.logWriter",                  # write build logs (CLOUD_LOGGING_ONLY)
    "roles/developerconnect.readTokenAccessor", # clone the repository through the link
    "roles/viewer",                             # read-only refresh during terraform plan
  ])
  deploy_base_roles = toset([
    "roles/logging.logWriter",
    "roles/developerconnect.readTokenAccessor",
    "roles/viewer",
  ])
}

resource "google_project_service" "cicd" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "developerconnect.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com", # holds the GitHub OAuth token; no longer enabled by Developer Connect
    "storage.googleapis.com",
  ])
  project            = local.project_id
  service            = each.value
  disable_on_destroy = false
}

# Terraform state for this environment's workload and for cicd/ itself.
# bootstrap.sh creates the bucket first (Terraform needs it for state), then
# this import adopts it so its settings are managed here.
import {
  to = google_storage_bucket.state
  id = "${local.project_id}/${local.state_bucket}"
}

resource "google_storage_bucket" "state" {
  project                     = local.project_id
  name                        = local.state_bucket
  location                    = upper(local.region)
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Keep old state versions for 90 days, enough to recover from a bad apply.
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 90
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "ci" {
  project      = local.project_id
  account_id   = "tf-ci-${local.environment}"
  display_name = "Terraform CI (${local.environment})"
  description  = "Pull-request checks and plans for ${var.github_repository}. Read-only."
  depends_on   = [google_project_service.cicd]

  lifecycle {
    precondition {
      condition     = local.environment == var.environment
      error_message = "environment.name in environments/${var.environment}.yaml must be ${var.environment}."
    }
    precondition {
      condition     = length(local.shared_project) == 0
      error_message = "environments/${join(".yaml, environments/", local.shared_project)}.yaml also use project ${local.project_id}. Give each environment its own project."
    }
  }
}

resource "google_service_account" "deploy" {
  project      = local.project_id
  account_id   = "tf-deploy-${local.environment}"
  display_name = "Terraform deploy (${local.environment})"
  description  = "Applies Terraform from main for ${var.github_repository}."
  depends_on   = [google_project_service.cicd]

  lifecycle {
    precondition {
      condition     = length(setintersection(local.deploy_roles, ["roles/owner", "roles/editor"])) == 0
      error_message = "Do not give the deploy identity roles/owner or roles/editor. List the specific roles your Terraform needs in deploy.roles."
    }
  }
}

resource "google_project_iam_member" "ci" {
  for_each = local.ci_roles
  project  = local.project_id
  role     = each.value
  member   = google_service_account.ci.member
}

resource "google_project_iam_member" "deploy" {
  for_each = setunion(local.deploy_base_roles, local.deploy_roles)
  project  = local.project_id
  role     = each.value
  member   = google_service_account.deploy.member
}

# Pull requests read state to plan; only main can lock and write it.
resource "google_storage_bucket_iam_member" "state_ci" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.ci.member
}

resource "google_storage_bucket_iam_member" "state_deploy" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.deploy.member
}

resource "google_project_iam_member" "approvers" {
  for_each = local.approval_required ? local.approvers : toset([])
  project  = local.project_id
  role     = "roles/cloudbuild.builds.approver"
  member   = each.value
}
