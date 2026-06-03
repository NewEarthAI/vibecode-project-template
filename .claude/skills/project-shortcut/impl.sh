#!/usr/bin/env bash
# Project Shortcut Implementation
# Adds shell aliases for fast project launching with git pull + tmux + claude

set -euo pipefail

# Configuration
ALIAS="${1:?Error: alias required}"
DIRECTORY="${2:?Error: directory required}"
DESCRIPTION="${3:-$ALIAS}"

# Resolve directory to absolute path
DIRECTORY=$(cd "$DIRECTORY" 2>/dev/null && pwd) || {
  echo "❌ Directory does not exist: $2" >&2
  exit 1
}

# Detect shell config file
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
  SHELL_TYPE="zsh"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
  SHELL_TYPE="bash"
else
  echo "❌ No shell config found (~/.zshrc or ~/.bashrc)" >&2
  exit 1
fi

# Validate alias format (alphanumeric + underscore)
if ! [[ "$ALIAS" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  echo "❌ Invalid alias: must start with letter/underscore, contain only alphanumeric/underscore" >&2
  exit 1
fi

# Build alias command
ALIAS_CMD="alias ${ALIAS}='cd \"${DIRECTORY}\" && git pull --ff-only 2>/dev/null; tx-claude .'"

# Check if alias already exists
if grep -q "^alias ${ALIAS}=" "$SHELL_CONFIG"; then
  echo "⚠️  Alias '${ALIAS}' already exists in $SHELL_CONFIG"
  echo "   Update it? (y/n)"
  read -r RESPONSE
  if [[ "$RESPONSE" != "y" ]]; then
    echo "Skipped."
    exit 0
  fi
  # Remove old alias
  sed -i '' "/^alias ${ALIAS}=/d" "$SHELL_CONFIG"
  echo "✓ Removed old alias"
fi

# Add comment for clarity
echo "" >> "$SHELL_CONFIG"
echo "# $DESCRIPTION (added by /project-shortcut)" >> "$SHELL_CONFIG"
echo "$ALIAS_CMD" >> "$SHELL_CONFIG"

echo "✓ Added alias: $ALIAS → $DIRECTORY"
echo "  Description: $DESCRIPTION"
echo ""
echo "Usage: $ALIAS"
echo ""
echo "To reload shell config:"
echo "  source $SHELL_CONFIG"
echo "  # or close and reopen terminal"
