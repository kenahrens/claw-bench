#!/usr/bin/env python3
import csv
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


RESULTS_DIR = Path("results")
AGENTS_FILE = Path("config/agents.csv")
PREFLIGHT_FILE = RESULTS_DIR / "matrix-preflight.tsv"
SCORE_FILE = RESULTS_DIR / "score.json"
OUT_FILE = RESULTS_DIR / "factory-summary.json"


def load_agents():
    if not AGENTS_FILE.exists():
        return []
    with AGENTS_FILE.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def load_preflight():
    rows = {}
    if not PREFLIGHT_FILE.exists():
        return rows
    with PREFLIGHT_FILE.open(encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            agent = row.get("agent", "").strip()
            if agent:
                rows[agent] = {
                    "status": row.get("status", "unknown").strip() or "unknown",
                    "reason": row.get("reason", "").strip(),
                    "image": row.get("image", "").strip(),
                }
    return rows


def load_score():
    if not SCORE_FILE.exists():
        return {"summary": [], "runs": []}
    return json.loads(SCORE_FILE.read_text(encoding="utf-8"))


def classify_failure(text: str):
    patterns = [
        (
            "rate_limit",
            r"\b429\b|rate[- ]limit|free-models-per-day|temporarily rate-limited",
        ),
        ("oom", r"out of memory|reached heap limit|oom"),
        ("missing_binary", r"executable file not found|command not found"),
        (
            "security_policy",
            r"command not allowed by security policy|blocked by security policy",
        ),
        (
            "missing_inputs",
            r"no files matching pattern|no project files|workspace currently contains no",
        ),
        ("image_pull", r"imagepullbackoff|manifest unknown|pull access denied|denied"),
    ]
    for label, pattern in patterns:
        if re.search(pattern, text, flags=re.IGNORECASE):
            return label
    if re.search(r"\berror\b|\bfailed\b", text, flags=re.IGNORECASE):
        return "runtime_error"
    return "unknown"


def summarize_failures(runs):
    reasons = Counter()
    for run in runs:
        if run.get("success"):
            continue
        path = Path(run.get("file", ""))
        if not path.exists():
            reasons["missing_log"] += 1
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        reasons[classify_failure(text)] += 1
    return [
        {"reason": reason, "count": count} for reason, count in reasons.most_common()
    ]


def main():
    RESULTS_DIR.mkdir(exist_ok=True)
    agents = load_agents()
    preflight = load_preflight()
    score = load_score()

    score_summary = {
        (row["agent"], row["mode"]): row for row in score.get("summary", [])
    }
    runs_by_agent = {}
    for run in score.get("runs", []):
        runs_by_agent.setdefault(run.get("agent"), []).append(run)

    per_agent = []
    for row in agents:
        agent = row.get("agent", "")
        if not agent:
            continue

        pre = preflight.get(
            agent,
            {
                "status": "unknown",
                "reason": "no preflight row",
                "image": row.get("image", ""),
            },
        )
        job_stats = score_summary.get((agent, "job"), {})
        daemon_stats = score_summary.get((agent, "daemon"), {})
        runs = runs_by_agent.get(agent, [])

        per_agent.append(
            {
                "agent": agent,
                "image": row.get("image", ""),
                "preflight_status": pre.get("status", "unknown"),
                "preflight_reason": pre.get("reason", ""),
                "job": {
                    "runs": job_stats.get("runs", 0),
                    "success_count": job_stats.get("success_count", 0),
                    "success_rate": job_stats.get("success_rate", 0.0),
                    "median_duration_seconds": job_stats.get("median_duration_seconds"),
                    "p95_duration_seconds": job_stats.get("p95_duration_seconds"),
                },
                "daemon": {
                    "runs": daemon_stats.get("runs", 0),
                    "success_count": daemon_stats.get("success_count", 0),
                    "success_rate": daemon_stats.get("success_rate", 0.0),
                },
                "failure_reasons": summarize_failures(runs),
            }
        )

    blockers = []
    unavailable = [x for x in per_agent if x["preflight_status"] == "unavailable"]
    if unavailable:
        blockers.append(
            {
                "type": "image_availability",
                "count": len(unavailable),
                "agents": [x["agent"] for x in unavailable],
            }
        )

    unknown_preflight = [x for x in per_agent if x["preflight_status"] == "unknown"]
    if unknown_preflight:
        blockers.append(
            {
                "type": "missing_preflight_data",
                "count": len(unknown_preflight),
                "agents": [x["agent"] for x in unknown_preflight],
            }
        )

    no_success = [
        x for x in per_agent if x["job"]["runs"] > 0 and x["job"]["success_count"] == 0
    ]
    if no_success:
        blockers.append(
            {
                "type": "zero_success_runs",
                "count": len(no_success),
                "agents": [x["agent"] for x in no_success],
            }
        )

    total_job_runs = sum(x["job"]["runs"] for x in per_agent)
    if total_job_runs == 0:
        blockers.append({"type": "no_job_runs", "count": 0, "agents": []})

    output = {
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "sources": {
            "agents": str(AGENTS_FILE),
            "preflight": str(PREFLIGHT_FILE),
            "score": str(SCORE_FILE),
        },
        "agent_count": len(per_agent),
        "blockers": blockers,
        "agents": per_agent,
    }

    OUT_FILE.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT_FILE}")


if __name__ == "__main__":
    main()
