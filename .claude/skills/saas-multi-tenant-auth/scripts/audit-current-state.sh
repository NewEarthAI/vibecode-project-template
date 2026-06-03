#!/usr/bin/env bash
# audit-current-state.sh — assess where a project is in the 6-tier shipping plan
#
# Usage:
#   bash audit-current-state.sh <SUPABASE_PROJECT_URL> <SERVICE_ROLE_KEY>
#
# Prints which tiers are shipped + what's missing. Use this when arriving at
# an in-progress project to skip to the failing tier.

set -euo pipefail

SUPABASE_URL="${1:-${SUPABASE_URL:-}}"
SERVICE_ROLE_KEY="${2:-${SUPABASE_SERVICE_ROLE_KEY:-}}"
PREFIX="${PREFIX:-bb}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SERVICE_ROLE_KEY" ]; then
  echo "Usage: $0 <SUPABASE_PROJECT_URL> <SERVICE_ROLE_KEY>"
  echo "Or set env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY"
  echo "Optional env: PREFIX (default: bb)"
  exit 1
fi

# Helper: run SQL and return scalar count
sqlc() {
  local query="$1"
  curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/sql_exec" \
    -H "apikey: $SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$query\"}" 2>/dev/null || echo "ERR"
}

# Note: Supabase doesn't have a generic sql_exec RPC by default. This script
# is a TEMPLATE — adapt the curl invocations to use information_schema queries
# via PostgREST, OR run the equivalent SQL via the Supabase MCP / dashboard.

echo "═══════════════════════════════════════════════════════════════════"
echo "saas-multi-tenant-auth — Current State Audit"
echo "Project: $SUPABASE_URL"
echo "Prefix: $PREFIX"
echo "═══════════════════════════════════════════════════════════════════"

cat <<EOF

Run these queries manually against your DB and check off each tier:

── Tier 1 (Foundation) ──────────────────────────────────────────────
  SELECT count(*) FROM information_schema.tables
  WHERE table_schema='public' AND table_name='${PREFIX}_organizations';
  -- Expect: 1 (table exists)

  SELECT count(*) FROM pg_proc
  WHERE proname='${PREFIX}_user_org_ids';
  -- Expect: 1

  SELECT count(*) FROM pg_proc
  WHERE proname='${PREFIX}_rls_health_check';
  -- Expect: 1

── Tier 2 (Invitations) ─────────────────────────────────────────────
  SELECT count(*) FROM information_schema.tables
  WHERE table_schema='public' AND table_name='${PREFIX}_pending_invites';
  -- Expect: 1

  SELECT count(*) FROM pg_proc
  WHERE proname IN ('accept_invite_atomic','get_auth_user_id_by_email');
  -- Expect: 2

── Tier 3 (Team Mgmt) ───────────────────────────────────────────────
  SELECT count(*) FROM pg_proc
  WHERE proname IN ('change_member_role','set_member_status','remove_member','transfer_ownership');
  -- Expect: 4

  SELECT count(*) FROM pg_trigger
  WHERE tgname='trg_${PREFIX}_block_last_owner_demote';
  -- Expect: 1

── Tier 4 (Audit Log) ───────────────────────────────────────────────
  SELECT count(*) FROM information_schema.tables
  WHERE table_schema='public' AND table_name='${PREFIX}_org_audit_log';
  -- Expect: 1

  SELECT count(*) FROM pg_trigger
  WHERE tgname LIKE '%audit%' AND tgrelid::regclass::text LIKE '%${PREFIX}_%';
  -- Expect: >= 4 (capture triggers + structural triggers)

── Tier 5 (Frontend) ────────────────────────────────────────────────
  Check your repo:
  ls src/hooks/useAuth.tsx src/hooks/useOrganization.ts \
     src/components/ui/OrgSwitcher.tsx src/pages/InviteAccept.tsx 2>&1

── Tier 6 (Hardening) ───────────────────────────────────────────────
  SELECT count(*) FROM cron.job WHERE jobname LIKE '%${PREFIX}%';
  -- Expect: >= 1 (RLS health check schedule)

  ls supabase/tests/cm32_cross_tenant_penetration.sql 2>&1
  -- Expect: file exists

═══════════════════════════════════════════════════════════════════
Skip to the first tier where something fails. Read references/tier-N-*.md
═══════════════════════════════════════════════════════════════════
EOF
