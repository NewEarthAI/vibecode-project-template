#!/usr/bin/env bash
# worktree-guard.sh — PreToolUse hook (matcher: Bash)
# Two concerns, one hook, triple-gated for token + latency efficiency:
#   1. Branch-modifying git op while other worktrees exist → inject worktree reminder
#   2. `git worktree add` → scan for stale .git/*.lock files
#
# EFFICIENCY CONTRACT:
#   - Matcher narrows to Bash (not *) — ~40% of tool calls max
#   - FAST PATH: bash-native substring check on raw JSON (no jq) bails in <2ms
#     for ALL non-git Bash calls (ls, cat, npm, curl, etc.) — ~95% of Bash calls
#   - jq + git queries only run when "git " substring is present
#   - Zero tokens injected (echo '{}') when not firing
#   - Max ~40 tokens injected when actually relevant

set -euo pipefail

input=$(cat)

# FAST PATH: raw string check on JSON input — bash substring is ~instant,
# avoids spawning jq for the 95%+ of Bash calls that aren't git.
case "$input" in
  *'"git '*) ;;
  *) echo '{}'; exit 0 ;;
esac

# SLOW PATH (git command detected): extract and inspect precisely
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
msg=""

# Concern 1: branch-modifying git op + multiple worktrees
if echo "$cmd" | grep -qE 'git (checkout|rebase|merge|cherry-pick|reset --hard|branch -[dD])'; then
  wt_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  if [ "${wt_count:-0}" -gt 1 ]; then
    msg="Multiple worktrees active. For NEW branch work prefer: git worktree add ~/code/<repo>-{slug} <ref>. NEVER use ~/Documents/GitHub/ — iCloud corrupts .git metadata. See .claude/rules/worktree-discipline.md."
  fi
fi

# Concern 2: git worktree add → stale lock scan (overrides concern 1 message)
if echo "$cmd" | grep -q 'git worktree add'; then
  stale=$(find .git -name "*.lock" -type f -mmin +10 2>/dev/null | head -3 | tr '\n' ' ')
  if [ -n "$stale" ]; then
    msg="Stale git locks (>10min): $stale. Remove before 'git worktree add' to avoid silent hang."
  fi
fi

if [ -z "$msg" ]; then
  echo '{}'
else
  jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
fi
