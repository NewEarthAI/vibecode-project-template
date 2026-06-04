-- supabase-live-emitter/scripts/queries.sql
-- The 6 read-only catalogue queries the emitter runs against pg_catalog + information_schema
-- + pg_policies + pg_depend to produce Doctrine 05 §6.5.1 canonical-shape nodes + edges.
--
-- Intent-Actual-Gap Mechanism Build Programme, M3 Session 2. NEVER mutate the database.
-- Schema authority: .claude/skills/topology-substrate/references/canonical-shape.md.
--
-- INVOCATION: each query is run via mcp__supabase-<project>__execute_sql (or the entity's
-- equivalent at propagation: mcp__supabase-<entity>__execute_sql). The :schemas placeholder
-- is replaced by the caller with a quoted CSV like 'public','dd_clean','dd_v3' before send.
-- (SQL placeholders cannot be parameterised through the MCP — the substitution is textual.)
--
-- Discipline (per .claude/skills/supabase-live-emitter/references/pg-depend-query-map.md):
--   - pg_depend OID-resolution joins are explicit (no implicit FK chasing).
--   - Schema filters appear on EVERY join chain (so cross-schema platform noise stays out).
--   - All queries return PRIMITIVES (text / int / bool) — never composite types — so the MCP
--     JSON serialisation is unambiguous downstream.

