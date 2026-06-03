#!/bin/bash
# .claude/hooks/session-end-continuation-gate.sh
#
# StopHook — writes an auto-continuation file when the session ends with
# UNCOVERED work AND no continuation was written this session.
#
# Per /Users/justin/.claude/plans/bring-this-all-together-immutable-diffie.md
# Layer 1. Per .claude/rules/decide-dont-menu-extended.md Class A: silent
# auto-fire, no operator prompt, never commits/pushes/merges.
#
# Position in chain: runs AFTER session-summarizer.sh (which captures git
# state), BEFORE vault-capture.sh (which propagates artefacts to Obsidian).
# That ordering lets vault-capture pick up the auto-continuation we write
# without a second sync pass.
#
# UNCOVERED-WORK DEFINITION:
#   (a) `git status --porcelain` non-empty (uncommitted files), OR
#   (b) commits on the current branch not yet pushed to origin
#
# CONTINUATION-WRITTEN-THIS-SESSION DEFINITION:
#   Any *.md file under continuations/ modified in the last 6 hours.
#   6h is the single-Mac session-window heuristic — generous enough to
#   tolerate long sessions, tight enough to not skip the auto-write across
#   day boundaries.
#
# SAFETY FLOOR (per decide-dont-menu-extended.md Class C):
#   - NEVER commits the continuation file
#   - NEVER pushes
#   - NEVER merges
#   - NEVER deletes a worktree
#   - Only writes a single new file to the working tree
#   - Always exits 0 (Stop hooks must never block session exit)

set -uo pipefail   # NOT -e — keep going past per-step failures

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
CONTINUATIONS_DIR="$PROJECT_ROOT/continuations"
SESSIONS_DIR="$PROJECT_ROOT/.claude/sessions"

# Bail silently if we're not in a recognisable project
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT/.git" ]; then
  exit 0
fi

# ── Gate 1: is there uncovered work? ──────────────────────────────────────
GIT_DIRTY="$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | head -50)"
CURRENT_BRANCH="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

UNPUSHED_COUNT=0
if [ "$CURRENT_BRANCH" != "unknown" ] && [ "$CURRENT_BRANCH" != "HEAD" ]; then
  # @{upstream} may not exist on local-only branches — silently fall back to origin/main delta
  UNPUSHED_RAW="$(git -C "$PROJECT_ROOT" log --oneline "@{upstream}..HEAD" 2>/dev/null \
    || git -C "$PROJECT_ROOT" log --oneline "origin/main..HEAD" 2>/dev/null \
    || echo "")"
  if [ -n "$UNPUSHED_RAW" ]; then
    UNPUSHED_COUNT=$(printf '%s\n' "$UNPUSHED_RAW" | wc -l | tr -d ' ')
  fi
fi

DIRTY_COUNT=0
if [ -n "$GIT_DIRTY" ]; then
  DIRTY_COUNT=$(printf '%s\n' "$GIT_DIRTY" | wc -l | tr -d ' ')
fi

# Normalise to integer (shell-portability.md §6)
DIRTY_COUNT=$(printf '%s' "$DIRTY_COUNT" | tr -dc '0-9' | head -c 6); DIRTY_COUNT="${DIRTY_COUNT:-0}"
UNPUSHED_COUNT=$(printf '%s' "$UNPUSHED_COUNT" | tr -dc '0-9' | head -c 6); UNPUSHED_COUNT="${UNPUSHED_COUNT:-0}"

if [ "$DIRTY_COUNT" -eq 0 ] && [ "$UNPUSHED_COUNT" -eq 0 ]; then
  # Clean exit — nothing to capture
  exit 0
fi

# ── Gate 2: was a continuation written this session? ──────────────────────
# Look for any .md in continuations/ modified in the last 6 hours
if [ -d "$CONTINUATIONS_DIR" ]; then
  RECENT_CONTINUATION=$(find "$CONTINUATIONS_DIR" -maxdepth 1 -type f -name '*.md' \
    -mmin -360 2>/dev/null | head -1)
  if [ -n "$RECENT_CONTINUATION" ]; then
    # Operator (or this session) already wrote a continuation — respect that
    exit 0
  fi
fi

# ── Gate 3: trivial-session filter (defensive — even though spec says silent auto-fire) ──
# If the only uncommitted change is to .claude/sessions/ or other ephemeral
# session-state files, don't generate a continuation — those are the session-
# summariser's own writes, not load-bearing work.
NON_EPHEMERAL_DIRTY=$(printf '%s\n' "$GIT_DIRTY" \
  | grep -v -E '^\s*[A-Z?]+\s+\.claude/sessions/' \
  | grep -v -E '^\s*[A-Z?]+\s+\.claude/autovibe-state\.json' \
  | wc -l | tr -d ' ')
NON_EPHEMERAL_DIRTY=$(printf '%s' "$NON_EPHEMERAL_DIRTY" | tr -dc '0-9' | head -c 6); NON_EPHEMERAL_DIRTY="${NON_EPHEMERAL_DIRTY:-0}"

if [ "$NON_EPHEMERAL_DIRTY" -eq 0 ] && [ "$UNPUSHED_COUNT" -eq 0 ]; then
  exit 0
fi

