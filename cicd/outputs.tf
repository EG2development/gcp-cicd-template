output "ci_service_account" {
  description = "Identity for pull-request builds (read-only)."
  value       = google_service_account.ci.email
}

output "deploy_service_account" {
  description = "Identity for main-branch deployments."
  value       = google_service_account.deploy.email
}

output "ci_check_name" {
  description = "Name of the GitHub check that the pull-request trigger posts. Bootstrap requires it in the main ruleset."
  value       = "${google_cloudbuild_trigger.ci.name} (${local.project_id})"
}

output "state_bucket" {
  description = "Terraform state bucket for this environment."
  value       = google_storage_bucket.state.name
}

output "summary" {
  description = "What bootstrap created, in plain words."
  value       = <<-EOT
    Repository:       ${var.github_repository}
    Environment:      ${local.environment} in ${local.project_id} (${local.region})
    Pull requests:    trigger ${google_cloudbuild_trigger.ci.name}, runs cloudbuild/ci.yaml as ${google_service_account.ci.email}
    Merges to main:   trigger ${google_cloudbuild_trigger.deploy.name}, runs cloudbuild/deploy.yaml as ${google_service_account.deploy.email}
    Approval needed:  ${local.approval_required ? "yes, gcloud alpha builds approve BUILD_ID --location ${local.region} --project ${local.project_id}" : "no"}
    Terraform state:  gs://${google_storage_bucket.state.name}/env/${local.environment}
    Build logs:       gcloud builds list --project ${local.project_id} --region ${local.region}
  EOT
}
