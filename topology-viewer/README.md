# Topology Drift Map — local viewer (visual layer, Wave 1)

The "visible in the repo locally" floor for the Intent-Actual-Gap mechanism's visual layer. It renders two
render-target-agnostic JSON files — a structure graph (`public/graph.json`) and a 5-state drift overlay
(`public/drift-overlay.json`) — as a drift-first interactive map.

## Run it

From the workshop root, one command produces the two JSONs and launches the viewer:

```bash
bash .claude/skills/topology-visual-emitter/scripts/build-local.sh
# or, via the command:  /topology visual
```

That reads the live substrate + reconcile verdicts (falling back to the bundled golden fixtures if none
exist), writes `public/graph.json` + `public/drift-overlay.json`, then runs the viewer dev server.

To run the viewer directly against whatever is already in `public/`:

```bash
cd topology-viewer && npm install && npm run dev
```

A committed sample (the golden fixture) ships in `public/`, so the viewer renders out of the box.

## What you see

- **Red** = drift (diverged from intent — act). **Orange** = blast-radius (downstream of a drift).
  **Amber** = blind spot (a dimension we can't see — *not* a clean bill of health). **Grey** = unverifiable
  (we looked but can't judge). **Faded** = in sync.
- Default view is **drift-first** — the small actionable subset + 1-hop context. Toggle **"Show all nodes"**
  for the full graph (the opt-in completeness path).
- The side panel ranks drifts by impact and shows the one named next-move + the source provenance per drift.
- The headline verdict is carried **verbatim** from `reconcile` — the map can never be greener than the
  verdict it renders.

## What it is NOT

Read-only. Nothing here mutates the topology — the substrate is the single source of truth (Doctrine 05 P5).
The drift action is *displayed*, never executed (reconcile v1 proposes only). This viewer is Wave 1; a
deployed surface (Agency OS, or a future Hermes dashboard) is Wave 2, gated behind the M5 sustain — and it
consumes the **same** two JSONs with no rework.

## Contracts

- `public/graph.json` → `.claude/skills/topology-visual-emitter/references/graph-shape.md`
- `public/drift-overlay.json` → `.claude/skills/topology-visual-emitter/references/drift-overlay-shape.md`
