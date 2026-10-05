# Existing objects on the server that every project's templates use. They're
# created outside this repo (with the server).

data "awx_organization" "default" {
  name = "Default"
}

data "awx_inventory" "this" {
  name         = var.inventory_names[var.treatment]
  organization = data.awx_organization.default.id
}

# The part of each project module's `context` that's the same for every
# branch; codegen adds project_id and name_prefix (see scripts/codegen.sh).
locals {
  awx = {
    organization_id     = data.awx_organization.default.id
    inventory_id        = data.awx_inventory.this.id
    default_credentials = var.default_credentials
  }
}
