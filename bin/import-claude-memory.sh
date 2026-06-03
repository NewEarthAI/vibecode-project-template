#!/usr/bin/env bash
# import-claude-memory.sh — Run on a Mac BEFORE bin/setup-claude-memory.sh
#
# Purpose: Pull this machine's existing Claude memory dir INTO the repo's
# agency/memory/ so nothing is lost when the symlink swap happens.
#
# Workflow on a NEW Mac that already has memory:
#   1. git clone + git fetch origin main + git pull
#   2. bash bin/import-claude-memory.sh    ← THIS SCRIPT (uploads existing)
#   3. Review `git status agency/memory/` + git diff agency/memory/
#   4. git add agency/memory/ && git commit -m "..." && git push origin main
#   5. bash bin/setup-claude-memory.sh    ← symlink swap (safe now)
#
# Conflict handling: if a file exists in BOTH user-memory and repo-memory with
# different content, this script preserves the conflicting incoming version as
# <file>.othermac-conflict-<timestamp> for manual review. Repo version stays
# the canonical default. User decides which content survives via git add.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_MEMORY="$REPO_ROOT/agency/memory"

ENCODED="$(echo "$REPO_ROOT" | sed 's|/|-|g; s| |-|g')"
USER_MEMORY="$HOME/.claude/projects/$ENCODED/memory"

echo "[import] repo-memory=$REPO_MEMORY"
echo "[import] user-memory=$USER_MEMORY"

if [ ! -d "$USER_MEMORY" ] || [ -L "$USER_MEMORY" ]; then
  echo "[import] No user-memory dir to import (either missing or already symlinked). Nothing to do."
  exit 0
fi

if [ ! -d "$REPO_MEMORY" ]; then
  echo "[import] ERROR: $REPO_MEMORY missing. Have you pulled latest main?"
  exit 1
fi

mkdir -p "$REPO_MEMORY"

TS="$(date +%Y%m%d-%H%M%S)"
ADDED=0
CONFLICTS=0
SAME=0

# Walk user-memory and process each file
while IFS= read -r -d '' src; do
  rel="${src#$USER_MEMORY/}"
  dst="$REPO_MEMORY/$rel"

  if [ ! -e "$dst" ]; then
    # New file — copy in
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    ADDED=$((ADDED+1))
    echo "  + $rel"
  elif cmp -s "$src" "$dst"; then
    # Identical — skip
    SAME=$((SAME+1))
  else
    # Conflict — preserve user version with suffix for review
    conflict_path="$dst.othermac-conflict-$TS"
    cp -p "$src" "$conflict_path"
    CONFLICTS=$((CONFLICTS+1))
    echo "  ⚠ CONFLICT: $rel (preserved as $rel.othermac-conflict-$TS)"
  fi
done < <(find "$USER_MEMORY" -type f -print0)

echo
echo "[import] Summary: added=$ADDED, identical=$SAME, conflicts=$CONFLICTS"

if [ "$ADDED" -gt 0 ] || [ "$CONFLICTS" -gt 0 ]; then
  echo
  echo "Next steps:"
  echo "  1. Review changes: cd $REPO_ROOT && git status agency/memory/"
  if [ "$CONFLICTS" -gt 0 ]; then
    echo "  2. Resolve conflicts: diff <file> <file.othermac-conflict-$TS> — pick winner, delete other"
  fi
  echo "  3. git add agency/memory/ && git commit -m \"chore(memory): import from <machine-name>\" && git push origin main"
  echo "  4. bash bin/setup-claude-memory.sh    ← symlink swap (safe now)"
else
  echo
  echo "Nothing new to import. Safe to run bin/setup-claude-memory.sh directly."
fi
