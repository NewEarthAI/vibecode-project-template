#!/usr/bin/env python3
"""
Iterative skill description optimization loop.

Runs eval → improve → re-eval cycles to optimize skill descriptions.
Supports train/test splitting to prevent overfitting.

Usage:
    python run_loop.py --skill-path .claude/skills/my-skill \
                       --eval-path .claude/skills/my-skill/evals/evals.json \
                       --max-iterations 5 \
                       --output-dir optimization_results/
"""

import argparse
import json
import random
import sys
import time
from pathlib import Path

from .improve_description import improve_description
from .run_eval import run_eval
from .generate_report import generate_html
from .utils import (
    ensure_dir,
    find_project_root,
    load_evals,
    parse_skill_frontmatter,
    read_json,
    write_json,
)


def split_eval_set(
    eval_set: list[dict],
    holdout: float = 0.3,
    seed: int = 42,
) -> tuple[list[dict], list[dict]]:
    """Split evals into train/test sets with stratified sampling.

    Stratifies by should_trigger to maintain balance in both sets.
    """
    rng = random.Random(seed)

    # Separate by trigger type
    trigger = [e for e in eval_set if e.get("should_trigger", True)]
    no_trigger = [e for e in eval_set if not e.get("should_trigger", True)]

    rng.shuffle(trigger)
    rng.shuffle(no_trigger)

    # Split each group
    trigger_split = max(1, int(len(trigger) * holdout))
    no_trigger_split = max(1, int(len(no_trigger) * holdout)) if no_trigger else 0

    test = trigger[:trigger_split] + no_trigger[:no_trigger_split]
    train = trigger[trigger_split:] + no_trigger[no_trigger_split:]

    return train, test


def run_loop(
    skill_path: Path,
    eval_path: Path,
    output_dir: Path,
    max_iterations: int = 5,
    holdout: float = 0.0,
    target_pass_rate: float = 1.0,
) -> dict:
    """Run iterative optimization loop.

    Args:
        skill_path: Path to skill directory
        eval_path: Path to evals.json
        output_dir: Where to write results
        max_iterations: Max optimization iterations
        holdout: Fraction to hold out for testing (0 = no split)
        target_pass_rate: Stop when this pass rate is achieved

    Returns:
        dict with optimization results and history
    """
    frontmatter = parse_skill_frontmatter(skill_path)
    skill_name = frontmatter.get("name", skill_path.name)
    all_evals = load_evals(eval_path)

    # Split if holdout requested
    if holdout > 0 and len(all_evals) >= 4:
        train_evals, test_evals = split_eval_set(all_evals, holdout)
        print(f"Split: {len(train_evals)} train, {len(test_evals)} test", file=sys.stderr)
    else:
        train_evals = all_evals
        test_evals = None

    ensure_dir(output_dir)
    history = []
    best_iteration = None
    best_pass_rate = 0.0

    for iteration in range(max_iterations):
        iter_dir = ensure_dir(output_dir / f"iteration-{iteration:03d}")
        print(f"\n{'='*50}", file=sys.stderr)
        print(f"Iteration {iteration + 1}/{max_iterations}", file=sys.stderr)
        print(f"{'='*50}", file=sys.stderr)

        # Write current train evals to temp file
        train_eval_path = iter_dir / "train_evals.json"
        write_json(train_eval_path, train_evals)

        # Run eval on train set
        print("Running eval on training set...", file=sys.stderr)
        train_results = run_eval(
            skill_path=skill_path,
            eval_path=train_eval_path,
            output_dir=iter_dir / "train",
        )

        train_pass_rate = train_results.get("summary", {}).get("pass_rate", 0)

        # Run eval on test set if available
        test_pass_rate = None
        if test_evals:
            test_eval_path = iter_dir / "test_evals.json"
            write_json(test_eval_path, test_evals)
            print("Running eval on test set...", file=sys.stderr)
            test_results = run_eval(
                skill_path=skill_path,
                eval_path=test_eval_path,
                output_dir=iter_dir / "test",
            )
            test_pass_rate = test_results.get("summary", {}).get("pass_rate", 0)

        # Record iteration
        iteration_record = {
            "iteration": iteration,
            "description": frontmatter.get("description", ""),
            "train_pass_rate": train_pass_rate,
            "test_pass_rate": test_pass_rate,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        history.append(iteration_record)

        # Track best
        effective_rate = test_pass_rate if test_pass_rate is not None else train_pass_rate
        if effective_rate > best_pass_rate:
            best_pass_rate = effective_rate
            best_iteration = iteration

        print(f"Train: {train_pass_rate:.0%}" + (f" | Test: {test_pass_rate:.0%}" if test_pass_rate is not None else ""), file=sys.stderr)

        # Check exit conditions
        if train_pass_rate >= target_pass_rate:
            print(f"Target pass rate {target_pass_rate:.0%} achieved!", file=sys.stderr)
            break

        if iteration < max_iterations - 1:
            # Improve description
            print("Improving description...", file=sys.stderr)
            improvement = improve_description(
                skill_path=skill_path,
                eval_results=train_results,
                history=history,
            )

            new_desc = improvement.get("description", "")
            if new_desc and new_desc != frontmatter.get("description"):
                # Update the SKILL.md with new description
                skill_md = skill_path / "SKILL.md"
                content = skill_md.read_text()

                old_desc = frontmatter.get("description", "")
                if old_desc in content:
                    content = content.replace(old_desc, new_desc, 1)
                    skill_md.write_text(content)
                    frontmatter["description"] = new_desc
                    print(f"Updated description ({len(new_desc)} chars)", file=sys.stderr)

                # Save improvement details
                write_json(iter_dir / "improvement.json", improvement)

    # Final output
    results = {
        "skill_name": skill_name,
        "iterations": len(history),
        "best_iteration": best_iteration,
        "best_pass_rate": best_pass_rate,
        "history": history,
        "final_description": frontmatter.get("description", ""),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    write_json(output_dir / "loop_results.json", results)

    # Generate HTML report
    try:
        html = generate_html(results, skill_name=skill_name)
        report_path = output_dir / "report.html"
        report_path.write_text(html)
        print(f"\nReport: {report_path}", file=sys.stderr)
    except Exception as e:
        print(f"WARNING: Could not generate HTML report: {e}", file=sys.stderr)

    return results


def main():
    parser = argparse.ArgumentParser(description="Run skill optimization loop")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--eval-path", required=True, help="Path to evals.json")
    parser.add_argument("--output-dir", default="optimization_results", help="Output directory")
    parser.add_argument("--max-iterations", type=int, default=5, help="Max iterations")
    parser.add_argument("--holdout", type=float, default=0.0, help="Test set holdout fraction")
    parser.add_argument("--target", type=float, default=1.0, help="Target pass rate to stop at")
    args = parser.parse_args()

    results = run_loop(
        skill_path=Path(args.skill_path),
        eval_path=Path(args.eval_path),
        output_dir=Path(args.output_dir),
        max_iterations=args.max_iterations,
        holdout=args.holdout,
        target_pass_rate=args.target,
    )

    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
