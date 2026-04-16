#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

namespace="${NAMESPACE:-claw-bench}"
agent_name="${AGENT_NAME:-}"
daemon_name="${DAEMON_NAME:-}"

# Support removing a specific daemon or all daemon deployments
if [[ -n "${daemon_name}" ]]; then
  kctl delete deployment "${daemon_name}" -n "${namespace}" --ignore-not-found >/dev/null
  kctl delete secret "${daemon_name}-auth" -n "${namespace}" --ignore-not-found >/dev/null 2>&1 || true
  echo "removed daemon resources for ${daemon_name}"
elif [[ -n "${agent_name}" ]]; then
  daemon_name="${agent_name}-daemon"
  kctl delete deployment "${daemon_name}" -n "${namespace}" --ignore-not-found >/dev/null
  kctl delete secret "${daemon_name}-auth" -n "${namespace}" --ignore-not-found >/dev/null 2>&1 || true
  echo "removed daemon resources for ${daemon_name}"
else
  # Remove all daemon deployments in the namespace
  kctl delete deployments -n "${namespace}" -l claw.mode=daemon --ignore-not-found >/dev/null
  kctl delete secrets -n "${namespace}" -l claw.mode=daemon --ignore-not-found >/dev/null 2>&1 || true
  echo "removed all daemon deployments in ${namespace}"
fi
