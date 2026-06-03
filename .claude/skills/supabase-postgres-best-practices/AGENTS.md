# Supabase Postgres Best Practices — Agent Guide

## Structure
```
supabase-postgres-best-practices/
  SKILL.md       — Main skill (read first)
  CLAUDE.md      — Quick reference for Claude Code
  AGENTS.md      — This navigation guide
  references/    — 34 rule files (load on demand)
```

## Token Efficiency
- SKILL.md: ~200 tokens (navigation menu)
- Each reference: ~300-500 tokens
- Load only the references needed for the current task
- Never load all 34 at once
