#!/usr/bin/env bash
set -euo pipefail

if [[ "$(kubectl config current-context)" != "minikube" ]]; then
  echo "warning: current kubectl context is not minikube"
fi

manifest="$(./scripts/render-job.sh)"
job_name="$(printf '%s\n' "${manifest}" | awk '/^  name:/ {print $2; exit}')"

printf '%s\n' "${manifest}" | kubectl apply -f -
kubectl wait --for=condition=complete --timeout=30m "job/${job_name}" -n claw-bench || true
kubectl logs "job/${job_name}" -n claw-bench --timestamps | tee "results/${job_name}.txt"

echo "saved logs to results/${job_name}.txt"
