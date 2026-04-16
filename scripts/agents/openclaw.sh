#!/usr/bin/env sh
set -eu

# openclaw task runner — invoked via kubectl exec
# Runs one task, syncs workspace before and after

task_instruction="${TASK_INSTRUCTION:?TASK_INSTRUCTION is required}"
default_provider="${DEFAULT_PROVIDER:-openai}"
default_model="${DEFAULT_MODEL:-gpt-5-mini}"

# Setup: copy workspace to openclaw's expected location
mkdir -p /home/node/.openclaw/workspace
cp -a /workspace/. /home/node/.openclaw/workspace/ >/dev/null 2>&1 || true

# Configure model and thinking
openclaw models set "${default_provider}/${default_model}" >/dev/null 2>&1 || true
openclaw config set agents.defaults.thinkingDefault low >/dev/null 2>&1 || true

# Run the task
openclaw agent --local --agent main -m "${task_instruction}" --json

# Sync modified files back to shared workspace
cp -a /home/node/.openclaw/workspace/. /workspace/ >/dev/null 2>&1 || true

# Signal completion for log collection
echo "TASK_COMPLETE"
