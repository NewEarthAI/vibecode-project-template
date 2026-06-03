#!/usr/bin/env bash
# write-per-machine-config.sh — generate `.claude/obsidian-second-brain.local.md`
# (skill: obsidian-vault-autopilot v1.0)
#
# Council A9 amendment: in v1.0, this script ONLY writes the per-machine config
# file. v1.2 spec calls for per-Mac plist substitution; deferred until spoke
# rollout when label parameterisation (A1) lands together.
#
# Usage: write-per-machine-config.sh <persona> <vault_path> <supabase_url> <keychain_item>
# Persona must be one of: newearth-internal (v1.0 only supports this)

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PERSONA="${1:-newearth-internal}"
VAULT_PATH="${2:?vault_path required as arg 2}"
SUPABASE_URL="${3:?supabase_url required as arg 3}"
KEYCHAIN_ITEM="${4:?keychain_item required as arg 4}"
CONFIG_FILE="$REPO_ROOT/.claude/obsidian-second-brain.local.md"

# Guard 1 — persona is one of the supported v1.0 values
if [ "$PERSONA" != "newearth-internal" ]; then
  echo "[write-per-machine-config] ERROR: v1.0 only supports persona=newearth-internal (got: $PERSONA)" >&2
  echo "[write-per-machine-config] external persona deferred to v2.0 per Spec 26 A13" >&2
  exit 1
fi

# Guard 2 — vault path must exist
if [ ! -d "$VAULT_PATH" ]; then
  echo "[write-per-machine-config] ERROR: vault_path does not exist: $VAULT_PATH" >&2
  exit 1
fi

# Guard 3 — config file must be gitignored (security invariant)
if ! git check-ignore -q "$CONFIG_FILE" 2>/dev/null; then
  echo "[write-per-machine-config] ERROR: $CONFIG_FILE is not gitignored — refusing to write" >&2
  echo "[write-per-machine-config] add to .gitignore: .claude/obsidian-second-brain.local.md" >&2
  exit 1
fi

# Derive repo_slug from REPO_ROOT basename (will be used by A1 plist label parameterisation in v1.2)
REPO_SLUG="$(basename "$REPO_ROOT")"

# TCC ADVISORY (council A3) — detect Documents-path vault
TCC_ADVISORY=""
if [[ "$VAULT_PATH" == *"/Documents/"* ]]; then
  TCC_ADVISORY="# WARNING: vault is under ~/Documents/ — macOS TCC ceiling prevents launchd autopilot.
# SessionStart-only sync applies. See council A3 in Spec 26 v2 + agency/memory/project_obsidian-autopilot-rollout-2026-05-15.md line 21."
fi

# Write the config file
cat > "$CONFIG_FILE" <<EOF
---
vault_path: "$VAULT_PATH"
supabase_url: "$SUPABASE_URL"
keychain_item: "$KEYCHAIN_ITEM"
persona: "$PERSONA"
repo_slug: "$REPO_SLUG"
created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
skill_version: "obsidian-vault-autopilot@1.0"
---

# Obsidian Second-Brain — Per-Machine Config

Per-machine, gitignored. Points the vault autopilot (\`bin/vault-sync.sh\`) and
the SessionStart context aggregator at this Mac's vault + database.

$TCC_ADVISORY

- \`vault_path\` — absolute path to vault root on this Mac
- \`supabase_url\` — per-vault Supabase project URL
- \`keychain_item\` — macOS Keychain service name holding service-role JWT
- \`persona\` — \`newearth-internal\` (v1.0 only); \`external\` lands in v2.0
- \`repo_slug\` — used by plist label parameterisation (A1, v1.2)

Authored by \`.claude/skills/obsidian-vault-autopilot/scripts/write-per-machine-config.sh\`.
Re-run the skill to update; do not hand-edit unless you know what you're doing.
EOF

echo "[write-per-machine-config] OK: $CONFIG_FILE"
echo "  persona     = $PERSONA"
echo "  vault_path  = $VAULT_PATH"
echo "  supabase    = $SUPABASE_URL"
echo "  keychain    = $KEYCHAIN_ITEM"
echo "  repo_slug   = $REPO_SLUG"
[ -n "$TCC_ADVISORY" ] && echo "  TCC NOTE    = vault is under ~/Documents/ — plist autopilot unreliable"
