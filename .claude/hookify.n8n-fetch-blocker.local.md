---
name: n8n-fetch-blocker
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__n8n_get_workflow
action: block
conditions:
  combinator: or
  conditions:
    - field: mode
      operator: equals
      pattern: full
    - field: mode
      operator: not_exists
---

**BLOCKED**: `n8n_get_workflow` requires explicit mode. Use `mode: "structure"` (2-5K tok) or `"minimal"` (100 tok). `full` = 50K+ tokens, LAST RESORT only with user approval.
