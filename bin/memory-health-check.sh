#!/usr/bin/env bash
# memory-health-check.sh — daily verification that the local-file memory layer is healthy.
#
# Three checks:
#   1. The Claude per-project memory dir is a symlink (not a real dir)
#   2. The symlink target matches this repo's agency/memory/ folder and exists
#   3. MEMORY.md at the target is under the 200-line system limit
#
# Exits non-zero on any failure so callers (daily-plan-generator Phase 0D.3) can
# surface a remediation step. Output is human-readable + ends with a one-line
# parsable status summary.
#
# Usage:
#   bash bin/memory-health-check.sh              # quiet on PASS, loud on FAIL
#   bash bin/memory-health-check.sh --verbose    # always print every check
#
# Composition:
#   - kairos-readiness.md — substrate doctrine (Supabase = durable SOT)
#   - symlink-discipline.md — when/why/how we use symlinks; cross-host (VPS) rules
#   - .claude/hooks/sessionstart-context-aggregator.sh — auto-creates the symlink

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENCODED=$(echo "$REPO_ROOT" | sed 's|/|-|g')
USER_MEMORY="$HOME/.claude/projects/${ENCODED}/memory"
REPO_MEMORY="$REPO_ROOT/agency/memory"
MEMORY_INDEX="$REPO_MEMORY/MEMORY.md"
MAX_LINES=200

VERBOSE=false
[ "${1:-}" = "--verbose" ] && VERBOSE=true

FAIL=0
NOTES=()

# ---------------------------------------------------------------------------
# Check 1 — Claude memory dir is a symlink
# ---------------------------------------------------------------------------
if [ -L "$USER_MEMORY" ]; then
  $VERBOSE && echo "✓ memory dir is a symlink"
elif [ -d "$USER_MEMORY" ]; then
  echo "⚠ memory dir is a REAL directory, not a symlink. Cross-machine sync is broken."
  echo "  Fix: bash $REPO_ROOT/bin/setup-claude-memory.sh"
  NOTES+=("memory_dir_not_symlinked")
  FAIL=1
elif [ -e "$USER_MEMORY" ]; then
  echo "⚠ memory path exists but is neither symlink nor directory. Inspect manually."
  NOTES+=("memory_path_unknown_type")
  FAIL=1
else
  echo "⚠ memory dir missing. SessionStart hook should create it on session open."
  echo "  First-time activation on this Mac: bash $REPO_ROOT/bin/enable-cross-machine-memory.sh"
  echo "  Subsequent machines: just open any Claude session in this repo."
  NOTES+=("memory_dir_missing")
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Check 2 — Symlink target matches expected git-tracked folder + exists
# ---------------------------------------------------------------------------
if [ -L "$USER_MEMORY" ]; then
  STORED_TARGET="$(readlink "$USER_MEMORY")"
  if [ ! -d "$STORED_TARGET" ]; then
    echo "⚠ memory symlink is dangling. Target does not exist:"
    echo "    $STORED_TARGET"
    echo "  Cause: agency/memory/ was renamed/deleted, or repo moved on disk."
    NOTES+=("dangling_symlink")
    FAIL=1
  elif [ "$STORED_TARGET" != "$REPO_MEMORY" ]; then
    echo "⚠ memory symlink target drift:"
    echo "    actual:   $STORED_TARGET"
    echo "    expected: $REPO_MEMORY"
    echo "  Likely cause: repo cloned at a different path than when symlink was created."
    NOTES+=("symlink_target_drift")
    FAIL=1
  else
    $VERBOSE && echo "✓ symlink target is the git-tracked agency/memory folder"
  fi
fi

# ---------------------------------------------------------------------------
# Check 3 — MEMORY.md size under the 200-line ceiling
# ---------------------------------------------------------------------------
if [ -f "$MEMORY_INDEX" ]; then
  LINES=$(wc -l < "$MEMORY_INDEX" | tr -d ' ')
  if [ "$LINES" -gt "$MAX_LINES" ]; then
    echo "⚠ MEMORY.md is $LINES lines (limit: $MAX_LINES). Run /refactor-memory-md."
    NOTES+=("memory_md_oversize:$LINES")
    FAIL=1
  else
    $VERBOSE && echo "✓ MEMORY.md is $LINES lines (under the $MAX_LINES limit)"
  fi
else
  echo "⚠ MEMORY.md not found at $MEMORY_INDEX"
  NOTES+=("memory_md_missing")
  FAIL=1
fi

# ---------------------------------------------------------------------------
# Status summary — one parsable line at the end
# ---------------------------------------------------------------------------
if [ "$FAIL" -eq 0 ]; then
  echo "✓ memory-health: PASS"
else
  echo "⚠ memory-health: FAIL (${NOTES[*]})"
fi

exit "$FAIL"
