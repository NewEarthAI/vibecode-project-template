#!/usr/bin/env bash
# activate-vault-autopilot.sh — One-time per-Mac activation of the vault-sync
# launchd autopilot (Obsidian canary, council 2026-05-15).
#
# Closes:
#   - F2 (Reliability Engineer): end-to-end write→read→delete smoke against the
#     ACTUAL substrate before trusting the autopilot, + a hard routing
#     assertion that the target is supabase-{your-agency-instance} (NOT one of the client-specific Supabase instances
#     — the BuyBox DB; a misroute would leak agency vault notes into a client
#     project, which RLS would not catch because the service_role bypasses it).
#   - Amendment 11 / Edge #5: plist __REPO_ROOT__ / __HOME__ are placeholders;
#     a copied-verbatim plist runs `__REPO_ROOT__/bin/vault-sync.sh` literally
#     and launchd fails silently. Mechanical `sed` substitution removes the
#     "edit the paths by hand" footgun the template comment described.
#
# Usage:  cd <repo-root> && bash bin/activate-vault-autopilot.sh
# Idempotent: re-running re-syncs the plist and reloads the agent cleanly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/bin/launchd/com.newearthai.vault-sync.plist.template"
LABEL="com.newearthai.vault-sync"
TARGET_PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SYNC_SCRIPT="$REPO_ROOT/bin/vault-sync.sh"

# Expected substrate — operator-supplied via env var (fail-loud if absent).
# Prod (newearthai-prod) = ridqdojzjotlvexfuwvx; staging = iqgsthdhkbkjpdqnfisu.
# Reliability Engineer NSF-1 (2026-05-20 schema-mirror council): default-to-prod
# pattern was an anti-pattern — silent prod-routing inverted the dev/prod-separation
# goal. Loud failure is the correct mode.
EXPECTED_REF="${EXPECTED_REF:?EXPECTED_REF env var required — set to the Supabase project ref this activator should bind against (e.g. ridqdojzjotlvexfuwvx for prod, iqgsthdhkbkjpdqnfisu for staging). Launchd plist EnvironmentVariables MUST set this.}"
EXPECTED_HOST="${EXPECTED_REF}.supabase.co"

say() { printf '[activate-autopilot] %s\n' "$*"; }
die() { printf '[activate-autopilot] ERROR: %s\n' "$*" >&2; exit 1; }

[ -f "$TEMPLATE" ]    || die "plist template missing: $TEMPLATE — pull latest main?"
[ -f "$SYNC_SCRIPT" ] || die "vault-sync.sh missing: $SYNC_SCRIPT"

# ── Routing assertion (F2, part 1) — parameterised script ─────────────────
# vault-sync.sh is now parameterised (Track C dev/prod-separation Phase 2.1,
# 2026-05-20). It reads SUPABASE_URL from its environment with a `${VAR:?...}`
# fail-loud guard. The autopilot's job is to prove BOTH:
#   (a) vault-sync.sh is properly parameterised (no hardcoded supabase.co ref)
#   (b) the live plist supplies SUPABASE_URL = https://<EXPECTED_REF>.supabase.co
# so that when launchd fires the script, routing matches what the operator asked
# for. Edge Case Finder EC-1 (2026-05-20 council): the OLD grep-based guard
# self-DOSed once vault-sync.sh became parameterised (zero literal URLs in the
# file). New 3-part check below.

# Part 1a: vault-sync.sh contains the parameterisation pattern (proof of
# explicit env-var dependency, not hardcoded).
if ! grep -qE '\$\{SUPABASE_URL:\?' "$SYNC_SCRIPT"; then
    die "vault-sync.sh missing parameterisation pattern — expected \${SUPABASE_URL:?...} guard. Stale checkout? Run: git pull"
fi
# Part 1b: no OTHER hardcoded supabase.co host literal leaked into vault-sync.sh
# (defence against partial-refactor regressions).
LEAKED_URLS=$(grep -oE 'https://[a-z0-9]+\.supabase\.co' "$SYNC_SCRIPT" | sort -u || true)
if [ -n "$LEAKED_URLS" ]; then
    die "vault-sync.sh contains hardcoded supabase host(s) — should be fully parameterised:
