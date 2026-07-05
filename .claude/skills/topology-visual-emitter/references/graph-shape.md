# Visual Graph Shape — `graph.json` contract (render-target-agnostic)

> **Authority**: this file is the output contract of `scripts/graph-transform.jq` (the substrate →
> render-graph transform). It is derived from `specs/16_VISUAL_LAYER_DESIGN.md` §2.3 + §3 and the FROZEN
> substrate contract `.claude/skills/topology-substrate/references/canonical-shape.md`. The transform reads
> the substrate READ-ONLY; this `graph.json` is a downstream rendering, NEVER a source of truth (Doctrine 05
> P5). Any render target — the local viewer, a future Agency-OS page, a future Hermes surface — consumes
> this shape unchanged.
>
> **Programme**: Intent-Actual-Gap Mechanism Build Programme, downstream application #1 (the visual layer),
> Wave 1. Build plan: the approved plan + `specs/16_VISUAL_LAYER_DESIGN.md`.

---

## Top-level envelope

```json
{
  "schema_version": "visual-v1",
  "entity": "<entity name — carried verbatim from the substrate>",
  "generated_at": "<ISO 8601 UTC — when this graph.json was produced>",
  "source_last_updated": "<the substrate's last_updated, carried for freshness>",
  "coverage": {
    "emitters": { "<name>": "<covered|absent|degenerate|declared-missing>", ... },
    "missing_emitters": [ {"name": "...", "reason": "..."} ]
  },
  "has_blind_spot_edges": false,
  "nodes":  [ /* render nodes — see below */ ],
  "edges":  [ /* render edges — see below */ ],
  "layers": [ /* logical groupings — see below */ ],
  "parent_map": { "<node_id>": ["<parent_node_id>", "..."] },
  "child_map":  { "<node_id>": ["<child_node_id>",  "..."] }
}
```

`parent_map` / `child_map` are carried **verbatim** from the substrate (which already derives + validates
them on every write — they cannot drift, per canonical-shape.md §parent_map/child_map). The transform does
NOT recompute them.

`has_blind_spot_edges` (Phase 2) is `true` when ANY render edge has `confidence == "blind-spot"`. It is the
chip's fail-safe signal — a substrate whose emitters all read `covered` can still carry blind-spot edges
(unresolved runtime targets), so the chip cannot rely on the coverage envelope alone.

## Render node

```json
{
  "id":         "<stable node id — verbatim from the substrate>",
  "kind":       "<substrate kind — table|view|function|trigger|rls_policy|edge_function|workflow|workflow_node|ts_module|config>",
  "render_kind":"<the visual class — see mapping below>",
  "category":   "<data|automation|code|config — the filter bucket>",
  "label":      "<short human label — derived from id (last path/colon segment)>",
  "emitter":    "<pg_depend|n8n_parser|dependency_cruiser|vercel_api|manual>",
  "coverage":   "<the emitter's coverage enum for this node's dimension>",
  "layer":      "<the layer id this node belongs to>",
  "source":     "<source_file@source_commit — provenance for the side panel>",
  "attributes": { /* the substrate's typed per-kind attributes, carried verbatim */ }
}
```

### `kind` → `render_kind` + `category` mapping (design §3)

| substrate `kind` | `render_kind` | `category` | notes |
|---|---|---|---|
| `table` | `table` | `data` | live `pg_depend` catalogue object |
| `view` | `schema` | `data` | |
| `function` | `function` | `data` | |
| `trigger` | `service` | `data` | |
| `rls_policy` | `policy` | `data` | a badge node; `attributes.enabled=false` renders a disabled-policy warning glyph |
| `edge_function` | `service` | `automation` | deploy state; `attributes.deployed_commit != source_commit` is a deploy-drift signal |
| `workflow` | `group` | `automation` | becomes a layer/container parent |
| `workflow_node` | `code` | `automation` | child of its workflow |
| `ts_module` | `code` | `code` | |
| `config` | `config` | `config` | declared config file (vercel/package) |
| `external_endpoint` | `external` | `external` | Phase 2 — a cross-system target (Supabase REST/function, external API, or an amber `blind-spot`). The viewer renders it by `attributes.classification`, NOT by drift state. |

