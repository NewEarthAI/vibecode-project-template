# Query Anti-Patterns

## Pagination

```sql
-- ❌ BAD: OFFSET for large datasets (scans and discards rows)
SELECT * FROM products ORDER BY id OFFSET 10000 LIMIT 20;

-- ✅ GOOD: Cursor-based pagination (constant performance)
SELECT * FROM products
WHERE id > $last_id
ORDER BY id
LIMIT 20;
```

## N+1 Queries

```sql
-- ❌ BAD: Query per row in application code
-- for user in users: SELECT * FROM orders WHERE user_id = user.id

-- ✅ GOOD: Single query with JOIN
SELECT u.*, o.order_count
FROM users u
LEFT JOIN (
    SELECT user_id, COUNT(*) as order_count
    FROM orders GROUP BY user_id
) o ON u.id = o.user_id;
```

## COUNT Estimation

```sql
-- ❌ BAD: Exact count on large table (full scan)
SELECT COUNT(*) FROM events;

-- ✅ GOOD: Approximate count (instant, no scan)
SELECT reltuples::bigint AS estimate
FROM pg_class WHERE relname = 'events';

-- ✅ GOOD: Exact count only when needed, with LIMIT
SELECT COUNT(*) FROM events WHERE fleet_number = '42' AND created_at > NOW() - INTERVAL '1 day';
```

## SELECT *

```sql
-- ❌ BAD: Fetches all columns including large JSONB/TEXT
SELECT * FROM events LIMIT 100;

-- ✅ GOOD: Only needed columns
SELECT event_id, fleet_number, primary_intent, created_at
FROM events LIMIT 100;
```

## Implicit Casts

```sql
-- ❌ BAD: String compared to integer (prevents index use)
SELECT * FROM users WHERE id = '123';

-- ✅ GOOD: Matching types
SELECT * FROM users WHERE id = 123;
```

## LIKE with Leading Wildcard

```sql
-- ❌ BAD: Leading wildcard prevents index use
SELECT * FROM users WHERE name LIKE '%smith%';

-- ✅ GOOD: pg_trgm GIN index for substring search
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_users_name_trgm ON users USING gin(name gin_trgm_ops);
SELECT * FROM users WHERE name ILIKE '%smith%';
```
