#!/usr/bin/env bash
# lock.sh — atomic `.claude/ship-state.lock/` directory as the lock primitive.
# JSON file `.claude/ship-state.json` carries metadata; the DIRECTORY IS the lock.
#
# Why mkdir: council 2026-04-19 flagged that JSON-write is not atomic on APFS.
# `mkdir` is atomic on every POSIX fs (creates-or-fails, no interleave).
#
# Usage:
#   lock.sh acquire <commit_sha> [pr_number]  → exit 0 acquired, exit 5 held, exit 6 corrupt
#   lock.sh release                           → exit 0 (idempotent)
#   lock.sh inspect                           → prints current holder state or "none"
#
# TTL: 10 minutes on started_at (lower bound) AND 60 minutes future-tolerance
# (upper bound). If started_at > now + 60min, treat as corrupt (clock skew).

set -uo pipefail

LOCK_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/ship-state.lock"
STATE_FILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/ship-state.json"
TTL_MIN=10
FUTURE_TOLERANCE_MIN=60

ts_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
ts_epoch() { date -u +%s; }

# Portable iso8601 → epoch (macOS + GNU)
iso_to_epoch() {
  local iso="$1"
  if date -u -d "$iso" +%s 2>/dev/null; then return; fi
  if date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null; then return; fi
  echo 0
}

action="${1:-}"

case "$action" in
  acquire)
    commit_sha="${2:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
    pr_number="${3:-null}"

    if mkdir "$LOCK_DIR" 2>/dev/null; then
      uuid="${CLAUDE_SESSION_ID:-$(uuidgen 2>/dev/null || echo $$)}"
      cat > "$STATE_FILE" <<EOF
{
  "pr_number": $pr_number,
  "session_uuid": "$uuid",
  "caller": "${SHIP_CALLER:-human}",
  "started_at": "$(ts_now)",
  "current_step": "prechecks",
  "commit_sha": "$commit_sha",
  "tier_results": {"T1": null, "T2": null, "T3": null},
  "completed_at": null,
  "exit_code": null
}
EOF
      exit 0
    fi

    # Lock dir exists — inspect held state
    if [ ! -f "$STATE_FILE" ]; then
      echo "lock: lock dir exists but state file missing — corrupt; remove $LOCK_DIR to recover" >&2
      exit 6
    fi

    started=$(grep -o '"started_at":[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')
    held_sha=$(grep -o '"commit_sha":[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')
    held_step=$(grep -o '"current_step":[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')
    held_uuid=$(grep -o '"session_uuid":[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')

    if [ -z "$started" ] || [ -z "$held_sha" ]; then
      echo "lock: state file missing required fields — corrupt; inspect $STATE_FILE before removing" >&2
      exit 6
    fi

    now_s=$(ts_epoch)
    started_s=$(iso_to_epoch "$started")
    if [ "$started_s" = "0" ]; then
      echo "lock: cannot parse started_at ($started) — corrupt; inspect $STATE_FILE" >&2
      exit 6
    fi

    # Upper bound: future-dated lock
    if [ "$started_s" -gt "$((now_s + FUTURE_TOLERANCE_MIN * 60))" ]; then
      echo "lock: started_at ($started) is more than ${FUTURE_TOLERANCE_MIN}min in the future — likely clock skew" >&2
      echo "  If this machine's clock was wrong, run: rm -rf $LOCK_DIR $STATE_FILE" >&2
      exit 6
    fi

    # TTL expired → take over
    age_min=$(( (now_s - started_s) / 60 ))
    if [ "$age_min" -ge "$TTL_MIN" ]; then
      rm -rf "$LOCK_DIR" "$STATE_FILE" 2>/dev/null || true
      # Retry once
      exec "$0" acquire "$commit_sha" "$pr_number"
    fi

    # Same commit/PR → collision
    if [ "$held_sha" = "$commit_sha" ]; then
      echo "lock: another /ship session (uuid: ${held_uuid:-unknown}, step: ${held_step:-unknown}) is active on commit $commit_sha (started ${started}, age ${age_min}min)" >&2
      echo "  Wait or: rm -rf $LOCK_DIR $STATE_FILE  (only if you're sure the other session crashed)" >&2
      exit 5
    fi

    # Different commit → proceed (lock is sha-scoped for Phase A)
    # Create a sha-suffixed lock dir to allow parallel ships on different commits
    alt_lock="$LOCK_DIR-${commit_sha:0:8}"
    if mkdir "$alt_lock" 2>/dev/null; then
      # Write a sidecar state file (not overwriting primary)
      alt_state="${STATE_FILE%.json}-${commit_sha:0:8}.json"
      uuid="${CLAUDE_SESSION_ID:-$(uuidgen 2>/dev/null || echo $$)}"
      cat > "$alt_state" <<EOF
{"pr_number": $pr_number, "session_uuid": "$uuid", "caller": "${SHIP_CALLER:-human}", "started_at": "$(ts_now)", "current_step": "prechecks", "commit_sha": "$commit_sha", "completed_at": null, "exit_code": null}
EOF
      exit 0
    fi

    echo "lock: sha-scoped lock $alt_lock also held" >&2
    exit 5
    ;;

  release)
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    # Leave STATE_FILE in place (carries completed_at for audit) but clear sha-suffixed
    # sidecars to avoid clutter
    find "${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude" -maxdepth 1 -name "ship-state-*.json" -mmin +15 -delete 2>/dev/null || true
    find "${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude" -maxdepth 1 -type d -name "ship-state.lock-*" -mmin +15 -exec rm -rf {} + 2>/dev/null || true
    exit 0
    ;;

  inspect)
    if [ ! -d "$LOCK_DIR" ] && [ ! -f "$STATE_FILE" ]; then
      echo "none"
      exit 0
    fi
    if [ -f "$STATE_FILE" ]; then
      cat "$STATE_FILE"
    else
      echo "lock dir exists but no state file"
    fi
    exit 0
    ;;

  *)
    echo "Usage: lock.sh {acquire <commit_sha> [pr_number] | release | inspect}" >&2
    exit 2
    ;;
esac
