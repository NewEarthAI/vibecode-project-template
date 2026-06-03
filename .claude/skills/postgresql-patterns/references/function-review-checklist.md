# Function & Trigger Review Checklist

## Trigger Optimization

```sql
-- ❌ BAD: Fires on every update even when nothing changed
CREATE TRIGGER update_modified
    BEFORE UPDATE ON table_name
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_time();

-- ✅ GOOD: Only fires when row actually changes
CREATE TRIGGER update_modified
    BEFORE UPDATE ON table_name
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION update_modified_time();
```

## Function Best Practices

```sql
-- ✅ Use SECURITY DEFINER carefully (runs as function owner, not caller)
CREATE FUNCTION admin_action()
RETURNS void
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Always set search_path to prevent hijacking
    PERFORM pg_notify('admin', 'action executed');
END;
$$ LANGUAGE plpgsql;
```

## Checklist
- [ ] Functions use `RETURNS TABLE` for multi-row results (not SETOF)
- [ ] `SECURITY DEFINER` functions set `search_path` explicitly
- [ ] Error handling with `EXCEPTION` blocks where needed
- [ ] Triggers use `WHEN` clause to avoid unnecessary firing
- [ ] `IMMUTABLE`/`STABLE`/`VOLATILE` correctly declared
- [ ] Parameter order preserved when replacing functions (PostgreSQL treats different order as new overload)
- [ ] No `SELECT *` inside functions — specify columns
- [ ] Functions that modify data use `VOLATILE` (default)
- [ ] Read-only functions use `STABLE` (allows query optimization)

## Parameter Order Safety (CRITICAL)

```sql
-- ❌ NEVER change parameter order in CREATE OR REPLACE FUNCTION
-- PostgreSQL treats different order as NEW overload, not replacement
-- Result: two functions → "function is not unique" error

-- ✅ If order must change: DROP old, then CREATE new
DROP FUNCTION IF EXISTS my_func(text, integer);
CREATE FUNCTION my_func(integer, text) ...
```
