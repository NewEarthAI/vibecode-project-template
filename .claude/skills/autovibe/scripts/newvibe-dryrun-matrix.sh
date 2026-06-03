#!/bin/bash
# .claude/skills/autovibe/scripts/newvibe-dryrun-matrix.sh
#
# NewVibe autofire — end-to-end integration matrix. Runs the REAL wired hooks
# (newvibe-autofire-stop.sh + newvibe-precompact-handoff.sh) against synthetic
# state in a throwaway sandbox. No real n8n dispatch can occur: no arm flag is
# created, so every gated path stops at the "would-dispatch" dry-run outcome.
#
# Repo-relative + self-contained (2026-05-17, Phase 2 — made permanent):
#   - the repo root is derived from THIS script's own location, and
#   - the continuation fixture is generated inside the sandbox.
# It therefore runs unchanged in any repo NewVibe is installed on — Agency-Main,
# the claude-code-project-template, or a spoke repo. The integration guide tells
# an adopting repo to run this matrix to confirm its NewVibe install is wired.
#
# Usage:  newvibe-dryrun-matrix.sh        -> run all scenarios; exit 0 (all pass) / 1
#
# Composes with the three unit --self-test harnesses (newvibe-chain-guard.sh,
# newvibe-dispatch-lib.sh, verify-continuation.sh): those test the units in
# isolation; this tests the two hooks end-to-end through the dispatch library.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# scripts/ -> autovibe/ -> skills/ -> .claude/ -> repo root
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
STOP_HOOK="$REPO_ROOT/.claude/hooks/newvibe-autofire-stop.sh"
PRECOMPACT_HOOK="$REPO_ROOT/.claude/hooks/newvibe-precompact-handoff.sh"

for h in "$STOP_HOOK" "$PRECOMPACT_HOOK"; do
  [ -f "$h" ] || { echo "FAIL: required hook missing: $h" >&2; exit 1; }
done

FIX_BASE="AUTOVIBE-2026-05-17-1200-newvibe-dryrun-fixture-MASTER.md"

pass=0; fail=0
check() {  # label expect-substr actual
  if printf '%s' "$3" | grep -qF "$2"; then
    echo "  PASS  $1"; pass=$((pass+1))
  else
    echo "  FAIL  $1 — wanted '$2'"
    echo "        got: $(printf '%s' "$3" | tr '\n' '~' | head -c 320)"
    fail=$((fail+1))
  fi
}
check_empty() {  # label actual
  if [ -z "$(printf '%s' "$2" | tr -d '[:space:]')" ]; then
    echo "  PASS  $1"; pass=$((pass+1))
  else
    echo "  FAIL  $1 — wanted empty output"
    echo "        got: $2"
    fail=$((fail+1))
  fi
}

NOW=$(date -u +%s)
iso() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d @"$1" +%Y-%m-%dT%H:%M:%SZ; }

# write_fixture <dest> — a synthetic continuation the verifier PASSes:
#   12 numbered sections, a "## 8. Current Branch" section (branch = main),
#   well over 500 bytes, no destructive keywords, canonical AUTOVIBE-*-MASTER.md
#   filename. Generated fresh so the matrix needs no real continuations/ file.
write_fixture() {
  local dest="$1" i
  {
    printf '# NewVibe dry-run fixture continuation\n\n'
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
      if [ "$i" = "8" ]; then
        printf '## 8. Current Branch\n\nmain\n\nFiller paragraph one. Filler paragraph two.\n\n'
      else
        printf '## %s. Section %s\n\nFiller content paragraph one. Filler content paragraph two. Filler content paragraph three.\n\n' "$i" "$i"
      fi
    done
  } > "$dest"
}

SB=""
mk_sandbox() {
  SB=$(mktemp -d)
  mkdir -p "$SB/.claude/skills/autovibe" "$SB/continuations"
  write_fixture "$SB/continuations/$FIX_BASE"
}
ship_state() {  # exit_code completed_at mode
  jq -nc --argjson ec "$1" --arg ca "$2" --arg m "$3" \
    '{pr_number:1,commit_sha:"abc",exit_code:$ec,completed_at:$ca,mode:$m,admin_merged:false}' \
    > "$SB/.claude/ship-state.json"
}

