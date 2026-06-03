#!/bin/bash
# Claude Code PreToolUse hook — Pre-commit quality gate
# Detects git commit commands and checks staged files for:
#   - Debug artifacts (console.log, debugger, TODO-REMOVE)
#   - Staged .env files (credential leak risk)
#   - Staged large files (>1MB, likely accidental)
#
# Exit codes:
#   0 = permit (proceed normally or not a git commit)
#   2 = block (issues found in staged files)
#
# Token cost: 0 on permit, ~30 on block (only the JSON reason)
# Usage: registered in .claude/settings.local.json under hooks.PreToolUse

set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Anchor cwd to repo root (hooks may run from any subprocess cwd)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT"

# Read tool input from stdin
TOOL_INPUT=$(cat)

# Extract tool name and command
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Only inspect Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Only inspect git commit commands
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

# ── Check 1: Debug artifacts in staged JS/TS files ──
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [[ -z "$STAGED" ]]; then
  exit 0
fi

DEBUG_ISSUES=""
while IFS= read -r file; do
  if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]] && [[ -f "$file" ]]; then
    # Only check ADDED lines (+ prefix) in staged diff
    FOUND=$(git diff --cached -- "$file" 2>/dev/null | grep -nE '^\+.*\b(console\.log|debugger|TODO.REMOVE)\b' | head -3 || true)
    if [[ -n "$FOUND" ]]; then
      DEBUG_ISSUES="${DEBUG_ISSUES}  ${file}: $(echo "$FOUND" | head -1 | sed 's/^\+//')\n"
    fi
  fi
done <<< "$STAGED"

if [[ -n "$DEBUG_ISSUES" ]]; then
  echo "{\"decision\":\"block\",\"reason\":\"Debug artifacts in staged files. Remove before committing:\\n${DEBUG_ISSUES}\"}" >&2
  exit 2
fi

# ── Check 2: .env files staged (credential exposure) ──
ENV_FILES=$(echo "$STAGED" | grep -E '\.env($|\.)' || true)
if [[ -n "$ENV_FILES" ]]; then
  echo "{\"decision\":\"block\",\"reason\":\".env file staged for commit: ${ENV_FILES}. This may expose credentials. Run: git reset HEAD ${ENV_FILES}\"}" >&2
  exit 2
fi

# ── Check 3: Large files staged (>1MB, likely accidental) ──
LARGE_FILES=""
while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    SIZE=$(wc -c < "$file" 2>/dev/null | tr -d ' ' || echo "0")
    if [[ "$SIZE" -gt 1048576 ]]; then
      SIZE_MB=$(echo "scale=1; $SIZE / 1048576" | bc 2>/dev/null || echo "?")
      LARGE_FILES="${LARGE_FILES}  ${file} (${SIZE_MB}MB)\n"
    fi
  fi
done <<< "$STAGED"

if [[ -n "$LARGE_FILES" ]]; then
  echo "{\"decision\":\"block\",\"reason\":\"Large files staged (>1MB). Likely accidental:\\n${LARGE_FILES}Unstage with: git reset HEAD <file>\"}" >&2
  exit 2
fi

# PERMIT: commit looks clean
exit 0
