# EXPLAIN ANALYZE

## Reading Query Plans

```sql
-- Full analysis with buffer statistics
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.name, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'::date
GROUP BY u.id, u.name;
```

## Key Metrics

| Metric | What It Means | Concern When |
|--------|---------------|-------------|
| Seq Scan | Full table scan | On tables > 10K rows with WHERE clause |
| Index Scan | Using index | Expected for selective queries |
| Bitmap Heap Scan | Index + recheck | Normal for GIN/multiple conditions |
| Nested Loop | Row-by-row join | Outer table is large |
| Hash Join | Build hash, probe | Large build side → memory pressure |
| Sort | Explicit sort | Large sort → disk spill (check work_mem) |
| Buffers: shared hit | Read from cache | - |
| Buffers: shared read | Read from disk | High ratio = cold cache or too small shared_buffers |

## pg_stat_statements

```sql
-- Top 10 slowest queries by total time
SELECT query, calls, total_exec_time, mean_exec_time, rows,
       100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS cache_hit_pct
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

## Identifying Problems

1. **Seq Scan on large table with WHERE** → Missing index
2. **High `actual rows` vs `rows removed by filter`** → Index not selective enough
3. **Sort method: external merge** → work_mem too low, sort spilling to disk
4. **Nested Loop with high loop count** → Consider hash join (check join column indexes)
