#!/usr/bin/env bash
# detect-persona.sh — 3-signal NewEarth-internal persona detection (skill: obsidian-vault-autopilot v1.0)
#
# Council A8 amendment: detection alone is insufficient; the skill MUST then prompt
# the operator for explicit confirmation before binding to any DB. This script is
# the detector ONLY — the confirmation prompt lives in SKILL.md.
#
# Council EdgeCase B-1 amendment: replaced free-text "NewEarth" grep with structured
# frontmatter field `agency: "newearthai"` (eliminates false positives where MEMORY.md
# mentions NewEarth as a vendor reference).
#
# Output (stdout): one of `newearth-internal`, `external`, `ambiguous`
# Exit code: 0 always (signal classification, not pass/fail)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || { echo "ambiguous"; exit 0; }

# Signal 1 — agency/ folder present at repo root
SIG_AGENCY=0
[ -d "$REPO_ROOT/agency" ] && SIG_AGENCY=1

# Signal 2 — MEMORY.md frontmatter contains structured `agency: "newearthai"` field
SIG_FRONTMATTER=0
for memfile in "$REPO_ROOT/MEMORY.md" "$REPO_ROOT/agency/memory/MEMORY.md" "$REPO_ROOT/.claude/memory/MEMORY.md"; do
  [ -f "$memfile" ] || continue
  if awk '/^---$/{if(++c==2) exit} c==1 && /agency:[[:space:]]*"?newearthai"?/' "$memfile" 2>/dev/null | grep -q "newearthai"; then
    SIG_FRONTMATTER=1
    break
  fi
done

# Signal 3 — git remote matches NewEarthAI/* OR NewEarth-AI/*
SIG_REMOTE=0
REMOTE_URL="$(git remote get-url origin 2>/dev/null || echo "")"
if echo "$REMOTE_URL" | grep -qiE "(github\.com[:/])(NewEarthAI|NewEarth-AI)/"; then
  SIG_REMOTE=1
fi

TOTAL=$((SIG_AGENCY + SIG_FRONTMATTER + SIG_REMOTE))

# Classification
case "$TOTAL" in
  3) echo "newearth-internal" ;;
  2) echo "newearth-internal" ;;  # 2-of-3 is sufficient signal — confirmation prompt is the final gate (A8)
  1) echo "ambiguous" ;;          # operator must clarify
  0) echo "external" ;;
esac

# Emit signal detail to stderr for debugging / report
{
  printf '%s\n' "[detect-persona] signals: agency=$SIG_AGENCY frontmatter=$SIG_FRONTMATTER remote=$SIG_REMOTE total=$TOTAL"
  printf '%s\n' "[detect-persona] remote=$REMOTE_URL"
} >&2

exit 0
