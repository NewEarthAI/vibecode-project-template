---
name: supabase-smart-query
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-*__execute_sql
action: warn
conditions:
  - field: query
    operator: not_contains
    pattern: LIMIT
  - field: query
    operator: not_contains
    pattern: COUNT
  - field: query
    operator: not_contains
    pattern: EXISTS
  - field: query
    operator: not_contains
    pattern: SUM
  - field: query
    operator: not_contains
    pattern: GROUP BY
---

**[supabase-smart-query] Missing LIMIT!**

Add `LIMIT` to your query. Wide tables waste 50K+ tokens on unbounded queries.

**Fix**: Append `ORDER BY created_at DESC LIMIT 20` (or appropriate limit).

**Exceptions** (no LIMIT needed): `COUNT(*)`, `EXISTS(...)`, `SUM()`, `GROUP BY` aggregates.

**CONTEXT_APPROVAL**: If autonomous agent needs unbounded query, state WHY and estimate token cost first.
