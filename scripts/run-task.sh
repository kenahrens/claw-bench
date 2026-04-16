#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

wait_timeout="${WAIT_TIMEOUT:-30m}"
require_github_token="${REQUIRE_GITHUB_TOKEN:-false}"
validate_result="${VALIDATE_RESULT:-false}"
track_b_eval="${TRACK_B_EVAL:-false}"
raw_results_dir="results/raw"
run_scope_file="${RUN_SCOPE_FILE:-results/current-run-jobs.txt}"

IFS=$'\t' read -r resolved_task_id resolved_task_instruction < <(
  TASK_REF="${TASK_REF:-}" TASK_ID="${TASK_ID:-}" TASK_INSTRUCTION="${TASK_INSTRUCTION:-}" ./scripts/resolve-task.sh
)

agent_name="${AGENT_NAME:?AGENT_NAME is required}"
agent_image="${AGENT_IMAGE:?AGENT_IMAGE is required}"
daemon_name="${DAEMON_NAME:-${agent_name}-daemon}"
default_provider="${DEFAULT_PROVIDER:-openai}"
default_model="${DEFAULT_MODEL:-gpt-5-mini}"
max_tool_iterations="${MAX_TOOL_ITERATIONS:-40}"
approval_mode="${APPROVAL_MODE:-default}"
resource_cpu_request="${RESOURCE_CPU_REQUEST:-1}"
resource_cpu_limit="${RESOURCE_CPU_LIMIT:-1}"
resource_memory_request="${RESOURCE_MEMORY_REQUEST:-512Mi}"
resource_memory_limit="${RESOURCE_MEMORY_LIMIT:-512Mi}"

export TASK_ID="${resolved_task_id}"
export TASK_INSTRUCTION="${resolved_task_instruction}"

echo "[run-task] kube context=${KUBE_CONTEXT:-minikube} agent=${agent_name} task=${TASK_ID}"
mkdir -p "${raw_results_dir}"
mkdir -p "$(dirname "${run_scope_file}")"

# Verify secrets exist
llm_key_b64="$(kctl get secret claw-secrets -n claw-bench -o jsonpath='{.data.llm_api_key}' 2>/dev/null || true)"
github_token_b64="$(kctl get secret claw-secrets -n claw-bench -o jsonpath='{.data.github_token}' 2>/dev/null || true)"

if [[ -z "${llm_key_b64}" || "${llm_key_b64}" == "ZHVtbXk=" || "${llm_key_b64}" == "UkVQTEFDRV9NRQ==" ]]; then
  echo "error: claw-secrets.llm_api_key is missing or placeholder; apply real credentials before running jobs" >&2
  exit 1
fi

if [[ "${require_github_token}" == "true" ]]; then
  if [[ -z "${github_token_b64}" || "${github_token_b64}" == "ZHVtbXk=" || "${github_token_b64}" == "UkVQTEFDRV9NRQ==" ]]; then
    echo "error: claw-secrets.github_token is missing or placeholder; apply real credentials before running jobs" >&2
    exit 1
  fi
fi

# Deploy the agent daemon if not already running
if ! kctl get deployment "${daemon_name}" -n claw-bench >/dev/null 2>&1; then
  echo "[run-task] deploying daemon ${daemon_name}"
  AGENT_NAME="${agent_name}" \
  AGENT_IMAGE="${agent_image}" \
  DAEMON_NAME="${daemon_name}" \
  DEFAULT_PROVIDER="${default_provider}" \
  DEFAULT_MODEL="${default_model}" \
  MAX_TOOL_ITERATIONS="${max_tool_iterations}" \
  APPROVAL_MODE="${approval_mode}" \
  RESOURCE_CPU_REQUEST="${resource_cpu_request}" \
  RESOURCE_CPU_LIMIT="${resource_cpu_limit}" \
  RESOURCE_MEMORY_REQUEST="${resource_memory_request}" \
  RESOURCE_MEMORY_LIMIT="${resource_memory_limit}" \
  ./scripts/deploy-daemon.sh
else
  echo "[run-task] daemon ${daemon_name} already running"
fi

# Record the run scope
printf '%s\n' "${daemon_name}-${TASK_ID}" >> "${run_scope_file}"

# Submit the task
task_timeout="${wait_timeout}"
TASK_TIMEOUT="${task_timeout}" \
AGENT_NAME="${agent_name}" \
DAEMON_NAME="${daemon_name}" \
TASK_ID="${TASK_ID}" \
TASK_INSTRUCTION="${TASK_INSTRUCTION}" \
./scripts/submit-daemon-task.sh

# Find the log file produced by submit-daemon-task.sh
task_suffix="$(printf '%s' "${TASK_ID}" | tr '[:upper:]' '[:lower:]')"
log_path="$(ls -t "${raw_results_dir}/${daemon_name}-${task_suffix}-daemon-"*.txt 2>/dev/null | head -1 || true)"

if [[ -z "${log_path}" ]]; then
  echo "error: no log file found for ${daemon_name} ${TASK_ID}" >&2
  exit 1
fi

if ! [[ "${track_b_eval}" =~ ^(true|false)$ ]]; then
  echo "error: TRACK_B_EVAL must be true or false" >&2
  exit 1
fi

if [[ "${validate_result}" == "true" ]]; then
  if ! RUN_LOG_PATH="${log_path}" python3 - <<'PY'
import os
import re
import sys

path = os.environ["RUN_LOG_PATH"]
text = open(path, encoding="utf-8", errors="replace").read()

hard_fail_markers = [
    "authentication_error",
    "Invalid API key",
    "LLM call failed",
    "error processing message",
    "Unsupported value:",
    "stopReason\": \"error\"",
]

for marker in hard_fail_markers:
    if marker in text:
        print(f"[run-task] detected error marker: {marker}", file=sys.stderr)
        sys.exit(1)

if re.search(r'"payloads"\s*:\s*\[\s*\]\s*,\s*"meta"', text):
    print("[run-task] detected empty payload result", file=sys.stderr)
    sys.exit(1)

sys.exit(0)
PY
  then
    echo "error: result validation failed for ${daemon_name} ${TASK_ID}" >&2
    exit 1
  fi
fi

if [[ "${track_b_eval}" == "true" ]]; then
  if ! JOB_NAME="${daemon_name}-${TASK_ID}" TASK_ID="${TASK_ID}" ./scripts/evaluate-track-b.sh; then
    echo "error: Track B evaluation gate failed for ${daemon_name} ${TASK_ID}" >&2
    exit 1
  fi
fi

echo "saved logs to ${log_path}"
