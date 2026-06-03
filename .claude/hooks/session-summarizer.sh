#!/bin/bash
# .claude/hooks/session-summarizer.sh
#
# StopHook — writes a session summary at end of every Claude Code session.
# Registered in .claude/settings.local.json under hooks.Stop.
#
# Outputs:
#   .claude/sessions/SESSION-{date}-{hash}.md  — session summary
#   .claude/sessions/session-state.env          — cross-session flags

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSIONS_DIR="$PROJECT_ROOT/.claude/sessions"
ROADMAP_FILE="$PROJECT_ROOT/ROADMAP.md"
STATE_FILE="$SESSIONS_DIR/session-state.env"

TODAY=$(date +%Y-%m-%d)
NOW=$(date +%H:%M)

# ── Ensure sessions directory exists ───────────────────────────────────────
mkdir -p "$SESSIONS_DIR"

# ── Initialize session-state.env if it doesn't exist ──────────────────────
if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" << INIT
# Session state — cross-session flags
# Updated by session-summarizer.sh, read by daily-plan-generator
CLIENTUPDATE_PENDING=false
INIT
fi

# ── Git hash ───────────────────────────────────────────────────────────────
GIT_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "no-git")
SESSION_FILE="$SESSIONS_DIR/SESSION-${TODAY}-${GIT_HASH}.md"

# ── Read today's progress log ──────────────────────────────────────────────
PROGRESS_FILE="$SESSIONS_DIR/claude-progress-${TODAY}.md"
MUTATION_COUNT=0
PROGRESS_SECTION=""

if [ -f "$PROGRESS_FILE" ]; then
    MUTATION_COUNT=$(grep -c "^## " "$PROGRESS_FILE" 2>/dev/null || echo "0")
    PROGRESS_SECTION=$(cat "$PROGRESS_FILE")
else
    PROGRESS_SECTION="No progress log found for this session."
fi

# ── Git commits today ──────────────────────────────────────────────────────
GIT_COMMITS=$(git -C "$PROJECT_ROOT" log --oneline --since="${TODAY} 00:00" 2>/dev/null | head -10 || echo "")
if [ -z "$GIT_COMMITS" ]; then
    GIT_COMMITS="No commits today."
fi

# ── Git state verification ────────────────────────────────────────────
GIT_DIRTY=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | head -20 || echo "")
GIT_UNPUSHED=""
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [[ "$CURRENT_BRANCH" != "unknown" ]]; then
    GIT_UNPUSHED=$(git -C "$PROJECT_ROOT" log --oneline "@{upstream}..HEAD" 2>/dev/null | head -5 || echo "")
fi

GIT_STATE_WARNING=""
if [[ -n "$GIT_DIRTY" ]]; then
    DIRTY_COUNT=$(echo "$GIT_DIRTY" | wc -l | tr -d ' ')
    GIT_STATE_WARNING="WARNING: ${DIRTY_COUNT} uncommitted change(s) at session end."
fi

UNPUSHED_WARNING=""
if [[ -n "$GIT_UNPUSHED" ]]; then
    UNPUSHED_COUNT=$(echo "$GIT_UNPUSHED" | wc -l | tr -d ' ')
    UNPUSHED_WARNING="NOTE: ${UNPUSHED_COUNT} unpushed commit(s) on ${CURRENT_BRANCH}."
fi

# ── ROADMAP health ─────────────────────────────────────────────────────────
ROADMAP_LINES=0
ROADMAP_WARNING=""
NEXT_ITEMS=""

if [ -f "$ROADMAP_FILE" ]; then
    ROADMAP_LINES=$(wc -l < "$ROADMAP_FILE" | tr -d ' ')
    if [ "$ROADMAP_LINES" -gt 550 ]; then
        ROADMAP_WARNING="ROADMAP.md is ${ROADMAP_LINES} lines. Run /compress-roadmap."
    fi

    # Extract top 3 NEXT lane items (### headings after ## NEXT, before ## LATER)
    NEXT_ITEMS=$(awk '/^## NEXT/{found=1; next} /^## LATER/{found=0} found && /^### /{gsub(/^### /,""); gsub(/ \[.*/,""); print NR": "$0}' "$ROADMAP_FILE" 2>/dev/null | head -3 || echo "")
