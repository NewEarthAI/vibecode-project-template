---
name: n8n-workflow-delete-block
enabled: true
event: PreToolUse
tool_matcher: mcp__n8n-mcp-.*__n8n_delete_workflow|mcp__n8n-mcp-.*__n8n_delete_multiple_workflows
action: block
---

# BLOCKED — n8n Workflow Deletion

Deleting n8n workflows is **irreversible**. Once deleted, the workflow definition, execution history, and all node configurations are permanently gone.

**This action requires explicit user approval.**

## What To Do Instead

1. **Deactivate** the workflow: `n8n_deactivate_workflow` — stops execution, preserves definition
2. **Export first**: Use `n8n_get_workflow` to save the JSON definition before deleting
3. **Ask the user**: Confirm the workflow ID and intent before proceeding

## If Deletion Is Truly Needed

Ask the user: "Please confirm deletion of workflow {ID} — this cannot be undone."

Wait for explicit confirmation before retrying.
