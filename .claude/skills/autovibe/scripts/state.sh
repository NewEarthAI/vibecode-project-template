#!/usr/bin/env bash
# autovibe/state.sh — atomic-mkdir lock + JSON state file for /autovibe
# Mirrors /ship/scripts/lock.sh patterns (atomic mkdir, TTL, trap discipline).
#
# REVISED 2026-04-19 (post-code-council): replaced grep/sed JSON ops with jq.
# Kills the entire class of (a) quote/newline/special-char corruption,
# (b) silent-noop on null-initialized fields, (c) regex injection via $key/$val.
# jq is system-installed on macOS at /usr/bin/jq; required dependency.
#
# Usage:
#   state.sh acquire [intent]              → exit 0 acquired, 5 held, 6 corrupt
#   state.sh release                       → exit 0 (idempotent)
#   state.sh inspect                       → prints current state JSON or "none"
#   state.sh write <key> <value>           → updates state field (any JSON-safe value)
#   state.sh write-num <key> <value>       → updates state field as JSON number/null
#   state.sh read <key>                    → prints state field
#
# TTL: 30 minutes (autovibe runs longer than ship — full plan→council→exec→ship)
# Future-tolerance: 60 minutes (clock-skew bound)

set -uo pipefail

LOCK_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/autovibe-state.lock"
STATE_FILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/autovibe-state.json"
TTL_MIN=30
FUTURE_TOLERANCE_MIN=60

ts_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ts_epoch() { date -u +%s; }

iso_to_epoch() {
  local iso="$1"
  local result
  if result=$(date -u -d "$iso" +%s 2>/dev/null); then echo "$result"; return; fi
  if result=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null); then echo "$result"; return; fi
  echo 0
}

# Validate jq is present — REQUIRED dependency post-council fix.
if ! command -v jq >/dev/null 2>&1; then
  echo "state.sh: jq not found in PATH — required dependency (install via 'brew install jq')" >&2
  exit 6
fi

# _read_field: safe field read using jq. Empty string if field missing/null/file missing.
_read_field() {
  local key="$1" file="$2"
  [ -f "$file" ] || { echo ""; return; }
  jq -r --arg k "$key" '.[$k] // empty' "$file" 2>/dev/null
}

# _write_field: atomic JSON write via jq + mv. Handles any string value safely.
# $1 = key (must match ^[a-z_]+$), $2 = value (string), $3 = type (string|number|bool|null)
_write_field() {
  local key="$1" val="$2" jtype="${3:-string}"
  # Validate key shape — defense against injection of `.` paths or special chars
  if ! echo "$key" | grep -qE '^[a-z_][a-z0-9_]*$'; then
    echo "state.sh: invalid key '$key' (must match ^[a-z_][a-z0-9_]*$)" >&2
    return 2
  fi
  [ -f "$STATE_FILE" ] || { echo "state.sh: state file missing — acquire first" >&2; return 6; }
  local tmp
  tmp=$(mktemp)
  case "$jtype" in
    string)
      jq --arg k "$key" --arg v "$val" '.[$k] = $v' "$STATE_FILE" > "$tmp"
      ;;
    number)
      jq --arg k "$key" --argjson v "${val:-0}" '.[$k] = $v' "$STATE_FILE" > "$tmp"
      ;;
    null)
      jq --arg k "$key" '.[$k] = null' "$STATE_FILE" > "$tmp"
      ;;
    bool)
      jq --arg k "$key" --argjson v "$val" '.[$k] = $v' "$STATE_FILE" > "$tmp"
      ;;
    *)
      echo "state.sh: unknown type '$jtype'" >&2
      rm -f "$tmp"
      return 2
      ;;
  esac
  if [ ! -s "$tmp" ]; then
    echo "state.sh: jq produced empty output — write rejected (state preserved)" >&2
    rm -f "$tmp"
    return 6
  fi
  mv "$tmp" "$STATE_FILE"
}

# _try_acquire_fresh: atomic mkdir + jq-based JSON write. Returns 0 if acquired.
# Defense against symlink TOCTOU: refuse if LOCK_DIR pre-exists as symlink.
_try_acquire_fresh() {
  local intent="$1"
  if [ -L "$LOCK_DIR" ]; then
    echo "state.sh: $LOCK_DIR is a symlink — refusing (potential TOCTOU); inspect and remove" >&2
    return 6
  fi
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    local uuid
    uuid="${CLAUDE_SESSION_ID:-$(uuidgen 2>/dev/null || echo $$)}"
    mkdir -p "$(dirname "$STATE_FILE")"
    local branch
    branch="$(git branch --show-current 2>/dev/null || echo unknown)"
    # Build state via jq — handles any-character intent safely
    local tmp
    tmp=$(mktemp)
    jq -n \
      --arg uuid "$uuid" \
      --arg started "$(ts_now)" \
      --arg intent "$intent" \
      --arg branch "$branch" \
      '{
        session_uuid: $uuid,
        started_at: $started,
        phase: "initialized",
        current_step: "preflight",
        intent: $intent,
        branch: $branch,
        artifacts: {
          plan_path: null,
          pr_number: null,
          merged_sha: null,
          rollback_cmd: null
        },
        completed_at: null,
        exit_code: null
      }' > "$tmp"
    if [ -s "$tmp" ]; then
      mv "$tmp" "$STATE_FILE"
      return 0
    else
      rm -f "$tmp"
      rmdir "$LOCK_DIR" 2>/dev/null || true
      echo "state.sh: failed to write initial state JSON" >&2
      return 6
    fi
  fi
  return 1  # mkdir failed — lock held
}

