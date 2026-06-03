---
name: supabase-database-hygiene
description: |
  Supabase PostgreSQL disk management, data retention, and operational hygiene. Covers: diagnosing disk bloat (table sizes, unused indexes, dead archives), designing tiered retention policies (hot/warm/cold with industry-standard windows), building batched pg_cron retention jobs (ctid+LIMIT+pg_sleep pattern), unused index audit protocol (verify stats_reset > 30d before dropping), autovacuum tuning for high-churn tables, pg_repack over VACUUM FULL, Supabase disk auto-scaling gotchas (can't shrink, 90%/50%/6hr cooldown), and pre-flight safety checklists. Use when Supabase disk is growing, auto-expansion triggered, tables need retention policies, indexes need auditing, or pg_cron cleanup jobs need building.
classification: capability-uplift
version: "1.0.0"
metadata:
  created_by: your-org
  created_date: "2026-03-26"
  battle_tested: true
  validated_on:
    - "Production fleet logistics DB: 12GB→18GB auto-expansion resolved, ~6GB reclaimed"
    - "Pre-flight caught 3 bugs (2 column names, 1 NOT NULL constraint)"
---

# Supabase Database Hygiene

Operational playbook for managing Supabase PostgreSQL disk space, retention policies, index hygiene, and automated cleanup. Battle-tested patterns from a production deployment that reclaimed ~6GB from an 18GB database.

## When to Apply

- Supabase disk auto-expansion notification received
- Database approaching 90% disk usage
- Tables growing unbounded without retention policies
- Need to audit and clean up unused indexes
- Setting up pg_cron retention jobs for the first time
- Diagnosing table bloat (10x+ dead tuple ratio)
- Planning data lifecycle (hot → warm → cold → delete)

## Skill Architecture

This skill orchestrates patterns from three companion skills:
- `supabase-postgres-best-practices` — Autovacuum tuning, index types, monitoring
- `postgresql-patterns` — Index strategies, query anti-patterns, review checklists
- `postgresql-internals` — MVCC/VACUUM, WAL, storage layout, pg_repack

**This skill adds:** The operational workflow that connects diagnosis → planning → implementation → verification.

## Workflow (7 Phases)

| Phase | Reference | What It Does |
|-------|-----------|-------------|
| 1. Diagnose | [references/diagnosis.md] | Table sizes, index audit, bloat detection, growth rate estimation |
| 2. Plan Retention | [references/retention-tiers.md] | Enterprise retention windows by data type, regulatory context |
| 3. Pre-Flight | [references/pre-flight-checklist.md] | Safety verification before any destructive operation |
| 4. Drop Indexes | [references/index-cleanup.md] | Unused index audit protocol, safe DROP patterns |
| 5. Build Retention | [references/retention-functions.md] | Batched DELETE functions, master sweep orchestrator |
| 6. Schedule & Monitor | [references/pg-cron-patterns.md] | pg_cron scheduling, backlog recovery, monitoring queries |
| 7. Reclaim Space | [references/space-reclamation.md] | pg_repack, VACUUM ANALYZE, autovacuum tuning |

## Quick Reference

### Supabase Disk Auto-Scaling (Gotchas)

| Fact | Detail |
|------|--------|
| Trigger | 90% of allocated disk |
| Expansion | +50% of current size |
| Cooldown | 6 hours between expansions |
| Shrink | **IMPOSSIBLE** without Postgres version upgrade (right-sizes to 1.2x actual) |
| Read-only | Triggers at 95% if cooldown blocks expansion |
| Cost | Pro plan: 8GB included, ~$0.125/GB/month overage |

### Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Single large `DELETE FROM ... WHERE date < X` | Locks table for minutes, WAL storm, bloat | Batched DELETE with `LIMIT` + `pg_sleep(0.1)` yield |
| `DROP INDEX CONCURRENTLY` in migration | Cannot run inside transaction block | Regular `DROP INDEX` (brief lock OK for unused indexes) |
| `VACUUM FULL` on production tables | ACCESS EXCLUSIVE lock blocks all reads/writes | `pg_repack -k` (online, SHARE UPDATE EXCLUSIVE) |
| Trust 0-scan index count blindly | Stats reset on restart | Verify `stats_reset` > 30 days in `pg_stat_database` |
| Set `raw_event = NULL` on NOT NULL column | Constraint violation at runtime | Check constraints BEFORE writing retention functions |
| All backlog jobs at same interval | Overlap causes lock contention | Stagger: `:00`, `:02`, `:05`, `:07` minute offsets |
| No `cron.unschedule()` guard before `cron.schedule()` | Re-run creates duplicate jobs | Always unschedule defensively first |
| Skip manual test before scheduling cron | Dynamic SQL bugs surface at 02:00 when nobody watches | Run sweep function manually once, inspect results |

## Scope Boundary

This skill covers **Supabase disk management and retention operations**. It does NOT cover:
- Query optimization → use `supabase-postgres-best-practices`
- Deep MVCC/WAL internals → use `postgresql-internals`
- Index design for query performance → use `postgresql-patterns`
- Project-specific table names or RPCs → see project rules files
