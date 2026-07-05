#!/usr/bin/env bash
# system-awareness-activation.sh — SessionStart + UserPromptSubmit hook
#
# PURPOSE
#   The activation layer of the System-Awareness Alignment Gate — the symmetric twin of
#   framing-audit-activation.sh. Where the framing-audit hook asks "is this the RIGHT question?",
#   this asks "does this plan fit the REAL system?".
#     - SessionStart  → injects the system-awareness mandate banner into EVERY session
#                       (unconditional; carries a heartbeat marker so a degraded hook is observable).
#     - UserPromptSubmit → on a PLAN-CLASS prompt, injects a CHEAP freshness snapshot (map-freshness
#                       verdict + ROADMAP NOW + a one-line DESTINATION presence note) + a directive to
#                       auto-run the DEEP read (/topology align). Silent on trivia / skip-listed commands.
#
#   The hook ANNOUNCES the mandate every session; it surfaces the cheap snapshot + triggers the deep read
#   only on plan-class work. The operator types NOTHING — Claude runs /topology align from the directive.
#
# DESIGN (council-amended, spec 17 v2 — Path B):
#   CHEAP TIER = FRESHNESS-ONLY. No cache. A timeout-bounded health-check --json | .verdict + a bounded
#   ROADMAP sed. The open-drift COUNT + DESTINATION detail + goals come from the DEEP read (/topology align),
#   which Claude auto-runs. SAFETY INVARIANTS (A6): timeout-bounded; NEVER runs reconcile/the deep read
#   inline (that would blow the budget); NEVER falls through to "" on a plan-class match (always an honest
#   degrade message); NEVER emits a false-green (the cheap tier reports freshness, never an alignment claim).
#
# COMPOSES WITH
#   - .claude/rules/system-awareness-mandate.md            (the doctrine)
#   - .claude/skills/system-awareness-gate/scripts/topology-align.sh  (the deep read the directive points at)
#   - .claude/skills/topology-health-check/scripts/health-check.sh    (the cheap freshness read)
#   - modelled on .claude/hooks/framing-audit-activation.sh (shape — separate hook per hook-efficiency.md §6)
#
# OUTPUT  JSON envelope on stdout: {"hookSpecificOutput":{"hookEventName":"<event>","additionalContext":"..."}}
#         Silent (no output) on a non-trigger UserPromptSubmit.
# EXIT    Always 0 in hook mode — advisory only, NEVER blocks. --self-test: 0 all pass, 1 any fail.
# KILL    HOOK_SYSTEM_AWARENESS_ACTIVATION=0 (or false/no/off/disabled) → hook no-ops.
# DEPS    jq (hard dep — also required by the topology reads). jq absent → graceful no-op + stderr note.
# BUDGET  cheap tier <1s typical (one bounded health-check parse + a bounded sed); SessionStart once/session.

set -uo pipefail

# ── kill-switch ───────────────────────────────────────────────────────────────
case "$(printf '%s' "${HOOK_SYSTEM_AWARENESS_ACTIVATION:-}" | tr 'A-Z' 'a-z')" in
  0|false|no|off|disabled) exit 0;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# hooks live at <repo>/.claude/hooks → repo root is two levels up (NOT one).
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HEALTH_SH="$REPO_ROOT/.claude/skills/topology-health-check/scripts/health-check.sh"
ALIGN_REF=".claude/skills/system-awareness-gate/scripts/topology-align.sh"

HEARTBEAT="[system-awareness-hook: active]"
BANNER="[system-awareness mandate] Before a load-bearing PLAN or BUILD, check the plan fits what the system
actually IS — its live map (topology health + open drift), its ROADMAP, its DESTINATION, its open goals.
The deep read is /topology align (Claude auto-runs it on plan-class work; you type nothing). Advisory, never
blocks. Only a FRESH map + IN_SYNC reconcile licenses \"aligned\"; absence / staleness / partiality / drift
are surfaced honestly, never laundered into a green light. NOT for trivia. Doctrine:
.claude/rules/system-awareness-mandate.md  (the symmetric twin of the framing-audit gate)."

