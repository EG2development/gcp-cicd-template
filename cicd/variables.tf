variable "environment" {
  description = "Environment to set up. Reads environments/<environment>.yaml. Supplied by bootstrap.sh."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.environment))
    error_message = "Use 2-10 lowercase letters or digits, starting with a letter, such as dev or prod."
  }
}

variable "github_repository" {
  description = "GitHub repository as owner/name. Derived from the git remote by bootstrap.sh."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "Use owner/name, for example eg2development/my-service."
  }
}

variable "github_app_installation_id" {
  description = "Installation of the Google Cloud Developer Connect GitHub App on the organisation, so the browser step only asks for Authorize. Platform Engineering sets it once (docs/how-to/set-up-the-organisation.md); null lets the browser step choose."
  type        = number
  default     = 172925456 # EG2development, all repositories, installed 19 October 2026
}

variable "iam_propagation_seconds" {
  description = "Wait after the first IAM grants, because Cloud Build checks the trigger identity's access when it creates a trigger."
  type        = number
  default     = 60
}
