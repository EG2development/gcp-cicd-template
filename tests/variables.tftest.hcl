# Example test. Cloud Build runs every tests/*.tftest.hcl in the test step.
# A mock provider needs no credentials, so tests run on pull requests too.
mock_provider "google" {}

variables {
  project_id  = "example-project"
  region      = "europe-west2"
  environment = "dev"
}

run "accepts_valid_settings" {
  command = plan
}

run "rejects_a_region_display_name" {
  command = plan

  variables {
    region = "London"
  }

  expect_failures = [var.region]
}
