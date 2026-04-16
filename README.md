# claw-bench

Kubernetes-first benchmark harness for the 2026 Claw runtime evaluation.

## Objective

Run a standardized autonomous-coding benchmark across the configured Claw runtimes while measuring:

- Performance
- Density
- Security

Runs use per-agent safety limits from `config/agents-safety.csv`, non-root security context, and network egress restrictions.

## Evaluation Matrix

The benchmark matrix is tracked in `config/agents.csv`.

## Repository Layout

- `config/agents.csv`: runtime matrix and image mapping.
- `config/agents-capabilities.csv`: per-agent command/interaction capability manifest.
- `config/agents-safety.csv`: per-agent timeout, approval mode, and tool-iteration policy.
- `config/eval.env`: checked-in run profile for one-command evaluation.
- `tasks/tasks.yaml`: benchmark task suite.
- `k8s/base`: namespace, PVC, secrets template, baseline deny policy.
- `k8s/templates`: agent Deployment manifest for daemon-mode execution.
- `scripts`: setup, policy generation, run orchestration, and log collection.
- `scripts/agents`: per-agent task runner scripts invoked via `kubectl exec`.
- `adapters/zeroclaw`: optional adapter image for restrictive runtime behavior.
- `adapters/picoclaw`: optional adapter image with symbol-enabled build for PicoClaw.

## Security and Isolation

`k8s/base/networkpolicy.yaml` applies a baseline deny policy.

`scripts/apply-egress-policy.sh` applies a generated egress allowlist policy for:

- `api.anthropic.com`
- `api.openai.com`
- `github.com`
- `api.github.com`
- Optional: `pypi.org` and `registry.npmjs.org` when `ALLOW_PACKAGE_REGISTRIES=true`

The policy also allows egress to the SpeedScale forwarder in the `speedscale` namespace for observability.

The policy resolves current A records and restricts daemon pods (`claw.mode=daemon`) to DNS + HTTPS on allowlisted destinations.

## Prereqs

- `kubectl`
- `minikube` (or another cluster/context)
- `bash`
- `envsubst` (from `gettext`)
- `dig` (for egress allowlist resolution)

## Quickstart

Use only these commands:

1. `make validate` - fast non-cluster validation (scripts/config/render checks).
2. `make bench-init` - one-time bootstrap + verify cluster secrets.
3. `make bench-smoke` - cheap synthetic canary (expects `SMOKE_OK`).
4. `make bench-run` - full clean end-to-end comparison run.
5. `make bench-report` - collect + score + summary (`results/factory-summary.json`).
6. `make smoke-each` - manual-first hello-world readiness report (`results/smoke-readiness.json`).
7. `make smoke-one AGENT_NAME=<agent> SMOKE_PROVIDER=<provider>` - single-agent single-provider hello check.
8. `make portability-sweep` - Track A compatibility sweep with taxonomy output (`results/portability-sweep.tsv`, `results/portability-sweep.json`).
9. `make track-b-baseline` - Track B deterministic fixture baseline with objective gates (`results/track-b-summary.json`).
10. `make consistency-check` - repeatability gate that runs full scenario multiple times and compares normalized signatures (`results/consistency/run*/signature.json`).
11. `make findings-package` - M4 publication package (`results/canonical-run-snapshot.json`, `results/findings-table.csv`, `results/findings-log-excerpts.md`, `results/findings-blog-draft.md`).

Optional helper commands:

- `make bench-help` - print the simple command set.
- `make bench-reset` - clean run state without running a benchmark.
- `PORTABILITY_PROVIDERS=openai,anthropic make portability-sweep` to choose provider lanes.
- `TASKS_FILE=tasks/track-b-tasks.yaml TRACK_B_EVAL=true make run-matrix` for direct Track B matrix execution.

That is the intended user interface. Everything else is internal/advanced.

## Advanced Commands

Use these only when you need lower-level control:

- `make compare` / `make factory`: direct end-to-end orchestration entrypoints.
- `make setup-stage`: run setup + preflight only.
- `make bootstrap`: one-time cluster setup and local adapter build cache.
- Legacy granular targets: `setup`, `setup-secrets`, `sync-workspace`, `setup-egress`, `build-zeroclaw-adapter`, `run-matrix`, `collect`, `score`.

Matrix notes:

