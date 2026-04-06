# claw-off-bench

Kubernetes-first benchmark harness for the 2026 Claw runtime shootout.

## Goals

- Benchmark agent runtimes on the same task suite.
- Enforce fair resource limits (`1 CPU`, `512Mi` memory).
- Capture artifacts for performance, density, and security analysis.
- Support restrictive ZeroClaw behavior with a compatibility job template.

## Layout

- `tasks/tasks.yaml`: benchmark task suite.
- `k8s/base`: namespace, pvc, secrets template, baseline network policy.
- `k8s/templates`: generic and ZeroClaw-specific Job manifests.
- `adapters/zeroclaw`: optional adapter image for restrictive runtime needs.
- `scripts`: render, run, and collect benchmark artifacts.

## Prereqs

- `kubectl`
- `minikube`
- `bash`
- `envsubst` (from `gettext`)

## Quickstart (Minikube)

1. Set context:

   ```bash
   kubectl config use-context minikube
   kubectl config current-context
   ```

2. Apply base resources:

   ```bash
   kubectl apply -f k8s/base/namespace.yaml
   kubectl apply -f k8s/base/pvc.yaml
   cp k8s/base/secrets.template.yaml k8s/base/secrets.yaml
   # edit k8s/base/secrets.yaml with real values
   kubectl apply -f k8s/base/secrets.yaml
   kubectl apply -f k8s/base/networkpolicy.yaml
   ```

3. Run one task (example):

   ```bash
   AGENT_NAME=zeroclaw \
   AGENT_IMAGE=zeroclaw-adapter:local \
   TASK_ID=T001 \
   TASK_INSTRUCTION="Fix failing unit tests and explain root cause" \
   ./scripts/run-task.sh
   ```

4. Collect logs:

   ```bash
   ./scripts/collect-logs.sh
   ```

## ZeroClaw notes

- Use `k8s/templates/job-zeroclaw.yaml` when the default template fails.
- This template keeps non-root and dropped caps, but allows writable root FS when needed.
- You can also use the adapter image in `adapters/zeroclaw` to normalize entrypoint and filesystem behavior.

## Next

- Expand `tasks/tasks.yaml` to your final evaluation matrix.
- Add scoring script for median/p95 across repeated runs.
- Publish findings using `docs/blog-draft.md` as the base.
