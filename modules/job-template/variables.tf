# --- Passed straight through from the project module -------------------------

variable "context" {
  description = "Supplied by central-awx to each project module; pass it through unchanged (context = var.context)."
  type = object({
    project_id          = number
    name_prefix         = string
    organization_id     = number
    inventory_id        = number
    default_credentials = list(string)
  })
}

# --- What the template is --------------------------------------------------

variable "name" {
  description = "Template name, without branch prefix (added automatically). No spaces."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.name))
    error_message = "Template names may only use letters, digits, dots, dashes and underscores (no spaces)."
  }
}

variable "playbook" {
  description = "Playbook path inside the project repo, e.g. playbooks/ping.yml."
  type        = string
}

variable "description" {
  type    = string
  default = ""
}

# --- Optional settings, with defaults ------------------------------------------

variable "credentials" {
  description = <<-EOT
    Credential names to attach. For each credential type you don't name here,
    the default credential of that type is added (e.g. the default machine
    credential when you name none).
  EOT
  type        = list(string)
  default     = []
}

variable "job_type" {
  description = "run or check."
  type        = string
  default     = "run"

  validation {
    condition     = contains(["run", "check"], var.job_type)
    error_message = "job_type must be \"run\" or \"check\"."
  }
}

variable "limit" {
  description = "Host pattern to limit the run to, e.g. a group name."
  type        = string
  default     = ""
}

variable "extra_vars" {
  description = "Extra variables, as an HCL object."
  type        = any
  default     = {}
}

variable "become" {
  description = "Run with privilege escalation (sudo)."
  type        = bool
  default     = false
}

variable "verbosity" {
  description = "0 (normal) to 4 (connection debug)."
  type        = number
  default     = 0
}

variable "timeout" {
  description = "Seconds before the job is canceled; 0 = no timeout."
  type        = number
  default     = 0
}

variable "prompt_on_launch" {
  description = "What to ask for when launching: any of limit, variables, inventory, credential, job_type, verbosity."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for p in var.prompt_on_launch : contains(["limit", "variables", "inventory", "credential", "job_type", "verbosity"], p)])
    error_message = "prompt_on_launch may only contain limit, variables, inventory, credential, job_type, verbosity."
  }
}

variable "survey" {
  description = <<-EOT
    Survey questions. Each needs variable and question; type defaults to
    text. Types: text, textarea, password, integer, float, multiplechoice,
    multiselect (choices required for the last two).
  EOT
  type = list(object({
    variable    = string
    question    = string
    type        = optional(string, "text")
    description = optional(string, "")
    required    = optional(bool, false)
    default     = optional(string, "")
    choices     = optional(list(string), [])
    min         = optional(number, 0)
    max         = optional(number, 1024)
  }))
  default = []
}
