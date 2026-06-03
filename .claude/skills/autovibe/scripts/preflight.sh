#!/usr/bin/env bash
# autovibe/preflight.sh — pre-execution gates for /autovibe
# Mirrors /ship/scripts/preflight.sh patterns. Lighter footprint (autovibe
# composes; it doesn't directly modify code, so tsc gate lives in /ship).
#
# Gates (in order):
#   1. path-check   — reject iCloud/OneDrive/Dropbox/tmp (reuse ship's path-check.sh)
#   2. disk free    — ≥10% on /System/Volumes/Data
#   3. stale locks  — .git/*.lock files >10min
#   4. gh auth      — `gh auth status` succeeds
#   5. fetch refs   — `git fetch origin main --prune` (non-blocking; network
#                     flakes should not halt autovibe — emit warning and continue)
#
# Exit: 0 clean; 6 unhealthy path; 7 disk; 8 auth; 1 generic blocker.
# Diagnostics on stderr; stdout reserved for structured output.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIP_PATH_CHECK="$(cd "$SCRIPT_DIR/../../ship/scripts" 2>/dev/null && pwd)/path-check.sh"

# --- 1. path-check (delegate to ship's hardened version) ---
if [ -x "$SHIP_PATH_CHECK" ]; then
  if ! bash "$SHIP_PATH_CHECK" "$PWD" >/tmp/autovibe-path.$$ 2>&1; then
    cat /tmp/autovibe-path.$$ >&2
    rm -f /tmp/autovibe-path.$$
    echo "preflight: path-check failed — autovibe requires healthy non-cloud cwd" >&2
    exit 6
  fi
  rm -f /tmp/autovibe-path.$$
else
  # Inline fallback if ship not installed (defensive)
  case "$PWD" in
    *Documents/GitHub*|*iCloud*|*OneDrive*|*Dropbox*|/tmp/*)
      echo "preflight: cwd is $PWD — cloud/temp paths corrupt git metadata. Use ~/code/ instead." >&2
      exit 6
      ;;
  esac
fi

# --- 2. disk free ---
data_vol="/System/Volumes/Data"
[ -d "$data_vol" ] || data_vol="/"
pct_used=$(df "$data_vol" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if [ -n "${pct_used:-}" ] && [ "$pct_used" -ge 90 ]; then
  echo "preflight: disk $pct_used% full on $data_vol — autovibe halts at 90% (APFS CoW corruption risk)" >&2
  exit 7
fi

# --- 3. stale git locks ---
if [ -d ".git" ]; then
  stale=$(find .git -maxdepth 2 -name "*.lock" -type f -mmin +10 2>/dev/null | head -3 | tr '\n' ' ')
  if [ -n "$stale" ]; then
    echo "preflight: stale git locks (>10min): $stale" >&2
    echo "  Remove with: rm -f $stale  (safe if no other git process is running)" >&2
    exit 1
  fi
fi

# --- 4. gh auth ---
if command -v gh >/dev/null 2>&1; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "preflight: gh auth status failed — run 'gh auth login' before invoking /autovibe" >&2
    exit 8
  fi
else
  echo "preflight: 'gh' CLI not found in PATH — required for /ship pr composition" >&2
  exit 8
fi

# --- 5. fetch origin refs (non-blocking) ---
# Single fetch keeps origin/main ref fresh so any in-session comparison is
# accurate. Intentionally NOT a pull/merge — that's /daily-plan's job at a
# different cadence. Network failures don't halt autovibe; many flows don't
# need fresh refs (typo fix, local work). Emit a single warning and continue.
if [ -d ".git" ]; then
  if ! git fetch origin main --prune --quiet 2>/dev/null; then
    echo "preflight: git fetch origin main failed (network or auth) — continuing with stale refs" >&2
  fi
fi

exit 0
