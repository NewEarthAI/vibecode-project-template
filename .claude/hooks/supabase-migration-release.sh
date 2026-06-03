#!/usr/bin/env bash
# supabase-migration-release.sh — PostToolUse hook
# Matcher: mcp__supabase-*__apply_migration + mcp__supabase-*__execute_sql
#
# Releases the migration-lock acquired by supabase-migration-guard.sh.
# Always exits clean — never blocks post-hoc.
#
# Installed 2026-04-20 after CM.32 T3-5 incident.

set -euo pipefail

LOCK_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/.supabase-migration-lock"
METADATA_FILE="$LOCK_DIR/metadata.json"
# SESSION_ID formula MUST match supabase-migration-guard.sh EXACTLY.
# Mismatch = release never matches holder = locks never release (10-min TTL stale).
SESSION_ID="${CLAUDE_SESSION_ID:-claude-ppid-$PPID}"

# Only release if WE hold the lock (session_id match)
if [ -f "$METADATA_FILE" ]; then
  holder=$(jq -r '.session_id // ""' "$METADATA_FILE" 2>/dev/null || echo "")
  if [ "$holder" = "$SESSION_ID" ]; then
    rm -rf "$LOCK_DIR" 2>/dev/null || true
  fi
fi

echo '{}'
exit 0
