-- ════════════════════════════════════════════════════════════════════════════
-- Tier 4 — Append-Only Audit Log (Pillar 7 — RLS + structural triggers + revoke)
-- ════════════════════════════════════════════════════════════════════════════
-- Placeholders: {{prefix}}, {{org_table}}, {{membership_table}}, {{invite_table}}, {{audit_table}}
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Audit log table ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.{{audit_table}} (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id                uuid NOT NULL REFERENCES public.{{org_table}}(id) ON DELETE CASCADE,
  actor_user_id         uuid NULL,
  event_type            text NOT NULL CHECK (event_type IN (
    'member_invited','member_joined','member_role_changed','member_status_changed',
    'member_removed','invite_cancelled','ownership_transferred','invite_resent',
    'org_settings_changed'
  )),
  target_membership_id  uuid NULL REFERENCES public.{{membership_table}}(id) ON DELETE SET NULL,
  target_email          citext NULL,
  target_user_id        uuid NULL,
  before_value          jsonb NULL,
  after_value           jsonb NULL,
  metadata              jsonb NULL,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_{{audit_table}}_org_created
  ON public.{{audit_table}} (org_id, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_{{audit_table}}_target_membership
  ON public.{{audit_table}} (target_membership_id) WHERE target_membership_id IS NOT NULL;

-- ─── Layer 1: RLS policies (read scoped, no UPDATE/DELETE) ────────────────

ALTER TABLE public.{{audit_table}} ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_log_read ON public.{{audit_table}};
CREATE POLICY audit_log_read ON public.{{audit_table}}
  FOR SELECT TO authenticated
  USING (
    ((auth.jwt() ->> 'role'::text) = 'service_role'::text)
    OR public.{{prefix}}_is_org_owner_or_admin(auth.uid(), org_id)
  );

DROP POLICY IF EXISTS audit_log_insert ON public.{{audit_table}};
CREATE POLICY audit_log_insert ON public.{{audit_table}}
  FOR INSERT TO authenticated
  WITH CHECK (
    ((auth.jwt() ->> 'role'::text) = 'service_role'::text)
    OR public.{{prefix}}_is_org_owner_or_admin(auth.uid(), org_id)
  );

DROP POLICY IF EXISTS audit_log_no_update ON public.{{audit_table}};
CREATE POLICY audit_log_no_update ON public.{{audit_table}} FOR UPDATE USING (false);

DROP POLICY IF EXISTS audit_log_no_delete ON public.{{audit_table}};
CREATE POLICY audit_log_no_delete ON public.{{audit_table}} FOR DELETE USING (false);

-- ─── Layer 2: Structural BEFORE triggers ──────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_{{audit_table}}_no_mutate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '{{audit_table}} is append-only (operation % forbidden)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS trg_{{audit_table}}_no_update ON public.{{audit_table}};
CREATE TRIGGER trg_{{audit_table}}_no_update
  BEFORE UPDATE ON public.{{audit_table}}
  FOR EACH ROW EXECUTE FUNCTION public.fn_{{audit_table}}_no_mutate();

DROP TRIGGER IF EXISTS trg_{{audit_table}}_no_delete ON public.{{audit_table}};
CREATE TRIGGER trg_{{audit_table}}_no_delete
  BEFORE DELETE ON public.{{audit_table}}
  FOR EACH ROW EXECUTE FUNCTION public.fn_{{audit_table}}_no_mutate();

-- ─── Layer 3: Permission revoke (defense in depth) ────────────────────────

GRANT SELECT ON public.{{audit_table}} TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.{{audit_table}} FROM authenticated, anon, public;

-- ─── Capture trigger: {{membership_table}} ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_audit_{{membership_table}}()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_actor uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_actor := COALESCE(auth.uid(), NEW.user_id);  -- joiner is actor for self-init
    INSERT INTO public.{{audit_table}}
      (org_id, actor_user_id, event_type, target_membership_id, target_user_id, after_value)
    VALUES (NEW.org_id, v_actor, 'member_joined', NEW.id, NEW.user_id,
      jsonb_build_object('role', NEW.role, 'status', NEW.status));

  ELSIF TG_OP = 'UPDATE' THEN
    v_actor := auth.uid();
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      INSERT INTO public.{{audit_table}}
        (org_id, actor_user_id, event_type, target_membership_id, target_user_id,
         before_value, after_value)
      VALUES (NEW.org_id, v_actor, 'member_role_changed', NEW.id, NEW.user_id,
        jsonb_build_object('role', OLD.role),
        jsonb_build_object('role', NEW.role));
    END IF;
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      INSERT INTO public.{{audit_table}}
        (org_id, actor_user_id, event_type, target_membership_id, target_user_id,
         before_value, after_value)
      VALUES (NEW.org_id, v_actor, 'member_status_changed', NEW.id, NEW.user_id,
        jsonb_build_object('status', OLD.status),
        jsonb_build_object('status', NEW.status));
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    -- Skip cascade-deletes from org removal
    IF NOT EXISTS (SELECT 1 FROM public.{{org_table}} WHERE id = OLD.org_id) THEN
      RETURN OLD;
    END IF;
    v_actor := auth.uid();
    INSERT INTO public.{{audit_table}}
      (org_id, actor_user_id, event_type, target_membership_id, target_user_id, before_value)
    VALUES (OLD.org_id, v_actor, 'member_removed', OLD.id, OLD.user_id,
      jsonb_build_object('role', OLD.role, 'status', OLD.status));
  END IF;

  RETURN COALESCE(NEW, OLD);

EXCEPTION WHEN OTHERS THEN
  -- ZERO-REGRESSION GUARANTEE: audit must NEVER block parent business op
  RAISE WARNING '[audit-membership] % failed: %', TG_OP, SQLERRM;
  RETURN COALESCE(NEW, OLD);
END $$;

DROP TRIGGER IF EXISTS trg_audit_{{membership_table}} ON public.{{membership_table}};
CREATE TRIGGER trg_audit_{{membership_table}}
  AFTER INSERT OR UPDATE OR DELETE ON public.{{membership_table}}
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_{{membership_table}}();

-- ─── Capture trigger: {{invite_table}} ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_audit_{{invite_table}}()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_actor uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_actor := COALESCE(auth.uid(), NEW.invited_by);
    INSERT INTO public.{{audit_table}}
      (org_id, actor_user_id, event_type, target_email, metadata)
    VALUES (NEW.org_id, v_actor, 'member_invited', NEW.invited_email,
      jsonb_build_object('role', NEW.role, 'invite_id', NEW.id));

  ELSIF TG_OP = 'DELETE' THEN
    -- Skip already-claimed (accept path UPDATEs claimed_at, doesn't DELETE)
    IF OLD.claimed_at IS NOT NULL THEN RETURN OLD; END IF;
    -- Skip cascade from org-deletion
    IF NOT EXISTS (SELECT 1 FROM public.{{org_table}} WHERE id = OLD.org_id) THEN
      RETURN OLD;
    END IF;
    v_actor := auth.uid();  -- NO fallback to invited_by — would misattribute
    INSERT INTO public.{{audit_table}}
      (org_id, actor_user_id, event_type, target_email, metadata)
    VALUES (OLD.org_id, v_actor, 'invite_cancelled', OLD.invited_email,
      jsonb_build_object('role', OLD.role, 'invite_id', OLD.id));
  END IF;

  RETURN COALESCE(NEW, OLD);

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING '[audit-invite] % failed: %', TG_OP, SQLERRM;
  RETURN COALESCE(NEW, OLD);
END $$;

DROP TRIGGER IF EXISTS trg_audit_{{invite_table}} ON public.{{invite_table}};
CREATE TRIGGER trg_audit_{{invite_table}}
  AFTER INSERT OR DELETE ON public.{{invite_table}}
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_{{invite_table}}();

COMMIT;
NOTIFY pgrst, 'reload schema';
