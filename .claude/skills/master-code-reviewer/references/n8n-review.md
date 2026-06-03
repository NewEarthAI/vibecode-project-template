# n8n Workflow Review Module

> Deep review patterns for n8n workflow JSON and Code node changes. Loaded when domain detection finds workflow files in the diff.

## Critical Checks (P0/P1)

### Node Name Immutability (P0)
Node names are permanent identifiers referenced by `$('NodeName')` across the workflow.
- **NEVER approve a node rename** without verifying ALL `$('NodeName')` references are updated
- Search the entire workflow JSON for the old name
- Version tracking goes INSIDE the node (code comments), not in the name

### HTTP Request Node Data Sink (P1)
HTTP Request nodes REPLACE `$json` with their HTTP response. Any downstream node that needs upstream data MUST use `$('UpstreamCodeNode').first().json`.
- Check: Does any node after an HTTP Request use bare `$json`?
- If yes: P1 — data silently replaced with HTTP response

### Parallel Branch Sequencing (P1)
n8n does NOT truly parallel-execute branches. First branch runs fully before second starts.
- If parallel branches write to the same row → last branch overwrites
- Solution: Status updates must be sequential in the main path

## Code Node Checks

### Execution Mode (P1)
- `runOnceForEachItem` — per-item logic (DEFAULT for most cases)
- `runOnceForAllItems` — ONLY for cross-item aggregation

### Return Patterns
| Mode | Pass-through | Filter | Transform |
|------|---|---|---|
| `runOnceForEachItem` | `return $input.item` | `return []` | `return {json: {key: value}}` |
| `runOnceForAllItems` | `return $input.all()` | `return []` | `return items.map(...)` |

**WRONG**: `return [{json: {key: value}}]` in `runOnceForEachItem` — causes `"A 'json' property isn't an object"` error
**WRONG**: `return [{json: $json}]` — `$json` is a sandbox proxy that fails `validateItem()`

### Sandbox Limitations (n8n Cloud)
NOT available: `fetch()`, `$helpers.httpRequest()`, `AbortController`, external npm packages
Available: `require('crypto')`, `Buffer`, `URL`, `DateTime` (Luxon), `$jmespath()`

## Connection Format Check
```json
"connections": {
  "Source Node Name": {
    "main": [[{"node": "Target Node Name", "type": "main", "index": 0}]]
  }
}
```
WRONG: `{"source": "...", "target": "..."}` or `{"from": "...", "to": "..."}`

## Webhook Security
- Verify authentication (shared secret, HMAC signature validation)
- No secrets in URL parameters (use headers)
- Input treated as untrusted — validate before DB writes
