# Existing objects on the server that every project's templates use. They're
# created outside this repo (with the server).

data "awx_organization" "default" {
  name = "Default"
}

data "awx_inventory" "this" {
  name         = var.inventory_names[var.treatment]
  organization = data.awx_organization.default.id
}

data "awx_credential_type" "machine" {
  name = "Machine"
  kind = "ssh"
}

data "awx_credential" "machine" {
  name            = var.credential_name
  organization    = data.awx_organization.default.id
  credential_type = data.awx_credential_type.machine.id
}

# Passed to every generated project/branch (see scripts/codegen.sh).
locals {
  awx = {
    organization_id = data.awx_organization.default.id
    inventory_id    = data.awx_inventory.this.id
    credential_id   = data.awx_credential.machine.id
  }
}
