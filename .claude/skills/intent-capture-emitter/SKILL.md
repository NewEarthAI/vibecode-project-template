---
name: intent-capture-emitter
description: |
  The intent-capture mechanism (M6, Doctrine 04) — part 1 of the Intent-Actual-Gap system, the producer
  of the contracted `left_view` reconciliation consumes. It records what a system was SUPPOSED to do —
  machine-addressably, authored-not-derived — so reconciliation's conservation class can answer "is this
  promise still kept?". Indexes intent CARRIERS (a DESTINATION.md, an ADR, a roadmap item) into a
  queryable intent ledger of 14-field Doctrine 04 §6.1 records; resolves a topic to its live (supersession-
  walked) terminal via a 3-op read API (get / read / slice); and ships four day-one guards: NSF-1
  (intent-staleness watchdog — an overdue acceptance_cadence is surfaced, not left to rot), NSF-2
  (falsifier-format validator — rejects a prose "could-this-lie?" note, demands a machine-executable
  check), NSF-3 (wired_to referential-integrity + an emitter-id-format-change batch heuristic), and the
  computed layer (per-field change-commit map in a SEPARATE intent-computed.json — the P2 boundary made
  structural). NEVER guesses a wired_to link from prose (D2). NEVER fabricates an intent view (the
  Element-4 test-fixture-only-pass failure). Plain-English + machine-readable --json.
  Use when: authoring/indexing intent for a project; an operator (human or AI) asks "what was this
  supposed to do?", "is this promise still wired up?", "is this intent stale?"; or reconciliation needs
  the `left_view` (wired_to + conditions) for a conservation check.
  Do NOT use for: WRITING the topology (the 4 topology emitters); the drift comparison itself (that is
  topology-reconcile); auto-repointing a broken wired_to (BANNED — P1; the operator supersedes); editing
  the doctrines or the frozen substrate.
allowed-tools: Bash, Read
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-06-08
last_verified: 2026-06-08
programme: intent-actual-gap-mechanism
programme_session: M6-intent-capture
schema_authority: docs/operational-doctrine/04_intent-capture.md  (§6.1, the 14-field record)
---

# Intent-Capture Emitter — the promise recorder (Intent-Actual-Gap mechanism, part 1 of 3)

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M6 (intent-capture). M3 built the topology
> (what the system IS). M4 built reconciliation (where parts drifted — versioning + derivation classes).
> This is Doctrine 04's mechanism: what the system was SUPPOSED to do. Its output is the `left_view`
> reconciliation's deferred **conservation class** consumes to answer "is this promise still kept?".

## What this is

A producer + a queryable store. It reads an intent **carrier** (a markdown artefact a human authored:
a `DESTINATION.md`, an ADR, a roadmap item) and indexes it into the intent ledger as a 14-field
Doctrine 04 §6.1 record. The record is the machine-addressable form of an authored promise; the carrier
stays the durable, git-committed source of truth.

Authored-not-derived (Doctrine 04 P1) is the spine: the emitter parses what the carrier states and NEVER
invents the load-bearing fields. In particular it NEVER guesses a `wired_to` link from prose (D2) — an
un-wired intent is marked `wired_to: pending`, never a name-match guess (a guess fabricates a `left_view`,
which is the failure this whole mechanism exists to prevent).

## The command surface (`scripts/`)

