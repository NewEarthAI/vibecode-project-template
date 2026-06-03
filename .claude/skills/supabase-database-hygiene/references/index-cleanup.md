---
title: Unused Index Audit & Cleanup Protocol
description: Safe protocol for identifying and dropping unused indexes on Supabase
tags: indexes, unused, cleanup, audit, DROP INDEX
---

# Unused Index Audit & Cleanup

## Step 1: Verify Stats Validity

```sql
SELECT datname, stats_reset FROM pg_stat_database WHERE datname = current_database();
-- ONLY proceed if stats_reset was > 30 days ago
-- If < 30 days: wait. Stats accumulate since last reset/restart.
```

## Step 2: Find Unused Indexes

```sql
SELECT s.schemaname, s.relname AS table_name, s.indexrelname AS index_name,
  pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size,
  s.idx_scan
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0
  AND 0 <> ALL (i.indkey)           -- exclude expression indexes
  AND NOT i.indisunique              -- exclude UNIQUE indexes
  AND NOT EXISTS (                   -- exclude constraint-backing indexes
    SELECT 1 FROM pg_constraint c WHERE c.conindid = s.indexrelid
  )
ORDER BY pg_relation_size(s.indexrelid) DESC;
```

## Step 3: Check for Invalid Indexes

Failed `CREATE INDEX CONCURRENTLY` leaves invalid indexes that slow every write:

```sql
SELECT indexrelname FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid WHERE NOT i.indisvalid;
```

## Step 4: Drop Indexes

**In a migration (inside transaction):** Use regular `DROP INDEX` (not CONCURRENTLY):
```sql
DROP INDEX IF EXISTS public.{{index_name}};
```

**Outside a transaction (manual):** Use `DROP INDEX CONCURRENTLY`:
```sql
DROP INDEX CONCURRENTLY IF EXISTS public.{{index_name}};
```

**For constraint-backing indexes** (PRIMARY KEY, UNIQUE): Use `REINDEX INDEX CONCURRENTLY`:
```sql
REINDEX INDEX CONCURRENTLY {{index_name}};
```

## Step 5: Document Recreate Commands

Always include recreate commands in comments for dropped indexes:
```sql
-- Recreate if needed:
--   CREATE INDEX CONCURRENTLY {{index_name}} ON {{table}} {{definition}};
```

## Special: Vector/Embedding Indexes

Vector indexes (HNSW, IVFFlat) are fully recreatable from table data — the embeddings live in the column, not the index. If a vector index has 0 scans:
- Safe to drop
- IVFFlat should be rebuilt AFTER sufficient data is loaded (uses k-means clustering)
- HNSW requires adequate `maintenance_work_mem` during rebuild
