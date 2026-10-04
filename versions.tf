terraform {
  required_version = ">= 1.6"

  # State lives in the cluster as Secrets (one per workspace), so CI runners
  # and local runs share it. How to reach the cluster is passed at init:
  #   local: tofu init -backend-config=backend/local.hcl
  #   CI:    tofu init -backend-config=backend/ci.hcl
  backend "kubernetes" {
    namespace     = "tofu-state"
    secret_suffix = "central-awx"
  }

  required_providers {
    awx = {
      # Published on the Terraform registry only, not registry.opentofu.org.
      source  = "registry.terraform.io/tfbrew/awx"
      version = "~> 1.8"
    }
  }
}
