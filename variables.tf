# Cloud Build sets these from environments/<environment>.yaml (TF_VAR_*), so
# never hard-code them. Put per-environment values in a locals map keyed by
# var.environment (see docs/how-to/add-an-environment.md).

variable "project_id" {
  description = "GCP project this environment deploys to."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Use a GCP project ID, such as my-team-dev."
  }
}

variable "region" {
  description = "Default region for resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "Use a region name, such as europe-west2."
  }
}

variable "environment" {
  description = "Environment name, such as dev or prod."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.environment))
    error_message = "Use 2-10 lowercase letters or digits, starting with a letter."
  }
}
