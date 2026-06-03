# Security Review Checklist

## Row Level Security (RLS)
- [ ] RLS enabled on all tables accessible via API
- [ ] Default deny (no policy = no access)
- [ ] Policies use `auth.uid()` or equivalent for user identification
- [ ] SELECT, INSERT, UPDATE, DELETE policies reviewed separately
- [ ] Service role key used only on server, never exposed to client
- [ ] RLS policies tested as different user roles

```sql
-- Standard RLS pattern
ALTER TABLE sensitive_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own data" ON sensitive_data
    FOR ALL TO authenticated
    USING (user_id = auth.uid());
```

## Privileges
- [ ] Principle of least privilege applied
- [ ] No `GRANT ALL` on production tables
- [ ] Sequence usage granted alongside INSERT permissions
- [ ] Schema-level grants reviewed

```sql
-- ❌ BAD: Overly broad
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;

-- ✅ GOOD: Granular
GRANT SELECT, INSERT, UPDATE ON specific_table TO app_user;
GRANT USAGE ON SEQUENCE specific_table_id_seq TO app_user;
```

## Query Safety
- [ ] All queries use parameterized values (no string concatenation)
- [ ] Input validated before reaching database
- [ ] Error messages don't leak schema information
- [ ] Audit trail on sensitive operations
