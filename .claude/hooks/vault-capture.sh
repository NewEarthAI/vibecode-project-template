#!/bin/bash
# .claude/hooks/vault-capture.sh
#
# Stop hook — captures session summary into Obsidian vault daily note.
# Runs AFTER session-summarizer.sh (depends on its output).
#
# Edge case defenses (from council 2026-04-13):
#   1. Atomic append (>>) not overwrite (>)
#   2. All paths double-quoted (vault path has a space)
#   3. mkdir-based file locking for parallel session safety (macOS compatible)
#   4. Exit 0 always — never block session end
#   5. Missing config = visible warning to stderr
#   6. Content tagged #auto-capture
#   7. Cold start counter

# Never block session end, no matter what — clean up lock on any exit
LOCK_DIR="/tmp/vault-capture.lock.d"
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; exit 0; }
trap cleanup ERR EXIT

set -u

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.claude/obsidian-second-brain.local.md"
SESSIONS_DIR="$PROJECT_ROOT/.claude/sessions"

TODAY=$(date +%Y-%m-%d)
NOW=$(date +%H:%M)

# ── Read vault config ──────────────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    echo "VAULT CAPTURE SKIPPED: No config at $CONFIG_FILE" >&2
    exit 0
fi

# Extract vault_path from YAML frontmatter
VAULT_PATH=$(awk '/^---$/{if(++c==2) exit} c==1 && /vault_path:/{gsub(/.*vault_path:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$CONFIG_FILE")

if [ -z "$VAULT_PATH" ]; then
    echo "VAULT CAPTURE SKIPPED: No vault_path in config" >&2
    exit 0
fi

if [ ! -d "$VAULT_PATH" ]; then
    echo "VAULT CAPTURE SKIPPED: Vault directory not found: $VAULT_PATH" >&2
    exit 0
fi

# ── Find session summary ──────────────────────────────────────────────────
GIT_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "no-git")
SESSION_FILE="$SESSIONS_DIR/SESSION-${TODAY}-${GIT_HASH}.md"

# Fall back to most recent session file if exact match not found
if [ ! -f "$SESSION_FILE" ]; then
    SESSION_FILE=$(ls -t "$SESSIONS_DIR"/SESSION-${TODAY}-*.md 2>/dev/null | head -1 || echo "")
fi

if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then
    echo "VAULT CAPTURE SKIPPED: No session summary found for $TODAY" >&2
    exit 0
fi

# ── Extract content from session summary ──────────────────────────────────
# Pull key sections — use [^W]/[^C] to stop at NEXT heading, not self
WORK_COMPLETED=$(awk '/^## Work Completed/,/^## [^W]/' "$SESSION_FILE" | grep -v "^## " | sed '/^$/d' | head -20 || true)
COMMITS=$(awk '/^## Commits Today/,/^## [^C]/' "$SESSION_FILE" | grep -v "^## " | sed '/^$/d' | head -10 || true)
BRANCH=$(awk '/^- Branch:/{print $3}' "$SESSION_FILE" | head -1 || true)
GIT_STATE_LINE=$(grep -E "(Clean|WARNING|uncommitted)" "$SESSION_FILE" | head -1 || true)

# Get project name from the repo directory
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# ── Build vault block ─────────────────────────────────────────────────────
VAULT_BLOCK="## Session ${NOW} — ${GIT_HASH} (${PROJECT_NAME})
#session #auto-capture #project/${PROJECT_NAME// /-}

### Work Completed
${WORK_COMPLETED:-No progress log for this session.}

### Commits
${COMMITS:-No commits this session.}

### Git State
- Branch: ${BRANCH:-unknown}
${GIT_STATE_LINE:+- ${GIT_STATE_LINE}}
"

