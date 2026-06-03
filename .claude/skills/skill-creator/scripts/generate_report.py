#!/usr/bin/env python3
"""
HTML report generator for skill optimization results.

Generates static HTML files viewable with `open` on macOS.

Usage:
    python generate_report.py --input loop_results.json --output report.html
    python generate_report.py --input - --output report.html  # stdin
"""

import argparse
import json
import sys
import time
from pathlib import Path


def score_class(correct: int, total: int) -> str:
    """CSS class based on accuracy."""
    if total == 0:
        return "score-na"
    rate = correct / total
    if rate >= 0.8:
        return "score-good"
    if rate >= 0.5:
        return "score-ok"
    return "score-bad"


def generate_html(data: dict, skill_name: str = "") -> str:
    """Generate an HTML report from optimization loop or benchmark data."""

    name = skill_name or data.get("skill_name", "Unknown Skill")
    history = data.get("history", [])
    best_iter = data.get("best_iteration", 0)
    best_rate = data.get("best_pass_rate", 0)

    # Build iteration rows
    iter_rows = []
    for h in history:
        idx = h.get("iteration", 0)
        train = h.get("train_pass_rate", 0)
        test = h.get("test_pass_rate")
        desc = h.get("description", "")[:80]
        is_best = idx == best_iter

        train_class = "score-good" if train >= 0.8 else ("score-ok" if train >= 0.5 else "score-bad")
        test_html = f'<td class="{train_class}">{test:.0%}</td>' if test is not None else '<td class="score-na">-</td>'

        row_class = ' class="best-row"' if is_best else ""
        iter_rows.append(
            f"<tr{row_class}>"
            f'<td>{"&#9733; " if is_best else ""}{idx + 1}</td>'
            f'<td class="{train_class}">{train:.0%}</td>'
            f"{test_html}"
            f"<td>{desc}{'...' if len(h.get('description', '')) > 80 else ''}</td>"
            f"</tr>"
        )

    iterations_html = "\n".join(iter_rows) if iter_rows else "<tr><td colspan='4'>No iterations run</td></tr>"

    # Final description
    final_desc = data.get("final_description", "N/A")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Skill Optimization Report — {name}</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
    background: #0d1117; color: #c9d1d9; padding: 2rem;
    max-width: 960px; margin: 0 auto;
  }}
  h1 {{ color: #f0f6fc; margin-bottom: 0.5rem; font-size: 1.5rem; }}
  h2 {{ color: #8b949e; margin: 1.5rem 0 0.75rem; font-size: 1.1rem; }}
  .meta {{ color: #8b949e; font-size: 0.85rem; margin-bottom: 1.5rem; }}
  .summary-grid {{
    display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; margin-bottom: 1.5rem;
  }}
  .summary-card {{
    background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 1rem;
  }}
  .summary-card .label {{ color: #8b949e; font-size: 0.8rem; text-transform: uppercase; }}
  .summary-card .value {{ font-size: 1.8rem; font-weight: 600; margin-top: 0.25rem; }}
  .score-good {{ color: #3fb950; }}
  .score-ok {{ color: #d29922; }}
  .score-bad {{ color: #f85149; }}
  .score-na {{ color: #8b949e; }}
  table {{
    width: 100%; border-collapse: collapse; background: #161b22;
    border: 1px solid #30363d; border-radius: 6px; overflow: hidden;
  }}
  th {{ background: #21262d; color: #8b949e; text-align: left; padding: 0.6rem 1rem; font-size: 0.8rem; text-transform: uppercase; }}
  td {{ padding: 0.6rem 1rem; border-top: 1px solid #30363d; font-size: 0.9rem; }}
  .best-row {{ background: #1a2332; }}
  .best-row td {{ border-top-color: #1f6feb; }}
  .description-box {{
    background: #161b22; border: 1px solid #30363d; border-radius: 6px;
    padding: 1rem; margin-top: 0.5rem; font-family: monospace; font-size: 0.85rem;
    white-space: pre-wrap; line-height: 1.5;
  }}
</style>
</head>
<body>
  <h1>Skill Optimization Report</h1>
  <div class="meta">{name} &middot; {len(history)} iterations &middot; {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())}</div>

  <div class="summary-grid">
    <div class="summary-card">
      <div class="label">Best Pass Rate</div>
      <div class="value {score_class(int(best_rate * 100), 100)}">{best_rate:.0%}</div>
    </div>
    <div class="summary-card">
      <div class="label">Best Iteration</div>
      <div class="value">{best_iter + 1 if best_iter is not None else '-'}</div>
    </div>
    <div class="summary-card">
      <div class="label">Total Iterations</div>
      <div class="value">{len(history)}</div>
    </div>
  </div>

  <h2>Iteration History</h2>
  <table>
    <thead>
      <tr><th>#</th><th>Train</th><th>Test</th><th>Description</th></tr>
    </thead>
    <tbody>
      {iterations_html}
    </tbody>
  </table>

  <h2>Final Description</h2>
  <div class="description-box">{final_desc}</div>
</body>
</html>"""

    return html


def main():
    parser = argparse.ArgumentParser(description="Generate HTML optimization report")
    parser.add_argument("--input", default="-", help="Input JSON path (- for stdin)")
    parser.add_argument("--output", default="report.html", help="Output HTML path")
    parser.add_argument("--skill-name", default="", help="Skill name")
    parser.add_argument("--open", action="store_true", help="Open in browser after generating")
    args = parser.parse_args()

    # Read input
    if args.input == "-":
        data = json.load(sys.stdin)
    else:
        with open(args.input) as f:
            data = json.load(f)

    html = generate_html(data, skill_name=args.skill_name)

    output_path = Path(args.output)
    output_path.write_text(html)
    print(f"Report written to: {output_path}", file=sys.stderr)

    if args.open:
        import subprocess
        subprocess.run(["open", str(output_path)])


if __name__ == "__main__":
    main()
