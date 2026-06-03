# Tier 1 — Foundation

**What ships**: Tables, helper functions, RLS policies, backfill, pg_cron health check.
**Template**: `templates/01_foundation.sql`
**Verification gate**: zero NULL `{{tenant_column}}` on existing data tables; RLS health check returns >0 visible rows.

## What you're building

```
{{org_table}}             ← organizations themselves
{{membership_table}}      ← user × org × role
{{prefix}}_user_org_ids() ← STABLE helper for RLS predicates
v_my_view                 ← any new view, with security_invoker=true
```

Plus: `{{tenant_column}}` (org_id) added as NULLABLE to every existing data table, then backfilled, then promoted to NOT NULL after verification.

## Migration sequence

1. **Apply `templates/01_foundation.sql`** with placeholders substituted
2. **Run backfill** — assign `{{tenant_column}}` to every existing row based on your routing rule (per-source / per-user / single default)
3. **Verify zero NULLs**
4. **Promote to NOT NULL** in a follow-up migration (Migration B in two-phase pattern)

Do NOT attempt single-migration NOT NULL promotion. Backfill failures need to be fixable without rolling back the entire schema change.

## Routing rules for backfill

Choose one:

### A. Single default org (simplest)

For projects where every existing user becomes a member of one default org:
```sql
INSERT INTO {{org_table}} (name, slug) VALUES ('Default Org', 'default');
UPDATE {{tenant_data_table}}
SET {{tenant_column}} = (SELECT id FROM {{org_table}} WHERE slug = 'default')
WHERE {{tenant_column}} IS NULL;
```

### B. Source-aware segmentation (a SaaS app CM.32 pattern)

For projects where existing data has a discriminator column (`source`, `customer_id`, etc):
```sql
INSERT INTO {{org_table}} (name, slug) VALUES
  ('Customer A', 'customer-a'),
  ('Customer B', 'customer-b'),
  ('System', 'system');

UPDATE {{tenant_data_table}} SET
  {{tenant_column}} = CASE
    WHEN source ILIKE 'customer-a%' THEN (SELECT id FROM {{org_table}} WHERE slug = 'customer-a')
    WHEN source ILIKE 'customer-b%' THEN (SELECT id FROM {{org_table}} WHERE slug = 'customer-b')
    ELSE (SELECT id FROM {{org_table}} WHERE slug = 'system')
  END,
  org_id_review_needed = (source IS NULL OR source NOT IN ('customer-a', 'customer-b'))
WHERE {{tenant_column}} IS NULL;
```

`org_id_review_needed = true` flags rows where the routing rule fell through to the default — admin reviews these manually.

### C. Per-user organizations (consumer SaaS pattern)

Every existing user gets their own personal org:
```sql
INSERT INTO {{org_table}} (name, slug, owner_user_id)
SELECT
  COALESCE(raw_user_meta_data->>'full_name', email) || ''s Workspace',
  'user-' || id::text,
  id
FROM auth.users
ON CONFLICT (slug) DO NOTHING;

INSERT INTO {{membership_table}} (org_id, user_id, role, status)
SELECT
  (SELECT id FROM {{org_table}} WHERE owner_user_id = u.id),
  u.id, 'owner', 'active'
FROM auth.users u
ON CONFLICT (org_id, user_id) DO NOTHING;
```

## Bypass triggers during backfill

```sql
SET LOCAL session_replication_role = 'replica';
-- ... your backfill UPDATEs ...
RESET session_replication_role;
```

Without this, every row update triggers any custom triggers on the table — slow on millions of rows AND can fire side-effect triggers (notifications, syncs) that you don't want during backfill.

**Safety FYI**: This bypasses RLS too. Only do this in migration scope, never in application code.

## RLS policy authoring

Per Pillar 2: split FOR INSERT / FOR UPDATE / FOR DELETE explicitly. Per Pillar 3: never `qual = true`.

