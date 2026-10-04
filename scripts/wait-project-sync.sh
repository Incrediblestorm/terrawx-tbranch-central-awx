#!/bin/bash
# Syncs an AWX project from source control and waits for the result, so the
# branch's playbooks are known to AWX before its job templates are created.
#
# Env: AWX_URL, AWX_TOKEN, PROJECT_ID
set -euo pipefail

api="${AWX_URL%/}/api/v2"
auth=(-H "Authorization: Bearer ${AWX_TOKEN}")

update=$(curl -fsS -X POST "${auth[@]}" "${api}/projects/${PROJECT_ID}/update/" | jq -r .project_update)
for _ in $(seq 1 60); do
  status=$(curl -fsS "${auth[@]}" "${api}/project_updates/${update}/" | jq -r .status)
  case "$status" in
    successful) exit 0 ;;
    failed | error | canceled) echo "project ${PROJECT_ID}: sync ${status}" >&2; exit 1 ;;
  esac
  sleep 3
done
echo "project ${PROJECT_ID}: sync timed out" >&2
exit 1