MODE="run"
[ "${1:-}" = "--self-test" ] && MODE="selftest"

# ── jq required ─────────────────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  if [ "$MODE" = "selftest" ]; then echo "SKIP: jq not available — cannot run self-test"; exit 0; fi
  echo "system-awareness-activation: jq absent — hook degraded (mandate rule still loads; SessionStart announcement skipped)" >&2
  exit 0
fi

# ── envelope ──────────────────────────────────────────────────────────────────
emit() {  # $1=event $2=additionalContext
  jq -n --arg e "$1" --arg c "$2" '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
}

# ── skip-list (prefix match, whitespace-trimmed) ────────────────────────────────
is_skip_listed() {
  case "$(printf '%s' "$1" | sed -E 's/^[[:space:]]+//')" in
    /commit*|/push*|/ship*|/daily-plan*|/prime*|/setup*|/topology*|/system-check*|/system-awareness*) return 0;;
    /reduce-to-first-principles*|/check-commensurability*|/map-feedback-loops*|/audit-artefact-grounding*) return 0;;
    /diagnose-bottleneck*|/decide-under-uncertainty*|/council*) return 0;;
  esac
  return 1
}

# ── plan-class detection (expanded classes — council A2) ────────────────────────
# Bias toward firing: a false-negative MISSES the gate (Edge Case Finder S2); a false-positive only adds
# one advisory snapshot (cheap, non-blocking). grep -iE; one match is enough.
is_plan_class() {
  local p="$1"
  printf '%s' "$p" | grep -iqE '^[[:space:]]*/(plan|autovibe|prompt-forge|build-with-agent-team)\b' && return 0
  printf '%s' "$p" | grep -iqE '\b(plan mode|enter plan)\b' && return 0
  printf '%s' "$p" | grep -iqE '\b(spec|design|architect|re-?architect|restructure|rework|overhaul|revamp|rewrite|migrate)\b' && return 0
  printf '%s' "$p" | grep -iqE '\b(build|add|implement|wire[ -]?up)\b.{0,40}\b(feature|endpoint|table|component|dashboard|workflow|integration|page|service|api|schema|migration|hook|rule|skill|agent)\b' && return 0
  printf '%s' "$p" | grep -iqE '\b(move|switch)\b.{0,30}\b(to|from|into|over)\b' && return 0
  printf '%s' "$p" | grep -iqE "\\bshould we\\b.{0,40}\\b(build|add|change|migrate|restructure|rework|move|switch|implement)\\b" && return 0
  printf '%s' "$p" | grep -iqE "\\blet'?s\\b.{0,30}\\b(build|add|restructure|rework|migrate|rewrite|design|implement)\\b" && return 0
  return 1
}

# bound a command to N seconds — timeout/gtimeout (GNU) OR perl alarm (macOS ships perl, not coreutils).
# Without ANY of the three the command runs unbounded — but perl is on every macOS, so that path is rare.
_bounded() { local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'alarm shift; exec @ARGV' "$s" "$@"
  else "$@"; fi
}

# ── cheap freshness read (HARD timeout-bounded; honest-degrade; NEVER the deep read) ──
freshness_verdict() {
  local v=""
  if [ -f "$HEALTH_SH" ]; then
    v="$(_bounded 3 bash "$HEALTH_SH" --json 2>/dev/null | jq -r '.verdict // empty' 2>/dev/null)"
  fi
  [ -n "$v" ] || v="UNREADABLE"   # timeout / absent / parse-fail → honest UNREADABLE, never "" on a plan-class match
  printf '%s' "$v"
}

