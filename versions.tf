terraform {
  required_version = "~> 1.16.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
  }

  # Cloud Build supplies bucket and prefix: gs://<project>-tfstate/env/<environment>.
  # See docs/how-to/run-terraform-locally.md to plan from your machine.
  backend "gcs" {}
}
