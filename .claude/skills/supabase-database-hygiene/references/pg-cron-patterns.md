---
title: pg_cron Scheduling Patterns
description: Safe pg_cron patterns for retention jobs, backlog recovery, and monitoring
tags: pg_cron, scheduling, backlog, monitoring, stagger
---

# pg_cron Scheduling Patterns

## Daily Sweep Schedule

```sql
-- Defensive: unschedule first to prevent duplicate jobs on re-run
SELECT cron.unschedule('{{job_name}}') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = '{{job_name}}'
);

-- Schedule daily at off-peak (02:00 UTC example)
SELECT cron.schedule(
  '{{job_name}}',
  '0 2 * * *',
  'SELECT {{sweep_function}}()'
);
```

## Backlog Recovery (Temporary High-Frequency Jobs)

When a table has millions of rows to clean and the 500K safety cap means one daily sweep won't clear the backlog:

```sql
-- STAGGER jobs to prevent overlap (2-5 minute offsets)
SELECT cron.schedule('backlog-{{table_1}}', '0,10,20,30,40,50 * * * *', '...');  -- :00
SELECT cron.schedule('backlog-{{table_2}}', '2,12,22,32,42,52 * * * *', '...');  -- :02
SELECT cron.schedule('backlog-{{table_3}}', '5,15,25,35,45,55 * * * *', '...');  -- :05
SELECT cron.schedule('backlog-{{table_4}}', '7,17,27,37,47,57 * * * *', '...');  -- :07
```

**CRITICAL:** Backlog jobs have no auto-expiry. Set a calendar reminder to unschedule them after ~1 week:

```sql
SELECT cron.unschedule('backlog-{{table_1}}');
SELECT cron.unschedule('backlog-{{table_2}}');
-- ...
```

## Cron Log Self-Cleanup

`cron.job_run_details` grows unboundedly. Always schedule a purge:

```sql
SELECT cron.schedule('purge-cron-run-details', '30 2 * * *',
  $$DELETE FROM cron.job_run_details WHERE end_time < now() - INTERVAL '7 days'$$);
```

## Monitoring Queries

```sql
-- Recent retention sweep results
SELECT alert_type, message, metadata->>'rows_deleted' AS deleted, created_at
FROM {{alerts_table}} WHERE alert_type LIKE 'retention%'
ORDER BY created_at DESC LIMIT 20;

-- Backlog recovery progress (total per table)
SELECT metadata->>'table' AS tbl,
  SUM((metadata->>'rows_deleted')::int) AS total_deleted,
  COUNT(*) AS runs
FROM {{alerts_table}} WHERE alert_type = 'retention_cleanup'
GROUP BY metadata->>'table' ORDER BY total_deleted DESC;

-- Cron job health check
SELECT jobid, jobname, start_time, end_time,
  (end_time - start_time) AS duration, status, return_message
FROM cron.job_run_details
ORDER BY start_time DESC LIMIT 20;

-- Failed jobs in last 24h
SELECT * FROM cron.job_run_details
WHERE status = 'failed' AND start_time > now() - interval '24 hours';
```

## Deployment via psql (Supabase-Specific)

Supabase `db push` often fails due to migration history divergence. Direct psql deployment:

```bash
# Extract credentials from supabase CLI debug output
export PGHOST=$(supabase inspect db table-sizes --linked --debug 2>&1 | grep -o 'PGHOST="[^"]*"' | cut -d'"' -f2)
# ... (extract PGUSER, PGPASSWORD, PGDATABASE, PGPORT similarly)

# Deploy migration file
PGPASSWORD="$PW" psql "$CONN_STRING" -c "SET SESSION ROLE postgres;" -f migration.sql
```

**Note:** The user is `cli_login_postgres.{{project_ref}}`, NOT `postgres`. Must `SET SESSION ROLE postgres` for DDL and cron operations.
