# n8n-cloud-emitter — MCP query recipe

> Equivalent of Session 2's `queries.sql`. n8n cloud is read via the MCP server, NOT via SQL —
> hence Markdown rather than SQL. The Claude session driving the emit issues these MCP calls
> in order and collects the JSON results, then runs the frozen `transform.jq` on them.

**Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 3. **MCP**:
`mcp__n8n-mcp-<instance>__*` (the entity's n8n instance — operator-confirmed). **Schema authority**:
`../topology-substrate/references/canonical-shape.md`.

---

## Read-only contract

Every call below is on the **read surface** of the n8n MCP. The emitter never invokes the
write surface (`n8n_create_workflow`, `n8n_update_full_workflow`, `n8n_update_partial_workflow`,
`n8n_delete_workflow`, `n8n_deploy_template`, `n8n_test_workflow`, `n8n_autofix_workflow`,
`n8n_manage_credentials`, `n8n_manage_datatable`). The SKILL.md `allowed-tools` list MUST
restrict to the four read-only tools listed in §0 below.

---

## §0 — Read-only tool surface

| MCP tool | Purpose |
|---|---|
| `n8n_health_check` | Phase 0 readiness — confirms MCP is reachable + version is current |
| `n8n_list_workflows` | Phase 1 discovery — one call per tag in `entity-scope.json#tags` |
| `n8n_get_workflow` | Phase 2 fetch — one call per workflow in the scoped union |
| (no others) | — |

---

## §1 — Health check (Phase 0)

```
mcp__n8n-mcp-<instance>__n8n_health_check(mode="status")
```

Expected: `success=true`, `status=ok`. If not, halt — the substrate write is moot when the
source is unreachable. (Coverage classification for that case is `degenerate` per
Doctrine 05 P6 / §8.4 — emitter records the degenerate state and exits rc 6.)

---

## §2 — Tag-union discovery (Phase 1)

For each tag in `entity-scope.json#tags`:

```
mcp__n8n-mcp-<instance>__n8n_list_workflows(tags=[<one_tag>], limit=100)
```

(Pass tags one-at-a-time. The n8n API tag-filter is single-tag-per-call; sending an array
with multiple values applies an AND filter which is the wrong intersection for our union
purpose.)

Collect every returned `id`. Union them with the id-override list in
`entity-scope.json#additional_workflow_ids`. Dedupe by id. The result is the **scope**.

For an example entity's tag set (the operator confirms each entity's tags at first
propagation), the v1 emit produces a set of distinct in-scope workflows (active + inactive +
archived), one node per workflow plus one node per workflow_node.

### Per-workflow metadata kept after Phase 1 (for the transform's later use)

