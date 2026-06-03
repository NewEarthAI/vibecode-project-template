# Doctrine — The 12 Pillars in Depth

Each pillar has: the rule, the WHY (mechanism), the failure precedent (scar tissue), and the enforcement (how to keep it from regressing).

---

## Pillar 1 — `security_invoker=true` on every multi-tenant view

**Rule**: Any view that selects from a table with RLS MUST be created with `WITH (security_invoker=true)`.

**Why**: Postgres views run as their owner by default (typically `postgres`). RLS policies on base tables are evaluated against the **owner's** identity, not the caller. Without `security_invoker`, the view bypasses RLS entirely.

**Enforcement (CI grep)**:
```sql
SELECT c.relname FROM pg_class c
WHERE c.relkind='v'
  AND c.relname ~ 'v_(your|prefix|pattern)_'
  AND NOT (c.reloptions @> ARRAY['security_invoker=on']);
-- Expect zero rows.
```

Add this to your migration test suite. Failing rows = leak risk.

---

## Pillar 2 — `FOR ALL` policies are banned on mutation-eligible tables

**Rule**: Always split into `FOR INSERT` / `FOR UPDATE` / `FOR DELETE` with explicit `WITH CHECK`.

**Why**: `FOR ALL` defaults `WITH CHECK` to mirror `USING`, but if you later broaden `USING` for read access, you've silently broadened write access too. Explicit is safer than implicit.

**Pattern**:
```sql
-- WRONG
CREATE POLICY "members_manage" ON {{table}}
  FOR ALL TO authenticated
  USING (has_access(auth.uid(), org_id));

-- RIGHT
CREATE POLICY "members_select" ON {{table}}
  FOR SELECT TO authenticated
  USING (has_access(auth.uid(), org_id));
CREATE POLICY "members_insert" ON {{table}}
  FOR INSERT TO authenticated
  WITH CHECK (has_access(auth.uid(), org_id) AND owner_user_id = auth.uid());
CREATE POLICY "members_update" ON {{table}}
  FOR UPDATE TO authenticated
  USING (has_access(auth.uid(), org_id))
  WITH CHECK (has_access(auth.uid(), org_id));
CREATE POLICY "members_delete" ON {{table}}
  FOR DELETE TO authenticated
  USING (is_admin(auth.uid(), org_id));
```

---

## Pillar 3 — `qual = true` SELECT policies are FORBIDDEN

**Rule**: No `USING (true)` policies on tables with per-tenant data.

**Failure precedent**: BuyBox `dd_deal_reviews` shipped with `"Anyone can read reviews" USING (true)` — every authenticated user could read every other tenant's deal reviews. This was a multi-month leak that nobody noticed because the view layer above it appeared to filter correctly. Closed in `20260420150000_cm32_t2_4_deal_reviews_rls.sql`.

**Enforcement**:
```sql
-- Find all qual=true SELECT policies (they show as USING (true))
SELECT schemaname, tablename, policyname, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND cmd = 'SELECT'
  AND qual = 'true';
-- Expect empty for tenant tables.
```

If a table has no direct tenant column, scope via JOIN to a tenant-bearing parent.

---

## Pillar 4 — Identity is JWT-derived, NEVER from request body

**Rule**: `invited_by`, `actor_user_id`, `created_by`, `assigned_by` come from `auth.uid()` server-side or `caller.id` after `supabase.auth.getUser()` in edge functions. Never accept these from the request body.

**Why**: A body-derived identity is forgeable by any authenticated user. An admin could send `{"invited_by": "<other-admin-uuid>"}` and pin the audit trail to someone else.

**Pattern (edge function)**:
```typescript
// WRONG
const { invited_by } = await req.json();

// RIGHT
const { data: { user: caller } } = await supabaseUser.auth.getUser();
if (!caller) return errorResponse('Unauthenticated', 'unauthenticated', 401);
const inviterUserId = caller.id;  // authoritative, cannot be forged
```

