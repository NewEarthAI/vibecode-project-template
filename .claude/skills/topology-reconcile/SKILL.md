---
name: topology-reconcile
description: |
  The reconciliation comparator (M4, Doctrine 06) — the part of the Intent-Actual-Gap mechanism that
  surfaces where a system's true structure (the topology map) has drifted from a reference view, ranked
  by impact, with ONE named action attached to every drift. Composes the FROZEN topology substrate
  (read-topology + validate-schema) READ-ONLY; NEVER writes the topology, NEVER runs an emitter inside
  the comparator (the P2 boundary — Doctrine 06 §3.2/§6.3, Test D operational limb). v1 ships the two
  topology-internal invariant classes (versioning/structural + derivation) that need NO intent record;
  the conservation class (intent's wired_to vs topology) is DEFERRED until an intent-capture producer
  exists (never fabricated — the Element-4 test-fixture-only-pass failure). Produces the Doctrine 06 §6.1
  invariant record with a 7-value verdict taxonomy (in_sync / drift / inconclusive / unverifiable_spot /
  unverifiable_dimension / no-invariants-registered / pending_verification), a provenance-aware freshness
  precondition (incomparable git/live/dirty provenances → inconclusive, never a false drift/in_sync), the
  four-action selector (revert / reconcile / approve_as_intentional / escalate), and impact_rank via a
  depth-limited depended_on_by walk. Plain-English chat + a machine-readable --json mode.
  Use when: an operator (human or AI) asks "where has my system drifted from what I intended?";
  "/topology reconcile", "is my deployed config still aligned with the repo", "show me the drifts",
  "reconcile the topology", AND/OR an /autovibe session asks "are there open drifts on the area I'm
  about to touch?" before acting.
  Do NOT use for: WRITING the topology (the 4 emitters); computing coverage/freshness only (that is
  /topology health); the conservation class / intent-vs-topology drift (DEFERRED — no intent producer);
  AUTO-EXECUTING a revert/reconcile (v1 PROPOSES + confirm-gates only; auto-exec is v2); editing the
  substrate or the doctrines (all frozen).
allowed-tools: Bash, Read
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-06-02
last_verified: 2026-06-02
programme: intent-actual-gap-mechanism
programme_session: M4-reconciliation-proof
schema_authority: references/reconcile-shape.md
---

# Topology Reconcile — the drift comparator (Intent-Actual-Gap mechanism, part 3 of 3)

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M4 (the reconciliation proof). M3 built the
> topology (the `right_view`); M2 authored the three doctrines. This is Doctrine 06's mechanism — the
> comparator that turns two static views into a live drift signal with a named remediation action.
>
> **The schema + contract authority is** 📄 `references/reconcile-shape.md` (derived from Doctrine 06).
> This skill READS the substrate via the substrate skill's two frozen read helpers; it never writes the
> topology, never runs an emitter inside `compute()`. Pure read-only judgment on top of proven primitives.

## What this is

The topology map (`/topology status` / `/topology health`) shows what the system IS. Reconciliation answers
the next question: **"is the system still what it was supposed to be, and if not, what should be done?"** —
as a structured verdict, ranked by impact, with one named action per drift, re-derived from source on every
run. It is the comparator Doctrine 06 §2 calls "the load-bearing design commitment neither sibling makes".

## What it composes (FROZEN — never reimplements)

```bash
SUB=".claude/skills/topology-substrate/scripts/substrate.sh"
bash "$SUB" read-topology '<jq-filter>'   # the substrate, sliced. rc 4 = not-init'd; rc 6 = corrupt.
bash "$SUB" validate-schema               # PASS (rc 0) or a violation list (rc 6).
```

- ALL substrate data is read through `read-topology` — never a direct `jq` on the file (it self-validates
  before serving). The freshness precondition reuses the health-check's `date -u +%s` + `fromdateiso8601`
  jq pattern (NEVER GNU `date -d`).
- The `right_view` is POPULATED by the 4 frozen emitters. The Test B proof drives the frozen
  `n8n-cloud-emitter` as a SEPARATE populate step (OUTSIDE the comparator — the P2 boundary), then the
  comparator READS the populated substrate. `compute()` never calls an emitter.

## The framing decision (recorded — why v1 ships 2 of 3 classes)

The intent-capture *mechanism* does not exist (only Doctrine 04's doc). A `/reduce-to-first-principles`
audit (2026-06-02, SMUGGLES_CONCLUSIONS/HIGH) found reconciliation's `left_view` is duck-typed and **2 of
3 invariant classes (versioning/structural + derivation) need NO intent record** — their `left_view` is
topology-internal. v1 ships those two, proves Test B on the real repo-vs-cloud n8n drift, and **defers the
conservation class** (intent's `wired_to` vs topology) until a real intent producer exists — never
fabricating an intent view (the §8.4 vacuous-green-light / Element-4 test-fixture-only-pass failure). Full
record + the council resolution: 📄 `references/reconcile-shape.md` + `council/sessions/2026-06-02-m4-reconciliation-proof-plan.md`.

## How a run works

`bash scripts/reconcile.sh [--json] [--invariant <id>]`:
1. **Reads the substrate** (rc 4 → `UNINITIALISED`; rc 6 → `CORRUPT` — the health-check mapping).
2. **Loads the registered invariants** (`references/invariants/*.json` — the §6.1 records). v1 registers
   ≥1 versioning + ≥1 derivation (the §6.8 liveness minimum) + an unverifiable-dimension demonstrator.
3. **For each invariant, `compute()`** — the §11 ordered decision-list as ONE jq expression returning a
   `{verdict, named_action}` discriminated union (`named_action != null IFF verdict == drift`, structurally
   guaranteed). The provenance-aware freshness precondition (§6.7) runs first: a structural assertion
   (same workflow by `n8n_id` ⇒ same node_count) fires `drift` regardless of commit-time comparability,
   while the commit-time versioning sub-assertion returns `inconclusive: incomparable-provenance` when the
   two sides' provenances aren't git-comparable (`live:` / `+dirty`).
4. **`impact_rank`** — a depth-limited (cycle-safe) `depended_on_by` walk; `rank_completeness: partial`
   whenever a dimension is declared-missing (the current substrate IS partial — never authoritative).
5. **Emits** the verdict records + a compound honest summary (plain-English + `--json`). v1 PROPOSES
   mutating actions (`revert`/`reconcile`) — it never auto-executes (the confirm-gate + persistent audit
   trail are v2). `action_outcome` is always `[]` in v1.

## The verdict taxonomy + the honest summary

Per-invariant verdicts: `in_sync` / `drift` / `inconclusive` (reasons: `incomparable-provenance`,
`stale-input-transient`, `stale-input-broken`, `right-view-absent`, `left-view-pending`) /
`unverifiable_spot` / `unverifiable_dimension` / `no-invariants-registered` / `pending_verification`.

The top-line summary is COMPOUND + honest (the §8.4 vacuous-green-light defence): `IN_SYNC` is reported
ONLY when EVERY invariant is in_sync; any `drift` dominates; otherwise `PARTIAL` / `INCONCLUSIVE` /
`UNVERIFIABLE` surface the mixed state — never hidden behind a single in_sync.

## Read-only invariants (verified by the eval + the live proof)

- NEVER writes the substrate (no `write-node`/`bulk-write`/`mark-emitter-ran`/`init`). The substrate is
  byte-untouched after a run (eval + live-proof asserted).
- NEVER runs an emitter inside `compute()` (the P2 boundary). The Test B populate step is SEPARATE.
- NEVER authors an intent record (the P2 boundary — §3.1).
- NEVER returns `drift` on incomparable/stale provenance or `in_sync` over an uncompared view (§6.7/§8.4).

## Exit codes

| rc | meaning |
|----|---------|
| 0 | the reconcile ran. The summary may be ANY value — IN_SYNC / DRIFT / PARTIAL / INCONCLUSIVE / UNVERIFIABLE / **CORRUPT** / **UNINITIALISED**. A corrupt/absent substrate is a successful *report*, not a script failure. |
| 2 | usage error (unknown argument) |
| 6 | genuine script-execution failure — `jq` not found, the substrate helper absent. NOT "substrate corrupt" (that is the `CORRUPT` summary at rc 0). |

## The deferred-but-required note (Doctrine 06 A6 — for the conservation-class implementer)

The v1 freshness precondition is node/record-level. The conservation class (when its intent producer
exists) requires FIELD-level scoping (a wording-only intent edit touching no `wired_to`/`conditions` field
must not gate every invariant). The conservation-class implementer MUST extend the precondition with a
per-field change-commit map — do NOT silently inherit this v1 partial guard. (Doctrine 06 §6.7 / A6.)

## Verification record

- **Live Test B proof (2026-06-02)** — DESTINATION Test B (a deliberate drift detected + ranked +
  action-attached, re-derived from real sources): on a scratch substrate seeded with the live my-project
  repo workflow nodes + the cloud node re-derived via the FROZEN `n8n-cloud-emitter` against the live
  <your-instance> workflow `Gz8EKN9CWxIDcGXcoCmYq`. **Baseline** (faithful published graph, 33 cloud == 33 repo)
  → `in_sync` (the negative control — no false drift). **Drift introduced** (a deliberate cloud-side node
  added without a repo change — Test B example b) → `drift`, node_count repo=33 vs cloud=34, ranked
  (`impact_rank 1, partial`), action `reconcile` (per-class authority: repo authoritative for the deployed
  config), commit-time sub-verdict honestly `inconclusive: incomparable-provenance (dirty vs live)`. The
  live my-project substrate was byte-untouched throughout (read-only honoured).
- Eval: `evals/canonical-shape.sh` (exact-verdict fixture eval — every verdict-taxonomy path + the
  council-added cases: incomparable-provenance, null-join, ambiguous-join, State B covered-but-absent,
  multi-invariant single-pass, cyclic depended_on_by, derivation drift, the discriminated-union invariant,
  the read-only/byte-untouched assert, oscillation-never-fires-in-v1).
- Integration: `evals/integration.sh` (the Test B proof harness — drives the frozen emitter, asserts
  baseline `in_sync` → injected `drift` re-derived from the substrate, isolation byte-untouched, LIVE_RAN
  honesty flag).
- Council: `council/sessions/2026-06-02-m4-reconciliation-proof-plan.md` (8 agents; C1-C5 + S1-S6; T1/T2
  operator decisions). Code-council: `council/code-reviews/2026-06-02-m4-reconciliation.md`.
