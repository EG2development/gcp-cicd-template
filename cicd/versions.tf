terraform {
  required_version = "~> 1.16.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
    # Used for one resource only: google_project_service_identity, which is
    # still beta-only in 8.7. It creates the Developer Connect service agent so
    # it can be granted access before the connection exists.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.7"
    }
  }

  # bootstrap.sh supplies bucket and prefix: gs://<project>-tfstate/cicd/<environment>.
  backend "gcs" {}
}

provider "google" {
  project               = local.project_id
  region                = local.region
  billing_project       = local.project_id
  user_project_override = true
  default_labels        = local.labels
}

provider "google-beta" {
  project               = local.project_id
  region                = local.region
  billing_project       = local.project_id
  user_project_override = true
}