build_snapshot() {
  local v="" roadmap="" dest_note="" snap=""
  v="$(freshness_verdict)"
  # bounded, format-tolerant ROADMAP NOW slice (env override for tests/propagation):
  # tier 1 a "## NOW" lane → tier 2 NEXT-status rows → tier 3 "## System:" headings.
  local roadmap_file="${TOPOLOGY_ALIGN_ROADMAP:-$REPO_ROOT/ROADMAP.md}"
  if [ -f "$roadmap_file" ]; then
    roadmap="$(sed -n '/^## NOW/,/^## [^#]/p' "$roadmap_file" 2>/dev/null | grep -E '^(> \*\*|\| [^-])' | head -n 5)"
    [ -n "$roadmap" ] || roadmap="$(grep -E '^(\||>|### |- )' "$roadmap_file" 2>/dev/null | grep -E '\bNEXT\b' | head -n 5)"
    [ -n "$roadmap" ] || roadmap="$(grep -E '^## System:' "$roadmap_file" 2>/dev/null | head -n 5)"
    [ -n "$roadmap" ] && roadmap="$(printf '%s\n' "$roadmap" | sed -E 's/^/    /')"
  fi
  [ -n "$roadmap" ] || roadmap="    (no NOW lane / NEXT items / ROADMAP.md found)"
  if [ -f "${TOPOLOGY_ALIGN_DESTINATION:-$REPO_ROOT/DESTINATION.md}" ]; then
    dest_note="present"
  else
    dest_note="ABSENT — no committed destination to check against"
  fi
  # honest freshness line — NEVER an alignment claim in the cheap tier
  local fresh_line
  case "$v" in
    FRESH)             fresh_line="system map: FRESH (usable for a structural check)";;
    STALE|PARTIAL|STALE_AND_PARTIAL|ANOMALOUS) fresh_line="system map: $v (partial/aged — the deep read will report the exact coverage gap)";;
    CORRUPT)           fresh_line="system map: CORRUPT — unreadable; the deep read will surface the integrity detail";;
    UNINITIALISED)     fresh_line="system map: NONE yet — the deep read will offer to build it (run /topology emitters)";;
    UNREADABLE|*)      fresh_line="system map: freshness UNREADABLE (health-check timed out or errored) — the deep read will retry";;
  esac
  snap="[system-awareness] plan-class work detected — surface system alignment before the plan locks.
  $fresh_line
  ROADMAP NOW:
$roadmap
  DESTINATION: $dest_note
  → Run the deep read now: $ALIGN_REF  (it surfaces open drift + named actions + DESTINATION + open goals,
    applies the honest-degradation matrix, and only licenses \"aligned\" on a FRESH map + IN_SYNC reconcile).
This is advisory — it never blocks. Doctrine: .claude/rules/system-awareness-mandate.md"
  printf '%s' "$snap"
}

# ── core processor ──────────────────────────────────────────────────────────────
process() {  # reads $1 = raw stdin JSON; echoes the envelope or "" (silent)
  local raw="$1" event prompt n
  event="$(printf '%s' "$raw" | jq -r '.hook_event_name // empty' 2>/dev/null)"
  # malformed JSON → jq prints nothing / errors → event empty AND no prompt → silent
  if [ "$event" = "SessionStart" ]; then
    emit "SessionStart" "$HEARTBEAT
$BANNER"
    return 0
  fi
  # UserPromptSubmit (explicit, or inferred from a prompt field)
  prompt="$(printf '%s' "$raw" | jq -r '.prompt // empty' 2>/dev/null)"
  [ -n "$prompt" ] || return 0
  if [ "$event" != "UserPromptSubmit" ] && [ -n "$event" ]; then
    return 0   # a known non-UserPromptSubmit event with a prompt field — not ours
  fi
  n="$(printf '%s' "$prompt" | tr -d '[:space:]' | wc -c | tr -d ' ')"
  n="${n:-0}"
  [ "$n" -ge 8 ] 2>/dev/null || return 0
  is_skip_listed "$prompt" && return 0
  is_plan_class "$prompt" || return 0
  emit "UserPromptSubmit" "$(build_snapshot)"
  return 0
}

