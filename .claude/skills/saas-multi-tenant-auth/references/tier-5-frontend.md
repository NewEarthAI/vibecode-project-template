# Tier 5 — Frontend Integration

**What ships**: AuthProvider with bare-auth inner pattern, `useOrganization` with realtime + JWT refresh, OrgSwitcher, Team page, InviteAccept page, error classifier.
**Templates**: `useAuth.tsx`, `useOrganization.ts`, `OrgSwitcher.tsx`, `error-classifier.ts`
**Verification gate**: org-switch invalidates all org-scoped queries + JWT refresh fires; realtime channel teardown on switch confirmed.

## The bare-auth inner pattern

```
AuthProvider (outer — owns user/session)
   └── BareAuthContext.Provider (exposes only user.id)
         └── AuthInner (calls useOrganization, exposes activeOrg/membership)
               └── AuthContext.Provider (final context with everything)
                     └── children
```

**Why two providers**: `useOrganization` reads `user.id` to scope its queries. But `useOrganization` itself wants to be in the same context tree as `useAuth` so consumers get one merged context. Without the bare-auth split:
- Single `AuthProvider` → can't call `useOrganization` inside (chicken-and-egg with own context)
- `useOrganization` outside `AuthProvider` → no `user.id` available

The bare-auth context exposes only `user.id` to `useOrganization`, then the inner provider merges org context into the final exported `AuthContext`.

See `templates/useAuth.tsx` for full implementation.

## useOrganization — the org-switch nerve center

Three responsibilities:

### 1. Active org persistence
```typescript
const ACTIVE_ORG_STORAGE_KEY = 'app_active_org_id';
const [activeOrgId, setActiveOrgId] = useState(() => readStoredOrgId());

// Validate stored org against memberships; clear if no longer valid
useEffect(() => {
  if (memberships.length === 0) {
    if (activeOrgId !== null) writeStoredOrgId(null), setActiveOrgId(null);
    return;
  }
  const storedValid = activeOrgId && memberships.some(m => m.org_id === activeOrgId);
  if (!storedValid) {
    const fallback = memberships[0].org_id;
    writeStoredOrgId(fallback);
    setActiveOrgId(fallback);
  }
}, [memberships, activeOrgId]);
```

### 2. Realtime subscription on memberships + JWT refresh on change

```typescript
useEffect(() => {
  if (!user?.id) return;

  const channel = supabase
    .channel(`{{membership_table}}:user:${user.id}`)
    .on('postgres_changes', {
      event: '*', schema: 'public',
      table: '{{membership_table}}',
      filter: `user_id=eq.${user.id}`,
    }, async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['org-memberships', user.id] }),
        supabase.auth.refreshSession(),  // ← Pillar 11
      ]);
    })
    .subscribe();

  return () => supabase.removeChannel(channel);
}, [user?.id, queryClient]);
```

### 3. Switch + complete invalidation

```typescript
const switchOrg = useCallback((orgId: string) => {
  // Validation
  const target = memberships.find(m => m.org_id === orgId);
  if (!target) return;

  writeStoredOrgId(orgId);
  setActiveOrgId(orgId);

  // Broadcast for stale-channel teardown
  window.dispatchEvent(new CustomEvent(ORG_SWITCHED_EVENT, { detail: { orgId } }));

  // Invalidate ALL org-scoped queries — full enumeration is required
  queryClient.invalidateQueries({ queryKey: ['org-members'] });
  queryClient.invalidateQueries({ queryKey: ['org-memberships'] });
  queryClient.invalidateQueries({ queryKey: ['org-audit-log'] });
  // ... continue for every org-scoped queryKey in your app
}, [memberships, queryClient]);
```

**Critical**: enumerate every org-scoped queryKey. Skipping any leaves stale data visible after switch. This is project-specific work — list every queryKey that depends on tenant data.

## Error classifier — the FunctionsHttpError trap

Important: `FunctionsHttpError.context` is a **raw `Response` object**, NOT a pre-parsed body. Supabase v2 docs are misleading on this point. Read it once via `await ctx.json()`.