**Pattern (RPC)**:
```sql
CREATE FUNCTION my_action(p_target_id uuid)
RETURNS ... LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_caller uuid := auth.uid();  -- ← the only source of truth
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated' USING ERRCODE = '42501';
  END IF;
  -- ... use v_caller, never accept caller from p_*
END $$;
```

---

## Pillar 5 — Atomic invite claim via RPC + partial unique index

**Rule**: Invite-acceptance is single-transaction atomic. Backed by a partial unique index that serializes claims at the database level.

**Why**: Two-tab race conditions are guaranteed once invite links are emailed. User opens email → clicks invite → opens it in two tabs (or refreshes) → both tabs hit accept-invite simultaneously. Without atomicity:
- Both create memberships → duplicate row
- Both try to update claimed_at → second one fails 500

**Pattern**:
```sql
-- 1. Partial unique index serializes the claim
CREATE UNIQUE INDEX idx_invites_token_unclaimed
  ON {{invite_table}}(token) WHERE claimed_at IS NULL;

-- 2. Atomic RPC
CREATE FUNCTION accept_invite_atomic(p_token text, p_user_id uuid)
RETURNS {{membership_table}}
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_invite {{invite_table}}%ROWTYPE;
        v_membership {{membership_table}}%ROWTYPE;
BEGIN
  -- Conditional UPDATE: only succeeds for unclaimed unexpired invites
  UPDATE {{invite_table}}
  SET claimed_at = now(), claimed_by = p_user_id
  WHERE token = p_token
    AND claimed_at IS NULL
    AND expires_at > now()
  RETURNING * INTO v_invite;

  IF v_invite.id IS NULL THEN
    RETURN NULL;  -- Already claimed or expired — caller treats as already_claimed
  END IF;

  INSERT INTO {{membership_table}} (org_id, user_id, role, status, invited_by)
  VALUES (v_invite.org_id, p_user_id, v_invite.role, 'active', v_invite.invited_by)
  ON CONFLICT (org_id, user_id) DO NOTHING
  RETURNING * INTO v_membership;

  RETURN v_membership;
END $$;
```

**Idempotency rule**: If the RPC returns NULL OR the unique-violation fires (`23505`), return **HTTP 200** with `status: "already_claimed"`. NEVER 4xx on race conditions — clients retry on network blip and idempotent success is non-negotiable.

---

## Pillar 6 — Owner-transfer is promote-BEFORE-demote in single tx

**Rule**: To transfer ownership, promote target to owner FIRST, then demote caller to admin. In one transaction.

**Why**: The last-owner guard trigger blocks demote-self if you're the only active owner. Reverse the order and the trigger fires on step 1, blocking the entire transfer.

**Pattern**:
```sql
CREATE FUNCTION transfer_ownership(p_to_membership_id uuid)
RETURNS TABLE (new_owner ..., old_owner ...)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_caller uuid := auth.uid();
        v_target {{membership_table}}%ROWTYPE;
BEGIN
  -- ... validation ...

  -- Step 1: Promote target. Org now has 2 active owners (transient state).
  UPDATE {{membership_table}} SET role = 'owner'
  WHERE id = p_to_membership_id;

  -- Step 2: Demote caller. Org returns to 1 active owner. Trigger satisfied.
  UPDATE {{membership_table}} SET role = 'admin'
  WHERE user_id = v_caller AND org_id = v_target.org_id AND role = 'owner';
END $$;
```

The trigger sees a valid 2-owner intermediate state and allows the demote.

---

## Pillar 7 — Append-only audit log = RLS deny + structural triggers

**Rule**: Audit tables enforce append-only at TWO layers:
1. RLS policies: `FOR UPDATE USING (false)` and `FOR DELETE USING (false)`
2. Structural triggers: `BEFORE UPDATE` / `BEFORE DELETE` that `RAISE EXCEPTION`

**Why**: RLS alone is bypassed by the table owner (postgres). Structural triggers raise even for postgres. Plus `REVOKE INSERT, UPDATE, DELETE FROM authenticated, anon, public` — capture triggers run as SECURITY DEFINER and bypass these revokes, but the revokes block any future migration that accidentally adds a permissive INSERT grant.

