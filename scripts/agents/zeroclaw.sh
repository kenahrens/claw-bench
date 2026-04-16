#!/usr/bin/env sh
set -eu

# zeroclaw task runner — invoked via kubectl exec
# Runs one task directly via zero-claw

task_instruction="${TASK_INSTRUCTION:?TASK_INSTRUCTION is required}"

# Run the task directly
zero-claw run "${task_instruction}"

# Signal completion for log collection
echo "TASK_COMPLETE"
