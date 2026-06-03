#!/usr/bin/env bash
# autovibe/post-ship.sh — post-push documentation step
# Invoked by the conversation after /ship returns 0.
#
# Reads:
#   .claude/ship-state.json     (ship's published artifacts)
#   .claude/autovibe-state.json (autovibe's own state)
# Writes:
#   .claude/autovibe-sessions/<ts>.md  (always — session log)
#   memory/feedback_autovibe_<ts>-<slug>.md  (only on novel outcomes)
#
# REVISED 2026-04-19 (post-code-council):
# - jq for state-file reads (kills grep/sed corruption class)
# - Accumulate memory-write reasons (was OR-chain; lost combined signals)
# - Heredoc inputs sanitized — quoted heredocs + safe substitution
# - write-num for numeric/null exit_code
#
# Memory write decision (per CLAUDE.md memory guidance):
#   SKIP: clean ship + no rollback + no admin-merge + no smoke unverifiability
#   WRITE: any of {non-zero ship exit, smoke rollback, admin-merge, smoke unverifiable}
#   Multi-signal: REASONS array accumulates all matches; saved together.
#
# Exit: 0 always. Doc step is opportunistic — failures here log to stderr but don't block.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIP_STATE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/ship-state.json"
AV_STATE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/autovibe-state.json"
SESSIONS_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/autovibe-sessions"
MEMORY_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/memory"
ROADMAP_ARCHIVE="${CLAUDE_PROJECT_DIR:-$(pwd)}/specs/ROADMAP-ARCHIVE.md"

# Args (optional — for evals/test that mock state):
#   $1 = ship_exit_code   (default: read from ship-state.json)
#   $2 = ship_signal      (one of: clean, rollback, admin_merge, smoke_unverifiable)
SHIP_EXIT="${1:-}"
SHIP_SIGNAL="${2:-clean}"

ts_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ts_slug() { date -u +%Y-%m-%d-%H%M; }

# Validate jq is present
if ! command -v jq >/dev/null 2>&1; then
  echo "post-ship: jq not found in PATH — required dependency" >&2
  exit 0
fi

# _read: safe field read via jq. Empty if missing.
_read() {
  local key="$1" file="$2"
  [ -f "$file" ] || { echo ""; return; }
  jq -r --arg k "$key" '.[$k] // empty' "$file" 2>/dev/null
}

# _read_nested: read a.b path
_read_nested() {
  local path="$1" file="$2"
  [ -f "$file" ] || { echo ""; return; }
  jq -r ".$path // empty" "$file" 2>/dev/null
}

# ─── Read state ──────────────────────────────────────────────

if [ ! -f "$AV_STATE" ]; then
  echo "post-ship: $AV_STATE missing — autovibe didn't acquire state. Skipping doc." >&2
  exit 0
fi

AV_UUID=$(_read session_uuid "$AV_STATE")
AV_STARTED=$(_read started_at "$AV_STATE")
AV_INTENT=$(_read intent "$AV_STATE")
AV_BRANCH=$(_read branch "$AV_STATE")

SHIP_SHA=""
SHIP_COMPLETED=""
SHIP_PR=""
if [ -f "$SHIP_STATE" ]; then
  SHIP_SHA=$(_read commit_sha "$SHIP_STATE")
  SHIP_COMPLETED=$(_read completed_at "$SHIP_STATE")
  SHIP_PR=$(_read pr_number "$SHIP_STATE")
  if [ -z "$SHIP_EXIT" ]; then
    SHIP_EXIT=$(_read exit_code "$SHIP_STATE")
  fi
fi

[ -z "$SHIP_EXIT" ] && SHIP_EXIT="0"
[ -z "$SHIP_SHA" ] && SHIP_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
[ -z "$SHIP_PR" ] && SHIP_PR="null"

# ─── Compute elapsed ─────────────────────────────────────────

