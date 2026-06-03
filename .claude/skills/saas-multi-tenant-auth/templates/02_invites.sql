-- ════════════════════════════════════════════════════════════════════════════
-- Tier 2 — Invitations Migration
-- ════════════════════════════════════════════════════════════════════════════
-- Placeholders: {{prefix}}, {{org_table}}, {{membership_table}}, {{invite_table}}
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Pending invites table ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.{{invite_table}} (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              uuid NOT NULL REFERENCES public.{{org_table}}(id) ON DELETE CASCADE,
  invited_email       citext NOT NULL,
  role                text NOT NULL CHECK (role IN ('admin','manager','member')),
  invited_by          uuid REFERENCES auth.users(id),
  token               text UNIQUE NOT NULL,
  expires_at          timestamptz NOT NULL,
  claimed_at          timestamptz,
  claimed_by          uuid REFERENCES auth.users(id),
  send_status         text NOT NULL DEFAULT 'pending'
                        CHECK (send_status IN ('pending','sent','failed')),
  send_error_message  text,
  sent_at             timestamptz,
  resend_message_id   text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

-- THE serializing index (Pillar 5)
CREATE UNIQUE INDEX IF NOT EXISTS idx_{{invite_table}}_token_unclaimed
  ON public.{{invite_table}}(token) WHERE claimed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_{{invite_table}}_org    ON public.{{invite_table}}(org_id);
CREATE INDEX IF NOT EXISTS idx_{{invite_table}}_email  ON public.{{invite_table}}(invited_email);

ALTER TABLE public.{{invite_table}} ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "org_admins_view_{{invite_table}}" ON public.{{invite_table}};
CREATE POLICY "org_admins_view_{{invite_table}}"
  ON public.{{invite_table}}
  FOR SELECT TO authenticated
  USING (public.{{prefix}}_is_org_owner_or_admin(auth.uid(), org_id));

-- DELETE/UPDATE policies for invite cancellation + send-retry
DROP POLICY IF EXISTS "org_admins_delete_{{invite_table}}" ON public.{{invite_table}};
CREATE POLICY "org_admins_delete_{{invite_table}}"
  ON public.{{invite_table}}
  FOR DELETE TO authenticated
  USING (public.{{prefix}}_is_org_owner_or_admin(auth.uid(), org_id) AND claimed_at IS NULL);

-- ─── Pagination-safe duplicate check RPC (Pillar 10) ──────────────────────

CREATE OR REPLACE FUNCTION public.get_auth_user_id_by_email(p_email text)
RETURNS uuid
STABLE LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM auth.users WHERE lower(email) = lower(p_email) LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) TO service_role;

-- ─── Atomic invite-claim RPC (Pillar 5) ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.accept_invite_atomic(
  p_token text,
  p_user_id uuid
) RETURNS public.{{membership_table}}
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite     public.{{invite_table}}%ROWTYPE;
  v_membership public.{{membership_table}}%ROWTYPE;
BEGIN
  -- Conditional UPDATE — only succeeds for unclaimed unexpired invites.
  -- Partial unique index `WHERE claimed_at IS NULL` serializes the claim.
  UPDATE public.{{invite_table}}
  SET claimed_at = now(), claimed_by = p_user_id
  WHERE token = p_token
    AND claimed_at IS NULL
    AND expires_at > now()
  RETURNING * INTO v_invite;

  IF v_invite.id IS NULL THEN
    RETURN NULL;  -- already claimed, expired, or invalid token
  END IF;

  INSERT INTO public.{{membership_table}}
    (org_id, user_id, role, status, invited_by)
  VALUES
    (v_invite.org_id, p_user_id, v_invite.role, 'active', v_invite.invited_by)
  ON CONFLICT (org_id, user_id) DO NOTHING
  RETURNING * INTO v_membership;

  RETURN v_membership;
END $$;

GRANT EXECUTE ON FUNCTION public.accept_invite_atomic(text, uuid) TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