action="${1:-}"

case "$action" in
  acquire)
    intent="${2:-unspecified}"

    if _try_acquire_fresh "$intent"; then
      exit 0
    fi
    fresh_exit=$?
    if [ "$fresh_exit" = "6" ]; then
      exit 6  # symlink refusal
    fi

    # Lock dir held — inspect
    if [ ! -f "$STATE_FILE" ]; then
      echo "state: lock dir exists but state file missing — corrupt; remove $LOCK_DIR to recover" >&2
      exit 6
    fi

    started=$(_read_field started_at "$STATE_FILE")
    held_uuid=$(_read_field session_uuid "$STATE_FILE")
    held_phase=$(_read_field phase "$STATE_FILE")

    if [ -z "$started" ]; then
      echo "state: state file missing required fields — corrupt; inspect $STATE_FILE" >&2
      exit 6
    fi

    now_s=$(ts_epoch)
    started_s=$(iso_to_epoch "$started")
    # Guard: empty/non-numeric → treat as corrupt (prevents arithmetic crash under set -u)
    [ -z "$started_s" ] && started_s=0
    if [ "$started_s" = "0" ]; then
      echo "state: cannot parse started_at ($started) — corrupt; inspect $STATE_FILE" >&2
      exit 6
    fi

    if [ "$started_s" -gt "$((now_s + FUTURE_TOLERANCE_MIN * 60))" ]; then
      echo "state: started_at ($started) is more than ${FUTURE_TOLERANCE_MIN}min in the future — clock skew" >&2
      echo "  If clock was wrong, run: rm -rf $LOCK_DIR $STATE_FILE" >&2
      exit 6
    fi

    age_min=$(( (now_s - started_s) / 60 ))
    if [ "$age_min" -ge "$TTL_MIN" ]; then
      # TTL expired — take over via SAME-PROCESS acquire (no exec; eliminates re-exec race + stale-intent injection)
      rm -rf "$LOCK_DIR" "$STATE_FILE" 2>/dev/null || true
      if _try_acquire_fresh "$intent"; then
        echo "state: reclaimed stale lock (was age ${age_min}min, holder uuid ${held_uuid:-unknown})" >&2
        exit 0
      else
        echo "state: tried to reclaim stale lock but mkdir lost the race — try again" >&2
        exit 5
      fi
    fi

    echo "state: another /autovibe session (uuid: ${held_uuid:-unknown}, phase: ${held_phase:-unknown}) is active (started ${started}, age ${age_min}min)" >&2
    echo "  Wait or: rm -rf $LOCK_DIR $STATE_FILE  (only if you're sure the other session crashed)" >&2
    exit 5
    ;;

  release)
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    # Leave STATE_FILE for audit; carries completed_at + exit_code
    exit 0
    ;;

  inspect)
    if [ ! -d "$LOCK_DIR" ] && [ ! -f "$STATE_FILE" ]; then
      echo "none"
      exit 0
    fi
    [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "lock dir exists, no state file"
    exit 0
    ;;

  write)
    key="${2:-}"; val="${3:-}"
    [ -z "$key" ] && { echo "state.sh write: missing key" >&2; exit 2; }
    _write_field "$key" "$val" "string"
    exit $?
    ;;

  write-num)
    key="${2:-}"; val="${3:-}"
    [ -z "$key" ] && { echo "state.sh write-num: missing key" >&2; exit 2; }
    if [ -z "$val" ] || [ "$val" = "null" ]; then
      _write_field "$key" "" "null"
    else
      # Validate numeric
      if ! echo "$val" | grep -qE '^-?[0-9]+(\.[0-9]+)?$'; then
        echo "state.sh write-num: '$val' is not numeric" >&2
        exit 2
      fi
      _write_field "$key" "$val" "number"
    fi
    exit $?
    ;;

  read)
    key="${2:-}"
    [ -z "$key" ] && { echo "state.sh read: missing key" >&2; exit 2; }
    _read_field "$key" "$STATE_FILE"
    exit 0
    ;;

  *)
    echo "Usage: state.sh {acquire [intent] | release | inspect | write <key> <value> | write-num <key> <value> | read <key>}" >&2
    exit 2
    ;;
esac
