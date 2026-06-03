#!/usr/bin/env bash
# framing-audit-activation.sh — SessionStart + UserPromptSubmit hook
#
# PURPOSE
#   Layer 2 of the Mandatory Framing-Audit Programme. Makes the framing-audit
#   suite ACTIVE, not merely mandated.
#     - SessionStart  → injects the framing-audit mandate banner into EVERY
#                       session (the operator's "no session without it"
#                       requirement). Unconditional. Carries a heartbeat
#                       marker so a degraded hook is observable.
#     - UserPromptSubmit → pattern-matches the prompt for decision / comparison
#                       / framing signals; injects AT MOST one one-line nudge
#                       toward the matching framing-audit primitive. Silent on
#                       every non-trigger and on trivial slash commands.
#
#   The hook ANNOUNCES the mandate every session; it NUDGES the audit only at
#   framing-relevant moments. It never runs an audit on trivia — that is the
#   announce-vs-run distinction in .claude/rules/framing-audit-mandate.md.
#
# COMPOSES WITH
#   - .claude/rules/framing-audit-mandate.md   (Layer 1 — the doctrine)
#   - the 5 framing-audit primitives (the 4 skills + the _shared classifier)
#   - modelled on .claude/hooks/pocock-implicit-activation.sh (shape, not content)
#   - heartbeat discipline modelled on sessionstart-context-aggregator.sh
#
# OUTPUT
#   A JSON envelope on stdout keyed to the event:
#     {"hookSpecificOutput":{"hookEventName":"<event>","additionalContext":"..."}}
#   Silent (no output) on a non-trigger UserPromptSubmit.
#
# EXIT
#   Always 0 in hook mode — advisory only, NEVER blocks a tool call.
#   --self-test mode: 0 if all cases pass, 1 if any fail.
#
# SELF-TEST
#   bash .claude/hooks/framing-audit-activation.sh --self-test
#   Proves the hook fires on every detection class AND stays silent on every
#   non-trigger — the behavioural fire-test the programme contract mandates.
#
# PERFORMANCE BUDGET
#   <120ms (one python3 startup). SessionStart fires once/session;
#   UserPromptSubmit once/prompt.

set -uo pipefail

# ── Hook-profile-gating kill-switch (see .claude/rules/hook-profile-gating.md) ─
# Honours HOOK_FRAMING_AUDIT_ACTIVATION ∈ {0,false,no,off,disabled} → DISABLE.
# Default (unset/empty) or 1/true/yes/enabled = ENABLED. Matches AUTOVIBE_AUTOFIRE
# precedent exactly (no _DISABLED suffix; feature-flag, not state-assertion).
# This hook is advisory-only — disabling is safe (NOT a safety-critical guard).
HOOK_DISABLE_VAR="HOOK_FRAMING_AUDIT_ACTIVATION"
HOOK_DISABLE_VAL="$(printf '%s' "${!HOOK_DISABLE_VAR:-}" | tr '[:upper:]' '[:lower:]')"
case "$HOOK_DISABLE_VAL" in
  0|false|no|off|disabled)
    echo "framing-audit-activation: DISABLED via ${HOOK_DISABLE_VAR}=${!HOOK_DISABLE_VAR} — unset or set to 1/true/yes/enabled to re-enable" >&2
    exit 0
    ;;
esac