ELAPSED_SEC="?"
if [ -n "$AV_STARTED" ] && [ -n "$SHIP_COMPLETED" ]; then
  started_s=0
  completed_s=0
  if started_s=$(date -u -d "$AV_STARTED" +%s 2>/dev/null); then
    completed_s=$(date -u -d "$SHIP_COMPLETED" +%s 2>/dev/null || echo 0)
  elif started_s=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$AV_STARTED" +%s 2>/dev/null); then
    completed_s=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$SHIP_COMPLETED" +%s 2>/dev/null || echo 0)
  fi
  if [ "$started_s" -gt 0 ] && [ "$completed_s" -gt 0 ]; then
    ELAPSED_SEC=$((completed_s - started_s))
  fi
fi

# ─── Detect file count + commit msg for ROADMAP closure ─────

FILE_COUNT=0
if [ "$SHIP_SHA" != "unknown" ]; then
  FILE_COUNT=$(git diff-tree --no-commit-id -r --name-only "$SHIP_SHA" 2>/dev/null | wc -l | tr -d ' ')
  [ -z "$FILE_COUNT" ] && FILE_COUNT=0
fi
COMMIT_MSG=""
if [ "$SHIP_SHA" != "unknown" ]; then
  COMMIT_MSG=$(git log -1 --format=%s "$SHIP_SHA" 2>/dev/null || echo "")
fi

# Roadmap ID match — supports INFRA.1, A2, CM.10, 5B.44, plus bare letters+digits like A2.
# Two patterns: (a) PREFIX.NUMBER  (b) bare LETTERS+DIGITS (e.g. A2, B3, CM10)
ROADMAP_IDS_DOTTED=$(echo "$COMMIT_MSG" | grep -oE '\b[A-Z]{1,5}[0-9]?\.[0-9]+\b' 2>/dev/null | sort -u | tr '\n' ' ')
ROADMAP_IDS_BARE=$(echo "$COMMIT_MSG" | grep -oE '\b[A-Z]{1,3}[0-9]+\b' 2>/dev/null | grep -vE '\.' | sort -u | tr '\n' ' ')
ROADMAP_IDS="${ROADMAP_IDS_DOTTED}${ROADMAP_IDS_BARE}"
ROADMAP_IDS=$(echo "$ROADMAP_IDS" | xargs)  # trim

# ─── Always: append session log (sanitized inputs) ──────────

mkdir -p "$SESSIONS_DIR"
SESSION_LOG="$SESSIONS_DIR/$(ts_slug)-${AV_UUID:0:8}.md"

# Sanitize values for safe markdown insertion: strip backticks, $(, `, control chars
_sanitize_md() {
  echo "$1" | tr -d '`$\\' | tr -d '\000-\010\013\014\016-\037'
}
SAFE_INTENT=$(_sanitize_md "$AV_INTENT")
SAFE_BRANCH=$(_sanitize_md "$AV_BRANCH")
SAFE_REASON_PLACEHOLDER=""

# QUOTED heredoc — no command substitution, no variable interpolation
{
  echo "# Autovibe session $(ts_slug) (uuid: ${AV_UUID:0:8})"
  echo ""
  echo "**Intent:** $SAFE_INTENT"
  echo "**Branch:** $SAFE_BRANCH"
  echo "**Started:** $AV_STARTED"
  echo "**Ship completed:** ${SHIP_COMPLETED:-unknown}"
  echo "**Elapsed:** ${ELAPSED_SEC}s"
  echo "**Ship exit:** $SHIP_EXIT (signal: $SHIP_SIGNAL)"
  echo "**Commit:** $SHIP_SHA"
  echo "**PR:** $SHIP_PR"
  echo "**Files changed:** $FILE_COUNT"
  echo "**Roadmap IDs in commit msg:** ${ROADMAP_IDS:-none}"
  echo ""
} >> "$SESSION_LOG"
echo "post-ship: wrote session log: $SESSION_LOG" >&2

# ─── Conditional: memory write — accumulate reasons ────────

REASONS=()
if [ "$SHIP_EXIT" != "0" ]; then
  REASONS+=("non-zero ship exit ($SHIP_EXIT)")
fi
case "$SHIP_SIGNAL" in
  rollback)            REASONS+=("auto-rollback fired") ;;
  admin_merge)         REASONS+=("admin-merge bypass invoked") ;;
  smoke_unverifiable)  REASONS+=("smoke unverifiable (no header)") ;;
