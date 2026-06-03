---
name: postgresql-internals
description: |
  Deep PostgreSQL internals — process architecture, memory management, MVCC, WAL, replication, storage layout, monitoring, and backup/recovery. Use when diagnosing performance issues, planning capacity, tuning configuration, or understanding Postgres behavior at the engine level. Complements query-level optimization skills with operational depth.
license: MIT
classification: capability-uplift
version: "2.0.0"
metadata:
  original_author: planetscale
  adapted_by: newearthai
  adapted_date: "2026-03-26"
---

# PostgreSQL Internals & Operations

Deep PostgreSQL operational knowledge — the engine-level patterns that explain WHY queries behave the way they do. Use alongside query optimization skills for the full picture.

## When to Apply

- Diagnosing slow queries that don't respond to index changes
- Planning database capacity or connection pool sizing
- Understanding MVCC behavior (dead tuples, wraparound, bloat)
- Tuning WAL, checkpoints, or shared_buffers
- Setting up replication or backup strategies
- Investigating OOM, disk, or connection exhaustion issues

## Query & Schema Optimization

| Topic | Reference | Use for |
|-------|-----------|---------|
| Schema Design | [references/schema-design.md] | Tables, primary keys, data types, foreign keys |
| Indexing | [references/indexing.md] | Index types, composite indexes, performance |
| Index Optimization | [references/index-optimization.md] | Unused/duplicate index queries, index audit |
| Partitioning | [references/partitioning.md] | Large tables, time-series, data retention |
| Query Patterns | [references/query-patterns.md] | SQL anti-patterns, JOINs, pagination, batch queries |
| Optimization Checklist | [references/optimization-checklist.md] | Pre-optimization audit, cleanup, readiness checks |
| MVCC and VACUUM | [references/mvcc-vacuum.md] | Dead tuples, long transactions, xid wraparound prevention |

## Operations & Architecture

| Topic | Reference | Use for |
|-------|-----------|---------|
| Process Architecture | [references/process-architecture.md] | Multi-process model, connection handling, auxiliary processes |
| Memory Architecture | [references/memory-management-ops.md] | Shared/private memory layout, OS page cache, OOM prevention |
| MVCC Transactions | [references/mvcc-transactions.md] | Isolation levels, XID wraparound, serialization errors |
| WAL and Checkpoints | [references/wal-operations.md] | WAL internals, checkpoint tuning, durability, crash recovery |
| Replication | [references/replication.md] | Streaming replication, slots, sync commit, failover |
| Storage Layout | [references/storage-layout.md] | PGDATA structure, TOAST, fillfactor, tablespaces, disk mgmt |
| Monitoring | [references/monitoring.md] | pg_stat views, logging, pg_stat_statements, host metrics |
| Backup and Recovery | [references/backup-recovery.md] | pg_dump, pg_basebackup, PITR, WAL archiving, backup tools |

## Scope Boundary

This skill covers PostgreSQL **engine internals and operations**. It does NOT cover:
- Supabase-specific features (RLS, PostgREST, auth) → use `supabase-postgres-best-practices`
- Query token optimization for MCP → use project-level `supabase-query-optimization`
- Project-specific schema gotchas → see project `data-layer.md` rules
