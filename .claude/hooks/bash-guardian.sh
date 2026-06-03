#!/bin/bash
# Claude Code PreToolUse hook — Bash command guardian
# Blocks destructive bash patterns that should NEVER auto-execute.
# Complements sql-guardian.sh (SQL) — this covers shell commands.
#
# Exit codes:
#   0 = permit (proceed normally)
#   2 = block (hard stop — Claude Code will not execute the tool)
#
# Token cost: 0 on permit, ~20 on block (only the JSON reason)
# Usage: registered in .claude/settings.local.json under hooks.PreToolUse

set -euo pipefail

# Read tool input from stdin
TOOL_INPUT=$(cat)

# Extract tool name and command
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Only inspect Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# Extract run_in_background flag
RUN_BG=$(echo "$TOOL_INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null || echo "false")

# Skip empty commands
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# ── CONTEXT: git command CWD verification ──
# Outputs CWD + remote as informational context (exit 0 = proceed, stdout = feedback to Claude)
# Prevents wrong-directory git operations
if echo "$COMMAND" | grep -qE '^\s*git\s'; then
  CWD=$(pwd)
  REMOTE=$(git remote get-url origin 2>/dev/null || echo "not a git repo")
  REPO_NAME=$(basename "$CWD")
  echo "GIT CWD CHECK | repo: $REPO_NAME | dir: $CWD | remote: $REMOTE"
fi

# ── PERMIT: agent-browser commands (E2E testing, browser automation) ──
if echo "$COMMAND" | grep -qE '^agent-browser\s'; then
  exit 0
fi

# ── BLOCK: git working-tree commands run in background ──
# Parallel background git commands can create zombie processes,
# corrupt the index, and push broken trees to remote.
if [[ "$RUN_BG" == "true" ]] && echo "$COMMAND" | grep -qE 'git\s+(status|diff|add|commit|reset|read-tree|rm|checkout|stash|merge|rebase|index-pack)\b'; then
  echo '{"decision":"block","reason":"Git working-tree commands MUST NOT run in background. Parallel git processes corrupt the index and create zombies. Run git commands sequentially in foreground."}'
  exit 2
fi

# ── BLOCK: git status -uall (memory explosion on large repos) ──
if echo "$COMMAND" | grep -qE 'git\s+status\s+.*-uall'; then
  echo '{"decision":"block","reason":"git status -uall blocked. This flag causes memory issues on large repos. Use git status without -uall."}'
  exit 2
fi

# ── BLOCK: rm with recursive + force flags ──
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\s+--force|-[a-zA-Z]*f[a-zA-Z]*r)\b'; then
  echo '{"decision":"block","reason":"Recursive force delete blocked. This is irreversible. Use a targeted rm command without combined -rf flags."}'
  exit 2
fi

# ── BLOCK: git push --force (overwrites remote history) ──
# Covers: --force, -f, -fu (combined force + set-upstream), -uf, etc.
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+.*-[a-zA-Z]*f[a-zA-Z]*\b'; then
  echo '{"decision":"block","reason":"git push --force blocked. Force-pushing overwrites remote history and can destroy collaborators work. Use git push without --force (works with -f, -fu, --force-with-lease variants)."}'
  exit 2
fi

# ── BLOCK: git reset --hard (discards uncommitted work) ──
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo '{"decision":"block","reason":"git reset --hard blocked. This discards all uncommitted changes irreversibly. Use git stash or git checkout for specific files instead."}'
  exit 2
fi

# ── BLOCK: git clean -f (deletes untracked files) ──
if echo "$COMMAND" | grep -qE 'git\s+clean\s+(-[a-zA-Z]*f|--force)'; then
  echo '{"decision":"block","reason":"git clean -f blocked. This permanently deletes untracked files. Review with git clean -n (dry run) first."}'
  exit 2
fi

# ── BLOCK: kill -9 / kill -KILL (unrecoverable process termination) ──
# Word-boundary anchored so `pkill -9` doesn't trip this — pkill is the
# intentional recovery tool (council 2026-04-11 — see pkill note below)
if echo "$COMMAND" | grep -qE '(^|[^a-zA-Z0-9_])kill\s+(-9|-KILL)\b'; then
  echo '{"decision":"block","reason":"kill -9 blocked. SIGKILL prevents graceful shutdown. Use kill (SIGTERM) first and only escalate if needed."}'
  exit 2
fi

# ── pkill / killall: INTENTIONALLY NOT BLOCKED (council 2026-04-11) ──
# Users typically have pkill recovery patterns in their allow list —
# forensic evidence that hook-induced hangs have happened and pkill is
# the escape hatch. Blocking pkill here would remove the only recovery
# path when a guardian hangs. kill -9 (above) remains blocked — it's
# narrower and less of a recovery pattern.

# ── BLOCK: .env file modification via bash ──
if echo "$COMMAND" | grep -qE '(>|>>|sed\s+-i|nano|vi|vim)\s+.*\.env\b'; then
  echo '{"decision":"block","reason":".env file modification blocked. Environment files contain credentials. Edit manually or use a dedicated secrets manager."}'
  exit 2
fi

# ── BLOCK: docker rm -f (force-removes containers) ──
if echo "$COMMAND" | grep -qE 'docker\s+rm\s+(-[a-zA-Z]*f|--force)'; then
  echo '{"decision":"block","reason":"docker rm -f blocked. Force-removing containers can disrupt running services. Stop the container first with docker stop."}'
  exit 2
fi

# ── BLOCK: chmod 777 (world-writable permissions) ──
if echo "$COMMAND" | grep -qE 'chmod\s+(-R\s+)?777\b'; then
  echo '{"decision":"block","reason":"chmod 777 blocked. World-writable permissions are a security risk. Use more restrictive permissions (755 for dirs, 644 for files)."}'
  exit 2
fi

# ── CONTEXT: chmod -R (recursive permission changes — non-777 variants) ──
if echo "$COMMAND" | grep -qE 'chmod\s+-R\b'; then
  echo "CHMOD -R detected. Verify the target directory is correct — recursive permission changes are hard to reverse."
fi

# ── CONTEXT: shell redirection to tracked files ──
# Warns when stdout redirection might overwrite important files (prefer Write/Edit tools)
if echo "$COMMAND" | grep -qE '>\s+[^/][^ ]+\.(ts|tsx|js|jsx|json|md|sql|sh|yaml|yml)\b' && \
   ! echo "$COMMAND" | grep -qE '>\s+/tmp/' && \
   ! echo "$COMMAND" | grep -qE '>\s+/dev/null'; then
  echo "Shell redirect to source file detected. Consider using Write/Edit tools instead for better traceability."
fi

# PERMIT: everything else
exit 0
