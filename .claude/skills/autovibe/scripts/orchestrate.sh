#!/usr/bin/env bash
# autovibe/orchestrate.sh — top-of-stack orchestrator
# Composes: prime-lite → preflight → triage → forge?/plan?/execute/code-council → ship → post-push
# (Strategy council + /amend-plan retired from autofire loop 2026-05-23 — rabbit-hole detours.
#  /code-council at step 7 stays — that's the DIFF reviewer for shipped code.)
#
# Usage:
#   orchestrate.sh "<intent>"                   → run flow
#   AUTOVIBE_DRYRUN=1 orchestrate.sh "<intent>" → print every command, execute none, exit 0
#   AUTOVIBE_FORMAT=json orchestrate.sh "..."   → structured stdout (one JSON line per phase)
#
# Exit codes (stable contract — see references/invocation-contract.md):
#   0  success — shipped + post-push doc done
#   1  preflight failed (path, disk, locks)
#   2  triage halted (no intent / unknown error)
#   3  composed-step failure (execute/code-council)
#   4  /ship returned non-zero (passes through ship's exit code class)
#   5  lock collision — another autovibe in progress
#   6  unhealthy path (path-check rejection)
#   7  disk full
#   8  gh auth missing
#   9  hotfix-refusal (Autovibe never auto-invokes /ship hotfix)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTENT="${1:-}"
DRYRUN="${AUTOVIBE_DRYRUN:-0}"
FORMAT="${AUTOVIBE_FORMAT:-prose}"

if [ -z "$INTENT" ]; then
  echo "orchestrate.sh: usage: orchestrate.sh \"<intent>\"" >&2
  exit 2
fi

_log() {
  # Structured log: prose to stderr, JSON to stdout when format=json
  local phase="$1" status="$2" detail="$3"
  if [ "$FORMAT" = "json" ]; then
    printf '{"phase":"%s","status":"%s","detail":"%s","ts":"%s"}\n' \
      "$phase" "$status" "$(echo "$detail" | sed 's/"/\\"/g')" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  else
    echo "[autovibe:$phase] $status — $detail" >&2
  fi
}

_run() {
  # $1 = label, rest = command
  local label="$1"; shift
  if [ "$DRYRUN" = "1" ]; then
    echo "[DRYRUN] $label: $*" >&2
    return 0
  fi
  _log "$label" "running" "$*"
  "$@"
}

# Trap: release lock ONLY on signal-based termination (INT/TERM).
# We deliberately do NOT trap EXIT — code-council 2026-04-19 caught that releasing
# the lock on `exit 0` broke the multi-turn handoff. The lock must persist across
# the conversation's composition phase (execute/code-council/ship) and is released
# explicitly by post-ship.sh (or via TTL takeover after 30 min).
cleanup_signal() {
  echo "[autovibe] caught termination signal — releasing lock" >&2
  bash "$SCRIPT_DIR/state.sh" release >/dev/null 2>&1 || true
}
trap cleanup_signal INT TERM

# ─── Phase 1: Preflight ───────────────────────────────────────

_log preflight start "checking path/disk/locks/auth"
if [ "$DRYRUN" != "1" ]; then
  if ! bash "$SCRIPT_DIR/preflight.sh"; then
    pf_exit=$?
    _log preflight fail "exit $pf_exit"
    exit $pf_exit
  fi
fi
_log preflight pass ""

# ─── Phase 2: Acquire state lock ─────────────────────────────

if [ "$DRYRUN" != "1" ]; then
  if ! bash "$SCRIPT_DIR/state.sh" acquire "$INTENT"; then
    sa_exit=$?
    _log lock fail "exit $sa_exit — see state file"
    exit $sa_exit
  fi
fi
_log lock acquired ""

# ─── Phase 3: prime-lite context briefing ────────────────────

PRIME_OUT="${TMPDIR:-/tmp}/autovibe-prime-$$.md"
PRIME_SCRIPT="$SCRIPT_DIR/../../prime-lite/scripts/brief.sh"
if [ -x "$PRIME_SCRIPT" ]; then
  _run prime bash "$PRIME_SCRIPT" > "$PRIME_OUT" 2>/dev/null || true
  _log prime done "briefing at $PRIME_OUT"
else
  _log prime skipped "prime-lite not installed"
fi

# ─── Phase 4: Forge gate (D4) ────────────────────────────────

word_count=$(echo "$INTENT" | wc -w | tr -d ' ')
needs_forge=0
# Forge only when intent is BOTH short AND structurally vague — skips clear short intents.
# Tighter than continuation §4.D4 "OR" heuristic to avoid forge-loop on every invocation.
has_verb_object=$(echo "$INTENT" | grep -qE '\b(add|fix|build|create|update|deploy|implement|wire|refactor|remove|enable|disable|tweak|change|rename|migrate)\b.*\b(in|to|from|for|on|at)\b' && echo yes || echo no)
if [ "$word_count" -lt 4 ]; then
  needs_forge=1
  forge_reason="intent <4 words (severely brief)"
