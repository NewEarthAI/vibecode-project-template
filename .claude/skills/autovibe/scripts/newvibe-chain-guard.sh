#!/bin/bash
# .claude/skills/autovibe/scripts/newvibe-chain-guard.sh
#
# NewVibe runaway-loop cap. Computes the chain depth the NEXT autofire dispatch
# would be, and decides allow / refuse. Without this, a self-spawning autofire
# chain that bugs out would spawn fresh sessions until the token budget is gone
# overnight. This is the single most safety-critical NewVibe script — it is
# built and self-tested in isolation before any dispatch wiring exists.
#
# Mechanism (plan D1): .claude/phase47-log.jsonl lives in-repo; every autofired
# session runs in that same repo, so the log IS the chain ledger. Depth = count
# of in-window real-spawn dispatch entries for this slug, + 1. No n8n workflow
# change and no dispatch-payload change are needed — the log file alone carries
# the chain. A runaway (rapid self-spawns) is exactly this signature.
#
# Usage:
#   newvibe-chain-guard.sh <project_slug> [log_path]
#       -> stdout: "depth=N"   exit 0 = allow, exit 1 = REFUSE (cap exceeded)
#   newvibe-chain-guard.sh --self-test
#       -> run fixtures; "ALL PASS (n/n)" or first FAIL
#
# A "real-spawn" status counts as a chain hop: autofire-dispatched,
# autofire-ssh-failed, autofire-status-unknown — in all three a remote session
# was attempted. Skips and would-dispatch (arm-off dry-run) do NOT count, since
# no new session spawned.
#
# Conservative-fail: if the counted total and the last entry's recorded
# chain_depth disagree, the larger wins (refuse sooner, never runaway). If the
# log cannot be parsed at all, the guard refuses (returns a depth above the cap).

set -uo pipefail

MAX_CHAIN_DEPTH=5
CHAIN_WINDOW_MIN=360   # 6h — autofire hops land minutes apart; a genuine fresh
                       # manual run hours later correctly starts a new chain.
SPAWN_STATUS_RE='^autofire-(dispatched|ssh-failed|status-unknown)$'