# ── The processing logic (python3 — portable; quoted heredoc = literal) ──────
PYCODE=$(cat <<'PYEOF'
import sys, json, re

HEARTBEAT = "[framing-audit-hook: active]"

BANNER = """[framing-audit mandate] A framing audit — checking the question is the RIGHT
question before answering it — is COMPULSORY before any load-bearing decision: build-vs-buy,
architecture choices, comparison-based verdicts, the goal of any multi-phase orchestration,
and creating or auditing a Claude Code artefact. NOT for trivia (typo fixes, factual
lookups, settings tweaks) — the mandate is announced every session; the audit runs only on
load-bearing decisions.

The five framing-audit primitives:
  /reduce-to-first-principles  - reduce a proposal/claim/gate to its irreducible question
  /check-commensurability      - classify a comparison; fire the Hands-On Calibration Gate
  /map-feedback-loops          - project a decision's second-order effects (DECISION mode)
  /audit-artefact-grounding    - audit a skill/rule/hook/agent/doctrine on six axes
  _shared/frame-vs-input-classifier.md - classify operator pushback (frame vs input)

Doctrine: .claude/rules/framing-audit-mandate.md  (the audit is a named, non-skippable step)"""

# Trivial workflows — no framing decision is being made here.
SKIP_TRIVIAL = ("/commit", "/push", "/ship", "/setup", "/daily-plan", "/prime")
# The framing tools themselves (already auditing) + /council, whose Reframer
# agent runs the framing audit as Phase 0 (see framing-audit-mandate.md). Skip.
SKIP_AUDITING = ("/council", "/reduce-to-first-principles", "/check-commensurability",
                 "/map-feedback-loops", "/audit-artefact-grounding",
                 "/diagnose-bottleneck", "/decide-under-uncertainty")
SKIP_PREFIXES = SKIP_TRIVIAL + SKIP_AUDITING

# Detection classes — compiled once at module load. A compile failure is
# surfaced to stderr and the hook exits 0 (never blocks). Order in _CLASSES
# below is most-specific-first; one match wins.
try:
    # A multi-phase orchestration starting — audit the goal's framing first.
    # (/council is NOT here — it is skip-listed; its Reframer handles Phase 0.)
    _ORCHESTRATION = re.compile(
        r"^\s*/(autovibe|plan|prompt-forge|build-with-agent-team)\b")
    # Operator pushback at a framing juncture.
    _PUSHBACK = re.compile(
        r"\bnot what i (asked|meant|wanted)\b|\bthat.?s not what i\b"
        r"|\bwait[ ,.—-]+what\b")
    # A comparison underpinning a verdict. The bare "X than Y" clause is gated
    # behind an interrogative/decision lead so plain declaratives
    # ("this loads faster than before") do not false-fire.
    _COMPARISON = re.compile(
        r"\b(vs\.?|versus)\b|\bbuild[- ]?vs[- ]?buy\b"
        r"|\bwhich (one |option )?(is |would be )?(better|best|cheaper|faster)\b"
        r"|\bcompared? (to|with|against)\b|\bapples (and|to) (pears|oranges)\b"
        r"|\bare we comparing\b|\b(adopt|buy|integrate) .* or build\b"
        r"|\bbuild .* or (adopt|buy|integrate|use)\b"
        r"|\b(is|are|was|were|would|will|should) [a-z].{0,55}?(better|worse|cheaper|faster|stronger|safer) than\b"
        r"|\b(better|worse|cheaper|faster|stronger|safer) than\b[^?\n]{0,40}\?")
    # A decision with second-order / over-time consequences.
    _SECONDORDER = re.compile(
        r"\bsecond[- ]?order\b|\bdownstream (effect|consequence|impact)\b"
        r"|\bripple\b|\bknock[- ]?on\b|\bunintended consequence"
        r"|\bfeedback loop\b|\blong[- ]?term (effect|consequence|impact)\b"
        r"|\bover the long\b")
    # Creating or auditing a Claude Code artefact — incl. rule + doctrine,
    # this project's primary artefact types.
    _ARTEFACT = re.compile(
        r"\baudit (this |the |my )?(skill|rule|hook|agent|doctrine)\b"
        r"|\b(create|build|write|ship|add) (a |an |the )?(new )?(skill|hook|rule|doctrine|agent|sub-?agent)\b"
        r"|\bis (this|the) (skill|rule|hook|agent|doctrine) (grounded|sound|well[- ]grounded)\b"
        r"|\breview (this|the|my) (skill|rule|hook|doctrine)\b")
    # A proposal / decision framing.
    _PROPOSAL = re.compile(
        r"\bshould (we|i)\b|\bdo we (build|buy|adopt|need)\b|\bis it worth\b"
        r"|\bworth (building|doing|it)\b|\b(let.?s|lets) (build|create)\b"
        r"|\bwe (need|should) to build\b|\bdecide whether\b|\bthe right question\b"
        r"|\bare we (asking|solving)\b|\breframe\b|\bfirst principles\b")
except re.error as exc:  # pragma: no cover — surfaced, never silenced
    sys.stderr.write("framing-audit-activation: regex compile error: %s\n" % exc)
    sys.exit(0)  # still never block — but the failure is visible on stderr

_CLASSES = [
    (_ORCHESTRATION, "a multi-phase orchestration is starting — run "
                     "/reduce-to-first-principles on the goal's framing before the "
                     "phases run."),
    (_PUSHBACK,    "operator pushback at a framing juncture — classify it (frame-criticism "
                   "vs input-criticism) via _shared/frame-vs-input-classifier.md before "
                   "answering inside the current frame."),
    (_COMPARISON,  "a comparison detected — run /check-commensurability before the verdict "
                   "locks (is this estimate-vs-estimate?)."),
    (_SECONDORDER, "a decision with over-time consequences — run /map-feedback-loops "
                   "(DECISION mode) before committing."),
    (_ARTEFACT,    "creating or auditing a Claude Code artefact — run "
                   "/audit-artefact-grounding on it."),
    (_PROPOSAL,    "a decision framing detected — run /reduce-to-first-principles before "
                   "locking it (what is the irreducible question?)."),
]

_NUDGE_TAIL = ("\nFraming audit is compulsory before load-bearing decisions — see "
               ".claude/rules/framing-audit-mandate.md")


def detect(lower):
    """Return the nudge body for the first matching class, or None."""
    for rx, body in _CLASSES:
        if rx.search(lower):
            return body
    return None


def envelope(event, ctx):
    return json.dumps({"hookSpecificOutput": {"hookEventName": event,
                                              "additionalContext": ctx}})


def process(raw):
    """Map a raw hook-input JSON string to the stdout string (empty = silent)."""
    try:
        data = json.loads(raw)
    except Exception:
        return ""  # never crash a session on a malformed payload
    if not isinstance(data, dict):
        return ""
    event = data.get("hook_event_name")

    # SessionStart — announce the mandate, unconditional. The heartbeat marker
    # makes a degraded hook observable (silent SessionStart == something wrong).
    if event == "SessionStart":
        return envelope("SessionStart", HEARTBEAT + "\n" + BANNER)

    # UserPromptSubmit (explicit, or inferred from a prompt field).
    if event == "UserPromptSubmit" or (event is None and "prompt" in data):
        prompt = data.get("prompt", "") or ""
        lower = prompt.lower()
        if len(lower.strip()) < 8:
            return ""
        if lower.lstrip().startswith(SKIP_PREFIXES):
            return ""
        nudge = detect(lower)
        if nudge:
            return envelope("UserPromptSubmit", "[framing-audit] " + nudge + _NUDGE_TAIL)
        return ""

    return ""  # unknown event with no prompt — silent


def run_self_test():
    """Behavioural fire-test — every detection class fires; non-triggers stay silent."""
    cases = [
        ("A  SessionStart announces the mandate + heartbeat",
         '{"hook_event_name":"SessionStart","source":"startup"}',
         lambda o: HEARTBEAT in o and "framing-audit mandate" in o
                   and "/reduce-to-first-principles" in o),
        ("B  UserPromptSubmit fires on a build-vs-buy comparison",
         '{"hook_event_name":"UserPromptSubmit","prompt":"should we build our own auth or use Clerk?"}',
         lambda o: "[framing-audit]" in o and "/check-commensurability" in o),
        ("C  UserPromptSubmit silent on a non-trigger",
         '{"hook_event_name":"UserPromptSubmit","prompt":"what time is it"}',
         lambda o: o == ""),
        ("D  UserPromptSubmit silent on a skip-list command",
         '{"hook_event_name":"UserPromptSubmit","prompt":"/ship quick — push the branch"}',
         lambda o: o == ""),
        ("E  _COMPARISON fires on an interrogative 'better than'",
         '{"hook_event_name":"UserPromptSubmit","prompt":"is Postgres better than MongoDB for this?"}',
         lambda o: "/check-commensurability" in o),
        ("F  _PROPOSAL fires in isolation (no comparison present)",
         '{"hook_event_name":"UserPromptSubmit","prompt":"should we adopt this new workflow"}',
         lambda o: "/reduce-to-first-principles" in o),
        ("G  _PUSHBACK fires on operator framing pushback",
         '{"hook_event_name":"UserPromptSubmit","prompt":"hang on, that is not what I asked for"}',
         lambda o: "frame-vs-input-classifier" in o),
        ("H  _SECONDORDER fires on an over-time decision",
         '{"hook_event_name":"UserPromptSubmit","prompt":"what are the second-order effects of this decision?"}',
         lambda o: "/map-feedback-loops" in o),
        ("I  _ARTEFACT fires on auditing a skill",
         '{"hook_event_name":"UserPromptSubmit","prompt":"can you audit this skill for me"}',
         lambda o: "/audit-artefact-grounding" in o),
        ("J  _ARTEFACT fires on creating a rule (the rule/doctrine fix)",
         '{"hook_event_name":"UserPromptSubmit","prompt":"write a new rule to enforce our architecture decisions"}',
         lambda o: "/audit-artefact-grounding" in o),
        ("K  _ORCHESTRATION fires on a bare /autovibe invocation",
         '{"hook_event_name":"UserPromptSubmit","prompt":"/autovibe resume the build cycle"}',
         lambda o: "/reduce-to-first-principles" in o and "orchestration" in o),
        ("L  implicit-event branch (no hook_event_name) fires",
         '{"prompt":"should we build or buy this tool?"}',
         lambda o: o != "" and "[framing-audit]" in o),
        ("M  malformed JSON returns empty (no crash)",
         'not json at all {{{',
         lambda o: o == ""),
        ("N  JSON array (not an object) returns empty",
         '[1, 2, 3]',
         lambda o: o == ""),
        ("O  sub-8-char prompt is silent",
         '{"hook_event_name":"UserPromptSubmit","prompt":"abc de"}',
         lambda o: o == ""),
    ]
    passed = failed = 0
    print("framing-audit-activation self-test")
    print("===================================")
    for name, payload, check in cases:
        try:
            out = process(payload)
            ok = bool(check(out))
        except Exception as exc:  # noqa
            ok, out = False, "EXC:%s" % exc
        if ok:
            print("  PASS  %s" % name)
            passed += 1
        else:
            print("  FAIL  %s  (got: %r)" % (name, out[:140]))
            failed += 1
    print("===================================")
    if failed == 0:
        print("framing-audit-activation self-test: ALL PASS (%d/%d)" % (passed, passed))
        sys.exit(0)
    print("framing-audit-activation self-test: %d FAILURE(S) (%d/%d)"
          % (failed, passed, passed + failed), file=sys.stderr)
    sys.exit(1)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "run"
    if mode in ("selftest", "--self-test"):
        run_self_test()
        return
    out = process(sys.stdin.read())
    if out:
        print(out)
    sys.exit(0)


main()
PYEOF
)

# ── Mode dispatch ────────────────────────────────────────────────────────────
MODE="run"
[ "${1:-}" = "--self-test" ] && MODE="selftest"

# python3 absent → graceful no-op. The mandate is NOT lost: the rule
# (.claude/rules/framing-audit-mandate.md) still loads; only the active hook
# nudge + the SessionStart announcement degrade. The degradation is announced
# on stderr so it is observable (a hook must never block a session).
if ! command -v python3 >/dev/null 2>&1; then
  if [ "$MODE" = "selftest" ]; then
    echo "SKIP: python3 not available — cannot run self-test"
    exit 0
  fi
  echo "framing-audit-activation: python3 absent — hook degraded (mandate rule still loads; SessionStart announcement skipped)" >&2
  exit 0
fi

if [ "$MODE" = "selftest" ]; then
  python3 -c "$PYCODE" selftest </dev/null
  exit $?
fi

# Hook mode — feed stdin straight to the processor. A python3 failure does NOT
# abort the script (no `set -e`); the trailing `exit 0` always runs.
python3 -c "$PYCODE" run
exit 0
