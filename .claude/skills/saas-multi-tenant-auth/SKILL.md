---
name: saas-multi-tenant-auth
description: |
  Bootstrap a SaaS-ready multi-tenant authentication and sub-user system on Supabase + React + TanStack Query.
  Use when adding organizations, teams, RBAC, invitation flows, or audit logging to a project. Also use when
  the request involves: "set up multi-tenant auth", "add organization/team support", "build sub-users",
  "create user invitation system", "add RBAC", "audit log for team actions", or hardening an existing
  single-tenant app for SaaS launch. Provides a six-tier shipping plan with explicit gate criteria, twelve
  non-negotiable doctrinal rules with named failure precedents (RLS leaks, audit forgery, race conditions,
  last-owner trap, listUsers pagination silent miss), parameterized SQL/Edge Function/React templates,
  and runtime verification gates. Skips for single-tenant apps, mobile-only auth, or projects without
  Supabase. Composes with `better-auth-security` (alternative auth library), `saas-platforms` (strategy
  layer), and `master-security-review` (post-build audit).
classification: encoded-preference
version: 1.0
created: 2026-04-28
updated: 2026-04-28
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
parameters:
  - name: prefix
    type: string
    default: bb
    description: Table prefix for new multi-tenant tables (e.g., bb, app, tenant)
  - name: org_table
    type: string
    default: "{{prefix}}_organizations"
  - name: membership_table
    type: string
    default: "{{prefix}}_org_memberships"
  - name: invite_table
    type: string
    default: "{{prefix}}_pending_invites"
  - name: audit_table
    type: string
    default: "{{prefix}}_org_audit_log"
  - name: tenant_column
    type: string
    default: org_id
  - name: owner_column
    type: string
    default: owner_user_id
  - name: tenant_data_tables
    type: list
    default: []
    description: Existing tables that need org_id column added + RLS policies (e.g., [users, projects, deals])
  - name: frontend_url
    type: url
    default: ""
  - name: from_email
    type: email
    default: noreply@example.com
validated_on:
  - "a SaaS app CM.32 (origin — 4 phases shipped 2026-04-19 to 2026-04-21, zero post-merge regressions)"
  - "Held-out: any Supabase + React project with RLS-on tables and a per-user auth.users base"
---

# SaaS Multi-Tenant Auth — The Ultimate Bootstrap Skill

## Purpose

Ship enterprise-grade multi-tenant auth in six tiers with verification gates between each. Twelve doctrinal rules — each with a named failure precedent — lock the architecture against the silent failure modes that kill multi-tenant apps after launch (RLS leaks, audit-trail forgery, two-tab race conditions, last-owner lockout, listUsers pagination misses).

This skill is **executable**, not just educational. Read SKILL.md for the doctrine + tier map; load `references/tier-N-*.md` files when shipping each tier; copy `templates/*.sql` and `templates/*.ts` with placeholder substitution; run `scripts/verify-tier-N.sh` at each gate.

## When to invoke this skill

Trigger on any of:
- "Set up multi-tenant auth"
- "Add organizations / teams / sub-users"
- "Build SaaS-ready auth"
- "Create invitation system" / "send team invites"
- "Add RBAC with roles" (owner / admin / manager / member)
- "Audit log for team actions"
- "Harden single-tenant app for SaaS launch"
- Symptom: "users can see each other's data" → skip to **Tier 1 doctrine + verification queries**

Do NOT trigger on:
- Single-tenant apps with no team concept
- Mobile-only auth flows
- Projects without Supabase (use `better-auth-security` instead)
- General "security review" — use `master-security-review`

## Stack assumptions

This skill is opinionated. It assumes:
- **Database**: Supabase Postgres with RLS enabled
- **Frontend**: React + TanStack Query + Vite (adapt patterns for Next.js / Remix as needed)
- **Email**: Resend (templates use Resend API; swap for Postmark/SendGrid by replacing the fetch call in `send-invite-edge-function.ts`)
- **Required Postgres extensions**: `citext`, `pgcrypto`, `pg_cron` (for the RLS health check)
- **Required env vars**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `FRONTEND_URL`, `INVITE_FROM_EMAIL`

