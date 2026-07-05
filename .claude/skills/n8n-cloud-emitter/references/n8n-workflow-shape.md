# n8n workflow shape — schema reference for the n8n MCP's `n8n_get_workflow` payload

> Equivalent of Session 2's `pg-depend-query-map.md`. Captures the genuinely novel shape
> discipline the transform must respect — the gotchas that would silently corrupt the
> topology if missed.

**Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 3. **Source of
truth**: live observation of `mcp__n8n-mcp-<your-instance>__n8n_get_workflow(mode="active")` against
my-project's <your-instance> instance (verified 2026-05-26).

---

## 1. Top-level workflow payload (`mode="active"` + `mode="full"`)

```jsonc
{
  "id": "<workflow_id>",          // opaque short string, e.g. "Gz8EKN9CWxIDcGXcoCmYq"
  "name": "<human-readable>",
  "active": true,
  "isArchived": false,
  "tags": [                        // array of {id, name, createdAt, updatedAt}
    {"id": "OAhsiF7CyhQPalKk", "name": "buybox", ...}
  ],
  "nodeCount": 34,                 // includes stickyNote nodes — DO NOT use as topology count
  "connectionCount": 27,            // n8n's count — ours differs after dedup
  "nodes": [ ... ],                // ARRAY of node objects (next section)
  "connections": { ... }            // OBJECT keyed by node NAME (not GUID) — see §3
}
```

`active` and `isArchived` are independent: a workflow can be active+archived (rare),
inactive+archived (the "graveyard" — present in my-project), inactive+not-archived (older
working copies, the bulk of the "deal intake" tag at my-project), or active+not-archived
(the live operational set).

---

## 2. Node object — the `nodes[]` entries

```jsonc
{
  "id": "<node_guid>",              // stable UUID; the substrate id discipline uses this
  "name": "<human-readable name>",  // editable + renameable — NEVER use as substrate id
  "type": "n8n-nodes-base.<type>",   // e.g. "executeWorkflow", "stickyNote", "webhook"
  "position": [<x>, <y>],            // pixel coordinates in the n8n editor
  "disabled": false,                 // optional — defaults to false; A.11 load-bearing
  "parameters": { ... },             // present in mode="active" + mode="full"
  "credentials": { ... },            // optional, OAuth bindings (out of scope v1)
  "webhookId": "<uuid>",             // optional, only on webhook nodes
  "notes": "<string>",               // optional, free-text annotation
  "notesInFlow": <bool>              // optional
}
```

### Key invariants

- `id` is stable across renames + edits; `name` is NOT
- `disabled: true` means the node is in the workflow body but its connections are not
  executed when the workflow runs (the A.11 analogue)
- `stickyNote` nodes have no flow (no connections in or out) — they're documentation
- `executeWorkflow` nodes carry the cross-workflow target in `parameters.workflowId`
  (next section)

---

## 3. The `connections` shape — keyed by NAME, NOT GUID

This is the load-bearing schema gotcha. n8n's `connections` object is keyed by node
**name**, both at the top level and inside each branch's target list:

```jsonc
{
  "connections": {
    "Source Node NAME (not GUID)": {
      "main": [
        [                                                  // branch 0
          {"node": "Target Node NAME", "type": "main", "index": 0}
        ],
        [                                                  // branch 1 (Switch / If node)
          {"node": "Other Target Name", "type": "main", "index": 0}
        ]
      ]
    }
  }
}
```

### Why this matters

- A user editing a node's name in the n8n UI mutates `connections` everywhere — the n8n
  backend renames the keys.
- The substrate id discipline MUST use the stable `id` (GUID), not the editable name.
- The transform builds a `name → id` lookup ONCE per workflow from `nodes[]`, then resolves
  every `connections` source + target name to its GUID before emitting an edge.

### Unresolved-name failure mode

A `connections` entry that names a node not present in `nodes[]` is a real n8n catalogue
bug (an orphaned reference, usually from an aborted rename). The transform emits the edge
with a synthetic `unresolved:<name>` target so the substrate's bulk-write integrity check
surfaces it loud, NOT a silent-drop. The completeness diagnostic counts these — operator
should investigate.

### Branch collapse

Multiple branches (`main[0]`, `main[1]`, ...) can target the same downstream node from
the same source (rare but possible). The transform deduplicates edges by
`(source, target, type)` so duplicate edges collapse — a future enhancement could emit
branch index as an edge attribute, deferred to v1.1.

---

## 4. `executeWorkflow` — cross-workflow target id has TWO shapes

`executeWorkflow` nodes carry the target workflow's id in `parameters.workflowId`. Two
shapes are observed in the wild:

### Shape 1 — plain string
```jsonc
{ "parameters": { "workflowId": "Gz8EKN9CWxIDcGXcoCmYq" } }
```

