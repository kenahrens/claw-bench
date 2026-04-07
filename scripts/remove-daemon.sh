#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

namespace="${NAMESPACE:-claw-bench}"
daemon_name="${DAEMON_NAME:-zeroclaw-daemon}"

kctl delete deployment "${daemon_name}" -n "${namespace}" --ignore-not-found >/dev/null
kctl delete service "${daemon_name}" -n "${namespace}" --ignore-not-found >/dev/null
kctl delete secret "${daemon_name}-auth" -n "${namespace}" --ignore-not-found >/dev/null

echo "removed daemon resources for ${daemon_name}"
