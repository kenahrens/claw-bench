#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

mkdir -p results/raw

collect_request_timeout="${COLLECT_REQUEST_TIMEOUT:-20s}"

if ! [[ "${collect_request_timeout}" =~ ^[0-9]+s$ ]]; then
  echo "error: COLLECT_REQUEST_TIMEOUT must use seconds format like 20s" >&2
  exit 1
fi

# Collect logs from all daemon deployments
daemon_names="$(kctl get deployments -n claw-bench -l claw.mode=daemon -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)"

if [[ -z "${daemon_names}" ]]; then
  echo "no daemon deployments found in claw-bench namespace"
  exit 0
fi

while IFS= read -r daemon_name; do
  [[ -z "${daemon_name}" ]] && continue

  pod_name="$(kctl get pods -n claw-bench -l app="${daemon_name}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "${pod_name}" ]]; then
    continue
  fi

  # Stream recent logs from the daemon pod (last task run)
  # Daemon pods run tail -f /dev/null normally; logs come from kubectl exec sessions
  # which are captured by submit-daemon-task.sh, so this is a fallback
  out_file="results/raw/${daemon_name}-pod-logs.txt"
  kctl logs "${pod_name}" -n claw-bench --timestamps --tail=1000 --request-timeout="${collect_request_timeout}" > "${out_file}" 2>/dev/null || true
done <<< "${daemon_names}"

echo "collected logs under results/raw/"
