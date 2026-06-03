---
name: n8n-auto-load
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__.*
action: addContext
---

# n8n Modes (MANDATORY)

| Tool | Default | Tokens | Full = LAST RESORT |
|------|---------|--------|--------------------|
| `n8n_get_workflow` | `structure` | ~2-5K | `full` = 50K+ |
| `n8n_executions` | `summary` | ~500 | `full` = 50K+ |
| `get_node` | Use `get_node_essentials` | ~200 | `get_node_info` = 100K+ |

Prefer `partial_workflow` over `full_workflow` for updates.

**Safety**: Never rename nodes (`$('Name')` breaks) · Use existing credentials · Read system prompts before modifying · Preserve field passthrough (`return {...input.json, newField}` not `return {newField}`) · Parallel terminal nodes race — use sequential

**STOP** (user approval): Node insert without passthrough plan · Node rename · Sub-workflow contract change · Branch logic near Merge node
