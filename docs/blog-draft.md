# Draft: Claw-Off 2026 on Kubernetes

## Working title

Claw-Off 2026: Benchmarking Autonomous Coding Agents Under Tight Resource and Security Constraints

## Narrative arc

1. Why we ran the benchmark now.
2. Why Kubernetes Jobs over local Docker Compose.
3. How we enforced fairness (1 CPU / 512Mi per run).
4. How we handled restrictive ZeroClaw container behavior.
5. Performance, density, and security results.
6. Practical recommendations by workload profile.

## Data to capture

- Success rate per task category.
- Median and p95 task completion time.
- Resource consumption per completed task.
- Blocked egress attempts and policy exceptions.

## Closing takeaway

There is no universal best runtime. Agent choice depends on context size, security posture, and compute budget.
