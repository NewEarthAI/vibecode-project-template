---
name: topology-visual-emitter
description: |
  The visual layer for the Intent-Actual-Gap mechanism (downstream application #1, Wave 1). Turns the
  FROZEN topology substrate + the reconcile drift verdicts into two render-target-agnostic JSON files — a
  structure graph (graph.json) and a 5-state drift overlay (drift-overlay.json) — and renders them in a
  local in-repo interactive viewer where intent-vs-actual drift lights up ON the map (red drift / orange
  blast-radius / amber blind-spot / grey unverifiable / faded in-sync), drift-first, with a ranked
  next-move side panel. READ-ONLY over the substrate + reconcile (composes their frozen read helpers; never
  writes either, never executes a drift action — Doctrine 05 P5 / Doctrine 06 v1-proposes-only). The two
  JSONs are the value; any future surface (a local viewer now, an Agency-OS page later, a future Hermes
  dashboard) renders the SAME two files with no rework.
  Use when: "show me the drift map", "/topology visual <entity>", "render the topology", "where is my
  system drifting, visually". Do NOT use for: WRITING the topology (the 4 emitters); computing drift (that
  is /topology reconcile); deploying to a portal (Wave 2, gated behind the M5 sustain).
allowed-tools: Bash, Read
user-invocable: true
version: 1.1
classification: capability-uplift
created: 2026-06-04
programme: intent-actual-gap-mechanism
programme_milestone: visual-layer-wave-1
schema_authority: references/graph-shape.md + references/drift-overlay-shape.md
---

# Topology Visual Emitter — the drift map (Intent-Actual-Gap mechanism, downstream application #1)

> **Design**: 📄 `specs/16_VISUAL_LAYER_DESIGN.md` (framing audit ran — drift-first, progressive disclosure,
> NOT "render everything to beat the competitor"). **Build plan**: the approved Wave-1 plan
> (`~/.claude/plans/sounds-great-proceed-with-replicated-globe.md`). The reconcile drift comparator
> (`/topology reconcile`) and the topology substrate are FROZEN; this skill only READS them.

## What this is

`/topology reconcile` answers "where has my system drifted?" as text. This skill answers it **as a map** —
drift lit up on the topology, drift-first, with one named next-move per drift. It is the literal "visible"
surface of the mechanism's `DESTINATION.md` contract (keep intended-vs-actual behaviour cheaply *visible*).

## The two outputs (render-target-agnostic — the value)

| File | Producer | Contract | Content |
|------|----------|----------|---------|
| `graph.json` | `scripts/graph-transform.jq` | `references/graph-shape.md` | structure: nodes + edges + layers, render-kind + category derived |
| `drift-overlay.json` | `scripts/drift-overlay-transform.jq` | `references/drift-overlay-shape.md` | state: the 5 drift node-sets + per-node actions, `summary` verbatim from reconcile |

Any surface renders these two unchanged. The local viewer (`topology-viewer/`) is Wave 1; an Agency-OS page
or a future Hermes surface is Wave 2 (gated behind the M5 sustain).

## What it composes (FROZEN — never reimplements)

```bash
SUB=".claude/skills/topology-substrate/scripts/substrate.sh"
REC=".claude/skills/topology-reconcile/scripts/reconcile.sh"
bash "$SUB" read-topology '.'   # the substrate, READ-ONLY (rc 4 = not init'd; rc 6 = corrupt)
bash "$REC" --json              # the drift verdicts, READ-ONLY (the --json envelope)
```

The two jq transforms turn those two outputs into the two render JSONs. `scripts/build-local.sh` runs the
whole pipeline and opens the local viewer.

## How a run works (`/topology visual <entity>`)

1. **Read** the substrate (`read-topology '.'`) and the drift verdicts (`reconcile --json`).
2. **Transform** → `graph.json` (`graph-transform.jq`) + `drift-overlay.json` (`drift-overlay-transform.jq`),
   written next to the substrate (default `.understand-anything/`).
3. **Render** → the local viewer reads the two JSONs and draws the drift-first map (`build-local.sh` →
   `npm run dev` or a built static bundle).

## Phase 2 — the cross-system render layer (v1.1, 2026-06-06)

The headline differentiator: **cross-system dependency edges** — wiring that crosses a system boundary
(frontend `ts_module` → Supabase `table`/`edge_function`; n8n `workflow_node` → Supabase REST / external
API; edge function → external API). These are produced by the data layer (`code-emitter` 1a +
`external-api-graph-emitter` 1b) and written into the substrate as edges carrying
`attributes: {derivation, confidence}` + `external_endpoint` nodes. This skill RENDERS them:

- `graph-transform.jq` derives per render edge: `cross_system` (confidence-present OR cross-layer) +
  `confidence` + carried `attributes`, plus `has_blind_spot_edges` on the envelope. **Keystone fail-safe**:
  a cross-system edge with unknown confidence is forced to `blind-spot` (amber) — never a confident green
  line (council 2026-06-06 A2).
- The viewer renders cross-system edges coloured by `type` (reads_from/writes_to/invokes/calls), solidity
  by `confidence`; **blind-spot edges + nodes render amber + dashed + badged, at full opacity, always
  shown** (a blind-spot is never silently dropped or faded — council A3/A4). A **"cross-system edges only"**
  filter isolates the architectural map; a persistent **"cross-system coverage is partial" chip** is read
  live from coverage state + the blind-spot signal (never hardcoded — council A1).
- **R5 (this wave)**: cross-system edges RENDER but do NOT participate in the drift blast walk — the blast
  walk reads `blastRadiusNodeIds` from reconcile, which never contains `external_endpoint` nodes.

## Read-only / honesty invariants

- NEVER writes the substrate or runs an emitter (the P2 boundary). NEVER executes a drift action (v1
  proposes only). NEVER makes the map greener than reconcile's verdict (`summary` carried verbatim —
  the §8.4 vacuous-green-light defence).
- A blind-spot (uncovered/unreadable dimension, OR an unresolved cross-system target) renders amber, never
  green, never dropped (Doctrine 05 P6 + the cross-system honesty boundary 1).
- "What depends on X?" stays answerable from `graph.json` without rendering (Doctrine 05 P5 — the diagram
  is a view, the substrate is the truth).

## Verification

- `evals/graph-shape.sh` — `graph-transform.jq` over the golden fixture (`evals/fixtures/substrate.json`).
- `evals/drift-overlay-shape.sh` — `drift-overlay-transform.jq` over the golden fixtures: all 5 states +
  the precedence rule + the verbatim-summary guard + the negative vacuous-green test
  (`evals/fixtures/reconcile-partial.json`).
- `evals/cross-system-render.sh` (Phase 2) — both transforms over the cross-system fixture pair
  (`evals/fixtures/substrate-cross-system.json` + `reconcile-cross-system.json`): every classification +
  confidence + edge type, the A2 keystone (unknown confidence → blind-spot), within-system attributes null
  (not `{}`), external→external cross-system, unknown-type survival, R5 (no external id in any blast/drift
  set), R8 (fixture byte-untouched). 38 assertions.
- Render smoke: `TOPO_FIXTURE=cross-system bash scripts/build-local.sh demo --no-serve` writes the
  cross-system demo render into the viewer and prints the cross-system edge count.

## Scope (Wave 1 only)

Wave 1 = the two transforms + the local in-repo viewer (this skill). Wave 2 (the deployed Agency-OS /
Hermes surface + the per-entity Supabase publish path) is GATED behind the M5 30-day sustain and decided
when the deploy target settles — see the approved plan.
