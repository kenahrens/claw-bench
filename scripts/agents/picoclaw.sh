#!/usr/bin/env sh
set -eu

# picoclaw task runner — invoked via kubectl exec
# Runs one task via picoclaw agent

task_instruction="${TASK_INSTRUCTION:?TASK_INSTRUCTION is required}"
default_provider="${DEFAULT_PROVIDER:-openai}"
default_model="${DEFAULT_MODEL:-gpt-4o-mini}"
api_key="${OPENAI_API_KEY:-${LLM_API_KEY:-}}"
temperature="${PICOCLAW_TEMPERATURE:-1}"

if [ -z "${api_key}" ]; then
  echo "error: OPENAI_API_KEY or LLM_API_KEY is required" >&2
  exit 1
fi

api_base="https://api.openai.com/v1"
if [ "${default_provider}" = "openrouter" ]; then
  api_base="https://openrouter.ai/api/v1"
fi

# Write picoclaw config
mkdir -p /home/picoclaw/.picoclaw
printf '{"agents":{"defaults":{"model_name":"bench","temperature":%s}},"model_list":[{"model_name":"bench","model":"%s/%s","api_key":"%s","api_base":"%s","temperature":%s}]}' \
  "${temperature}" "${default_provider}" "${default_model}" "${api_key}" "${api_base}" "${temperature}" \
  > /home/picoclaw/.picoclaw/config.json

# Run the task
exec picoclaw agent --model bench -m "${task_instruction}"