```typescript
import { FunctionsHttpError } from '@supabase/supabase-js';

export async function extractErrorPayload(err: unknown): Promise<{
  code: string; message: string; details?: Record<string, unknown>;
}> {
  if (err instanceof FunctionsHttpError) {
    const ctx = err.context as Response;
    try {
      const body = await ctx.json();
      return {
        code: body.code ?? 'unknown_error',
        message: body.error ?? 'Unknown error',
        details: body.details,
      };
    } catch {
      return { code: 'parse_error', message: 'Failed to parse error response' };
    }
  }
  if (err instanceof Error) {
    return { code: 'generic_error', message: err.message };
  }
  return { code: 'unknown_error', message: String(err) };
}
```

In every mutation hook:
```typescript
const acceptInvite = useMutation({
  mutationFn: async (...) => { ... },
  onError: async (err) => {
    const { code, message, details } = await extractErrorPayload(err);
    switch (code) {
      case 'user_exists_use_login':
        navigate('/auth?email=' + encodeURIComponent(...) + '&mode=signin');
        break;
      case 'email_send_failed':
        toast.error(message, { action: <RetryButton /> });
        break;
      // ... all the codes from Pillar 12 table ...
      default:
        toast.error(message);
    }
  },
});
```

## OrgSwitcher component

Simple dropdown reading from `useAuth().memberships` and calling `switchOrg`. UI implementation is project-specific (Radix vs MUI vs shadcn) — see `templates/OrgSwitcher.tsx` for shadcn variant.

## Team page

Sections:
1. **Active members** — list of `{{membership_table}}` rows for active org with role/status badges + action menu (change role, suspend, remove, transfer ownership)
2. **Pending invites** — list of `{{invite_table}}` rows where `claimed_at IS NULL`, with Resend / Cancel actions; show "Failed" badge with Retry button when `send_status = 'failed'`
3. **Audit log** — recent rows from `{{audit_table}}` for active org, with actor email + event type + before/after values

Wire each action to its hook (`useChangeMemberRole`, `useSetMemberStatus`, `useRemoveMember`, `useTransferOwnership`, `useCancelInvite`, `useInviteMember`).

## InviteAccept page (`/invite/accept?token=...&email=...`)

Logic:
1. On mount, parse `token` and `email` from URL
2. If user is signed in AND `user.email !== email`: show "Signed in as X. Sign out to accept invite for Y."
3. If user is signed in AND email matches: show "Accept invite" button → POST accept-invite with token only
4. If user is NOT signed in: show signup form (password + display_name) OR "I already have an account" → flips to sign-in
5. Handle `code: 'user_exists_use_login'` by flipping to sign-in form even if user typed password

Pillar 12 in action: every error code maps to specific UI behavior, never generic.

## Verification gate (must pass before Tier 6)

### Test 1: Org-switch invalidates queries
```typescript
// Snoop on queryClient.invalidateQueries calls
const spy = vi.spyOn(queryClient, 'invalidateQueries');
switchOrg(otherOrgId);
expect(spy).toHaveBeenCalledWith({ queryKey: ['org-members'] });
expect(spy).toHaveBeenCalledWith({ queryKey: ['propertyEnriched'] });
// ... assert all org-scoped queryKeys ...
```

### Test 2: JWT refresh on membership change
```typescript
const spy = vi.spyOn(supabase.auth, 'refreshSession');
// Simulate realtime event on {{membership_table}}
await channel.send({ type: 'INSERT', new: { user_id, org_id, role } });
expect(spy).toHaveBeenCalled();
```

### Test 3: FunctionsHttpError context parsing
```typescript
// Construct via class indirection so we don't expose 'new' adjacent to a generic class name
const FHE = FunctionsHttpError;
const fakeError = Reflect.construct(FHE, [
  Reflect.construct(Response, [JSON.stringify({ error: 'X', code: 'user_exists_use_login' }), { status: 400 }])
]);
const { code } = await extractErrorPayload(fakeError);
expect(code).toBe('user_exists_use_login');
```

### Test 4: Org-switched window event fires
```typescript
const handler = vi.fn();
window.addEventListener('app:org-switched', handler);
switchOrg(otherOrgId);
expect(handler).toHaveBeenCalledWith(expect.objectContaining({ detail: { orgId: otherOrgId } }));
```

All four must pass.
