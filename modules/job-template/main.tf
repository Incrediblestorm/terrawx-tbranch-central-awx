# One AWX job template, with the conventions every project gets for free:
# project- and branch-prefixed name, labels, the environment's inventory, and
# default credentials filled in per credential type.

# --- Credentials: look up by name; fill in defaults per credential type -------

data "restapi_object" "credential" {
  for_each = toset(concat(var.credentials, var.context.default_credentials))

  path         = "/credentials/"
  query_string = "name=${urlencode(each.key)}"
  results_key  = "results"
  search_key   = "name"
  search_value = each.key
}

locals {
  credential_type = { for name, c in data.restapi_object.credential : name => c.api_data.credential_type }
  named_types     = toset([for name in var.credentials : local.credential_type[name]])

  credential_ids = distinct(concat(
    [for name in var.credentials : tonumber(data.restapi_object.credential[name].id)],
    [
      for name in var.context.default_credentials : tonumber(data.restapi_object.credential[name].id)
      if !contains(local.named_types, local.credential_type[name])
    ],
  ))
}

# --- The template -------------------------------------------------------------

resource "awx_job_template" "this" {
  name        = "${var.context.name_prefix}${var.name}"
  description = var.description
  project     = var.context.project_id
  inventory   = var.context.inventory_id
  playbook    = var.playbook

  job_type       = var.job_type
  limit          = var.limit
  extra_vars     = length(var.extra_vars) > 0 ? yamlencode(var.extra_vars) : "---"
  become_enabled = var.become
  verbosity      = var.verbosity
  timeout        = var.timeout

  survey_enabled = length(var.survey) > 0

  ask_limit_on_launch      = contains(var.prompt_on_launch, "limit")
  ask_variables_on_launch  = contains(var.prompt_on_launch, "variables")
  ask_inventory_on_launch  = contains(var.prompt_on_launch, "inventory")
  ask_credential_on_launch = contains(var.prompt_on_launch, "credential")
  ask_job_type_on_launch   = contains(var.prompt_on_launch, "job_type")
  ask_verbosity_on_launch  = contains(var.prompt_on_launch, "verbosity")
}

resource "awx_job_template_credential" "this" {
  job_template_id = awx_job_template.this.id
  credential_ids  = local.credential_ids
}

resource "awx_job_template_label" "this" {
  job_template_id = awx_job_template.this.id
  label_ids       = var.context.label_ids
}

resource "awx_job_template_survey_spec" "this" {
  count = length(var.survey) > 0 ? 1 : 0

  id = awx_job_template.this.id
  spec = [
    for q in var.survey : {
      variable             = q.variable
      question_name        = q.question
      question_description = q.description
      type                 = q.type
      required             = q.required
      default              = q.default
      choices              = length(q.choices) > 0 ? q.choices : null
      min                  = q.min
      max                  = q.max
    }
  ]
}