If any assumption breaks, the skill output remains useful as a doctrine reference but the templates need adaptation.

## The Six-Tier Shipping Plan

```
Tier 1 — Foundation        → bootstrap tables, helper fn, additive RLS, backfill
   ↓ Gate: zero NULL tenant_column on existing data tables
Tier 2 — Invitations       → send/accept edge functions + atomic claim RPC
   ↓ Gate: two-tab race test passes (idempotent already_claimed)
Tier 3 — Team management   → role/status/remove/transfer RPCs + last-owner trigger
   ↓ Gate: owner-transfer atomic test passes
Tier 4 — Audit log         → append-only table + RLS deny + structural triggers + capture triggers
   ↓ Gate: pen-test T13 (UPDATE/DELETE on audit_log raises) passes
Tier 5 — UI integration    → AuthProvider + useOrganization + OrgSwitcher + Team page + InviteAccept
   ↓ Gate: org-switch invalidates all org-scoped queries + JWT refresh fires
Tier 6 — Hardening         → cross-tenant pen tests + RLS health check pg_cron + observability
   ↓ Gate: pen-test suite passes 100% + RLS health check returns >0 visible rows
```

**Each tier has a dedicated reference file** (`references/tier-N-*.md`) with full SQL/TypeScript and a verification script (`scripts/verify-tier-N.sh`). Do not skip tiers. Do not skip gates.

## The Twelve Doctrinal Pillars

These are NON-NEGOTIABLE. Every named pillar has an associated failure precedent — this is not theoretical advice, it is scar tissue.

### Pillar 1 — `security_invoker=true` on every multi-tenant view

Postgres views default to SECURITY DEFINER semantics, BYPASSING the RLS on base tables. A view of multi-tenant data without `security_invoker=true` will leak across tenants the moment any user has a `qual=true` SELECT on the view itself.

```sql
CREATE OR REPLACE VIEW v_my_view WITH (security_invoker=true) AS ...
```

CI grep guard: see `references/tier-6-hardening.md` § Regression Greps.

### Pillar 2 — `FOR ALL` policies are banned on mutation-eligible tables

Always split into `FOR INSERT` / `FOR UPDATE` / `FOR DELETE` with explicit `WITH CHECK` clauses. Postgres defaults `WITH CHECK = USING` on `FOR ALL` but the implicitness is a silent-drift surface — a future migration that broadens `USING` for SELECT will silently broaden write access too.

### Pillar 3 — `qual = true` SELECT policies are FORBIDDEN on tenant-data tables

A policy with `USING (true)` makes the entire table readable by any authenticated user.

> **Failure precedent**: a SaaS app's `dd_deal_reviews` shipped with `"Anyone can read reviews" USING (true)` — every authenticated user could read every other tenant's deal reviews. Closed in migration `20260420150000_cm32_t2_4_deal_reviews_rls.sql`.

If a table has no direct tenant column, scope via JOIN:
```sql
USING (EXISTS (
  SELECT 1 FROM tenant_data t
  WHERE t.id = my_table.parent_id
    AND t.{{tenant_column}} = ANY({{prefix}}_user_org_ids(auth.uid()))
))
```

### Pillar 4 — Identity is JWT-derived, NEVER from request body

Fields like `invited_by`, `actor_user_id`, `created_by` MUST come from the verified JWT (`auth.uid()` server-side, or `caller.id` after `supabase.auth.getUser()` in edge functions). Accepting these from the request body permits **audit-trail forgery** by any authenticated admin.

> **Failure precedent**: An early version of `send-org-invite` accepted `invited_by` from the body. An admin could attribute their invite to another admin's user_id, poisoning the audit log. Removed in v1.0 — derived from `caller.id` only.

### Pillar 5 — Atomic invite claim via RPC + partial unique index

Two-tab race conditions are **guaranteed** the moment your invite link is sent. Defense:

1. RPC `accept_invite_atomic(p_token, p_user_id)` that does claim-update + membership-insert in a single transaction
2. Partial unique index: `CREATE UNIQUE INDEX ... ON {{invite_table}}(token) WHERE claimed_at IS NULL` — serializes the claim at the database level
3. Edge function falls back to manual sequence with `ON CONFLICT (org_id, user_id) DO NOTHING` if RPC absent
4. **Already-claimed returns 200 with `status: "already_claimed"`, NEVER 4xx** — idempotency under network retry is non-negotiable

