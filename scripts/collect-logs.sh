#!/usr/bin/env bash
set -euo pipefail

mkdir -p results

jobs="$(kubectl get jobs -n claw-bench -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
if [[ -z "${jobs}" ]]; then
  echo "no jobs found in claw-bench namespace"
  exit 0
fi

while IFS= read -r job; do
  [[ -z "${job}" ]] && continue
  kubectl logs "job/${job}" -n claw-bench --timestamps > "results/${job}.txt" || true
done <<< "${jobs}"

echo "collected logs under results/"
