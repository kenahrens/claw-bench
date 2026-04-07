#!/usr/bin/env python3
import csv
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESULTS_DIR = ROOT / "results"
AGENTS_FILE = ROOT / "config" / "agents.csv"
SAFETY_FILE = ROOT / "config" / "agents-safety.csv"
PREFLIGHT_FILE = RESULTS_DIR / "matrix-preflight.tsv"
OUT_FILE = RESULTS_DIR / "smoke-readiness.json"


def load_csv(path):
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def parse_filter(value):
    if not value:
        return set()
    return {item.strip() for item in value.split(",") if item.strip()}


def run(cmd, env=None):
    return subprocess.run(
        cmd,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def newest_log_for_agent(agent):
    matches = list(RESULTS_DIR.glob(f"{agent}-hello-*.txt"))
    if not matches:
        return None
    return str(max(matches, key=lambda p: p.stat().st_mtime))


def summarize_log_failure(text):
    if "authentication_error" in text:
        return "api authentication error"
    if "Incorrect API key provided" in text:
        return "invalid api key"
    if "executable file not found" in text:
        return "runtime command missing"
    if "out of memory" in text.lower():
        return "runtime oom"
    for line in reversed(text.splitlines()):
        if "Error:" in line or "error:" in line:
            return line.strip()[:220]
    return "hello response missing"


def hello_check_passed(text, prompt):
    if not text:
        return False

    hard_failure_markers = (
        "authentication_error",
        "LLM call failed",
        "error processing message",
        "Unsupported value: 'temperature'",
    )
    if any(marker in text for marker in hard_failure_markers):
        return False

    sanitized = text.replace(prompt, "")
    return re.search(r"(^|[^A-Z0-9_])HELLO_WORLD([^A-Z0-9_]|$)", sanitized) is not None


def main():
    RESULTS_DIR.mkdir(exist_ok=True)

    prompt = os.environ.get("SMOKE_PROMPT", "Reply with exactly: HELLO_WORLD")
    smoke_timeout = os.environ.get("SMOKE_WAIT_TIMEOUT", "120s")
    selected = parse_filter(os.environ.get("AGENT_FILTER", ""))

    agents = load_csv(AGENTS_FILE)
    safety = {row["agent"]: row for row in load_csv(SAFETY_FILE)}

    # Fast image readiness check before per-agent runs.
    preflight_env = os.environ.copy()
    preflight_env["PREFLIGHT_ONLY"] = "true"
    if selected:
        preflight_env["AGENT_FILTER"] = ",".join(sorted(selected))
    preflight_proc = run(["./scripts/run-matrix.sh"], env=preflight_env)

    preflight_rows = {}
    if PREFLIGHT_FILE.exists():
        with PREFLIGHT_FILE.open(newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                preflight_rows[row["agent"]] = row

    records = []

    for row in agents:
        agent = row["agent"].strip()
        if selected and agent not in selected:
            continue

        pre = preflight_rows.get(
            agent, {"status": "unknown", "reason": "no preflight row"}
        )
        record = {
            "agent": agent,
            "image": row["image"].strip(),
            "preflight_status": pre.get("status", "unknown"),
            "status": "blocked",
            "reason": "",
            "log_file": None,
        }

        if pre.get("status") != "available":
            record["reason"] = pre.get("reason", "image unavailable")
            records.append(record)
            continue

        env = os.environ.copy()
        env.update(
            {
                "AGENT_NAME": agent,
                "AGENT_IMAGE": row["image"].strip(),
                "AGENT_TEMPLATE": row["template"].strip(),
                "AGENT_BIN": row["bin"].strip(),
                "TASK_ID": "HELLO",
                "TASK_INSTRUCTION": prompt,
                "WAIT_TIMEOUT": smoke_timeout,
                "REQUIRE_GITHUB_TOKEN": "false",
            }
        )

        policy = safety.get(agent, {})
        mapping = {
            "cpu_request": "RESOURCE_CPU_REQUEST",
            "cpu_limit": "RESOURCE_CPU_LIMIT",
            "memory_request": "RESOURCE_MEMORY_REQUEST",
            "memory_limit": "RESOURCE_MEMORY_LIMIT",
            "max_tool_iterations": "MAX_TOOL_ITERATIONS",
            "approval_mode": "APPROVAL_MODE",
        }
        for src, dst in mapping.items():
            value = policy.get(src, "").strip()
            if value:
                env[dst] = value

        proc = run(["./scripts/run-task.sh"], env=env)
        latest_log = newest_log_for_agent(agent)
        record["log_file"] = latest_log

        log_text = ""
        if latest_log:
            log_text = Path(latest_log).read_text(encoding="utf-8", errors="replace")

        if hello_check_passed(log_text, prompt):
            record["status"] = "ready"
            record["reason"] = "hello check passed"
        else:
            record["status"] = "blocked"
            record["reason"] = summarize_log_failure(log_text)

        records.append(record)

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "prompt": prompt,
        "wait_timeout": smoke_timeout,
        "preflight_command_succeeded": preflight_proc.returncode == 0,
        "agents": records,
    }
    OUT_FILE.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print("agent\tpreflight\tstatus\treason")
    for rec in records:
        print(
            f"{rec['agent']}\t{rec['preflight_status']}\t{rec['status']}\t{rec['reason']}"
        )
    print(f"wrote {OUT_FILE}")


if __name__ == "__main__":
    main()