### Pillar 6 — Owner-transfer is promote-BEFORE-demote in single tx

Last-owner guard trigger blocks demoting the only active owner. Owner-transfer must therefore:
1. Promote target to owner (org now has 2 active owners — trigger sees valid state)
2. Demote caller to admin (1 owner remains — trigger allows)

Reverse the order and the trigger fires on step 1, blocking the entire transfer. Wrap in single transaction.

### Pillar 7 — Append-only audit log = RLS deny + structural triggers

Belt + suspenders:
- RLS: `FOR UPDATE USING (false)` and `FOR DELETE USING (false)`
- Structural: `BEFORE UPDATE` / `BEFORE DELETE` triggers that `RAISE EXCEPTION`

If a future migration accidentally adds a permissive UPDATE/DELETE policy, the structural trigger still raises. Plus `REVOKE INSERT, UPDATE, DELETE ON audit_log FROM authenticated, anon, public` — trigger functions are SECURITY DEFINER so they bypass these revokes, but a future migration that adds a permissive INSERT grant is now structurally blocked.

> **Failure precedent**: The HomePros compliance unblock required append-only guarantee. Single-layer protection (RLS only) was rejected — auditors specifically asked for structural enforcement. Phase 4a shipped both layers.

### Pillar 8 — STABLE helper function for RLS predicates

```sql
CREATE OR REPLACE FUNCTION public.{{prefix}}_user_org_ids(p_user_id uuid)
RETURNS uuid[]
STABLE                          -- enables query-execution caching
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(ARRAY(
    SELECT org_id FROM public.{{membership_table}}
    WHERE user_id = p_user_id AND status = 'active'
  ), ARRAY[]::uuid[]);
$$;
```

`STABLE` lets Postgres call this once per query rather than once per row. Without `STABLE`, RLS predicates re-execute the membership lookup per scanned row — N×N performance collapse on large tables.

### Pillar 9 — `_v2` policy migration with sunset date

When replacing legacy RLS policies, additive `_v2` policies coexist with legacy until verified, then legacy is dropped. **Every `_v2` migration MUST declare a sunset date** in a comment. Coexistence is bounded-time, not permanent.

```sql
-- SUNSET: 2026-05-20 — drop legacy "owner_view_properties" once _v2 verified
CREATE POLICY "org_members_view_properties_v2" ON ...
```

Create a follow-up issue pinned to that date.

### Pillar 10 — Pagination-safe duplicate check (the `listUsers` trap)

`supabase.auth.admin.listUsers()` defaults to **50 users per page**. Code that iterates without pagination silently misses every user past page 1.

> **Failure precedent**: Original `accept-org-invite` symptom — production users with >50 auth users started getting `"Failed to create user account"` 500s when their email in fact already existed. Fix: created `get_auth_user_id_by_email(p_email)` SECURITY DEFINER RPC for a single deterministic lookup. Replace `listUsers` with this RPC everywhere.

### Pillar 11 — Org-switch invalidates ALL org-scoped queries + refreshes JWT

When the user switches active org, you must:
1. **Refresh JWT** (`supabase.auth.refreshSession()`) so RLS sees the new active membership claim immediately
2. **Invalidate all org-scoped query keys** — pipeline, matches, members, audit, notifications, anything tenant-bound
3. **Broadcast a window event** (`window:dispatchEvent('app:org-switched')`) so other hooks can teardown stale realtime channels

Realtime subscriptions filtered by `tenant_column=eq.${oldOrgId}` will continue serving stale events for up to 30s otherwise.

### Pillar 12 — Every 4xx renders specific actionable UI state

No generic "Something went wrong." Every error response from edge functions returns `{ error, code, details? }`. The frontend error classifier maps `code` to actionable UI:

