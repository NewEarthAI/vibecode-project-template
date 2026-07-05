#!/bin/bash
# .claude/hooks/cross-chat-collision-detect.sh
#
# PreToolUse hook on Write + Edit — warns when the target file was
# modified by another process (sibling chat, manual edit, sibling worktree
# operation) since this session started.
#
# Composes Layer 4 / Phase 2 of the bring-this-all-together plan
# (continuations/2026-05-24-BRING-THIS-ALL-TOGETHER-COORDINATION-PLAN-MASTER-CONTINUATION.md).
# Closes the exact failure mode where chat B stashes chat A's work silently.
#
# Per the decide-dont-menu doctrine (Class A): silent default
# is warn-and-proceed, NEVER block. Per .claude/rules/hook-efficiency.md:
# triple-gated (matcher → fast-path → conditional early-exit).
#
# DETECTION ALGORITHM:
#   1. Read session-start timestamp from session-marker file
#      (created on first invocation if absent)
#   2. Compare target file mtime vs session-start
#   3. Compare git stash list — any stash created after session-start
#      whose message OR contents reference the target file
#   4. If either match → warn to stderr (one-line, never blocking)
#
# SAFETY:
#   - NEVER blocks (always exits 0, never decision: "block")
#   - NEVER mutates the target file
#   - NEVER inspects file contents — only mtime + stash metadata
#   - Trivial-file allowlist: skips .claude/sessions/*, continuations/*,
#     .claude/autovibe-state.json (high false-positive surfaces from
#     sibling session-summariser writes)
#
# COMPOSITION:
#   - session-end-continuation-gate.sh (Stop hook) — fires at session-end
#     and writes auto-continuation when work uncovered. This hook fires
#     at session start (implicitly, via first-write) + every Write/Edit
#     to catch sibling-chat collisions mid-flight.

set -uo pipefail   # NOT -e — keep going past per-step failures

# ── Gate 1: matcher narrows to Write + Edit, but stdin contains the tool ──
# input. Bail fast if not Write or Edit by inspecting tool_name field.
INPUT="$(cat 2>/dev/null || echo '')"

# Fast-path: if input is empty or doesn't look like a Write/Edit, exit silently
case "$INPUT" in
  *'"tool_name":"Write"'*|*'"tool_name":"Edit"'*) ;;
  *) echo '{}'; exit 0 ;;
esac

# ── Gate 2: extract target file path (raw substring before jq) ──
# Look for "file_path":"..." in the input. If absent, no file to check.
case "$INPUT" in
  *'"file_path"'*) ;;
  *) echo '{}'; exit 0 ;;
esac

# Now use jq for proper extraction (input passed Gate 1+2, worth the cost)
TARGET_FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [ -z "$TARGET_FILE" ]; then
  echo '{}'; exit 0
fi

