# n8n Workflow Patterns & Safety Rules

## Execution Mode Selection

Choose the correct mode for the use case:
- **`runOnceForEachItem`** — When Code node processes items independently (per-item logic, filtering, transforming)
- **`runOnceForAllItems`** — ONLY when you genuinely need cross-item aggregation (counting, grouping, merging)

**Rule**: ANY Code node processing multiple items MUST use `runOnceForEachItem` unless it requires cross-item access. Default mode breaks paired-item tracking for downstream Execute Workflow nodes.

## Code Node Return Patterns

| Mode | Pass-through | Filter out | Transform |
|------|-------------|------------|-----------|
| `runOnceForEachItem` | `return $input.item` | `return []` | `return {json: {key: value}}` |
| `runOnceForAllItems` | `return $input.all()` | `return []` | `return items.map(...)` |

**Code node v2 `runOnceForEachItem` — return a SINGLE OBJECT, NOT an array:**
- CORRECT: `return {json: {key: value}}`
- WRONG: `return [{json: {key: value}}]` — causes `"A 'json' property isn't an object"` error
- NEVER use `return [{json: $json}]` — `$json` is a sandbox proxy that fails `validateItem()`
- Use `return $input.item` for pass-through

## Parallel Branches Are Sequential (CRITICAL)

n8n does NOT truly parallel-execute branches within a single workflow execution. When a node has multiple output connections, n8n processes the **first branch fully** before starting the second. This means:
- A "fire-and-forget" parallel branch actually runs LAST
- If it writes to the same row as a later-path node, it OVERWRITES the final state
- **Solution**: Make status updates SEQUENTIAL (in the main path), not parallel branches

## Sandbox Limitations (n8n Cloud)

**NOT available:**
- `fetch()` — ReferenceError
- `$helpers.httpRequest()` — ReferenceError on Cloud
- `AbortController` — ReferenceError
- External npm packages (axios, lodash, moment, etc.)

**Available:**
- `require('crypto')`, `Buffer`, `URL`
- `DateTime` (Luxon), `$jmespath()`
- Standard JS built-ins

**Workaround for HTTP**: Use HTTP Request node (separate node) OR call an edge function.

## HTTP Request Nodes Are Data Sinks (CRITICAL)

HTTP Request nodes REPLACE `$json` with their HTTP response. Any node downstream of an HTTP Request that needs upstream data MUST use `$('UpstreamCodeNode').first().json` — NEVER bare `$json`.

**When inserting an HTTP Request node into an existing chain:**
1. Identify ALL downstream nodes that use `$json`
2. Replace every `$json` ref with `$('LastCodeNodeBeforeHTTP').first().json`
3. Verify with post-deploy API check

**This is one of the most common silent failure modes in n8n.** Classifications, enrichment data, or context can be silently replaced with an HTTP response, causing downstream nodes to persist empty or wrong data for days before anyone notices.

## Node Naming (IMMUTABLE — NEVER CHANGE)

- **Node names are permanent identifiers** — referenced by `$('NodeName')` across the workflow
- **NEVER rename a node** — not even version bumps (V1.0 → V1.1 → V1.2)
- **NEVER put version numbers in node names** — "Prepare Event Data V4.18" is WRONG
- **Version tracking goes INSIDE the node**: code comments (`// V1.2 FIX: ...`), metadata vars, or prompt_version fields
- If a node must be replaced: create NEW node, update ALL `$('OldName')` refs, then delete old

## Common Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `$("Node").all()` for paired items | Execution-scoped, not branch-scoped | Guard with filters or use `.item` |
| `$("Node").first()` for current item | Always returns item 1 | Use `.item` for paired items |
| `$input.all()[0]` for single | Drops everything after first | Use `$input.item` or iterate with `.map()` |
| `redirect:'follow'` in sandbox | Doesn't work | Use `redirect:'manual'` + Location header |
| `$json.field` after HTTP Request | HTTP response replaced upstream data | `$('UpstreamCode').first().json.field` |
| Version numbers in node names | Rename = silent `$('OldName')` breakage | Version in code comments inside node |

