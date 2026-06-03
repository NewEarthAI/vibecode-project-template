---
name: n8n-error-branch-required
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__n8n_update_full_workflow
action: warn
---

**n8n error branch required** for full workflow updates.

4-node pattern: Error Trigger → Format Error (Code: workflow_name, node_name, error_message, timestamp, data_integrity flag — all with fallbacks) → WhatsApp Alert (`[KI ERROR]`/`[NF ERROR]` prefix) → Audit Log (MUST use `$('Format Error').item.json`, never bare `$json` — HTTP replaces it).

Verify: INBOUND bot guard includes error prefix pattern (prevents feedback loop).
