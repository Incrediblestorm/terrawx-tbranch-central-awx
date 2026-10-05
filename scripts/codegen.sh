#!/bin/bash
# Generates gen_<project>.tf.json for every project in projects.auto.tfvars.json.
#
#   scripts/codegen.sh <test|prod>
#
# For each branch it manages (prod: the default branch; test: the default
# branch plus every feature/* branch) it writes:
#   - an AWX project pinned to that branch,
#   - a sync step that waits for AWX to pull the branch's current commit,
#   - a module call to the branch's own template definitions
#     (<repo>//<module_path>?ref=<commit>), passing one `context` object that
#     the project module hands to central-awx's modules/job-template (name
#     prefix "" for the default branch, "<suffix>-" for feature/<suffix>), and
#     `modules` (var.awx_modules), the sources the project module calls.
#
# Every run regenerates every project, so a plain `tofu apply` reconciles
# everything (deleted branches drop out). Output is deterministic: same
# branches and commits in, byte-identical files out.
#
# Env: GITHUB_TOKEN (optional; avoids GitHub API rate limits)
set -euo pipefail

treatment=${1:?usage: codegen.sh <test|prod>}
case "$treatment" in test | prod) ;; *) echo "treatment must be test or prod" >&2; exit 1 ;; esac

cd "$(dirname "$0")/.."
auth=()
[ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

# All branches of a GitHub repo as {name, sha}. Any API error fails the run:
# an empty list would destroy every template of the project.
branches() {
  local repo=$1 page=1 out='[]' batch
  while :; do
    batch=$(curl -fsS "${auth[@]}" "https://api.github.com/repos/${repo}/branches?per_page=100&page=${page}")
    [ "$(jq length <<<"$batch")" -eq 0 ] && break
    out=$(jq -c --argjson b "$batch" '. + [$b[] | {name, sha: .commit.sha}]' <<<"$out")
    page=$((page + 1))
  done
  echo "$out"
}

rm -f gen_*.tf.json

jq -c '.projects[]' projects.auto.tfvars.json | while read -r p; do
  name=$(jq -r .name <<<"$p")
  url=$(jq -r .repo_url <<<"$p")
  default=$(jq -r '.default_branch // "main"' <<<"$p")
  path=$(jq -r '.module_path // "awx"' <<<"$p")
  repo=$(sed -E 's#^https://github.com/##; s#\.git$##; s#/$##' <<<"$url")

  [[ "$name" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]] || { echo "invalid project name: $name" >&2; exit 1; }

  all=$(branches "$repo")
  jq -e --arg d "$default" 'any(.[]; .name == $d)' <<<"$all" >/dev/null ||
    { echo "$name: default branch $default not found" >&2; exit 1; }

  jq -S \
    --arg project "$name" --arg url "$url" --arg path "$path" \
    --arg default "$default" --arg treatment "$treatment" '
    def key: "\($project)__" + (gsub("[^A-Za-z0-9_-]"; "_"));
    def prefix: if . == $default then "" else (ltrimstr("feature/") + "-") end;

    [ .[]
      | select(.name == $default or ($treatment == "test" and (.name | startswith("feature/"))))
      | . + { key: (.name | key), prefix: (.name | prefix) } ]
    | if any(.[]; .prefix | test("\\s")) then error("branch names must not contain whitespace") else . end
    | {
        resource: {
          awx_project: (map({ (.key): {
            name: (.prefix + $project),
            organization: "${local.awx.organization_id}",
            scm_type: "git",
            scm_url: $url,
            scm_branch: .name,
            scm_update_on_launch: true
          }}) | add),
          terraform_data: (map({ ("\(.key)_sync"): {
            triggers_replace: ["${awx_project.\(.key).id}", .sha],
            provisioner: [{ "local-exec": {
              command: "${path.module}/scripts/wait-project-sync.sh",
              environment: {
                AWX_URL: "${var.awx_url}",
                AWX_TOKEN: "${var.awx_token}",
                PROJECT_ID: "${awx_project.\(.key).id}"
              }
            }}]
          }}) | add)
        },
        module: (map({ (.key): {
          source: "git::\($url).git//\($path)?ref=\(.sha)",
          context: "${merge(local.awx, { project_id = awx_project.\(.key).id, name_prefix = \"\(.prefix)\" })}",
          modules: "${var.awx_modules}",
          depends_on: ["terraform_data.\(.key)_sync"]
        }}) | add)
      }' <<<"$all" > "gen_${name}.tf.json"

  echo "gen_${name}.tf.json: $(jq -r '.module | keys | join(", ")' "gen_${name}.tf.json")"
done
