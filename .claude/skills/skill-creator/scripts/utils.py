#!/usr/bin/env python3
"""
Shared utilities for skill-creator evaluation scripts.

All eval execution uses `claude -p` CLI (no direct Anthropic API calls).
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional


def find_project_root() -> Path:
    """Walk up from CWD to find the directory containing .claude/."""
    current = Path.cwd()
    for parent in [current, *current.parents]:
        if (parent / ".claude").is_dir():
            return parent
    print("ERROR: Could not find project root (no .claude/ directory)", file=sys.stderr)
    sys.exit(1)


def parse_skill_frontmatter(skill_path: Path) -> dict:
    """Parse YAML frontmatter from a SKILL.md file.

    Returns dict with at minimum 'name' and 'description' keys.
    Handles our extended frontmatter (version, parameters, validated_on, etc.).
    """
    skill_md = skill_path / "SKILL.md" if skill_path.is_dir() else skill_path
    if not skill_md.exists():
        return {}

    content = skill_md.read_text()
    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return {}

    # Use simple parsing to avoid yaml dependency
    frontmatter = {}
    current_key = None
    current_value_lines = []

    for line in match.group(1).split("\n"):
        # Check for key: value or key: | (multiline)
        key_match = re.match(r"^(\w[\w-]*)\s*:\s*(.*)", line)
        if key_match and not line.startswith("  ") and not line.startswith("\t"):
            # Save previous key if exists
            if current_key:
                val = "\n".join(current_value_lines).strip()
                frontmatter[current_key] = val
            current_key = key_match.group(1)
            value = key_match.group(2).strip()
            if value == "|" or value == ">":
                current_value_lines = []
            elif value:
                current_value_lines = [value]
            else:
                current_value_lines = []
        elif current_key and (line.startswith("  ") or line.startswith("\t")):
            current_value_lines.append(line.strip())
        elif current_key and line.strip() == "":
            current_value_lines.append("")

    # Save last key
    if current_key:
        val = "\n".join(current_value_lines).strip()
        frontmatter[current_key] = val

    return frontmatter


def run_claude_cli(
    prompt: str,
    skill_path: Optional[Path] = None,
    timeout: int = 300,
    stream: bool = False,
) -> dict:
    """Run claude -p with the given prompt. Returns parsed output.

    Args:
        prompt: The prompt to send
        skill_path: Optional skill directory to load
        timeout: Timeout in seconds
        stream: If True, use stream-json output format

    Returns:
        dict with keys: 'output', 'success', 'duration_ms', 'token_usage'
    """
    cmd = ["claude", "-p", prompt, "--output-format"]
    cmd.append("stream-json" if stream else "json")

    if skill_path:
        # Claude Code loads skills from .claude/skills/ automatically
        # We pass the skill context via the prompt
        pass

    start = time.time()
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        duration_ms = int((time.time() - start) * 1000)

        if stream:
            return {
                "output": result.stdout,
                "success": result.returncode == 0,
                "duration_ms": duration_ms,
                "stderr": result.stderr,
            }

        # Parse JSON output
        try:
            parsed = json.loads(result.stdout)
            return {
                "output": parsed,
                "success": result.returncode == 0,
                "duration_ms": duration_ms,
                "stderr": result.stderr,
            }
        except json.JSONDecodeError:
            return {
                "output": result.stdout,
                "success": False,
                "duration_ms": duration_ms,
                "stderr": result.stderr,
            }

    except subprocess.TimeoutExpired:
        duration_ms = int((time.time() - start) * 1000)
        return {
            "output": None,
            "success": False,
            "duration_ms": duration_ms,
            "stderr": f"Timeout after {timeout}s",
        }


def detect_skill_trigger(stream_output: str, skill_name: str) -> bool:
    """Parse stream-json output to detect if a skill was triggered.

    Looks for tool_use content blocks where the tool is 'Skill' or 'Read'
    targeting the skill's SKILL.md file.
    """
    for line in stream_output.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
            # Check for Skill tool invocation
            if event.get("type") == "content_block_start":
                block = event.get("content_block", {})
                if block.get("type") == "tool_use":
                    tool_name = block.get("name", "")
                    if tool_name == "Skill":
                        return True
                    # Also check for Read of the skill's SKILL.md
                    if tool_name == "Read":
                        input_data = block.get("input", {})
                        if skill_name in str(input_data.get("file_path", "")):
                            return True
        except json.JSONDecodeError:
            continue
    return False


def load_evals(eval_path: Path) -> list[dict]:
    """Load evals from an evals.json file."""
    if not eval_path.exists():
        print(f"ERROR: Eval file not found: {eval_path}", file=sys.stderr)
        sys.exit(1)

    with open(eval_path) as f:
        data = json.load(f)

    # Handle both list format and object-with-evals-key format
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and "evals" in data:
        return data["evals"]

    print(f"ERROR: Invalid eval format in {eval_path}", file=sys.stderr)
    sys.exit(1)


def calculate_stats(values: list[float]) -> dict:
    """Calculate mean, stddev, min, max for a list of values."""
    if not values:
        return {"mean": 0, "stddev": 0, "min": 0, "max": 0}

    n = len(values)
    mean = sum(values) / n
    variance = sum((x - mean) ** 2 for x in values) / n if n > 1 else 0
    stddev = variance**0.5

    return {
        "mean": round(mean, 4),
        "stddev": round(stddev, 4),
        "min": round(min(values), 4),
        "max": round(max(values), 4),
    }


def ensure_dir(path: Path) -> Path:
    """Create directory if it doesn't exist. Returns the path."""
    path.mkdir(parents=True, exist_ok=True)
    return path


def write_json(path: Path, data: dict, indent: int = 2) -> None:
    """Write JSON to file with pretty printing."""
    ensure_dir(path.parent)
    with open(path, "w") as f:
        json.dump(data, f, indent=indent, default=str)


def read_json(path: Path) -> dict:
    """Read and parse a JSON file."""
    with open(path) as f:
        return json.load(f)
