# Which AWX server to manage and how. In CI these come from the GitHub Actions
# environment (TF_VAR_awx_url, TF_VAR_awx_token, TF_VAR_treatment); locally
# from envs/<environment>.tfvars (git-ignored).

variable "awx_url" {
  description = "Base URL of the AWX server, e.g. https://awx.example.com"
  type        = string
}

variable "awx_token" {
  description = "AWX OAuth2 personal access token."
  type        = string
  sensitive   = true
}

variable "treatment" {
  description = "prod: default branches only. test: default branches plus every feature/* branch, with prefixed template names."
  type        = string

  validation {
    condition     = contains(["test", "prod"], var.treatment)
    error_message = "treatment must be \"test\" or \"prod\"."
  }
}

# The project list lives in projects.auto.tfvars.json (committed), so the
# codegen script can read it too.
variable "projects" {
  description = "Ansible projects whose job templates this repo manages."
  type = list(object({
    name           = string
    repo_url       = string
    default_branch = optional(string, "main")
    module_path    = optional(string, "awx")
  }))
}

variable "inventory_names" {
  description = "Inventory the templates use, per treatment."
  type        = map(string)
  default     = { test = "test-inventory", prod = "inventory" }
}

variable "credential_name" {
  description = "Machine credential the templates use."
  type        = string
  default     = "lab-ssh"
}