| Script | What it does |
|--------|--------------|
| `emit.sh <kind> <carrier> [entity]` | Index ONE carrier: extract → transform → store bulk-write → mark-emitter-ran → validate. `<kind>` ∈ destination / adr / roadmap_item. Git **commit-time** provenance (a dirty carrier is stamped `+dirty` so freshness can return `inconclusive`, never a false in_sync). |
| `intent-store.sh <cmd>` | The ledger engine (atomic mkdir-lock, jq-only). `init` / `bulk-write` (upsert-by-id, D8 — never auto-marks supersession) / `mark-emitter-ran` / `read-intent` / **`get <topic>`** (supersession-walked terminal) / **`read <id>`** / **`slice <topic> <fields>`** / `validate-schema`. |
| `nsf1-staleness-gate.sh [--json]` | **NSF-1** — per-record acceptance-cadence watchdog. An `accepted` promise overdue for re-confirmation → `stale_intent` (exit 1, LOUD + BINDING in the sustain loop). Each overdue record listed; absence of a cadence uses the 90-day default; a present-but-unintelligible cadence is an anomaly, never laundered. |
| `nsf2-falsifier-validate.sh '<rec>' \| --all` | **NSF-2** — the falsifier-format validator. Enforces Doctrine 04 §6.1.1: form (reject prose, require a parsing machine-executable check), referential (a `type:script` path must resolve), complementarity (the falsifier must differ from `binary_test`, not be its bare negation). The direct guard against the vacuous-green-light. |
| `nsf3-wired-integrity.sh [--json]` | **NSF-3** — wired_to referential-integrity sieve + the emitter-id-format-change batch heuristic (≥5 same-(emitter,kind) failures in one run → `possible_emitter_id_format_change`). Coverage-honest: FULL map → confident `wired_to_target_absent`; PARTIAL map → `wired_to_target_unverifiable` (never a false drift on an uncovered emitter). |
| `intent-computed.sh [--json]` | The **computed layer** generator — the per-field change-commit map, written to a SEPARATE `intent-computed.json` keyed by record id (the P2 boundary is structural). Single-pass over each carrier's git history; committed-state-only (a dirty carrier → `inconclusive: uncommitted-changes`). Reconcile reads this for FIELD-LEVEL freshness. |
| `extract.mjs` / `transform.jq` | Internal pipeline pieces (carrier → raw → the §6.1 record). Not invoked directly; `emit.sh` composes them. |

## The 14-field record + the read API

The record schema is **owned by Doctrine 04 §6.1** (5-field provenance envelope + 9 payload fields) —
this skill never redefines it. The three-resolution read API (Doctrine 04 §6.8) keeps an AI session's
context bounded: `get` returns the supersession-walked terminal for a topic; `read` returns the whole
terminal record; `slice` returns just the named fields (e.g. `slice billing "wired_to,conditions"` — the
exact join inputs reconciliation needs, nothing more).

## ★ The `wired_to` rename-supersession protocol (Gate 1 — council A14)

This is the one behaviour an operator MUST understand, because reconcile's action vocabulary cannot
express it and getting it wrong fabricates intent.

**What `wired_to` stores**: the **exact canonical node-id string** the topology emitter produces for the
implementation artefact (e.g. `public.deals`, an `rls_policy` node id, an edge-function name). It is
**stable across topology re-runs** (a re-emit produces the same id) and **deliberately changes across a
rename** (a renamed entity *is* a new identity).

**The rename case** (the one reconcile cannot auto-resolve):

1. A rename re-creates the same promise under a NEW id. The OLD id named in `wired_to` is genuinely gone.
2. Reconcile's conservation invariant re-resolves `wired_to` against the LIVE substrate on every run (no
   cached resolution). The old id → absent → verdict `drift`, `named_action: escalate`,
   `reason: wired_to_target_absent`.
3. **M6 does NOT auto-repoint `wired_to`.** Auto-repointing would assert a fulfilment claim the author
   never made — a P1 violation (fabricated intent). **Auto-repoint is OUT of v1, permanently, by design.**
4. **No rename-candidate guessing** (G1 / D2): M6 never offers a "similar-named node" as the new target.
   A name-match guess is exactly the fabricated-`left_view` the mechanism exists to prevent.
5. The operator investigates the `escalate`. If the rename was deliberate, they resolve it via Doctrine
   04's **supersession**: author a SUCCESSOR intent record carrying the NEW `wired_to` id, and mark the
   old record `superseded_by` the successor. The supersession walk then returns the new record as the
   live terminal; reconcile resolves the new id; the promise is kept under its new identity.

**What prevents silent rot**: the live re-resolution every run + **NSF-3 firing after every topology
emit**. A target that quietly disappears surfaces as a referential failure within one cycle, not months
later.

## ★ Finding the canonical node-id string to author into `wired_to` (council A14)

Never type a node id from memory or approximate it — copy the EXACT string the topology emitter produced:

