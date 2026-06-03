-- ════════════════════════════════════════════════════════════════════════════
-- Tier 1 — Foundation Migration (parameterized)
-- saas-multi-tenant-auth skill — replace {{placeholders}} before running
-- ════════════════════════════════════════════════════════════════════════════
--
-- Placeholders to replace:
--   {{prefix}}              → e.g. bb, app, tenant
--   {{org_table}}           → e.g. bb_organizations
--   {{membership_table}}    → e.g. bb_org_memberships
--   {{tenant_data_table}}   → list of YOUR data tables (repeat block for each)
--   {{tenant_column}}       → e.g. org_id
--   {{owner_column}}        → e.g. owner_user_id
--   <<<TEST_USER_EMAIL>>>   → real production owner email (for RLS health check)
--
-- Manual gate before Migration B (NOT NULL promote):
--   SELECT count(*) FROM {{tenant_data_table}} WHERE {{tenant_column}} IS NULL;
--   -- expect 0
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─── Section 1: Core tables ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.{{org_table}} (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  slug            text UNIQUE NOT NULL,
  owner_user_id   uuid REFERENCES auth.users(id),
  brand_palette   text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);
CREATE INDEX IF NOT EXISTS idx_{{org_table}}_owner ON public.{{org_table}}(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_{{org_table}}_active ON public.{{org_table}}(slug) WHERE archived_at IS NULL;
ALTER TABLE public.{{org_table}} ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.{{membership_table}} (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid NOT NULL REFERENCES public.{{org_table}}(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('owner','admin','manager','member')),
  status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended')),
  joined_at   timestamptz NOT NULL DEFAULT now(),
  invited_by  uuid REFERENCES auth.users(id),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_{{membership_table}}_user ON public.{{membership_table}}(user_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_{{membership_table}}_org  ON public.{{membership_table}}(org_id)  WHERE status = 'active';
ALTER TABLE public.{{membership_table}} ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.{{prefix}}_rls_health_checks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checked_at      timestamptz NOT NULL DEFAULT now(),
  test_user_email text NOT NULL,
  visible_count   int NOT NULL,
  expected_min    int NOT NULL,
  passed          boolean NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_{{prefix}}_rls_health_recent
  ON public.{{prefix}}_rls_health_checks(checked_at DESC);
ALTER TABLE public.{{prefix}}_rls_health_checks ENABLE ROW LEVEL SECURITY;

-- ─── Section 2: Helper function (Pillar 8) ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.{{prefix}}_user_org_ids(p_user_id uuid)
RETURNS uuid[]
STABLE
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    ARRAY(
      SELECT org_id FROM public.{{membership_table}}
      WHERE user_id = p_user_id AND status = 'active'
    ),
    ARRAY[]::uuid[]
  );
$$;

GRANT EXECUTE ON FUNCTION public.{{prefix}}_user_org_ids(uuid) TO authenticated;

-- Helper for owner/admin checks (used by RPCs in Tier 3)
CREATE OR REPLACE FUNCTION public.{{prefix}}_is_org_owner_or_admin(p_user uuid, p_org uuid)
RETURNS boolean
STABLE LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.{{membership_table}}
    WHERE user_id = p_user AND org_id = p_org
      AND role IN ('owner','admin') AND status = 'active'
  );
$$;
GRANT EXECUTE ON FUNCTION public.{{prefix}}_is_org_owner_or_admin(uuid, uuid) TO authenticated;

-- ─── Section 3: Add tenant_column to existing data tables (NULLABLE) ──────
--
-- REPEAT THIS BLOCK FOR EACH OF YOUR DATA TABLES that need org scoping.
-- Use NULL initially, backfill in Section 4, promote to NOT NULL in Migration B.

ALTER TABLE public.{{tenant_data_table}}
  ADD COLUMN IF NOT EXISTS {{tenant_column}} uuid REFERENCES public.{{org_table}}(id),
  ADD COLUMN IF NOT EXISTS {{owner_column}}  uuid REFERENCES auth.users(id);

CREATE INDEX IF NOT EXISTS idx_{{tenant_data_table}}_{{tenant_column}}
  ON public.{{tenant_data_table}}({{tenant_column}});
CREATE INDEX IF NOT EXISTS idx_{{tenant_data_table}}_{{owner_column}}
  ON public.{{tenant_data_table}}({{owner_column}});

-- ─── Section 4: Backfill (choose ONE pattern) ──────────────────────────────

SET LOCAL session_replication_role = 'replica';  -- bypass triggers

-- Pattern A: single default org
-- INSERT INTO public.{{org_table}} (name, slug) VALUES ('Default', 'default')
--   ON CONFLICT (slug) DO NOTHING;
-- UPDATE public.{{tenant_data_table}}
--   SET {{tenant_column}} = (SELECT id FROM public.{{org_table}} WHERE slug = 'default')
--   WHERE {{tenant_column}} IS NULL;

-- Pattern B: source-aware (replace 'source_field' with your discriminator)
-- INSERT INTO public.{{org_table}} (name, slug) VALUES
--   ('Customer A', 'customer-a'), ('Customer B', 'customer-b')
--   ON CONFLICT (slug) DO NOTHING;
-- UPDATE public.{{tenant_data_table}} SET
--   {{tenant_column}} = CASE
--     WHEN source_field = 'A' THEN (SELECT id FROM public.{{org_table}} WHERE slug = 'customer-a')
--     WHEN source_field = 'B' THEN (SELECT id FROM public.{{org_table}} WHERE slug = 'customer-b')
--     ELSE (SELECT id FROM public.{{org_table}} WHERE slug = 'default')
--   END
--   WHERE {{tenant_column}} IS NULL;

-- Pattern C: per-user (consumer SaaS)
-- INSERT INTO public.{{org_table}} (name, slug, owner_user_id)
-- SELECT
--   COALESCE(raw_user_meta_data->>'full_name', email) || '''s Workspace',
--   'user-' || id::text, id
-- FROM auth.users ON CONFLICT (slug) DO NOTHING;

RESET session_replication_role;

-- ─── Section 5: RLS policies (additive _v2 with sunset) ────────────────────
--
-- SUNSET: <<<SET-DATE-HERE>>> — drop legacy policies once _v2 verified

DROP POLICY IF EXISTS "org_members_view_{{tenant_data_table}}_v2" ON public.{{tenant_data_table}};
CREATE POLICY "org_members_view_{{tenant_data_table}}_v2"
  ON public.{{tenant_data_table}}
  FOR SELECT TO authenticated
  USING ({{tenant_column}} IS NOT NULL
         AND {{tenant_column}} = ANY(public.{{prefix}}_user_org_ids(auth.uid())));

DROP POLICY IF EXISTS "owner_or_admin_edit_{{tenant_data_table}}_v2" ON public.{{tenant_data_table}};
CREATE POLICY "owner_or_admin_edit_{{tenant_data_table}}_v2"
  ON public.{{tenant_data_table}}
  FOR UPDATE TO authenticated
  USING (
    {{owner_column}} = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.{{membership_table}}
      WHERE user_id = auth.uid()
        AND org_id = public.{{tenant_data_table}}.{{tenant_column}}
        AND role IN ('owner','admin','manager')
        AND status = 'active'
    )
  )
  WITH CHECK ({{tenant_column}} = ANY(public.{{prefix}}_user_org_ids(auth.uid())));

-- Org table policies
DROP POLICY IF EXISTS "members_view_{{org_table}}" ON public.{{org_table}};
CREATE POLICY "members_view_{{org_table}}"
  ON public.{{org_table}}
  FOR SELECT TO authenticated
  USING (id = ANY(public.{{prefix}}_user_org_ids(auth.uid())));

DROP POLICY IF EXISTS "owner_admin_update_{{org_table}}" ON public.{{org_table}};
CREATE POLICY "owner_admin_update_{{org_table}}"
  ON public.{{org_table}}
  FOR UPDATE TO authenticated
  USING (public.{{prefix}}_is_org_owner_or_admin(auth.uid(), id));

-- Membership table policies
DROP POLICY IF EXISTS "members_view_own_{{membership_table}}" ON public.{{membership_table}};
CREATE POLICY "members_view_own_{{membership_table}}"
  ON public.{{membership_table}}
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR org_id = ANY(public.{{prefix}}_user_org_ids(auth.uid())));

DROP POLICY IF EXISTS "admin_only_view_{{prefix}}_rls_health_checks" ON public.{{prefix}}_rls_health_checks;
CREATE POLICY "admin_only_view_{{prefix}}_rls_health_checks"
  ON public.{{prefix}}_rls_health_checks
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.{{membership_table}} m
      WHERE m.user_id = auth.uid() AND m.role = 'owner' AND m.status = 'active'
    )
  );

-- ─── Section 6: RLS health check (Pillar — silent canary) ─────────────────

CREATE OR REPLACE FUNCTION public.{{prefix}}_rls_health_check()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_test_email    text := '<<<REPLACE-WITH-PROD-OWNER-EMAIL>>>';
  v_test_user_id  uuid;
  v_visible_count int;
  v_expected_min  int := 1;
BEGIN
  SELECT id INTO v_test_user_id FROM auth.users WHERE email = v_test_email;
  IF v_test_user_id IS NULL THEN
    INSERT INTO public.{{prefix}}_rls_health_checks(test_user_email, visible_count, expected_min, passed)
    VALUES (v_test_email, 0, v_expected_min, false);
    RETURN;
  END IF;

  SELECT count(*) INTO v_visible_count
  FROM public.{{tenant_data_table}}
  WHERE {{tenant_column}} = ANY(public.{{prefix}}_user_org_ids(v_test_user_id));

  INSERT INTO public.{{prefix}}_rls_health_checks(test_user_email, visible_count, expected_min, passed)
  VALUES (v_test_email, v_visible_count, v_expected_min, v_visible_count >= v_expected_min);
END $$;

-- ─── Section 7: pg_cron schedule (every 6h) ────────────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
      FROM cron.job WHERE jobname = '{{prefix}}-rls-health-check';
    PERFORM cron.schedule(
      '{{prefix}}-rls-health-check',
      '0 */6 * * *',
      $cron$SELECT public.{{prefix}}_rls_health_check();$cron$
    );
  ELSE
    RAISE NOTICE 'pg_cron not installed — schedule manually after enabling extension';
  END IF;
END $$;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- Verification (run AFTER commit)
-- ════════════════════════════════════════════════════════════════════════════
-- See references/verification-gates.md → Tier 1 → Tier 2 Gate
