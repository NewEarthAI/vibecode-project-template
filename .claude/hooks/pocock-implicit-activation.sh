#!/usr/bin/env bash
# pocock-implicit-activation.sh — UserPromptSubmit hook
#
# PURPOSE
#   Layer 2 of the Pocock Implicit-Activation Programme. Surfaces a one-line
#   `[pocock-hint] consider: X` nudge when patterns match the bug-class,
#   plan-stress-test, refactor, or unfamiliar-code work classes — without
#   forcing the user to type the exact trigger phrase from a Pocock skill's
#   description field.
#
#   The hook NUDGES; it never invokes. The rule
#   (~/.claude/rules/pocock-implicit-activation.md, project-mirrored at
#   .claude/rules/pocock-implicit-activation.md when present) is the doctrine
#   that tells Claude what to do with the nudge.
#
# ESCALATION (added 2026-05-20)
#   After the 2nd hint in the same session WITHOUT a Pocock invocation, the
#   hook escalates with a louder message:
#     "Pocock hint fired twice without invocation. Either invoke
#      /pocock-diagnose now OR explicitly state why you're proceeding
#      without it."
#   Rationale: a single ignored hint is acceptable (judgment call); two ignored
#   hints in one session signals the hook is being routed around rather than
#   judged. The escalation prompts a decision, not a halt.
#
# OUTPUT
#   JSON envelope on stdout when the hint fires:
#     {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."}}
#   Silent on every non-trigger.
#
# EXIT
#   Always 0 in hook mode — advisory only, NEVER blocks a tool call.
#   --self-test mode: 0 if all cases pass, 1 if any fail.
#
# SELF-TEST
#   bash .claude/hooks/pocock-implicit-activation.sh --self-test

set -uo pipefail

# Session-scoped counter for escalation. CLAUDE_SESSION_ID is preferred when
# present; fall back to a stable per-shell sentinel so the counter persists
# across invocations within the same session.
COUNTER_DIR="${TMPDIR:-/tmp}"
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
COUNTER_FILE="${COUNTER_DIR}/pocock-hint-count-${SESSION_ID}"

PYCODE=$(cat <<'PYEOF'
import sys, json, re, os

COUNTER_FILE = os.environ.get("POCOCK_COUNTER_FILE", "/tmp/pocock-hint-count-default")

# Detection classes — most-specific first. One match wins.
try:
    _BUG = re.compile(
        r"\b(bug|broken|throwing|failing|crash|timeout|perf regression"
        r"|error|exception|stack ?trace|500|404|why is this failing)\b")
    _PLAN_GRILL = re.compile(
        r"\b(stress[- ]?test|grill|challenge this (design|plan|spec)"
        r"|fuzzy|domain language|sharpen the (plan|spec))\b")
    _REFACTOR = re.compile(
        r"\b(refactor|tangled|extract (this|the)|ball of mud|deepen"
        r"|shallow module|simplif(y|ying) this|clean(ing)? up this code)\b")
    _UNFAMILIAR = re.compile(
        r"\bexplain this code\b|\bi don.?t know this area\b"
        r"|\bhow does this (fit|work)\b|\bzoom out\b")
except re.error as exc:
    sys.stderr.write("pocock-implicit-activation: regex compile error: %s\n" % exc)
    sys.exit(0)

_CLASSES = [
    (_BUG,         "/pocock-diagnose",        "bug-class signal — consider /pocock-diagnose (6-phase feedback loop)"),
    (_PLAN_GRILL,  "/pocock-grill-with-docs", "plan/spec stress-test signal — consider /pocock-grill-with-docs"),
    (_REFACTOR,    "/pocock-improve-codebase-architecture", "refactor signal — consider /pocock-improve-codebase-architecture (deep modules)"),
    (_UNFAMILIAR,  "/pocock-zoom-out",        "unfamiliar-code signal — consider /pocock-zoom-out"),
]

# Skip lists — already invoking a Pocock tool, or running a trivial slash command.
SKIP_POCOCK = ("/pocock-diagnose", "/pocock-grill-with-docs",
               "/pocock-improve-codebase-architecture", "/pocock-zoom-out")
SKIP_TRIVIAL = ("/commit", "/push", "/ship", "/setup", "/daily-plan", "/prime")
SKIP_PREFIXES = SKIP_POCOCK + SKIP_TRIVIAL


def detect(lower):
    for rx, primitive, body in _CLASSES:
        if rx.search(lower):
            return primitive, body
    return None, None


def read_counter():
    try:
        with open(COUNTER_FILE, "r") as fh:
            raw = fh.read().strip()
            return int(raw) if raw else 0
    except Exception:
        return 0


def write_counter(n):
    try:
        with open(COUNTER_FILE, "w") as fh:
            fh.write(str(n))
    except Exception:
        pass  # counter is best-effort; never crash a session


def reset_counter():
    try:
        os.unlink(COUNTER_FILE)
    except Exception:
        pass


def envelope(ctx):
    return json.dumps({"hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": ctx}})


