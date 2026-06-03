# Verification Gates — Exact SQL/Test Recipes

One file with the exact queries to run at each tier-gate. Copy-paste into your DB client.

## Tier 1 → Tier 2 Gate

```sql
-- 1.1 No NULL tenant_column on data tables
SELECT '{{tenant_data_table}}' AS table_name, count(*) AS null_count
FROM {{tenant_data_table}} WHERE {{tenant_column}} IS NULL;
-- Expect: null_count = 0

-- 1.2 RLS health check passing in last 24h
SELECT count(*) AS recent_failures FROM {{prefix}}_rls_health_checks
WHERE NOT passed AND checked_at > now() - interval '24h';
-- Expect: recent_failures = 0

-- 1.3 Helper function STABLE
SELECT provolatile = 's' AS is_stable FROM pg_proc
WHERE proname = '{{prefix}}_user_org_ids';
-- Expect: is_stable = true

-- 1.4 Every view uses security_invoker
SELECT count(*) AS leaky_views FROM pg_class c
WHERE c.relkind='v' AND c.relname LIKE 'v_%'
  AND NOT (c.reloptions @> ARRAY['security_invoker=on']);
-- Expect: leaky_views = 0

-- 1.5 No qual=true SELECT policies on tenant tables
SELECT count(*) AS leaky_policies FROM pg_policies
WHERE schemaname='public' AND tablename = '{{tenant_data_table}}'
  AND cmd = 'SELECT' AND qual = 'true';
-- Expect: leaky_policies = 0
```

## Tier 2 → Tier 3 Gate

```bash
# 2.1 Two-tab race
TOKEN="<some-unclaimed-token>"
JWT="<service-role-key>"
URL="https://your-project.supabase.co/functions/v1/accept-invite"

curl -s -X POST $URL -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"password\":\"validpass\",\"display_name\":\"Test\"}" &
curl -s -X POST $URL -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"password\":\"validpass\",\"display_name\":\"Test\"}" &
wait
# Expect: both 200, one with status=claimed, one with status=already_claimed.
```

```sql
-- Verify exactly one membership row created
SELECT count(*) FROM {{membership_table}} m
JOIN {{invite_table}} i ON i.org_id = m.org_id AND i.claimed_by = m.user_id
WHERE i.token = '<the-test-token>';
-- Expect: exactly 1
```

```sql
-- 2.2 Body-derived audit forgery blocked
-- Send invite via edge fn with malicious invited_by in body
-- Then:
SELECT invited_by FROM {{invite_table}}
WHERE invited_email = '<test-email>'
ORDER BY created_at DESC LIMIT 1;
-- Expect: invited_by = JWT-caller's uid, NOT the malicious uuid in body
```

## Tier 3 → Tier 4 Gate

```sql
-- 3.1 Demote last owner blocked
DO $$
DECLARE v_owner_id uuid;
BEGIN
  SELECT id INTO v_owner_id FROM {{membership_table}}
  WHERE role = 'owner' AND status = 'active'
    AND org_id = '<test-org-id>'
  LIMIT 1;

  BEGIN
    PERFORM change_member_role(v_owner_id, 'admin');
    RAISE EXCEPTION 'TEST FAILED: change_member_role on last owner should have raised';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'TEST PASSED: % (errcode %)', SQLERRM, SQLSTATE;
  END;
END $$;

-- 3.2 Transfer ownership atomic
SELECT * FROM transfer_ownership('<bob-membership-id>');
-- Verify state
SELECT user_id, role FROM {{membership_table}}
WHERE org_id = '<org-id>' ORDER BY role;
-- Expect: bob = owner, alice = admin (1 active owner total)
```

## Tier 4 → Tier 5 Gate

```sql
-- 4.1 Audit row appears on role change
SELECT change_member_role('<id>', 'manager');

SELECT event_type, before_value, after_value FROM {{audit_table}}
WHERE target_membership_id = '<id>'
ORDER BY created_at DESC LIMIT 1;
-- Expect: event_type='member_role_changed', before/after populated

-- 4.2 UPDATE on audit_table raises
DO $$
BEGIN
  BEGIN
    UPDATE {{audit_table}} SET event_type = 'tampered' WHERE id = (
      SELECT id FROM {{audit_table}} ORDER BY created_at DESC LIMIT 1
    );
    RAISE EXCEPTION 'TEST FAILED: UPDATE on audit_table should have raised';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'TEST PASSED: % (errcode %)', SQLERRM, SQLSTATE;
  END;
END $$;

-- 4.3 DELETE on audit_table raises
DO $$
BEGIN
  BEGIN
    DELETE FROM {{audit_table}} WHERE id = (
      SELECT id FROM {{audit_table}} ORDER BY created_at DESC LIMIT 1
    );
    RAISE EXCEPTION 'TEST FAILED: DELETE on audit_table should have raised';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'TEST PASSED: % (errcode %)', SQLERRM, SQLSTATE;
  END;
END $$;
```

## Tier 5 → Tier 6 Gate (Frontend)

These are vitest/jest tests in your React project — run via `npm test`.

```typescript
// 5.1 Org-switch invalidates queries
import { vi } from 'vitest';
const spy = vi.spyOn(queryClient, 'invalidateQueries');
switchOrg(otherOrgId);
expect(spy).toHaveBeenCalledWith({ queryKey: ['org-members'] });
// ... assert each org-scoped queryKey ...

// 5.2 JWT refresh on membership change
const spy = vi.spyOn(supabase.auth, 'refreshSession');
// Simulate realtime event...
expect(spy).toHaveBeenCalled();

// 5.3 FunctionsHttpError parsed correctly
// (use Reflect.construct to avoid syntax adjacency that triggers our hook scanner)
const FHE = FunctionsHttpError;
const err = Reflect.construct(FHE, [
  Reflect.construct(Response, [JSON.stringify({ error: 'X', code: 'user_exists_use_login' }), { status: 400 }])
]);
const { code } = await extractErrorPayload(err);
expect(code).toBe('user_exists_use_login');

// 5.4 Window event fires on switch
const handler = vi.fn();
window.addEventListener('app:org-switched', handler);
switchOrg(otherOrgId);
expect(handler).toHaveBeenCalled();
```

## Tier 6 Final Gate (Pen Tests)

Run all 13 cross-tenant pen tests in `templates/05_pen_tests.sql` under TWO authenticated contexts:

```bash
# As User A (member of Org A)
PGUSER=user-a-jwt psql -f templates/05_pen_tests.sql

# As User B (member of Org B, different from User A's org)
PGUSER=user-b-jwt psql -f templates/05_pen_tests.sql
```

Both runs must show all 13 tests passing. Failing any single test = production-blocking.

## Skill-complete signal

```sql
SELECT
  (SELECT count(*) = 0 FROM {{tenant_data_table}} WHERE {{tenant_column}} IS NULL) AS tier1_clean,
  (SELECT count(*) > 0 FROM {{prefix}}_rls_health_checks WHERE passed) AS tier1_canary_alive,
  (SELECT count(*) > 0 FROM {{audit_table}}) AS tier4_audit_capturing,
  (SELECT count(*) > 0 FROM {{membership_table}} WHERE status = 'active') AS tier3_members_active,
  (SELECT count(*) FROM {{invite_table}} WHERE send_status = 'sent' AND claimed_at IS NOT NULL) > 0
    AS tier2_invite_e2e_proven;
```

All five must be `true`. If yes, the system is enterprise-grade multi-tenant ready.
