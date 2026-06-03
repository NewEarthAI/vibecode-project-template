---
name: n8n-http-error-handling
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__n8n_update_partial_workflow|mcp__n8n-mcp-*__n8n_update_full_workflow
action: warn
conditions:
  combinator: and
  conditions:
    - field: command
      operator: contains
      pattern: httpRequest
---

**n8n HTTP error handling check**

External API HTTP nodes: `"onError": "continueRegularOutput"` + downstream Code MUST check `if ($json.error || $json.statusCode >= 400) return [];`

Internal webhooks (`/webhook/...`): fail loud, no continueRegularOutput.

Error branch (4 nodes): Error Trigger → Format Error (Code) → WhatsApp Alert → Audit Log. Audit Log MUST use `$('Format Error').item.json` not bare `$json` (HTTP response replaces $json).
