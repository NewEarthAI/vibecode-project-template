# Pitfalls — Failure-Mode Index

When something breaks. Each entry: the symptom, the root cause, the fix.

---

## P-1 "Users can see each other's data after deploy"

**Symptom**: Tenant A user sees Tenant B's rows in pipeline / dashboard / list view.

**Likely causes** (in order):
1. Pillar 1 violation — view missing `security_invoker=true`. Run CI grep.
2. Pillar 3 violation — `qual = true` SELECT policy on a tenant table.
3. RLS not enabled on the table at all (`ENABLE ROW LEVEL SECURITY` skipped).
4. View bypasses RLS by joining through a SECURITY DEFINER function that ignores `auth.uid()`.

**Fix sequence**:
```sql
-- 1. Identify which table is leaking
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM v_leaky_view LIMIT 5;
-- Look for SeqScan on tenant tables ignoring policy predicates

-- 2. Verify view's security_invoker
SELECT relname, reloptions FROM pg_class WHERE relname = 'v_leaky_view';

-- 3. Verify policies on base table
SELECT * FROM pg_policies WHERE tablename = '<base-table>';
```

---

## P-2 "Failed to create user account" — but the user already exists

**Symptom**: 500 errors on accept-invite specifically for emails that already have an auth.users row.

**Root cause**: Pillar 10 — code is using `auth.admin.listUsers()` without pagination. Defaults to 50/page, silently misses page 2+.

**Fix**: Replace ALL `listUsers()` calls with `get_auth_user_id_by_email` RPC:
```typescript
// WRONG
const { data: { users } } = await supabaseAdmin.auth.admin.listUsers();
const existing = users.find(u => u.email === email);

// RIGHT
const { data: existingId } = await supabaseAdmin.rpc(
  'get_auth_user_id_by_email', { p_email: email }
);
```

Audit your codebase: `grep -rn "auth.admin.listUsers" src/ supabase/functions/` — every hit needs review.

---

## P-3 "Two memberships created for one user" / "duplicate key violation on accept-invite"

**Symptom**: Either two rows in `{{membership_table}}` for the same (org_id, user_id), OR 500 errors on accept-invite under load.

**Root cause**: Pillar 5 violation — partial unique index missing OR atomic RPC bypassed.

**Fix**:
```sql
-- 1. Verify partial unique index exists
SELECT indexname FROM pg_indexes
WHERE tablename = '{{invite_table}}' AND indexdef LIKE '%WHERE%claimed_at IS NULL%';

-- 2. Verify accept_invite_atomic RPC exists
SELECT proname FROM pg_proc WHERE proname = 'accept_invite_atomic';

-- 3. Clean up duplicate memberships (if any)
DELETE FROM {{membership_table}} a USING {{membership_table}} b
WHERE a.id < b.id
  AND a.org_id = b.org_id
  AND a.user_id = b.user_id;

-- 4. Add unique constraint to prevent future duplicates
ALTER TABLE {{membership_table}}
  ADD CONSTRAINT uniq_org_user UNIQUE (org_id, user_id);
```

---

## P-4 "Cannot demote owner" — but I'm transferring ownership

**Symptom**: `transfer_ownership` raises "Cannot demote/suspend last active owner."

**Root cause**: Pillar 6 violation — code is doing demote-FIRST, then promote. Trigger fires on demote because momentarily 0 owners.

**Fix**: Use the provided `transfer_ownership` RPC which orders correctly. Do NOT call `change_member_role(self, 'admin')` followed by `change_member_role(target, 'owner')` — the first call always raises.

---

## P-5 "Audit log row not appearing"

**Symptom**: Team mutation succeeds, but no row in `{{audit_table}}`.

**Likely causes**:
1. Capture trigger missing or disabled
2. Trigger function has bug + EXCEPTION handler swallowing it (RAISE WARNING in logs but no error to caller — by design per zero-regression rule)
3. `auth.uid()` returns NULL inside trigger AND fallback to `NEW.user_id` not handling that branch

**Fix sequence**:
```sql
-- 1. Verify triggers exist
SELECT tgname, tgrelid::regclass FROM pg_trigger
WHERE tgname LIKE '%audit%' AND NOT tgisinternal;

-- 2. Check Postgres logs for RAISE WARNING [audit]
-- (in Supabase: Database > Logs > Postgres)

-- 3. Manually invoke trigger function with synthetic data
-- 4. Check trigger function body for COALESCE(auth.uid(), NEW.user_id) fallback
```

---

## P-6 "Org-switch shows previous org's data for 30 seconds"

**Symptom**: After clicking OrgSwitcher, pipeline/list views still show old org's rows for ~30s before refreshing.

**Root cause**: Pillar 11 — `switchOrg` is missing `queryClient.invalidateQueries` for one or more org-scoped queryKeys. TanStack Query's default `staleTime` (30s in some patterns) keeps the stale data visible.

**Fix**: Audit every queryKey used in your app. For each org-scoped one, add it to `switchOrg`:
```typescript
// Find every useQuery that depends on org_id
grep -rn "useQuery.*queryKey:" src/

// Add each to switchOrg
queryClient.invalidateQueries({ queryKey: ['<key>'] });
```