def process(raw):
    try:
        data = json.loads(raw)
    except Exception:
        return ""
    if not isinstance(data, dict):
        return ""

    event = data.get("hook_event_name")
    if event and event != "UserPromptSubmit" and "prompt" not in data:
        return ""

    prompt = (data.get("prompt") or "").strip()
    lower = prompt.lower()
    if len(lower) < 8:
        return ""

    # If the user is invoking a Pocock skill, reset the counter and stay silent.
    if lower.lstrip().startswith(SKIP_POCOCK):
        reset_counter()
        return ""

    # Trivial commands — stay silent, don't touch the counter.
    if lower.lstrip().startswith(SKIP_TRIVIAL):
        return ""

    primitive, body = detect(lower)
    if not primitive:
        return ""

    count = read_counter() + 1
    write_counter(count)

    if count >= 2:
        msg = ("[pocock-hint ESCALATION] %s\n"
               "Pocock hint fired twice without invocation. "
               "Either invoke %s now OR explicitly state why you're "
               "proceeding without it.\n"
               "Doctrine: ~/.claude/rules/pocock-implicit-activation.md"
               % (body, primitive))
    else:
        msg = ("[pocock-hint] consider: %s\n"
               "Doctrine: ~/.claude/rules/pocock-implicit-activation.md"
               % body)

    return envelope(msg)


def run_self_test():
    cases = [
        ("A  bug-class fires /pocock-diagnose hint (1st = standard)",
         '{"hook_event_name":"UserPromptSubmit","prompt":"this is throwing a 500 error in production"}',
         lambda o: "[pocock-hint]" in o and "/pocock-diagnose" in o and "ESCALATION" not in o,
         True),  # reset counter before
        ("B  2nd consecutive hint escalates",
         '{"hook_event_name":"UserPromptSubmit","prompt":"this code is broken and failing"}',
         lambda o: "ESCALATION" in o and "twice without invocation" in o,
         False),
        ("C  invoking /pocock-diagnose resets + stays silent",
         '{"hook_event_name":"UserPromptSubmit","prompt":"/pocock-diagnose start the loop"}',
         lambda o: o == "",
         False),
        ("D  post-reset, next bug-class is standard again",
         '{"hook_event_name":"UserPromptSubmit","prompt":"why is this failing again"}',
         lambda o: "[pocock-hint]" in o and "ESCALATION" not in o,
         False),
        ("E  refactor-class fires /pocock-improve-codebase-architecture",
         '{"hook_event_name":"UserPromptSubmit","prompt":"can we refactor this tangled module"}',
         lambda o: "[pocock-hint" in o and "/pocock-improve-codebase-architecture" in o,
         True),  # reset to test category in isolation
        ("F  plan-grill fires /pocock-grill-with-docs",
         '{"hook_event_name":"UserPromptSubmit","prompt":"stress-test this plan for me"}',
         lambda o: "/pocock-grill-with-docs" in o,
         True),
        ("G  unfamiliar-code fires /pocock-zoom-out",
         '{"hook_event_name":"UserPromptSubmit","prompt":"explain this code area, I do not know it"}',
         lambda o: "/pocock-zoom-out" in o,
         True),
        ("H  non-trigger stays silent",
         '{"hook_event_name":"UserPromptSubmit","prompt":"what time is it"}',
         lambda o: o == "",
         True),
        ("I  trivial slash command stays silent",
         '{"hook_event_name":"UserPromptSubmit","prompt":"/ship quick"}',
         lambda o: o == "",
         True),
        ("J  short prompt stays silent",
         '{"hook_event_name":"UserPromptSubmit","prompt":"hi"}',
         lambda o: o == "",
         True),
        ("K  malformed JSON returns empty",
         'not json',
         lambda o: o == "",
         True),
    ]
    passed = failed = 0
    print("pocock-implicit-activation self-test")
    print("=====================================")
    for name, payload, check, reset_before in cases:
        if reset_before:
            reset_counter()
        try:
            out = process(payload)
            ok = bool(check(out))
        except Exception as exc:
            ok, out = False, "EXC:%s" % exc
        if ok:
            print("  PASS  %s" % name)
            passed += 1
        else:
            print("  FAIL  %s  (got: %r)" % (name, out[:160]))
            failed += 1
    reset_counter()  # clean up after self-test
    print("=====================================")
    if failed == 0:
        print("pocock-implicit-activation self-test: ALL PASS (%d/%d)" % (passed, passed))
        sys.exit(0)
    print("pocock-implicit-activation self-test: %d FAILURE(S) (%d/%d)"
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

# Mode dispatch
MODE="run"
[ "${1:-}" = "--self-test" ] && MODE="selftest"

# Export counter file path so python sub-process sees it
export POCOCK_COUNTER_FILE="${COUNTER_FILE}"

if ! command -v python3 >/dev/null 2>&1; then
  if [ "$MODE" = "selftest" ]; then
    echo "SKIP: python3 not available — cannot run self-test"
    exit 0
  fi
  echo "pocock-implicit-activation: python3 absent — hook degraded" >&2
  exit 0
fi

if [ "$MODE" = "selftest" ]; then
  python3 -c "$PYCODE" selftest </dev/null
  exit $?
fi

python3 -c "$PYCODE" run
exit 0
