#!/bin/bash
# Bootstrap Obsidian autopilot on this repo + machine.
#
# Idempotent: safe to run repeatedly. /update-latest invokes this every sync.
#
# What it does:
#   1. Detects if .claude/obsidian-second-brain.local.md already exists.
#      If yes — verifies vault_scope_slug is set; adds one if missing. Done.
#      If no  — creates one with the three shared agency values pre-filled
#               and the repo slug auto-detected from the folder name.
#   2. Verifies the macOS Keychain entry exists. If absent — prints exact
#      command for operator to provision it, then exits non-zero.
#   3. Verifies vault_path resolves to a real folder. Warns if not.
#   4. Smoke-tests the SessionStart vault block end-to-end.
#
# Exit codes:
#   0 — all good, vault loop ready
#   1 — Keychain entry missing (operator must add manually)
#   2 — vault_path doesn't resolve (operator must fix vault_path or install
#       Agency-Main repo at the conventional location)

set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONFIG="$REPO_ROOT/.claude/obsidian-second-brain.local.md"
EXAMPLE="$REPO_ROOT/.claude/obsidian-second-brain.example.md"

# Auto-detect repo slug from folder name. Lowercased, hyphens collapsed, trim
# the "-ai" suffix the agency uses on most repo names (your project → buybox,
# Agency-Main → agency-main, nirvana-freight → nirvana-freight). Operators
# can override by editing the .local.md file after bootstrap.
detect_slug() {
  local raw
  raw=$(basename "$REPO_ROOT" | tr '[:upper:]' '[:lower:]')
  # Trim "-ai" suffix when the repo name ends in it (your project convention)
  raw="${raw%-ai}"
  # Trim "-main" suffix on parent-repo names (Agency-Main → agency)
  raw="${raw%-main}"
  echo "$raw"
}

SLUG=$(detect_slug)
VAULT_PATH_DEFAULT="$HOME/ObsidianVault"
SUPABASE_URL_DEFAULT=""   # set to https://YOUR-PROJECT-REF.supabase.co (empty = skip DB sync)
KEYCHAIN_ITEM_DEFAULT="project-supabase-service-role-jwt"

# Special case: Agency-Main parent should NOT set a scope slug (sees full vault).
# Detected by folder name OR by the presence of agency/vault/ in this repo.
IS_AGENCY_MAIN=0
if [ -d "$REPO_ROOT/agency/vault" ]; then
  IS_AGENCY_MAIN=1
  SLUG=""
fi

echo "═══════════════════════════════════════════════════════"
echo " Obsidian Autopilot Bootstrap"
echo "═══════════════════════════════════════════════════════"
echo " Repo:  $(basename "$REPO_ROOT")"
echo " Slug:  ${SLUG:-<none — full vault (Agency-Main parent)>}"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── Step 1: Create or update the per-machine config ─────────────────────────
if [ ! -f "$CONFIG" ]; then
  echo "[1/4] No .local.md found — creating with defaults..."
  cat > "$CONFIG" <<EOF
---
# Per-machine obsidian autopilot config — gitignored, never committed.
# Auto-created by bootstrap-obsidian.sh on $(date -u +%Y-%m-%d).
# Edit values below if defaults don't match this Mac's setup.

vault_path: "$VAULT_PATH_DEFAULT"
supabase_url: "$SUPABASE_URL_DEFAULT"
keychain_item: "$KEYCHAIN_ITEM_DEFAULT"
EOF
  if [ -n "$SLUG" ]; then
    cat >> "$CONFIG" <<EOF
# Per-repo scope — restricts SessionStart vault block to rows whose
# source_path contains this slug. Each downstream repo gets its own; the
# Agency-Main parent omits this line and sees the full vault.
vault_scope_slug: "$SLUG"
EOF
  fi
  echo "---" >> "$CONFIG"
  echo "" >> "$CONFIG"
  echo "# Obsidian Autopilot — Per-Machine Config" >> "$CONFIG"
  echo "" >> "$CONFIG"
  echo "Auto-bootstrapped. Re-run \`bash .claude/scripts/bootstrap-obsidian.sh\` to re-verify." >> "$CONFIG"
  echo "✓ Created $CONFIG"