## Execute Workflow Node (CRITICAL — Silent Failures)

### workflowId Format (v1.2+)
The `workflowId` parameter MUST use the resource locator format:
```json
{
  "workflowId": {
    "__rl": true,
    "value": "<workflow-id>",
    "mode": "id"
  }
}
```
- **WRONG**: `"workflowId": "<workflow-id>"` — bare string silently fails with "No information about the workflow to execute found"
- Copy the `__rl` format from any existing Execute Workflow node in the codebase

### Project Ownership (callerPolicy)
Workflows with `callerPolicy: "workflowsFromSameOwner"` can ONLY call sub-workflows in the **same n8n project**. If your new workflow is in a personal project and the target is in a team project:
- Error: `"The sub-workflow (ID) cannot be called by this workflow"`
- Fix: Transfer the caller workflow to the same project via `PUT /api/v1/workflows/{id}/transfer` with `{"destinationProjectId": "<project-id>"}`
- Check project: `GET /api/v1/workflows/{id}` → `shared[0].projectId`

### Data Passing — Flat Fields Only
When using `workflowInputs` with `mappingMode: "defineBelow"`, **nested objects get flattened to strings**:
- **WRONG**: Passing `from: { value: [{ address: "..." }] }` → arrives as `"[object Object]"`
- **RIGHT**: Pass flat fields (`sender_email`, `sender_name`) and rebuild objects in the receiving workflow's first Code node
- Arrays survive if serialized: `submission_ids: JSON.stringify(arr)` → parse in receiver

### Webhook Trigger — $json.body
Webhook nodes wrap the POST body in `$json.body`, NOT `$json` directly:
- **WRONG**: `const input = $json;` → gets headers, params, query, body, webhookUrl
- **RIGHT**: `const input = $json.body || $json;` → gets the actual POST payload
- This applies to webhook trigger nodes, NOT Execute Workflow Trigger nodes (which use `$json` directly)

## Workflow PUT API Requirements (as of 2026-03-26)

When deploying workflows via `PUT /api/v1/workflows/{id}`:

**MUST include**: `name`, `nodes`, `connections`, `settings`
**MUST strip**: `tags`, `staticData`, `active`, `callerPolicy`, `availableInMCP`, `timeSavedMode`

**Execution save settings** — ALL PUT payloads MUST include these or webhooks become "ghost" (no execution history):
```json
"settings": {
  "saveDataSuccessExecution": "all",
  "saveDataErrorExecution": "all",
  "saveExecutionProgress": true,
  "saveManualExecutions": true
}
```

**Activation**: Use `POST /api/v1/workflows/{id}/activate` and `/deactivate` — NOT PATCH.
**webhookId**: API PUT overwrites the live version. Preserve `webhookId` fields or endpoints return 404 after deploy. Deactivate/reactivate to re-register if lost.
**Webhook responseMode**: Inter-workflow calls = `"onReceived"`. INCOMPATIBLE with Respond to Webhook nodes.

## Naming Conventions
- n8n workflows: `kebab-case-descriptive`
- n8n nodes: **immutable names**, no version suffixes, descriptive purpose
- Always include error handling in n8n workflows
- NEVER use `n8n_list_workflows` — use project workflow skill for IDs

## Platform Disambiguation (CRITICAL)

**n8n and Make.com are DIFFERENT platforms with DIFFERENT MCP servers.**
- n8n operations → `mcp__n8n-mcp-.*__*` tools ONLY
- Make.com operations → `mcp__make__*` tools ONLY
- **NEVER** use `mcp__make__*` tools (scenarios_list, scenarios_run, etc.) for n8n workflow work
- If the task mentions workflows, nodes, webhooks, or executions → it is n8n, not Make.com
- Make.com is used for specific legacy scenarios only — when in doubt, ask