---

## P-7 "Realtime events firing for the wrong org after switch"

**Symptom**: After org switch, realtime subscriptions fire updates for the previous org's rows.

**Root cause**: Pillar 11 — the `app:org-switched` window event isn't being listened to by stale-channel teardown logic. Channels created with `filter: org_id=eq.${oldOrgId}` continue receiving events.

**Fix**: Every realtime hook must:
```typescript
useEffect(() => {
  const handler = () => {
    if (channelRef.current) supabase.removeChannel(channelRef.current);
    channelRef.current = null;
  };
  window.addEventListener('app:org-switched', handler);
  return () => window.removeEventListener('app:org-switched', handler);
}, []);
```

Plus: include the org_id in the channel name so cross-client name collisions don't occur:
```typescript
.channel(`leads_changes:${activeOrgId}`)  // not just 'leads_changes'
```

---

## P-8 "Resend invite email never sent"

**Symptom**: Invite created in DB (`send_status = 'pending'` or `'failed'`), email never arrives.

**Likely causes**:
1. RESEND_API_KEY not set in edge function env
2. From email not verified in Resend dashboard
3. Recipient domain bouncing (check Resend webhook deliveries)
4. Resend API rate limit hit (free tier = 100/day)

**Fix**:
```sql
-- 1. Find failed invites with error messages
SELECT id, invited_email, send_status, send_error_message, created_at
FROM {{invite_table}}
WHERE send_status = 'failed'
ORDER BY created_at DESC LIMIT 20;

-- 2. Retry failed sends
-- (call send-invite edge fn again with same org_id+email; idempotent refresh)
```

UI surfaces this with the red Retry button per Pillar 12.

---

## P-9 "Generic 'Something went wrong' on accept-invite"

**Symptom**: User sees generic error toast, no actionable next step.

**Root cause**: Pillar 12 violation — frontend error classifier missing the `code` switch, OR using `String(error)` on a `FunctionsHttpError` (produces `[object Object]`).

**Fix**: Audit every mutation hook's `onError`. Each must use `extractErrorPayload(err)` (see `templates/error-classifier.ts`) and have a switch over known `code` values.

---

## P-10 "RLS health check failing — but everything looks fine"

**Symptom**: `bb_rls_health_checks.passed = false` rows accumulating, but the test_user_email user can clearly see data when logged in.

**Likely causes**:
1. `<<<REPLACE-WITH-PROD-OWNER-EMAIL>>>` placeholder never replaced — the function returns early with `passed=false`
2. Test user got removed/suspended from their org
3. The test user's org's data was deleted/moved
4. `{{prefix}}_user_org_ids` returns empty for the test user (membership row missing)

**Fix**:
```sql
-- 1. Look up the actual test user
SELECT id FROM auth.users WHERE email = '<your-test-user-email>';

-- 2. Verify their org membership
SELECT * FROM {{membership_table}} WHERE user_id = '<their-id>' AND status = 'active';

-- 3. Verify they have visible data
SELECT count(*) FROM {{tenant_data_table}}
WHERE {{tenant_column}} = ANY({{prefix}}_user_org_ids('<their-id>'));

-- If 0: either backfill missed their org's data OR they're the wrong test user.
-- Update the test_user_email in {{prefix}}_rls_health_check() function.
```

---

## P-11 "Invited admin can do everything except invite more admins"

**Symptom**: Admin role doesn't allow inviting other admins.

**Root cause**: This is intentional per Pillar 6 — only owners can promote to owner via `transfer_ownership`. Admins inviting admins via `send-invite` IS allowed; the limit is on `change_member_role(<id>, 'owner')` from non-owner.

**Verification**: Check the edge function ALLOWED_ROLES set — should include `'admin'`. Check `change_member_role` RPC — should allow caller-owner to promote to owner, and caller-admin to promote to admin/manager/member.

---

## P-12 "Migration B (NOT NULL promote) takes forever / locks tables"

**Symptom**: `ALTER TABLE ... ALTER COLUMN tenant_column SET NOT NULL` on a large table holds an ACCESS EXCLUSIVE lock for minutes, blocking writes.

**Root cause**: Postgres scans entire table to verify NOT NULL constraint.

**Fix** (zero-downtime pattern):
```sql
-- 1. Add CHECK constraint NOT VALID (no full scan)
ALTER TABLE {{tenant_data_table}}
  ADD CONSTRAINT tenant_column_not_null CHECK ({{tenant_column}} IS NOT NULL) NOT VALID;

-- 2. Validate in background (still acquires lock but only briefly per row)
ALTER TABLE {{tenant_data_table}} VALIDATE CONSTRAINT tenant_column_not_null;

-- 3. Now SET NOT NULL is fast (uses the existing CHECK as proof)
ALTER TABLE {{tenant_data_table}} ALTER COLUMN {{tenant_column}} SET NOT NULL;

-- 4. Drop the redundant CHECK
ALTER TABLE {{tenant_data_table}} DROP CONSTRAINT tenant_column_not_null;
```

This is standard Postgres lore but easy to forget under deadline pressure.
