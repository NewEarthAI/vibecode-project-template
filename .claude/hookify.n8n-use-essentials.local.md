---
name: n8n-use-essentials
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__get_node_info
action: block
---

**[BLOCKED] get_node_info is the wrong tool**

`get_node_info` has a **20% failure rate** and returns **100KB+ payloads**. It is almost never the right choice.

**Use these instead:**
- `get_node_essentials` — compact node config (~2KB, 95% token savings)
- `search_nodes` — find node types by keyword
- `n8n_get_workflow(mode: "structure")` — to understand workflow topology

Only use `get_node_info` with explicit CONTEXT_APPROVAL and a stated reason.