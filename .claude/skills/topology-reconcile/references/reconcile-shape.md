# Topology Reconcile — Schema & Contract Authority (M4)

> **Authority**: this file is derived from `docs/operational-doctrine/06_conservation-law-verification.md`
> §6.1 (the invariant record), §6.2-6.3 (the duck-typed views + typed `compute()`), §6.4 (the invariant
> classes), §6.5 + §11 (the action selector + ordered decision-list), §6.6 (the action gate + audit),
> §6.7 (the freshness precondition), §6.8 (the liveness gate), Appendix C (the invariant catalogue).
> It is the M4-v1 contract the comparator (`scripts/reconcile.sh`) implements and the evals assert against.
>
> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M4 (reconciliation proof). Spec
> `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`. Build plan `specs/14_*`. Contract
> `.claude/rules/intent-actual-gap-mechanism-alignment.md`. Council `council/sessions/2026-06-02-m4-reconciliation-proof-plan.md`.

---

## LOAD-BEARING FRAMING (recorded for audit) — why M4 ships versioning + derivation, defers conservation

The intent-capture *mechanism* (Doctrine 04's producer) does NOT exist — only the doctrine doc. A
`/reduce-to-first-principles` audit (2026-06-02) returned **SMUGGLES_CONCLUSIONS / HIGH**: "what intent
layer does M4 need?" presupposes reconciliation's missing input is an intent layer. Doctrine 06 §6.2
(duck-typed `left_view`) + Appendix C show **2 of 3 invariant classes need NO intent record** — their
`left_view` is topology-internal:

| Class | `left_view` | `right_view` | Needs intent record? |
|-------|-------------|--------------|----------------------|
| **Structural / conservation-of-derivation** (the M4 headline) | one source-derived view of an object (a `repo:` workflow node) | another source-derived view of the SAME object (the `cloud:` node, joined by `n8n_id`) | **NO** (both topology-side) |
| **Derivation** | the node/edge set | the live-derived topology | **NO** (both topology-side) |
| Conservation (intent's `wired_to` vs topology) | intent's `wired_to` | the topology subgraph | YES (DEFERRED — no intent producer) |

M4 ships the two no-intent classes, proves DESTINATION Test B (disjunctive — one drift example suffices)
on the real repo-vs-cloud n8n drift, and **never fabricates an intent `left_view`** (the Element-4
test-fixture-only-pass / §8.4 vacuous-green-light failure Doctrine 06 forbids).

**Deferred-but-required (Doctrine 06 A6 — §6.7 field-level freshness scoping)**: the v1 freshness
precondition is record/node-level. The conservation class (when its intent producer exists) requires
FIELD-level scoping (a wording-only intent edit touching no `wired_to`/`conditions` field must not gate
every invariant in that record). The conservation-class implementer MUST extend the freshness precondition
with a per-field change-commit map — do NOT silently inherit this v1 partial guard.

---

## The invariant record — Doctrine 06 §6.1 (16 top-level fields + the M4 `inconclusive_reason` field)

A reconciliation invariant is the §6.1 record. The doctrine names 16 top-level fields (the "17" in Doctrine
06 §6.1 counts the `rank_completeness` sub-field inside `impact_rank`). M4 adds ONE field —
`inconclusive_reason` — the reason-code carrier for non-drift `inconclusive` verdicts (kept SEPARATE from
`drift_detail`, which is populated ONLY on `drift`, per the §6.3 discriminated union; a non-drift verdict
carries `drift_detail: null`). v1 populates every field; `action_outcome` is always `[]` in v1 (no
auto-exec — see "Action gate" below).

```
id                  # stable identity of the invariant record (provenance envelope)
kind                # versioning | derivation | conservation  (the invariant CLASS — §6.4)
source_file         # the file declaring the invariant (a references/invariants/*.json file)
source_commit       # commit the invariant DECLARATION last changed in (provenance envelope)
timestamp           # when THIS check last ran (set at compute time)
left_view           # the reference side — a jq projection of the substrate (DATA, never a producer — P2)
right_view          # the actual side — a jq projection of the substrate (DATA, never a producer — P2)
assertion           # the computable relationship that should hold (equality | containment | count-match)
verdict             # in_sync | drift | inconclusive | unverifiable_spot | unverifiable_dimension
                    #   | no-invariants-registered | pending_verification
drift_detail        # { reason_class: unilateral_drift | bilateral_wrongness | classification_uncertain
                    #     | oscillation_detected | incomparable_provenance,
                    #   specifics: <typed-per-reason_class> }
                    #   incomparable_provenance (M4 addition) carries specifics:
                    #     { left_provenance: "git|live|dirty", right_provenance: "git|live|dirty" }
impact_rank         # { rank: <int>, rank_completeness: "complete" | "partial", missing_dimensions: [...] }
affected_nodes      # topology node ids implicated by the drift
named_action        # revert | reconcile | approve_as_intentional | escalate    (REQUIRED iff verdict==drift; null otherwise)
action_outcome      # APPEND-ONLY list; ALWAYS [] in v1 (no auto-exec). v2 populates on confirmed execution.
cadence             # how often THIS check runs (informational in v1)
source_of_truth_ref # what defines "intended" for this invariant (e.g. "repo is authoritative for the deployed config")
```

The first 5 fields are the **provenance envelope** shared with Doctrines 04/05. The other 12 are the
reconciliation-specific payload (Test D: only the 5 envelope fields are shared with topology/intent —
pairwise Jaccard < 23%, separability EARNED).

---

## The verdict taxonomy (§6.1 + P1/P4/P6) — what each verdict means + when it is the HONEST answer

| Verdict | When | The doctrine principle |
|---------|------|------------------------|
| `in_sync` | the assertion holds over two PRESENT, COMPARABLE views | P1 (a real computed verdict) |
| `drift` | the assertion FAILS over two present views — carries exactly one `named_action` | P3 (named action attached) |
| `inconclusive` | a precondition prevents an honest comparison — carries a reason code | P4 (stale/absent → never drift/in_sync) |
| `unverifiable_spot` | the `right_view` includes a `manual` source-orphan node | P6 (no continuous generator) |
| `unverifiable_dimension` | the invariant reads an emitter dimension whose `coverage == "declared-missing"/"absent"` | P6 (a dark surface, declared) |
| `no-invariants-registered` | the registry is empty or all-no-op (< the §6.8 liveness minimum) | P1/§6.8 (in_sync PROHIBITED over an empty registry) |
| `pending_verification` | an action fired; awaiting re-evaluation (v2 — never reached in v1) | §6.6 |

### `inconclusive` reason codes (§6.7 + M4 addition)
- `stale-input-transient` — `right_view` is behind but within the cadence window (wait).
- `stale-input-broken` — `right_view` is behind AND beyond the max-staleness window (diagnose the generator; fires a distinct `topology-stale` signal).
- **`incomparable-provenance` (M4 addition — council C1)** — the two sides' `source_commit` provenances are NOT time-comparable on the same basis (one git-resolvable, one `live:`/`+dirty`). The commit-time *versioning* sub-assertion returns this; it NEVER returns `drift`/`in_sync` on un-alignable time bases.
- `right-view-absent` — the right view is empty because the surface exists but no comparison view was produced.
- `left-view-pending` — the left view is empty by design (`wired_to: pending` — conservation class, deferred).

---

## The join key — `attributes.n8n_id` (council C2 — verified present on repo workflow nodes)

The structural invariant matches a `repo:`-prefixed workflow node to its `cloud:`-prefixed twin by
`attributes.n8n_id` (NOT by the `id` prefix — the prefixes differ by design). Every repo workflow node
carries it (e.g. `repo:workflows/gmail-clozers-comps.json` → `attributes.n8n_id: "Gz8EKN9CWxIDcGXcoCmYq"`);
the n8n-cloud emitter's `cloud:` nodes ARE the n8n id (`cloud:Gz8EKN9CWxIDcGXcoCmYq`).

**Join-edge cases (eval-asserted):**
- a `repo:` workflow node with `null`/absent `n8n_id` → `inconclusive: right-view-absent` (cannot establish the join — NEVER a silent wrong-match).
- two `repo:` nodes sharing one `n8n_id` (a copy-rename) → flagged as `classification_uncertain`, NOT silently double-matched.
- a `cloud:` node present but no matching `repo:` node → `drift` (an unclaimed/unauthored cloud surface) per §A.13 / decision-list step 0c.

---

## The provenance-aware freshness precondition (council C1 — the load-bearing correctness invariant)

Doctrine 06 §6.7 + A11 want git commit-time on BOTH sides. The real substrate carries non-git-resolvable
provenances: cloud nodes are `source_commit: "live:honeybird:<id>"`, in-repo nodes can be
`source_commit: "<sha>+dirty"`. `git log "live:honeybird:..."` errors; a `+dirty` marker is not a clean
ref. Therefore:

1. **Classify each side's `source_commit` provenance**: `git` (a resolvable SHA), `live` (a `live:` prefix), or `dirty` (a `+dirty` suffix).
2. **The freshness SIGNAL is the node's `.timestamp`** (the ISO-8601 derivation/emit time — the health-check `fromdateiso8601` pattern, NEVER GNU `date -d`). This is the A4 "deploy id + timestamp" proxy, documented as intended — not a §9.10 wall-clock violation, because it is the DERIVATION time of a source-derived node, not an arbitrary clock read.
3. **The commit-time VERSIONING sub-assertion** (is the deployed commit the reviewed commit?) runs ONLY when BOTH sides are `git`-provenance. When either side is `live`/`dirty`, that sub-assertion returns `inconclusive: incomparable-provenance` — NEVER `drift`/`in_sync`.
4. **The STRUCTURAL assertion** (operator decision T1 — same workflow by `n8n_id` ⇒ same `node_count`) fires INDEPENDENT of commit-time comparability: it compares two source-derived structural facts (node counts), which are present and comparable regardless of provenance time-basis. A count mismatch → `drift`. This is what fires the Test B headline.

So a single repo-vs-cloud invariant produces, honestly and simultaneously: a `drift` on the structural
count-conservation assertion (Test B fires) AND an `inconclusive: incomparable-provenance` on the
commit-time versioning sub-assertion (the honest non-verdict where the time bases don't align).

---

## The ordered decision-list (§11) — ONE jq expression, a `{verdict, named_action}` discriminated union (council C4)

Implemented as a SINGLE jq expression (NOT a bash guard chain with intermediate `exit`s — that risks a
`drift` escaping with `named_action: null` under `set -e`). Evaluated top-down; first match wins:

```
0.  PRECONDITION (P4/§6.7): provenance-aware freshness.
      - structural assertion (count by n8n_id) is computed regardless (T1).
      - commit-time sub-assertion: if either side's provenance ∈ {live, dirty} → that sub-verdict is
        inconclusive: incomparable-provenance.
0a. LIVENESS (P1/§6.8): registry empty or all-no-op → no-invariants-registered. HALT.
0b. UNVERIFIABLE (P6): right_view's emitter coverage == "declared-missing"/"absent" → unverifiable_dimension. HALT.
      right_view includes a manual source-orphan node → unverifiable_spot. HALT.
      (detection via jq -e exit-code on the coverage ENUM, never echo|grep -q — SIGPIPE; never a node-count.)
0c. EMPTY/JOIN: left_view empty (join key null) → inconclusive: right-view-absent. HALT.
      right_view empty because the emitter is COVERED but this specific node is absent (State B)
        → inconclusive: right-view-absent (a transient gap — NOT drift). HALT.
      right_view present but no matching left (unclaimed cloud surface) → drift (named_action by step 2-7). 
1.  COMPUTE the structural assertion over left_view vs right_view. Holds → in_sync. HALT.
2.  (drift) authoritative side UNKNOWN from available data → escalate (reason: authorship_ambiguous). HALT. (A3)
3.  consequence HIGH (impact_rank > threshold OR security control OR irreversible) AND NOT deliberate-and-tracked → escalate. HALT.
4.  actual drifted, reference still right → revert (confirm-gated, P5). HALT.
5.  reference stale, change deliberate-and-tracked → reconcile (confirm-gated). HALT.
6.  reference stale, change deliberate-but-untracked → approve_as_intentional. HALT.
7.  ELSE (fits none) → escalate (catch-all — closes the no-tiebreak case). HALT.
```

**The discriminated union** the jq returns: `{verdict: "drift", named_action: <one of four>, ...}` OR
`{verdict: <non-drift>, named_action: null, ...}`. `named_action != null IFF verdict == drift` is
structurally guaranteed by the jq expression's shape — not documented-but-possible.

---

## The per-class authority rule (council S3 — the four-action selector v1 default)

In v1 there is NO intent record, so the doctrine's "deliberate-and-tracked" test (which reads an intent
record / roadmap entry) has no data source. The v1 default, per invariant CLASS:

- **Structural / versioning class** — the **REPO is authoritative by definition** (the repo is the source
  of truth for "what should be deployed"). A repo-vs-cloud drift where the cloud diverged → step 5
  `reconcile` (bring the deployed cloud config to match the repo — i.e. redeploy), framed as the
  doctrine's "actual drifted, reference still right" with the repo as the reference. This avoids
  anti-pattern 9.9 (escalate-everything).
- **Derivation class** — the **source set is authoritative**. A repo-declared object absent from the
  live-derived topology → `reconcile` (apply it); a topology node with no resolvable source → `escalate`
  (source-orphan masquerade).
- **Genuinely-unknown authority** (e.g. a cloud surface with no repo counterpart AND no clear owner) →
  `escalate` (authorship_ambiguous).

`source_of_truth_ref` on each invariant record names the authority explicitly ("repo is authoritative for
the deployed config").

---

## The action-execution gate (P5/§6.6) — v1 PROPOSES, never auto-executes (council S1)

`revert`/`reconcile` are state-mutating. v1 **proposes** the named action and prints it; it does NOT
execute. No persistent records file in v1 — stdout + `--json` IS the audit trail (`action_outcome` is
always `[]`). The persistent gitignored records file + its mkdir-lock + the auto-exec path defer to v2.
`approve_as_intentional`/`escalate` are record-or-notify (safe) — also surfaced to stdout in v1.

**Oscillation guard (§8.6 — council S2)**: the `drift_detail.reason_class: oscillation_detected` variant
+ the `len(action_outcome) ≥ 3` guard are **not exercisable in v1** (no auto-exec populates
`action_outcome`). v1 marks the code path `# v2-gated` and an eval asserts `oscillation_detected` is NEVER
returned under v1 conditions (prevents a code-path bug misfiring it).

---

## `impact_rank` (§A6) — the `depended_on_by` walk

`impact_rank.rank` = the count of downstream consumers, walked from the drifted node's `depended_on_by`
via `read-topology`. Carries `rank_completeness: partial` + `missing_dimensions` when the topology graph
is incomplete at the entity (the current BuyBox-AI substrate IS partial — supabase + n8n declared-missing
— so every rank on it is `partial`, never presented as authoritative, §8.7).

**Walk safety (council S4):** `(.depended_on_by // [])` coalesces null to empty (M1); the walk is
DEPTH-LIMITED (default 20) with a visited-set so a cyclic `depended_on_by` cannot hang. A cycle sets
`rank_completeness: partial` + a `cycle_detected` flag — never an infinite loop.

---

## What this skill is NOT (scope boundaries)

- **Not an emitter** — it READS the substrate; it NEVER runs an emitter inside `compute()` (the P2
  boundary — the Test D operational limb). The Test B live re-run drives the frozen n8n-cloud emitter as a
  SEPARATE step (a populate step OUTSIDE the comparator), then the comparator reads the populated substrate.
- **Not an intent author** — it NEVER writes an intent record (the P2 boundary — §3.1).
- **Not a substrate writer** — READ-ONLY; the substrate is byte-untouched after a run (eval-asserted).
- **Not the conservation class** — that needs an intent producer (deferred). v1 = structural + derivation.
- **Not an auto-executor** — v1 proposes; the confirm-gate + auto-exec + the persistent audit trail are v2.

---

## References

- `docs/operational-doctrine/06_conservation-law-verification.md` — the build spine (§6.1-6.8, §11, Appendix C/E)
- `.claude/skills/topology-substrate/references/canonical-shape.md` — the substrate the views project from (the `attributes.n8n_id` join key, the coverage enum, the `source_commit` provenance formats)
- `.claude/skills/topology-health-check/scripts/health-check.sh` — the `fromdateiso8601` freshness pattern + the `owned()` node-attribution jq this skill composes
- `council/sessions/2026-06-02-m4-reconciliation-proof-plan.md` — the extended council (C1-C5, S1-S6, T1/T2 operator decisions)
- `DESTINATION.md` — Test B (the M4 bar) + the Element-4 could-the-test-lie scenarios
