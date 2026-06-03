---
name: supabase-destructive-sql
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-.*__execute_sql
action: warn
---

**SQL pre-flight**: DELETE/DROP/TRUNCATE/ALTER detected? → Has WHERE? Row count estimated? Rollback plan? Reversible within 24h? Schema read first?

**HARD STOP** (user approval): DELETE no WHERE · TRUNCATE · DROP TABLE/VIEW/FUNCTION · ALTER DROP COLUMN · audit/evidence table mutations

**Always safe**: SELECT · INSERT ON CONFLICT · UPDATE with WHERE (bounded rows)

Hard blocks also enforced by sql-guardian.sh (exit 2).
