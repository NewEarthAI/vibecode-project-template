---
name: supabase-list-tables-block
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-*__list_tables
action: block
---

**BLOCKED**: `list_tables` returns ~480KB. Use `information_schema` SQL instead: `SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ILIKE '%pattern%'` or `SELECT column_name, data_type FROM information_schema.columns WHERE table_name='X'`. 95%+ token savings.
