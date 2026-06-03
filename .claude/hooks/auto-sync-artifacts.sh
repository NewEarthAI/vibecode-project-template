#!/bin/bash
# .claude/hooks/auto-sync-artifacts.sh
#
# Stop hook — auto-commits and pushes metadata/artifact files to origin.
# Runs AFTER session-summarizer.sh so session logs are included.
#
# ONLY syncs non-code artifact paths. Source code changes remain explicit.
# Safe to run on every session end — no-ops if nothing changed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# ── Artifact paths to auto-sync (metadata only, never source code) ──
ARTIFACT_PATHS=(
  ".claude/memory/"
  ".claude/sessions/"
  ".claude/plans/"
  "continuations/"
  "specs/"
  "council/"
  "research-outputs/"
  "e2e-screenshots/"
  "docs/"
)

# ── Stage only artifact paths that have changes ──
STAGED=false
for path in "${ARTIFACT_PATHS[@]}"; do
  if [ -e "$path" ]; then
    # Add tracked + untracked files in this path
    git add "$path" 2>/dev/null || true
  fi
done

# ── Check if anything was staged ──
if git diff --cached --quiet 2>/dev/null; then
  # Nothing to commit — clean exit
  exit 0
fi

# ── Count what we're committing ──
FILE_COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# ── Commit with descriptive message ──
git commit -m "auto: sync ${FILE_COUNT} session artifact(s) [${TIMESTAMP}]

Paths: $(git diff --cached --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')$([ "$FILE_COUNT" -gt 5 ] && echo " (+$((FILE_COUNT - 5)) more)")

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>" \
  --quiet 2>/dev/null || {
    echo "auto-sync: commit failed (pre-commit hook?), skipping push"
    exit 0
  }

# ── Push to origin (best-effort, don't block session exit) ──
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
git push origin "$BRANCH" --quiet 2>/dev/null || {
  echo "auto-sync: push failed (network/auth), commit saved locally"
  exit 0
}

echo "auto-sync: committed and pushed ${FILE_COUNT} artifact(s) to origin/${BRANCH}"
exit 0