- `scripts/run-matrix.sh` performs image preflight and writes `results/matrix-preflight.tsv`.
- `scripts/run-matrix.sh` defaults to a fast lane (`TASK_FILTER=T001,T002`, `FAIL_FAST=true`) for quicker iteration.
- `scripts/preflight-gate.sh` enforces credentials/image readiness for the selected comparison mode before matrix execution.
- `make doctor` prints blockers for a full-matrix run before execution.
- Unavailable agents are skipped by default so available agents still run.
- Set `MATRIX_STRICT=true` to fail when any configured agent is unavailable.
- Set `COMPARISON_MODE=full` to require all configured agents before running.
- Set `TASK_FILTER=` (empty) to run all tasks, or provide a list like `TASK_FILTER=T001,T002,T003`.
- Override task source with `TASKS_FILE=...` (default `tasks/tasks.yaml`), e.g. `tasks/track-b-tasks.yaml`.
- Set `FAIL_FAST=false` only when you intentionally want to continue after failures.

- Budget guardrails are enforced when set: `MAX_TOTAL_RUNS`, `MAX_FAILED_RUNS`, `MAX_WALL_CLOCK_MIN`, `MAX_ANTHROPIC_RUNS` (`0` disables a guardrail).
- `preflight-gate` is strict by default: it verifies guardrails are set and runs per-agent smoke contract checks (`RUN_SMOKE_CONTRACTS=true`) before full matrix execution.
- Enable deterministic Track B score gates with `TRACK_B_EVAL=true`; each run writes `results/raw/<job>-trackb-eval.json`.
- Track B completion requires the marker `TRACK_B_DONE`; missing marker is classified as `contract mismatch`.
- Track B enforces edit policy: only `src/` may change; edits to `tests/` or `hidden_tests/` are classified as `contract mismatch`.
- Set `TRACK_B_RESET_WORKSPACE=true` to re-sync the workspace before every run (enabled by default in `make track-b-baseline`).
- Use `make matrix-preflight` to run only the availability check.
- To compare the full matrix, ensure every image in `config/agents.csv` is pullable from your environment. Note: `picoclaw-symbols:latest` and `zeroclaw-adapter:latest` are built locally (via `make build-picoclaw-symbols` / `make build-zeroclaw-adapter`); other agent images are pulled from remote registries.
- `nemoclaw` is configured as `nemoclaw:latest` and may require building a local image from `https://github.com/NVIDIA/NemoClaw`.

## Daemon-Only Architecture

All agents run as long-lived Kubernetes Deployments (daemons), not one-shot Jobs. This matches how claws run in production and provides continuous SpeedScale eBPF capture data.

1. `make deploy-daemon AGENT_NAME=<agent>` — deploys a daemon for any configured agent.
2. Tasks are submitted via `kubectl exec`, which invokes the agent's task runner script (`scripts/agents/<agent>.sh`).
3. Each agent runs in a pod that stays alive (`tail -f /dev/null`); tasks execute inside the running container.
4. `make remove-daemon AGENT_NAME=<agent>` — tears down the daemon deployment.

Notes:

- The generic Deployment template is `k8s/templates/deployment-agent.yaml`.
- Per-agent task runners live in `scripts/agents/` (e.g., `scripts/agents/zeroclaw.sh`).
- Daemon pods share a workspace PVC at `/workspace`.
- SpeedScale eBPF capture annotations are applied to all daemon pods for continuous observability.

## Notes

- `claw-secrets` should contain `openai_api_key`, `anthropic_api_key`, `llm_api_key`, and `github_token`.
- Use `scripts/setup-secrets.sh` with `OPENAI_API_KEY` and `ANTHROPIC_API_KEY` for mixed-provider runs.
- `make smoke-one` is the recommended contract-debug path: it runs one agent daemon at a time and blocks on failures.

- Each agent has a task runner in `scripts/agents/` that handles its specific invocation contract.
- The generic Deployment template applies non-root, dropped caps, and writable tmp/home volumes.
- Raw per-run logs and gate outputs are written to `results/raw/` for post-run scoring and analysis.
- Scoring is scoped to the active run set using `results/current-run-jobs.txt`.
- All agents run in daemon (Deployment) mode — there are no Job-based execution paths.
- Final comparison summary is written to `results/factory-summary.json`.
- Track B fixture mapping lives in `config/track-b-fixtures.csv` and deterministic fixture tasks live in `tasks/track-b-tasks.yaml`.

## Strategy Reset (Next)

The next iteration shifts from command-by-command execution to a factory workflow:

- one config file for run inputs (`config/eval.env`), not per-command env churn
- one command (`make factory`) that runs setup, preflight, full multi-agent task execution, collection, and scoring
- one diagnostic command (`make doctor`) that explains blockers for full-matrix comparison before execution
- one final artifact (`results/factory-summary.json`) for direct agent comparison

`make eval` now provides a profile-driven one-command entrypoint using `config/eval.env`.

`make factory` now provides an end-to-end run path: setup, matrix preflight, matrix execution, log collection, and scoring.

The remaining factory follow-up work is focused on ongoing benchmark operations and blocker clarity for full-matrix comparisons.
