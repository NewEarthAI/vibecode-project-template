---
name: memory-freshness
enabled: true
event: Stop
action: addContext
---

# Memory Freshness Check — Stop Event

Before ending this session, check whether you learned anything worth persisting to auto-memory.

**Quick scan** — Did this session involve any of these?

| Signal | Memory Action |
|--------|---------------|
| Discovered a gotcha/bug that will recur (API quirk, column name mismatch, config trap) | Add to MEMORY.md or a topic file |
| User stated a preference ("always do X", "never do Y", "I prefer Z") | Add to User Preferences section |
| Found a pattern that took multiple attempts to get right (hook config, deployment steps) | Document the working pattern |
| Corrected a wrong assumption from a previous session | Update or remove the stale memory |
| Built something reusable (shell script, RPC, edge function, hook) | Document the artifact + location |

**If YES to any**: Update the relevant memory file before the session ends.

**Guard rails**:
- Don't save session-specific details (current task state, in-progress work)
- Don't duplicate what's already in CLAUDE.md or `.claude/rules/`
- Check existing MEMORY.md first — update existing entries rather than adding duplicates
- Keep MEMORY.md under 200 lines (move detailed content to topic files)

**If NO**: No action needed. Not every session produces memory-worthy insights.