# A sandbox /tmp path matches no REPO_MAP pattern — force the slug.
export NEWVIBE_PROJECT_SLUG=example-app
# Pin LC_ALL=C — this matrix drives the REAL wired hooks, which run in
# non-interactive C-locale shells. Reproduce that, not an ambient UTF-8 locale.
export LC_ALL=C

echo "NewVibe — dry-run integration matrix"
echo "============================================="

# A — no ship-state.json -> Stop hook is a silent no-op
mk_sandbox
OUT=$(NEWVIBE_ROOT_OVERRIDE="$SB" bash "$STOP_HOOK" 2>&1); RC=$?
check_empty "A  no ship-state -> Stop hook silent no-op" "$OUT"
if [ "$RC" -eq 0 ]; then echo "  PASS  A  Stop hook exit 0"; pass=$((pass+1))
else echo "  FAIL  A  Stop hook exit $RC"; fail=$((fail+1)); fi
rm -rf "$SB"

# B — clean ship + fresh continuation -> all gates pass -> would-dispatch (not armed)
mk_sandbox
ship_state 0 "$(iso $((NOW-300)))" pr
touch "$SB/continuations/$FIX_BASE"
OUT=$(NEWVIBE_ROOT_OVERRIDE="$SB" bash "$STOP_HOOK" 2>&1)
check "B  clean ship -> would-dispatch"            "would dispatch"  "$OUT"
check "B    heartbeat shows depth=1"               "depth=1"         "$OUT"
check "B    heartbeat shows branch=main"           "branch=main"     "$OUT"
check "B    phase47-log has would-dispatch entry"  "would-dispatch"  "$(cat "$SB/.claude/phase47-log.jsonl" 2>/dev/null)"
# F — CA-1 regression: a 'would-dispatch' dry-run is NOT a real dispatch, so a
#     second run is NOT deduped — it re-evaluates and produces another
#     would-dispatch. (Pre-CA-1 this was silently swallowed — council 2026-05-18.)
OUT2=$(NEWVIBE_ROOT_OVERRIDE="$SB" bash "$STOP_HOOK" 2>&1)
check "F  re-run after would-dispatch -> NOT deduped, re-evaluates" "would dispatch" "$OUT2"
rm -rf "$SB"

# C — a depth-5 chain already in the log -> runaway cap REFUSES the next hop
mk_sandbox
ship_state 0 "$(iso $((NOW-300)))" pr
touch "$SB/continuations/$FIX_BASE"
NOWISO=$(iso "$NOW")
for d in 1 2 3 4 5; do
  jq -nc --arg ts "$NOWISO" --argjson d "$d" \
    '{ts:$ts,slug:"example-app",status:"autofire-dispatched",chain_depth:$d}'
done > "$SB/.claude/phase47-log.jsonl"
OUT=$(NEWVIBE_ROOT_OVERRIDE="$SB" bash "$STOP_HOOK" 2>&1)
check "C  depth-5 chain -> runaway REFUSE" "runaway cap" "$OUT"
rm -rf "$SB"

# D — kill-switch set -> skip
mk_sandbox
ship_state 0 "$(iso $((NOW-300)))" pr
touch "$SB/continuations/$FIX_BASE"
OUT=$(NEWVIBE_ROOT_OVERRIDE="$SB" AUTOVIBE_AUTOFIRE=0 bash "$STOP_HOOK" 2>&1)
check "D  kill-switch active -> skip" "kill-switch" "$OUT"
rm -rf "$SB"

# E — PreCompact hook -> would-dispatch, trigger recorded as precompact
mk_sandbox
touch "$SB/continuations/$FIX_BASE"
OUT=$(NEWVIBE_ROOT_OVERRIDE="$SB" CLAUDE_PROJECT_DIR="$SB" bash "$PRECOMPACT_HOOK" 2>&1)
check "E  PreCompact -> would-dispatch"     "would dispatch"          "$OUT"
check "E    phase47-log trigger=precompact" '"trigger":"precompact"'  "$(cat "$SB/.claude/phase47-log.jsonl" 2>/dev/null)"
rm -rf "$SB"

echo "============================================="
total=$(( pass + fail ))
if [ "$fail" -eq 0 ]; then
  echo "newvibe-dryrun-matrix: ALL PASS ($pass/$total)"
  exit 0
fi
echo "newvibe-dryrun-matrix: $fail FAILED ($pass/$total)"
exit 1
