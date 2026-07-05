---
description: Plain-English view of the Master Blueprint topology substrate — what the graph covers, how fresh each emitter is, what's not yet built, and where it has drifted from intent (reconcile)
---

# /topology

Operator surface for the topology substrate (the canonical system-structure graph). Read-only by default.
The substrate skill's helpers are at `.claude/skills/topology-substrate/scripts/substrate.sh`; the schema
authority is `.claude/skills/topology-substrate/references/canonical-shape.md`.

## Subcommands

### `topology status` (default)

```bash
bash .claude/skills/topology-substrate/scripts/substrate.sh read-topology
```

Then relay to the operator **in layman voice**: which emitters have run and how stale each is (from
`emitters.<name>.last_emitted_at` vs now), the overall `last_updated`, the node/edge counts, and the
declared-missing emitters (the 5 not-yet-built layers). If the substrate does not exist yet (exit 4), say so
plainly and offer to run `init <entity>`.

### `topology health`

```bash
bash .claude/skills/topology-health-check/scripts/health-check.sh
```

The opinionated verdict layer (the topology-health-check skill, M3 Session 6). Where `status` relays the raw
substrate, `health` gives a judgment: a single freshness verdict (FRESH / STALE / PARTIAL / STALE_AND_PARTIAL /
ANOMALOUS / CORRUPT / UNINITIALISED), per-emitter coverage (the 4-way enum) + staleness vs configurable
thresholds, per-kind node counts, anomaly flags (covered-but-empty, future-dated, unparseable timestamp), and
the integrity verdict. Read-only — composes `read-topology` + `validate-schema`, never writes. Add `--json` for
machine-readable output (used by `/setup` wiring + the integration test). Relay the plain-English report
verbatim to the operator; it is already in layman voice. This is the "is my topology healthy?" front door for
both a fresh `/setup` and a drop-in on an established codebase.

### `topology reconcile`

```bash
bash .claude/skills/topology-reconcile/scripts/reconcile.sh
```

The drift comparator (the topology-reconcile skill, M4 — Doctrine 06). Where `health` reports coverage +
freshness, `reconcile` answers the next question: **"where has the system drifted from what it was supposed
to be, and what should be done?"** It compares two source-derived views that should agree (e.g. an in-repo
n8n workflow vs its live cloud twin, joined by `n8n_id`) and emits, per registered invariant: a verdict
(in_sync / drift / inconclusive / unverifiable_dimension / unverifiable_spot / no-invariants-registered),
ranked by impact, with ONE named action on every drift (revert / reconcile / approve_as_intentional /
escalate). Read-only — composes `read-topology` + `validate-schema`, never writes the topology, never runs
an emitter inside the comparator (the P2 boundary). v1 ships the two topology-internal invariant classes
(versioning/structural + derivation); the conservation class (intent's `wired_to` vs topology) is DEFERRED
until an intent-capture producer exists. v1 PROPOSES mutating actions (never auto-executes — the confirm-gate
+ audit trail are v2). Add `--json` for machine-readable output (the `/autovibe` drift-check surface) or
`--invariant <id>` to run one invariant. Relay the plain-English report verbatim to the operator. Honest
about `inconclusive` (e.g. `incomparable-provenance` when the two sides' commit-times can't be aligned) — it
never fakes a drift or a green-light over inputs it cannot actually compare.

### `topology align`

```bash
bash .claude/skills/system-awareness-gate/scripts/topology-align.sh
```

The **plan-level alignment read** (the System-Awareness Alignment Gate's deep read — the symmetric twin of the
framing-audit gate). Where `reconcile` answers "where has the LIVE system drifted from the saved map?", `align`
answers the OTHER question: **"does the plan I am about to build fit what the system actually IS, where it is
headed, and what was committed?"** It composes the four anchors at plan-time — `health` (map freshness) +
`reconcile` (open drift, ESTABLISHED only) + `ROADMAP.md` NOW + `DESTINATION.md` + the active goal ledger — and
applies an **honest-degradation matrix (R0–R7)**: only a FRESH map + IN_SYNC reconcile ever licenses the word
"aligned"; absence / corruption / anomaly / staleness / partiality / drift are each surfaced honestly, NEVER
laundered into a green light. Dual-mode: an ESTABLISHED repo gets the full alignment read; a FROM-SCRATCH repo
(no substrate) gets an honest "NO system map yet — checked against written intent only" + a build-the-map offer.
Read-only — composes the existing read helpers, never writes the substrate, never runs an emitter, never executes
a drift action. Add `--json` for the machine-readable verdict object (`alignment_verdict` + `licensed_aligned` +
coverage facts). **Claude auto-runs this on plan-class work (the operator types nothing); it is invoked by the
`.claude/hooks/system-awareness-activation.sh` directive or on plan-mode entry.** Doctrine:
`.claude/rules/system-awareness-mandate.md`. Relay the plain-English report verbatim to the operator.

### `topology visual [<entity-label>]`

```bash
bash .claude/skills/topology-visual-emitter/scripts/build-local.sh '<optional entity label>'
```

The **drift map** (the topology-visual-emitter skill, the visual layer Wave 1). Where `reconcile` answers
"where has the system drifted?" as text, `visual` answers it **as a map** — drift lit up ON the topology,
drift-first, with one named next-move per drift. It reads the FROZEN substrate (`read-topology`) + the drift
verdicts (`reconcile --json`), runs two jq transforms into two render-target-agnostic JSON files
(`graph.json` + `drift-overlay.json`), drops them into the local viewer (`topology-viewer/`), and launches it.
Read-only — composes the two frozen read helpers, never writes the substrate, never executes a drift action.
Colour legend: red = drift, orange = blast-radius (downstream), amber = blind-spot (uncovered/unreadable
dimension — NOT a clean bill of health), grey = unverifiable, faded = in-sync. The default view is drift-first
(the small actionable subset + 1-hop context); a "Show all nodes" toggle reveals the full graph. The two
JSONs are the value — the SAME files feed any future surface (a deployed Agency-OS page, a future Hermes
dashboard) with no rework; that deployed surface is Wave 2, gated behind the M5 30-day sustain. If no live
substrate/reconcile exists, the build falls back to the golden fixtures so the viewer always renders. Pass
`--no-serve` to write the JSONs without launching the viewer.

### `topology validate`

```bash
bash .claude/skills/topology-substrate/scripts/substrate.sh validate-schema
```

Relay `PASS` or the violation list verbatim. A non-PASS means the substrate is corrupt or hand-edited — surface
it as the most important thing on screen.

### `topology read [jq-filter]`

```bash
bash .claude/skills/topology-substrate/scripts/substrate.sh read-topology '<optional jq filter>'
```

Print the substrate (optionally sliced by a jq filter, e.g. `.nodes[] | select(.kind=="rls_policy")`).

### `topology init <entity>` (the one mutating subcommand)

```bash
bash .claude/skills/topology-substrate/scripts/substrate.sh init '<entity>'
```

Creates the empty substrate (idempotent) seeded with the 3 emitters at `declared-missing` and the 5
`missing_emitters` markers. Only run when the operator explicitly asks to initialise.

## Notes

- Read-only except `init`. The substrate is written by emitters (M3 Sessions 2-5) via the Skill tool, not by
  this command. `health` + `reconcile` are read-only judgment layers over the substrate — neither writes it.
- Substrate path: `${TOPOLOGY_SUBSTRATE_PATH:-<repo>/.understand-anything/topology-graph.json}` — per-repo,
  gitignored.
- At M3-v1 all three emitters read `declared-missing` until the emitter sessions populate them — that is the
  honest, correct answer, not a failure.