**Pattern**:
```sql
-- RLS layer
ALTER TABLE {{audit_table}} ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_no_update ON {{audit_table}} FOR UPDATE USING (false);
CREATE POLICY audit_no_delete ON {{audit_table}} FOR DELETE USING (false);

-- Structural layer
CREATE FUNCTION fn_{{audit_table}}_no_mutate() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '{{audit_table}} is append-only (operation % forbidden)', TG_OP
    USING ERRCODE = '42501';
END $$;

CREATE TRIGGER trg_{{audit_table}}_no_update BEFORE UPDATE ON {{audit_table}}
  FOR EACH ROW EXECUTE FUNCTION fn_{{audit_table}}_no_mutate();
CREATE TRIGGER trg_{{audit_table}}_no_delete BEFORE DELETE ON {{audit_table}}
  FOR EACH ROW EXECUTE FUNCTION fn_{{audit_table}}_no_mutate();

-- Revoke layer
REVOKE INSERT, UPDATE, DELETE ON {{audit_table}} FROM authenticated, anon, public;
```

Pen-test T13 (in `templates/05_pen_tests.sql`) verifies this.

---

## Pillar 8 — STABLE helper function for RLS predicates

**Rule**: The function that returns the user's active org IDs must be marked `STABLE`.

**Why**: `STABLE` enables Postgres to call the function once per query rather than once per row. Without it, RLS predicates re-execute the membership lookup per scanned row — N×N performance collapse on large tables.

**Pattern**:
```sql
CREATE OR REPLACE FUNCTION public.{{prefix}}_user_org_ids(p_user_id uuid)
RETURNS uuid[]
STABLE              -- ← critical
LANGUAGE sql
SECURITY DEFINER    -- ← bypass RLS on membership_table itself
SET search_path = public
AS $$
  SELECT COALESCE(ARRAY(
    SELECT org_id FROM public.{{membership_table}}
    WHERE user_id = p_user_id AND status = 'active'
  ), ARRAY[]::uuid[]);
$$;
```

`SECURITY DEFINER` is necessary because the calling user can't read their own memberships if the membership_table's own RLS predicate calls this function (circular dependency).

---

## Pillar 9 — `_v2` policy migration with sunset date

**Rule**: When replacing legacy RLS policies, additive `_v2` policies coexist with legacy until verified, then legacy is dropped. Every `_v2` migration declares a sunset date.

**Why**: Hot-replacing RLS policies risks production downtime if the new policy has a bug. Coexistence lets you verify under traffic before dropping the safety net. **But coexistence is bounded** — leaving _v2 policies forever creates ambiguity about which policy is authoritative.

**Pattern**:
```sql
-- SUNSET: 2026-05-20 — drop legacy "owner_view_properties" once _v2 verified
CREATE POLICY "org_members_view_properties_v2" ON {{tenant_data_table}}
  FOR SELECT TO authenticated
  USING ({{tenant_column}} = ANY({{prefix}}_user_org_ids(auth.uid())));
```

Open a follow-up issue pinned to the sunset date with the legacy-drop migration ready to go.

---

## Pillar 10 — Pagination-safe duplicate check (the `listUsers` trap)

**Rule**: NEVER use `supabase.auth.admin.listUsers()` for "does this email already have an account?" checks. Use a dedicated SECURITY DEFINER RPC.

**Why**: `listUsers()` paginates at 50 users/page by default. Code that doesn't iterate (the common case) silently misses every user past page 1.

**Failure precedent**: Production users with >50 auth users started getting `"Failed to create user account"` 500s when their email in fact already existed (page 2+). The bug shipped for weeks before being noticed because deployments under 50 users didn't trigger it.

**Fix**:
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

Edge function:
```typescript
// WRONG
const { data: { users } } = await supabaseAdmin.auth.admin.listUsers();
const existing = users.find(u => u.email === email);

// RIGHT
const { data: existingId } = await supabaseAdmin.rpc(
  'get_auth_user_id_by_email', { p_email: email }
);
```