esac

if [ "${#REASONS[@]}" -gt 0 ] && [ -d "$MEMORY_DIR" ]; then
  # Build slug from sanitized intent (no path traversal possible — sed strips /, ., ..)
  SLUG=$(echo "$SAFE_INTENT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | cut -c1-40 | sed 's/-$//')
  [ -z "$SLUG" ] && SLUG="unnamed"
  MEM_FILE="$MEMORY_DIR/feedback_autovibe_$(ts_slug)-${SLUG}.md"
  REASON_JOINED=$(IFS='; '; echo "${REASONS[*]}")
  {
    echo "---"
    echo "name: Autovibe ship $(ts_slug) — ${REASON_JOINED}"
    echo "description: Autovibe shipped \"${SAFE_INTENT}\" with notable signal — ${REASON_JOINED}. Captured for future regression awareness."
    echo "type: feedback"
    echo "---"
    echo ""
    echo "**Intent:** ${SAFE_INTENT}"
    echo "**Outcome:** ${REASON_JOINED}"
    echo "**Branch:** ${SAFE_BRANCH}"
    echo "**Commit:** ${SHIP_SHA}"
    echo "**PR:** ${SHIP_PR}"
    echo "**Ship exit:** ${SHIP_EXIT}"
    echo "**Elapsed:** ${ELAPSED_SEC}s"
    echo ""
    echo "**Why:** This run produced an outcome that diverges from the clean-ship baseline. Save so future autovibe runs can detect the same pattern early or avoid the same trap."
    echo ""
    echo "**How to apply:** When a future autovibe invocation has similar intent shape OR touches the same files, surface this memory in the prime-lite briefing as a precedent."
  } > "$MEM_FILE"
  echo "post-ship: wrote memory entry: $MEM_FILE (${REASON_JOINED})" >&2
elif [ "${#REASONS[@]}" -gt 0 ]; then
  REASON_JOINED=$(IFS='; '; echo "${REASONS[*]}")
  echo "post-ship: would write memory ($REASON_JOINED) but $MEMORY_DIR doesn't exist" >&2
else
  echo "post-ship: clean ship, no memory entry needed" >&2
fi

# ─── Conditional: ROADMAP closure ──────────────────────────

if [ -n "$ROADMAP_IDS" ] && [ -f "$ROADMAP_ARCHIVE" ]; then
  {
    echo "## Closed by autovibe $(ts_slug)"
    for id in $ROADMAP_IDS; do
      # COMMIT_MSG sanitized for archive: strip backticks/dollar to prevent renderer issues
      SAFE_MSG=$(_sanitize_md "$COMMIT_MSG")
      echo "- $id — commit $SHIP_SHA — \"$SAFE_MSG\""
    done
  } >> "$ROADMAP_ARCHIVE"
  echo "post-ship: appended ROADMAP closure for: $ROADMAP_IDS" >&2
fi

# ─── Update autovibe state to complete (use jq-backed writes) ─

bash "$SCRIPT_DIR/state.sh" write phase "complete" 2>/dev/null \
  || echo "post-ship: state write 'phase' failed" >&2
bash "$SCRIPT_DIR/state.sh" write current_step "post_push_done" 2>/dev/null \
  || echo "post-ship: state write 'current_step' failed" >&2
bash "$SCRIPT_DIR/state.sh" write-num exit_code "$SHIP_EXIT" 2>/dev/null \
  || echo "post-ship: state write-num 'exit_code' failed" >&2

# ─── Pillar B' — write structural draft continuation for next chat ─
# post-handoff-writer is opportunistic: failures log to stderr but never
# block the session-end path. Prints "Continuation written to: <path>" on
# success or "Continuation skipped: <reason>" otherwise (heartbeat — see
# council session 2026-04-30-agentic-os-architecture-pillars-extended.md).
bash "$SCRIPT_DIR/post-handoff-writer.sh" "$SHIP_EXIT" "$SHIP_SIGNAL" 2>/dev/null \
  || echo "post-ship: post-handoff-writer.sh failed" >&2

exit 0
