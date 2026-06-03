---
name: task-context-injector
enabled: true
event: PreToolUse
tool_matcher: Agent
action: addContext
---

# Sub-Agent Rules

Follow project CLAUDE.md and .claude/rules/ — domain hooks auto-inject on tool calls.

**Elevated Access Protocol** (mode=full, mutations, destructive ops):
1. State WHY minimal/structure is insufficient
2. Estimate token cost of the elevated operation
3. Get explicit approval before proceeding
4. If no approval channel, use most efficient alternative
