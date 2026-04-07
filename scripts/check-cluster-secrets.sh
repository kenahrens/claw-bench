#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

namespace="${NAMESPACE:-claw-bench}"
require_github_token="${REQUIRE_GITHUB_TOKEN:-false}"
require_openai_key="${REQUIRE_OPENAI_KEY:-false}"
require_anthropic_key="${REQUIRE_ANTHROPIC_KEY:-false}"

if ! [[ "${require_github_token}" =~ ^(true|false)$ ]]; then
  echo "error: REQUIRE_GITHUB_TOKEN must be true or false" >&2
  exit 1
fi

if ! [[ "${require_openai_key}" =~ ^(true|false)$ ]]; then
  echo "error: REQUIRE_OPENAI_KEY must be true or false" >&2
  exit 1
fi

if ! [[ "${require_anthropic_key}" =~ ^(true|false)$ ]]; then
  echo "error: REQUIRE_ANTHROPIC_KEY must be true or false" >&2
  exit 1
fi

llm_key_b64="$(kctl get secret claw-secrets -n "${namespace}" -o jsonpath='{.data.llm_api_key}' 2>/dev/null || true)"
github_token_b64="$(kctl get secret claw-secrets -n "${namespace}" -o jsonpath='{.data.github_token}' 2>/dev/null || true)"
openai_key_b64="$(kctl get secret claw-secrets -n "${namespace}" -o jsonpath='{.data.openai_api_key}' 2>/dev/null || true)"
anthropic_key_b64="$(kctl get secret claw-secrets -n "${namespace}" -o jsonpath='{.data.anthropic_api_key}' 2>/dev/null || true)"

if [[ -z "${llm_key_b64}" || "${llm_key_b64}" == "ZHVtbXk=" || "${llm_key_b64}" == "UkVQTEFDRV9NRQ==" ]]; then
  echo "error: secret claw-secrets.llm_api_key missing or placeholder in namespace ${namespace}" >&2
  exit 1
fi

if [[ "${require_github_token}" == "true" ]]; then
  if [[ -z "${github_token_b64}" || "${github_token_b64}" == "ZHVtbXk=" || "${github_token_b64}" == "UkVQTEFDRV9NRQ==" ]]; then
    echo "error: secret claw-secrets.github_token missing or placeholder in namespace ${namespace}" >&2
    exit 1
  fi
fi

if [[ "${require_openai_key}" == "true" ]]; then
  if [[ -z "${openai_key_b64}" || "${openai_key_b64}" == "ZHVtbXk=" || "${openai_key_b64}" == "UkVQTEFDRV9NRQ==" ]]; then
    echo "error: secret claw-secrets.openai_api_key missing or placeholder in namespace ${namespace}" >&2
    exit 1
  fi
fi

if [[ "${require_anthropic_key}" == "true" ]]; then
  if [[ -z "${anthropic_key_b64}" || "${anthropic_key_b64}" == "ZHVtbXk=" || "${anthropic_key_b64}" == "UkVQTEFDRV9NRQ==" ]]; then
    echo "error: secret claw-secrets.anthropic_api_key missing or placeholder in namespace ${namespace}" >&2
    exit 1
  fi
fi

echo "verified claw-secrets in namespace ${namespace}"
