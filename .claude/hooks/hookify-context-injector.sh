#!/bin/bash
# .claude/hooks/hookify-context-injector.sh
#
# Universal hookify context injector — reads matching .local.md rules
# and outputs their content as additional context for Claude.
#
# Claude Code hook protocol:
#   stdin:  JSON { tool_name, tool_input } (PreToolUse/PostToolUse)
#           JSON { stop_hook_type } (Stop)
#   stdout: Plain text → shown to Claude as additional context
#   exit 0: Always permit (this script injects context, never blocks)
#
# Arguments:
#   $1 = event type: PreToolUse | PostToolUse | Stop (default: PreToolUse)
#
# Registered in settings.local.json for specific tool matchers.
# Scans .claude/hookify.*.local.md files with matching frontmatter.
#
# Performance: ~36 files × awk parse ≈ <100ms on modern hardware.

set -euo pipefail

EVENT="${1:-PreToolUse}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKIFY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read stdin (tool call JSON from Claude Code)
INPUT=$(cat 2>/dev/null || echo "{}")

# Extract tool_name for tool-specific events
TOOL_NAME=""
if [[ "$EVENT" == "PreToolUse" || "$EVENT" == "PostToolUse" ]]; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
fi

OUTPUT=""

for rule_file in "$HOOKIFY_DIR"/hookify.*.local.md; do
  [[ -f "$rule_file" ]] || continue

  # ── Parse frontmatter (between first and second ---) ──
  frontmatter=$(awk '/^---$/{n++; if(n==2) exit; next} n==1{print}' "$rule_file" 2>/dev/null) || continue

  enabled=$(echo "$frontmatter" | awk -F': *' '/^enabled:/{print $2; exit}')
  event=$(echo "$frontmatter" | awk -F': *' '/^event:/{print $2; exit}')
  action=$(echo "$frontmatter" | awk -F': *' '/^action:/{print $2; exit}')
  matcher=$(echo "$frontmatter" | awk -F': *' '/^tool_matcher:/{print $2; exit}')
  name=$(echo "$frontmatter" | awk -F': *' '/^name:/{print $2; exit}')
  [[ -z "$name" ]] && name=$(basename "$rule_file" .local.md | sed 's/^hookify\.//')

  # ── Filter: enabled + matching event + context action ──
  [[ "$enabled" == "true" ]] || continue
  [[ "$event" == "$EVENT" ]] || continue
  [[ "$action" == "addContext" || "$action" == "warn" ]] || continue

  # ── Tool matcher check ──
  if [[ -n "$matcher" ]]; then
    if [[ -z "$TOOL_NAME" ]]; then
      # Stop events have no tool_name — skip rules with tool matchers
      continue
    fi
    matched=false
    # Split on | for alternation patterns (e.g., "Write|Edit")
    IFS='|' read -ra alts <<< "$matcher"
    for alt in "${alts[@]}"; do
      # Normalize mixed glob/regex to pure regex:
      #   1. Protect existing .* (regex wildcard)
      #   2. Escape remaining literal dots
      #   3. Convert glob * to regex .*
      #   4. Restore protected .* sequences
      regex=$(echo "$alt" | sed 's/\.\*/__DOTSTAR__/g; s/\./\\./g; s/\*/.*/g; s/__DOTSTAR__/.*/g')
      if echo "$TOOL_NAME" | grep -qE "^${regex}$" 2>/dev/null; then
        matched=true
        break
      fi
    done
    [[ "$matched" == "true" ]] || continue
  fi

  # ── Extract content after frontmatter ──
  content=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$rule_file" 2>/dev/null) || continue

  if [[ -n "$content" ]]; then
    if [[ "$action" == "warn" ]]; then
      OUTPUT+=$'\n'"⚠ hookify/$name:"$'\n'"$content"$'\n'
    else
      OUTPUT+=$'\n'"hookify/$name:"$'\n'"$content"$'\n'
    fi
  fi
done

# Output context to stdout (Claude Code shows this to Claude)
if [[ -n "$OUTPUT" ]]; then
  echo "$OUTPUT"
fi

exit 0