| code | UI behavior |
|---|---|
| `user_exists_use_login` | Flip to sign-in form with email prefilled |
| `email_send_failed` | Show red Retry button (Resend transient) |
| `invite_expired` | Show "request new invite" CTA |
| `already_member` | Redirect to org dashboard with toast |
| `forbidden` | Show "ask an admin" message with admin email |

`FunctionsHttpError.context` must be parsed as a **raw `Response` object**, not as a pre-parsed body. See `references/tier-5-frontend.md` § Error Classifier.

## Pre-flight checklist (before starting Tier 1)

```bash
# 1. Verify Supabase project access
supabase projects list

# 2. Verify required extensions
supabase db execute "
  SELECT extname FROM pg_extension WHERE extname IN ('citext','pgcrypto','pg_cron');
"
# Expect 3 rows. If pg_cron missing, contact Supabase support to enable.

# 3. Verify env vars set
for v in SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY RESEND_API_KEY FRONTEND_URL; do
  test -n "${!v}" && echo "✓ $v set" || echo "✗ $v MISSING"
done

# 4. Verify auth redirect URLs configured in Supabase dashboard
#    Auth → URL Configuration → Redirect URLs:
#      - {{frontend_url}}/auth/callback
#      - {{frontend_url}}/invite/accept

# 5. Identify existing data tables that need org_id added
#    These become {{tenant_data_tables}} parameter
supabase db execute "
  SELECT table_name FROM information_schema.tables
  WHERE table_schema='public' AND table_type='BASE TABLE'
  ORDER BY table_name;
"
```

If any step fails, halt and surface the blocker before proceeding.

## How to use this skill

### For a fresh project (recommended path)