`render_kind` and `category` are derived; the viewer dispatches colour/shape/filter on them. They are
additive — the substrate schema is untouched (Test D held).

## Render edge

```json
{
  "source": "<node_id>",
  "target": "<node_id>",
  "type": "<substrate edge type — free-form; cross-system values: reads_from|writes_to|invokes|calls>",
  "weight": 1,
  "cross_system": false,
  "confidence": null,
  "attributes": null
}
```

Edges are carried from the substrate edge set with an **idset filter** (drop any edge whose `source` or
`target` is not a present node — the same defensive pass as `code-emitter/transform.jq` step 4). A
cross-SYSTEM edge is the headline visual differentiator (design §3) — the viewer draws it as a cross-layer
connection.

### Phase 2 — the derived cross-system fields

- **`cross_system`** (boolean): `true` when the edge carries a `confidence` attribute (the data contract
  writes `{derivation, confidence}` ONLY on cross-system edges) **OR** its endpoints sit in different layers
  **OR** either endpoint is an `external_endpoint`. The third test is load-bearing: an external→external
  edge has both endpoints in `layer:external`, so the layer-diff test alone would miss it (and a
  confidence-less such edge would slip through the first test too) — the kind test closes that hole. A
  confidence-less cross-system edge then becomes a `blind-spot` via the fail-safe below, never a silent
  within-system downgrade.
- **`confidence`** (`declared-high | declared-medium | blind-spot | null`): carried from
  `edge.attributes.confidence`; `null` on within-system edges. **KEYSTONE FAIL-SAFE**: a cross-system edge
  whose confidence is unknown (attributes `null`/missing) is forced to `"blind-spot"` — unknown confidence
  fails TOWARD the amber marker, never toward a confident green line.
- **`attributes`** (`{derivation, confidence} | null`): the substrate edge attributes, carried verbatim on
  cross-system edges; `null` (never `{}`) on within-system edges.

The viewer styles within-system edges faint grey (unchanged); cross-system edges coloured by `type` with an
arrowhead, solidity by `confidence` (declared-high solid · declared-medium dashed+dimmer · blind-spot amber+
dashed). Blind-spot edges render LAST (on top) so amber is never hidden behind a parallel solid edge.

## Layer

```json
{ "id": "<layer id>", "name": "<human name>", "category": "<data|automation|code|config>", "nodeIds": ["<node_id>", ...] }
```

Layers are **derived** by grouping nodes by `category` (the design §2.1 container model), plus one
per-`workflow` group (a workflow + its `workflow_node` children form their own layer). The default v1 layer
set:

| layer id | name | members |
|---|---|---|
| `layer:data` | Database | all `data`-category nodes (table/view/function/trigger/rls_policy) |
| `layer:automation` | Automation & Deploy | `edge_function` + workflow groups |
| `layer:code` | Code | `ts_module` nodes |
| `layer:config` | Config | `config` nodes |
| `layer:external` | External APIs | `external_endpoint` nodes (Phase 2 — cross-system targets) |
| `layer:workflow:<id>` | `<workflow label>` | a workflow + its `workflow_node` children (a nested group) |

## What this contract is NOT

- **Not the substrate** — it is a derived rendering; the substrate JSON remains the single write surface.
- **Not the drift overlay** — drift/coverage colour state lives in the separate `drift-overlay.json`
  (`references/drift-overlay-shape.md`); this file is the structure-only graph. The two are merged at render
  time so the same `graph.json` can be shown with or without an overlay.
- **Not LLM-summarised** — unlike the competitor (Understand-Anything), nodes carry derived provenance
  (`source`), not an LLM `summary`. `summary` is intentionally absent.