---

## Pillar 11 — Org-switch invalidates ALL org-scoped queries + refreshes JWT

**Rule**: When the user switches active org, the client MUST:
1. Refresh JWT (`supabase.auth.refreshSession()`) — RLS sees new active membership claim
2. Invalidate all org-scoped query keys
3. Broadcast a window event so other hooks can teardown stale realtime channels

**Why**: TanStack Query has a 30-second `staleTime` default. Without explicit invalidation, the previous org's data stays visible for up to 30 seconds after switch. Realtime subscriptions filtered by `org_id=eq.${oldOrgId}` continue serving events for the wrong tenant. JWT membership claim is stale until refresh.

**Pattern** (see `templates/useOrganization.ts` for full):
```typescript
const switchOrg = useCallback((orgId: string) => {
  // ...validation...
  writeStoredOrgId(orgId);
  setActiveOrgId(orgId);

  // 1. Broadcast for stale-channel teardown
  window.dispatchEvent(new CustomEvent('app:org-switched', { detail: { orgId } }));

  // 2. Invalidate all org-scoped query keys (full enumeration required)
  queryClient.invalidateQueries({ queryKey: ['org-members'] });
  queryClient.invalidateQueries({ queryKey: ['org-memberships'] });
  // ... continue for every org-scoped queryKey in your app
}, [queryClient]);

// 3. JWT refresh on membership realtime change
useEffect(() => {
  const channel = supabase.channel(`memberships:${user.id}`)
    .on('postgres_changes', { event: '*', schema: 'public',
        table: '{{membership_table}}', filter: `user_id=eq.${user.id}` },
      async () => {
        await Promise.all([
          queryClient.invalidateQueries({ queryKey: ['org-memberships', user.id] }),
          supabase.auth.refreshSession(),  // ← RLS sees new claim
        ]);
      })
    .subscribe();
  return () => supabase.removeChannel(channel);
}, [user.id]);
```

---

## Pillar 12 — Every 4xx renders specific actionable UI state

**Rule**: No generic "Something went wrong." Every error response from edge functions returns `{ error, code, details? }`. Frontend error classifier maps `code` to actionable UI.

**Why**: Generic errors are dead-ends. Users don't know what to do. Support tickets pile up. Specific errors map to specific recovery actions.

**Standard error code → UI mapping**:

| code | HTTP | UI behavior |
|---|---|---|
| `unauthenticated` | 401 | Redirect to /auth |
| `forbidden` | 403 | "You don't have permission. Ask an admin." with admin email |
| `validation_error` | 400 | Show field-level errors |
| `user_exists_use_login` | 400 | Flip to sign-in form, prefill email |
| `already_member` | 400 | Toast + redirect to org dashboard |
| `invite_expired` | 410 | "Request a new invite" CTA |
| `email_send_failed` | 500 | Red Retry button (transient) |
| `db_error` | 500 | Generic + Sentry capture |
| `internal_error` | 500 | Generic + Sentry capture |

**Pattern (edge function)**:
```typescript
function errorResponse(error: string, code: string, status: number, details?) {
  return new Response(
    JSON.stringify({ error, code, ...(details ? { details } : {}) }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
```

**Pattern (frontend classifier)** — see `templates/error-classifier.ts`. Critical detail: `FunctionsHttpError.context` is a **raw `Response` object**, NOT a pre-parsed body. Read it once via `await ctx.json()`.

---

## Composition: how the pillars compose

- **Pillars 1-3** = read-side correctness (RLS doctrine)
- **Pillars 4-6, 10** = write-side correctness (identity, atomicity, ordering, pagination)
- **Pillar 7** = audit & compliance
- **Pillar 8-9** = performance + maintainability
- **Pillar 11-12** = client correctness + UX

Skip any one and you ship a multi-tenant system with a known failure mode. Ship all twelve and you have CM.32-grade quality.