# ── Write the auto-continuation ──────────────────────────────────────────
mkdir -p "$CONTINUATIONS_DIR"

TS_DATE=$(date +%Y-%m-%d)
TS_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "no-git")

# Derive branch-slug for filename (last 30 chars of branch, sanitised)
BRANCH_SLUG=$(printf '%s' "$CURRENT_BRANCH" \
  | tr '/' '-' \
  | tr -dc 'A-Za-z0-9-' \
  | tail -c 40)
BRANCH_SLUG="${BRANCH_SLUG:-unknown-branch}"

AUTO_FILE="$CONTINUATIONS_DIR/${TS_DATE}-AUTO-${BRANCH_SLUG}.md"

# Don't overwrite an existing auto file from earlier today on the same branch
if [ -f "$AUTO_FILE" ]; then
  # Append a timestamped suffix to ensure uniqueness
  AUTO_FILE="$CONTINUATIONS_DIR/${TS_DATE}-AUTO-${BRANCH_SLUG}-$(date +%H%M%S).md"
fi

# Capture commit list (last 10 today)
GIT_COMMITS=$(git -C "$PROJECT_ROOT" log --oneline --since="${TS_DATE} 00:00" 2>/dev/null | head -10)
[ -z "$GIT_COMMITS" ] && GIT_COMMITS="(no commits this session)"

# Capture unpushed commits (truncated)
UNPUSHED_LIST=""
if [ "$UNPUSHED_COUNT" -gt 0 ]; then
  UNPUSHED_LIST=$(git -C "$PROJECT_ROOT" log --oneline "@{upstream}..HEAD" 2>/dev/null \
    || git -C "$PROJECT_ROOT" log --oneline "origin/main..HEAD" 2>/dev/null \
    || echo "(unable to enumerate)")
fi

# Capture dirty file list (truncated to 30)
DIRTY_LIST=$(printf '%s\n' "$GIT_DIRTY" | head -30)

cat > "$AUTO_FILE" <<EOF
---
title: "Auto-continuation — ${CURRENT_BRANCH} (${TS_DATE})"
type: auto-continuation
auto_generated: true
impl_status: pending
impl_session: ${GIT_HASH}
impl_completed_date:
branch: ${CURRENT_BRANCH}
session_end_utc: ${TS_UTC}
dirty_file_count: ${DIRTY_COUNT}
unpushed_commit_count: ${UNPUSHED_COUNT}
entities: []
---

# Auto-continuation — ${CURRENT_BRANCH}

**Generated**: ${TS_UTC} (auto-fired by 📄 \`.claude/hooks/session-end-continuation-gate.sh\`)
**Branch**: \`${CURRENT_BRANCH}\` at commit \`${GIT_HASH}\`
**Trigger**: session ended with uncovered work and no continuation was written manually.

Per 📄 \`.claude/rules/decide-dont-menu-extended.md\` Class A + 📄 \`/Users/justin/.claude/plans/bring-this-all-together-immutable-diffie.md\` Layer 1: this file is silent auto-fire. **Nothing was committed, pushed, or merged.** Only this file was written to the working tree.

---

## What's loose

**Uncommitted files (${DIRTY_COUNT})**:

\`\`\`
${DIRTY_LIST}
\`\`\`

**Unpushed commits (${UNPUSHED_COUNT})**:

\`\`\`
${UNPUSHED_LIST}
\`\`\`

**Commits made this session**:

\`\`\`
${GIT_COMMITS}
\`\`\`

---

## Next-session pickup protocol

1. **Read the corresponding session summary** at 📄 \`.claude/sessions/SESSION-${TS_DATE}-${GIT_HASH}.md\` for context on what this session was doing
2. **Decide the disposition** of the uncommitted work:
   - If load-bearing → \`/ship quick\` to commit + push + open a PR
   - If experimental → \`git stash push -u -m "stash from auto-continuation ${TS_DATE}"\` to preserve and clear
   - If trivial → \`git restore .\` to discard
3. **Decide the disposition of this auto-continuation file**:
   - If the work was load-bearing AND a real continuation should be written → invoke \`/Master-Continuation-Prompt\` to author the proper handoff, then delete this auto-file
   - If the work was trivial / this auto-file is enough → leave it as-is (it will surface in \`/where\` until the branch is clean)
   - If false-positive (truly nothing to capture) → \`git restore --staged --worktree\` on this file and delete it

---

## Why this file exists

Per the operator's stated default: *"just do what is safest, most logical, most secure and is going to achieve the best result, now and going forward."* When a session ends with uncovered work, the safest path is to PRESERVE STATE VISIBILITY — a future you (or another chat) opens this worktree and immediately sees what was loose.

This file is the read-only audit trail. Nothing else is mutated.

---

## Strategic alignment

**ROADMAP items this advances**: state-coordination floor — composes with the worktree-discipline + multi-session-arc-coordination doctrine.
**ROADMAP items this rejects**: none — this is observational infrastructure, not feature work.
**If this advances nothing**: that's a sign the session was trivial-but-dirty (e.g., an exploratory grep left files modified). In that case, delete this file in the next session and proceed.

---

*Auto-fired by \`.claude/hooks/session-end-continuation-gate.sh\`. Forward-only from 2026-05-24.*
EOF

# Silent success — exit 0 always
exit 0
