#!/usr/bin/env sh
set -eu

prompt="${TASK_PROMPT:-}"
provider="${DEFAULT_PROVIDER:-openai}"
model="${DEFAULT_MODEL:-gpt-5-mini}"
api_key="${LLM_API_KEY:-}"

if [ -z "${prompt}" ]; then
  echo "error: TASK_PROMPT is required" >&2
  exit 1
fi

if [ -z "${api_key}" ]; then
  echo "error: LLM_API_KEY is required" >&2
  exit 1
fi

api_base="https://api.openai.com/v1"
if [ "${provider}" = "openrouter" ]; then
  api_base="https://openrouter.ai/api/v1"
fi

mkdir -p /home/picoclaw/.picoclaw
printf '{"agents":{"defaults":{"model_name":"bench","temperature":1}},"model_list":[{"model_name":"bench","model":"%s/%s","api_key":"%s","api_base":"%s","temperature":1}]}' \
  "${provider}" "${model}" "${api_key}" "${api_base}" > /home/picoclaw/.picoclaw/config.json

exec picoclaw agent --model bench -m "${prompt}"
