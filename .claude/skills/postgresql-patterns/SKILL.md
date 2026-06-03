---
name: postgresql-patterns
description: |
  PostgreSQL query patterns, anti-patterns, and code review checklists. Covers JSONB operations, array types, window functions, full-text search, CTEs, custom types, index strategies, schema design review, trigger optimization, and RLS security patterns. Use when writing, reviewing, or optimizing PostgreSQL queries and schemas.
classification: capability-uplift
version: "1.0.0"
metadata:
  merged_from:
    - postgresql-optimization (github/awesome-copilot)
    - postgresql-code-review (github/awesome-copilot)
  adapted_by: newearthai
  adapted_date: "2026-03-26"
---

# PostgreSQL Patterns & Code Review

Query patterns, anti-patterns, and review checklists for PostgreSQL. Focuses on leveraging PostgreSQL-specific features rather than treating it as a generic SQL database.

## When to Apply

- Writing or reviewing SQL queries
- Designing or reviewing schemas
- Choosing index types (B-tree, GIN, GiST, covering)
- Working with JSONB, arrays, or custom types
- Implementing full-text search
- Building recursive queries or window functions
- Reviewing trigger and function quality
- Implementing Row Level Security (RLS)

## Query & Data Type Patterns

| Topic | Reference | Use for |
|-------|-----------|---------|
| JSONB Operations | [references/jsonb-patterns.md] | GIN indexes, containment queries, path operations, constraints |
| Array Operations | [references/array-patterns.md] | Array queries, GIN indexes, aggregation, bulk updates |
| Window Functions | [references/window-functions.md] | Running totals, rankings, moving averages, lag/lead |
| Full-Text Search | [references/full-text-search.md] | tsvector, GIN indexes, ranking, search queries |
| CTEs & Recursion | [references/ctes-recursion.md] | Recursive queries, hierarchical data, materialized CTEs |
| Custom Types | [references/custom-types.md] | ENUMs, domains, composite types, range types, geometric types |

## Index & Performance Patterns

| Topic | Reference | Use for |
|-------|-----------|---------|
| Index Strategies | [references/index-strategies.md] | Composite, partial, expression, covering indexes |
| Query Anti-Patterns | [references/query-anti-patterns.md] | Pagination, aggregation, JSON querying mistakes |
| EXPLAIN Analysis | [references/explain-analysis.md] | Reading query plans, identifying bottlenecks |

## Code Review Checklists

| Topic | Reference | Use for |
|-------|-----------|---------|
| Schema Review | [references/schema-review-checklist.md] | Data types, constraints, TIMESTAMPTZ, CITEXT, naming |
| Security Review | [references/security-review-checklist.md] | RLS, privileges, parameterized queries, audit trails |
| Function Review | [references/function-review-checklist.md] | Trigger optimization, PL/pgSQL best practices, error handling |

## Scope Boundary

This skill covers PostgreSQL **query patterns and code review**. It does NOT cover:
- Engine internals (MVCC, WAL, memory) → use `postgresql-internals`
- Supabase-specific features (PostgREST, auth, storage) → use `supabase-postgres-best-practices`
- Project-specific canonical views/RPCs → see project-level `supabase-query-optimization`
