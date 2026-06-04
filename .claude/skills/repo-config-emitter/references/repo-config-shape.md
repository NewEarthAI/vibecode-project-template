# repo-config-emitter — source shape reference

> The shape of the three in-repo source classes this emitter reads, and the `config`-kind
> rationale. Schema authority for the OUTPUT is
> 📄 `../../topology-substrate/references/canonical-shape.md`.
>
> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 5.

---

## 1. In-repo n8n workflow JSON (the `repo:` counterpart to Session-3's `cloud:`)

### Location (v1 scope)

BuyBox-AI keeps n8n workflow exports as JSON in TWO directories — the emitter walks BOTH:
- `workflows/*.json` (3 files at build time)
- `n8n-workflows/*.json` (1 file at build time — the id is in the filename)

Excluded: `specs/**/*.json` (e.g. `specs/gmail-parser-hardening/workflow_backup_pre_v2_fix.json`
is a backup, NOT live repo topology). v1 = the two canonical dirs only.

### The CRITICAL shape difference from Session 3 — TOP-LEVEL, not body-wrapped

Session-3's n8n MCP returned `nodes`/`connections` under a `body` wrapper. The in-repo JSON
files are raw n8n exports with everything at the TOP LEVEL:

```jsonc
{
  "id": "Gz8EKN9CWxIDcGXcoCmYq",          // the n8n workflow id (used for attributes + calls resolution, NOT the node id)
  "name": "Gmail -> Clozers Comps",
  "active": true,
  "isArchived": null,                       // OFTEN null on exports -> transform defaults to false
  "tags": [],                               // flat array on exports (Session 3's MCP returned objects)
  "nodes": [ ... ],                         // TOP LEVEL
  "connections": { ... },                   // TOP LEVEL
  "createdAt": "...", "updatedAt": "...", "settings": {...}, "pinData": {...}, ...
}
```

The transform accessor is `$wf.nodes` / `$wf.connections` (NOT `$wf.body.nodes`). The invoking
session builds a per-file record carrying `relpath` (the repo-relative path — the id prefix) plus
the fields above.

### Node + connection shape (identical to Session 3)

```jsonc
"nodes": [
  { "id": "<guid>", "name": "<name>", "type": "n8n-nodes-base.<type>", "position": [x,y], "disabled": false, "parameters": {...} }
]
"connections": {
  "<Source Node NAME>": { "main": [ [ {"node": "<Target Node NAME>", "type":"main", "index":0} ] ] }
}
```

- `connections` is keyed by node **NAME**, not GUID → the transform resolves name→GUID per
  workflow; unresolved names → `unresolved:<name>` (surfaced loud, counted).
- Sticky notes (`n8n-nodes-base.stickyNote`) are filtered out before emission.
- `disabled: true` is the A.11 presence-≠-effectiveness signal — emitted faithfully.

### Cross-workflow `calls` — the n8n-id ↔ repo-path indirection

An `executeWorkflow` node references its target by n8n workflow id
(`parameters.workflowId`, plain-string OR resource-locator `{__rl, value, mode}` shape). But the
in-repo node id is `repo:<filepath>`, not the n8n id. So the transform:
1. builds an `n8n_id → repo_node_id` map across the emit set (every workflow's `id` field → its
   `repo:<relpath>` node id);
2. resolves each `calls` edge's target through it;
3. a target NOT in the emit set → `unresolved-workflow:<id>` (dropped by the idset filter, counted
   in `cross_workflow_edges_skipped`).

This is the one bit Session 3's transform didn't need (cloud node ids WERE the n8n ids).

### Node id scheme

- workflow: `repo:<relpath>` (e.g. `repo:workflows/gmail-clozers-comps.json`)
- workflow_node: `repo:<relpath>:<node-guid>`

---

## 2. vercel.json (a `config` node)

Repo-root file. Shape:

