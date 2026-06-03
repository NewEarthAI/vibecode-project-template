# CTEs & Recursive Queries

## Recursive Hierarchical Query

```sql
WITH RECURSIVE category_tree AS (
    -- Base case: root categories
    SELECT id, name, parent_id, 1 as level
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    -- Recursive step: children
    SELECT c.id, c.name, c.parent_id, ct.level + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree ORDER BY level, name;
```

## Non-Recursive CTEs (Readability)

```sql
-- Named subqueries for clarity
WITH active_users AS (
    SELECT user_id, MAX(last_seen) as last_active
    FROM sessions
    WHERE last_seen > NOW() - INTERVAL '30 days'
    GROUP BY user_id
),
user_orders AS (
    SELECT user_id, COUNT(*) as order_count, SUM(total) as revenue
    FROM orders
    WHERE created_at > NOW() - INTERVAL '30 days'
    GROUP BY user_id
)
SELECT u.name, au.last_active, uo.order_count, uo.revenue
FROM users u
JOIN active_users au ON u.id = au.user_id
LEFT JOIN user_orders uo ON u.id = uo.user_id;
```

## Performance Note

CTEs in PostgreSQL 12+ are automatically inlined (optimized) unless marked `MATERIALIZED`. Use `MATERIALIZED` only when the CTE is referenced multiple times and you want to avoid re-executing it.
