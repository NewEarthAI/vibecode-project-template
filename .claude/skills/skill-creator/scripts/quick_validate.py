#!/usr/bin/env python3
"""
Quick validation script for skills — adapted for our extended frontmatter.

Validates SKILL.md frontmatter schema. Accepts both Anthropic standard fields
and our extended fields (version, parameters, validated_on, etc.).

Usage:
    python quick_validate.py .claude/skills/my-skill/
"""

import re
import sys
from pathlib import Path


# Anthropic standard fields
ANTHROPIC_FIELDS = {"name", "description", "license", "allowed-tools", "metadata", "compatibility"}

# Our extended fields (Workflow Sovereignty — these define our creation workflow)
EXTENDED_FIELDS = {
    "version",
    "created",
    "updated",
    "supersedes",
    "validated_on",
    "parameters",
    "user-invocable",
    "triggers",
    "classification",  # NEW: capability-uplift or encoded-preference
    "template_managed",
    "template_section",
}

ALLOWED_FIELDS = ANTHROPIC_FIELDS | EXTENDED_FIELDS

VALID_CLASSIFICATIONS = {"capability-uplift", "encoded-preference"}


def validate_skill(skill_path: Path) -> tuple[bool, str, list[str]]:
    """Validate a skill directory.

    Returns:
        (valid, message, warnings)
    """
    skill_path = Path(skill_path)
    warnings = []

    # Check SKILL.md exists
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        return False, "SKILL.md not found", warnings

    content = skill_md.read_text()
    if not content.startswith("---"):
        return False, "No YAML frontmatter found", warnings

    # Extract frontmatter
    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return False, "Invalid frontmatter format", warnings

    frontmatter_text = match.group(1)

    # Simple YAML parsing (avoid dependency)
    frontmatter = {}
    for line in frontmatter_text.split("\n"):
        key_match = re.match(r"^(\w[\w-]*)\s*:", line)
        if key_match:
            key = key_match.group(1)
            frontmatter[key] = True  # Just track key presence

    # Check for unexpected keys
    unexpected = set(frontmatter.keys()) - ALLOWED_FIELDS
    if unexpected:
        warnings.append(
            f"Non-standard key(s): {', '.join(sorted(unexpected))}. "
            f"These are allowed but won't be recognized by Anthropic's official validator."
        )

    # Required fields
    if "name" not in frontmatter:
        return False, "Missing 'name' in frontmatter", warnings
    if "description" not in frontmatter:
        return False, "Missing 'description' in frontmatter", warnings

    # Validate name format
    name_match = re.search(r"^name:\s*(.+)", frontmatter_text, re.MULTILINE)
    if name_match:
        name = name_match.group(1).strip()
        if not re.match(r"^[a-z0-9-]+$", name):
            return False, f"Name '{name}' should be kebab-case", warnings
        if name.startswith("-") or name.endswith("-") or "--" in name:
            return False, f"Name '{name}' has invalid hyphen placement", warnings
        if len(name) > 64:
            return False, f"Name too long ({len(name)} chars, max 64)", warnings

    # Validate description length
    desc_match = re.search(
        r"^description:\s*\|?\s*\n((?:\s+.*\n)*)", frontmatter_text, re.MULTILINE
    )
    if not desc_match:
        desc_match = re.search(r"^description:\s*(.+)", frontmatter_text, re.MULTILINE)
    if desc_match:
        desc = desc_match.group(1).strip()
        if len(desc) > 1024:
            return False, f"Description too long ({len(desc)} chars, max 1024)", warnings
        if "<" in desc or ">" in desc:
            return False, "Description cannot contain angle brackets", warnings

    # Validate classification if present
    class_match = re.search(r"^classification:\s*(.+)", frontmatter_text, re.MULTILINE)
    if class_match:
        classification = class_match.group(1).strip()
        if classification not in VALID_CLASSIFICATIONS:
            warnings.append(
                f"Classification '{classification}' not recognized. "
                f"Valid: {', '.join(sorted(VALID_CLASSIFICATIONS))}"
            )

    # Content quality checks
    body = content[match.end():]
    line_count = len(body.strip().split("\n"))

    if line_count > 500:
        warnings.append(f"SKILL.md body is {line_count} lines (recommended max: 500)")

    # Check for evals directory (recommended for Level 2+ skills)
    evals_dir = skill_path / "evals"
    if not evals_dir.exists():
        warnings.append("No evals/ directory — consider adding evals for testing")

    return True, "Skill is valid!", warnings


def main():
    if len(sys.argv) != 2:
        print("Usage: python quick_validate.py <skill_directory>")
        sys.exit(1)

    valid, message, warnings = validate_skill(sys.argv[1])

    if warnings:
        for w in warnings:
            print(f"WARNING: {w}")

    print(message)
    sys.exit(0 if valid else 1)


if __name__ == "__main__":
    main()
