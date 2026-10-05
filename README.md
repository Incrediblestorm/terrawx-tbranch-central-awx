# central-awx

Manages AWX projects and job templates with OpenTofu. Each Ansible project
defines its own job templates (in its repo, per branch); this repo wires them
into an AWX server.

## How it works

1. **Projects** are listed in `projects.auto.tfvars.json` (committed):
   name, repo URL, default branch, and where the template module lives
   (`awx/` by default).
2. **Codegen** (`scripts/codegen.sh <treatment>`) asks GitHub for each
   project's branches and writes `gen_<project>.tf.json` with, per branch:
   an AWX project pinned to the branch, a step that syncs it, and a call to the
   branch's own template module, pinned to the branch's current commit.
3. **`tofu apply`** creates or updates everything. Every run regenerates every
   project, so deleted branches are removed too.

| Treatment | Branches | Template names |
|---|---|---|
| `prod` | default branch only | as defined, e.g. `ping` |
| `test` | default branch + every `feature/*` | default: `ping`; `feature/foo`: `foo-ping` |

The AWX project for `feature/foo` is named `foo-<project>`. Names have no
spaces.

### Writing templates in a project repo

A project's module (e.g. `awx/`) contains one call to central-awx's
job-template module per template, plus a two-line `variables.tf`:

```hcl
module "ping" {
  source  = var.modules.job_template
  context = var.context

  name     = "ping"
  playbook = "playbooks/ping.yml"
  # optional: credentials, job_type, limit, extra_vars, become, verbosity,
  #           timeout, prompt_on_launch, survey, description
}
```

```hcl
variable "context" { type = any }
variable "modules" { type = any }
```

central-awx supplies both: `context` (AWX project for the branch, name prefix,
inventory, default credentials) and `modules` (where its modules live, set in
`modules.auto.tfvars.json`). The module then:

- names the template, adding the branch prefix (`feature/foo` -> `foo-ping`);
  names may not contain spaces
- uses the environment's inventory (`test-inventory` on test, `inventory` on
  prod)
- attaches `credentials` (looked up by name, any credential on the server),
  plus each of `default_credentials` whose type the template didn't name
  (default: the `lab-ssh` machine credential)

Module sources in variables need OpenTofu >= 1.8 (early evaluation); this
setup doesn't work with Terraform.

## Environments

One GitHub Actions environment per AWX server, providing:

| Name | Kind | Value |
|---|---|---|
| `AWX_URL` | variable | base URL of the server |
| `AWX_TOKEN` | secret | AWX OAuth2 token |
| `AWX_TREATMENT` | variable | `test` or `prod` |

exposed to OpenTofu as `TF_VAR_awx_url`, `TF_VAR_awx_token`,
`TF_VAR_treatment`. The OpenTofu workspace is named after the environment, so
state is separate per server.

## CI

`.github/workflows/awx.yml` runs on the in-cluster `awx-local` runners
(provided by the infrastructure) when a project repo sends a
`repository_dispatch`:

| Event | When | Applies to |
|---|---|---|
| `project-feature` | a `feature/*` branch is pushed or deleted | test |
| `project-main` | something is merged into `main` | test, then prod |

It can also be run manually (optionally including prod). Each run: codegen
for the environment's treatment, `tofu init`, select the environment's
workspace, `tofu apply`.

State is stored in the cluster (`kubernetes` backend, namespace
`tofu-state`), shared by CI and local runs; `backend/ci.hcl` and
`backend/local.hcl` say how each reaches the cluster.

## Running locally

Create `envs/<environment>.tfvars` (git-ignored; see
`terraform.tfvars.example`), then:

```bash
scripts/codegen.sh test            # set GITHUB_TOKEN to avoid API rate limits
tofu init -backend-config=backend/local.hcl
tofu workspace select -or-create test
tofu apply -var-file=envs/test.tfvars
```

Needs `curl` and `jq`.

## Notes

- Provider: `tfbrew/awx`, published only on the Terraform registry, so the
  source is `registry.terraform.io/tfbrew/awx` (OpenTofu installs it fine).
- Codegen fails the run if GitHub can't be queried or a project's default
  branch is missing. An empty branch list would otherwise remove every
  template of that project.
