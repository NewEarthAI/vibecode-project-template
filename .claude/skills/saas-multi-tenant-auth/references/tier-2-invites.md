# Tier 2 — Invitations

**What ships**: `{{invite_table}}`, `accept_invite_atomic` RPC, `get_auth_user_id_by_email` RPC, `send-invite` + `accept-invite` edge functions.
**Templates**: `02_invites.sql`, `send-invite-edge-function.ts`, `accept-invite-edge-function.ts`
**Verification gate**: two-tab race test passes (idempotent `already_claimed`); pagination-safe duplicate check returns correct user past 50-user threshold.

## Architecture

```
Admin clicks "Invite" → POST send-invite (auth required)
                     → JWT-derived inviter (Pillar 4)
                     → Pagination-safe duplicate check (Pillar 10, get_auth_user_id_by_email RPC)
                     → Insert/upsert {{invite_table}} with crypto-random token
                     → Resend API call → {send_status: 'sent'} or 'failed' with retry surface (Pillar 12)

Invitee clicks link  → /invite/accept?token=...&email=...
                     → POST accept-invite
                     → Lookup invite, check expiry, idempotent already_claimed (Pillar 5)
                     → Find-or-create auth.users (RPC, NOT listUsers — Pillar 10)
                     → accept_invite_atomic RPC (Pillar 5)
                     → 200 with {status: 'claimed' | 'already_claimed'}
```

## Critical schema details

```sql
CREATE TABLE {{invite_table}} (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              uuid NOT NULL REFERENCES {{org_table}}(id) ON DELETE CASCADE,
  invited_email       citext NOT NULL,                                     -- ← citext, not text
  role                text NOT NULL CHECK (role IN ('admin','manager','member')),
  invited_by          uuid REFERENCES auth.users(id),                      -- JWT-derived in edge fn
  token               text UNIQUE NOT NULL,                                -- 32+ char crypto-random
  expires_at          timestamptz NOT NULL,
  claimed_at          timestamptz,
  claimed_by          uuid REFERENCES auth.users(id),
  send_status         text NOT NULL DEFAULT 'pending'
                        CHECK (send_status IN ('pending','sent','failed')),
  send_error_message  text,
  sent_at             timestamptz,
  resend_message_id   text,                                                -- for delivery webhook correlation
  created_at          timestamptz NOT NULL DEFAULT now()
);

-- THE serializing index (Pillar 5)
CREATE UNIQUE INDEX idx_{{invite_table}}_token_unclaimed
  ON {{invite_table}}(token) WHERE claimed_at IS NULL;
```

`citext` (case-insensitive text) on `invited_email` matters because users type emails inconsistently. Without citext, `Alice@x.com` and `alice@x.com` produce duplicate invites.

## The atomic claim RPC

```sql
CREATE OR REPLACE FUNCTION public.accept_invite_atomic(
  p_token text,
  p_user_id uuid
) RETURNS {{membership_table}}
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite {{invite_table}}%ROWTYPE;
  v_membership {{membership_table}}%ROWTYPE;
BEGIN
  -- Conditional UPDATE serialized by partial unique index
  UPDATE {{invite_table}}
  SET claimed_at = now(), claimed_by = p_user_id
  WHERE token = p_token
    AND claimed_at IS NULL
    AND expires_at > now()
  RETURNING * INTO v_invite;

  IF v_invite.id IS NULL THEN
    RETURN NULL;  -- Already claimed, expired, or token invalid
  END IF;

  INSERT INTO {{membership_table}} (org_id, user_id, role, status, invited_by)
  VALUES (v_invite.org_id, p_user_id, v_invite.role, 'active', v_invite.invited_by)
  ON CONFLICT (org_id, user_id) DO NOTHING
  RETURNING * INTO v_membership;

  RETURN v_membership;
END $$;

GRANT EXECUTE ON FUNCTION public.accept_invite_atomic(text, uuid) TO service_role;
-- ↑ NOT to authenticated — accept-invite edge fn uses service_role
```

## Pagination-safe duplicate check RPC

```sql
CREATE OR REPLACE FUNCTION public.get_auth_user_id_by_email(p_email text)
RETURNS uuid
STABLE LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM auth.users WHERE lower(email) = lower(p_email) LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_auth_user_id_by_email(text) TO service_role;
```

Use this everywhere you need to check "does this email have an account?" Replace every `auth.admin.listUsers()` call.

## Edge function critical points

**send-invite** (`templates/send-invite-edge-function.ts`):
1. Two clients: `supabaseUser` (anon key + user JWT) for auth check; `supabaseAdmin` (service role) for DB writes
2. Caller MUST be `owner` or `admin` of target org — check via `{{membership_table}}` lookup
3. `invited_by` derived from `caller.id` ALWAYS (Pillar 4)
4. Idempotent: existing pending invite for (org_id, invited_email) gets refreshed token + expiry, not duplicate row
5. Resend failure → record `send_status='failed'` AND return 500 with `code: 'email_send_failed'` so UI shows Retry (Pillar 12)
6. Capture Resend `id` as `resend_message_id` for delivery-webhook correlation

**accept-invite** (`templates/accept-invite-edge-function.ts`):
1. Service role only (no user JWT needed — user may not be authenticated yet)
2. Already-claimed → 200 with `status: 'already_claimed'` (NEVER 4xx)
3. Existing email + password supplied → return `code: 'user_exists_use_login'` (400) so UI flips to sign-in form
4. Race-condition fallback: if RPC unavailable, manual claim sequence with conditional UPDATE + INSERT-with-conflict
5. Optional: inherit functional roles from inviter (e.g., `buyer`/`seller` flags) so new user skips role-setup prompt

## Verification gate (must pass before Tier 3)

### Test 1: Pagination-safe duplicate check
```sql
-- Seed 60 dummy users (test env only, NOT prod)
-- Then: try to invite the 55th user's email
-- Expected: edge fn returns 'already_member' or refreshes existing invite
-- Failure mode (if listUsers is still being used): "Failed to create user" 500
```

### Test 2: Two-tab race
```bash
# Use curl twice in parallel against accept-invite with same token
curl -X POST $URL/accept-invite -d '{"token":"X","password":"Y","display_name":"Z"}' &
curl -X POST $URL/accept-invite -d '{"token":"X","password":"Y","display_name":"Z"}' &
wait
# Expected: ONE returns status='claimed', the other returns status='already_claimed'.
# Both 200. Zero 500s. Exactly ONE row in {{membership_table}} for that user.
```

### Test 3: Body-derived audit forgery blocked
```bash
# Send {"invited_by": "<other-admin-uuid>"} in body
curl -X POST $URL/send-invite -H "Authorization: Bearer $JWT" \
  -d '{"org_id":"X","invited_email":"new@x.com","role":"member","invited_by":"<malicious-uuid>"}'

# Expected: invited_by in DB equals JWT caller's uid, NOT the body value
```

All three must pass. If Test 2 produces duplicate memberships, the partial unique index is missing or `accept_invite_atomic` was bypassed.
