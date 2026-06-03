-- ════════════════════════════════════════════════════════════════════════════
-- Tier 3 — Team Management RPCs + Last-Owner Guard Trigger
-- ════════════════════════════════════════════════════════════════════════════
-- Placeholders: {{prefix}}, {{membership_table}}
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Last-owner guard trigger (Pillar 6 safety net) ───────────────────────

CREATE OR REPLACE FUNCTION public.{{prefix}}_block_last_owner_demote()
RETURNS trigger LANGUAGE plpgsql
AS $$
DECLARE v_active_owner_count int;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.role = 'owner' AND OLD.status = 'active'
       AND (NEW.role <> 'owner' OR NEW.status <> 'active') THEN
      SELECT count(*) INTO v_active_owner_count
      FROM public.{{membership_table}}
      WHERE org_id = OLD.org_id AND role = 'owner' AND status = 'active'
        AND id <> OLD.id;
      IF v_active_owner_count = 0 THEN
        RAISE EXCEPTION 'Cannot demote/suspend last active owner. Transfer ownership first.'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.role = 'owner' AND OLD.status = 'active' THEN
      SELECT count(*) INTO v_active_owner_count
      FROM public.{{membership_table}}
      WHERE org_id = OLD.org_id AND role = 'owner' AND status = 'active'
        AND id <> OLD.id;
      IF v_active_owner_count = 0 THEN
        RAISE EXCEPTION 'Cannot remove last active owner. Transfer ownership first.'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;

DROP TRIGGER IF EXISTS trg_{{prefix}}_block_last_owner_demote ON public.{{membership_table}};
CREATE TRIGGER trg_{{prefix}}_block_last_owner_demote
  BEFORE UPDATE OR DELETE ON public.{{membership_table}}
  FOR EACH ROW EXECUTE FUNCTION public.{{prefix}}_block_last_owner_demote();

-- ─── change_member_role ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.change_member_role(
  p_membership_id uuid,
  p_new_role text
) RETURNS public.{{membership_table}}
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_target public.{{membership_table}};
  v_result public.{{membership_table}};
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_new_role NOT IN ('owner','admin','manager','member') THEN
    RAISE EXCEPTION 'Invalid role: %' , p_new_role USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_target FROM public.{{membership_table}} WHERE id = p_membership_id;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Membership not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT public.{{prefix}}_is_org_owner_or_admin(v_caller, v_target.org_id) THEN
    RAISE EXCEPTION 'Only owners and admins can change roles' USING ERRCODE = '42501';
  END IF;

  -- Promotion to owner requires caller is also owner
  IF p_new_role = 'owner' AND NOT EXISTS (
    SELECT 1 FROM public.{{membership_table}}
    WHERE user_id = v_caller AND org_id = v_target.org_id
      AND role = 'owner' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Only an owner can promote to owner. Use transfer_ownership.'
      USING ERRCODE = '42501';
  END IF;

  IF v_target.role = p_new_role THEN
    RETURN v_target;  -- no-op
  END IF;

  UPDATE public.{{membership_table}}
  SET role = p_new_role, updated_at = now()
  WHERE id = p_membership_id
  RETURNING * INTO v_result;
  RETURN v_result;
END $$;

GRANT EXECUTE ON FUNCTION public.change_member_role(uuid, text) TO authenticated;

-- ─── set_member_status ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_member_status(
  p_membership_id uuid,
  p_new_status text
) RETURNS public.{{membership_table}}
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_target public.{{membership_table}};
  v_result public.{{membership_table}};
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_new_status NOT IN ('active','suspended') THEN
    RAISE EXCEPTION 'Invalid status: %', p_new_status USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_target FROM public.{{membership_table}} WHERE id = p_membership_id;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Membership not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT public.{{prefix}}_is_org_owner_or_admin(v_caller, v_target.org_id) THEN
    RAISE EXCEPTION 'Only owners and admins can change member status' USING ERRCODE = '42501';
  END IF;
  IF v_target.status = p_new_status THEN
    RETURN v_target;
  END IF;

  UPDATE public.{{membership_table}}
  SET status = p_new_status, updated_at = now()
  WHERE id = p_membership_id
  RETURNING * INTO v_result;
  RETURN v_result;
END $$;

GRANT EXECUTE ON FUNCTION public.set_member_status(uuid, text) TO authenticated;

-- ─── remove_member ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.remove_member(p_membership_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_target public.{{membership_table}};
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_target FROM public.{{membership_table}} WHERE id = p_membership_id;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Membership not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT public.{{prefix}}_is_org_owner_or_admin(v_caller, v_target.org_id) THEN
    RAISE EXCEPTION 'Only owners and admins can remove members' USING ERRCODE = '42501';
  END IF;
  IF v_target.user_id = v_caller THEN
    RAISE EXCEPTION 'You cannot remove yourself. Ask another admin or transfer ownership first.'
      USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.{{membership_table}} WHERE id = p_membership_id;
  RETURN p_membership_id;
END $$;

GRANT EXECUTE ON FUNCTION public.remove_member(uuid) TO authenticated;

-- ─── transfer_ownership (Pillar 6 — promote BEFORE demote, atomic) ────────

CREATE OR REPLACE FUNCTION public.transfer_ownership(p_to_membership_id uuid)
RETURNS TABLE (new_owner public.{{membership_table}}, old_owner public.{{membership_table}})
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller            uuid := auth.uid();
  v_target            public.{{membership_table}};
  v_caller_membership public.{{membership_table}};
  v_new_owner         public.{{membership_table}};
  v_old_owner         public.{{membership_table}};
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_target FROM public.{{membership_table}} WHERE id = p_to_membership_id;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Target membership not found' USING ERRCODE = 'P0002';
  END IF;

  -- Caller must be current owner
  SELECT * INTO v_caller_membership
  FROM public.{{membership_table}}
  WHERE user_id = v_caller AND org_id = v_target.org_id
    AND role = 'owner' AND status = 'active';
  IF v_caller_membership IS NULL THEN
    RAISE EXCEPTION 'Only the current owner can transfer ownership' USING ERRCODE = '42501';
  END IF;

  IF v_target.id = v_caller_membership.id THEN
    RAISE EXCEPTION 'Cannot transfer ownership to yourself' USING ERRCODE = '22023';
  END IF;
  IF v_target.status <> 'active' THEN
    RAISE EXCEPTION 'Target must be active' USING ERRCODE = '22023';
  END IF;

  -- Step 1: Promote target. Org now has 2 active owners (transient).
  UPDATE public.{{membership_table}} SET role = 'owner', updated_at = now()
  WHERE id = p_to_membership_id RETURNING * INTO v_new_owner;

  -- Step 2: Demote caller. Trigger sees 1 remaining owner → allowed.
  UPDATE public.{{membership_table}} SET role = 'admin', updated_at = now()
  WHERE id = v_caller_membership.id RETURNING * INTO v_old_owner;

  RETURN QUERY SELECT v_new_owner, v_old_owner;
END $$;

GRANT EXECUTE ON FUNCTION public.transfer_ownership(uuid) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