For each workflow in the scope, keep `{id, name, active, isArchived, tags[]}` from
`list_workflows` — these populate the workflow node's `attributes.{name, active, archived,
tags}` later. `nodeCount` is NOT taken from `list_workflows` (it counts sticky notes too);
the transform recomputes `node_count` AND `connection_count` from the filtered nodes in the
fetched workflow body.

### §2a — Input pre-processing contract (REQUIRED — the transform expects this shape)

Between the MCP fetch (`§2` / `§3`) and the jq transform (`scripts/transform.jq`), the
invoking Claude session MUST shape each workflow into the contract `transform.jq` expects.
The MCP returns `nodes` and `connections` at the TOP LEVEL of the workflow object; the
transform expects them under a `body` key. Wrap each MCP response before assembling the
`workflows.json` input file:

```jq
# Per workflow, build:
{
  id, name, active, isArchived,
  tags,            # see Tag-shape note below
  fetch_mode,      # "active" or "full" — MUST be set explicitly; defaulting silently lies
  body: {nodes, connections}
}
```

**Tag-shape note**: the n8n MCP returns `tags` as an ARRAY OF OBJECTS
(`[{"id": "...", "name": "buybox", "createdAt": "...", ...}, ...]`). The substrate stores
them as ARRAY OF STRINGS. The transform performs a defensive flatten — passing through
either shape — but the operator-curated path is to flatten at this pre-processing step
(`(.tags // []) | map(.name)`) so the assembled input matches the documented contract
exactly. Either path produces the same substrate output; pre-flattening keeps the
diagnostics block accurate.

**Why the wrapper exists**: keeps the transform's input contract stable across data sources.
If a later v1.1 enhancement fetches workflow structure from a different MCP shape (e.g. a
file export, or a `mode="details"` response with execution stats wrapping nodes), the
wrapping step is where the adapter lives — `transform.jq` doesn't change.

**Without the wrapper**: `$wf.body.nodes` evaluates to `null`, defaults to `[]`, and the
transform silently produces an empty topology for every workflow. The harness exits PASS
but the substrate records 0 workflow_nodes — Session-3 code-council CRITICAL silent-empty-graph trap.

---

## §3 — Per-workflow structure fetch (Phase 2)

For each workflow `id` in the scope:

```
mcp__n8n-mcp-<instance>__n8n_get_workflow(id=<wf_id>, mode="active")
```

If the call errors with `no live version` / `never been activated` (workflows that have
NEVER been activated have no published graph), fall back to:

```
mcp__n8n-mcp-<instance>__n8n_get_workflow(id=<wf_id>, mode="full")
```

…and log the fallback in the emit's completeness diagnostic. Doctrine 05 P1
(generator-not-author) prefers the actual published graph; for never-activated workflows
the draft IS the only structure that exists — recording the fallback is honest provenance.

### What the call returns

In `mode="active"`:
```json
{
  "id": "<workflow_id>",
  "name": "<human-readable name>",
  "active": true,
  "isArchived": false,
  "nodes": [
    {
      "id": "<node guid>",
      "name": "<human-readable node name>",
      "type": "n8n-nodes-base.<type>",
      "position": [<x>, <y>],
      "disabled": false,   // OR true (load-bearing A.11 analogue)
      "parameters": { ... }, // present in mode="full" + mode="active"
      "credentials": { ... }, // optional
      "webhookId": "<uuid>" // optional, only on webhook nodes
    },
    ...
  ],
  "connections": {
    "<Source Node NAME (not GUID)>": {
      "main": [
        [ {"node": "<Target Node NAME>", "type": "main", "index": 0} ],
        [ ... ]  // branches in the same edge slot — collapsed to one edge per (src,tgt) in v1
      ]
    }
  },
  "tags": [...]
}
```

### CRITICAL — `connections` is keyed by node NAME, not GUID

n8n names are user-editable and renameable; the per-node `id` GUID is stable. Build a
`name → id` lookup ONCE per workflow from `nodes[]`, then resolve every source + target
name in `connections` to its GUID before emitting an edge. The transform fails LOUD on an
unresolved name (emits an edge to a synthetic `unresolved:<name>` target so the substrate's
bulk-write integrity check surfaces it). Silent-drop would mask a real catalogue bug.

---

## §4 — `executeWorkflow` parameter walk (the cross-workflow edge surface)

Doctrine 05 §7.3 names cross-workflow edges as a load-bearing leverage point. They come
from `executeWorkflow` nodes — each one has its target workflow id in
`parameters.workflowId`, which has **two possible shapes**:

```jsonc
// Shape 1 (plain string):
{ "parameters": { "workflowId": "Gz8EKN9CWxIDcGXcoCmYq" } }

// Shape 2 (resource-locator, per project's .claude/rules/n8n-patterns.md):
{ "parameters": { "workflowId": { "__rl": true, "value": "Gz8EKN9CWxIDcGXcoCmYq", "mode": "id" } } }
```

The transform handles both via a small jq helper (`extract_workflow_id`). If the target
workflow is **outside the scope** (a BuyBox workflow calls a non-BuyBox workflow), the edge
is SKIPPED with a logged warning + counted in the completeness diagnostic — v1 does NOT
emit a placeholder stub for out-of-scope targets. (Reason: the substrate's referential
integrity would reject an edge whose target is absent; a stub workflow would lie about
coverage. Out-of-scope targets become visible only via the diagnostic.)

If the target id is missing OR null OR doesn't resolve, the edge is skipped + counted as a
"dangling-target" warning.

---

## §5 — Sticky-note exclusion

n8n stores documentation as `n8n-nodes-base.stickyNote` nodes. They carry no flow and are
not part of the topology. The transform filters them out before emission:

```jq
($workflow.nodes | map(select(.type != "n8n-nodes-base.stickyNote")))
```

Sticky-note nodes are counted in the verbatim `list_workflows` `nodeCount` but NOT in the
emitted `node_count` attribute on the workflow node.

---

## §6 — `disabled: true` round-trip (the A.11 analogue)

A workflow_node with `disabled: true` is in the workflow body but its connections are NOT
executed. This is the n8n equivalent of an RLS policy with `enabled: false` — presence
≠ effectiveness. Doctrine 05 A.11 names this as a real silent failure mode (a disabled
node that should be on, or an enabled node that should be off, is a topology drift signal).

The transform emits every non-stickyNote node with its `disabled` flag faithfully populated
on `attributes.disabled`. Connections from a disabled node are STILL emitted as edges
(they exist in the workflow body) — the substrate carries the structural fact; the
reconciliation mechanism (M4) interprets the meaning.

---

## §7 — Completeness diagnostic (the operator's safety net)

At emit time, after the transform completes, the harness prints:

```
n8n-cloud emit complete:
  Tag-union workflows: V (from N tag calls)
  Id-override workflows: M
  Total scope: V+M distinct workflows
  Active: A   Inactive: I   Archived: R
  Node-fetch fallbacks (active→full): F
  Emitted workflows: W (workflow nodes)
  Emitted workflow_nodes: N (after stickyNote exclusion of S)
  Edges: E_total (X within-workflow + Y cross-workflow + Z containment)
  Skipped (out-of-scope target): O
  Skipped (unresolved name): U
```

If `Skipped (unresolved name): U` is greater than zero, the eval considers that a real
catalogue bug — the transform surfaces it loud, the operator should investigate, NOT a
silent-drop.

The diagnostic + the substrate's heartbeat (`mark-emitter-ran n8n-cloud covered`) together
give the operator an honest "did the scope catch everything" view.

---

## §8 — Provenance

Every emitted node carries:

```
source_file:   "n8n_cloud (live)"
source_commit: "live:<instance>:<workflow_id>"
source_line:   null      (workflows are JSON objects, not line-addressable usefully)
emitter:       "n8n_parser"
timestamp:     "<ISO 8601 UTC of this run>"
declared_intent_ref: null    (M4 wires it)
```

The `live:<instance>:<workflow_id>` convention is **deterministic per workflow** so a
multi-workflow substrate downstream can disambiguate which workflow a node came from. This
satisfies D05 P2 (every node traces to source) without fabricating a git commit.

---

## §9 — Why no parallelisation

A typical run is **~6 tag calls + ~11 workflow-content calls** = roughly 17 MCP calls per
emit. At ~2 s per call (n8n cloud latency) this is ~35 s of round-trips. Acceptable; no
parallelisation needed for v1. Parallelising would risk hitting the n8n cloud rate-limit;
the cost of a slightly-slower emit is much lower than the cost of a 429-Too-Many-Requests
mid-run. (Documented for v1.1 if scale grows.)

---

## §10 — Why not search workflows by name pattern

The n8n MCP exposes a `search_nodes` tool (for node-type discovery) but does NOT expose
`search_workflows` (for workflow discovery by name pattern). Tag is the only API-level
scope signal. This is why `entity-scope.json#additional_workflow_ids` exists — the
belt-and-braces safety net for untagged workflows the operator knows belong in the scope.

---

## §11 — Why no project filter (`projectId`)

The entity n8n instance does have projects (enterprise feature). The `n8n_list_workflows`
tool DOES accept a `projectId` parameter. However: per the operator's per-entity contract,
each NewEarth entity organises its work via folder/tag conventions (not necessarily
projects), and `projectId` is enterprise-only. Tag-union + id-override is the
project-agnostic discovery path; folks who adopt a per-project organisation can extend the
recipe later by adding a `projectId` field to `entity-scope.json`.

---

## References

- `entity-scope.json` — the operator-curated tag set + id-override for the entity
- `transform.jq` — the frozen jq transform
- `emit.sh` — the finishing harness
- `references/n8n-workflow-shape.md` — schema reference for the n8n MCP's get_workflow payload
- `docs/operational-doctrine/05_topology-from-source.md` — §6.2, §6.5.1, §7.3, A.11, Appendix C
- `.claude/rules/n8n-patterns.md` — resource-locator format, immutable node names, execution-mode rules
