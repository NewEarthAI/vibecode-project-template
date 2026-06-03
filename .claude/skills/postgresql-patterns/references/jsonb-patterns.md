# JSONB Operations

## Indexing

```sql
-- GIN index for JSONB containment queries
CREATE INDEX idx_events_data_gin ON events USING gin(data);

-- Path-specific GIN index (smaller, faster for known paths)
CREATE INDEX idx_orders_status ON orders USING gin((data->'status'));
```

## Query Patterns

```sql
-- ✅ Containment operator (uses GIN index)
SELECT * FROM events WHERE data @> '{"type": "login"}';

-- ✅ Path query with containment
SELECT * FROM events
WHERE data @> '{"type": "login"}'
  AND data #>> '{user,role}' = 'admin';

-- ✅ Key existence check
SELECT * FROM events WHERE data ? 'user_id';

-- ❌ BAD: Cast to text (no index, full scan)
SELECT * FROM users WHERE data::text LIKE '%admin%';

-- ❌ BAD: Arrow operator without index support
SELECT * FROM orders WHERE data->>'status' = 'shipped';
```

## Aggregation

```sql
SELECT jsonb_agg(data) FROM events WHERE data ? 'user_id';
```

## Constraints

```sql
-- Validate JSONB structure at the schema level
ALTER TABLE orders ADD CONSTRAINT valid_status
CHECK (data->>'status' IN ('pending', 'shipped', 'delivered'));
```

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `data::text LIKE '%x%'` | Full scan, no index | `data @> '{"key": "x"}'` |
| `data->>'field' = 'val'` | Arrow operator not GIN-indexable | `data @> '{"field": "val"}'` |
| Deep nesting without validation | Schema drift | Add CHECK constraints |
