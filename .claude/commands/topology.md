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
