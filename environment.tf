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

# Generic AWX API access, used by modules/job-template to find credentials by
# name (the awx provider needs the credential type to do that).
provider "restapi" {
  uri          = "${trimsuffix(var.awx_url, "/")}/api/v2"
  bearer_token = var.awx_token
}
