#!/usr/bin/env python3
"""
Skill description optimizer.

Uses Claude CLI with extended thinking to iteratively improve skill descriptions
for better trigger accuracy. Analyzes eval results to identify false positives
and missed triggers, then generates improved descriptions.

Usage:
    python improve_description.py --skill-path .claude/skills/my-skill \
                                  --eval-results eval_results.json \
                                  --output improved.json
"""

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

from .utils import find_project_root, parse_skill_frontmatter, read_json, write_json


def improve_description(
    skill_path: Path,
    eval_results: dict,
    history: list[dict] | None = None,
    max_length: int = 1024,
) -> dict:
    """Generate an improved skill description based on eval results.

    Uses claude -p with a carefully crafted prompt that includes:
    - Current description and its performance
    - Failed cases (false positives + missed triggers)
    - Previous improvement attempts (to avoid cycles)

    Args:
        skill_path: Path to skill directory
        eval_results: Output from run_eval.py
        history: Previous improvement attempts
        max_length: Max description length in chars

    Returns:
        dict with 'description', 'reasoning', 'history'
    """
    frontmatter = parse_skill_frontmatter(skill_path)
    current_desc = frontmatter.get("description", "")
    skill_name = frontmatter.get("name", skill_path.name)

    # Analyze failures
    results = eval_results.get("results", [])
    failures = [r for r in results if not r.get("correct", False)]
    false_positives = [r for r in failures if not r.get("should_trigger") and r.get("triggered")]
    missed_triggers = [r for r in failures if r.get("should_trigger") and not r.get("triggered")]

    summary = eval_results.get("summary", {})

    # Build optimization prompt
    prompt_parts = [
        "You are optimizing a Claude Code skill description for better trigger accuracy.",
        "",
        f"## Skill: {skill_name}",
        f"## Current Description:",
        f"{current_desc}",
        "",
        f"## Current Performance:",
        f"- Overall pass rate: {summary.get('pass_rate', 0):.0%}",
        f"- Trigger accuracy: {summary.get('trigger_queries', {}).get('rate', 0):.0%}",
        f"- No-trigger accuracy: {summary.get('no_trigger_queries', {}).get('rate', 0):.0%}",
        "",
    ]

    if missed_triggers:
        prompt_parts.append("## Missed Triggers (should have fired but didn't):")
        for r in missed_triggers:
            prompt_parts.append(f"- \"{r['query']}\"")
        prompt_parts.append("")

    if false_positives:
        prompt_parts.append("## False Positives (fired when it shouldn't have):")
        for r in false_positives:
            prompt_parts.append(f"- \"{r['query']}\"")
        prompt_parts.append("")

    if history:
        prompt_parts.append("## Previous Attempts (avoid repeating these):")
        for h in history[-3:]:  # Last 3 attempts
            prompt_parts.append(f"- Description: \"{h.get('description', '')[:100]}...\"")
            prompt_parts.append(f"  Pass rate: {h.get('pass_rate', 0):.0%}")
        prompt_parts.append("")

    prompt_parts.extend([
        "## Instructions:",
        "Write an improved description that:",
        "1. Is 100-200 words (imperative phrasing: 'Use this skill when...')",
        "2. Avoids overfitting to specific test cases",
        "3. Focuses on USER INTENT, not implementation details",
        "4. Is DISTINCTIVE enough to avoid confusion with other skills",
        f"5. Does not exceed {max_length} characters",
        "",
        "Think carefully about what makes this skill unique and when it should/shouldn't fire.",
        "",
        "Output ONLY the new description text, wrapped in <new_description> tags:",
        "<new_description>Your improved description here</new_description>",
    ])

    prompt = "\n".join(prompt_parts)

    # Run via claude CLI
    try:
        result = subprocess.run(
            ["claude", "-p", prompt, "--output-format", "json"],
            capture_output=True,
            text=True,
            timeout=120,
        )

        output_text = result.stdout
        try:
            parsed = json.loads(output_text)
            if isinstance(parsed, dict) and "result" in parsed:
                output_text = parsed["result"]
            elif isinstance(parsed, dict) and "content" in parsed:
                output_text = parsed["content"]
        except json.JSONDecodeError:
            pass

        # Extract description from tags
        desc_match = re.search(
            r"<new_description>(.*?)</new_description>",
            output_text,
            re.DOTALL,
        )

        if desc_match:
            new_desc = desc_match.group(1).strip()
        else:
            # Fallback: use the whole output
            new_desc = output_text.strip()

        # Enforce length limit
        if len(new_desc) > max_length:
            # Ask Claude to shorten
            shorten_result = subprocess.run(
                [
                    "claude", "-p",
                    f"Shorten this skill description to under {max_length} characters "
                    f"while keeping its meaning:\n\n{new_desc}\n\n"
                    f"Output ONLY the shortened description, nothing else.",
                    "--output-format", "json",
                ],
                capture_output=True,
                text=True,
                timeout=60,
            )
            shortened = shorten_result.stdout.strip()
            try:
                parsed = json.loads(shortened)
                shortened = parsed.get("result", parsed.get("content", shortened))
            except json.JSONDecodeError:
                pass
            new_desc = shortened[:max_length]

        return {
            "description": new_desc,
            "previous_description": current_desc,
            "improvement_reasoning": f"Optimized for {len(missed_triggers)} missed triggers "
                                     f"and {len(false_positives)} false positives",
        }

    except subprocess.TimeoutExpired:
        return {
            "description": current_desc,
            "previous_description": current_desc,
            "improvement_reasoning": "Timeout — kept original description",
            "error": "CLI timeout",
        }


def main():
    parser = argparse.ArgumentParser(description="Optimize skill description")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--eval-results", required=True, help="Path to eval results JSON")
    parser.add_argument("--history", help="Path to history JSON (previous attempts)")
    parser.add_argument("--output", default="-", help="Output path (- for stdout)")
    args = parser.parse_args()

    eval_results = read_json(Path(args.eval_results))
    history = read_json(Path(args.history)) if args.history else None

    result = improve_description(
        skill_path=Path(args.skill_path),
        eval_results=eval_results,
        history=history,
    )

    output_json = json.dumps(result, indent=2)
    if args.output == "-":
        print(output_json)
    else:
        Path(args.output).write_text(output_json)


if __name__ == "__main__":
    main()
