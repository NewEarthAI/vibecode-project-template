---
title: Batched Retention Functions
description: pg_cron-safe retention functions with batch DELETE, yield, and logging
tags: retention, pg_cron, batch-delete, functions
---

# Batched Retention Functions

## Generic Retention Cleaner

```sql
CREATE OR REPLACE FUNCTION retention_cleanup_table(
  p_table_name TEXT,
  p_timestamp_col TEXT,
  p_cutoff_days INT,
  p_batch_size INT DEFAULT 10000
) RETURNS INT AS $$
DECLARE
  v_deleted_total INT := 0;
  v_deleted_batch INT;
  v_start_ts TIMESTAMPTZ := clock_timestamp();
  v_sql TEXT;
BEGIN
  v_sql := format(
    'DELETE FROM %I WHERE ctid IN (
       SELECT ctid FROM %I
       WHERE %I < now() - make_interval(days => $1)
       LIMIT $2
     )',
    p_table_name, p_table_name, p_timestamp_col
  );

  LOOP
    EXECUTE v_sql USING p_cutoff_days, p_batch_size;
    GET DIAGNOSTICS v_deleted_batch = ROW_COUNT;
    v_deleted_total := v_deleted_total + v_deleted_batch;
    EXIT WHEN v_deleted_batch = 0;
    PERFORM pg_sleep(0.1);  -- yield to production queries
    EXIT WHEN v_deleted_total >= 500000;  -- safety cap per run
  END LOOP;

  -- Log to system_alerts (adjust table/columns to your schema)
  INSERT INTO {{alerts_table}} (severity, alert_type, message, metadata, created_at)
  VALUES ('info', 'retention_cleanup',
    format('Retention: %s rows deleted from %s (cutoff: %s days)',
           v_deleted_total, p_table_name, p_cutoff_days),
    jsonb_build_object(
      'table', p_table_name, 'rows_deleted', v_deleted_total,
      'cutoff_days', p_cutoff_days, 'duration_ms',
      EXTRACT(EPOCH FROM (clock_timestamp() - v_start_ts)) * 1000,
      'capped', v_deleted_total >= 500000
    ), now());

  RETURN v_deleted_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `ctid`-based batch targeting | PostgreSQL-idiomatic; avoids subquery correlation |
| `LIMIT` not `FOR UPDATE SKIP LOCKED` | Retention runs alone on schedule; SKIP LOCKED is for concurrent work queues |
| `pg_sleep(0.1)` between batches | Yields CPU and connection slots to production queries |
| 500K row safety cap | Prevents single run from taking hours on massive backlog |
| `SECURITY DEFINER` | pg_cron runs as postgres; function needs DELETE on all tables |
| `format('%I', ...)` for identifiers | Prevents SQL injection through table/column names |
| Log to alerts table | pg_cron only shows row count; errors inside the loop are otherwise invisible |

## Master Sweep Orchestrator

```sql
CREATE OR REPLACE FUNCTION database_hygiene_sweep() RETURNS JSONB AS $$
DECLARE
  v_results JSONB := '{}'::JSONB;
  v_count INT;
BEGIN
  -- Call per-table retention with appropriate windows
  v_count := retention_cleanup_table('{{table_1}}', '{{timestamp_col_1}}', {{days_1}});
  v_results := v_results || jsonb_build_object('{{table_1}}', v_count);

  v_count := retention_cleanup_table('{{table_2}}', '{{timestamp_col_2}}', {{days_2}});
  v_results := v_results || jsonb_build_object('{{table_2}}', v_count);

  -- ... repeat for each table

  -- Log master sweep result
  INSERT INTO {{alerts_table}} (severity, alert_type, message, metadata, created_at)
  VALUES ('info', 'database_hygiene_sweep',
    format('Hygiene sweep complete'), v_results, now());

  RETURN v_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Specialized: Strip-Then-Delete (For Large JSONB Columns)

When a table has a large JSONB payload column that's NOT NULL:

```sql
-- Phase 1: Strip payload to empty object (respects NOT NULL constraint)
UPDATE {{table_name}} SET {{payload_col}} = '{}'::jsonb
WHERE ctid IN (
  SELECT ctid FROM {{table_name}}
  WHERE {{payload_col}} IS NOT NULL
    AND {{payload_col}} != '{}'::jsonb
    AND {{timestamp_col}} < now() - make_interval(days => {{strip_days}})
  LIMIT {{batch_size}}
);

-- Phase 2: Delete the row entirely after a longer window
-- (uses retention_cleanup_table with a longer cutoff)
```

**Why two phases?** Stripping the JSON payload at 14 days reclaims ~60% of row storage. Deleting the row at 30 days removes the rest. This gives you more headroom without losing metadata for the intermediate period.
