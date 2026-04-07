#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kube.sh
source "${script_dir}/lib/kube.sh"

namespace="${NAMESPACE:-claw-bench}"
openai_api_key="${OPENAI_API_KEY:-${LLM_API_KEY:-${OPENROUTER_API_KEY:-}}}"
anthropic_api_key="${ANTHROPIC_API_KEY:-${LLM_API_KEY:-}}"
llm_api_key="${LLM_API_KEY:-${openai_api_key:-${anthropic_api_key:-}}}"
github_token="${GITHUB_TOKEN:-}"
require_github_token="${REQUIRE_GITHUB_TOKEN:-false}"

if [[ -z "${llm_api_key}" ]]; then
  echo "error: set OPENAI_API_KEY and/or ANTHROPIC_API_KEY (or LLM_API_KEY) before running setup-secrets" >&2
  exit 1
fi

if [[ -z "${openai_api_key}" ]]; then
  echo "warning: OPENAI_API_KEY not set; openai_api_key will reuse llm_api_key" >&2
  openai_api_key="${llm_api_key}"
fi

if [[ -z "${anthropic_api_key}" ]]; then
  echo "warning: ANTHROPIC_API_KEY not set; anthropic_api_key will reuse llm_api_key" >&2
  anthropic_api_key="${llm_api_key}"
fi

if [[ -z "${github_token}" ]]; then
  if [[ "${require_github_token}" == "true" ]]; then
    echo "error: set GITHUB_TOKEN before running setup-secrets" >&2
    exit 1
  fi
  github_token="chat-only-not-used"
  echo "warning: GITHUB_TOKEN not set; using chat-only placeholder token" >&2
fi

if [[ "${llm_api_key}" == "dummy" || "${llm_api_key}" == "REPLACE_ME" ]]; then
  echo "error: LLM_API_KEY cannot be a placeholder value" >&2
  exit 1
fi

if [[ "${openai_api_key}" == "dummy" || "${openai_api_key}" == "REPLACE_ME" ]]; then
  echo "error: OPENAI_API_KEY cannot be a placeholder value" >&2
  exit 1
fi

if [[ "${anthropic_api_key}" == "dummy" || "${anthropic_api_key}" == "REPLACE_ME" ]]; then
  echo "error: ANTHROPIC_API_KEY cannot be a placeholder value" >&2
  exit 1
fi

if [[ "${github_token}" == "dummy" || "${github_token}" == "REPLACE_ME" ]]; then
  echo "error: GITHUB_TOKEN cannot be a placeholder value" >&2
  exit 1
fi

kctl create secret generic claw-secrets \
  -n "${namespace}" \
  --from-literal=llm_api_key="${llm_api_key}" \
  --from-literal=openai_api_key="${openai_api_key}" \
  --from-literal=anthropic_api_key="${anthropic_api_key}" \
  --from-literal=github_token="${github_token}" \
  --dry-run=client -o yaml | kctl apply -f -

echo "applied claw-secrets in namespace ${namespace}"
