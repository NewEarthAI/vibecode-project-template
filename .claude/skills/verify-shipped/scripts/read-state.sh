#!/usr/bin/env bash
# read-state.sh — primitive used by autovibe Phase 4.5 + daily-plan Phase 1.5
#
# Reads the most recent `/verify-shipped` state file. Returns:
#   exit 0 + JSON on stdout    — state is valid, fresh, and not interrupted
#   exit 1 + reason on stderr  — state is missing OR stale OR interrupted (caller should refresh)
#   exit 2 + reason on stderr  — state file is malformed JSON (caller should investigate)
#
# Canonical path:  .claude/verify-shipped-last-run.json
# Legacy fallback: .claude/verify-fleet-last-run.json (defensive — v1.0 ships canonical)
#
# Staleness threshold defaults to 24h. Override via --max-age <seconds>.
#
# Usage:
#   bash read-state.sh                       # default 24h staleness
#   bash read-state.sh --max-age 3600        # 1h staleness
#   bash read-state.sh --max-age 0           # disable staleness check (always fresh)
#
# Pure bash + jq. No MCP, no network. Bash 3.2 portable per shell-portability.md.

set -uo pipefail

# Resolve repo root (works from any cwd) per shell-portability.md
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Canonical + legacy paths
CANONICAL="$REPO_ROOT/.claude/verify-shipped-last-run.json"
LEGACY="$REPO_ROOT/.claude/verify-fleet-last-run.json"

# Default staleness threshold: 24h (86400s)
MAX_AGE_SECONDS=86400

# Parse flags
while [ $# -gt 0 ]; do
  case "$1" in
    --max-age)
      shift
      MAX_AGE_SECONDS="${1:-86400}"
      shift
      ;;
    --max-age=*)
      MAX_AGE_SECONDS="${1#--max-age=}"
      shift
      ;;
    *)
      echo "[ERROR] unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

# Numeric normaliser per shell-portability.md §6
to_int() {
  local raw="${1:-0}"
  raw=$(printf '%s' "$raw" | tr -dc '0-9' | head -c 10)
  printf '%s' "${raw:-0}"
}

MAX_AGE_SECONDS=$(to_int "$MAX_AGE_SECONDS")

# Choose state file: canonical first, legacy fallback
STATE_FILE=""
USED_LEGACY=0
if [ -f "$CANONICAL" ]; then
  STATE_FILE="$CANONICAL"
elif [ -f "$LEGACY" ]; then
  STATE_FILE="$LEGACY"
  USED_LEGACY=1
fi

# Missing entirely
if [ -z "$STATE_FILE" ]; then
  echo "[MISSING] no state file at $CANONICAL (or legacy $LEGACY) — caller should run /verify-shipped quick" >&2
  exit 1
fi

# Verify jq is present (caller's responsibility, but fail loud if not)
if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq not found on PATH — read-state.sh requires jq for JSON parsing" >&2
  exit 2
fi

# Validate JSON shape — must parse + have a timestamp field
if ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
  echo "[MALFORMED] $STATE_FILE is not valid JSON" >&2
  exit 2
fi

TIMESTAMP=$(jq -r '.timestamp // empty' "$STATE_FILE")
if [ -z "$TIMESTAMP" ]; then
  echo "[MALFORMED] $STATE_FILE missing required field: timestamp" >&2
  exit 2
fi

# Check interrupted flag (set by trap-on-INT/TERM in /verify-shipped Phase 0/8)
# IMPORTANT: when MAX_AGE_SECONDS=0 (caller wants ANY cached state regardless of age),
# we ALSO bypass the interrupted check — the caller is the lock-contention fallback path
# in SKILL.md Phase 0 + autovibe Phase 4.5. Returning exit 1 here would trigger a fresh
# /verify-shipped invocation that contends for the still-held lock = retry storm.
# Code-council 2026-05-07 silent-failure-hunter CRITICAL #2.
INTERRUPTED=$(jq -r '.interrupted // false' "$STATE_FILE")
if [ "$INTERRUPTED" = "true" ] && [ "$MAX_AGE_SECONDS" -gt 0 ]; then
  echo "[INTERRUPTED] last /verify-shipped run was interrupted ($TIMESTAMP) — caller should refresh" >&2
  exit 1
fi

# Compute age in seconds — macOS BSD `date` syntax differs from GNU
# `date -j -f` parses ISO-8601 on BSD; `date -d` parses on GNU
# CRITICAL: BSD `date -j -f` ignores the trailing 'Z' and parses input as LOCAL time.
# Prefix `TZ=UTC` to interpret the input as UTC — otherwise SAST/EDT/PDT-zoned
# Macs compute wrong age (proven 2026-05-07: SAST UTC+2 produced 3h diff on 1h-old stamp).
NOW_EPOCH=$(date -u +%s)
TS_EPOCH=""
if TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TIMESTAMP" +%s >/dev/null 2>&1; then
  # macOS BSD path
  TS_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TIMESTAMP" +%s 2>/dev/null)
elif date -d "$TIMESTAMP" +%s >/dev/null 2>&1; then
  # GNU path (Linux/CI) — `date -d` honours the Z suffix natively
  TS_EPOCH=$(date -d "$TIMESTAMP" +%s 2>/dev/null)
else
  echo "[MALFORMED] $STATE_FILE has unparseable timestamp: $TIMESTAMP" >&2
  exit 2
fi

TS_EPOCH=$(to_int "$TS_EPOCH")
if [ "$TS_EPOCH" = "0" ]; then
  echo "[MALFORMED] $STATE_FILE timestamp parsed to zero: $TIMESTAMP" >&2
  exit 2
fi

AGE_SECONDS=$((NOW_EPOCH - TS_EPOCH))

# Stale check (skip when MAX_AGE_SECONDS=0 — caller wants to read regardless of age)
if [ "$MAX_AGE_SECONDS" -gt 0 ] && [ "$AGE_SECONDS" -gt "$MAX_AGE_SECONDS" ]; then
  echo "[STALE] $STATE_FILE is ${AGE_SECONDS}s old (threshold ${MAX_AGE_SECONDS}s; ts=$TIMESTAMP) — caller should refresh" >&2
  exit 1
fi

# Legacy fallback notice — emit ONCE on stderr so callers can log a migration hint
if [ "$USED_LEGACY" = "1" ]; then
  echo "[INFO] state-file legacy path detected ($LEGACY); next /verify-shipped run will write canonical $CANONICAL" >&2
fi

# Success — emit raw JSON on stdout
cat "$STATE_FILE"
exit 0
