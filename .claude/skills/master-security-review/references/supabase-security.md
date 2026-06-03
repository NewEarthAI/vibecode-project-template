# Supabase Security Module

> Deep Supabase/PostgreSQL security checks. Referenced by newearthai-security-review Tier 4.

## RLS Verification Queries

```sql
-- Find all public tables WITHOUT RLS enabled (CRITICAL)
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND NOT rowsecurity;

-- Find tables WITH RLS but NO policies (dangerous — RLS blocks ALL access)
SELECT t.tablename
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename
WHERE t.schemaname = 'public' AND t.rowsecurity AND p.policyname IS NULL;

-- List all RLS policies for audit
SELECT tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies WHERE schemaname = 'public'
ORDER BY tablename;
```

## Key Access Patterns

| Key | Where | RLS? | Usage |
|-----|-------|------|-------|
| `anon` | Client-side, NEXT_PUBLIC_* | Enforced | Read public data, auth flows |
| `service_role` | Edge Functions ONLY | Bypassed | Admin operations, background jobs |

**CRITICAL**: `service_role` key in client code = all RLS bypassed. This is the #1 Supabase vulnerability.

## auth.uid() Patterns

```sql
-- GOOD: RLS policy using auth.uid()
CREATE POLICY "users_own_data" ON user_data
    FOR ALL USING (auth.uid() = user_id);

-- GOOD: Multi-tenant with JWT claim
CREATE POLICY "tenant_isolation" ON orders
    FOR ALL USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);

-- BAD: No user scoping (any authenticated user sees all)
CREATE POLICY "authenticated_access" ON sensitive_data
    FOR SELECT USING (auth.role() = 'authenticated');
```

## SECURITY DEFINER Audit

```sql
-- Find all SECURITY DEFINER functions (elevated privileges)
SELECT n.nspname, p.proname, p.prosecdef
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.prosecdef = true;
```

Each SECURITY DEFINER function should:
- Have `SET search_path = public` to prevent search_path injection
- Be explicitly justified (why does it need to bypass RLS?)
- Validate all input parameters
- Be called only from Edge Functions, not directly from client

## Edge Function Security

- Validate `Authorization: Bearer <token>` header
- Use `createClient(url, serviceRoleKey)` only for operations requiring elevated access
- Validate request body with Zod or manual checks
- Set CORS headers appropriately
- Never return raw database errors to client
