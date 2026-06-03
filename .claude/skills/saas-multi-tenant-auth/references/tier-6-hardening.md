# Tier 6 — Hardening

**What ships**: Cross-tenant penetration tests, RLS health check pg_cron schedule, observability (Sentry org tagging), CI regression greps.
**Template**: `templates/05_pen_tests.sql`
**Verification gate**: pen-test suite passes 100% under both authenticated user contexts (User A from Org A, User B from Org B).

## The 13 cross-tenant pen tests

| # | Test | Verifies |
|---|---|---|
| T1 | User A cannot SELECT User B's tenant data | Pillar 1, 3 |
| T2 | User A cannot UPDATE User B's tenant data | UPDATE policy |
| T3 | User A cannot DELETE User B's tenant data | DELETE policy |
| T4 | User A cannot read User B's `{{membership_table}}` rows | Membership scoping |
| T5 | User A cannot invite to User B's org | Edge fn auth check |
| T6 | User A cannot accept User B's invite (different email) | Email match + JWT |
| T7 | Audit log SELECT scoped to org owner/admin only | Pillar 7 |
| T8 | RLS policy count matches expected per table | Schema regression |
| T9 | All views with tenant data have `security_invoker=true` | Pillar 1 |
| T10 | No `qual = true` SELECT policies exist on tenant tables | Pillar 3 |
| T11 | `{{tenant_column}}` is NOT NULL on every tenant data row | Backfill complete |
| T12 | Cross-tenant audit-log read blocked | Audit RLS scoping |
| T13 | UPDATE/DELETE on `{{audit_table}}` raises | Pillar 7 structural |

Run as a SQL test suite on every migration PR. Failing any = blocking.

## RLS health check pg_cron — the silent canary

Already deployed in Tier 1. In Tier 6 we add the alerting wire-up:

```sql
-- Inside {{prefix}}_rls_health_check(), after the INSERT:
IF NOT v_passed THEN
  -- Queue an alert via existing notification infrastructure
  INSERT INTO {{notification_queue}} (event_type, recipient_email, payload, status)
  VALUES (
    'rls_health_check_failed',
    '<<<REPLACE-WITH-ON-CALL-EMAIL>>>',
    jsonb_build_object(
      'test_user_email', v_test_email,
      'visible_count', v_visible_count,
      'expected_min', v_expected_min,
      'severity', 'critical'
    ),
    'pending'
  );
END IF;
```

The alert wires into your project's notification system (Telegram, email, PagerDuty). The principle: if the RLS health check ever returns 0 visible rows for a known-good user, **someone gets paged immediately**.

## Sentry org tagging

Every Sentry event tagged with `org_slug`, `org_id`, `org_role`. Lets you filter the dashboard by `org_slug:tenant-x` and answer "why does this error fire only for this customer?"

In `useAuth.tsx`:
```typescript
useEffect(() => {
  const orgId = activeOrg?.id ?? null;
  if (lastSyncedOrgId.current === orgId) return;
  lastSyncedOrgId.current = orgId;
  if (activeOrg) {
    Sentry.setTag('org_slug', activeOrg.slug ?? 'unknown');
    Sentry.setTag('org_id', activeOrg.id);
    Sentry.setTag('org_role', activeMembership?.role ?? 'none');
  } else {
    Sentry.setTag('org_slug', 'none');
    Sentry.setTag('org_id', 'none');
    Sentry.setTag('org_role', 'none');
  }
}, [activeOrg, activeMembership]);
```

The `lastSyncedOrgId` ref prevents redundant tag-set calls on re-renders.

## CI regression greps

Add these to your CI:

```bash
# 1. No security_definer views (must use security_invoker)
psql -f - <<'SQL'
SELECT c.relname FROM pg_class c
WHERE c.relkind='v' AND c.relname LIKE 'v_%'
  AND NOT (c.reloptions @> ARRAY['security_invoker=on']);
SQL
# Expect zero rows. Failing rows = leak risk.

# 2. No qual=true SELECT policies on tenant tables
psql -f - <<'SQL'
SELECT schemaname, tablename, policyname FROM pg_policies
WHERE schemaname = 'public' AND cmd = 'SELECT' AND qual = 'true'
  AND tablename IN ('{{list_of_tenant_tables}}');
SQL
# Expect zero rows.

# 3. No FOR ALL policies on mutation-eligible tables
psql -f - <<'SQL'
SELECT schemaname, tablename, policyname FROM pg_policies
WHERE schemaname = 'public' AND cmd = 'ALL'
  AND tablename IN ('{{list_of_tenant_tables}}', '{{membership_table}}', '{{invite_table}}');
SQL
# Expect zero rows.

# 4. Helper function is STABLE
psql -f - <<'SQL'
SELECT proname, provolatile FROM pg_proc
WHERE proname = '{{prefix}}_user_org_ids' AND provolatile <> 's';
SQL
# Expect zero rows.

# 5. _v2 policies have a sunset comment
grep -E "_v2" supabase/migrations/*.sql | grep -v "SUNSET:"
# Expect empty (every _v2 should have an associated SUNSET comment).
```

Wire these into GitHub Actions or the equivalent. Failing = block merge.

## Observability dashboard

Build a small admin observability page (or use Supabase dashboard queries) showing:
1. **RLS health check trend** — `bb_rls_health_checks` time-series, alert when any failed in last 24h
2. **Audit log volume by event_type** — confirms triggers are firing across all event types
3. **Pending invite send_status breakdown** — alerts when `send_status='failed'` count grows
4. **Active orgs / total members / active members** — top-level org health
5. **Sentry filtered by org_slug** — per-tenant error rates

## Decommissioning legacy RLS policies (the _v2 sunset)

After Tier 6 ships and runs in prod for 1-2 weeks (per your `_v2` SUNSET dates), drop legacy policies in a follow-up migration:

```sql
-- Migration B: legacy policy drop (after _v2 verified)
DROP POLICY IF EXISTS "owner_view_properties_legacy" ON {{tenant_data_table}};
-- ... drop all _v2 predecessors ...

-- Optionally rename _v2 policies for cleanliness:
ALTER POLICY "org_members_view_properties_v2" ON {{tenant_data_table}}
  RENAME TO "org_members_view_properties";

-- Promote {{tenant_column}} to NOT NULL
ALTER TABLE {{tenant_data_table}} ALTER COLUMN {{tenant_column}} SET NOT NULL;
```

This is the "Migration B" gate referenced in Tier 1.

## Verification gate (skill complete)

All six tiers green:
- Tier 1: 5 verification queries pass
- Tier 2: 3 race/forgery/pagination tests pass
- Tier 3: 4 RPC-behavior tests pass
- Tier 4: 4 audit-trigger/append-only tests pass
- Tier 5: 4 frontend-integration tests pass
- Tier 6: 13 pen tests pass + 5 CI greps green

Plus: RLS health check has fired at least once with `passed=true`. Sentry shows org_slug tags. Real production user has invited at least one teammate end-to-end.

If all of this is green, you have shipped enterprise-grade multi-tenant auth.