# --- compute_next_depth: echoes the depth the next dispatch would be ---------
# Args: $1 = slug, $2 = log path. Always echoes a single integer.
# On any jq/parse failure -> echoes a value above the cap (conservative refuse).
compute_next_depth() {
  local slug="$1" log="$2"
  # Absent or empty log => fresh chain.
  if [ ! -s "$log" ]; then echo 1; return; fi

  local now_epoch window_start
  now_epoch=$(date -u +%s)
  window_start=$(( now_epoch - CHAIN_WINDOW_MIN * 60 ))

  # ONE jq pass: filter to this slug's in-window real-spawn entries, then return
  # both the count and the most-recent recorded chain_depth.
  local pair count prior
  pair=$(jq -rs \
    --argjson ws "$window_start" \
    --arg slug "$slug" \
    --arg re "$SPAWN_STATUS_RE" '
    [ .[]
      | select((.slug // "") == $slug)
      | select(((.status // "")) | test($re))
      | select(((.ts // "") | fromdateiso8601? // 0) >= $ws)
    ] as $hits
    | "\($hits | length) \(($hits | sort_by(.ts) | last | (.chain_depth // 0)) // 0)"
  ' "$log" 2>/dev/null)
  local jq_rc=$?

  if [ "$jq_rc" -ne 0 ] || [ -z "$pair" ]; then
    # Log unreadable / corrupt — fail conservative: force a refuse.
    echo $(( MAX_CHAIN_DEPTH + 2 )); return
  fi

  count=$(printf '%s' "$pair" | awk '{print $1}' | tr -dc '0-9'); count=${count:-0}
  prior=$(printf '%s' "$pair" | awk '{print $2}' | tr -dc '0-9'); prior=${prior:-0}

  # Conservative: the larger of (count of prior spawns, last recorded depth) + 1.
  local base=$count
  [ "$prior" -gt "$base" ] && base=$prior
  echo $(( base + 1 ))
}

# --- main -------------------------------------------------------------------
run_guard() {
  local slug="${1:-}" log="${2:-}"
  if [ -z "$slug" ]; then
    echo "[chain-guard] usage: newvibe-chain-guard.sh <project_slug> [log_path]" >&2
    return 2
  fi
  if [ -z "$log" ]; then
    local script_dir project_root
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    project_root="$(cd "$script_dir/../../../.." && pwd)"
    log="$project_root/.claude/phase47-log.jsonl"
  fi

  local depth
  depth=$(compute_next_depth "$slug" "$log")
  echo "depth=$depth"

  if [ "$depth" -gt "$MAX_CHAIN_DEPTH" ]; then
    echo "[chain-guard] REFUSE — next autofire depth $depth exceeds MAX_CHAIN_DEPTH $MAX_CHAIN_DEPTH (slug=$slug window=${CHAIN_WINDOW_MIN}min)" >&2
    return 1
  fi
  return 0
}

# --- self-test --------------------------------------------------------------
self_test() {
  # Pin LC_ALL=C — autofire hooks run in non-interactive C-locale shells; the
  # self-test must reproduce that environment, not an ambient UTF-8 one.
  export LC_ALL=C
  local tmp pass=0 fail=0
  tmp=$(mktemp -d)

  local NOW
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local OLD="2020-01-01T00:00:00Z"

  # _entry slug status depth ts  -> one JSONL line
  _entry() {
    jq -nc --arg s "$1" --arg st "$2" --argjson d "$3" --arg ts "$4" \
      '{ts:$ts, slug:$s, status:$st, chain_depth:$d}'
  }

  # _check label expected_rc expected_depth logfile slug
  _check() {
    local label="$1" exp_rc="$2" exp_depth="$3" lf="$4" slug="$5"
    local out rc got
    out=$(run_guard "$slug" "$lf" 2>/dev/null); rc=$?
    got=${out#depth=}
    if [ "$rc" -eq "$exp_rc" ] && [ "$got" = "$exp_depth" ]; then
      echo "  PASS  $label (depth=$got rc=$rc)"; pass=$((pass+1))
    else
      echo "  FAIL  $label — expected depth=$exp_depth rc=$exp_rc, got depth=$got rc=$rc"
      fail=$((fail+1))
    fi
  }

  echo "newvibe-chain-guard self-test"
  echo "==============================="

  # T1: absent log -> fresh chain, allow
  _check "T1 absent log -> depth 1 allow" 0 1 "$tmp/does-not-exist.jsonl" testslug

  # T2: empty log -> fresh chain, allow
  : > "$tmp/empty.jsonl"
  _check "T2 empty log -> depth 1 allow" 0 1 "$tmp/empty.jsonl" testslug

  # T3: 4 in-window real-spawn entries -> next depth 5, allow (5 <= MAX)
  { _entry testslug autofire-dispatched 1 "$NOW"
    _entry testslug autofire-dispatched 2 "$NOW"
    _entry testslug autofire-dispatched 3 "$NOW"
    _entry testslug autofire-dispatched 4 "$NOW"; } > "$tmp/depth4.jsonl"
  _check "T3 four in-window -> depth 5 allow" 0 5 "$tmp/depth4.jsonl" testslug

  # T4: 5 in-window real-spawn entries -> next depth 6, REFUSE
  { _entry testslug autofire-dispatched 1 "$NOW"
    _entry testslug autofire-dispatched 2 "$NOW"
    _entry testslug autofire-dispatched 3 "$NOW"
    _entry testslug autofire-dispatched 4 "$NOW"
    _entry testslug autofire-dispatched 5 "$NOW"; } > "$tmp/depth5.jsonl"
  _check "T4 five in-window -> depth 6 REFUSE" 1 6 "$tmp/depth5.jsonl" testslug

  # T5: 5 entries but ALL out-of-window -> chain expired, depth 1, allow
  { _entry testslug autofire-dispatched 1 "$OLD"
    _entry testslug autofire-dispatched 2 "$OLD"
    _entry testslug autofire-dispatched 3 "$OLD"
    _entry testslug autofire-dispatched 4 "$OLD"
    _entry testslug autofire-dispatched 5 "$OLD"; } > "$tmp/old.jsonl"
  _check "T5 five out-of-window -> depth 1 allow" 0 1 "$tmp/old.jsonl" testslug

  # T6: 5 in-window entries for a DIFFERENT slug -> our slug fresh, allow
  { _entry otherslug autofire-dispatched 1 "$NOW"
    _entry otherslug autofire-dispatched 2 "$NOW"
    _entry otherslug autofire-dispatched 3 "$NOW"
    _entry otherslug autofire-dispatched 4 "$NOW"
    _entry otherslug autofire-dispatched 5 "$NOW"; } > "$tmp/otherslug.jsonl"
  _check "T6 five for other slug -> depth 1 allow" 0 1 "$tmp/otherslug.jsonl" testslug

  # T7: 5 in-window entries with chain_depth recorded as 0 -> count (5) wins
  #     over the bad recorded depth -> next depth 6, REFUSE (conservative max)
  { _entry testslug autofire-dispatched 0 "$NOW"
    _entry testslug autofire-dispatched 0 "$NOW"
    _entry testslug autofire-dispatched 0 "$NOW"
    _entry testslug autofire-dispatched 0 "$NOW"
    _entry testslug autofire-dispatched 0 "$NOW"; } > "$tmp/baddepth.jsonl"
  _check "T7 count beats bad recorded depth -> depth 6 REFUSE" 1 6 "$tmp/baddepth.jsonl" testslug

  # T8: 5 in-window entries with NON-spawn statuses -> no chain hops, depth 1
  { _entry testslug would-dispatch 1 "$NOW"
    _entry testslug autofire-skipped 1 "$NOW"
    _entry testslug would-dispatch 1 "$NOW"
    _entry testslug autofire-skipped 1 "$NOW"
    _entry testslug would-dispatch 1 "$NOW"; } > "$tmp/nonspawn.jsonl"
  _check "T8 non-spawn statuses -> depth 1 allow" 0 1 "$tmp/nonspawn.jsonl" testslug

  # T8b: 2 in-window entries but the last records chain_depth=6 -> the recorded
  #      prior depth (6) beats the count (2); conservative max -> next depth 7 -> REFUSE
  { _entry testslug autofire-dispatched 5 "$NOW"
    _entry testslug autofire-dispatched 6 "$NOW"; } > "$tmp/priorwins.jsonl"
  _check "T8b recorded prior depth beats count -> depth 7 REFUSE" 1 7 "$tmp/priorwins.jsonl" testslug

  # T9: corrupt log line -> conservative REFUSE
  printf '{not valid json\n' > "$tmp/corrupt.jsonl"
  local cout crc cdepth
  cout=$(run_guard testslug "$tmp/corrupt.jsonl" 2>/dev/null); crc=$?
  cdepth=${cout#depth=}
  if [ "$crc" -eq 1 ] && [ "$cdepth" -gt "$MAX_CHAIN_DEPTH" ]; then
    echo "  PASS  T9 corrupt log -> REFUSE (depth=$cdepth rc=$crc)"; pass=$((pass+1))
  else
    echo "  FAIL  T9 corrupt log — expected REFUSE depth>$MAX_CHAIN_DEPTH, got depth=$cdepth rc=$crc"
    fail=$((fail+1))
  fi

  rm -rf "$tmp"
  local total=$(( pass + fail ))
  echo "==============================="
  if [ "$fail" -eq 0 ]; then
    echo "newvibe-chain-guard self-test: ALL PASS ($pass/$total)"
    return 0
  fi
  echo "newvibe-chain-guard self-test: $fail FAILED ($pass/$total)"
  return 1
}

# --- entry point ------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit $?
fi

run_guard "${1:-}" "${2:-}"
exit $?