1. Read this SKILL.md fully (you're here)
2. Read `references/doctrine.md` once — internalize the 12 pillars
3. Open `references/tier-1-foundation.md` → apply migration → run `scripts/verify-tier-1.sh`
4. Open `references/tier-2-invites.md` → deploy edge functions → run verification
5. Continue through Tiers 3, 4, 5, 6 with gates between each

### For a stuck-in-progress project

1. Run `scripts/audit-current-state.sh` to map what already exists
2. Skip to the failing tier per audit output
3. Apply doctrinal fixes per the named failure precedents

### For an existing single-tenant project to harden for SaaS

1. Run all six tiers but spend longer on **Tier 1 backfill section** — every existing data table needs `org_id` added with a sensible default (often a single "default org" for all existing users)
2. **Tier 5 is more invasive** — every existing query in the app needs a tenant filter or RLS policy

## Reference files (load on demand)

| File | When to load |
|---|---|
| `references/doctrine.md` | Always — reference for the 12 pillars |
| `references/tier-1-foundation.md` | Tier 1 ship |
| `references/tier-2-invites.md` | Tier 2 ship |
| `references/tier-3-team-mgmt.md` | Tier 3 ship |
| `references/tier-4-audit-log.md` | Tier 4 ship |
| `references/tier-5-frontend.md` | Tier 5 ship |
| `references/tier-6-hardening.md` | Tier 6 ship |
| `references/verification-gates.md` | At each gate — exact SQL queries |
| `references/pitfalls.md` | When something breaks — failure-mode index |

## Templates (copy + substitute placeholders)

| File | Purpose |
|---|---|
| `templates/01_foundation.sql` | Tables, RLS, helper, backfill |
| `templates/02_invites.sql` | bb_pending_invites + accept_invite_atomic RPC |
| `templates/03_team_mgmt.sql` | change_member_role / set_member_status / remove_member / transfer_ownership |
| `templates/04_audit_log.sql` | Append-only audit log + structural triggers |
| `templates/05_pen_tests.sql` | 13 cross-tenant penetration tests |
| `templates/send-invite-edge-function.ts` | Resend email invite, JWT-derived inviter |
| `templates/accept-invite-edge-function.ts` | Atomic claim with RPC + manual fallback |
| `templates/useAuth.tsx` | Auth context with bare-auth inner pattern |
| `templates/useOrganization.ts` | Active org + realtime + JWT refresh |
| `templates/OrgSwitcher.tsx` | Multi-org dropdown |
| `templates/error-classifier.ts` | FunctionsHttpError → actionable UI mapping |

## Anti-Patterns (refuse these — fail your launch)

| Anti-pattern | Pillar violated | Symptom |
|---|---|---|
| `CREATE VIEW v_x AS ...` without `WITH (security_invoker=true)` | Pillar 1 | Cross-tenant leaks |
| `FOR ALL` RLS policy on a tenant table | Pillar 2 | Silent permission drift |
| `USING (true)` SELECT policy on tenant data | Pillar 3 | Every user reads everything |
| `invited_by` accepted from request body | Pillar 4 | Audit-trail forgery |
| Sequential UPDATE-then-INSERT for invite claim (no atomic RPC) | Pillar 5 | Two-tab race → duplicate memberships |
| `change_member_role(self, 'admin')` then `change_member_role(target, 'owner')` | Pillar 6 | Last-owner trigger blocks step 1 |
| Audit table with RLS-only deny (no structural triggers) | Pillar 7 | Future migration adds permissive UPDATE policy → silent forgery |
| Helper function NOT marked `STABLE` | Pillar 8 | RLS predicates re-execute per row → N×N collapse |
| `_v2` policy migration without sunset date | Pillar 9 | Permanent ambiguity about authoritative policy |
| `auth.admin.listUsers()` without pagination loop | Pillar 10 | Silent miss of every user past page 1 |
| `switchOrg()` without exhaustive `invalidateQueries` | Pillar 11 | Stale org data visible 30s post-switch |
| Generic `toast.error('Something went wrong')` | Pillar 12 | Users dead-end with no recovery action |
| `String(funcsHttpError)` instead of parsing `.context as Response` | Pillar 12 | UI shows `[object Object]` |

## Confident-mode safety FYIs

- The Tier 1 migration uses `SET LOCAL session_replication_role = 'replica'` to bypass triggers during backfill. This is necessary for performance on large tables but means any custom triggers on data tables won't fire. Verify your data tables don't have triggers that need to run — if they do, run a separate trigger-aware backfill.
- The pg_cron RLS health check uses a designated test user email. **Set this in `references/tier-6-hardening.md` BEFORE deploy** — defaulting to a placeholder email means alerts fire forever.
- Resend's free tier rate-limits at 100 emails/day. For >100 invites/day, upgrade or add a queue (`{{prefix}}_invite_send_queue` + worker).

## Related skills

- **`saas-platforms`** — strategy/decision layer (when to multi-tenant, billing models, feature flags). Compose: read `saas-platforms` first to decide architecture, then this skill to ship it.
- **`better-auth-security`** — alternative auth library. If using Better Auth instead of Supabase Auth, that skill replaces Tiers 2 + 5 here.
- **`master-security-review`** — post-build audit. After all six tiers, invoke `master-security-review` for an independent verdict.
- **`postgresql-code-review`** — for migration review pre-merge.

## Strategic Alignment

**ROADMAP item(s) this advances**: Multi-tenant readiness for any SaaS-direction project. For a SaaS app specifically: closes the "internal tool first, SaaS later" gap codified in `project_launch_sequencing_internal_first.md` — this skill is what shipping the SaaS layer looks like.

**ROADMAP item(s) this REJECTS**: None directly — this is a capability skill, not a feature.

**If this advances nothing today**: It is the codified scar tissue from CM.32. Pushable to template via `/push-to-template` so future projects skip the 4-phase learning curve.

## Failure precedents (cited above)

- `dd_deal_reviews` qual=true leak — Pillar 3 (closed 2026-04-20)
- `invited_by` body-derived audit forgery — Pillar 4 (closed pre-Tier-2 ship)
- `auth.admin.listUsers()` 50-user pagination silent miss — Pillar 10 (replaced with RPC)
- HomePros compliance audit requiring structural append-only — Pillar 7 (Phase 4a)
- Two-tab race producing duplicate memberships — Pillar 5 (atomic RPC + partial unique index)

## Version & maintenance

- v1.0 — Initial skill, derived from a SaaS app CM.32 (2026-04-19 to 2026-04-21 ship cycle)
- Update when: new failure mode discovered → add to pillars + pitfalls + pen-tests
- Decommission when: Supabase ships a managed multi-tenant primitive that subsumes this entire stack (not anytime soon)
