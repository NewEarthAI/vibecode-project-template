---
name: supabase-postgres-best-practices
description: |
  Supabase-maintained Postgres performance rules across 8 categories (query, connections, RLS, schema, locking, data access, monitoring, advanced). Each rule has incorrect/correct SQL examples with EXPLAIN output. Use when writing queries, designing schemas, configuring connections, or implementing RLS on Supabase PostgreSQL.
license: MIT
classification: capability-uplift
version: "2.0.0"
metadata:
  original_author: supabase
  adapted_by: newearthai
  adapted_date: "2026-03-26"
---

# Supabase Postgres Best Practices

Performance optimization rules for Postgres on Supabase. 34 rules across 8 categories, prioritized by impact. Each rule file contains incorrect/correct SQL, EXPLAIN output, and Supabase-specific notes.

## When to Apply

- Writing SQL queries or designing schemas on Supabase
- Implementing or optimizing indexes
- Configuring connection pooling (Supavisor)
- Implementing Row-Level Security (RLS)
- Reviewing database performance issues
- Concurrency and locking patterns

## Rule Categories by Priority

| Priority | Category | Impact | Prefix | Key Rules |
|----------|----------|--------|--------|-----------|
| 1 | Query Performance | CRITICAL | `query-` | Missing indexes, composite, partial, covering, index types |
| 2 | Connection Management | CRITICAL | `conn-` | Pooling, limits, idle timeout, prepared statements |
| 3 | Security & RLS | CRITICAL | `security-` | RLS basics, RLS performance, privileges |
| 4 | Schema Design | HIGH | `schema-` | Data types, PKs, constraints, FK indexes, lowercase IDs, partitioning |
| 5 | Concurrency & Locking | MEDIUM-HIGH | `lock-` | Advisory locks, short transactions, skip locked, deadlock prevention |
| 6 | Data Access Patterns | MEDIUM | `data-` | Pagination, upsert, batch inserts, N+1 queries |
| 7 | Monitoring | LOW-MEDIUM | `monitor-` | EXPLAIN ANALYZE, pg_stat_statements, VACUUM/ANALYZE |
| 8 | Advanced Features | LOW | `advanced-` | JSONB indexing, full-text search |

## How to Use

Read individual rule files in `references/` for detailed patterns:

```
references/query-missing-indexes.md    — When to add indexes
references/conn-pooling.md             — Supavisor configuration
references/security-rls-basics.md      — RLS policy patterns
references/schema-data-types.md        — Type selection guide
references/lock-deadlock-prevention.md — Avoiding deadlocks
references/data-pagination.md          — Cursor vs offset
references/monitor-explain-analyze.md  — Reading query plans
references/_sections.md                — Full rule index
```

Each rule file contains:
- Why it matters (brief explanation)
- Incorrect SQL with explanation
- Correct SQL with explanation
- EXPLAIN output or metrics (where applicable)
- Supabase-specific notes

## Scope Boundary

This skill covers **Supabase Postgres performance rules**. It does NOT cover:
- Engine internals (MVCC, WAL, memory, replication) → use `postgresql-internals`
- Query patterns & code review checklists → use `postgresql-patterns`
- Project-specific canonical views/RPCs → see project-level `supabase-query-optimization`
- Project-specific schema gotchas → see project `data-layer.md` rules
