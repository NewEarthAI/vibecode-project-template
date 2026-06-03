#!/usr/bin/env python3
"""
Eval review HTML generator.

Generates a comprehensive review page from grading results,
comparisons, and benchmark data. Opens with `open` on macOS.

Usage:
    python generate_review.py --grading-dir results/ --output review.html
    python generate_review.py --grading-dir results/ --output review.html --open
"""

import argparse
import json
import sys
import time
from pathlib import Path


def load_all_results(grading_dir: Path) -> dict:
    """Load all available result files from a grading directory."""
    results = {}

    for json_file in grading_dir.rglob("*.json"):
        key = json_file.stem
        try:
            with open(json_file) as f:
                results[key] = json.load(f)
        except json.JSONDecodeError:
            pass

    return results


def generate_review_html(results: dict, title: str = "Eval Review") -> str:
    """Generate comprehensive review HTML from all available results."""

    sections = []

    # Grading results
    if "grading" in results:
        g = results["grading"]
        summary = g.get("summary", {})
        expectations = g.get("expectations", [])

        exp_rows = []
        for exp in expectations:
            passed = exp.get("passed", False)
            icon = "&#10003;" if passed else "&#10007;"
            cls = "score-good" if passed else "score-bad"
            evidence = exp.get("evidence", "No evidence")
            exp_rows.append(
                f'<tr><td class="{cls}">{icon}</td>'
                f'<td>{exp.get("text", "?")}</td>'
                f'<td>{evidence}</td></tr>'
            )

        sections.append(f"""
        <h2>Grading Results</h2>
        <div class="summary-grid">
            <div class="summary-card">
                <div class="label">Pass Rate</div>
                <div class="value score-{'good' if summary.get('pass_rate', 0) >= 0.8 else 'bad'}">{summary.get('pass_rate', 0):.0%}</div>
            </div>
            <div class="summary-card">
                <div class="label">Passed</div>
                <div class="value">{summary.get('passed', 0)}/{summary.get('total', 0)}</div>
            </div>
        </div>
        <table>
            <thead><tr><th>Status</th><th>Expectation</th><th>Evidence</th></tr></thead>
            <tbody>{''.join(exp_rows)}</tbody>
        </table>
        """)

    # Comparison results
    for key, data in results.items():
        if "winner" in data and "rubric" in data:
            winner = data.get("winner", "?")
            reasoning = data.get("reasoning", "")
            sections.append(f"""
            <h2>Blind Comparison</h2>
            <div class="summary-card" style="margin-bottom: 1rem;">
                <div class="label">Winner</div>
                <div class="value">Output {winner}</div>
            </div>
            <p style="margin-bottom: 1rem;">{reasoning}</p>
            """)

    # Eval results (trigger testing)
    if "eval_results" in results:
        e = results["eval_results"]
        summary = e.get("summary", {})
        eval_details = e.get("results", [])

        detail_rows = []
        for r in eval_details:
            correct = r.get("correct", False)
            icon = "&#10003;" if correct else "&#10007;"
            cls = "score-good" if correct else "score-bad"
            should = "trigger" if r.get("should_trigger") else "no-trigger"
            did = "triggered" if r.get("triggered") else "silent"
            detail_rows.append(
                f'<tr><td class="{cls}">{icon}</td>'
                f'<td>{r.get("query", "?")[:60]}...</td>'
                f'<td>{should}</td><td>{did}</td>'
                f'<td>{r.get("duration_ms", 0)}ms</td></tr>'
            )

        sections.append(f"""
        <h2>Trigger Evaluation</h2>
        <div class="summary-grid">
            <div class="summary-card">
                <div class="label">Overall</div>
                <div class="value">{summary.get('pass_rate', 0):.0%}</div>
            </div>
            <div class="summary-card">
                <div class="label">Trigger Rate</div>
                <div class="value">{summary.get('trigger_queries', {{}}).get('rate', 0):.0%}</div>
            </div>
            <div class="summary-card">
                <div class="label">No-Trigger Rate</div>
                <div class="value">{summary.get('no_trigger_queries', {{}}).get('rate', 0):.0%}</div>
            </div>
        </div>
        <table>
            <thead><tr><th>Status</th><th>Query</th><th>Expected</th><th>Actual</th><th>Time</th></tr></thead>
            <tbody>{''.join(detail_rows)}</tbody>
        </table>
        """)

    sections_html = "\n".join(sections) if sections else "<p>No results found.</p>"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>{title}</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
    background: #0d1117; color: #c9d1d9; padding: 2rem;
    max-width: 1100px; margin: 0 auto;
  }}
  h1 {{ color: #f0f6fc; margin-bottom: 0.5rem; font-size: 1.5rem; }}
  h2 {{ color: #f0f6fc; margin: 2rem 0 0.75rem; font-size: 1.2rem; border-bottom: 1px solid #30363d; padding-bottom: 0.5rem; }}
  .meta {{ color: #8b949e; font-size: 0.85rem; margin-bottom: 1.5rem; }}
  .summary-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }}
  .summary-card {{ background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 1rem; }}
  .summary-card .label {{ color: #8b949e; font-size: 0.75rem; text-transform: uppercase; }}
  .summary-card .value {{ font-size: 1.5rem; font-weight: 600; margin-top: 0.25rem; }}
  .score-good {{ color: #3fb950; }}
  .score-ok {{ color: #d29922; }}
  .score-bad {{ color: #f85149; }}
  table {{ width: 100%; border-collapse: collapse; background: #161b22; border: 1px solid #30363d; border-radius: 6px; overflow: hidden; margin-bottom: 1rem; }}
  th {{ background: #21262d; color: #8b949e; text-align: left; padding: 0.5rem 0.75rem; font-size: 0.75rem; text-transform: uppercase; }}
  td {{ padding: 0.5rem 0.75rem; border-top: 1px solid #30363d; font-size: 0.85rem; }}
  p {{ line-height: 1.6; color: #c9d1d9; }}
</style>
</head>
<body>
  <h1>{title}</h1>
  <div class="meta">Generated {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())}</div>
  {sections_html}
</body>
</html>"""


def main():
    parser = argparse.ArgumentParser(description="Generate eval review HTML")
    parser.add_argument("--grading-dir", required=True, help="Directory with result JSON files")
    parser.add_argument("--output", default="review.html", help="Output HTML path")
    parser.add_argument("--title", default="Eval Review", help="Page title")
    parser.add_argument("--open", action="store_true", help="Open in browser")
    args = parser.parse_args()

    results = load_all_results(Path(args.grading_dir))
    html = generate_review_html(results, title=args.title)

    output_path = Path(args.output)
    output_path.write_text(html)
    print(f"Review written to: {output_path}", file=sys.stderr)

    if args.open:
        import subprocess
        subprocess.run(["open", str(output_path)])


if __name__ == "__main__":
    main()
