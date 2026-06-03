---
name: supabase-select-star
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-*__execute_sql
action: block
conditions:
  - field: query
    operator: contains
    pattern: "SELECT *"
---

**BLOCKED**: `SELECT *` wastes 60-80% tokens on JSONB/media columns. Specify only needed columns. For schema discovery use `information_schema.columns`. Also enforced by sql-guardian.sh (exit 2).
