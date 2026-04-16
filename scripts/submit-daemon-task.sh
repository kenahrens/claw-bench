#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

IFS=$'\t' read -r resolved_task_id resolved_task_instruction < <(
  TASK_REF="${TASK_REF:-}" TASK_ID="${TASK_ID:-}" TASK_INSTRUCTION="${TASK_INSTRUCTION:-}" ./scripts/resolve-task.sh
)

namespace="${NAMESPACE:-claw-bench}"
agent_name="${AGENT_NAME:?AGENT_NAME is required}"
daemon_name="${DAEMON_NAME:-${agent_name}-daemon}"
task_timeout="${TASK_TIMEOUT:-10m}"
raw_results_dir="results/raw"

# Find the agent runner script
agent_runner="${script_dir}/agents/${agent_name}.sh"
if [[ ! -f "${agent_runner}" ]]; then
  echo "error: no task runner found for agent ${agent_name} at ${agent_runner}" >&2
  exit 1
fi

# Find the running pod
pod_name="$(kctl get pods -n "${namespace}" -l app="${daemon_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${pod_name}" ]]; then
  echo "error: no pod found for daemon ${daemon_name}; run deploy-daemon.sh first" >&2
  exit 1
fi

# Copy the agent runner script into the pod
kctl cp "${agent_runner}" "${namespace}/${pod_name}:/tmp/agent-task.sh" -c agent
kctl exec "${pod_name}" -n "${namespace}" -c agent -- chmod +x /tmp/agent-task.sh

# Submit the task via kubectl exec
# The runner script reads TASK_INSTRUCTION from the environment
task_suffix="$(printf '%s' "${resolved_task_id}" | tr '[:upper:]' '[:lower:]')"
log_path="${raw_results_dir}/${daemon_name}-${task_suffix}-daemon-$(date +%s).txt"
mkdir -p "${raw_results_dir}"

echo "[submit] running task ${resolved_task_id} on ${daemon_name} (pod ${pod_name})"

set +e
# Base64-encode the task instruction to avoid shell injection risks
b64_instruction="$(printf '%s' "${resolved_task_instruction}" | base64)"
kctl exec "${pod_name}" -n "${namespace}" -c agent -- \
  sh -c "TASK_INSTRUCTION=\$(echo '${b64_instruction}' | base64 -d) /tmp/agent-task.sh" 2>&1 | tee "${log_path}"
exit_code=$?
set -e

if [[ ${exit_code} -ne 0 ]]; then
  echo "error: task ${resolved_task_id} failed on ${daemon_name} (exit ${exit_code})" >&2
  exit 1
fi

echo "saved task output to ${log_path}"
