#!/usr/bin/env bash
# code-council-verification.sh — SubagentStop hook.
#
# When a code-council / code-review subagent issues a PASS verdict without a
# verification artifact, inject a downgrade message into the parent session.
#
# Artifact = one of:
#   - `VERIFIED:` prefix line
#   - Triple-backtick terminal-output block (```)
#   - Specific file:line citation (path/to/file.tsx:123)
#   - Inline screenshot reference
#
# Rationale: diff-only review can issue PASS on code that crashes at runtime
# if the bug straddles a scope boundary (declaration in one function, usage in
# another) where both sides pre-date the diff. Runtime evidence — typecheck
# output, a playwright screenshot, or even a single file:line citation — is
# what distinguishes an authoritative review from a plausibility check.
# See .claude/rules/typecheck-and-review-gates.md.
#
# Triple-gate pattern (hook-efficiency.md §2):
#   Gate 1 — SubagentStop event (registered in settings.local.json)
#   Gate 2 — raw substring "PASS" / "VERDICT" in transcript tail (<10ms bail)
#   Gate 3 — agent-type matches targeted list; final response contains PASS
#
# Registration (in .claude/settings.local.json or shared .claude/settings.json):
#   "SubagentStop": [{
#     "matcher": "*",
#     "hooks": [{
#       "type": "command",
#       "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/code-council-verification.sh",
#       "timeout": 10
#     }]
#   }]

set -uo pipefail

# Read stdin JSON safely — on any parse error, exit cleanly with no-op
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && { echo '{}'; exit 0; }

# Gate 2a — raw-string fast-path on stdin (should mention transcript_path)
case "$INPUT" in
  *transcript_path*) : ;;
  *) echo '{}'; exit 0 ;;
esac

# Extract transcript path — bail if jq unavailable or path missing
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  echo '{}'; exit 0
fi

# Gate 2b — raw-string fast-path on transcript tail. If no "PASS" mention
# anywhere recent, we're not scoring this subagent. <5ms bail.
TAIL=$(tail -500 "$TRANSCRIPT" 2>/dev/null || true)
case "$TAIL" in
  *PASS*|*VERDICT*|*"code-council"*|*"code review"*|*"code reviewer"*) : ;;
  *) echo '{}'; exit 0 ;;
esac

# Gate 3a — identify subagent_type from most recent Task invocation in tail.
# Transcript is JSONL; Task tool_use entries contain subagent_type.
AGENT_TYPE=$(printf '%s\n' "$TAIL" | grep -oE '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]+"' | tail -1 | sed -E 's/.*"([^"]+)"$/\1/')

# Is this a reviewer-class subagent? If not, skip.
case "$AGENT_TYPE" in
  security-auditor|performance-reviewer|spec-validator|feature-dev:code-reviewer|pr-review-toolkit:code-reviewer|superpowers:code-reviewer|code-reviewer|silent-failure-hunter|pr-test-analyzer|comment-analyzer|type-design-analyzer|master-code-reviewer)
    : # targeted
    ;;
  *)
    echo '{}'; exit 0
    ;;
esac

# Gate 3b — extract the most recent assistant message content from the transcript.
# JSONL format: last line with "role":"assistant" (or "type":"assistant" in some variants).
FINAL_LINE=$(tail -300 "$TRANSCRIPT" 2>/dev/null | grep -E '"(role|type)"[[:space:]]*:[[:space:]]*"assistant"' | tail -1 || true)
[ -z "$FINAL_LINE" ] && { echo '{}'; exit 0; }

FINAL_RESPONSE=$(printf '%s' "$FINAL_LINE" | jq -r '
  if .message.content then
    (.message.content | if type == "array" then map(select(.type == "text") | .text) | join("\n") else . end)
  elif .content then
    (.content | if type == "array" then map(select(.type == "text") | .text) | join("\n") else . end)
  else empty end
' 2>/dev/null || true)

[ -z "$FINAL_RESPONSE" ] && { echo '{}'; exit 0; }

# Check for PASS verdict language. Must be explicit, not incidental.
if ! printf '%s' "$FINAL_RESPONSE" | grep -qE '(^|[^a-zA-Z])(PASS|Verdict:[[:space:]]*PASS|✓ PASS|approved)( |$|\.|\,|:|;)'; then
  echo '{}'; exit 0
fi

# Check for at least one verification artifact.
HAS_VERIFIED=0
HAS_CODE_BLOCK=0
HAS_FILE_LINE=0
HAS_SCREENSHOT=0

printf '%s' "$FINAL_RESPONSE" | grep -qE '(^|[^a-zA-Z])VERIFIED:' && HAS_VERIFIED=1
printf '%s' "$FINAL_RESPONSE" | grep -q '```'                      && HAS_CODE_BLOCK=1
printf '%s' "$FINAL_RESPONSE" | grep -qE '[a-zA-Z0-9_/.-]+\.(ts|tsx|js|jsx|sh|sql|py|md|json|yml|yaml):[0-9]+' && HAS_FILE_LINE=1
printf '%s' "$FINAL_RESPONSE" | grep -qiE '(screenshot|snapshot|\.png|\.jpg)' && HAS_SCREENSHOT=1

TOTAL=$((HAS_VERIFIED + HAS_CODE_BLOCK + HAS_FILE_LINE + HAS_SCREENSHOT))

if [ "$TOTAL" -eq 0 ]; then
  MSG="code-council-verification: The '${AGENT_TYPE}' subagent issued a PASS verdict without a verification artifact. Per .claude/rules/typecheck-and-review-gates.md, PASS without runtime evidence is not authoritative — diff-only review can miss scope bugs where both declaration and usage pre-date the diff. AUTO-DOWNGRADE TO ADVISORY. Before shipping based on this review, re-invoke the subagent with a request for concrete evidence: (a) 'npm run typecheck' terminal output, (b) a specific file:line citation with actual content, (c) a playwright screenshot reference, or (d) a 'VERIFIED:' prefix line documenting what was checked. The PASS verdict alone is insufficient."

  # Emit stderr line for visibility in Claude Code logs
  echo "$MSG" >&2

  # Also emit structured additionalContext via hookSpecificOutput — Claude Code
  # will inject this into the parent session's next turn if supported for this event.
  jq -nc --arg msg "$MSG" '{
    "hookSpecificOutput": {
      "hookEventName": "SubagentStop",
      "additionalContext": $msg
    }
  }'
  exit 0
fi

echo '{}'
exit 0