# ── Write to vault daily note (with mkdir-based lock) ─────────────────────
# Per-user daily folder (NS-1, council 2026-05-10): daily/{user}/YYYY-MM-DD.md
# Avoids guaranteed merge conflict when both users edit "the daily note" on
# the same date. Falls back to "unknown" on the rare path where $USER is unset
# (defensive — keeps stray content out of either user's folder).
USER_SLUG="${USER:-unknown}"
DAILY_DIR="$VAULT_PATH/daily/$USER_SLUG"
DAILY_FILE="$DAILY_DIR/${TODAY}.md"

# Ensure daily directory exists
mkdir -p "$DAILY_DIR"

# Dedup: skip if this git hash was already captured in today's daily note
if [ -f "$DAILY_FILE" ] && grep -q "## Session.*${GIT_HASH}" "$DAILY_FILE" 2>/dev/null; then
    exit 0
fi

# mkdir is atomic on POSIX — exactly one process wins the race (macOS has no flock)
# LOCK_DIR defined at top level for cleanup trap
LOCK_ACQUIRED=false
for i in 1 2 3 4 5; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        LOCK_ACQUIRED=true
        break
    fi
    sleep 1
done

if [ "$LOCK_ACQUIRED" = false ]; then
    # Stale lock? Force remove if older than 30s
    if [ -d "$LOCK_DIR" ]; then
        LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo "0") ))
        if [ "$LOCK_AGE" -gt 30 ]; then
            rmdir "$LOCK_DIR" 2>/dev/null || true
            mkdir "$LOCK_DIR" 2>/dev/null && LOCK_ACQUIRED=true
        fi
    fi
fi

if [ "$LOCK_ACQUIRED" = false ]; then
    echo "VAULT CAPTURE: Could not acquire lock after 5 retries" >&2
    exit 0
fi

# Create daily note with frontmatter if it doesn't exist
if [ ! -f "$DAILY_FILE" ]; then
    cat > "$DAILY_FILE" << FRONTMATTER
---
tags:
  - daily
created: ${TODAY}
---

# ${TODAY}

FRONTMATTER
fi

# Atomic append — never overwrites existing content
printf '\n---\n\n%s\n' "$VAULT_BLOCK" >> "$DAILY_FILE"

# Release lock
rmdir "$LOCK_DIR" 2>/dev/null || true

# ── Git commit in vault (non-blocking) ────────────────────────────────────
if [ -d "$VAULT_PATH/.git" ]; then
    (
        cd "$VAULT_PATH"
        git add "daily/${USER_SLUG}/${TODAY}.md" 2>/dev/null || true
        git commit -m "auto-capture: session ${NOW} from ${PROJECT_NAME}" --no-gpg-sign 2>/dev/null || true
    ) || {
        # Git failure is a warning, not fatal — append note to daily file
        printf '\n> **Warning**: Git commit failed for this capture.\n' >> "$DAILY_FILE" 2>/dev/null || true
    }
fi

# ── Cold start counter ────────────────────────────────────────────────────
NOTE_COUNT=$(find "$VAULT_PATH/daily" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$NOTE_COUNT" -lt 14 ]; then
    echo "Vault: ${NOTE_COUNT} daily notes. /drift unlocks at ~14." >&2
fi

# ── Trigger vault-sync at session end (Gap-5+ extension 2026-05-15) ───────
# SessionStart fires vault-sync at session open; this Stop hook fires it
# again at session close. Together: writes that happen DURING a session
# (Claude creating vault notes, manual edits in Obsidian mid-session)
# reach the agency database within seconds of the session ending — instead
# of waiting until the next session open. Non-blocking; silent on failure.
REPO_ROOT_FOR_SYNC="$(cd "$(dirname "$CONFIG_FILE")/.." && pwd)"
if [ -x "$REPO_ROOT_FOR_SYNC/bin/vault-sync.sh" ]; then
    (
        nohup bash "$REPO_ROOT_FOR_SYNC/bin/vault-sync.sh" >/dev/null 2>&1 &
    ) >/dev/null 2>&1
fi

exit 0