elif [ "$word_count" -lt 8 ] && [ "$has_verb_object" = "no" ]; then
  needs_forge=1
  forge_reason="intent short and lacks verb/object pair"
fi
if [ "$needs_forge" = "1" ]; then
  _log forge needed "$forge_reason"
  if [ "$DRYRUN" = "1" ]; then
    echo "[DRYRUN] would invoke /prompt-forge skill on intent" >&2
  else
    # Forge invocation is delegated to the calling Claude session via Skill tool;
    # this script can't invoke skills directly. Mark the state so the caller knows.
    bash "$SCRIPT_DIR/state.sh" write current_step "forge_needed"
  fi
else
  _log forge skipped "intent is specific enough"
fi

# ─── Phase 5: Triage (D2) ────────────────────────────────────

TRIAGE_OUT="$(bash "$SCRIPT_DIR/triage.sh" "$INTENT" 2>/tmp/autovibe-triage-$$.err)"
TRIAGE_REASON="$(cat /tmp/autovibe-triage-$$.err 2>/dev/null)"
rm -f /tmp/autovibe-triage-$$.err
_log triage "$TRIAGE_OUT" "$TRIAGE_REASON"

if [ "$DRYRUN" != "1" ]; then
  bash "$SCRIPT_DIR/state.sh" write current_step "triage_$TRIAGE_OUT"
fi

# ─── Phase 6: Branch on triage outcome ───────────────────────

case "$TRIAGE_OUT" in
  direct)
    MODE_DOC="$SCRIPT_DIR/../modes/direct.md"
    SHIP_MODE="quick"
    ;;
  plan|ambiguous)
    # Ambiguous escalates to plan branch for safety (D2: judgment fails closed)
    MODE_DOC="$SCRIPT_DIR/../modes/planned.md"
    SHIP_MODE="pr"
    ;;
  *)
    _log triage fail "unknown triage output: $TRIAGE_OUT"
    exit 2
    ;;
esac

_log mode dispatch "branch=$TRIAGE_OUT, ship-mode=$SHIP_MODE, doc=$MODE_DOC"

# ─── Phase 7: Compose downstream skills ──────────────────────
#
# This script CANNOT directly invoke /execute, /code-council, /ship — those
# are Claude-CLI commands run via the Skill tool by the calling session.
# orchestrate.sh writes the next-step directive into state and exits with a
# sentinel; the calling Claude session reads state and invokes the next skill.
# (Strategy council + /amend-plan were retired from the autofire loop
# 2026-05-23 — operator-only `/council` survives as a manual skill outside
# autovibe.)
#
# Why not invoke them directly? Skills run in the conversation context;
# they can read prior conversation, plan files, and council session
# files. A subprocess shell can't reproduce that context. The shell's
# job is preflight + triage + state management; the conversation drives
# the composition.
#
# In DRYRUN mode, we print the planned composition for verification.

if [ "$DRYRUN" = "1" ]; then
  echo "[DRYRUN] would compose:" >&2
  if [ "$TRIAGE_OUT" = "direct" ]; then
    cat <<EOF >&2
  1. /execute (no plan)
  2. /ship $SHIP_MODE --format=json --caller=autovibe
  3. post-push doc step
EOF
  else
    cat <<EOF >&2
  1. (if forge needed) /prompt-forge "$INTENT"
  2. framing-audit (goal-audit checkpoint — Skill reduce-to-first-principles / check-commensurability / map-feedback-loops)
  3. EnterPlanMode
  4. (if grill triggers) Skill pocock-grill-with-docs
  5. Skill superpowers:writing-plans
  6. ExitPlanMode (auto-accept; Foundation-First operator self-check)
  7. /execute
  8. /code-council (diff review)
  9. /ship $SHIP_MODE --format=json --caller=autovibe + post-push doc step
EOF
  fi
  exit 0
fi

# Real run: write the composition directive, exit with sentinel.
bash "$SCRIPT_DIR/state.sh" write current_step "compose_${TRIAGE_OUT}_pending"
_log handoff ready "calling session must compose: see modes/$([ "$TRIAGE_OUT" = "direct" ] && echo direct.md || echo planned.md)"

# Exit 0 here means "preflight + triage clean, ready for compose phase".
# The orchestrator's full lifecycle runs across multiple Claude turns:
# this shell call is one turn (gates), then the session invokes skills,
# then writes back to state, then optionally calls /ship which has its
# own state file.
exit 0
