---
name: n8n-update-safety
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-*__n8n_update_partial_workflow|mcp__n8n-mcp-*__n8n_update_full_workflow
action: warn
---

**n8n update checklist**: Connection format correct (SOURCE→`node` field)? · Field passthrough preserved? · `$('NodeName')` refs valid? · Merge nodes receive all branches? · Sub-workflow contract unchanged? · Existing credentials used? · `onError: "continueRegularOutput"`? · Backup fetched? · Test planned?

Prefer `partial_workflow` over full update. Safe pattern: `return {...items[0].json, newField}`