-- ============================================================================
-- Q1 — tables: relkind='r' in user schemas, with columns aggregated + row estimate
-- ============================================================================
-- Emits one row per table; columns is a JSON array of column names ordered by attnum.
-- row_estimate is reltuples (autovacuum's last estimate; -1 means never analysed).
SELECT
  n.nspname AS schema,
  c.relname AS name,
  c.oid::bigint AS oid,
  c.reltuples::bigint AS row_estimate,
  COALESCE(
    json_agg(a.attname ORDER BY a.attnum)
      FILTER (WHERE a.attnum > 0 AND NOT a.attisdropped),
    '[]'::json
  ) AS columns
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_attribute a ON a.attrelid = c.oid
WHERE c.relkind = 'r'
  AND n.nspname IN (:schemas)
GROUP BY n.nspname, c.relname, c.oid, c.reltuples
ORDER BY n.nspname, c.relname;

-- ============================================================================
-- Q2 — views: relkind in ('v','m'); is_materialized + definition_hash
-- ============================================================================
-- definition_hash = md5(pg_get_viewdef(oid, true)) — a stable fingerprint of the view body.
-- Two views with the same hash have identical bodies; reconciliation can use this for drift.
SELECT
  n.nspname AS schema,
  c.relname AS name,
  c.oid::bigint AS oid,
  (c.relkind = 'm') AS is_materialized,
  md5(COALESCE(pg_get_viewdef(c.oid, true), '')) AS definition_hash
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('v', 'm')
  AND n.nspname IN (:schemas)
ORDER BY n.nspname, c.relname;

-- ============================================================================
-- Q3 — functions: prokind='f', NOT extension-owned, with language + volatility
-- ============================================================================
-- The extension-owned filter (pg_depend.deptype='e' LEFT JOIN IS NULL) is load-bearing:
-- without it, a typical project's public schema would surface 801 PostGIS/pgcrypto/etc. functions
-- as user nodes. Aggregates (prokind='a') and window functions (prokind='w') are also
-- excluded — they're extension-installed almost by definition.
-- volatility: 'i'=immutable, 's'=stable, 'v'=volatile (per pg_proc.h)
-- Decoded server-side so downstream consumers receive the canonical-shape strings directly
-- (D05 §6.5.1 + canonical-shape.md per-kind contract). Keeps the jq transform thin.
SELECT
  n.nspname AS schema,
  p.proname AS name,
  p.oid::bigint AS oid,
  l.lanname AS language,
  CASE p.provolatile
    WHEN 'i' THEN 'immutable'
    WHEN 's' THEN 'stable'
    WHEN 'v' THEN 'volatile'
    ELSE p.provolatile::text
  END AS volatility
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_language l ON l.oid = p.prolang
LEFT JOIN pg_depend d
  ON d.objid = p.oid
  AND d.classid = 'pg_proc'::regclass
  AND d.deptype = 'e'
WHERE n.nspname IN (:schemas)
  AND p.prokind = 'f'
  AND d.objid IS NULL
ORDER BY n.nspname, p.proname;

-- ============================================================================
-- Q4 — triggers: NOT tgisinternal, tgtype bitmask decoded to timing + event
-- ============================================================================
-- tgtype bitmask (per src/include/catalog/pg_trigger.h):
--   bit 1 (value 2)   = TRIGGER_TYPE_BEFORE       -> timing BEFORE (else AFTER unless INSTEAD OF)
--   bit 2 (value 4)   = TRIGGER_TYPE_INSERT       -> event INSERT
--   bit 3 (value 8)   = TRIGGER_TYPE_DELETE       -> event DELETE
--   bit 4 (value 16)  = TRIGGER_TYPE_UPDATE       -> event UPDATE
--   bit 5 (value 32)  = TRIGGER_TYPE_TRUNCATE     -> event TRUNCATE
--   bit 6 (value 64)  = TRIGGER_TYPE_INSTEAD      -> timing INSTEAD OF (views only)
-- function_schema + function_name resolve the cross-schema function reference so the
-- trigger->function edge is unambiguous (a same-named helper in two schemas does not collide).
-- id is pre-formed at the SQL layer per the SpecValidator's finding: triggers are unique
-- per (schema, table, name); a same-named trigger on a different table would collide if
-- the id were only schema.name. The pre-formed id is the canonical node id the jq
-- transform writes through verbatim.
SELECT
  cn.nspname || '.' || c.relname || '.' || t.tgname AS id,
  cn.nspname AS schema,
  c.relname AS table_name,
  t.tgname AS name,
  t.oid::bigint AS oid,
  t.tgfoid::bigint AS function_oid,
  fn.nspname AS function_schema,
  f.proname AS function_name,
  CASE
    WHEN (t.tgtype::int & 2) > 0 THEN 'BEFORE'
    WHEN (t.tgtype::int & 64) > 0 THEN 'INSTEAD OF'
    ELSE 'AFTER'
  END AS timing,
  CONCAT_WS(' OR ',
    CASE WHEN (t.tgtype::int & 4)  > 0 THEN 'INSERT'   END,
    CASE WHEN (t.tgtype::int & 8)  > 0 THEN 'DELETE'   END,
    CASE WHEN (t.tgtype::int & 16) > 0 THEN 'UPDATE'   END,
    CASE WHEN (t.tgtype::int & 32) > 0 THEN 'TRUNCATE' END
  ) AS event
FROM pg_trigger t
JOIN pg_class c     ON c.oid = t.tgrelid
JOIN pg_namespace cn ON cn.oid = c.relnamespace
JOIN pg_proc f      ON f.oid = t.tgfoid
JOIN pg_namespace fn ON fn.oid = f.pronamespace
WHERE NOT t.tgisinternal
  AND cn.nspname IN (:schemas)
ORDER BY cn.nspname, c.relname, t.tgname;

-- ============================================================================
-- Q5 — rls_policies: pg_policies + pg_class.relrowsecurity (the A.11 enabled flag)
-- ============================================================================
-- pg_policies is a convenience view of pg_policy joined to pg_class/pg_namespace.
-- The 'enabled' flag is the LOAD-BEARING signal: presence in pg_policies != effectiveness;
-- only when pg_class.relrowsecurity = true on the policy's table is the policy enforced.
-- (D05 A.11: the dangerous case is policies present but the table's RLS is disabled.)
-- pol.roles is a text[] of role names; cast via to_jsonb so jq receives a clean array.
-- id is pre-formed at the SQL layer per the SpecValidator's finding: rls_policies are
-- unique per (schema, table, policy_name); a same-named policy on a different table
-- would collide if the id were only schema.name.
-- The pg_class join is namespace-guarded via the dependent pg_namespace join + the
-- schemaname filter — the n.nspname = pol.schemaname predicate eliminates any
-- cross-schema phantom match before output (per the SecurityAuditor + Performance
-- findings).
SELECT
  pol.schemaname || '.' || pol.tablename || '.' || pol.policyname AS id,
  pol.schemaname AS schema,
  pol.tablename  AS table_name,
  pol.policyname AS name,
  c.relrowsecurity AS enabled,
  pol.cmd        AS command,
  to_jsonb(pol.roles) AS role
FROM pg_policies pol
JOIN pg_class c     ON c.relname = pol.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = pol.schemaname
WHERE pol.schemaname IN (:schemas)
ORDER BY pol.schemaname, pol.tablename, pol.policyname;

-- ============================================================================
-- Q6 — edges via pg_rewrite (view -> base) — the only pg_depend path that works
--       cleanly for v1; trigger and rls_policy edges come from their own Q4/Q5 rows.
-- ============================================================================
-- For each view (relkind in 'v','m'), pg_rewrite stores the rewrite rule; pg_depend records
-- the rule's dependencies on base relations. We project this as one (source_id, target_id)
-- row per (view, base_relation) pair. The GROUP BY dedupes column-level dependencies
-- (pg_depend records one row per column referenced) down to one edge per relation pair.
-- Both endpoints' schemas are restricted to the user set so we don't emit edges that point
-- into pg_catalog / extensions / etc.
SELECT
  vn.nspname || '.' || v.relname AS source_id,
  tn.nspname || '.' || t.relname AS target_id,
  'depends_on' AS edge_type
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class v   ON v.oid = r.ev_class
JOIN pg_namespace vn ON vn.oid = v.relnamespace
JOIN pg_class t   ON t.oid = d.refobjid
JOIN pg_namespace tn ON tn.oid = t.relnamespace
WHERE d.classid = 'pg_rewrite'::regclass
  AND d.refclassid = 'pg_class'::regclass
  AND v.relkind IN ('v', 'm')
  AND t.relkind IN ('r', 'v', 'm')
  AND v.oid <> t.oid
  AND vn.nspname IN (:schemas)
  AND tn.nspname IN (:schemas)
GROUP BY vn.nspname, v.relname, tn.nspname, t.relname
ORDER BY 1, 2;

-- NOTE — function -> table edges:
-- Postgres records function->table dependencies in pg_depend ONLY for SQL-language
-- functions; plpgsql function bodies are opaque to the catalogue. a typical project's functions
-- are dominantly plpgsql, so a pg_depend-based function->table edge query returns ~0 rows
-- for plpgsql. This is a known Postgres limitation, NOT a v1 gap — the substrate honestly
-- reflects what the catalogue exposes. A future enhancement could parse plpgsql bodies
-- (Session 2.1+ or M4); v1 emits function nodes with empty depends_on tables for plpgsql,
-- which is the honest answer per D05 P1+P2 (generator-not-author + traceability).
