#!/usr/bin/env python3
"""
Benchmark result aggregator.

Aggregates multiple eval/benchmark runs into summary statistics with
mean, stddev, min, max for pass rates, timing, and token usage.

Usage:
    python aggregate_benchmark.py --benchmark-dir benchmarks/2026-03-05/ \
                                  --output benchmark.json
"""

import argparse
import json
import sys
import time
from pathlib import Path

from .utils import calculate_stats, ensure_dir, read_json, write_json


def load_run_results(benchmark_dir: Path) -> list[dict]:
    """Discover and load grading/eval results from a benchmark directory.

    Supports directory layouts:
        benchmark_dir/
        ├── run-001/
        │   ├── grading.json
        │   └── timing.json
        ├── run-002/
        │   ├── grading.json
        │   └── timing.json
        └── ...

    Also supports flat layout with eval_results.json files.
    """
    runs = []

    # Look for run directories
    for run_dir in sorted(benchmark_dir.iterdir()):
        if not run_dir.is_dir():
            continue

        run_data = {"run_id": run_dir.name}

        # Load grading results
        grading_path = run_dir / "grading.json"
        eval_path = run_dir / "eval_results.json"

        if grading_path.exists():
            try:
                grading = read_json(grading_path)
                summary = grading.get("summary", {})
                run_data["pass_rate"] = summary.get("pass_rate", 0)
                run_data["passed"] = summary.get("passed", 0)
                run_data["total"] = summary.get("total", 0)
                run_data["metrics"] = grading.get("metrics", {})
            except (json.JSONDecodeError, KeyError) as e:
                print(f"WARNING: Error loading {grading_path}: {e}", file=sys.stderr)
                continue
        elif eval_path.exists():
            try:
                eval_data = read_json(eval_path)
                summary = eval_data.get("summary", {})
                run_data["pass_rate"] = summary.get("pass_rate", 0)
                run_data["passed"] = summary.get("correct", 0)
                run_data["total"] = summary.get("total_queries", 0)
                run_data["avg_duration_ms"] = summary.get("avg_duration_ms", 0)
            except (json.JSONDecodeError, KeyError) as e:
                print(f"WARNING: Error loading {eval_path}: {e}", file=sys.stderr)
                continue
        else:
            continue

        # Load timing data if available
        timing_path = run_dir / "timing.json"
        if timing_path.exists():
            try:
                timing = read_json(timing_path)
                run_data["duration_ms"] = timing.get("duration_ms", 0)
                run_data["tokens"] = timing.get("tokens", 0)
            except (json.JSONDecodeError, KeyError):
                pass

        runs.append(run_data)

    return runs


def aggregate_results(runs: list[dict]) -> dict:
    """Compute summary statistics from individual runs."""
    if not runs:
        return {"error": "No runs found"}

    pass_rates = [r.get("pass_rate", 0) for r in runs]
    durations = [r.get("duration_ms", r.get("avg_duration_ms", 0)) for r in runs if r.get("duration_ms") or r.get("avg_duration_ms")]
    tokens = [r.get("tokens", 0) for r in runs if r.get("tokens")]

    return {
        "pass_rate": calculate_stats(pass_rates),
        "duration_ms": calculate_stats(durations) if durations else None,
        "tokens": calculate_stats(tokens) if tokens else None,
        "run_count": len(runs),
    }


def generate_markdown(summary: dict, runs: list[dict], skill_name: str = "") -> str:
    """Generate a human-readable markdown benchmark report."""
    lines = [
        f"# Benchmark Report{f' — {skill_name}' if skill_name else ''}",
        "",
        f"**Runs:** {summary.get('run_count', 0)}",
        f"**Generated:** {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())}",
        "",
        "## Pass Rate",
        "",
        "| Metric | Value |",
        "|--------|-------|",
    ]

    pr = summary.get("pass_rate", {})
    lines.extend([
        f"| Mean | {pr.get('mean', 0):.1%} |",
        f"| Std Dev | {pr.get('stddev', 0):.4f} |",
        f"| Min | {pr.get('min', 0):.1%} |",
        f"| Max | {pr.get('max', 0):.1%} |",
    ])

    if summary.get("duration_ms"):
        d = summary["duration_ms"]
        lines.extend([
            "",
            "## Execution Time",
            "",
            "| Metric | Value |",
            "|--------|-------|",
            f"| Mean | {d.get('mean', 0):.0f}ms |",
            f"| Std Dev | {d.get('stddev', 0):.0f}ms |",
            f"| Min | {d.get('min', 0):.0f}ms |",
            f"| Max | {d.get('max', 0):.0f}ms |",
        ])

    if summary.get("tokens"):
        t = summary["tokens"]
        lines.extend([
            "",
            "## Token Usage",
            "",
            "| Metric | Value |",
            "|--------|-------|",
            f"| Mean | {t.get('mean', 0):.0f} |",
            f"| Std Dev | {t.get('stddev', 0):.0f} |",
            f"| Min | {t.get('min', 0):.0f} |",
            f"| Max | {t.get('max', 0):.0f} |",
        ])

    # Individual runs table
    lines.extend([
        "",
        "## Individual Runs",
        "",
        "| Run | Pass Rate | Duration | Tokens |",
        "|-----|-----------|----------|--------|",
    ])

    for r in runs:
        pr = f"{r.get('pass_rate', 0):.0%}"
        dur = f"{r.get('duration_ms', r.get('avg_duration_ms', '-'))}ms" if r.get('duration_ms') or r.get('avg_duration_ms') else "-"
        tok = str(r.get("tokens", "-"))
        lines.append(f"| {r.get('run_id', '?')} | {pr} | {dur} | {tok} |")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Aggregate benchmark results")
    parser.add_argument("--benchmark-dir", required=True, help="Path to benchmark directory")
    parser.add_argument("--output", default="benchmark.json", help="Output JSON path")
    parser.add_argument("--skill-name", default="", help="Skill name for report")
    parser.add_argument("--markdown", help="Optional markdown report output path")
    args = parser.parse_args()

    benchmark_dir = Path(args.benchmark_dir)
    if not benchmark_dir.is_dir():
        print(f"ERROR: {benchmark_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    runs = load_run_results(benchmark_dir)
    if not runs:
        print("ERROR: No run results found", file=sys.stderr)
        sys.exit(1)

    summary = aggregate_results(runs)

    output = {
        "metadata": {
            "skill_name": args.skill_name,
            "benchmark_dir": str(benchmark_dir),
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        },
        "summary": summary,
        "runs": runs,
    }

    write_json(Path(args.output), output)
    print(f"Aggregated {len(runs)} runs → {args.output}", file=sys.stderr)

    if args.markdown:
        md = generate_markdown(summary, runs, args.skill_name)
        Path(args.markdown).write_text(md)
        print(f"Markdown report → {args.markdown}", file=sys.stderr)

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
