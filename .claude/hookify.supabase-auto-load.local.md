---
name: supabase-auto-load
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-*__.*
action: addContext
---

# Supabase Checklist

**Before every query**: Specific columns (no `SELECT *`) · `LIMIT` present (or aggregate) · `WHERE` filters · JSONB: use `->>'key'` not full fetch · Could an RPC do this?

**Progressive disclosure**: COUNT first (~50 tok) → targeted SELECT with LIMIT (~500 tok) → full row only when editing (~2K+)

**Anti-patterns**: `SELECT *` on JSONB tables (5K+/row) · missing LIMIT (50K+) · fetch-then-filter in code · N+1 query loops (use array_agg/JOINs) · id comparisons without ::text cast
