# Build logs and failure alerts. Cloud Monitoring has no build-status metric,
# so the alert matches the failure lines that every pipeline step prints.

locals {
  build_logs = join(" AND ", [
    "resource.type=\"build\"",
    "logName=\"projects/${local.project_id}/logs/cloudbuild\"",
    "resource.labels.build_trigger_id=(\"${google_cloudbuild_trigger.ci.trigger_id}\" OR \"${google_cloudbuild_trigger.deploy.trigger_id}\")",
  ])
}

# Keep this environment's build logs for a year (the _Default bucket keeps 30 days).
resource "google_logging_project_bucket_config" "builds" {
  project        = local.project_id
  location       = local.region
  bucket_id      = "cicd-${local.environment}"
  retention_days = 365
  description    = "Cloud Build logs for ${var.github_repository} (${local.environment})"
}

# A sink into a bucket in its own project has no writer identity to grant.
resource "google_logging_project_sink" "builds" {
  project                = local.project_id
  name                   = "cicd-${local.environment}"
  destination            = "logging.googleapis.com/${google_logging_project_bucket_config.builds.id}"
  filter                 = local.build_logs
  unique_writer_identity = true
}

resource "google_monitoring_notification_channel" "email" {
  count        = local.alert_email == "" ? 0 : 1
  project      = local.project_id
  display_name = "CI/CD alerts (${local.environment})"
  type         = "email"
  labels = {
    email_address = local.alert_email
  }
  depends_on = [google_project_service.cicd]
}

# Deployments only: a failed pull-request build is normal feedback, a failed
# deployment needs someone to act.
resource "google_monitoring_alert_policy" "deploy_failed" {
  project               = local.project_id
  display_name          = "Deployment failed: ${var.github_repository} (${local.environment})"
  combiner              = "OR"
  notification_channels = google_monitoring_notification_channel.email[*].id
  user_labels           = local.labels

  conditions {
    display_name = "A ${local.environment}-deploy build step failed"
    condition_matched_log {
      filter = join(" AND ", [
        "resource.type=\"build\"",
        "resource.labels.build_trigger_id=\"${google_cloudbuild_trigger.deploy.trigger_id}\"",
        "textPayload=~\"FAIL [a-z-]+:|ERROR: build step\"",
      ])
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "1800s"
  }

  documentation {
    mime_type = "text/markdown"
    content   = "The ${local.environment}-deploy build failed. Find it with `gcloud builds list --project ${local.project_id} --region ${local.region} --filter='status=FAILURE' --limit 1`, read the FAIL line, then follow docs/how-to/recover-a-failed-deployment.md in ${var.github_repository}."
  }

  depends_on = [google_project_service.cicd]
}
