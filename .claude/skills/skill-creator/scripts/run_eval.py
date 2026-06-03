#!/usr/bin/env python3
"""
Skill trigger evaluation runner.

Evaluates whether Claude correctly triggers (or avoids triggering) a skill
based on test prompts. Uses `claude -p` CLI with stream-json output.

Usage:
    python run_eval.py --skill-path .claude/skills/my-skill \
                       --eval-path .claude/skills/my-skill/evals/evals.json \
                       --output-dir results/
"""

import argparse
import json
import subprocess
import sys
import tempfile
import time
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

from .utils import (
    detect_skill_trigger,
    ensure_dir,
    find_project_root,
    load_evals,
    parse_skill_frontmatter,
    write_json,
)


def run_single_query(
    query: str,
    skill_name: str,
    skill_description: str,
    should_trigger: bool,
    project_root: Path,
    timeout: int = 120,
) -> dict:
    """Run a single eval query and detect if the skill was triggered.

    Creates a temporary command file with the skill description,
    runs claude -p, and checks stream events for skill activation.
    """
    run_id = str(uuid.uuid4())[:8]
    start = time.time()

    # Create temp command file so claude knows about the skill
    temp_cmd_dir = project_root / ".claude" / "commands"
    temp_cmd_file = temp_cmd_dir / f"_eval_temp_{run_id}.md"

    try:
        temp_cmd_file.write_text(
            f"---\nskill: {skill_name}\ndescription: {skill_description}\n---\n\n"
            f"Temporary eval command for {skill_name}"
        )

        cmd = [
            "claude",
            "-p",
            query,
            "--output-format",
            "stream-json",
            "--max-turns",
            "3",
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(project_root),
        )

        duration_ms = int((time.time() - start) * 1000)
        triggered = detect_skill_trigger(result.stdout, skill_name)

        # Determine if this result is correct
        correct = triggered == should_trigger

        return {
            "run_id": run_id,
            "query": query,
            "should_trigger": should_trigger,
            "triggered": triggered,
            "correct": correct,
            "duration_ms": duration_ms,
            "success": result.returncode == 0,
        }

    except subprocess.TimeoutExpired:
        duration_ms = int((time.time() - start) * 1000)
        return {
            "run_id": run_id,
            "query": query,
            "should_trigger": should_trigger,
            "triggered": False,
            "correct": not should_trigger,  # Timeout = no trigger
            "duration_ms": duration_ms,
            "success": False,
            "error": f"Timeout after {timeout}s",
        }
    finally:
        # Clean up temp file
        if temp_cmd_file.exists():
            temp_cmd_file.unlink()


def run_eval(
    skill_path: Path,
    eval_path: Path,
    output_dir: Path,
    max_workers: int = 3,
    timeout: int = 120,
) -> dict:
    """Run all eval queries in parallel and aggregate results.

    Args:
        skill_path: Path to the skill directory
        eval_path: Path to evals.json
        output_dir: Where to write results
        max_workers: Max parallel eval runs
        timeout: Per-query timeout in seconds

    Returns:
        Aggregated results dict
    """
    project_root = find_project_root()
    evals = load_evals(eval_path)
    frontmatter = parse_skill_frontmatter(skill_path)
    skill_name = frontmatter.get("name", skill_path.name)
    skill_description = frontmatter.get("description", "")

    print(f"Running {len(evals)} eval queries for skill: {skill_name}", file=sys.stderr)

    results = []

    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures = {}
        for eval_item in evals:
            query = eval_item.get("prompt", eval_item.get("query", ""))
            should_trigger = eval_item.get("should_trigger", True)

            future = executor.submit(
                run_single_query,
                query=query,
                skill_name=skill_name,
                skill_description=skill_description,
                should_trigger=should_trigger,
                project_root=project_root,
                timeout=timeout,
            )
            futures[future] = eval_item

        for future in as_completed(futures):
            result = future.result()
            eval_item = futures[future]
            result["eval_id"] = eval_item.get("id", "unknown")
            results.append(result)
            status = "PASS" if result["correct"] else "FAIL"
            print(f"  [{status}] {result['query'][:60]}...", file=sys.stderr)

    # Aggregate
    total = len(results)
    correct = sum(1 for r in results if r["correct"])
    trigger_results = [r for r in results if r["should_trigger"]]
    no_trigger_results = [r for r in results if not r["should_trigger"]]

    trigger_correct = sum(1 for r in trigger_results if r["correct"])
    no_trigger_correct = sum(1 for r in no_trigger_results if r["correct"])

    summary = {
        "skill_name": skill_name,
        "total_queries": total,
        "correct": correct,
        "pass_rate": round(correct / total, 4) if total > 0 else 0,
        "trigger_queries": {
            "total": len(trigger_results),
            "correct": trigger_correct,
            "rate": round(trigger_correct / len(trigger_results), 4) if trigger_results else 0,
        },
        "no_trigger_queries": {
            "total": len(no_trigger_results),
            "correct": no_trigger_correct,
            "rate": round(no_trigger_correct / len(no_trigger_results), 4) if no_trigger_results else 0,
        },
        "avg_duration_ms": round(
            sum(r["duration_ms"] for r in results) / total
        ) if total > 0 else 0,
    }

    output = {
        "summary": summary,
        "results": results,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    # Write results
    ensure_dir(output_dir)
    write_json(output_dir / "eval_results.json", output)

    print(f"\nResults: {correct}/{total} correct ({summary['pass_rate']:.0%})", file=sys.stderr)
    return output


def main():
    parser = argparse.ArgumentParser(description="Run skill trigger evaluations")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--eval-path", required=True, help="Path to evals.json")
    parser.add_argument("--output-dir", default="eval_results", help="Output directory")
    parser.add_argument("--max-workers", type=int, default=3, help="Max parallel runs")
    parser.add_argument("--timeout", type=int, default=120, help="Per-query timeout (seconds)")
    args = parser.parse_args()

    results = run_eval(
        skill_path=Path(args.skill_path),
        eval_path=Path(args.eval_path),
        output_dir=Path(args.output_dir),
        max_workers=args.max_workers,
        timeout=args.timeout,
    )

    # Output JSON to stdout
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
