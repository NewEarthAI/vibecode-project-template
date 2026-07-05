# Conservation-Law Verification — Operational Doctrine

> **Doctrine 06 of the operational-doctrine set.** Companion doctrines: `04_intent-capture.md` (the authored promise — the `left_view` source), `05_topology-from-source.md` (the derived actual graph — the `right_view` source). This doctrine is the third of the three Intent-Actual-Gap mechanisms (programme spec `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`; success contract `DESTINATION.md` v2).
>
> **Authored**: 2026-05-22 (M2, Intent-Actual-Gap Mechanism Build Programme). **Verification**: triple gate (`doctrine-verification-gate.md`) — see Sections 13-14. **Separability**: defended in Section 12 (Test D). **Plan**: `specs/13_M2_DOCTRINE_06_PLAN.md` v2 (extended-council GO + amendments A1-A11).
> **schema-review-required: before-M3-ships** — the machine-readable invariant record in Section 6 + Section 12 is a pre-M3 design commitment; before M3 ships the reconciliation mechanism, re-read this doctrine and flag any field the implementation will not expose (a flag triggers a Test D re-run).

---

## 1. Purpose

Conservation-Law Verification is the mechanism that **measures the gap between what a system was supposed to do and what it actually does, and attaches a named action to close it**. It takes two views that should agree — an intended view (from Doctrine 04's intent records) and an actual view (from Doctrine 05's derived topology) — asserts the invariant that should hold between them, emits a verdict, and proposes one of four named actions.

The doctrine governs neither half of the gap. It does not author what the system is supposed to do (that is intent, Doctrine 04) and it does not derive what the system actually is (that is topology, Doctrine 05). It governs the **comparator**: the artefact that takes two already-emitted views and answers "is the promise still kept, and if not, what should be done about it?" — as a structured verdict, source-traceable, with a remediation path attached.

The doctrine exists because intent and topology, on their own, are two unconnected facts. A destination promises that authenticated users can access only their own billing; the topology shows which RLS policies actually exist. Nothing connects them until something *asserts the invariant* ("the promised access control is wired") and *computes a verdict*. Without that comparator, "is my promise still kept?" requires a human to hold both views in their head and diff them manually — exactly the cognitive cost the programme exists to eliminate. The single discipline that makes the comparator trustworthy is captured in one phrase: **a named invariant that is never actually computed is theatre, not verification.**

## 2. Why this doctrine earned its slot

The M1 research (`specs/research/architecture-blueprint-research-2026-05-22.md`) found that every open-source reconciliation tool — Soda, Great Expectations, dbt tests, Datafold, Atlas drift detection, the GitOps reconciliation loop — is **pure ALERT**: it detects that two views disagree and surfaces the disagreement, but proposes no action. The destination forbids stopping there: "Closing drift is a named action, not improvisation … the operator sees one of four named actions attached to it" (Condition 3). Named-action vocabularies exist only in closed commercial tools and are not published; the four-action vocabulary in this doctrine is therefore **authored from first principles, defended on internal grounds, with no industry template** (Section 6.4, Section 12.1 F4).

This doctrine earns its slot because the compare-and-propose-an-action payload is a load-bearing design commitment that neither Doctrine 04 (which authors a promise) nor Doctrine 05 (which derives a fact) makes. It is also the only mechanism that *consumes* both siblings' contracted outputs — Doctrine 04's `wired_to` and `conditions` as the `left_view`, Doctrine 05's subgraph as the `right_view`. Without it, those two contracts have no consumer (Section 14). Its separability from the other two is earned not by being upstream of them (it is downstream of both) but by the asymmetry of the dependency — it reads both; neither reads it — and by a schema, an update cadence, and an operator workflow none of the other two carries (Section 12).

## 3. Scope boundary — what this doctrine does NOT do

### 3.1 Authoring the intended view (→ Doctrine 04, Intent Capture)

The `left_view` of a reconciliation invariant is an intent record's `wired_to` + `conditions`. Conservation-Law Verification does NOT author that intent — it *reads* an already-authored record. If a session finds itself writing a new intent claim inside the reconciliation mechanism, it has crossed into Doctrine 04's jurisdiction. Reconciliation consumes intent; it never produces it.

### 3.2 Deriving the actual view (→ Doctrine 05, Topology-from-Source)

