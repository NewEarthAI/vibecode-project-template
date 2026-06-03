---
title: Database Disk Diagnosis
description: Identify what's consuming disk space on Supabase PostgreSQL
tags: supabase, disk, diagnosis, table-sizes, bloat, indexes
---

# Database Disk Diagnosis

## Step 1: Table Sizes (Top Consumers)

```bash
supabase inspect db table-sizes --linked
```

Or via SQL:
```sql
SELECT schemaname, tablename,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
  pg_total_relation_size(schemaname || '.' || tablename) AS total_bytes
FROM pg_tables WHERE schemaname = 'public'
ORDER BY total_bytes DESC LIMIT 25;
```

## Step 2: Index Sizes & Usage

```bash
supabase inspect db index-sizes --linked
```

Key columns: `Size`, `Percent used`, `Index scans`, `Unused` (true = 0 scans).

## Step 3: Bloat Detection

```bash
supabase inspect db bloat --linked
```

Bloat > 2x = needs attention. Bloat > 10x = autovacuum failing (check for long-running transactions).

## Step 4: Growth Rate Estimation

```sql
-- Date range of a table (estimate daily growth)
SELECT
  MIN({{timestamp_col}}) AS oldest,
  MAX({{timestamp_col}}) AS newest,
  COUNT(*) AS total_rows,
  pg_size_pretty(pg_total_relation_size('{{table_name}}')) AS total_size
FROM {{table_name}};
```

**Formula:** `total_size / days_of_data = daily_growth_rate`
**Monthly projection:** `daily_growth * 30`
**Time to next expansion:** `(disk_allocated * 0.9 - current_usage) / daily_growth`

## Step 5: Vacuum Stats

```bash
supabase inspect db vacuum-stats --linked
```

Tables with `last_autovacuum = NULL` have never been vacuumed — check `n_dead_tup` for bloat indicators.

## Step 6: WAL Size (Hidden Disk Consumer)

```sql
SELECT pg_size_pretty(SUM(size)) AS wal_size FROM pg_ls_waldir();
```

WAL grows unbounded if replication slots are stale:
```sql
SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;
```
