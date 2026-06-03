#!/usr/bin/env bash
# setup-claude-memory.sh — One-time per-machine setup
#
# Purpose: Symlink Claude's per-project memory dir to this repo's agency/memory/
# so memory persists across machines via git (no manual sync needed).
#
# Usage: cd <repo-root> && bash bin/setup-claude-memory.sh
# Idempotent: safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_MEMORY="$REPO_ROOT/agency/memory"

# Compute Claude's project memory dir name from the repo path.
# Claude encodes the path as "-" + slashes-replaced + "-" suffix.
# Example: /Users/{user}/Documents/GitHub/{Your Project Name}
#   →      -Users-{user}-Documents-GitHub-{Your-Project-Name}
ENCODED="$(echo "$REPO_ROOT" | sed 's|/|-|g; s| |-|g')"
CLAUDE_PROJECT_DIR="$HOME/.claude/projects/$ENCODED"
USER_MEMORY="$CLAUDE_PROJECT_DIR/memory"

echo "[setup] repo-root=$REPO_ROOT"
echo "[setup] repo-memory=$REPO_MEMORY"
echo "[setup] user-memory=$USER_MEMORY"

# Verify repo memory exists
if [ ! -d "$REPO_MEMORY" ]; then
  echo "[setup] ERROR: $REPO_MEMORY does not exist. Have you pulled latest main?"
  exit 1
fi

mkdir -p "$CLAUDE_PROJECT_DIR"

# If symlink already correct, exit clean
if [ -L "$USER_MEMORY" ] && [ "$(readlink "$USER_MEMORY")" = "$REPO_MEMORY" ]; then
  echo "[setup] Symlink already correct. Done."
  exit 0
fi

# If user-memory exists as a regular dir (first-time on new Mac with prior memory), back up
if [ -d "$USER_MEMORY" ] && [ ! -L "$USER_MEMORY" ]; then
  BACKUP="${USER_MEMORY}.backup-$(date +%Y%m%d-%H%M%S)"
  echo "[setup] Backing up existing $USER_MEMORY → $BACKUP"
  mv "$USER_MEMORY" "$BACKUP"
fi

# If symlink exists pointing somewhere else, remove
if [ -L "$USER_MEMORY" ]; then
  echo "[setup] Removing stale symlink"
  rm "$USER_MEMORY"
fi

ln -s "$REPO_MEMORY" "$USER_MEMORY"
echo "[setup] Symlink created: $USER_MEMORY → $REPO_MEMORY"
echo "[setup] Done. Claude memory now lives in repo (git-tracked, cross-machine)."
