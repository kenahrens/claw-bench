#!/usr/bin/env sh
set -eu

# nanoclaw task runner — invoked via kubectl exec
# Runs one task via stdin JSON contract

task_instruction="${TASK_INSTRUCTION:?TASK_INSTRUCTION is required}"

# Build the payload via python3 for safe JSON serialization
mkdir -p /tmp/nanoclaw

payload="$(python3 -c 'import json,os; print(json.dumps({"prompt":os.environ["TASK_INSTRUCTION"],"groupFolder":"/tmp/nanoclaw","chatJid":"claw-bench","isMain":True,"options":{"pathToClaudeCodeExecutable":"/app/node_modules/.bin/anthropic-ai-sdk"}}))')"

printf '%s' "${payload}" | /app/entrypoint.sh

# Signal completion for log collection
echo "TASK_COMPLETE"