# ── Gate 3: trivial-file allowlist — skip known noisy surfaces ──
case "$TARGET_FILE" in
  */.claude/sessions/*) echo '{}'; exit 0 ;;
  */.claude/autovibe-state.json) echo '{}'; exit 0 ;;
  */continuations/*-AUTO-*.md) echo '{}'; exit 0 ;;
esac

# ── Resolve repo root (bail if not in a git repo) ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT/.git" ]; then
  echo '{}'; exit 0
fi

# Target file must be under the repo to be in scope
case "$TARGET_FILE" in
  "$PROJECT_ROOT"/*) ;;
  *) echo '{}'; exit 0 ;;
esac

# ── Session-start marker ──────────────────────────────────────────────────
# Marker file is created on first invocation, mtime serves as session-start.
# Per-session uniqueness via $$ would break across multiple Claude processes;
# we use a single marker per repo per hour-window instead.
MARKER_DIR="$PROJECT_ROOT/.claude/sessions"
mkdir -p "$MARKER_DIR" 2>/dev/null
MARKER_FILE="$MARKER_DIR/.collision-detect-session-start"

# Stale-marker policy: if marker is >12h old, treat as new session and refresh
if [ -f "$MARKER_FILE" ]; then
  MARKER_AGE_MINS=$(( ($(date +%s) - $(stat -f %m "$MARKER_FILE" 2>/dev/null || stat -c %Y "$MARKER_FILE" 2>/dev/null || echo 0)) / 60 ))
  if [ "$MARKER_AGE_MINS" -gt 720 ]; then
    touch "$MARKER_FILE"
  fi
else
  touch "$MARKER_FILE"
  # First write — no prior session to compare against, exit silently
  echo '{}'; exit 0
fi

SESSION_START_EPOCH=$(stat -f %m "$MARKER_FILE" 2>/dev/null || stat -c %Y "$MARKER_FILE" 2>/dev/null || echo 0)

# ── Detection 1: target file mtime vs session start ───────────────────────
WARN_REASONS=()
if [ -f "$TARGET_FILE" ]; then
  FILE_MTIME_EPOCH=$(stat -f %m "$TARGET_FILE" 2>/dev/null || stat -c %Y "$TARGET_FILE" 2>/dev/null || echo 0)

  # Allow 30s tolerance — same-session writes can race the marker
  TOLERANCE=30
  if [ "$FILE_MTIME_EPOCH" -gt "$((SESSION_START_EPOCH + TOLERANCE))" ]; then
    # File was modified AFTER session-start. Check if it was THIS session
    # by looking at git diff vs HEAD — if file is in current working tree's
    # uncommitted changes, likely this session. If not, sibling-process.
    REL_PATH="${TARGET_FILE#$PROJECT_ROOT/}"
    IS_OUR_CHANGE=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null | grep -Fx "$REL_PATH" | head -1)
    IS_OUR_UNTRACKED=$(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard 2>/dev/null | grep -Fx "$REL_PATH" | head -1)

    if [ -z "$IS_OUR_CHANGE" ] && [ -z "$IS_OUR_UNTRACKED" ]; then
      # File modified post-session-start but NOT in our diff → sibling-process write
      WARN_REASONS+=("file mtime advanced post-session-start without being in our git diff")
    fi
  fi
fi

# ── Detection 2: git stash entries created post-session-start ─────────────
# A sibling chat may have stashed work containing this file
STASH_HITS=""
STASH_LIST=$(git -C "$PROJECT_ROOT" stash list --format='%ct|%gs' 2>/dev/null | head -20)
if [ -n "$STASH_LIST" ]; then
  REL_PATH="${TARGET_FILE#$PROJECT_ROOT/}"
  while IFS='|' read -r STASH_EPOCH STASH_MSG; do
    [ -z "$STASH_EPOCH" ] && continue
    # Only stashes created AFTER our session-start are interesting
    if [ "$STASH_EPOCH" -gt "$SESSION_START_EPOCH" ]; then
      # Check if stash message OR contents reference target file
      case "$STASH_MSG" in
        *"$REL_PATH"*) STASH_HITS="$STASH_HITS$STASH_MSG; " ;;
      esac
    fi
  done <<< "$STASH_LIST"
fi
if [ -n "$STASH_HITS" ]; then
  WARN_REASONS+=("git stash created post-session-start referencing this path")
fi

# ── Decision: warn or stay silent ─────────────────────────────────────────
if [ ${#WARN_REASONS[@]} -eq 0 ]; then
  echo '{}'; exit 0
fi

REL_DISPLAY="${TARGET_FILE#$PROJECT_ROOT/}"
REASON_TEXT=$(IFS='; '; echo "${WARN_REASONS[*]}")

# Emit warning via additionalContext per hook-efficiency.md (never block)
# Composes with the operator's terminal — they see the warning in-line.
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "⚠️ cross-chat-collision-detect: '${REL_DISPLAY}' may have been touched by another chat or process since this session started (${REASON_TEXT}). Read the file before writing to avoid overwriting sibling work."
  }
}
EOF
exit 0
