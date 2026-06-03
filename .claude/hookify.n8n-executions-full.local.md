---
name: n8n-executions-full
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__n8n_executions
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

**BLOCKED**: `n8n_executions` requires explicit mode. Use `"summary"` (500 tok) or `"error"` (200-500 tok). `full` = 50K+, NEVER use unless exporting raw data with user approval.