# ── self-test (behavioural fire-test incl. the false-negative corpus — council A2) ──
run_self_test() {
  local passed=0 failed=0
  echo "system-awareness-activation self-test"
  echo "====================================="
  # name | payload | check (1=present-tag, 0=silent, 2=banner)
  _chk() {
    local name="$1" payload="$2" want="$3" out ok=0
    out="$(process "$payload")"
    case "$want" in
      banner)  case "$out" in *"$HEARTBEAT"*"system-awareness mandate"*) ok=1;; esac;;
      fires)   case "$out" in *"[system-awareness]"*"$ALIGN_REF"*) ok=1;; esac;;
      silent)  [ -z "$out" ] && ok=1;;
    esac
    if [ "$ok" = "1" ]; then echo "  PASS  $name"; passed=$((passed+1)); else echo "  FAIL  $name (got: $(printf '%s' "$out" | head -c 80))"; failed=$((failed+1)); fi
  }
  _chk "A SessionStart announces banner+heartbeat" '{"hook_event_name":"SessionStart","source":"startup"}' banner
  _chk "B fires on /plan"                          '{"hook_event_name":"UserPromptSubmit","prompt":"/plan add a dashboard"}' fires
  _chk "C fires on build-a-feature"                '{"hook_event_name":"UserPromptSubmit","prompt":"can you build a new matching endpoint for us"}' fires
  _chk "D fires on design-the-architecture"        '{"hook_event_name":"UserPromptSubmit","prompt":"design the architecture for the new intake flow"}' fires
  _chk "E false-neg corpus: restructure"           '{"hook_event_name":"UserPromptSubmit","prompt":"let us restructure the auth flow"}' fires
  _chk "F false-neg corpus: migrate"               '{"hook_event_name":"UserPromptSubmit","prompt":"migrate the billing to the new schema"}' fires
  _chk "G false-neg corpus: move X to Y"           '{"hook_event_name":"UserPromptSubmit","prompt":"move the matcher to an edge function"}' fires
  _chk "H silent on a typo fix"                    '{"hook_event_name":"UserPromptSubmit","prompt":"fix the spelling of recieve"}' silent
  _chk "I silent on a factual lookup"              '{"hook_event_name":"UserPromptSubmit","prompt":"what time is it in cape town"}' silent
  _chk "J silent on /ship (skip-list)"             '{"hook_event_name":"UserPromptSubmit","prompt":"/ship quick — push the branch"}' silent
  _chk "K silent on /topology align (skip-list)"   '{"hook_event_name":"UserPromptSubmit","prompt":"/topology align"}' silent
  _chk "L silent on malformed JSON"                'not json at all {{{' silent
  _chk "M silent on a JSON array"                  '[1,2,3]' silent
  _chk "N silent on sub-8-char prompt"             '{"hook_event_name":"UserPromptSubmit","prompt":"hi"}' silent
  _chk "O implicit-event branch fires on plan-class" '{"prompt":"should we build a new reporting dashboard"}' fires
  _chk "P fires on /autovibe"                      '{"hook_event_name":"UserPromptSubmit","prompt":"/autovibe ship the intake change"}' fires
  _chk "Q fires on /prompt-forge"                  '{"hook_event_name":"UserPromptSubmit","prompt":"/prompt-forge a session prompt for the migration"}' fires
  _chk "R fires on /build-with-agent-team"         '{"hook_event_name":"UserPromptSubmit","prompt":"/build-with-agent-team the new pipeline"}' fires
  _chk "S fires on let's-build (let.?s regex L94)" '{"hook_event_name":"UserPromptSubmit","prompt":"let'"'"'s build the onboarding flow"}' fires
  echo "====================================="
  if [ "$failed" = "0" ]; then echo "system-awareness-activation self-test: ALL PASS ($passed/$passed)"; exit 0; fi
  echo "system-awareness-activation self-test: $failed FAILURE(S) ($passed/$((passed+failed)))" >&2; exit 1
}

# ── dispatch ────────────────────────────────────────────────────────────────────
if [ "$MODE" = "selftest" ]; then
  run_self_test
fi
OUT="$(process "$(cat)")"
[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
