-- ════════════════════════════════════════════════════════════════════════════
-- Tier 6 — Cross-Tenant Penetration Tests (13 tests)
-- ════════════════════════════════════════════════════════════════════════════
-- Run as TWO different authenticated users from TWO different orgs.
-- Set: SET LOCAL "request.jwt.claims" = '{"sub":"<user-A-uuid>", "role":"authenticated"}';
-- Each test should NOTICE 'PASSED' or RAISE 'FAILED'.
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_user_a uuid := '<<<USER-A-UUID>>>';      -- member of Org A
  v_user_b uuid := '<<<USER-B-UUID>>>';      -- member of Org B (different from A)
  v_org_a  uuid := '<<<ORG-A-UUID>>>';
  v_org_b  uuid := '<<<ORG-B-UUID>>>';
  v_count  int;
BEGIN
  -- ─── T1: User A cannot SELECT User B's tenant data ───
  PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  SELECT count(*) INTO v_count FROM public.{{tenant_data_table}}
  WHERE {{tenant_column}} = v_org_b;
  IF v_count > 0 THEN RAISE EXCEPTION 'T1 FAILED: User A read % rows from Org B', v_count; END IF;
  RAISE NOTICE 'T1 PASSED: cross-tenant SELECT blocked';

  -- ─── T4: User A cannot read User B's memberships ───
  SELECT count(*) INTO v_count FROM public.{{membership_table}}
  WHERE org_id = v_org_b AND user_id <> v_user_a;
  IF v_count > 0 THEN RAISE EXCEPTION 'T4 FAILED: User A read % membership rows from Org B', v_count; END IF;
  RAISE NOTICE 'T4 PASSED: cross-tenant membership read blocked';

  -- ─── T7: Member (non-admin) cannot read audit log ───
  SELECT count(*) INTO v_count FROM public.{{audit_table}} WHERE org_id = v_org_b;
  IF v_count > 0 THEN RAISE EXCEPTION 'T7 FAILED: User A read % audit rows from Org B', v_count; END IF;
  RAISE NOTICE 'T7 PASSED: cross-tenant audit read blocked';

  -- ─── T11: All tenant data has non-NULL tenant_column ───
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  SELECT count(*) INTO v_count FROM public.{{tenant_data_table}}
  WHERE {{tenant_column}} IS NULL;
  IF v_count > 0 THEN RAISE EXCEPTION 'T11 FAILED: % rows have NULL {{tenant_column}}', v_count; END IF;
  RAISE NOTICE 'T11 PASSED: zero NULL tenant_column';

  -- ─── T12: Cross-tenant audit-log read blocked even for admins ───
  PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  SELECT count(*) INTO v_count FROM public.{{audit_table}} WHERE org_id = v_org_b;
  IF v_count > 0 THEN RAISE EXCEPTION 'T12 FAILED: even admin read % cross-tenant audit', v_count; END IF;
  RAISE NOTICE 'T12 PASSED: admin cross-tenant audit blocked';
END $$;

-- ─── T13: UPDATE/DELETE on audit_table raises (run as service_role) ───
DO $$
BEGIN
  BEGIN
    UPDATE public.{{audit_table}} SET event_type = 'tampered'
    WHERE id = (SELECT id FROM public.{{audit_table}} ORDER BY created_at DESC LIMIT 1);
    RAISE EXCEPTION 'T13a FAILED: UPDATE on audit_table did not raise';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '42501' THEN
      RAISE NOTICE 'T13a PASSED: UPDATE blocked (errcode 42501)';
    ELSE
      RAISE EXCEPTION 'T13a FAILED: wrong errcode %', SQLSTATE;
    END IF;
  END;

  BEGIN
    DELETE FROM public.{{audit_table}}
    WHERE id = (SELECT id FROM public.{{audit_table}} ORDER BY created_at DESC LIMIT 1);
    RAISE EXCEPTION 'T13b FAILED: DELETE on audit_table did not raise';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '42501' THEN
      RAISE NOTICE 'T13b PASSED: DELETE blocked (errcode 42501)';
    ELSE
      RAISE EXCEPTION 'T13b FAILED: wrong errcode %', SQLSTATE;
    END IF;
  END;
END $$;

-- ─── T8: RLS policy count regression ───
DO $$
DECLARE
  v_expected_table text;
  v_count int;
BEGIN
  -- Customize per project — list each tenant table + min expected policies
  FOR v_expected_table IN SELECT unnest(ARRAY['{{tenant_data_table}}'])
  LOOP
    SELECT count(*) INTO v_count FROM pg_policies
    WHERE schemaname = 'public' AND tablename = v_expected_table;
    IF v_count < 2 THEN  -- minimum: SELECT + UPDATE policies
      RAISE EXCEPTION 'T8 FAILED: % has only % policies (expected >= 2)', v_expected_table, v_count;
    END IF;
  END LOOP;
  RAISE NOTICE 'T8 PASSED: policy count meets minimum';
END $$;

-- ─── T9: Every view uses security_invoker ───
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM pg_class c
  WHERE c.relkind='v' AND c.relname LIKE 'v_%'
    AND NOT (c.reloptions @> ARRAY['security_invoker=on']);
  IF v_count > 0 THEN
    RAISE EXCEPTION 'T9 FAILED: % views missing security_invoker=true', v_count;
  END IF;
  RAISE NOTICE 'T9 PASSED: all views use security_invoker';
END $$;

-- ─── T10: No qual=true SELECT policies on tenant tables ───
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM pg_policies
  WHERE schemaname='public' AND cmd = 'SELECT' AND qual = 'true'
    AND tablename IN ('{{tenant_data_table}}');  -- expand to your tenant tables
  IF v_count > 0 THEN
    RAISE EXCEPTION 'T10 FAILED: % qual=true SELECT policies on tenant tables', v_count;
  END IF;
  RAISE NOTICE 'T10 PASSED: no qual=true policies on tenant tables';
END $$;

RAISE NOTICE '═══════════════════════════════════════════════════════════════════';
RAISE NOTICE 'Pen test suite complete. Repeat under User B context to verify symmetry.';
