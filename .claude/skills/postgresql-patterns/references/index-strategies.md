# Index Strategies

## Composite Indexes

```sql
-- Column order matters: most selective first, or match query WHERE clause order
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- Supports: WHERE user_id = X AND order_date = Y
-- Supports: WHERE user_id = X (leftmost prefix)
-- Does NOT support: WHERE order_date = Y (skips first column)
```

## Partial Indexes

```sql
-- Index only the rows you actually query
CREATE INDEX idx_active_users ON users(created_at)
WHERE status = 'active';

-- Much smaller than full index, faster updates
CREATE INDEX idx_orders_recent ON orders(user_id)
WHERE order_date >= '2024-01-01';
```

## Expression Indexes

```sql
-- Index computed values
CREATE INDEX idx_users_lower_email ON users(lower(email));

-- Query must use same expression
SELECT * FROM users WHERE lower(email) = 'user@example.com';
```

## Covering Indexes (INCLUDE)

```sql
-- Include non-key columns to avoid table lookups (index-only scans)
CREATE INDEX idx_orders_covering ON orders(user_id, status)
INCLUDE (total, created_at);

-- Query reads entirely from index, never touches table heap
SELECT total, created_at FROM orders
WHERE user_id = 123 AND status = 'shipped';
```

## Index Type Selection

| Data Type | Index Type | Use When |
|-----------|-----------|----------|
| Scalar (int, text, date) | B-tree (default) | Equality, range, ORDER BY |
| JSONB | GIN | Containment (@>), key existence (?) |
| Arrays | GIN | Containment (@>), overlap (&&) |
| Full-text (tsvector) | GIN | Text search (@@) |
| Geometric / range | GiST | Overlap, nearest-neighbor, exclusion |
| Low-cardinality | BRIN | Very large tables, naturally ordered data |

## Unused Index Detection

```sql
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
-- Zero scans = candidate for removal (check after sufficient traffic)
```
