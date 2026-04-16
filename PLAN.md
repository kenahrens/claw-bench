# Implementation Plan

- [x] Review existing Kubernetes scaffold and confirm gaps against the 2026 Claw evaluation goals.
- [x] Add a canonical evaluation matrix artifact for repeatable benchmark runs.
- [x] Keep job templates aligned on fair limits (`1 CPU`, `512Mi`) and non-root execution.
- [x] Add configurable command/bin support so each runtime can be invoked without template forks.
- [x] Implement Kubernetes egress cage workflow that enforces allowlisted LLM/GitHub destinations.
- [x] Support optional dependency egress for package registries when explicitly enabled.
- [x] Add matrix orchestration script to run all agents against the task suite with repeat support.
- [x] Update operator workflow in README for setup, egress policy application, single run, matrix run, and log collection.
- [x] Validate changed scripts and manifests in-repo before handoff.
- [x] Add setup hardening to require real credentials and prevent placeholder secret runs.
- [x] Add workspace sync automation so benchmark jobs run against the expected repository contents.
- [x] Add ZeroClaw daemon-mode benchmark track using Kubernetes deployment + service templates.
- [x] Add daemon lifecycle scripts to deploy/pair, submit HTTP tasks, and remove daemon resources.
- [x] Document daemon-mode workflow in README as a separate steady-state benchmark path.
- [x] Add standard task aliases (`TASK_1`, `TASK_2`, ...) for simpler benchmark execution.
- [x] Add make targets for indexed job and daemon task runs without per-run instruction env vars.
- [x] Add an easy-button workflow that performs setup + run with sensible defaults in one command.
- [x] Add an easy matrix workflow that runs setup + matrix execution in one command.
- [x] Add benchmark scoring workflow for success rate, median, and p95 from `results/` artifacts.

## Revised Multi-Agent Plan

- [x] Add matrix preflight to verify each configured agent image is runnable before execution.
- [x] Generate an explicit availability report so unsupported/private images are visible up front.
- [x] Skip unavailable agents by default (with optional strict mode) so comparisons proceed with available agents.
- [x] Expose one-command multi-agent run path that defaults to all configured agents.
- [x] Keep zero-touch command for users while surfacing exactly what still blocks full-matrix comparisons.

## Automation-First Reset Plan

- [x] Replace ad-hoc env-var driven runs with a single checked-in run profile file (`config/eval.env`) plus one command.
- [x] Add `make factory` to execute end-to-end evaluation: setup -> preflight -> run all agents across 5 standard tasks -> collect -> score.
- [x] Lock a canonical 5-task suite dedicated to cross-agent comparison (stable IDs, instructions, and repeat defaults).
- [x] Add agent capability manifest (`config/agents-capabilities.csv`) for command contract, interactive behavior, and required flags per runtime.
- [x] Add non-interactive safety policy per agent (approval bypass, max tool iterations, timeout policy) so runs do not hang.
- [x] Add preflight gate that fails early when required images/credentials are missing for the selected comparison mode.
- [x] Produce a single final comparison artifact (`results/factory-summary.json`) with per-agent pass/fail, success rate, median, p95, and failure reasons.
- [x] Add a `make doctor` diagnostic to print exactly what is blocking a full-matrix benchmark before running.

## Post-Reset Milestones

- [x] M1: Add hard matrix budget controls (`MAX_TOTAL_RUNS`, `MAX_FAILED_RUNS`, `MAX_WALL_CLOCK_MIN`, optional `MAX_ANTHROPIC_RUNS`) and keep fail-fast/cleanup defaults on.
- [x] M2: Add Track A portability sweep with standardized failure taxonomy output.
- [x] M3: Add Track B deterministic coding fixtures and objective score gates.
- [x] M4: Publish one canonical run snapshot and findings package.

## Jobs-to-Deployments Conversion

- [x] Convert all agents from Kubernetes Jobs to long-lived Deployments (daemon-only mode).
- [x] Create generic Deployment template (`k8s/templates/deployment-agent.yaml`) with `tail -f /dev/null` entrypoint.
- [x] Create per-agent task runner scripts (`scripts/agents/`) invoked via `kubectl exec`.
- [x] Generalize `deploy-daemon.sh` to support all agents (not just ZeroClaw).
- [x] Generalize `submit-daemon-task.sh` for kubectl exec task submission.
- [x] Rewrite `run-task.sh` for daemon/Deployment mode (auto-deploy + submit task).
- [x] Rewrite `run-matrix.sh` for daemon mode (deploy daemons per agent, submit tasks).
- [x] Update `easy-button.sh` for daemon-only mode (remove EASY_MODE=job option).
- [x] Update `collect-logs.sh` to collect from daemon pods instead of Job pods.
- [x] Update `clean-bench.sh` to clean daemon deployments instead of Jobs.
- [x] Update `score-results.py` for daemon log patterns and TASK_COMPLETE marker.
- [x] Update `smoke-each.py` and `run-smoke-one.sh` for daemon mode.
- [x] Update `validate.sh` to check agent runner scripts and Deployment template.
- [x] Update `apply-egress-policy.sh` to target `claw.mode=daemon` label.
- [x] Update `build-findings-package.py` to use daemon mode instead of job mode.
- [x] Remove `config/agents.csv` template column (no longer needed).
- [x] Remove `EASY_MODE` from `config/eval.env` (daemon-only).
- [x] Delete all Job templates and `render-job.sh`.
- [x] Delete old zeroclaw-specific Deployment/Service templates.
- [x] Update Makefile (remove submit-daemon-task target, add daemon cleanup to bench-smoke).
- [x] Update README.md and PLAN.md documentation.

This conversion provides:
- Continuous SpeedScale eBPF capture data (no fragmented per-pod sessions).
- Production-accurate agent execution (claws run as long-lived processes, not batch Jobs).
- Simplified architecture (one Deployment template, one task submission mechanism).
