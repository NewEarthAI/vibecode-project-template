---
title: Space Reclamation & Autovacuum Tuning
description: Reclaim disk space after cleanup and prevent future bloat
tags: pg_repack, vacuum, autovacuum, bloat, space-reclamation
---

# Space Reclamation

## Why DELETE Doesn't Free Disk

PostgreSQL `DELETE` marks rows as dead tuples. `VACUUM` marks the space reusable within PostgreSQL but does NOT return it to the OS. Only `VACUUM FULL` or `pg_repack` shrink the physical file.

## pg_repack (Recommended — Online)

```sql
-- Enable extension (one-time)
CREATE EXTENSION IF NOT EXISTS pg_repack WITH SCHEMA extensions;
```

```bash
# Run via CLI (requires direct connection string)
pg_repack -k -d "postgresql://..." --table {{table_name}}
```

| Property | pg_repack | VACUUM FULL |
|----------|-----------|-------------|
| Lock | SHARE UPDATE EXCLUSIVE (reads/writes continue) | ACCESS EXCLUSIVE (blocks everything) |
| Disk headroom | ~2x table + indexes | ~1x table |
| Requires | PK or UNIQUE NOT NULL index | Nothing |
| Available on Supabase | Yes (enable pg_repack extension, use `-k` flag) | Yes (always) |

## VACUUM ANALYZE (After Backlog Cleanup)

After batched deletes clear millions of rows, run VACUUM ANALYZE to:
1. Mark dead space as reusable (within PostgreSQL)
2. Update planner statistics (prevents wrong query plans)

```sql
VACUUM ANALYZE {{table_name}};
```

**Do this BEFORE pg_repack.** VACUUM ANALYZE is non-blocking and reclaims dead tuple space for PostgreSQL reuse. pg_repack then compacts the physical file.

## Autovacuum Tuning for High-Churn Tables

Default autovacuum triggers at 20% dead tuples — too late for tables with millions of rows.

```sql
ALTER TABLE {{table_name}} SET (
  autovacuum_vacuum_scale_factor = 0.05,      -- Vacuum at 5% dead tuples (default 0.20)
  autovacuum_analyze_scale_factor = 0.02      -- Analyze at 2% changes (default 0.10)
);
```

**Apply to:** Tables that receive >10K writes/day, telematics/GPS tables, log tables, queue tables.

**Do NOT change global autovacuum settings** — per-table overrides are safer and more targeted.

## Diagnosing Why Autovacuum Failed

If a table has 10x+ bloat, autovacuum was blocked. Check in order:

1. **Long-running transactions:**
```sql
SELECT pid, state, now() - xact_start AS tx_age, query
FROM pg_stat_activity WHERE xact_start IS NOT NULL ORDER BY xact_start;
```

2. **Autovacuum workers at capacity:**
```sql
SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'autovacuum worker';
-- Compare against max_autovacuum_workers (default 3)
```

3. **Table excluded from autovacuum:**
```sql
SELECT relname, reloptions FROM pg_class
WHERE relname = '{{table_name}}' AND reloptions @> '{autovacuum_enabled=false}';
```

4. **Autovacuum throttled too aggressively:**
```sql
SHOW autovacuum_vacuum_cost_delay;  -- Default 2ms; set to 0 on fast storage
SHOW autovacuum_vacuum_cost_limit;  -- Default ~200; raise to 1000-2000 on fast storage
```

## Supabase Disk Shrinkage

Supabase disk **cannot shrink** after auto-expansion. The only path to reduce allocated disk:

1. Delete data + VACUUM FULL (or pg_repack) to reduce actual usage
2. Trigger a **Postgres version upgrade** — Supabase right-sizes disk to 1.2x actual data

This means: once expanded to 18GB, you're at 18GB until the next Postgres upgrade, even if actual usage drops to 6GB.
