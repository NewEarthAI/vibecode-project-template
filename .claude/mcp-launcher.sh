#!/bin/bash
# MCP Server Launcher — Keychain-backed secret injection
# Replaces plaintext API keys in settings.json with macOS Keychain lookups.
#
# Usage (in ~/.claude/settings.json):
#   "command": "~/.claude/mcp-launcher.sh",
#   "args": ["<server-name>", "<original-command>", "<original-args>..."]
#
# Keys stored in Keychain as: service="claude-mcp-<server-name>", account="api-key"
#
# Store a key:
#   security add-generic-password -U -s "claude-mcp-<server-name>" -a "api-key" -w "<key>"
#
# Retrieve a key:
#   security find-generic-password -s "claude-mcp-<server-name>" -a "api-key" -w
#
# Supported server patterns:
#   supabase-*    → exports SUPABASE_ACCESS_TOKEN
#   n8n-mcp-*     → exports N8N_API_KEY
#   github        → exports GITHUB_PERSONAL_ACCESS_TOKEN
#   airtable-*    → exports AIRTABLE_API_KEY
#   redis-*       → replaces {{KEYCHAIN}} in args (password)
#   wassenger     → replaces {{KEYCHAIN}} in args (API key)
#
# Servers without keychain entries pass through unchanged (warning to stderr).

set -euo pipefail

SERVER="$1"
shift

# Fetch key from macOS Keychain (silent on missing)
KEY=$(security find-generic-password -s "claude-mcp-${SERVER}" -a "api-key" -w 2>/dev/null || true)

if [ -z "$KEY" ]; then
  echo "mcp-launcher: no keychain entry for claude-mcp-${SERVER}" >&2
  exec "$@"
fi

# Inject key based on server type
case "$SERVER" in
  supabase-*)
    export SUPABASE_ACCESS_TOKEN="$KEY"
    ;;
  n8n-mcp-*)
    export N8N_API_KEY="$KEY"
    ;;
  github)
    export GITHUB_PERSONAL_ACCESS_TOKEN="$KEY"
    ;;
  airtable-*)
    export AIRTABLE_API_KEY="$KEY"
    ;;
  redis-*|wassenger)
    # Arg-based keys: replace {{KEYCHAIN}} placeholder in args
    ARGS=()
    for arg in "$@"; do
      if [ "$arg" = "{{KEYCHAIN}}" ]; then
        ARGS+=("$KEY")
      else
        ARGS+=("$arg")
      fi
    done
    exec "${ARGS[@]}"
    ;;
  *)
    # Unknown server type with a key — export as generic MCP_API_KEY
    export MCP_API_KEY="$KEY"
    ;;
esac

exec "$@"