```sql
-- SELECT: members of the org can read
CREATE POLICY "org_members_view_{{tenant_data_table}}_v2"
  ON {{tenant_data_table}}
  FOR SELECT TO authenticated
  USING ({{tenant_column}} IS NOT NULL
         AND {{tenant_column}} = ANY({{prefix}}_user_org_ids(auth.uid())));

-- UPDATE: row owner OR admin/manager can edit
CREATE POLICY "owner_or_admin_edit_{{tenant_data_table}}_v2"
  ON {{tenant_data_table}}
  FOR UPDATE TO authenticated
  USING (
    {{owner_column}} = auth.uid()
    OR EXISTS (
      SELECT 1 FROM {{membership_table}}
      WHERE user_id = auth.uid()
        AND org_id = {{tenant_data_table}}.{{tenant_column}}
        AND role IN ('owner','admin','manager')
        AND status = 'active'
    )
  )
  WITH CHECK ({{tenant_column}} = ANY({{prefix}}_user_org_ids(auth.uid())));
-- ↑ WITH CHECK prevents updating the row to a different tenant
```

Pillar 9: keep legacy policies during _v2 phase, drop in a follow-up migration.

## RLS health check (pg_cron)

```sql
CREATE OR REPLACE FUNCTION public.{{prefix}}_rls_health_check()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_test_email   text := '<<<REPLACE-WITH-PROD-OWNER-EMAIL>>>';
  v_test_user_id uuid;
  v_visible_count int;
BEGIN
  SELECT id INTO v_test_user_id FROM auth.users WHERE email = v_test_email;
  IF v_test_user_id IS NULL THEN
    INSERT INTO {{prefix}}_rls_health_checks(test_user_email, visible_count, expected_min, passed)
    VALUES (v_test_email, 0, 1, false);
    RETURN;
  END IF;

  SELECT count(*) INTO v_visible_count
  FROM {{tenant_data_table}}
  WHERE {{tenant_column}} = ANY({{prefix}}_user_org_ids(v_test_user_id));

  INSERT INTO {{prefix}}_rls_health_checks(test_user_email, visible_count, expected_min, passed)
  VALUES (v_test_email, v_visible_count, 1, v_visible_count >= 1);
END $$;

-- Schedule
SELECT cron.schedule('{{prefix}}-rls-health-check', '0 */6 * * *',
  $$SELECT public.{{prefix}}_rls_health_check();$$);
```

**Critical**: Replace `<<<REPLACE-WITH-PROD-OWNER-EMAIL>>>` with a real production owner who is active and has at least 1 row of data visible. Defaulting this to a placeholder = silent alarm forever.

## Verification gate (must pass before Tier 2)

```sql
-- 1. No NULL tenant_columns
SELECT count(*) FROM {{tenant_data_table}} WHERE {{tenant_column}} IS NULL;
-- Expect 0

-- 2. RLS health check passing
SELECT count(*) FROM {{prefix}}_rls_health_checks
WHERE NOT passed AND checked_at > now() - interval '24h';
-- Expect 0

-- 3. Helper function exists and STABLE
SELECT proname, provolatile FROM pg_proc
WHERE proname = '{{prefix}}_user_org_ids';
-- Expect 's' for STABLE in provolatile column

-- 4. Every new view uses security_invoker
SELECT c.relname FROM pg_class c
WHERE c.relkind='v' AND c.relname LIKE 'v_%'
  AND NOT (c.reloptions @> ARRAY['security_invoker=on']);
-- Expect 0 rows

-- 5. No qual=true SELECT policies on tenant tables
SELECT schemaname, tablename, policyname FROM pg_policies
WHERE schemaname='public'
  AND tablename = '{{tenant_data_table}}'
  AND cmd = 'SELECT' AND qual = 'true';
-- Expect 0 rows
```

All five must pass. If any fails, stop and resolve before proceeding to Tier 2.

## What NOT to do in Tier 1

- ❌ Promote `{{tenant_column}}` to NOT NULL in the same migration as the ADD COLUMN
- ❌ Drop legacy RLS policies before _v2 verified under load
- ❌ Skip the RLS health check ("we'll add monitoring later")
- ❌ Use `FOR ALL` policies because they're "shorter"
- ❌ Default the test_user_email to a placeholder
