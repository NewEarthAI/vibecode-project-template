#!/usr/bin/env bash
# pocock-implicit-activation.sh — UserPromptSubmit hook
#
# PURPOSE
#   Detect work-class signals in user prompts (e.g. "why is this broken",
#   "stress test this plan", "refactor this") and inject a one-line
#   "Pocock skill candidates" hint into Claude's context. NOT auto-fire —
#   discoverability boost so Claude considers the right skill without
#   requiring the user to use exact trigger phrases from a skill description.
#
# COMPOSES WITH
#   - .claude/rules/pocock-implicit-activation.md (self-discipline rule)
#   - .claude/rules/pre-completion-pocock-check.md (verification gate)
#   - All Pocock skills + tdd-design-companion rule (Spec 22 adoption 2026-05-02)
#
# EXIT
#   Always 0 (advisory only — never blocks). Output goes to stdout as
#   additionalContext for Claude.
#
# COUNCIL CONTEXT
#   2026-05-02 Spec 22 Pocock adoption council (8 agents) flagged:
#     "User shouldn't have to use exact trigger phrases — discoverability
#      via implicit activation closes the gap between owning the skill
#      and actually invoking it."
#
# PERFORMANCE BUDGET
#   <50ms per invocation. Bash-native pattern matching, no external CLI.

set -uo pipefail

# Read prompt from stdin (Claude Code passes {"prompt": "..."} JSON)
INPUT=$(cat)

# Extract the prompt text. Handle both raw text + JSON-wrapped forms.
if echo "$INPUT" | head -c 1 | grep -q '{'; then
  # JSON form — extract .prompt field. Use python (universal) since jq
  # may not be on every Mac and we want this hook to be portable.
  PROMPT=$(echo "$INPUT" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null || echo "$INPUT")
else
  PROMPT="$INPUT"
fi

# Lowercase for case-insensitive matching. Strip newlines.
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')

# Skip if prompt is trivially short or matches negation patterns
[ ${#LOWER} -lt 8 ] && exit 0

# Skip if user is explicitly invoking a non-Pocock workflow that takes precedence
case "$LOWER" in
  /commit*|/push*|/ship*|/setup*|/daily-plan*|/prime*) exit 0 ;;
esac

# ──────────────────────────────────────────────────────────────────────────
# Pattern detection — work classes that map to Pocock skills.
# Order matters: most specific first. We surface AT MOST one hint per turn
# to avoid noise. If multiple match, the first match wins.
# ──────────────────────────────────────────────────────────────────────────

CANDIDATES=""

# Class 1 — DEBUG / DIAGNOSE signals (highest priority — most error-prone class)
if echo "$LOWER" | grep -qE '\b(broken|throwing|crashing|failing|fails|fail\b|hang(s|ing)?|stuck|errored?|exception|stack trace|why is this|what.{1,12}wrong|doesn.t work|isn.t working|not working|timeout|timing out|slow|regress(ion|ed)|perf(ormance)? (issue|problem)|silent(ly)? fail)' 2>/dev/null; then
  CANDIDATES="pocock-diagnose"
fi

# Class 2 — PLAN GRILLING / DOMAIN-LANGUAGE signals
if [ -z "$CANDIDATES" ] && echo "$LOWER" | grep -qE '\b(grill|stress[- ]test|challenge (this|my|the) (plan|design|approach)|fuzzy|sharpen|domain (model|language|glossary)|context\.md|adr|architecture decision|ubiquitous)' 2>/dev/null; then
  CANDIDATES="pocock-grill-with-docs"
fi

# Class 3 — REFACTOR / DEEPENING signals
if [ -z "$CANDIDATES" ] && echo "$LOWER" | grep -qE '\b(refactor|deepen|extract module|tangled|messy code|ball of mud|coupled|tightly coupled|shallow module|deep module|architecture (review|audit|clean)|spaghetti|code smell)' 2>/dev/null; then
  CANDIDATES="pocock-improve-codebase-architecture"
fi

# Class 4 — UNFAMILIAR CODE / ORIENTATION signals
if [ -z "$CANDIDATES" ] && echo "$LOWER" | grep -qE '\b(zoom out|don.t know this|unfamiliar|explain this (code|module|file)|what does this|how does this fit|map of|higher.level (view|perspective))' 2>/dev/null; then
  CANDIDATES="pocock-zoom-out"
fi

# Class 5 — TEST WRITING signals
if [ -z "$CANDIDATES" ] && echo "$LOWER" | grep -qE '\b(write tests?|tdd|test[- ]driven|red[- ]green[- ]refactor|test[- ]first|failing test|regression test|unit test|integration test)' 2>/dev/null; then
  CANDIDATES="superpowers:test-driven-development + .claude/rules/tdd-design-companion.md"
fi

# Class 6 — TOKEN EFFICIENCY signals
if [ -z "$CANDIDATES" ] && echo "$LOWER" | grep -qE '\b(be brief|less tokens?|shorter|compact|terse|tldr|caveman|condense|reduce verbosity|too verbose|too long)' 2>/dev/null; then
  CANDIDATES="caveman"
fi

# No match → silent exit (most prompts shouldn't trigger)
[ -z "$CANDIDATES" ] && exit 0

# ──────────────────────────────────────────────────────────────────────────
# Output: minimal context-injection line. One sentence, prefixed for visibility,
# names the candidate skill(s) + the implicit-activation rule.
# ──────────────────────────────────────────────────────────────────────────

cat <<EOF
[pocock-hint] Work class detected → consider: ${CANDIDATES}.
Read .claude/rules/pocock-implicit-activation.md before claiming completion.
EOF

exit 0
