#!/usr/bin/env bash
# ci-watch.sh — wrap `gh pr checks --watch` with hard timeout + distinct exit
# code for "status unknown" (council 2026-04-19 FLAG 3).
#
# Usage: ci-watch.sh [<pr_number_or_branch>] [--timeout <minutes>]
#
# Exit codes:
#   0 — all checks SUCCESS
#   1 — one or more checks FAILURE
#   9 — timeout reached; CI status UNKNOWN (never map to pass or fail)
#   2 — gh unavailable or not authenticated
#
# When exit 9: caller (/ship pr) should halt with "CI status unknown after Ns;
# inspect with `gh pr checks` and re-run /ship pr." Never proceed to merge.

set -uo pipefail

# Parse args: collect positional (first one = target), consume flags.
# NOTE: previous version set `target="${1:-}"` unconditionally, so
# `ci-watch.sh --timeout 10` (no PR given) would pass "--timeout" to `gh pr checks`.
target=""
timeout_min=15
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) timeout_min="$2"; shift 2 ;;
    -*) shift ;;
    *)
      if [ -z "$target" ]; then target="$1"; fi
      shift
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "ci-watch: gh CLI not found" >&2
  exit 2
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "ci-watch: gh not authenticated; run: gh auth login" >&2
  exit 2
fi

# Resolve timeout binary (macOS lacks `timeout` by default)
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout $((timeout_min * 60))"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout $((timeout_min * 60))"
else
  # No timeout available — use manual fallback with background + kill
  TIMEOUT_CMD=""
fi

# Invocation: `gh pr checks <target> --watch` polls until all checks complete.
# --fail-fast exits nonzero on first failure (fast feedback).
if [ -n "$target" ]; then
  cmd=(gh pr checks "$target" --watch --fail-fast)
else
  cmd=(gh pr checks --watch --fail-fast)
fi

if [ -n "$TIMEOUT_CMD" ]; then
  $TIMEOUT_CMD "${cmd[@]}" 2>&1
  rc=$?
  # GNU timeout exits 124 on timeout, 137 on SIGKILL
  case $rc in
    0) exit 0 ;;
    124|137) echo "ci-watch: timeout ${timeout_min}min reached — CI status UNKNOWN" >&2; exit 9 ;;
    *) exit 1 ;;
  esac
else
  # Manual timeout: run in background, kill if not done in N seconds
  ( "${cmd[@]}" ) &
  pid=$!
  elapsed=0
  interval=5
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$interval"
    elapsed=$((elapsed + interval))
    if [ "$elapsed" -ge "$((timeout_min * 60))" ]; then
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      kill -KILL "$pid" 2>/dev/null
      echo "ci-watch: timeout ${timeout_min}min reached — CI status UNKNOWN" >&2
      exit 9
    fi
  done
  wait "$pid"
  exit $?
fi
