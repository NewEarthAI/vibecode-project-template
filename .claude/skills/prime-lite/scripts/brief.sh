#!/usr/bin/env bash
# prime-lite/brief.sh — lightweight repo-state briefing for orchestrators
# Budget: <1500 words, <3 seconds, read-only
# Exit codes: always 0 (briefing skill, not a gate). Warnings go to stderr.

set -uo pipefail

CWD="$(pwd)"
TRUNC_LIMIT=20  # head -N cap for any list section

# 1. CWD + worktree health warning (stderr only — preflight.sh enforces)
echo "## Repo State Briefing"
echo ""
echo "**CWD:** \`$CWD\`"
case "$CWD" in
  *Documents/GitHub*|*iCloud*|*OneDrive*|*Dropbox*|/tmp/*)
    echo "WARNING: cwd in cloud-synced or temp path — git metadata corruption risk" >&2
    echo ""
    echo "> WARNING: cwd in cloud-synced or temp path. preflight.sh would reject this."
    ;;
esac
echo ""

# 2. Branch + ahead-of-main + worktree root
BRANCH="$(git branch --show-current 2>/dev/null || echo 'detached')"
AHEAD="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"
WT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")"
echo "**Branch:** \`$BRANCH\` (commits ahead of origin/main: $AHEAD)"
echo "**Worktree root:** \`$WT_ROOT\`"
echo ""

# 3. Working-tree status
echo "### Working tree"
echo '```'
git status --porcelain 2>/dev/null | head -$TRUNC_LIMIT || echo "(no git status available)"
DIRTY_COUNT="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
if [ "$DIRTY_COUNT" -gt "$TRUNC_LIMIT" ]; then
  echo "... ($((DIRTY_COUNT - TRUNC_LIMIT)) more changes truncated)"
fi
echo '```'
echo ""

# 4. Recent commits
echo "### Recent commits"
echo '```'
git log --oneline -10 2>/dev/null || echo "(no git log available)"
echo '```'
echo ""

# 5. Worktree list
echo "### Worktrees"
echo '```'
git worktree list 2>/dev/null | head -$TRUNC_LIMIT || echo "(not a git repo)"
echo '```'
echo ""

# 6. Recent council sessions
if [ -d "council/sessions" ]; then
  echo "### Recent council sessions"
  echo '```'
  ls -t council/sessions/ 2>/dev/null | head -5
  echo '```'
  echo ""
fi

# 7. ROADMAP NOW section (first 30 lines)
if [ -f "specs/ROADMAP.md" ]; then
  echo "### ROADMAP (first 30 lines)"
  echo '```'
  head -30 specs/ROADMAP.md
  echo '```'
  echo ""
fi

# 8. Recent specs
if [ -d "specs" ]; then
  echo "### Recent specs"
  echo '```'
  ls -t specs/*.md 2>/dev/null | head -5 | xargs -n1 basename
  echo '```'
  echo ""
fi

exit 0
