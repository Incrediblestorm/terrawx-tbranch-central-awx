# One OpenTofu workspace per environment keeps state separate per AWX server:
#
#   tofu workspace select -or-create test
#   tofu apply -var-file=envs/test.tfvars

locals {
  # tobool() on a message string fails the run with that message.
  environment = terraform.workspace != "default" ? terraform.workspace : tobool(
    "Select an environment workspace first: tofu workspace select -or-create test (or prod)"
  )
}

provider "awx" {
  endpoint = var.awx_url
  token    = var.awx_token
}