else
  echo "[1/4] .local.md already exists — checking for vault_scope_slug..."
  if ! grep -q "^vault_scope_slug:" "$CONFIG" 2>/dev/null; then
    if [ -n "$SLUG" ]; then
      # Insert vault_scope_slug before the closing '---' of the frontmatter
      awk -v slug="$SLUG" '
        /^---$/ && c++ == 1 {
          print "vault_scope_slug: \"" slug "\""
        }
        { print }
      ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
      echo "✓ Added vault_scope_slug: \"$SLUG\" to existing config"
    else
      echo "✓ Agency-Main parent — no slug needed (sees full vault)"
    fi
  else
    EXISTING_SLUG=$(awk '/^---$/{if(++c==2) exit} c==1 && /vault_scope_slug:/{gsub(/.*vault_scope_slug:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$CONFIG")
    echo "✓ vault_scope_slug already set to \"$EXISTING_SLUG\""
  fi
fi
echo ""

# ── Step 2: Verify Keychain entry ───────────────────────────────────────────
echo "[2/4] Verifying macOS Keychain entry..."
KC_ITEM=$(awk '/^---$/{if(++c==2) exit} c==1 && /keychain_item:/{gsub(/.*keychain_item:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$CONFIG")
if security find-generic-password -s "$KC_ITEM" -a "service_role" -w >/dev/null 2>&1; then
  echo "✓ Keychain entry '$KC_ITEM' resolves on this Mac"
else
  cat <<EOF
✗ Keychain entry '$KC_ITEM' NOT found on this Mac.

Provision it with:
  security add-generic-password \\
    -s '$KC_ITEM' \\
    -a 'service_role' \\
    -w '<paste-agency-supabase-service-role-jwt-here>'

Get the JWT from another Mac that's already set up:
  security find-generic-password -s '$KC_ITEM' -a 'service_role' -w

Then re-run: bash .claude/scripts/bootstrap-obsidian.sh
EOF
  exit 1
fi
echo ""

# ── Step 3: Verify vault_path resolves ──────────────────────────────────────
echo "[3/4] Verifying vault_path..."
VAULT_PATH=$(awk '/^---$/{if(++c==2) exit} c==1 && /vault_path:/{gsub(/.*vault_path:[[:space:]]*"?/,""); gsub(/"[[:space:]]*$/,""); print}' "$CONFIG")
if [ -d "$VAULT_PATH" ]; then
  echo "✓ vault_path resolves: $VAULT_PATH"
else
  cat <<EOF
⚠ vault_path '$VAULT_PATH' does NOT resolve on this Mac.

This usually means your Obsidian vault isn't at the configured path.
Either:
  (a) create a vault at that path (or move your existing one there), or
  (b) edit $CONFIG and set vault_path to wherever your vault actually lives

SessionStart vault block will still work (it reads from Supabase, not the vault
folder). But Stop-hook vault-capture.sh won't be able to append session
summaries to daily notes until vault_path resolves.
EOF
  # Soft warning — don't exit non-zero; SessionStart side still works.
fi
echo ""

# ── Step 4: Smoke-test the SessionStart vault block ─────────────────────────
echo "[4/4] Smoke-testing SessionStart vault block..."
HOOK="$REPO_ROOT/.claude/hooks/sessionstart-context-aggregator.sh"
if [ ! -x "$HOOK" ]; then
  echo "⚠ Hook not found at $HOOK — skipping smoke test."
else
  OUT=$(echo "{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$REPO_ROOT\"}" | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // .additionalContext // empty' 2>/dev/null | grep -A 1 "📓 Recent vault activity" | head -2)
  if [ -n "$OUT" ]; then
    echo "✓ Vault block emits:"
    echo "$OUT" | sed 's/^/    /'
  else
    echo "⚠ Vault block emitted nothing — vault may be empty, or smoke check needs investigation."
  fi
fi
echo ""
echo "═══════════════════════════════════════════════════════"
echo " ✓ Obsidian autopilot bootstrap complete"
echo "═══════════════════════════════════════════════════════"