### Shape 2 — resource-locator
```jsonc
{
  "parameters": {
    "workflowId": {
      "__rl": true,
      "value": "Gz8EKN9CWxIDcGXcoCmYq",
      "mode": "id"
    }
  }
}
```

This is documented in `.claude/rules/n8n-patterns.md` as the n8n v1.2+ resource-locator
format. The transform's `extract_workflow_id` helper handles both shapes:

```jq
def extract_workflow_id($wf_id_value):
  if ($wf_id_value | type) == "string" then $wf_id_value
  elif ($wf_id_value | type) == "object" then
    if ($wf_id_value | has("value")) then $wf_id_value.value
    else null
    end
  else null
  end;
```

`null` (the executeWorkflow node has no target — happens during workflow editing) results
in NO cross-workflow edge being emitted; the workflow_node itself IS still emitted (the
node exists; only the edge is absent).

---

## 5. The `mode="active"` vs `mode="full"` fallback

`mode="active"` returns the PUBLISHED graph (the graph actually running). For workflows
that have NEVER been activated, this errors with:

```
"data": { "code": "NO_LIVE_VERSION", "message": "Workflow has never been activated" }
```

(Exact error wording may vary; the harness pattern is: try `active`, on error try `full`.)

`mode="full"` returns the DRAFT graph (the editor state, possibly unsaved). For
never-activated workflows the draft IS the only structure that exists. Doctrine 05 P1
(generator-not-author) prefers actual; recording the fallback in the workflow node's
`attributes.fetch_mode` (`"active"` or `"full"`) makes the provenance honest.

---

## 6. Sticky-note filter

`n8n-nodes-base.stickyNote` is documentation, never part of the flow. Sticky notes:
- Have no inbound or outbound connections
- Carry their text in `parameters.content`
- Sometimes have `position` outside the workflow's bounding box

Filter rule (used in the transform):

```jq
.nodes | map(select(.type != "n8n-nodes-base.stickyNote"))
```

The `connections` object should never reference a stickyNote — but defensive: the
`name → id` lookup is built AFTER the filter, so a `connections` entry that names a
stickyNote will be flagged as `unresolved:<name>` and surface in the diagnostic.

---

## 7. Trigger type derivation

Doctrine 05 §6.5.1 requires `workflow.attributes.trigger_type`. n8n doesn't expose a
"workflow trigger type" field directly — it's implicit in the entry node's type. The
transform derives it from the first non-stickyNote node whose type matches a known
trigger pattern:

| n8n node type pattern (regex) | Derived `trigger_type` |
|---|---|
| `*Trigger$` (matches `manualTrigger`, `scheduleTrigger`, `errorTrigger`, `executeWorkflowTrigger`, etc.) | the node's type verbatim |
| `*webhook$` | the node's type verbatim |
| `*cron$` / `*schedule$` | the node's type verbatim |
| no match (workflow has no obvious entry) | `"manual"` (safe default) |

This is a heuristic, not a contract — operator can disambiguate by inspecting the
workflow's first executable node in the n8n UI. The honest value lives in
`attributes.trigger_type`; downstream consumers can ignore it if they prefer to walk
nodes themselves.

---

## 8. Why we trust the n8n MCP — and its limits

The MCP exposes a clean read-only surface. **This emitter uses ONLY three tools**:
`n8n_list_workflows`, `n8n_get_workflow`, `n8n_health_check`. `n8n_executions` is
MCP-available but explicitly OUT OF SCOPE for this emitter — it returns runtime
execution data, not structural topology (Doctrine 05 §3.5 declared-structure vs
observed-execution distinction). See SKILL.md "Filtering decisions" table.
The shape above is verified empirically against the live <your-instance> instance — what
the three approved tools return IS what we work with.

**Known limits**:
- No `search_workflows` (only `search_nodes`) — we use tag-union + id-override for
  discovery
- No `projectId`-by-default — projects are enterprise-feature gated; tag is the
  cross-edition discovery signal
- `nodeCount` in `list_workflows` includes stickyNotes — recompute from the filtered
  `nodes[]` in the workflow body
- Execution data is gated behind `n8n_executions` (out of scope for topology — runtime
  signal, not structural)

---

## References

- 📄 `scripts/queries.md` — the MCP recipe + read-only contract
- 📄 `scripts/transform.jq` — the frozen jq transform applying this shape discipline
- 📄 `.claude/rules/n8n-patterns.md` — project-wide n8n discipline (resource-locator,
  immutable node names, execution-mode rules)
- 📄 `docs/operational-doctrine/05_topology-from-source.md` — §6.2 (this emitter),
  §6.5.1 (the per-kind contract), §7.3 (cross-workflow edges — the leverage point),
  A.11 (presence ≠ effectiveness)
