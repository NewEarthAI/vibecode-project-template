#!/bin/bash
# layman-violation-detector.sh — Stop hook
#
# After-the-fact catch: scans the last assistant message for known layman-voice
# violations and surfaces them so the user does not have to police manually.
# When detected, emits an additionalContext instructing the model to lead its
# next reply with a brief acknowledgement — ensuring the user SEES the catch.
#
# Triple-gated for token efficiency (per .claude/rules/hook-efficiency.md):
#   Gate 1: registered for Stop event only
#   Gate 2: bash-native — extract transcript_path; bail if absent
#   Gate 3: regex-scan last message for known violations; emit only on hit
#
# Cost on clean replies:    ~0 tokens output, <60ms
# Cost on violation replies: ~30 tokens injected, <80ms
# Latency budget:           <100ms (well under 15s timeout)
#
# Detected violations:
#   - menu-of-options ("Three options:", "Two paths:")
#   - raw-claude-path-in-prose (.claude/skills/X/Y.md outside code blocks)
#   - bare-CLI-as-label (npm run X / git push / tsc -- as sentence-start)
#   - American-spelling-in-prose (behavior/organize/realize/optimize/analyze)
#   - undefined-acronym (RPC/RLS/MVCC/JWT/SHA/HMAC used without inline definition)
#
# Self-test:
#   See .claude/hooks/layman-violation-detector.test.sh

set -uo pipefail

input=$(cat 2>/dev/null || echo "{}")

# Gate 2: extract transcript path; bail if missing.
transcript_path=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    print(json.loads(sys.stdin.read()).get("transcript_path", ""))
except Exception:
    pass
' 2>/dev/null)

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  echo '{}'
  exit 0
fi

# Gate 3: extract last assistant message text from transcript JSONL,
# scan for violations, emit only if at least one fires.
last_msg=$(tail -100 "$transcript_path" 2>/dev/null | python3 -c '
import json, sys
last = ""
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("type") == "assistant":
        msg = d.get("message", {})
        for c in (msg.get("content") or []):
            if isinstance(c, dict) and c.get("type") == "text":
                last = c.get("text", "")
# Cap at 4000 chars to keep regex scans fast
print(last[-4000:] if last else "")
' 2>/dev/null)

if [ -z "$last_msg" ]; then
  echo '{}'
  exit 0
fi

# Strip fenced code blocks for prose-only checks (Commonwealth spelling,
# raw paths, bare CLI). Code identifiers are exempt per layman-mode rule.
prose=$(printf '%s' "$last_msg" | awk '
BEGIN { in_code = 0 }
/^```/ { in_code = 1 - in_code; next }
{ if (!in_code) print }
')

violations=()

# 1. Menu-of-options pattern (banned outright per Principle 3)
if printf '%s' "$last_msg" | grep -qiE "(three|two|four|five) (options|paths|choices|ways):"; then
  violations+=("menu-of-options")
fi

# 2. Raw .claude/* paths in prose (kindergarten-teacher principle)
if printf '%s' "$prose" | grep -qE "\.claude/(skills|hooks|rules|commands|memory|agents)/[A-Za-z0-9_-]+/"; then
  violations+=("raw-claude-path-in-prose")
fi

# 3. Bare CLI command as sentence-start label (no prose framing)
if printf '%s' "$prose" | grep -qE "^[[:space:]]*(npm run [a-z:-]+|git push|git rebase|tsc --[a-z]+|gh pr [a-z]+)[[:space:]]"; then
  violations+=("bare-CLI-as-label")
fi

# 4. American spelling in prose (high-confidence words; code identifiers
# pre-stripped via prose extract above).
if printf '%s' "$prose" | grep -qiE "\b(behavior|organize|realize|recognize|optimize|analyze|favorite|color)\b"; then
  # Filter false-positives: "color" is acceptable when referring to CSS/code identifiers
  # Re-check excluding lines that look like code references
  if printf '%s' "$prose" | grep -vE '`[^`]*`' | grep -qiE "\b(behavior|organize|realize|recognize|optimize|analyze|favorite)\b"; then
    violations+=("American-spelling-in-prose")
  fi
fi

# 5. Undefined acronym — the acronym appears but no inline definition follows
# nearby. Heuristic: acronym in prose AND no "ACRONYM —" / "ACRONYM (" pattern.
for acro in RPC RLS MVCC JWT SHA HMAC TTL CRUD PR CI; do
  if printf '%s' "$prose" | grep -qE "\b$acro\b"; then
    if ! printf '%s' "$prose" | grep -qE "\b$acro\b[[:space:]]*[—(]|\b$acro\b[[:space:]]+[a-z]+[[:space:]]+(is|means|stands|=)"; then
      violations+=("undefined-acronym:$acro")
      break  # one acronym flag per turn is enough signal
    fi
  fi
done

if [ ${#violations[@]} -eq 0 ]; then
  echo '{}'
  exit 0
fi

# Emit warning. additionalContext is consumed by the model on the next turn;
# the instruction tells the model to surface the catch to the user so they
# see the system caught it.
joined=$(IFS=", "; printf '%s' "${violations[*]}")
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"⚠️ LAYMAN-VOICE SLIP detected in last reply: ${joined}. On your NEXT reply, lead with one short sentence acknowledging the slip (e.g., \"Layman-slip caught: ${joined} — apologies, fixing.\") so the user sees the system caught it. Then proceed with the user's request in proper layman voice per .claude/rules/layman-mode.md."}}
EOF