```jsonc
{
  "headers":  [ { "source": "/assets/(.*)", "headers": [ {"key":"Cache-Control", "value":"..."} ] }, ... ],
  "rewrites": [ { "source": "...", "destination": "/index.html" } ],
  "redirects": [ ... ]   // optional
}
```

Emitted as ONE node: `id: "repo:vercel.json"`, `kind: "config"`, `emitter: "manual"`,
`attributes: {config_type:"vercel", header_count, rewrite_count, redirect_count}`,
`manual_justification` (required). NO edges in v1 (the route→function deploy binding is the M4
`vercel_api` observed-state emitter — §3.5 distinguishes the DECLARED file from the DEPLOYED state).

---

## 3. package.json (a `config` node)

Repo-root file. Shape:

```jsonc
{
  "name": "vite_react_shadcn_ts",
  "version": "0.0.0",
  "dependencies": { "<pkg>": "<version>", ... },
  "devDependencies": { ... },
  "scripts": { "build": "...", "typecheck": "...", ... }
}
```

Emitted as ONE node: `id: "repo:package.json"`, `kind: "config"`, `emitter: "manual"`,
`attributes: {config_type:"package", name, version, dependency_count, dev_dependency_count,
script_count, dependencies{}}`, `manual_justification` (required). NO edges in v1.

**Why one node, not 94 per-dep nodes**: the frozen enum has no `dependency` kind, and external
npm packages are not in-repo code. The dep tree rides as an `attributes.dependencies` object —
queryable ("what version of React") without enum growth. Per-dependency nodes are a v1.1 concern
if M4 reconciliation needs them.

---

## 4. The `config` kind rationale (M3 Session 5 amendment)

The frozen 9-kind enum (`table|view|function|trigger|rls_policy|edge_function|workflow|
workflow_node|ts_module`) had no home for a config/dependency file. The continuation's first idea
— `kind: "manual"` — is **impossible**: `manual` is an EMITTER value, not a kind (substrate.sh:
"a manual node still carries one of the domain kinds"). validate-schema rejects a kind not in
`VALID_KINDS`.

Doctrine 05 names "deploy config" as a read source artefact in §1 + §3 + Appendix C (the
`vercel_api` row), placing `vercel.json` (the declared FILE, not the deployed state) and
`package.json` (the dependency manifest) in scope as DECLARED structure — §3.5's boundary is
*runtime tracing* (the deployed-state binding), which stays OUT. The kind enum simply never gave
the declared config FILE a home. So M3 Session 5 added one `config` kind via the
doctrine-verification-gate triple gate (deletion-as-re-invention + `/code-council` on the doctrine
delta + real-decision test against the live `Gz8…` cloud-vs-repo drift), recorded in
📄 `../../../council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md`. The amendment is
additive (no field-schema change — `config_type` rides inside the existing `attributes` object,
a single counted field in Test D), so Test D separability between Doctrines 04/05/06 is unaffected
(all three pairwise Jaccard overlaps unchanged < 50%).

A `config` node is ALWAYS `emitter: "manual"` + a mandatory `manual_justification` (§6.6): unlike
`pg_depend` / `n8n_parser` / `dependency_cruiser`, no machine emitter parses a config file into a
dependency graph in v1, so a config node is a source-orphan-class node — its source artefact
exists and is named in `source_file`, but no generator derives edges from it. `config_type`
sub-discriminates the file class without enum growth (tsconfig, env schema → future `config_type`
values, not new kinds).

---

## References

- `../../topology-substrate/references/canonical-shape.md` — the frozen output schema (the
  `config` kind is documented there)
- `../n8n-cloud-emitter/references/n8n-workflow-shape.md` — the n8n JSON shape reference (the node
  + connection shape is identical; only the wrapper differs)
- `docs/operational-doctrine/05_topology-from-source.md` — §1 + §3 + Appendix C ("deploy config"
  as a read source artefact = the declared-structure in-scope grounding; §3.5 is the runtime
  exclusion), §6.5.1 (the `config` row), §6.6 (source-orphan rule)
