---
title: Pre-Flight Safety Checklist
description: Mandatory verification before any destructive database operation
tags: safety, pre-flight, verification, checklist
---

# Pre-Flight Safety Checklist

**Run EVERY check before deploying retention migrations.** This checklist caught 3 bugs in its first production use.

## 1. Verify Tables Exist

```sql
-- For each table referenced in retention functions
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name IN (
  '{{table_1}}', '{{table_2}}', '{{table_3}}'
);
```

## 2. Verify Timestamp Columns

**CRITICAL:** Column names vary between tables (`created_at`, `timestamp`, `detected_at`, `event_datetime`). Dynamic SQL with wrong column names fails silently at runtime.

```sql
-- For EACH table, verify the exact timestamp column name
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = '{{table_name}}'
  AND column_name ILIKE '%time%' OR column_name ILIKE '%created%' OR column_name ILIKE '%date%';
```

**If information_schema returns empty** (permission issue), use pg_catalog:
```sql
SET SESSION ROLE postgres;
SELECT a.attname, t.typname, a.attnotnull
FROM pg_attribute a JOIN pg_type t ON a.atttypid = t.oid
WHERE a.attrelid = 'public.{{table_name}}'::regclass
  AND a.attnum > 0 AND NOT a.attisdropped;
```

## 3. Verify Column Constraints

**Caught in production:** `SET column = NULL` on a NOT NULL column causes runtime error in pg_cron jobs at 02:00 when nobody is watching.

```sql
SELECT a.attname, a.attnotnull, pg_get_expr(d.adbin, d.adrelid) AS default_val
FROM pg_attribute a
LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
WHERE a.attrelid = 'public.{{table_name}}'::regclass
  AND a.attname = '{{column_to_modify}}';
```

## 4. Verify Index Scan Counts + Stats Reset Date

```sql
-- When were stats last reset? Must be > 30 days for 0-scan to be meaningful
SELECT datname, stats_reset FROM pg_stat_database WHERE datname = current_database();

-- Unused indexes (excluding constraints and unique indexes)
SELECT s.relname AS table_name, s.indexrelname AS index_name,
  pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size,
  s.idx_scan
FROM pg_stat_user_indexes s
JOIN pg_index i ON s.indexrelid = i.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisunique
  AND NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conindid = s.indexrelid)
ORDER BY pg_relation_size(s.indexrelid) DESC;
```

## 5. Verify Archive/Table Dependencies

Before truncating or dropping any table, verify nothing reads from it:

```bash
# Search codebase for references
grep -r "{{schema}}.{{table_name}}" --include="*.sql" --include="*.ts" --include="*.tsx" .

# Check for views depending on the table
# (Must run as postgres role)
SELECT dependent_ns.nspname AS dependent_schema,
  dependent_view.relname AS dependent_view
FROM pg_depend
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
JOIN pg_class AS dependent_view ON pg_rewrite.ev_class = dependent_view.oid
JOIN pg_namespace AS dependent_ns ON dependent_view.relnamespace = dependent_ns.oid
WHERE pg_depend.refobjid = '{{schema}}.{{table_name}}'::regclass;
```

## 6. Verify pg_cron Job Name Conflicts

```sql
SELECT jobid, jobname, schedule FROM cron.job
WHERE jobname IN ('{{job_name_1}}', '{{job_name_2}}', '{{job_name_3}}');
```

If any exist, add defensive `cron.unschedule()` guards before `cron.schedule()`.

## 7. Verify No Long-Running Transactions Blocking Autovacuum

```sql
SELECT pid, state, now() - xact_start AS tx_age, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start LIMIT 10;
```

Transactions older than 1 hour block autovacuum from reclaiming dead tuples across ALL tables.