fi

# ── Session file count warning ─────────────────────────────────────────────
SESSION_COUNT=$(ls "$SESSIONS_DIR"/SESSION-*.md 2>/dev/null | wc -l | tr -d ' ' || echo "0")
SESSION_WARNING=""
if [ "$SESSION_COUNT" -gt 14 ]; then
    SESSION_WARNING="${SESSION_COUNT} session files. Consider archiving older ones."
fi

# ── /clientprojectupdate auto-trigger check ────────────────────────────────
# Fires when ANY ROADMAP has milestone completions (~~strikethrough~~, COMPLETE, DONE, [x])
# Scans root + sub-project ROADMAPs (customize ROADMAP_FILES for your repo)
CLIENT_UPDATE_NOTE=""
ROADMAP_CHANGED=0

# Find all ROADMAP.md files in the repo (root + subdirectories)
ROADMAP_FILES=$(git -C "$PROJECT_ROOT" ls-files '*.md' 2>/dev/null | grep -i 'ROADMAP\.md$' || echo "ROADMAP.md")
for RFILE in $ROADMAP_FILES; do
    if git -C "$PROJECT_ROOT" diff HEAD~1 HEAD -- "$RFILE" >/dev/null 2>&1; then
        FILE_CHANGES=$(git -C "$PROJECT_ROOT" diff HEAD~1 HEAD -- "$RFILE" 2>/dev/null \
            | grep -cE "^\+.*(COMPLETE|DONE|\[x\])" || true)
        ROADMAP_CHANGED=$((ROADMAP_CHANGED + FILE_CHANGES))
    fi
done

if [ "$ROADMAP_CHANGED" -gt 0 ]; then
    # Update session-state.env (idempotent)
    if [ -f "$STATE_FILE" ]; then
        grep -v "CLIENTUPDATE_PENDING" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
        mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
    fi
    echo "CLIENTUPDATE_PENDING=true" >> "$STATE_FILE"
    CLIENT_UPDATE_NOTE="/clientprojectupdate auto-triggered (${ROADMAP_CHANGED} milestone change(s) in ROADMAP)"
fi

# ── Write session summary ──────────────────────────────────────────────────
cat > "$SESSION_FILE" << SUMMARY
# Session — ${TODAY} ${NOW}
**Git hash**: ${GIT_HASH}
**Mutations logged**: ${MUTATION_COUNT}

## Work Completed

${PROGRESS_SECTION}

## Commits Today

${GIT_COMMITS}

## Next Session Priorities (from ROADMAP NEXT lane)

${NEXT_ITEMS:-"Check ROADMAP.md directly."}

## Git State at Session End
- Branch: ${CURRENT_BRANCH}
${GIT_DIRTY:+- Uncommitted changes:\n${GIT_DIRTY}}
${GIT_UNPUSHED:+- Unpushed commits:\n${GIT_UNPUSHED}}
${GIT_STATE_WARNING:+- ${GIT_STATE_WARNING}}
${UNPUSHED_WARNING:+- ${UNPUSHED_WARNING}}
${GIT_DIRTY:-${GIT_UNPUSHED:-- Clean (all committed and pushed)}}

## Context Health
- ROADMAP.md: ${ROADMAP_LINES} lines${ROADMAP_WARNING:+ — ${ROADMAP_WARNING}}
${SESSION_WARNING:+- ${SESSION_WARNING}}
${CLIENT_UPDATE_NOTE:+- ${CLIENT_UPDATE_NOTE}}

---
*Generated by session-summarizer.sh at ${NOW}*
SUMMARY

exit 0