The `right_view` of a reconciliation invariant is a topology subgraph. Conservation-Law Verification does NOT generate that graph — it *reads* an already-emitted one (Doctrine 05's `subgraph(filter)` contract, 05 §6.5 + Appendix E). If the mechanism finds itself running an emitter (`pg_depend`, the n8n parser) to produce the graph it compares against, it has crossed into Doctrine 05's jurisdiction. Reconciliation consumes topology; it never generates it.

### 3.3 Continuous monitoring / alerting infrastructure (delegated to M3 + observability)

*How often* the check runs, *where* the alert goes, and the runner's own uptime are M3 mechanism + observability concerns. This doctrine specifies the `cadence` field (how often an invariant should be checked) and the verdict-and-action semantics; it does not specify the cron schedule, the notification channel, or the runner's heartbeat. Those are operate-cost concerns the M3 build inherits from this doctrine's Application Checklist (Section 11) and Appendix E.

### 3.4 Fixing the drift itself (the named action proposes; the operator/AI executes)

Conservation-Law Verification *proposes* one of four named actions. It does not, by default, *execute* the state-mutating ones (`revert`, `reconcile`) without confirmation (Section 6.6, Principle 5). The doctrine governs the verdict and the proposed action; the act of restoring state, redeploying, or amending an intent record is performed by the operator or by an AI session under a confirmation gate, with an audit row. The mechanism is the diagnostician, not the surgeon-without-consent.

### 3.5 Runtime behaviour verification (a different signal class)

Whether a function actually executed correctly at runtime (traces, spans, assertions on live behaviour — Sentry, PostHog, runtime contract checks) is a different signal from whether two *declared/intended* views agree. Conservation-Law Verification compares the intended structure against the derived structure; it does not observe execution. A workflow that is correctly wired (in_sync) can still fail at runtime — that is observability's domain, not this doctrine's. The exception is the versioning class (6.4.1), which compares a deployed commit against a source commit — but even there it compares *declared* deploy provenance, not *observed* runtime behaviour.

## 4. Governing principles

Each principle is paired with a falsification condition.

### Principle 1: A named invariant that is never computed is theatre

Every reconciliation invariant must, when it fires, actually compute a verdict against two real, present views. Asserting that an invariant *should* hold — naming it as a gate, a check, a promise — without ever computing its verdict against two emitted views is the doctrine's root failure. This is the principle the Gate-3 real-decision case (Section 13) turns on.

**Falsification**: if an invariant is recorded as a gate or check but its `verdict` field is never populated by an actual comparison of `left_view` against `right_view`, the invariant is theatre — it provides false assurance. The mechanical test: every invariant claiming to verify something must produce a `verdict ∈ {in_sync, drift, inconclusive, unverifiable_spot, unverifiable_dimension, no-invariants-registered, pending_verification}` from a real two-view comparison, or it is not a verification.

### Principle 2: The comparator consumes finished views; it never authors or generates them

Reconciliation reads an already-emitted intent view (`left_view`) and an already-emitted topology view (`right_view`). It does not author intent (P1 of Doctrine 04) and does not generate topology (P1 of Doctrine 05). This is the basis of its operational separability (Section 12.3): a compiler consumes source files without being the editor or the filesystem.

**Falsification**: if computing a verdict requires the reconciliation mechanism to author a new intent record OR run a topology emitter inside itself, the principle is violated, the comparator is not a separate mechanism but a re-implementation of its siblings, and Test D's operational limb fails — the doctrine count reverts.

### Principle 3: Every verdict carries a named action or a named reason it cannot

A `drift` verdict carries exactly one of four named actions (`revert` / `reconcile` / `approve_as_intentional` / `escalate`), selected by the rule in Section 6.5. A non-`drift` verdict (`inconclusive`, `unverifiable_spot`, `no-invariants-registered`) carries a named *reason* and the operator step that resolves it. No verdict is a bare signal an operator must interpret unaided — the destination's Condition 3 demands the action be attached.

**Falsification**: if a `drift` verdict is emitted with no `named_action`, or with two competing actions and no tiebreak, the action vocabulary is incomplete (Section 6.5's falsification condition) and the principle is violated for that drift.

### Principle 4: A comparison against a stale or absent view is inconclusive, never in_sync and never drift

If the `right_view` topology is staler than the last change to the `left_view` intent fields the invariant reads (the freshness precondition, Section 6.7), OR if either view is empty, the verdict is `inconclusive` (or the more specific `unverifiable_*`), NEVER `drift` (a false alarm that trains operators to ignore verdicts) and NEVER `in_sync` (a false all-clear over input that was never actually compared). `inconclusive` is a load-bearing, honest verdict — the mechanism saying "I cannot speak to this yet" — not a cop-out.

**Falsification**: if the mechanism emits `drift` on a stale-input comparison (false positive) or `in_sync` over an empty/absent view (vacuous green-light), Principle 4 is violated and the theatre-of-trust failure (8.1) or the vacuous-green-light failure (8.4) is live.

### Principle 5: State-mutating actions are gated and audited; read-only actions are safe-by-default

Two of the four actions mutate live state: `revert` (restore the intended state) and `reconcile` (update the intent to match the new actual). These do not execute automatically by default — they require operator/AI confirmation, and every execution writes an audit row recording what changed, from what state, to what state, triggered by which invariant verdict. The other two actions — `approve_as_intentional` (record + file a tracked entry) and `escalate` (route to council/human review) — are record-or-notify only and are safe to automate. This mirrors the workshop's standing confirm-before-destructive guardrail.

**Falsification**: if a `revert` or `reconcile` executes a state mutation with no confirmation gate and no audit row, the principle is violated and the silent-state-mutation failure (8.3) is live — a mis-fired auto-revert silently undoes a deliberate change with no recovery trail.

### Principle 6: An invariant the mechanism cannot continuously verify is marked, not silently passed

Some invariants compare against a node a generator cannot continuously re-derive — a `manual` source-orphan node (Doctrine 05 §6.6), or a degenerate dimension at an entity (your project's Postgres-only topology). For those, the verdict is `unverifiable_spot` (a single un-regenerable node) or `unverifiable_dimension` (a whole dark surface), NOT `in_sync`. The mechanism never asserts a promise is kept over a surface it cannot actually re-check.

**Falsification**: if an invariant whose `right_view` includes a `manual` node returns `in_sync` (implying continuous verification that no generator provides), Principle 6 is violated and the source-orphan vacuous-green-light (8.5) is live.

### Principle interaction — how the six compose

The principles form a dependency chain an M3 builder implements together, not piecemeal:

- **P1 (compute, don't assert) is the root.** A reconciliation mechanism that names invariants but never computes their verdicts is theatre regardless of how good its vocabulary is. P3 (named action) and P4 (honest non-verdicts) only have meaning if P1 holds — there must be a real verdict before there can be an action or an honest "I cannot say."
- **P2 (consume, don't author/generate) is what makes reconciliation a separate mechanism** rather than a re-implementation of its siblings. It is the operational-separability basis (Section 12.3); violate it and the three-way split collapses into one bundled thing.
- **P4 (stale/absent → inconclusive) is what makes P1's verdicts trustworthy over time.** A mechanism that computes verdicts (P1) but computes them against stale inputs produces false positives that erode trust — P4 is the guard that keeps the computed verdict honest.
- **P5 (gate + audit mutating actions) is what makes P3's actions safe.** A named action that mutates state automatically is more dangerous than no action; P5 bounds the blast radius.
- **P6 (mark the unverifiable) is what keeps P4 honest at the edges** — `inconclusive` is for *timing* (stale input that will clear); `unverifiable_*` is for *structural* incompleteness (a surface that will never be continuously checkable). Conflating them hides a permanent gap behind a transient label.

Practical order for M3: implement P1+P2 first (the compute-from-two-consumed-views core), then P4 (the freshness/empty-view guard), then P3 (the action selector), then P5 (the gate + audit on mutating actions), then P6 (the unverifiable markers). An implementation that builds the action selector (P3) before the compute-and-freshness core (P1+P4) has built a mechanism that confidently proposes actions on verdicts that may be theatre or false positives.

## 5. Assumptions

- **A1**: Both sibling views are emittable and present. Doctrine 04 can produce an intent record's `left_view` (its `wired_to` + `conditions`); Doctrine 05 can produce a topology `subgraph` as the `right_view`. Where one is absent, the invariant is `inconclusive` or `unverifiable_*` (P4/P6), never silently `in_sync`.
- **A2**: The two views carry the shared 5-field provenance envelope (`id`, `kind`, `source_file`, `source_commit`, `timestamp`) so the freshness precondition (6.7) can compare their commit-times. This is the substrate all three mechanisms share (Section 12).
- **A3**: An invariant's `assertion` is expressible as a computable relationship between fields of the two views (an equality, a containment, a count-match). An invariant whose assertion cannot be mechanically computed is not a reconciliation invariant — it is a manual review item out of scope (3.5).
- **A4**: The reconciliation mechanism can read git commit-time for both views' source commits (the freshness precondition uses commit-time, not wall-clock — A11/6.7). For file-based sources this resolves from git; for live sources (a deployed config) the provenance is the deploy id + timestamp (inherited from Doctrine 05 A3).
- **A5**: At least one versioning + one derivation invariant is registered before the mechanism is declared live at an entity (the minimum-viable-invariant-set guard, 6.8 / 8.6). An empty registry is `no-invariants-registered`, not `in_sync`.
- **A6**: `impact_rank` is computed by walking Doctrine 05's `depended_on_by` from the drifted node (the A.17 composition trace contracted in Doctrine 05). Where the topology graph is incomplete at an entity, `impact_rank` carries a `rank_completeness: partial` flag — a partial fan-in count under-ranks impact and must be flagged, never presented as authoritative (8.7).

## 6. Mechanisms

### 6.1 The invariant record — machine-readable carrier

The atomic unit is the **invariant record**, a structured object with these fields:

```
id                  # stable identity of the invariant record (provenance envelope)
kind                # versioning | derivation | conservation (the invariant class)
source_file         # the file declaring the invariant (provenance envelope)
source_commit       # commit the invariant declaration last changed in (provenance envelope)
timestamp           # when this check last ran (provenance envelope)
left_source         # M6 addition — where the left_view is read from: `intent` (the intent store, via INTENT_SUBSTRATE_PATH) | absent/`topology` (the topology substrate, the default). The conservation class's two-source selector (§6.4.3). Versioning/derivation invariants OMIT this → topology default → byte-unchanged.
left_view           # the "intended" side — a duck-typed view (6.2); typically intent's wired_to + conditions
right_view          # the "actual" side — a duck-typed view (6.2); typically a topology subgraph
assertion           # the computable equality/containment/count relationship that should hold
verdict             # in_sync | drift | inconclusive | unverifiable_spot | unverifiable_dimension | no-invariants-registered | pending_verification
drift_detail        # STRUCTURED (Gate-2 patch — reason_class enum extended for the §8.6 oscillation signal):
                    # { reason_class: unilateral_drift | bilateral_wrongness | classification_uncertain | oscillation_detected,
                    #   specifics: <tagged-union-per-reason_class — typed per case, NOT free-form> }
                    # The oscillation_detected variant carries specifics: { run_count: int (≥3), last_action_executed_at: timestamp }.
                    # specifics is typed per reason_class; an M3 builder cannot store oscillation run-count as unstructured text.
impact_rank         # downstream-consumer impact, walked from topology's depended_on_by; carries rank_completeness (A6/A10)
affected_nodes      # topology node ids implicated by the drift
named_action        # revert | reconcile | approve_as_intentional | escalate (with a reason on escalate, A3)
                    # CROSS-FIELD INVARIANT (Gate-2 patch): named_action is REQUIRED when verdict == drift,
                    # FORBIDDEN when verdict != drift. The §6.3 verdict() return is a discriminated union enforcing this:
                    # { verdict: 'drift', named_action: NonNullAction, ... } | { verdict: NonDriftVerdict, named_action: null, ... }
action_outcome      # APPEND-ONLY LIST (Gate-2 patch — supports the §8.6 oscillation guard's ≥3-cycle detection):
                    # action_outcome: [{ executed_at, from_state, to_state, succeeded }]  (empty list when no action has run)
                    # CROSS-FIELD INVARIANT: action_outcome non-empty implies verdict ∈ {pending_verification, or a post-action re-checked value} — never a pre-action verdict.
                    # The oscillation guard (§8.6) counts len(action_outcome) of recent drift→action cycles; a single struct could not.
cadence             # how often THIS check runs (distinct from intent's acceptance_cadence)
source_of_truth_ref # what defines "intended" for this invariant
```

The first five fields (`id`, `kind`, `source_file`, `source_commit`, `timestamp`) are the **provenance envelope** shared with the other two mechanisms (Doctrines 04, 05). The remaining twelve are the reconciliation-specific payload — the compare-and-act fields (`left_view`, `right_view`, `assertion`, `verdict`, `drift_detail`, `impact_rank`, `affected_nodes`, `named_action`, `action_outcome`, `cadence`, `source_of_truth_ref`) that distinguish this mechanism (Section 12, the Test D defence). Note `action_outcome` (A9) is new vs. the v1 sketch's 15 fields, as is the `rank_completeness` sub-field inside `impact_rank` (A10); the schema was 17 fields at M4. **M6 added `left_source`** (the conservation class's two-source selector) → **18 fields**; Test D re-run on the 18-field set is logged in the Status Footer + Doctrine 04 §12.1.1 (both pairs moved further below 50%, separability strengthened).

### 6.2 The duck-typed view contract (A1 — the separability-load-bearing decision)

`left_view` and `right_view` are **duck-typed, not schema-typed to the siblings**. The comparator accepts ANY structured intent-side record and ANY structured actual-side record, provided each carries the 5-field provenance envelope (so freshness can be computed). It does NOT require the specific field set of Doctrine 04 or Doctrine 05.

This is the decision that makes separability genuine rather than a tightly-coupled pipeline (Section 12.3, council A1). If the comparator were hardwired to read `wired_to` as a named field of Doctrine 04 and `depended_on_by` as a named field of Doctrine 05, it would be the final stage of an Extract→Transform→Load pipeline, not a separate mechanism. By contracting the minimal required interface — *"a left view and a right view, each carrying the provenance envelope, plus an assertion expressed over their fields"* — the comparator can be invoked on any intent source and any actual source. The typical instantiation reads 04's and 05's outputs, but the contract does not bind it to them.

### 6.3 The read API (the typed interface — A1, makes Decision-2 falsifiable at Gate 2)

The comparator exposes a small, typed read surface (a deep module). The signatures take **only views** — never a generator function or an author function as an argument, which is what structurally enforces P2 and makes the separability falsifier checkable at review time, not deferred to M3:

```
define_invariant(kind, left_view, right_view, assertion, cadence, source_of_truth_ref) -> invariant_id
compute(invariant_id, left_view_snapshot, right_view_snapshot) -> verdict_record
   # left_view_snapshot, right_view_snapshot are ALREADY-EMITTED views (data), not producers.
   # compute() NEVER calls an emitter or an intent author. This is the P2 boundary, enforced at the type level.
verdict(invariant_id) -> DriftVerdict | NonDriftVerdict   # discriminated union — see below
   # DriftVerdict     = { verdict: 'drift', drift_detail, impact_rank, named_action: <one of the four>, action_outcome: [...] }
   # NonDriftVerdict  = { verdict: 'in_sync' | 'inconclusive' | 'unverifiable_spot' | 'unverifiable_dimension'
   #                              | 'no-invariants-registered' | 'pending_verification',
   #                      drift_detail: null, named_action: null, impact_rank, action_outcome: [...] }
   # The discriminated union makes the cross-field invariant (named_action non-null IFF verdict == drift) STRUCTURALLY UNREPRESENTABLE
   # at the type level — not just documented-but-possible. (Gate-2 patch.)
registry_health() -> { live_invariant_count, no_op_invariant_count } # for the liveness gate (6.8)
```

No write to the views themselves: the comparator never edits intent or topology. It only writes its own verdict records and, when a confirmed action executes, the `action_outcome` audit row (6.6 / P5).

### 6.4 The three invariant classes (the doctrine's taxonomy)

Each class maps to a different `left_view`/`right_view` pairing. The canonical analogue named for each is the CLASS pattern only — never evidence the three-way mechanism split works (F4, Section 12.1).

| Class | The question it answers | `left_view` | `right_view` | Class-pattern analogue (NOT split-precedent) |
|-------|------------------------|-------------|--------------|-----------------|
| **Versioning** | Is the recorded promise still the live one? | intent's current (non-superseded) record | topology's deployed/live commit (e.g. an edge function's `deployed_commit`) | semver / GitOps desired-vs-live |
| **Derivation** | Does the generated topology trace to source? | the source artefact set | topology's emitted node provenance | dbt source-freshness |
| **Conservation** | Do two views of state agree? | intent's `wired_to` | topology's actual subgraph | double-entry bookkeeping (a balance-across-two-sources pattern only — accounting has no separate "intent capture" mechanism, so it is NOT a precedent for the three-way split) |

#### 6.4.1 Versioning class
Compares a promised version against the live one. Example: intent says the billing edge function should be at the reviewed commit; topology's `edge_function` node carries `deployed_commit`; the invariant asserts `source_commit == deployed_commit`. A mismatch is the deploy-drift class (Doctrine 05 A.15, the Cedar Hurst pattern).

#### 6.4.2 Derivation class
Compares whether the generated topology traces to source. Example: a materialized view's `last_refresh` vs the `source_commit` of a base table it depends on (Doctrine 05 A.14) — if the view is older than its base, the derivation invariant breaches.

#### 6.4.3 Conservation class
Compares two views of state for agreement (the double-entry analogue). Example: intent's `wired_to` claims an RLS policy enforces own-billing access; topology's subgraph either contains the enabled policy node or it does not (Doctrine 05 A.1 / A.11). Counts match; deployed config matches repo; promised features are wired.

### 6.5 The action selector (the four-action vocabulary — workshop-original, no industry template)

When the verdict is `drift`, exactly one named action is selected. The **2-axis grid** explains the design intent; the **flat ordered decision-list** (Section 11) is the M3-implementable form (A11). Both are in the doctrine, serving the reasoning audience and the builder audience respectively.

**The 2-axis grid** (axis A = which side is authoritative; axis B = consequence tier):

| | Low consequence (closeable without human judgement) | High consequence (needs human/council judgement) |
|---|---|---|
| **Actual drifted; intent still right** | `revert` — restore the intended state | `escalate` |
| **Intent stale; change deliberate + TRACKED** (roadmap/ADR exists) | `reconcile` — update intent to match new actual | `reconcile` with warning (A4 — a tracked deliberate change is NOT blocked behind escalation) |
| **Intent stale; change deliberate but UNTRACKED** | `approve_as_intentional` — record + file a retroactive tracked entry | `approve_as_intentional` + retroactive entry |
| **Authoritative side UNKNOWN** (A3) | `escalate` (reason: `authorship_ambiguous`) | `escalate` (reason: `authorship_ambiguous`) |
| **Unintended + consequential** | — | `escalate` |

`escalate` is the override (for unintended high-consequence drift), the catch-all (for any drift fitting none of the rows), AND the authorship-ambiguous sink (A3). The tracked/untracked split (A4) is the carve-out that prevents a correct, tracked, deliberate improvement from being blocked behind council review — high-consequence + deliberate-and-tracked reaches `reconcile`-with-warning, not `escalate`.

**Falsification condition**: the vocabulary is incomplete if (a) a real drift fits none of the rows, OR (b) two rows fit with no tiebreak. The `escalate` catch-all closes (a); the ordered decision-list (Section 11) closes (b) by fixing the evaluation order so the first matching rule wins.

### 6.6 The action-execution gate + audit (P5 — A9)

`revert` and `reconcile` mutate state and are **confirm-gated by default**. The selector emits the `named_action`; execution does not proceed until an operator confirms (one click) or an AI session issues a structured confirm call (destination Condition 3: "one click for humans and one structured call for AI"). Auto-execution is available only as an explicit opt-in scoped to a low `impact_rank` threshold, and even then writes the audit row.

Every executed action **appends** a row to `action_outcome` (now an append-only list per the §6.1 patch): `{ executed_at, from_state, to_state, succeeded }`. After a `revert`/`reconcile` fires, the invariant enters `pending_verification` until the next run re-evaluates it. A second `drift` on the same invariant within one cadence after an action fired is an **escalation signal** (the action did not resolve the drift — likely an oscillation, 8.6 / A.10), not a fresh independent detection. The oscillation guard counts consecutive drift→action cycles by reading `action_outcome` history — `len(action_outcome) ≥ 3` with alternating drift/action pattern → `drift_detail.reason_class = oscillation_detected` with `specifics.run_count` populated.

The consequence-assessment heuristic (which determines axis B, low vs high) is named and falsifiable: **high consequence = `impact_rank` above a configured threshold OR the affected node is a security control (`rls_policy`, an auth edge function) OR the action is irreversible.** Anything else is low consequence. A reviewer can check this against any drift; it is not an implicit judgement.

### 6.7 The freshness precondition (P4 — A6, field-level scoped)

Before the `assertion` is evaluated, a precondition gate runs. It compares, **using git commit-time on both sides** (A11 — never wall-clock, which is subject to skew):

> the `right_view` topology's regenerating commit-time MUST be ≥ the commit-time of the last change to the SPECIFIC `left_view` intent fields this invariant reads (`wired_to` / `conditions`) — NOT the whole intent record's `source_commit`.

If the precondition fails (topology is staler than the relevant intent fields), the verdict is `inconclusive`, with a reason code:
- `stale-input-transient` — topology is behind but within the configured cadence window (the next regeneration will clear it; operator action: wait). (A7)
- `stale-input-broken` — topology is behind AND beyond the max-staleness window (the generator has missed ≥N cycles; this fires a distinct `topology-stale` alert, not a silent inconclusive; operator action: diagnose the generator). (A7)

The **field-level scoping** (A6) is what prevents the system-wide-blackout trap: a wording-only intent edit that touches no `wired_to`/`conditions` field does NOT force every invariant in that record to `inconclusive` — only invariants reading the changed fields are gated. The record carries a per-field change-commit map so the precondition can scope correctly.

### 6.8 The liveness gate (P1 + minimum-viable-invariant-set — A8)

The mechanism is not "live" at an entity merely because it is running. Liveness requires:

> `count(invariants WHERE left_view NON-EMPTY AND right_view NON-EMPTY) ≥ 2`, including ≥1 versioning and ≥1 derivation invariant (A5).

If the registry is empty, the verdict is `no-invariants-registered` (a LOUD distinct verdict) — the mechanism is PROHIBITED from emitting `in_sync` when it has checked nothing. A registered invariant whose `left_view` or `right_view` matches zero nodes is a no-op invariant and is flagged on first run, not silently counted toward liveness. This closes the vacuous-green-light failure (8.4) and the empty-registry-looks-healthy failure at startup.

## 7. Leverage points — where this doctrine pays rent

### 7.1 The cross-mechanism comparison (the highest-leverage point)

Reconciliation is the only mechanism that turns two static views into a live drift signal. By contracting the comparison here — the duck-typed view interface (6.2), the typed read API (6.3), the verdict-and-action semantics — the doctrine prevents the M3 mechanism from improvising the join. Intent emits the promise; topology emits the fact; reconciliation emits the verdict + action. The contract is fixed.

### 7.2 "Is my promise still kept?" — the conservation query

The single most valuable operator question this doctrine answers. Before trusting that a security promise holds, a conservation invariant compares intent's `wired_to` (the promised RLS policy) against topology's actual subgraph (the policy node, with its `enabled` attribute) and emits `in_sync` or `drift` with a named action — source-traceable on both sides. This is the question whose silent failure is the most dangerous (a disabled-but-present security control, A.6).

### 7.3 Deploy-drift made a first-class signal (versioning class)

The source-vs-deployed drift class (Doctrine 05 A.15, the Cedar Hurst pattern) becomes a versioning invariant: `source_commit == deployed_commit` on an edge-function node. Drift fires `reconcile` (redeploy) or `escalate` (if consequential). The silent-killer class the `verify-shipped` skill exists to catch becomes a continuously-checked invariant.

### 7.4 AI-session drift-awareness (Condition 6)

An `/autovibe` session, before acting, asks the comparator "are there open drifts on the area I'm about to touch?" and gets a structured, ranked, source-traceable answer with named actions — without re-discovering the gap manually. This is the autonomous-consumption the destination's Test C requires.

### 7.5 Anti-leverage — where this doctrine does NOT pay rent

Reconciliation earns nothing (and may mislead) in these situations:

- **No intent OR no topology**: with only one view, there is nothing to compare. Reconciliation is the comparator; it is vacuous where a side is absent (it correctly returns `inconclusive`/`unverifiable_*`, but it adds no value there).
- **Runtime-behaviour questions**: "did this actually run correctly?" is observability (3.5), not a declared-view comparison. Reconciliation compares intended structure against derived structure, never observed execution.
- **Single-author, single-session, never-changing systems**: where intent and actual cannot drift apart (one person, one session, no deploys), the comparator has no gap to find. Its overhead exceeds its value.
- **Subjective or non-computable "agreement"**: an invariant whose assertion cannot be mechanically computed (A3) is a manual review item, not a reconciliation invariant. Forcing it into the mechanism produces `classification_uncertain` noise.

Naming the anti-leverage prevents the over-application failure: a comparator applied where it pays no rent erodes trust in it everywhere.

## 8. Failure modes — where this doctrine produces wrong results

### 8.1 Theatre-of-trust via false-positive drift (stale input)

If the comparator fires `drift` while topology is staler than the intent fields it reads, operators see drift that is not real, learn to distrust verdicts, and bypass the mechanism (destination Element 4 scenario 1). Detection signal: a `drift` verdict where the freshness precondition (6.7) should have gated to `inconclusive`. **Recovery**: the freshness precondition is mandatory and field-scoped (P4/A6); a stale comparison is `inconclusive`, never `drift`.

### 8.2 Silent-perpetual-inconclusive (the dark mechanism)

If the comparator returns `inconclusive` indefinitely (topology never regenerates, or the generator is broken) and does not distinguish transient from broken, the operator sees no drift AND no error — indistinguishable from `in_sync`. Detection signal: `inconclusive` persisting beyond the cadence window with no `topology-stale` alert. **Recovery**: split `inconclusive` into `stale-input-transient` vs `stale-input-broken` (A7); the broken state fires a distinct alert, making the dark mechanism loud.

### 8.3 Silent state mutation (mis-fired auto-action)

If `revert`/`reconcile` execute automatically with no confirmation and no audit row, a mis-fired auto-revert silently undoes a deliberate change (the developer deployed first, authored intent second; the comparator reverted the correct change to a stale state). Detection signal: a state change with no `action_outcome` audit row tracing it. **Recovery**: P5/A9 — mutating actions confirm-gate by default and write an audit row; the blast radius is recoverable in minutes from the audit trail, not days.

### 8.4 Vacuous-green-light (empty registry or empty views)

If the comparator emits `in_sync` when the registry is empty, or when registered invariants match zero nodes, it asserts "all promises kept" having checked nothing (destination Element 4 scenario 2). Detection signal: an `in_sync` system-level verdict with `live_invariant_count` of zero or all-no-op. **Recovery**: the liveness gate (6.8/A8) emits `no-invariants-registered` and PROHIBITS `in_sync` over an empty/no-op registry.

### 8.5 Source-orphan vacuous-green-light

If an invariant compares against a `manual` source-orphan node (Doctrine 05 §6.6) and returns `in_sync`, it implies continuous verification no generator provides — the node could have re-drifted weeks ago. Detection signal: an `in_sync` verdict on an invariant whose `affected_nodes` include a node with `emitter: "manual"`. **Recovery**: P6/A10 — such an invariant returns `unverifiable_spot`, distinct from `inconclusive`, with a manual-confirm action.

### 8.6 Oscillation thrash (revert-ratchet)

If a competing automated actor re-applies a deviation each cycle, the comparator fires `drift`→`revert`→`in_sync`→`drift` repeatedly, thrashing state and generating audit noise that obscures real drifts. Detection signal: the same invariant cycling drift→action→drift across ≥3 runs. **Recovery**: an oscillation guard — N≥3 consecutive drift-after-action cycles auto-escalate with the run-count in `drift_detail`; the named action becomes "diagnose the competing actor," not another `revert`.

### 8.7 Partial impact-rank at degenerate entities

If `impact_rank` is computed on an incomplete topology (your project's Postgres-only graph misses n8n consumers), it under-ranks impact and presents a false-low as authoritative. Detection signal: an `impact_rank` with no `rank_completeness` flag at an entity with a known-degenerate dimension. **Recovery**: A6/A10 — `impact_rank` carries `rank_completeness: partial` + the missing dimensions; a consumer must not treat a partial rank as authoritative.

### 8.8 Recovery procedures (per failure mode)

| Failure | Detection signal | Recovery |
|---------|------------------|----------|
| 8.1 Theatre-of-trust (false drift) | `drift` where freshness should gate | Field-scoped freshness precondition → `inconclusive` (P4/6.7) |
| 8.2 Silent-perpetual-inconclusive | `inconclusive` past cadence, no alert | Split transient/broken; broken fires `topology-stale` (A7) |
| 8.3 Silent state mutation | state change, no `action_outcome` row | Confirm-gate + audit row on mutating actions (P5/A9) |
| 8.4 Vacuous-green-light | `in_sync` with empty/no-op registry | Liveness gate → `no-invariants-registered` (A8) |
| 8.5 Source-orphan vacuous green | `in_sync` on a `manual`-node invariant | `unverifiable_spot` verdict (P6/A10) |
| 8.6 Oscillation thrash | drift→action→drift × ≥3 | Oscillation guard → auto-escalate with run-count |
| 8.7 Partial impact-rank | rank with no completeness flag | `rank_completeness: partial` + missing dims (A6/A10) |

The recovery column is the operational payload — an M3 mechanism implements each row as an automated remediation or a structured operator prompt.

## 9. Anti-patterns

### 9.1 Assert-without-compute
Naming an invariant as a gate or check (a "reproducibility check", a "config matches") without ever computing its verdict against two real views. The Gate-3 Hermes failure (Section 13) is this anti-pattern's canonical case. Right: every named invariant computes a real verdict (P1) or it does not exist.

### 9.2 Pure-alert (no named action)
Surfacing drift with no action attached — the OSS-tool default the destination Condition 3 forbids. Right: every `drift` carries one of the four named actions (P3).

### 9.3 Auto-mutate-without-gate
Letting `revert`/`reconcile` execute automatically with no confirmation or audit. Right: mutating actions confirm-gate + audit (P5).

### 9.4 Drift-on-stale (false positive)
Emitting `drift` when topology is staler than the intent fields read. Right: stale input → `inconclusive` (P4).

### 9.5 In-sync-over-nothing (vacuous green)
Returning `in_sync` when the registry is empty, a view is empty, or a node is a `manual` orphan. Right: `no-invariants-registered` / `inconclusive` / `unverifiable_spot` respectively (P1/P4/P6).

### 9.6 Authors-or-generates-internally
The comparator running an emitter or authoring an intent record inside `compute()`. Right: `compute()` takes already-emitted views only (P2/6.3) — the boundary that keeps reconciliation a separate mechanism.

### 9.7 Reconciliation-states-intent overreach
Recording, inside a verdict, what the system *should* do (an authored claim). That is intent (Doctrine 04). Right: the verdict states whether two views agree; the "should" lives in the intent record being compared.

### 9.8 Record-level freshness gating
Forcing every invariant in a record to `inconclusive` because any field of the record changed (the system-wide-blackout trap). Right: scope freshness to the specific fields the invariant reads (A6/6.7).

### 9.9 Escalate-everything
A selector that routes nearly all drift to `escalate` (because the tracked/untracked split and the authorship-unknown rule are not implemented), making the four-action vocabulary a one-action mechanism in disguise. Right: the tracked-deliberate carve-out (A4) and the worked low-consequence `revert`/`reconcile` examples (Appendix A) keep the lower-tier actions live.

### 9.10 Wall-clock freshness
Comparing topology generation wall-clock against intent commit-time, which a clock-skewed CI system corrupts. Right: git commit-time on both sides (A11/6.7).

## 10. AI-operator implications

### 10.1 The verdict as the AI session's drift-check
An autonomous session, before acting on an area, calls `verdict()` over the relevant invariants and learns the open drifts — ranked, source-traceable, with named actions — without manual diffing. The named action tells it what closing the drift requires.

### 10.2 The confirm-gate as the AI's safety handle
An AI session that receives a `revert`/`reconcile` named action does NOT execute it silently — it issues a structured confirm call (Condition 3) and the execution writes an audit row. This is what lets an autonomous session act on a drift without the silent-state-mutation risk (8.3).

### 10.3 `inconclusive` and `unverifiable_*` as the AI's honesty handles
An AI session reads `inconclusive: stale-input-transient` as "wait for the next topology run," `stale-input-broken` as "the generator is down — do not trust any verdict here," and `unverifiable_spot` as "this node has no generator; confirm it manually." The mechanism tells the session when it cannot be trusted, rather than guessing.

### 10.4 AI-specific failure modes reconciliation must guard against
- **Acting on a false-positive drift**: an AI that auto-executes `revert` on a stale-input false alarm. Guard: P4 — stale input is `inconclusive`, never `drift`, so no action is proposed.
- **Trusting a vacuous green**: an AI that reads `in_sync` and assumes verification when the registry was empty. Guard: P1/A8 — `no-invariants-registered` is a distinct verdict the AI must not read as healthy.
- **Silently mutating on a mis-classified action**: an AI that auto-reverts a deliberate-but-untracked change. Guard: A4 — that case routes to `approve_as_intentional`, not `revert`; and P5 gates the mutation regardless.

## 11. Application checklist — what the M3 companion mechanism operationalises

The selector as a **flat, ordered decision-list** (A11 — the M3-implementable form; the §6.5 grid is the reasoning form). Evaluate top-down; first match wins (this is what closes the two-rows-fit-no-tiebreak case):

```
0. PRECONDITION (P4/6.7): if right_view topology commit-time < last-change commit-time of the
   left_view fields this invariant reads → verdict = inconclusive
       (within cadence window → stale-input-transient; beyond → stale-input-broken + topology-stale alert). HALT.
0a. LIVENESS (P1/6.8): if registry empty or all-no-op → no-invariants-registered. HALT.
0b. UNVERIFIABLE (P6): if right_view includes a `manual` source-orphan node → unverifiable_spot. HALT.
    if the whole dimension is degenerate at this entity → unverifiable_dimension. HALT.
0c. EMPTY VIEWS: left_view empty because wired_to=pending → inconclusive. HALT.
    right_view empty because the surface exists but no intent claims it → drift (unintended surface).
1. COMPUTE the assertion over left_view vs right_view (P1). If it holds → in_sync. HALT.
2. (drift) If authoritative side UNKNOWN from available data → escalate (reason: authorship_ambiguous). HALT. (A3)
3. If consequence HIGH (impact_rank > threshold OR security control OR irreversible) AND NOT deliberate-and-tracked
       → escalate. HALT.
4. If actual drifted and intent still right → revert (confirm-gated, P5). HALT.
5. If intent stale and change deliberate-and-tracked → reconcile (with warning if high-consequence, A4; confirm-gated). HALT.
6. If intent stale and change deliberate-but-untracked → approve_as_intentional + retroactive entry. HALT.
7. ELSE (fits none) → escalate (catch-all). HALT.
POST-ACTION (A9): a revert/reconcile sets pending_verification; re-evaluate next run;
    a second drift within one cadence after an action → escalate (oscillation, 8.6).
```

The M3 mechanism implements steps 0-7 as an ordered guard chain, writes the `verdict_record`, and (for confirmed mutating actions) the `action_outcome` audit row.

## 12. Test D defence — separability of Conservation-Law Verification from Intent and Topology

Mandatory per programme spec §2. Three limbs: schema (Test D proper), falsification-condition (F2), operational-separability (the council's A1) — plus the update-cadence argument (A2) folded into the operational limb.

### 12.1 Schema limb — the Jaccard result (re-run on the amended 17-field schema, A11)

Reconciliation's output schema (Section 6.1) has **17 fields** after the council amendments (the v1 sketch's 15 + `action_outcome` (A9) + the `rank_completeness` sub-field promoted into `impact_rank`'s payload (A10); the verdict/reason-code expansions are enum values, not new field names). Pairwise field-name overlap:

| Pair | Shared fields | Jaccard | < 50%? |
|------|---------------|---------|--------|
| Reconciliation ∩ Intent | id, kind, source_file, source_commit, timestamp (5) | 5 / (17+13−5) = 5/25 = **20.0%** | yes |
| Reconciliation ∩ Topology | id, kind, source_file, source_commit, timestamp (5) | 5 / (17+10−5) = 5/22 = **22.7%** | yes |

The only shared fields are the 5-field provenance envelope. Reconciliation's 12 payload fields (`left_view`, `right_view`, `assertion`, `verdict`, `drift_detail`, `impact_rank`, `affected_nodes`, `named_action`, `action_outcome`, `cadence`, `source_of_truth_ref` — and the structured sub-payloads) appear in no other mechanism's schema. **The amendments moved the pairs FURTHER apart** (from 21.7%→20.0% and 25.0%→22.7%): the new fields are reconciliation-only payload, which grows the union without touching the intersection. Separability is strengthened, not threatened, by the council's hardening.

**F1 consolidation robustness**: the most aggressive honest consolidation — treating `left_view`/`right_view`/`affected_nodes` as one shared "edges" concept comparable to intent's `wired_to` and topology's `depends_on` — raises the intersection to at most 6: Reconciliation∩Intent 6/25 = 24.0%, Reconciliation∩Topology 6/22 = 27.3%. No consolidation crosses 50%. Stripping the trivial envelope (`id`/`kind`/`timestamp`) LOWERS overlap, strengthening separability.

**F4 citation discipline**: separability is defended on the internal grounds below — schema divergence + the compare-and-propose-an-action payload + the update-cadence asymmetry — NOT on industry precedent. The M1 research found NO organisation maps these three dimensions as separate (every OSS reconciliation tool is pure-ALERT; Stripe separates intent from reconciliation but has no topology dimension; double-entry bookkeeping balances two sources but has no separate intent-capture mechanism). Double-entry is cited as the conservation-CLASS pattern only (6.4.3); accounting's ledger/transaction/audit structure is NOT cited as a precedent for the three-way mechanism split — that would be exactly the F4 violation the contract forbids.

### 12.2 Falsification-condition limb (F2)

> **Conservation-Law Verification's separateness from its siblings fails if `compute()` ever authors an intent record or runs a topology emitter internally** — at that point the comparator is not consuming two finished views but re-implementing one of its siblings, the operational boundary collapses, and the three mechanisms converge toward one bundled pipeline. The typed read API (6.3) is the controlled boundary: `compute()` takes view *data*, never a producer *function*, so the breach is structurally prevented and visible at the type level rather than possible silently.

**Test D re-run trigger (A5)**: any M3 change that adds/renames a field in any of the three schemas triggers a mandatory Test D re-run, appended here as a dated row. Test D is a living invariant. The 2026-05-22 council amendments themselves triggered the re-run recorded in 12.1 (15→17 fields; both pairs dropped further below 50%).

### 12.3 Operational-separability limb (the council's A1)

**(a) Input/output contracts:**

| Direction | Contract |
|-----------|----------|
| Reconciliation **reads** from Intent | a `left_view` — duck-typed (6.2): any structured intent-side record carrying the provenance envelope. Typically intent's `wired_to` + `conditions`. |
| Reconciliation **reads** from Topology | a `right_view` — duck-typed: any structured actual-side record carrying the provenance envelope. Typically a topology `subgraph`. |
| Reconciliation **emits** for Intent | nothing automatically. A `reconcile` action *proposes* an intent amendment, but the amendment is executed in Doctrine 04's jurisdiction under a confirm-gate (P5) — reconciliation does not author it. |
| Reconciliation **emits** for Topology | nothing. Reconciliation never writes the graph. |

Reconciliation reads BOTH siblings; NEITHER sibling reads reconciliation (Doctrine 04's intent is authored independently of any verdict; Doctrine 05's topology derives from source independently of any verdict). This **one-directional read dependency** is the separation signature: a *bundled* design would have the mechanisms mutually feed (Backstage's single hand-authored YAML). A one-way read is composition.

**(b) Independent-invocability check (mechanical):** "Invoking Reconciliation" = given two ALREADY-EMITTED views (data, carrying the provenance envelope), define an invariant and COMPUTE its verdict (6.3). This operation does **not** require authoring any intent record and does **not** require running any topology emitter. The duck-typed interface (6.2) means it can be invoked on ANY two conforming views, not only Doctrine 04's and 05's specific outputs — which is what distinguishes a separate mechanism from the final stage of a hardwired ETL pipeline. **Falsifier**: if, at M3, `compute()` cannot run without internally calling a topology emitter or an intent author, this limb fails and the doctrine count reverts. The typed API signature (6.3) makes this falsifier checkable at Gate 2 (the signature takes views, not producers), not deferred to M3.

**(c) The update-cadence argument (A2 — the additional internal-grounds limb):** the three mechanisms have three distinct update cadences, which is independent evidence they are three things, not three views of one:
- **Intent** updates on a deliberate human/agent commitment (rare, intentional — a destination is authored, an ADR is written).
- **Topology** updates on a source-of-truth change (frequent, automated — a migration lands, a workflow JSON changes; topology's freshness IS its source derivation, so it cannot update on any other trigger).
- **Reconciliation** updates when EITHER view changes AND can additionally run **on-demand** (an operator or AI asks "is this kept right now?") — a cadence neither sibling has. Topology structurally cannot run "on demand against a hypothetical intent" because its content is fixed by source; intent cannot run "on demand against a hypothetical actual" because it is authored, not computed. Only the comparator has a verb ("check now") that the other two lack.

Three cadences, three triggers, three update verbs. A bundled mechanism would have one update cadence (Backstage's YAML updates when someone edits the YAML). The cadence asymmetry is structural evidence of separation, alongside the schema divergence (12.1) and the consume-don't-produce boundary (12.3b).

**(d) Worked compound-drift example (composition, not bundling):** the RLS-drop event from Doctrine 04 (A.1 / 12.3c) and Doctrine 05 (A.1 / 12.3c), traced from reconciliation's seat:

1. **Intent** holds the promise (authed users access own billing) with `wired_to` naming the RLS policy node. Reconciliation reads this as `left_view` — it does not author it.
2. **Topology** regenerates after the migration that dropped the RLS policy: the policy node is absent from the new graph. Reconciliation reads this subgraph as `right_view` — it does not generate it.
3. **Reconciliation** runs the freshness precondition (topology regenerated after the intent's relevant fields last changed → passes, P4), computes the conservation assertion (intent expects the RLS node; topology subgraph lacks it → fails), emits `verdict: drift`, `drift_detail: { reason_class: unilateral_drift }`, walks topology's `depended_on_by` for `impact_rank` (the billing surface), and — because the affected node is a security control (high consequence per 6.6) and the drop was unintended — selects `named_action: escalate`. A security control was silently dropped; it goes to human review under a confirm-gate.

Reconciliation did exactly its own job — compute a verdict from two consumed views and propose an action — without authoring intent or generating topology. It composed with the other two; it did not bundle. A bundled mechanism would have had reconciliation *generate the topology itself* or *author the intent itself*, collapsing three mechanisms into one. The separation is what lets the comparator stay a pure two-view function with a typed boundary.

### 12.4 Test D defence verdict

Conservation-Law Verification is separable on all limbs: schema (20.0-22.7% on the amended 17-field set, robust to consolidation, and the amendments moved it FURTHER apart), falsification-condition (the consume-don't-produce boundary made concrete via the typed `compute()` signature), operational (reads-both-emits-to-neither one-directional dependency + a mechanical duck-typed invocability check + the three-cadence asymmetry + a worked compound-drift event resolved by composition). **Separability: EARNED.**

## 13. Real-decision test appendix (Gate 3)

**Pre-nominated case (council A2, sourced from history): the 2026-05-14 eight-agent Hermes build-vs-buy council** — documented verbatim in `.claude/skills/_shared/framing-audit-suite-handoff.md` (lines 14-16) and the re-run record `council/2026-05-18-hermes-rerun-acceptance-test.md`. This is the Hermes failure that birthed the framing-audit suite; it is NOT a reconstruction from memory (the orchestrator verified the documented pattern before authoring).

**Actual outcome (locked before applying the doctrine)**: the agency ran a 3-phase competitor evaluation of Hermes Agent. All eight council agents converged unanimously: BUILD NATIVE. The Phase-2 "reproducibility check" gate — whose first-principles intent was *"test whether the competitor's claims hold up when run in our environment"* — had silently become a build-cost estimate: a theoretical native-build cost compared against a theoretical Hermes-integration cost. Estimate vs estimate, zero hands-on data. The council shipped the wrong verdict; the framing-audit suite was built afterward to prevent recurrence (the 2026-05-18 re-run confirmed the suite now catches it at Phase 2).

**Doctrine applied**: the "reproducibility check" gate was, in this doctrine's terms, **an asserted invariant that was never computed** (Anti-pattern 9.1). It named a conservation-class check — "the reproduced result matches the claimed result" — but never emitted a verdict against two real views, because no actual reproduction run existed. Specifically: the `left_view` would be the intent (the claimed Hermes capability / the reproducibility condition); the `right_view` would be the actual result of running the reproduction in the agency's environment. The `right_view` was **absent** — no reproduction was run.

**Counterfactual recommendation**: with Doctrine 06 in place, the reproducibility gate cannot be a rhetorical flourish. It is a versioning/conservation invariant whose `compute()` requires two present views. The freshness/empty-view precondition (P4/6.7, step 0c) fires: `right_view` is empty (no reproduction result exists to compare against) → `verdict: inconclusive` (right view absent), NOT `in_sync`. An `inconclusive` gate **cannot lock a verdict** — the doctrine forbids treating "we asserted reproducibility" as "reproducibility holds." The council would have been blocked from using the reproducibility gate as a verdict-anchor until an actual reproduction run produced a `right_view`. The estimate-vs-estimate comparison would have been exposed as resting on an uncomputed invariant before the BUILD-NATIVE verdict locked.

**Verdict**: PASS (recommendation differs — the gate returns `inconclusive: right-view-absent` and cannot lock, vs the actual "asserted and shipped" — AND is better-grounded: it cites the specific empty-view precondition that converts a theatre invariant into a blocking honest non-verdict, the exact mechanism the framing-audit suite was later built to provide). Confidence: the case was council-nominated (second party) and is documented, approaching STRONG-PASS; full STRONG-PASS deferred pending an independent confirmation that the `inconclusive`-blocks-lock path would have changed the council's behaviour in the live 2026-05-14 run rather than only in hindsight.

## 14. Deletion test appendix (Gate 1)

**Named downstream consumers**:

1. **The M3 reconciliation mechanism builder** (next milestone). Without this doctrine, the M3 builder re-derives: the invariant record schema (6.1), the duck-typed view interface + typed read API (6.2-6.3), the three invariant classes (6.4), the four-action selector + its 2-axis grid + the flat ordered decision-list (6.5/11), the action-execution gate + audit (6.6), the field-scoped freshness precondition (6.7), and the liveness gate (6.8). Every one is a non-trivial design decision the doctrine settles.
2. **The companion reconciliation skill** (M3+). The Section-11 ordered decision-list is the skill's procedure; the anti-anchoring guard (`diagnostic-skill-anti-anchoring.md`) applies because "is this drift real / which action?" can take an operator-supplied hypothesis.
3. **Doctrines 04 and 05 as contract-providers**. Doctrine 04's `wired_to`/`conditions` (the `left_view` source) and Doctrine 05's `subgraph` (the `right_view` source — contracted in 05 §12.3a + Appendix E) have **no consumer without Doctrine 06**. The two sibling contracts are written specifically for this mechanism to consume; deleting 06 leaves them dangling.

**Re-invention specifics** (what each consumer would rebuild from scratch without this doctrine):

- The compute-don't-produce boundary (P2) and its typed-API enforcement (6.3) — without it, M3 would likely build reconciliation as the final stage of a hardwired pipeline coupled to 04/05's exact schemas (the join-layer collapse the council flagged CRITICAL), losing separability silently.
- The four-action selector + its falsification condition (6.5) — without it, M3 would build a pure-ALERT mechanism (the OSS default, forbidden by destination Condition 3) or invent an ad-hoc action vocabulary with no tiebreak rule.
- The field-scoped freshness precondition (6.7) — without it, M3 would build either no freshness guard (false-positive drift → theatre-of-trust) or a record-level guard (system-wide-blackout trap).
- The verdict taxonomy (P1/P4/P6 — `inconclusive` transient/broken, `unverifiable_spot`, `no-invariants-registered`, `pending_verification`) — without it, M3 would conflate "timing-stale," "structurally-unverifiable," and "nothing-registered" under a single `inconclusive` or, worse, under `in_sync` (the vacuous-green-light family).

**Verdict**: PASS. Three named consumers, two of which (the M3 builder + the companion skill) re-invent the full mechanism, and one of which (doctrines 04/05 as contract-providers) has dangling contracts without 06; the four re-invention specifics above are each a multi-decision design problem the doctrine settles once.

## 15. References

### 15.1 Primary sources (conservation-law / reconciliation patterns)
- GitOps reconciliation loop (Flux/Argo desired-vs-live) — the desired-state-vs-actual-state comparison pattern (cited for the versioning class, not the three-way split)
- Atlas schema drift detection — https://atlasgo.io/ (the repo-vs-live database drift pattern, the derivation/conservation class)
- dbt source freshness — https://docs.getdbt.com/docs/build/sources (the derivation-class staleness pattern)
- Double-entry bookkeeping — the balance-across-two-sources pattern (the conservation class ONLY; explicitly NOT a precedent for the three-way mechanism split, per F4)
- Soda / Great Expectations / Datafold — the pure-ALERT reconciliation tools the M1 research found (cited as what this doctrine goes BEYOND via named actions, not as a template)

### 15.2 Counter-evidence (cited honestly, per F4)
- Every OSS reconciliation tool is pure-ALERT (no named action) — cited as the gap this doctrine's four-action vocabulary fills; the vocabulary is therefore workshop-original, defended on internal grounds.
- Stripe Ledger separates intent from reconciliation but has NO topology dimension — cited as honest counter-evidence: no organisation maps all three the way this destination does (the M1 falsifier finding).
- Spotify Backstage BUNDLES intent + topology in one hand-authored YAML — cited as the bundled design this doctrine's one-directional-read + duck-typed boundary explicitly rejects.

### 15.3 Related workshop artefacts
- `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`, `DESTINATION.md` v2, `specs/research/architecture-blueprint-research-2026-05-22.md`
- `specs/13_M2_DOCTRINE_PLAN.md` (Phase 1 Test D dry-run), `specs/13_M2_DOCTRINE_06_PLAN.md` v2 (this doctrine's plan + the 11 council amendments)
- `council/sessions/2026-05-22-m2-doctrine-authoring-plan.md`, `council/sessions/2026-05-22-doctrine-06-plan-review.md` (the extended council that produced A1-A11)
- `.claude/skills/_shared/framing-audit-suite-handoff.md` + `council/2026-05-18-hermes-rerun-acceptance-test.md` (the Gate-3 real-decision case — the documented 2026-05-14 Hermes failure)
- `loading-state-invariants.md` (the disabled-RLS / deploy-drift incidents the conservation + versioning classes catch)
- `verify-shipped` skill (the deploy-vs-source drift class — the versioning-class signal)
- `docs/operational-doctrine/04_intent-capture.md` (the `left_view` source), `05_topology-from-source.md` (the `right_view` source)
- `docs/operational-doctrine/02_systems-thinking.md` (the quality + length + structure template this doctrine mirrors)
- `.claude/rules/doctrine-verification-gate.md` (the triple gate), `.claude/rules/diagnostic-skill-anti-anchoring.md` (the M3 companion skill's guard), `.claude/rules/operational-guardrails.md` (the confirm-before-destructive precedent for P5)

## Status Footer

- **Doctrine**: 06 — Conservation-Law Verification
- **Status**: authored 2026-05-22 (M2); triple gate — Gate 1 (deletion) PASS, Gate 3 (real-decision) PASS, Gate 2 (code-council) pending this session
- **Test D**: separability EARNED (schema 20.0-22.7% on the amended 17-field set — moved further apart by the council hardening; falsification-condition via the typed `compute()` boundary; operational limb with one-directional read + mechanical duck-typed invocability + the three-cadence asymmetry + a worked compound-drift example)
- **Council**: plan reviewed by extended council 2026-05-22 (`council/sessions/2026-05-22-doctrine-06-plan-review.md`) — GO + 11 amendments (A1-A11) all folded in
- **schema-review-required: before-M3-ships** (A2/Test D re-run trigger)
- **Cross-doctrine consistency**: re-run the `doctrine-verification-gate.md` consistency check across doctrines 04/05/06 before any propagation event (M2 close-out step 2)
- **Companion mechanism**: not yet built (M3) — build order + handoff notes in Appendix E
- **Invariant-class catalogue**: Appendix C (the M3 reference); **degeneracy matrix**: Appendix D (per-entity expected coverage)
- **Sibling doctrines**: 04 (intent, the `left_view` source), 05 (topology, the `right_view` source)
- **Test D re-run log**: (2026-05-22 — initial computation on 15-field sketch: Intent∩Recon 21.7%, Topology∩Recon 25.0%; 2026-05-22 — re-run on amended 17-field set after council A1-A11: Intent∩Recon 20.0%, Topology∩Recon 22.7%, both < 50%, separability strengthened; **2026-06-07 — M6 added `left_source` (17→18 fields): Reconciliation∩Intent = 5/(18+14−5) = 5/27 = 18.5%, Reconciliation∩Topology = 5/(18+10−5) = 5/23 = 21.7%, both < 50%, separability strengthened further — per `council/sessions/2026-06-07-m6-intent-capture-plan-v2-execution-soundness.md` A2/D7**; append a dated row on any schema field add/rename)

---

## Appendix A — Worked examples

Thirteen worked examples. Template: **situation → verdict + action → detection signal → what the doctrine says → what goes wrong without it → composition trace**.

### A.1 The dropped RLS policy (conservation class, escalate)

**Situation**: intent promises authed users access only their own billing, `wired_to` an RLS policy node; a migration drops the policy. **Verdict + action**: conservation invariant — intent expects the RLS node, topology subgraph lacks it → `drift`, `reason_class: unilateral_drift`; the affected node is a security control (high consequence, 6.6) and the drop was unintended → `named_action: escalate`. **Detection signal**: a conservation assertion failing where `affected_nodes` is an `rls_policy`. **What the doctrine says** (6.4.3): a missing promised security control escalates. **Without it**: the dropped policy is invisible until a data leak; intent and topology each "did their job" but nothing compared them. **Composition trace**: intent supplies `left_view`, topology supplies `right_view`, reconciliation supplies the verdict + escalate — the canonical three-mechanism compound-drift resolution (12.3d).

### A.2 The deploy that lags source (versioning class, reconcile)

**Situation**: an edge function's `deployed_commit` is older than its repo `source_commit` (the Cedar Hurst class, Doctrine 05 A.15). **Verdict + action**: versioning invariant — `source_commit == deployed_commit` fails → `drift`; actual (the deploy) drifted, intent (ship the reviewed code) still right, low consequence → `named_action: revert`-style redeploy, framed as `reconcile` (bring deployed to match source). Confirm-gated (P5). **Detection signal**: `source_commit ≠ deployed_commit` on an edge-function node. **What the doctrine says** (6.4.1, 7.3): deploy-drift is a first-class versioning invariant. **Without it**: the deployed-vs-source drift is the silent killer `verify-shipped` exists to catch — invisible until behaviour diverges from the reviewed code. **Composition trace**: topology supplies both provenances (repo + deployed); reconciliation computes the versioning verdict + the redeploy action.

### A.3 The deliberate, tracked, consequential refactor (the tracked/untracked carve-out, A4)

**Situation**: a team refactors the billing edge function — deliberate, tracked in a roadmap entry, affecting 12 downstream consumers (high `impact_rank`). Intent still points to the old function. **Verdict + action**: `drift`; intent stale, change deliberate-AND-tracked, high consequence → step 5 of the decision-list → `reconcile` **with warning** (NOT escalate, per A4). Confirm-gated. **Detection signal**: a high-fan-in drift whose `source_of_truth_ref` resolves to an existing roadmap/ADR entry. **What the doctrine says** (6.5/A4): a correct, tracked, deliberate improvement is not blocked behind council review just because it is consequential. **Without it**: the escalate-override would queue a good change for review (friction tax → operators work around the mechanism, 9.9). **Composition trace**: intent's `wired_to` (old function) vs topology's actual (new function); the roadmap-entry presence routes to reconcile-with-warning.

### A.4 The unauthorised column (authorship-ambiguous → escalate, A3)

**Situation**: a column appears in topology with no intent record referencing it. **Verdict + action**: `drift`; the mechanism cannot tell from its own data whether the column was added unauthorised (→ revert) or added deliberately with intent not yet written (→ reconcile/approve) — axis A is UNKNOWN → step 2 → `named_action: escalate`, reason `authorship_ambiguous`. **Detection signal**: a topology node with no matching intent `wired_to`, no authorship signal. **What the doctrine says** (A3): authorship-unknown escalates regardless of consequence — never coin-flips between revert and reconcile. **Without it**: the 2-axis grid case (b) (two rows fit, no tiebreak) is unhandled; the mechanism either guesses wrong (auto-reverts a legitimate column, or reconciles an unauthorised one) or stalls. **Composition trace**: the absence of an intent `left_view` for the column is itself the signal; reconciliation escalates rather than fabricating an authoritative side.

### A.5 The stale-input false alarm prevented (the freshness precondition, P4 / the 13th example, A11)

**Situation**: intent's `wired_to` was amended at commit T2 to add a new RLS policy; topology last regenerated at T1 < T2, before the policy was added. A naive comparison would see "intent expects a policy topology doesn't have" → false `drift`. **Verdict + action**: the freshness precondition (6.7) fires — topology's commit-time (T1) < the last-change commit-time of the `wired_to` field this invariant reads (T2) → `verdict: inconclusive`, reason `stale-input-transient` (within cadence window). NO action; HALT. **Detection signal**: a would-be drift where topology predates the relevant intent change. **What the doctrine says** (P4/8.1): a stale comparison is `inconclusive`, never `drift` — the single most important guard against theatre-of-trust. **Without it**: the false `drift` trains the operator to ignore verdicts; once trust breaks they bypass the mechanism (the destination's highest-consequence failure). **Composition trace**: reconciliation waits for topology to regenerate against T2; on the next run topology includes the new policy and the verdict resolves honestly to `in_sync` or a real `drift`.

### A.6 The disabled-but-present security control (conservation class, attribute-level, escalate)

**Situation**: an RLS policy exists in topology but its `attributes.enabled` is `false` (disabled, not dropped — Doctrine 05 A.11). **Verdict + action**: conservation invariant — intent promises enforced own-billing access; topology shows the policy present but `enabled: false` → `drift`, `reason_class: unilateral_drift`; security control silently inert → `named_action: escalate`. **Detection signal**: an `rls_policy` node present but `attributes.enabled == false` against an intent promising enforcement. **What the doctrine says** (6.4.3): presence ≠ effectiveness; the conservation assertion reads the attribute, not just node existence. **Without it**: a verdict that only checks node presence shows the policy as present and implies protection that is disabled — a dangerous false `in_sync`. **Composition trace**: topology's attribute-level derivation (05 A.11) supplies the `enabled` flag; reconciliation asserts against it and escalates the inert control.

### A.7 The empty registry at first deploy (liveness gate, A8)

**Situation**: the mechanism is installed at a new entity; no invariants registered yet. **Verdict + action**: `verdict: no-invariants-registered` (LOUD, distinct); `in_sync` is PROHIBITED. **Detection signal**: `registry_health()` returns `live_invariant_count == 0`. **What the doctrine says** (6.8/A8): the mechanism is not live until ≥1 versioning + ≥1 derivation invariant with non-empty views are registered. **Without it**: an empty registry returns `in_sync` (vacuous green-light, 8.4) — the operator believes all promises are kept when nothing has been checked (destination Element 4 scenario 2). **Composition trace**: until intent records and topology subgraphs exist to register invariants over, reconciliation honestly reports it has nothing to verify.

### A.8 The mis-fired auto-revert prevented (action gate + audit, P5 / A9)

**Situation**: a developer deploys a deliberate breaking migration, then intends to author the intent update next. The comparator runs in the window between deploy and intent-update. **Verdict + action**: it sees actual-drifted, intent-still-old → would select `revert`. But P5 confirm-gates: `revert` does NOT auto-execute; it surfaces for confirmation. The operator sees "revert the migration you just deployed?" and declines, authoring the intent update instead. **Detection signal**: a `revert` proposed on a node whose `source_commit` is newer than the intent it is compared against (a recent deliberate change). **What the doctrine says** (P5/6.6/A9): mutating actions confirm-gate by default + write an audit row. **Without it**: the auto-revert silently undoes the deliberate migration; the operator sees the system regressed with no trail (8.3). **Composition trace**: the confirm-gate is the safety boundary between reconciliation's *proposal* and the actual state mutation in topology's domain.

### A.9 The source-orphan that can't be continuously verified (unverifiable_spot, P6 / A10)

**Situation**: an invariant compares against an infra node that is a `manual` source-orphan (Doctrine 05 §6.6, an unmonitored DigitalOcean droplet). It was `in_sync` on first registration; six weeks later the droplet is reconfigured but no generator catches it. **Verdict + action**: `verdict: unverifiable_spot` (NOT `in_sync`); named action = manually confirm the node's state + update topology, then re-run. **Detection signal**: an invariant whose `affected_nodes` include a node with `emitter: "manual"`. **What the doctrine says** (P6/A10): the mechanism never asserts a promise is kept over a node it cannot continuously re-derive. **Without it**: the stale `in_sync` is a vacuous green-light over a node that re-drifted weeks ago (8.5). **Composition trace**: topology's `emitter: "manual"` marker (05 §6.6) tells reconciliation this node has no generator, so it returns `unverifiable_spot` rather than a continuous-verification verdict.

### A.10 The oscillating drift (revert-ratchet guard, 8.6)

**Situation**: an n8n workflow auto-patches a config each run; the comparator detects drift, the operator reverts, the next run the workflow re-patches, drift again. **Verdict + action**: on the third drift→revert→drift cycle, the oscillation guard fires → `named_action: escalate` with the run-count in `drift_detail`; the action becomes "diagnose the competing actor," not another `revert`. **Detection signal**: the same invariant cycling drift→action→drift across ≥3 runs (visible via `action_outcome` history + `pending_verification` re-evaluation). **What the doctrine says** (8.6/A9): repeated revert is treating the symptom; the cause is a competing automated actor. **Without it**: the revert-ratchet thrashes state and floods the audit log, drowning real drifts (theatre-of-trust by noise). **Composition trace**: the `action_outcome` + `pending_verification` machinery (6.6) supplies the run-history that makes oscillation detectable.

### A.11 The repo migration never applied (live-vs-repo, derivation class, reconcile)

**Situation**: a migration file exists in the repo declaring an index, but it was never applied to the live database (Doctrine 05 A.16, A6). **Verdict + action**: derivation invariant — the repo source declares an object the live-derived topology lacks → `drift`, `reason_class: unilateral_drift`; intent (apply the migration) still right, actual (live DB) drifted, low consequence → `named_action: reconcile` (apply it). Confirm-gated. **Detection signal**: a repo migration declares an object absent from the live-derived graph. **What the doctrine says** (6.4.2): topology reports the LIVE source-of-truth (A6); the repo-vs-live gap is a derivation invariant. **Without it**: the operator trusts the migration file, assumes the index exists, queries stay slow, the unapplied migration is invisible. **Composition trace**: topology's live graph is the `right_view`; the repo migration set is the `left_view`-side source-of-truth; reconciliation flags the unapplied migration with an apply action.

### A.12 The cross-entity propagation, degenerate dimension (unverifiable_dimension, A10)

**Situation**: the mechanism propagates to your project — Postgres-only topology (no n8n, no TS, automation in Make.com). An operator registers a conservation invariant over an automation surface. **Verdict + action**: the n8n topology dimension is degenerate at this entity → `verdict: unverifiable_dimension` for that invariant; the Postgres-surface invariants run normally. **Detection signal**: an invariant whose `right_view` dimension has no emitter coverage at this entity (Doctrine 05 Appendix D degeneracy matrix). **What the doctrine says** (P6/A10/6.4): reconciliation scopes its invariants to the covered surface and flags the uncovered surface as `unverifiable_dimension` — never asserts `in_sync` over a dark dimension. **Without it**: the operator believes the automation surface is verified when no emitter covers it (vacuous green at propagation). **Composition trace**: topology's coverage declaration (05 P6/Appendix D) tells reconciliation which surfaces are dark; reconciliation marks invariants over them `unverifiable_dimension`.

### A.13 The empty left_view (wired_to: pending) vs empty right_view (unintended surface)

**Situation**: two distinct empty-view cases. (i) An intent record has `wired_to: pending` (explicitly aspirational, no implementation yet). (ii) A topology subgraph exists for a surface that no intent record claims. **Verdict + action**: (i) `left_view` empty by design → `verdict: inconclusive` (nothing to compare — the intent acknowledged the gap); NOT `in_sync` (would assert the empty state is desired) and NOT `drift` (nothing to revert toward). (ii) `right_view` is a real surface with no intent → `verdict: drift` (an unintended, unclaimed surface) → `escalate` or `approve_as_intentional` per the selector. **Detection signal**: (i) `wired_to == "pending"`; (ii) a topology subgraph with no matching intent claim. **What the doctrine says** (step 0c, P4): the three empty-view cases get three different verdicts — never collapsed into a single `in_sync`. **Without it**: case (i) returns a false `in_sync` (vacuous green over an acknowledged gap) and case (ii) is silently ignored (an unclaimed surface no one verifies). **Composition trace**: intent's `wired_to: pending` (04's explicit-aspiration marker) tells reconciliation to return `inconclusive` for (i); the absence of any intent `left_view` for (ii) makes the unclaimed surface a `drift`.

## Appendix B — Quick-reference operator card

| You observe | It means | Doctrine action |
|-------------|----------|-----------------|
| A named gate/check with no computed verdict | Theatre invariant (9.1) | Compute a real verdict against two views, or it does not exist |
| `drift` while topology predates the relevant intent change | False positive (8.1) | Should be `inconclusive` — apply the freshness precondition (6.7) |
| `inconclusive` persisting past the cadence window | Dark mechanism (8.2) | Split transient/broken; broken fires `topology-stale` (A7) |
| A state change with no `action_outcome` audit row | Silent mutation (8.3) | Confirm-gate + audit mutating actions (P5/A9) |
| `in_sync` with `live_invariant_count == 0` | Vacuous green (8.4) | `no-invariants-registered`; never `in_sync` over empty registry (A8) |
| `in_sync` on an invariant touching a `manual` node | Source-orphan vacuous green (8.5) | `unverifiable_spot`; manually confirm + update (P6/A10) |
| Same invariant cycling drift→action→drift ×3 | Oscillation thrash (8.6) | Auto-escalate with run-count; diagnose the competing actor |
| `impact_rank` with no completeness flag at a degenerate entity | Partial under-ranking (8.7) | `rank_completeness: partial` + missing dims (A6/A10) |
| A `drift` with no `named_action` | Pure-alert (9.2) | Attach one of the four actions (P3/6.5) |
| Authoritative side unknown, two actions both plausible | Selector case (b) (6.5) | `escalate` reason `authorship_ambiguous` (A3) |
| A high-consequence drift on a tracked deliberate change | Friction-tax risk (9.9) | `reconcile` with warning, NOT escalate (A4) |
| Topology wall-clock compared to intent commit-time | Skew-vulnerable (9.10) | git commit-time on both sides (A11/6.7) |

## Appendix C — The invariant-class catalogue (M3 reference)

The invariant classes the M3 mechanism implements, each with worked invariant instances (≥4 per class so the M3 builder does not re-derive):

### Versioning class (is the recorded promise still the live one?)
| Invariant | `left_view` | `right_view` | Assertion | Typical drift action |
|-----------|-------------|--------------|-----------|----------------------|
| Deploy matches reviewed commit | intent: reviewed `source_commit` | topology edge-function `deployed_commit` | `source_commit == deployed_commit` | reconcile (redeploy) |
| Intent supersession is current | intent: non-superseded record | topology: the live object | the live object matches the current (not superseded) intent | escalate if a superseded promise is live |
| Workflow version active | intent: the intended active workflow | topology workflow node `active` attribute | the intended workflow `active == true` | reconcile / escalate |
| Schema version applied | intent: target migration version | topology: live schema version | live version ≥ target | reconcile (apply migration) |

### Derivation class (does the generated topology trace to source?)
| Invariant | `left_view` | `right_view` | Assertion | Typical drift action |
|-----------|-------------|--------------|-----------|----------------------|
| Every node has resolvable provenance | source artefact set | topology node `source_file`/`source_commit` | every node traces to a present source | escalate (source-orphan masquerade) |
| Materialized view fresher than base | base table `source_commit` | view `last_refresh` attribute | `last_refresh ≥ base source_commit` | reconcile (refresh) |
| Repo migration applied to live | repo migration set | live-derived topology | every repo-declared object exists live | reconcile (apply) |
| No dangling edges | topology node set | topology edge targets | every `depends_on` target node exists | escalate (latent error, A.13/05) |

### Conservation class (do two views of state agree?)
| Invariant | `left_view` | `right_view` | Assertion | Typical drift action |
|-----------|-------------|--------------|-----------|----------------------|
| Promised RLS policy wired + enabled | intent `wired_to` (RLS) | topology rls_policy node + `enabled` attribute | policy present AND `enabled == true` | escalate (security) |
| Promised feature has implementation | intent `wired_to` | topology subgraph | every `wired_to` target exists | reconcile / escalate |
| Count conservation | intent: expected count | topology: actual count | counts match | reconcile / escalate |
| No unclaimed surface | intent corpus | topology surface | every topology surface has an intent claim | approve_as_intentional / escalate (A.13) |

## Appendix D — Degeneracy matrix across the canonical entities

Reconciliation coverage depends on BOTH siblings' coverage at each entity (it compares their outputs). The matrix is the M3/M4 expectation — what "complete coverage" means at each entity, so a degenerate dimension is expected and declared (P6), never mistaken for verified:

| Entity | Intent coverage | Topology coverage | Reconciliation reach | Expected `unverifiable_dimension` |
|--------|-----------------|-------------------|----------------------|-----------------------------------|
| my-project | rich (destinations, ADRs) | rich (pg + n8n + TS + Vercel) | full — all three classes over all surfaces | none |
| your project | rich | rich (KI pipeline) | full | possibly Vercel surface |
| your project | Markdown-only intent | Postgres-only topology | conservation + derivation over the Postgres surface only | n8n, TS, Vercel surfaces — automation invariants `unverifiable_dimension` |

At your project, reconciliation over the Postgres surface is the *correct* output, declared as such; invariants over the (absent) automation surface return `unverifiable_dimension`, not `in_sync`. The matrix prevents the vacuous-green-light at propagation: an operator at your project sees "reconciliation: Postgres-surface only (automation surface unverifiable — no topology emitter coverage)" and knows that is expected, not broken.

## Appendix E — M3 handoff notes

For the M3 session that builds the reconciliation mechanism from this doctrine:

- **Build order** (from the principle-interaction analysis): the compute-from-two-consumed-views core (P1+P2) first — the typed `compute()` taking views-not-producers (6.3) is the contract; build it before anything so the separability boundary is enforced from line one. Then the freshness precondition (P4/6.7), then the action selector (P3/6.5 as the ordered decision-list in §11), then the action gate + audit (P5/6.6), then the unverifiable markers (P6).
- **The duck-typed view interface (6.2) is the contract** — build `compute()` to accept ANY two provenance-carrying views, not 04's/05's specific schemas. This is what keeps reconciliation a separate mechanism rather than the final stage of a hardwired pipeline (Section 12.3). The typed signature taking views-not-producers is the structural enforcement.
- **`schema-review-required: before-M3-ships`**: the first M3 step is to re-read this doctrine and confirm the 17-field invariant record (6.1) + the verdict taxonomy match what the implementation will expose. Flag any field the implementation will not produce — that flag triggers a Test D re-run (12.2).
- **The freshness precondition is field-scoped, not record-scoped** (A6/6.7) — the record must carry a per-field change-commit map so a wording-only intent edit does not blackout every invariant. Use git commit-time on both sides (A11), never wall-clock.
- **State-mutating actions (`revert`/`reconcile`) are confirm-gated + audited by default** (P5/6.6) — build the confirm-gate and the `action_outcome` audit row before any auto-execution path; auto-execution is an explicit low-impact opt-in, not the default. The runner needs its own heartbeat (a failed runner returns nothing, which must not read as `in_sync`).
- **The liveness gate (6.8) is mechanism-enforced, not installation discipline** — `compute()` refuses to emit `in_sync` over an empty/no-op registry; surface `no-invariants-registered` on every run until ≥1 versioning + ≥1 derivation invariant with non-empty views is registered.
- **`impact_rank` consumes topology's `depended_on_by`** (A6, the A.17 trace contracted in 05) — carry `rank_completeness: partial` when the topology graph is incomplete at the entity, so a partial fan-in count is never presented as authoritative.
