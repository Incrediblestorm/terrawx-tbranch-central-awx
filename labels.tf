# Labels on every template, for filtering in AWX: the project, the branch, and
# what manages it. The branch list comes from codegen (managed_branches).

locals {
  labels = toset(concat(
    ["managed-by:${var.managed_by}"],
    [for p in var.projects : "project:${p.name}"],
    [for b in var.managed_branches : "branch:${b}"],
  ))
}

resource "awx_label" "this" {
  for_each = local.labels

  name         = each.key
  organization = data.awx_organization.default.id
}
