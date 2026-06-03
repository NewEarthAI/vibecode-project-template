---
name: supabase-migration-safety
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-.*__apply_migration
action: warn
---

**Migration pre-flight** (permanent — column drops irreversible, RLS immediate on prod):

Drops column/table/index? → Backed up? · Changes RLS? → Verified against app queries? · NOT NULL without DEFAULT? → Existing rows safe? · Rollback migration ready? · Need `NOTIFY pgrst, 'reload schema'` after?

**HARD STOP**: DROP COLUMN (>100 rows, not re-derivable) · DROP TABLE (production) · RLS on user/audit tables · auth.users/identities changes
