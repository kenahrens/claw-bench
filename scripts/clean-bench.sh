#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

namespace="${NAMESPACE:-claw-bench}"
clean_results="${CLEAN_RESULTS:-true}"

if ! [[ "${clean_results}" =~ ^(true|false)$ ]]; then
  echo "error: CLEAN_RESULTS must be true or false" >&2
  exit 1
fi

echo "[clean] remove daemon resources"
./scripts/remove-daemon.sh >/dev/null 2>&1 || true

echo "[clean] remove daemon deployments"
kctl delete deployments -n "${namespace}" -l claw.mode=daemon --ignore-not-found >/dev/null 2>&1 || true

echo "[clean] remove runner pods"
kctl delete pods -n "${namespace}" -l claw.mode=daemon --ignore-not-found >/dev/null 2>&1 || true

echo "[clean] remove old local result artifacts"
if [[ "${clean_results}" == "true" ]]; then
  rm -f results/*.json results/*.tsv
  rm -f results/current-run-jobs.txt
  rm -rf results/raw
fi

echo "cleaned benchmark run state"
