---
name: n8n-use-essentials
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__get_node_info
action: block
---

**[BLOCKED] get_node_info returns 100KB+ of raw node documentation**

`get_node_info` has a ~20% failure rate and dumps the entire node specification — parameters, descriptions, examples, type definitions. This is almost never what you need.

**Use `get_node_essentials` instead:**
```
get_node_essentials({ nodeType: "n8n-nodes-base.httpRequest" })
```

`get_node_essentials` returns only:
- Required parameters for the operation
- Common optional parameters
- Key gotchas and validation rules
- ~2-5KB vs 100KB+

**Token savings: 95%+ with get_node_essentials**

Only use `get_node_info` with explicit CONTEXT_APPROVAL when `get_node_essentials` cannot answer your question.
