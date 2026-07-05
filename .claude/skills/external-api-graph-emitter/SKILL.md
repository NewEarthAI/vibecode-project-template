---
name: external-api-graph-emitter
description: |
  The external-API / cross-system topology emitter — the visual-layer Phase-1b mapper. Reads a
  project's n8n workflow JSON (READ-ONLY, via the entity's n8n MCP, e.g.
  mcp__n8n-mcp-<your-instance> for my-project) and parses its HTTP-request nodes into Doctrine 05 §6.1
  canonical-shape cross-system edges + external_endpoint nodes: an n8n workflow_node ->
  reads_from/writes_to a Supabase REST table, -> invokes a Supabase edge function, -> calls an
  external API (Stripe, etc.), or -> a blind-spot when the URL is runtime-constructed (an n8n
  ={{ expression }}). It OWNS the external_endpoint kind (emitter external_api_parser); the code
  emitter is the documented joint-attribution co-producer (it emits blind-spot external_endpoints for
  unresolved frontend supabase calls). Resolution is against the LIVE substrate node-id set read
  READ-ONLY; an unresolved Supabase target becomes a blind-spot UNLESS supabase-live coverage is
  definitively "covered" (then a counted drop = a genuine dangling reference) — the R2 fail-safe that
  never silently drops. Writes via ONE bulk-write to the topology substrate (the Session-1 contract).
  Use when: an operator wants the cross-system "n8n <-> database / external-API" edges in the
  substrate for the visual layer; "/external-api-emit", "emit the cross-system edges", "what does
  this workflow call", "which workflows hit Supabase / Stripe"; AND/OR after an n8n workflow with
  HTTP nodes landed (P3 regenerate-not-edit).
  Do NOT use for: writing to n8n cloud (read-only); the within-workflow node graph (that is the
  n8n-cloud emitter — this emitter adds only the cross-SYSTEM edges out of HTTP nodes); frontend
  supabase calls (the code emitter, Phase 1a, owns those); computing reconciliation / drift (M4);
  editing the substrate code (Session-1 contract is FROZEN — compose, do not reimplement).
allowed-tools: Bash, Read, mcp__n8n-mcp-<your-instance>__n8n_health_check, mcp__n8n-mcp-<your-instance>__n8n_list_workflows, mcp__n8n-mcp-<your-instance>__n8n_get_workflow
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-06-05
programme: intent-actual-gap-mechanism
---

# external-api-graph-emitter — cross-system edges from n8n HTTP nodes

The visual layer's headline feature is **cross-system dependency edges** — wiring that crosses a
system boundary. This emitter produces the **n8n side**: every HTTP-request node *and dedicated Supabase
node* in a workflow that hits a Supabase REST table, a Supabase edge function, or an external API becomes
a cross-system edge. It is the `external-api-graph` emitter the substrate has long declared in
`missing_emitters`.

## What it produces

**(a) Per HTTP-request node** (`.type` matching `httpRequest`, URL in `.parameters.url`, method in
`.parameters.method`), classified by URL:

| URL shape | edge type | target | confidence |
|---|---|---|---|
| `https://<ref>.supabase.co/rest/v1/<table>` | `reads_from` (GET) / `writes_to` (POST/PUT/PATCH/DELETE) | `public.<table>` (R9-normalised) | `declared-medium` (read/write inferred from the HTTP method — a heuristic) |
| `https://<ref>.supabase.co/functions/v1/<name>` | `invokes` | `repo:supabase/functions/<name>` | `declared-high` |
| any other literal URL (`https://api.stripe.com/...`) | `calls` | a NEW `external_endpoint` node `ext:external-api:<host><path>` (classification `external-api`) | `declared-high` |
| an n8n expression URL (`={{ ... }}` / contains `{{ }}`) | `calls` | a `blind-spot` `external_endpoint` `ext:blind-spot:n8n:<wf>:<node>` | `blind-spot` (amber) |

**(b) Per dedicated Supabase node** (`.type` ending `.supabase` — the action node, NOT `supabaseTrigger`),
classified by `.parameters.operation` + `.parameters.tableId` (a string or an n8n resourceLocator `{__rl}`):

| node shape | edge type | target | confidence |
|---|---|---|---|
| literal `tableId`, read op (`get` / `getAll`) | `reads_from` | `public.<table>` (R9-normalised) | `declared-medium` (read/write inferred from the operation) |
| literal `tableId`, write op (`create` / `update` / `upsert` / `delete`) | `writes_to` | `public.<table>` | `declared-medium` |
| expression `tableId` (`={{ ... }}` / contains `{{ }}`) or empty | `calls` | a `blind-spot` `external_endpoint` `ext:blind-spot:n8n:<wf>:<node>` | `blind-spot` (amber) |

A resolved REST target that is NOT in the live substrate routes by R2 (counted drop when supabase-live
coverage is `covered`; blind-spot otherwise) — identical for both node families. The source node id is
the n8n-cloud-emitter's `cloud:<wf.id>:<node.id>` workflow_node — so this emitter **composes with** the
n8n-cloud emitter (which must have run for the source nodes to exist), it does not duplicate it.

## The two honesty boundaries (LOCKED — the framing-audit reframe)

