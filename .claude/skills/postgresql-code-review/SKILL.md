---
name: postgresql-code-review
description: |
  Deep PostgreSQL/Supabase code review — JSONB indexing, GIN/GiST, CITEXT, custom domains,
  RLS policies with auth.uid(), SECURITY DEFINER vs INVOKER, and Supabase-specific patterns.
  This is the specialist companion to master-code-reviewer for SQL/migration diffs.
  For general code review with scoring, use master-code-reviewer.
version: 1.1
source: github/awesome-copilot (enhanced for the project)
classification: capability-uplift
allowed-tools: Read, Grep, Glob
triggers:
  - "review this SQL"
  - "review this migration"
  - "check this RLS policy"
  - "Supabase schema review"
  - "PostgreSQL review"
do-not-trigger:
  - "code review" (general) → use master-code-reviewer
  - "security review" → use master-security-review
paths:
  - "supabase/**"
  - "**/migrations/**"
  - "**/*.sql"
---

# PostgreSQL & Supabase Code Review

> Deep specialist for PostgreSQL/Supabase schema, RLS, and query patterns.
> This skill provides depth that master-code-reviewer references but doesn't contain.
> For comprehensive code review with scoring and severity, use master-code-reviewer alongside this skill.

## Master Skill Relationship

This is a **companion specialist** to `master-code-reviewer`. When reviewing a PR that contains both SQL and application code, both skills should be active — the master handles process/scoring/output, this skill handles PostgreSQL-specific depth.

## PostgreSQL-Specific Review Areas

### JSONB Best Practices
```sql
-- BAD: Inefficient JSONB usage (no index support)
SELECT * FROM orders WHERE data->>'status' = 'shipped';

-- GOOD: Indexable JSONB queries
CREATE INDEX idx_orders_status ON orders USING gin((data->'status'));
SELECT * FROM orders WHERE data @> '{"status": "shipped"}';

-- GOOD: JSONB validation
ALTER TABLE orders ADD CONSTRAINT valid_status
CHECK (data->>'status' IN ('pending', 'shipped', 'delivered'));
```

### Array Operations Review
```sql
-- GOOD: GIN indexed array queries
CREATE INDEX idx_products_categories ON products USING gin(categories);
SELECT * FROM products WHERE categories @> ARRAY['electronics'];
```

### PostgreSQL Schema Design
```sql
-- GOOD: PostgreSQL-optimized schema
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email CITEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);
CREATE INDEX idx_users_metadata ON users USING gin(metadata);
```

### Custom Types and Domains
```sql
-- GOOD: PostgreSQL custom types
CREATE TYPE currency_code AS ENUM ('USD', 'EUR', 'GBP', 'JPY');
CREATE DOMAIN positive_amount AS DECIMAL(10,2) CHECK (VALUE > 0);
```

## PostgreSQL-Specific Anti-Patterns

### Performance Anti-Patterns
- Not using GIN/GiST for appropriate data types
- Treating JSONB like a simple string field
- Using inefficient array operations
- Poor partition key selection

### Schema Design Issues
- Not using ENUM types for limited value sets
- Ignoring constraints for data validation
- Using VARCHAR instead of TEXT or CITEXT
- Unstructured JSONB without validation

### Function and Trigger Issues
```sql
-- GOOD: Optimized trigger function
CREATE OR REPLACE FUNCTION update_modified_time()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_modified_time_trigger
    BEFORE UPDATE ON table_name
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION update_modified_time();
```

## Supabase RLS Patterns (Critical)

```sql
-- Check all public tables have RLS enabled
SELECT schemaname, tablename, rowsecurity
FROM pg_tables WHERE schemaname = 'public' AND NOT rowsecurity;

-- Check for RLS-enabled tables with NO policies (dangerous!)
SELECT t.tablename FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename
WHERE t.schemaname = 'public' AND t.rowsecurity AND p.policyname IS NULL;

-- GOOD: Supabase RLS with auth.uid()
ALTER TABLE user_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_data" ON user_data
    FOR ALL USING (auth.uid() = user_id);

-- GOOD: Multi-tenant isolation
CREATE POLICY "tenant_isolation" ON orders
    FOR ALL USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);
```

### SECURITY DEFINER vs INVOKER
```sql
-- SECURITY INVOKER (default, safer): Runs with caller's permissions
CREATE FUNCTION public.get_user_data() RETURNS SETOF users
LANGUAGE sql SECURITY INVOKER AS $$
  SELECT * FROM users WHERE id = auth.uid();
$$;

-- SECURITY DEFINER (elevated, audit carefully): Runs with function owner's permissions
-- Only use when the function MUST bypass RLS (e.g., admin operations)
CREATE FUNCTION public.admin_get_all_users() RETURNS SETOF users
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT * FROM users;
$$;
-- ALWAYS add: SET search_path = public to prevent search_path injection
```

### Supabase Key Rules
- `anon` key: Client-safe, RLS-enforced, limited scopes
- `service_role` key: Bypasses RLS — NEVER in client code, NEVER in NEXT_PUBLIC_*
- Edge Functions: Only place service_role should exist outside DB

## PostgreSQL Code Quality Checklist

### Schema Design
- [ ] Using appropriate PostgreSQL data types (CITEXT, JSONB, arrays)
- [ ] Leveraging ENUM types for constrained values
- [ ] Implementing proper CHECK constraints
- [ ] Using TIMESTAMPTZ instead of TIMESTAMP
- [ ] Defining custom domains for reusable constraints

### Performance
- [ ] Appropriate index types (GIN for JSONB/arrays, GiST for ranges)
- [ ] JSONB queries using containment operators (@>, ?)
- [ ] Proper use of window functions and CTEs

### Security
- [ ] Row Level Security (RLS) implementation where needed
- [ ] Proper role and privilege management
- [ ] Using PostgreSQL's built-in encryption functions
