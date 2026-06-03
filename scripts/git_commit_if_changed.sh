#!/usr/bin/env bash
# =============================================================================
# safe-bash task: git_commit_if_changed
# Commit only if normalized content hash actually differs from HEAD
# Usage: ./git_commit_if_changed.sh <file_path> <commit_message>
# =============================================================================
set -euo pipefail

FILE_PATH="${1:?Usage: $0 <file_path> <commit_message>}"
COMMIT_MSG="${2:?Usage: $0 <file_path> <commit_message>}"
AUDIT_LOG="${SAFE_BASH_AUDIT_LOG:-.claude/safe-bash-audit.jsonl}"

# --- Arg validation ---
if [[ "$FILE_PATH" =~ [\`\$\|\;\>\<\&\(\)] ]]; then
  echo "ERROR: Invalid characters in file_path" >&2
  exit 2
fi
if [ ! -f "$FILE_PATH" ]; then
  echo "ERROR: File not found: $FILE_PATH" >&2
  exit 2
fi

START_MS=$(($(date +%s) * 1000))

# --- Compute normalized hashes ---
# For JSON files, use jq canonical normalization; otherwise use raw content
EXT="${FILE_PATH##*.}"
if [ "$EXT" = "json" ]; then
  NEW_HASH=$(jq -S '.' "$FILE_PATH" 2>/dev/null | sha256sum | cut -d' ' -f1)
  OLD_HASH=$(git show "HEAD:${FILE_PATH}" 2>/dev/null | jq -S '.' 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "none")
else
  NEW_HASH=$(sha256sum "$FILE_PATH" | cut -d' ' -f1)
  OLD_HASH=$(git show "HEAD:${FILE_PATH}" 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "none")
fi

END_MS=$(($(date +%s) * 1000))
DURATION=$((END_MS - START_MS))

if [ "$NEW_HASH" = "$OLD_HASH" ]; then
  echo "NO CHANGE: ${FILE_PATH} hash unchanged (${NEW_HASH:0:12}...)"

  mkdir -p "$(dirname "$AUDIT_LOG")"
  cat >> "$AUDIT_LOG" <<AUDIT_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","task":"git_commit_if_changed","args":["${FILE_PATH}"],"cwd":"$(pwd)","exit_code":0,"action":"skip","old_hash":"${OLD_HASH}","new_hash":"${NEW_HASH}","duration_ms":${DURATION}}
AUDIT_EOF
  exit 0
fi

# --- Stage and commit ---
git add "$FILE_PATH"
git commit -m "$COMMIT_MSG

Co-Authored-By: safe-bash <noreply@dispodaddy.dev>"

POST_HASH=$(git show "HEAD:${FILE_PATH}" 2>/dev/null | sha256sum | cut -d' ' -f1)

mkdir -p "$(dirname "$AUDIT_LOG")"
cat >> "$AUDIT_LOG" <<AUDIT_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","task":"git_commit_if_changed","args":["${FILE_PATH}","${COMMIT_MSG}"],"cwd":"$(pwd)","exit_code":0,"action":"committed","old_hash":"${OLD_HASH}","new_hash":"${NEW_HASH}","post_commit_hash":"${POST_HASH}","duration_ms":${DURATION}}
AUDIT_EOF

echo "COMMITTED: ${FILE_PATH}"
echo "  Old: ${OLD_HASH:0:12}..."
echo "  New: ${NEW_HASH:0:12}..."