1. **Declared-wiring-only + blind-spots, never green, never dropped.** A runtime-constructed URL
   (an n8n `={{ expression }}`) is rendered as an **amber `blind-spot`** `external_endpoint`, never a
   green edge (we do not statically know the target) and never silently dropped (that reads as "no
   call"). Doctrine 05 §3.5 made visible, not violated.
2. **The R2 fail-safe (never a silent drop).** A Supabase-REST/function target that does NOT resolve
   against the live substrate node-id set becomes a **counted drop** (a logged dangling-reference
   diagnostic) ONLY when supabase-live coverage is definitively `covered`. In every other coverage
   state (`declared-missing` / `degenerate` / `absent` / key-absent / empty) it becomes a **blind-spot**
   — the fail-safe direction. There is no code path where an unresolved cross-system call vanishes.

## Joint-attribution (Doctrine 05 P4)

This emitter (`external_api_parser`) **owns** the `external_endpoint` kind. The code emitter
(`dependency_cruiser`, Phase 1a) also emits `blind-spot` `external_endpoint` nodes for unresolved
frontend supabase calls. Each *node* still carries exactly one emitter (P4 holds at the node level);
the *kind* has two producers — recorded as a named exception in `canonical-shape.md` so the
health-check's `owned_but_uncovered` detector does not false-fire.

## Run (the driving session)

```bash
# 1. Read the entity's workflows READ-ONLY (live: the n8n MCP n8n_get_workflow per scoped id; or an
#    in-repo workflow JSON file). Collect them into a JSON array -> /tmp/wfs.json.
# 2. Read the LIVE substrate resolution inputs READ-ONLY (BEFORE this emit writes):
SUBSTRATE_IDS="$(bash ../topology-substrate/scripts/substrate.sh read-topology '[.nodes[].id]' 2>/dev/null || echo '[]')"
SB_COV="$(bash ../topology-substrate/scripts/substrate.sh read-topology '.emitters["supabase-live"].coverage' 2>/dev/null | tr -d '"')"
# 3. Transform + emit:
jq -n --slurpfile workflows /tmp/wfs.json --arg now "$NOW" --arg src_commit "live:<your-instance>:WF" \
   --argjson substrate_ids "$SUBSTRATE_IDS" --arg supabase_coverage "$SB_COV" \
   -f scripts/transform.jq > /tmp/combined.json
jq '.nodes' /tmp/combined.json > /tmp/nodes.json ; jq '.edges' /tmp/combined.json > /tmp/edges.json
bash scripts/emit.sh /tmp/nodes.json /tmp/edges.json "my-project"
```

## Scope at this version (1b)

- **[NOW] built + evalled**: the n8n HTTP-request-node surface AND the dedicated Supabase-node surface
  (follow-up #4) — this file + `scripts/transform.jq` + `scripts/emit.sh` + `evals/cross-system-n8n.sh`
  (34 assertions green). Run against in-repo / fixture workflow JSON.
- **[SHIPPED elsewhere] edge-function `fetch()` external-API surface** (follow-up #1, 2026-06-06): landed
  in the **code emitter** (`code-emitter/scripts/extract.mjs` + `transform.jq`), NOT here — only the code
  emitter parses edge-function TS, so a `fetch()` external endpoint carries emitter `dependency_cruiser`
  (the documented joint-attribution co-producer). Edge-function *supabase* calls (`.from` / `.invoke`)
  were already covered by the Phase-1a code emitter. See `code-emitter/evals/fetch-external.sh`.
- **[M5-GATED]**: running LIVE against a client n8n cloud + promoting `external-api-graph` to a
  registered emitter SLOT (KNOWN_EMITTER_NAMES) with a coverage heartbeat + publishing. At [NOW] scope
  `emit.sh` does NOT call `mark-emitter-ran` (the slot does not exist yet); the emitter PRODUCES +
  validates the topology, and coverage tracking lands with the live run.

## Known limitations (honest)

- Parses two node families: `httpRequest`-type nodes (by `.parameters.url`/`.endpoint`) and dedicated
  `n8n-nodes-base.supabase` action nodes (by `.parameters.operation` + `.parameters.tableId`, follow-up
  #4). Other node types that reach Supabase via a non-standard shape (e.g. a community node, or a Code
  node issuing raw HTTP) are NOT parsed — they would surface only if rewritten as an httpRequest or the
  dedicated Supabase node.
- The source workflow_node (`cloud:<wf>:<node>`) must already exist in the substrate (the n8n-cloud
  emitter must have run). If it has not, the cross-system edge fails referential integrity at
  bulk-write — run the n8n-cloud emitter first.
- **id-less node dedup (rare, documented):** the accounting invariant (`accounted == total_source_nodes_seen`)
  proves every source node is *routed* to an outcome, but it counts pre-dedup. Two nodes that BOTH lack an
  `id` get the same `source_id` `cloud:<wf>:?`; if they also share target+type they collapse to one edge
  under `unique_by` and the counter does not separately surface that. Real n8n nodes always carry ids — only
  a hand-built/malformed workflow JSON triggers this. The surviving edge is honest (never a false-green); a
  collapsed duplicate is an under-count of real edges, not a fabricated one. Pre-existing on the HTTP path.

## References

- `../topology-substrate/references/canonical-shape.md` — the `external_endpoint` kind + the
  joint-attribution exception + the R2 blind-spot routing rule (the schema authority).
- `docs/operational-doctrine/05_topology-from-source.md` §6.5.1 — the `external_endpoint` kind row + note.
- `../n8n-cloud-emitter/` — the sibling emitter whose `cloud:<wf>:<node>` ids this composes with, and
  whose structure this mirrors.
- `../code-emitter/` — Phase 1a, the frontend cross-system surface + the joint-attribution co-producer.
- `council/sessions/2026-06-05-visual-layer-phases-0-2-build-gate.md` — the gate + the R2/R3/R9 resolutions.
