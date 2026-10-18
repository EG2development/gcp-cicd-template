# The approved Terraform image ships these plugin versions, so CI never
# downloads plugins. Locally, run `tflint --init` once.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "google" {
  enabled = true
  version = "0.40.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}