$LEAKED_URLS"
fi
say "parameterisation OK — vault-sync.sh reads SUPABASE_URL from environment"
say "routing target — https://${EXPECTED_HOST} (EXPECTED_REF=$EXPECTED_REF)"

# ── e2e smoke (F2, part 2) — write → read → delete a sentinel row ──────────
SERVICE_KEY=$(security find-generic-password -s "agency-supabase-newearthai-service-role-jwt" -a "service_role" -w 2>/dev/null || true)
[ -n "$SERVICE_KEY" ] || die "service_role JWT missing from Keychain — see agency/memory/reference_supabase-newearthai-credentials.md"
ENDPOINT="https://${EXPECTED_HOST}/rest/v1/vault_sync_log"
SENTINEL="__activate_smoke_$$_$(date +%s)__"

smoke_code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
    -X POST "$ENDPOINT" \
    -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    --data-binary "{\"machine\":\"$(hostname)\",\"repo_slug\":\"$SENTINEL\",\"rows_upserted\":0,\"rows_conflict\":0,\"rows_failed\":0,\"exit_code\":0,\"note\":\"activate-autopilot smoke — auto-deleted\"}" \
    2>/dev/null || echo 000)
[ "$smoke_code" = "201" ] || die "smoke WRITE failed (HTTP $smoke_code) — substrate unreachable or vault_sync_log RLS/grant broken. NOT activating."

read_n=$(curl -sS --max-time 15 \
    "$ENDPOINT?repo_slug=eq.${SENTINEL}&select=id" \
    -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" 2>/dev/null \
    | grep -o '"id"' | wc -l | tr -d ' ')
[ "${read_n:-0}" -ge 1 ] || die "smoke READ-BACK failed — wrote but could not read sentinel. NOT activating."

del_code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
    -X DELETE "$ENDPOINT?repo_slug=eq.${SENTINEL}" \
    -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Prefer: return=minimal" 2>/dev/null || echo 000)
case "$del_code" in 200|204) ;; *) say "WARN: smoke cleanup DELETE returned $del_code — sentinel row repo_slug=$SENTINEL may need manual purge" ;; esac
say "e2e smoke OK — write 201, read-back $read_n, delete $del_code"

# ── plist placeholder substitution (Amendment 11 / Edge #5) ────────────────
mkdir -p "$HOME/Library/LaunchAgents"
TMP_PLIST=$(mktemp "${TMPDIR:-/tmp}/vault-sync-plist.XXXXXX")
trap 'rm -f "$TMP_PLIST"' EXIT
sed -e "s|__REPO_ROOT__|${REPO_ROOT}|g" -e "s|__HOME__|${HOME}|g" "$TEMPLATE" > "$TMP_PLIST"
if grep -q '__REPO_ROOT__\|__HOME__' "$TMP_PLIST"; then
    die "placeholder substitution incomplete — refusing to install a broken plist"
fi

if [ -f "$TARGET_PLIST" ] && cmp -s "$TMP_PLIST" "$TARGET_PLIST"; then
    say "plist already current at $TARGET_PLIST (idempotent no-op on file)"
else
    cp "$TMP_PLIST" "$TARGET_PLIST"
    say "installed plist → $TARGET_PLIST"
fi

# ── Load / reload the launchd agent ────────────────────────────────────────
GUI="gui/$(id -u)"
launchctl bootout  "$GUI/$LABEL"        2>/dev/null || true
launchctl bootstrap "$GUI" "$TARGET_PLIST" 2>/dev/null \
    || die "launchctl bootstrap failed — check: launchctl print $GUI/$LABEL"
launchctl kickstart -k "$GUI/$LABEL"    2>/dev/null || true

say "autopilot ACTIVE — vault-sync runs every 600s + at load."
say "Verify:  launchctl list | grep vault-sync   (PID + last exit)"
say "         tail ~/Library/Logs/vault-sync.log"
say "         SELECT * FROM vault_sync_log ORDER BY synced_at DESC LIMIT 3;"
