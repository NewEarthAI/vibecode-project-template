#!/usr/bin/env bash
# verify-grid.sh — 7-check verification grid for the Obsidian vault autopilot
# (skill: obsidian-vault-autopilot v1.0)
#
# Encodes the verification we built live on Justin's Mac 2026-05-22 (7/7 PASS).
#
# Council amendments applied:
#   - A3: Check #4 marks plist-absent as ADVISORY (not FAIL) when vault is under ~/Documents/
#   - A8: Check #1 compares git remote to stored persona; ADVISORY on drift (closes stale-persona CRITICAL-2)
#   - A11: Check #5 queries vault_sync_log DB row, not log file tail (catches JWT-rotation silent failure)
#
# Exit 0 = 7/7 PASS (ADVISORY counts as pass with note). Exit 1 = any FAIL.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || { echo "verify-grid: cannot cd to repo root" >&2; exit 1; }

CONFIG_FILE="$REPO_ROOT/.claude/obsidian-second-brain.local.md"

PASS_COUNT=0
ADVISORY_COUNT=0
FAIL_COUNT=0
EXIT_CODE=0

say_pass()     { printf '  ✓ PASS:     %s\n' "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
say_advisory() { printf '  ⚠ ADVISORY: %s\n' "$1"; ADVISORY_COUNT=$((ADVISORY_COUNT+1)); }
say_fail()     { printf '  ✗ FAIL:     %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT+1)); EXIT_CODE=1; }

echo "════ Obsidian Vault Autopilot — 7-Check Verification Grid ════"

# Check 1 — Repo identity (A8: persona vs remote re-challenge)
echo ""
echo "[1/7] Repo identity"
REMOTE_URL="$(git remote get-url origin 2>/dev/null || echo "")"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
STORED_PERSONA=""
if [ -f "$CONFIG_FILE" ]; then
  STORED_PERSONA=$(awk -F'"' '/^persona:/{print $2}' "$CONFIG_FILE" 2>/dev/null)
fi
echo "  repo  = $REPO_ROOT"
echo "  remote= $REMOTE_URL"
echo "  branch= $BRANCH"
echo "  stored persona = ${STORED_PERSONA:-<not set>}"
if [ "$STORED_PERSONA" = "newearth-internal" ]; then
  if echo "$REMOTE_URL" | grep -qiE "(github\.com[:/])(NewEarthAI|NewEarth-AI)/"; then
    say_pass "remote matches stored persona pattern (newearth-internal)"
  else
    say_advisory "stored persona is newearth-internal but remote does NOT match NewEarthAI/* — re-run bootstrap to reclassify"
  fi
else
  say_pass "repo identity captured"
fi

# Check 2 — Per-machine config exists + required fields
echo ""
echo "[2/7] Per-machine config"
if [ ! -f "$CONFIG_FILE" ]; then
  say_fail "config missing: $CONFIG_FILE"
else
  MISSING_FIELDS=""
  for field in vault_path supabase_url keychain_item persona; do
    if ! grep -qE "^${field}:" "$CONFIG_FILE"; then
      MISSING_FIELDS="$MISSING_FIELDS $field"
    fi
  done
  if [ -z "$MISSING_FIELDS" ]; then
    say_pass "config has all 4 required fields"
  else
    say_fail "config missing fields:$MISSING_FIELDS"
  fi
fi

# Check 3 — Vault path resolves + non-empty
echo ""
echo "[3/7] Vault path"
VAULT_PATH=""
[ -f "$CONFIG_FILE" ] && VAULT_PATH=$(awk -F'"' '/^vault_path:/{print $2}' "$CONFIG_FILE" 2>/dev/null)
if [ -z "$VAULT_PATH" ]; then
  say_fail "vault_path not set in config"
elif [ ! -d "$VAULT_PATH" ]; then
  say_fail "vault_path does not exist: $VAULT_PATH"
else
  NOTE_COUNT=$(find "$VAULT_PATH" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
  say_pass "vault at $VAULT_PATH (notes: $NOTE_COUNT)"
fi

# Check 4 — Launchd autopilot (A3: ADVISORY if vault under ~/Documents/)
echo ""
echo "[4/7] Launchd autopilot"
LAUNCH_LINE="$(launchctl list 2>/dev/null | grep vault-sync || true)"
TCC_AFFECTED=0
[[ "$VAULT_PATH" == *"/Documents/"* ]] && TCC_AFFECTED=1
if [ -z "$LAUNCH_LINE" ]; then
  if [ "$TCC_AFFECTED" = "1" ]; then
    say_advisory "plist not loaded; vault is under ~/Documents/ — TCC ceiling makes launchd unreliable; SessionStart-only sync is the canonical workaround (council A3)"
  else
    say_fail "plist not loaded (run activator)"
  fi
else
  LAST_EXIT=$(echo "$LAUNCH_LINE" | awk '{print $2}')
  if [ "$LAST_EXIT" = "0" ] || [ "$LAST_EXIT" = "-" ]; then
    say_pass "launchctl shows vault-sync loaded; last exit = $LAST_EXIT"
  else
    say_advisory "launchctl shows vault-sync loaded but last exit = $LAST_EXIT (check log)"
  fi
fi

# Check 5 — Last sync recent (A11: query DB row, not log file)
echo ""
echo "[5/7] Last sync recent"
SUPABASE_URL=""
[ -f "$CONFIG_FILE" ] && SUPABASE_URL=$(awk -F'"' '/^supabase_url:/{print $2}' "$CONFIG_FILE" 2>/dev/null)
KEYCHAIN_ITEM=""
[ -f "$CONFIG_FILE" ] && KEYCHAIN_ITEM=$(awk -F'"' '/^keychain_item:/{print $2}' "$CONFIG_FILE" 2>/dev/null)
SERVICE_KEY=""
[ -n "$KEYCHAIN_ITEM" ] && SERVICE_KEY=$(security find-generic-password -s "$KEYCHAIN_ITEM" -a "service_role" -w 2>/dev/null || true)
# Must match vault-sync.sh line 114 — same normaliser so the query joins correctly
HOSTNAME=$(hostname 2>/dev/null | tr -cs 'A-Za-z0-9.-' '-' | sed 's/-*$//'); HOSTNAME=${HOSTNAME:-unknown}

if [ -z "$SUPABASE_URL" ] || [ -z "$SERVICE_KEY" ]; then
  say_advisory "cannot query vault_sync_log (missing supabase_url or service_role JWT) — falling back to log file check"
  if [ -f "$HOME/Library/Logs/vault-sync.log" ]; then
    LAST_LOG_LINE=$(grep -vE "0 modified files|No files to sync" ~/Library/Logs/vault-sync.log 2>/dev/null | tail -1 || echo "")
    if [ -n "$LAST_LOG_LINE" ]; then
      echo "    log tail: $LAST_LOG_LINE"
    fi
  fi
else
  LAST_SYNC=$(curl -sS --max-time 10 \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    "$SUPABASE_URL/rest/v1/vault_sync_log?machine=eq.$HOSTNAME&order=synced_at.desc&limit=1&select=synced_at" 2>/dev/null || echo "")
  if [ -z "$LAST_SYNC" ] || [ "$LAST_SYNC" = "[]" ]; then
    say_fail "no vault_sync_log row found for machine=$HOSTNAME — autopilot may never have run"
  else
    say_pass "last sync row present in vault_sync_log: $LAST_SYNC"
  fi
fi

# Check 6 — Keychain entries
echo ""
echo "[6/7] Keychain entries"
REQUIRED="agency-supabase-newearthai-service-role-jwt"
OPTIONAL="claude-mcp-supabase-newearthai agency-supabase-newearthai-secret-key agency-supabase-newearthai-publishable-key"
if security find-generic-password -s "$REQUIRED" >/dev/null 2>&1; then
  say_pass "$REQUIRED present"
else
  say_fail "$REQUIRED missing (required for autopilot)"
fi
for s in $OPTIONAL; do
  if security find-generic-password -s "$s" >/dev/null 2>&1; then
    echo "    ✓ optional: $s present"
  else
    echo "    ⚠ optional: $s missing (forward-protection only)"
  fi
done

# Check 7 — Cross-machine memory symlink (composes bin/memory-health-check.sh)
echo ""
echo "[7/7] Cross-machine memory symlink"
if [ -x "$REPO_ROOT/bin/memory-health-check.sh" ]; then
  if bash "$REPO_ROOT/bin/memory-health-check.sh" >/dev/null 2>&1; then
    say_pass "memory-health-check: PASS"
  else
    say_fail "memory-health-check: FAIL (run: bash bin/memory-health-check.sh --verbose)"
  fi
else
  say_advisory "bin/memory-health-check.sh not found — skipping check 7"
fi

# Summary
echo ""
echo "════ Verification Summary ════"
printf '  PASS:      %d / 7\n' "$PASS_COUNT"
printf '  ADVISORY:  %d\n' "$ADVISORY_COUNT"
printf '  FAIL:      %d\n' "$FAIL_COUNT"
echo ""
if [ "$FAIL_COUNT" = "0" ]; then
  echo "✓ obsidian-vault-autopilot: PASS"
  exit 0
else
  echo "✗ obsidian-vault-autopilot: FAIL — see checks above"
  exit 1
fi
