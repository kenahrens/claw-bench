#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

namespace="${NAMESPACE:-claw-bench}"
agent_name="${AGENT_NAME:?AGENT_NAME is required}"
agent_image="${AGENT_IMAGE:?AGENT_IMAGE is required}"
daemon_name="${DAEMON_NAME:-${agent_name}-daemon}"
daemon_port="${DAEMON_PORT:-8787}"
default_provider="${DEFAULT_PROVIDER:-openai}"
default_model="${DEFAULT_MODEL:-gpt-5-mini}"
max_tool_iterations="${MAX_TOOL_ITERATIONS:-40}"
approval_mode="${APPROVAL_MODE:-default}"
resource_cpu_request="${RESOURCE_CPU_REQUEST:-1}"
resource_cpu_limit="${RESOURCE_CPU_LIMIT:-1}"
resource_memory_request="${RESOURCE_MEMORY_REQUEST:-512Mi}"
resource_memory_limit="${RESOURCE_MEMORY_LIMIT:-512Mi}"

if ! [[ "${max_tool_iterations}" =~ ^[0-9]+$ ]] || [[ "${max_tool_iterations}" -lt 1 ]]; then
  echo "error: MAX_TOOL_ITERATIONS must be a positive integer" >&2
  exit 1
fi

if ! [[ "${approval_mode}" =~ ^(default|strict|none)$ ]]; then
  echo "error: APPROVAL_MODE must be default, strict, or none" >&2
  exit 1
fi

# Per-agent home directory
case "${agent_name}" in
  openclaw|nemoclaw) AGENT_HOME="/home/node" ;;
  picoclaw) AGENT_HOME="/home/picoclaw" ;;
  *) AGENT_HOME="/home/node" ;;
esac

# Remove any existing deployment for this daemon
if kctl get deployment "${daemon_name}" -n "${namespace}" >/dev/null 2>&1; then
  echo "[deploy-daemon] removing existing deployment ${daemon_name}"
  kctl delete deployment "${daemon_name}" -n "${namespace}" --ignore-not-found >/dev/null 2>&1 || true
  sleep 2
fi

export DAEMON_NAME AGENT_NAME AGENT_IMAGE AGENT_HOME DAEMON_PORT DEFAULT_PROVIDER DEFAULT_MODEL \
  MAX_TOOL_ITERATIONS APPROVAL_MODE RESOURCE_CPU_REQUEST RESOURCE_CPU_LIMIT \
  RESOURCE_MEMORY_REQUEST RESOURCE_MEMORY_LIMIT

envsubst < k8s/templates/deployment-agent.yaml | kctl apply -f -

echo "[deploy-daemon] waiting for ${daemon_name} rollout"
kctl rollout status "deployment/${daemon_name}" -n "${namespace}" --timeout=180s

echo "deployed ${daemon_name} (agent=${agent_name}, image=${agent_image})"