```bash
# list candidate node ids from the topology substrate (READ-ONLY), filtered to your artefact:
bash .claude/skills/topology-substrate/scripts/substrate.sh read-topology \
  '[ .nodes[] | select(.kind == "rls_policy") | .id ]'
# or search by a substring of the artefact name:
bash .claude/skills/topology-substrate/scripts/substrate.sh read-topology \
  '[ .nodes[] | select(.id | test("deals")) | {id, kind} ]'
```

Author the returned id string **verbatim** into the carrier's `wired_to`. If no node matches, the
implementation does not exist yet in the map → mark `wired_to: pending` (run the relevant topology
emitter first, or the promise is aspirational). Verify the authored record with NSF-3 before relying on it.

## Constraints (carried)

- **READ-ONLY** over the frozen topology substrate, reconcile's proven paths, and the 4 topology emitters.
  M6 writes ONLY the intent ledger + `intent-computed.json`.
- **NEVER fabricate an intent view** (the Element-4 test-fixture-only-pass failure). A prose Element-4
  candidate is surfaced under `.diagnostics`, NEVER auto-promoted into the `falsifier` field.
- **NEVER name-match-guess `wired_to`** (D2). Un-wired → `pending`.
- **The P2 boundary is structural**: derived values (the per-field change map, "% resolved") live ONLY in
  `intent-computed.json` (emitter-stamped), NEVER inside an authored §6.1 record.
- The ledger lives under the gitignored `.understand-anything/` — it is a regenerable INDEX; the CARRIER
  is the committed source of truth (re-emit rebuilds the ledger).

## Composition with the other two mechanisms

| Mechanism | How it composes |
|-----------|-----------------|
| topology (M3, Doctrine 05) | Supplies the node-id space `wired_to` resolves against (the `right_view`). NSF-3 + the computed layer read it READ-ONLY. |
| reconcile (M4, Doctrine 06) | The consumer. Its **conservation class** takes this skill's `wired_to` + `conditions` as the `left_view` (`left_source: intent`), resolves them against topology, and emits the drift verdict + named action. **The conservation branch in reconcile is M6 phase S3a — BUILT 2026-06-08 (`compute_conservation()` in `reconcile.sh`; dedicated /code-council PASS; 33-assertion unit eval + the M4 48-assertion regression green). The live your project proof (S3b) remains (see below).** |

## What is built vs the your project-gated tail

This skill (the emitter + store + guards + computed layer) is complete and eval-proven, and **S3a is now
BUILT** (2026-06-08). Two phases remain, each requiring live your project access — the operator go-ahead point:

- **S3a (DONE 2026-06-08)** — the **conservation `kind` branch** in `topology-reconcile/scripts/reconcile.sh`
  (additive-only; `left_source: intent`; emitter-level NO_MAP routing; field-level freshness). Dedicated
  /code-council → BLOCKING → PASS (a silent versioning-comparator fallthrough class found, remediated
  defence-in-depth, and eval-locked); 33-assertion unit eval + the M4 48-assertion regression GREEN.
  Review: `council/code-reviews/2026-06-08-m6-s3a-reconcile-conservation.md`.
- **S1** (your project-gated) — author ONE real intent carrier on your project via `define-destination` (a structurally-
  verifiable `rls_policy` promise, a machine-executable falsifier, a `wired_to` at a real node id).
- **S3b** (your project-gated) — the live proof (the real-decision / Test B): emit topology → index the carrier →
  re-emit → reconcile `in_sync` → inject drift (intent-store-only re-point) → `drift` ranked + named action.

## Verification record

- Eval suite: `evals/run-all.sh` — **112 assertions across 6 suites, ALL GREEN** (intent-store
  supersession 19, parsers 22, NSF-1 17, NSF-2 13, NSF-3 27, computed-layer 14).
- End-to-end proven on the real workshop `DESTINATION.md` (record `intent:destination:destination-md`,
  status `accepted`, `wired_to: pending`, validates PASS).
- Plan: `specs/18_M6_INTENT_CAPTURE_BUILD_PLAN.md` (v3). Council: `council/sessions/2026-06-07-m6-intent-capture-plan-v2-execution-soundness.md`. Doctrine: `docs/operational-doctrine/04_intent-capture.md`.
