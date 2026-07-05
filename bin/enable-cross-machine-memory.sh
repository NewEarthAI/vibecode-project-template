#!/usr/bin/env bash
# enable-cross-machine-memory.sh — One-time activation on the FIRST Mac only.
#
# Activates the SessionStart hook that auto-creates the memory symlink on
# every Mac going forward. After running this script + committing + pushing,
# every other Mac just needs `git pull origin main` and to open a Claude
# session — symlink auto-creates from the SessionStart hook, no manual setup.
#
# What this script does:
#   1. Copies .claude/settings.json.suggested → .claude/settings.json
#      (settings.json is checked-in agent config — Claude itself is blocked
#      from writing it directly; that's why this is a human-run script)
#   2. Stages the change for git
#   3. Prints the commit + push commands (does NOT auto-push — keeps
#      destructive remote ops behind explicit user confirmation)
#
# Usage: cd <repo-root> && bash bin/enable-cross-machine-memory.sh
# Idempotent: safe to re-run; skips work if already activated.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/.claude/settings.json.suggested"
TARGET="$REPO_ROOT/.claude/settings.json"

if [ ! -f "$TEMPLATE" ]; then
  echo "[activate] ERROR: $TEMPLATE missing. Have you pulled latest main?"
  exit 1
fi

if [ -f "$TARGET" ]; then
  if cmp -s "$TEMPLATE" "$TARGET"; then
    echo "[activate] Already activated (settings.json identical to suggested)."
    echo "[activate] If not committed yet: git add .claude/settings.json && git commit -m 'feat(memory): cross-machine SessionStart hook' && git push origin main"
    exit 0
  fi
  echo "[activate] WARNING: $TARGET already exists with different content."
  echo "[activate] Manual merge required. Compare:"
  echo "          diff $TEMPLATE $TARGET"
  echo "[activate] Then merge the SessionStart hook block from .suggested into your existing settings.json."
  exit 2
fi

cp "$TEMPLATE" "$TARGET"
echo "[activate] Created $TARGET"
echo
echo "Next steps (paste each line):"
echo "  cd \"$REPO_ROOT\""
echo "  git add .claude/settings.json"
echo "  git commit -m 'feat(memory): cross-machine SessionStart hook activates symlink auto-setup'"
echo "  git push origin main"
echo
echo "After push: every other Mac runs ONLY 'git pull origin main' + opens Claude. Symlink auto-creates."
