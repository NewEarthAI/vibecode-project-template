# Intent Capture as Mechanism — Operational Doctrine

> **Doctrine 04 of the operational-doctrine set.** Companion doctrines: `05_topology-from-source.md` (the actual graph), `06_conservation-law-verification.md` (the cross-system invariants). This doctrine is the first of the three Intent-Actual-Gap mechanisms (programme spec `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`; success contract `DESTINATION.md` v2).
>
> **Authored**: 2026-05-22 (M2, Intent-Actual-Gap Mechanism Build Programme). **Verification**: triple gate (`doctrine-verification-gate.md`) — see Sections 13-14. **Separability**: defended in Section 12 (Test D).
> **schema-review-required: before-M3-ships** — the machine-readable schema described in Section 6 + Section 12 is a pre-M3 design commitment; before M3 ships the intent-capture mechanism, re-read this doctrine and flag any field the implementation will not expose.

---

## 1. Purpose

Intent Capture is the mechanism that records **what a system is supposed to do or be**, in a carrier that is simultaneously machine-addressable, human-readable, and partial-readable, such that the recorded intent can be compared against the system's actual behaviour at any time without the comparing party having to reconstruct the intent from prose.

The doctrine governs the *intent* half of the intended-vs-actual gap. It does not measure the gap (that is reconciliation, Doctrine 06) and it does not derive the actual state (that is topology, Doctrine 05). It governs the artefacts that say *what was promised*: destinations, Architecture Decision Records (ADRs — short notes recording why a significant design choice was made), roadmap intent, and machine-readable contracts. Its single job is to make a promise legible enough that a machine or a human can later ask "is this still true?" and get a traceable answer.

The doctrine exists because intent, in most software projects, is scattered across prose documents, commit messages, chat logs, and the heads of the people who built the system. Scattered intent cannot be compared against actual state. The gap between intended and actual behaviour stays invisible not because no one wrote the intent down, but because what they wrote down is not addressable — you cannot point a machine at "the thing we said we wanted" and get a structured answer.

## 2. Why this doctrine earned its slot

Three of the workshop's existing doctrines (Theory of Constraints, Systems Thinking, Decision Quality) govern *reasoning about* systems. None of them governs the *artefact that records what a system is supposed to do*. The Intent-Actual-Gap programme requires that artefact to be a first-class, separately-maintained mechanism — the M1 research (`specs/research/architecture-blueprint-research-2026-05-22.md`) found that the leading industry intent-capture patterns (ADRs, RFCs, OpenAPI, the workshop's own DESTINATION.md) all share one property: intent is *authored*, never derived. That single property is what distinguishes this doctrine's mechanism from the other two and is the load-bearing reason it earns a separate slot rather than being folded into topology.

The deletion test (Section 14) confirms the slot: removing this doctrine forces the M3 intent-capture mechanism builder and the companion skill author to re-derive, from scratch, what an intent record's machine-readable shape is, what the difference between authored and derived intent is, and how an intent record links to the implementation that fulfils it. None of those questions is answered by Doctrine 05 or 06.

## 3. Scope boundary — what this doctrine does NOT do

Intent Capture governs the recording and addressing of intent. It explicitly delegates the following:

### 3.1 Deriving the actual dependency graph (→ Doctrine 05, Topology-from-Source)

Intent Capture records what the system is *supposed* to depend on, where the author chose to state it. It does NOT generate the actual dependency graph from source. When an intent record says "the billing UI depends on the billing edge function," that is an authored claim — the *verification* that the dependency actually exists in the deployed system is topology's job (Doctrine 05) and the *comparison* of claim against actual is reconciliation's job (Doctrine 06).

### 3.2 Measuring or surfacing the gap (→ Doctrine 06, Conservation-Law Verification)

Intent Capture provides one of the two views a reconciliation invariant compares (the `left_view` — see Section 12, the cross-mechanism contract). It does NOT itself assert that the intent and the actual agree or disagree. An intent record is inert with respect to drift — it is the reference, not the comparator.

### 3.3 Project management / task tracking

Roadmap *intent* (what a roadmap item promises) is in scope; roadmap *scheduling* (when, who, sprint mechanics) is not. The doctrine governs the promise, not the project plan that delivers it.

### 3.4 Prose documentation and knowledge management

A README, an architecture essay, or a runbook is documentation, not intent capture, unless it carries a machine-addressable record of a promise with a defined success condition. The line: if a future machine cannot ask "is this still true?" against it and get a structured answer, it is documentation, and this doctrine does not govern it.

### 3.5 Requirements elicitation / product discovery

How intent is *formed* (user research, stakeholder interviews, the `define-destination` authoring flow) is upstream of this doctrine. Intent Capture governs intent once it exists and needs to be recorded addressably.

## 4. Governing principles

Each principle is paired with a falsification condition — the observation that would prove the principle wrong in a given case.

### Principle 1: Intent is authored, never derived

An intent record is written by a human or an agent making a deliberate commitment. It is never computed from the system's actual state. This is the boundary that separates intent from topology: topology is generated from source; intent is authored input. The two never share an authoring act.

**Falsification**: if an intent record's content can be fully reconstructed by running a generator over source artefacts (with no human/agent commitment added), it is not intent — it is topology mislabelled. The generator-not-author boundary has been crossed in the wrong direction.

### Principle 2: Every intent record carries no derived fields

A consequence of Principle 1, sharp enough to be its own rule. An intent record's fields are all authored. A derived value (e.g. "what percentage of this intent's `wired_to` links currently resolve to live topology nodes") is NOT a field of the intent record — it belongs in a separate computed layer. Mixing a derived field into an authored record collapses the generator-not-author boundary at the field level and makes the record's provenance ambiguous.

**Falsification**: if an intent record contains a field whose value changes without any author touching the record (because a generator recomputed it), the principle is violated for that field, and the record's separability from topology has degraded.

### Principle 3: Every intent record is wire-able to its implementation

An intent record carries a `wired_to` field linking it to the implementation artefacts claimed to fulfil it. The link is authored (the author asserts "this destination condition is fulfilled by this edge function"). The *verification* that the link still holds is reconciliation's job — but the link itself must exist, or the intent is unfalsifiable and the gap is unmeasurable.

**Falsification**: if an intent record states a condition but carries no `wired_to` link to any implementation, the gap for that condition cannot be measured — the intent is a wish, not a verifiable promise. (Exception: intent that is deliberately aspirational/not-yet-wired is valid, but must carry an explicit `wired_to: pending` marker, not an absent field.)

### Principle 4: Intent is addressable at three resolutions — machine, human, partial

The same intent record must be readable by a machine (structured query returns a field), by a human (the prose conditions are legible), and partially (a session asks for the slice relevant to its task, not the whole intent corpus). A carrier that serves only one resolution fails the destination's Condition 1 (answers on demand) or Condition 6 (AI operators first-class).

**Falsification** (anchored to the §6.8 read API, not a restatement): P4 is falsified if `slice(topic, fields)` cannot return a named field without a human parsing prose (machine resolution fails), OR if `read(id)` returns a record whose `conditions` are not legible to a non-technical operator (human resolution fails). The test is mechanical: run the two operations and check each returns its resolution without the other being required.

### Principle 5: Intent supersession is an explicit, traversable chain — never an implicit overwrite

When intent changes, the old record is not overwritten; it is marked `superseded_by` the new record. The chain is traversable to a single terminal (live) record. A query for "current intent" walks the chain to the terminal node deterministically. This prevents an agent from anchoring on a stale, superseded promise.

**Falsification**: if a query for current intent can return a superseded record (because the chain has no terminal, or two records claim to be terminal, or the traversal is ambiguous), the principle is violated — and the theatre-of-trust failure (Section 8.3) becomes live.

### Principle 6: Intent status is a closed enum, not free text

An intent record's lifecycle is a closed set of states (`draft`, `accepted`, `superseded`, `fulfilled`) with defined transitions. A machine reading the status must never have to parse natural language to learn whether a promise is live. Free-text status defeats machine-addressability.

**Falsification**: if a status value outside the closed enum appears (or if "fulfilled" is asserted without a reconciliation verdict backing it), the status field has degraded to prose and Principle 4's machine resolution fails.

### Principle interaction — how the six compose

The principles are not independent rules; they form a dependency chain an M3 builder must implement together, not piecemeal:

- **P1 (authored-not-derived) is the root.** Everything else depends on it. P2 (no derived fields) is P1 applied at the field level. Violate P1 and the whole authored/derived boundary — the basis of Test D separability (Section 12) — collapses.
- **P3 (wire-able) makes intent *falsifiable*; P6 (closed-enum status) makes it *machine-legible*.** Together they are what let reconciliation consume intent: P3 supplies the `wired_to` join input, P6 supplies an unambiguous `status` the comparator can branch on. An intent record satisfying P1+P2 but not P3 is authored and clean but useless to reconciliation (no join handle).
- **P4 (three-resolution addressability) is orthogonal to the others** — it governs *how* a record is read, not *what* it contains. But it depends on P6: partial-readability of a `status` field is meaningless if the status is free text.
- **P5 (supersession chain) is the temporal dimension.** It is what makes P1-P4 hold *over time* as intent changes. Without P5, an authored, wired, legible record still rots — the next amendment overwrites it and the audit trail is gone.

The practical consequence for M3: implement P1 first (it is the boundary the mechanism polices), then P3+P6 (the reconciliation contract), then P5 (versioning), then P4 (the read API). An implementation that does P4 (a nice query interface) before P1 (the authored boundary) builds a fast way to read records whose provenance is already ambiguous.

## 5. Assumptions

- **A1**: The project has a single source-of-truth repository (Git) where intent artefacts live alongside (but distinct from) the code they describe. Intent stored outside version control (a wiki, a chat) is out of this doctrine's reach.
- **A2**: Intent authors (human or agent) are willing to record a falsifiable success condition, not just a description. A promise with no test is documentation, not intent (Section 3.4).
- **A3**: The implementation artefacts an intent record wires to are themselves addressable (a file path, a commit, a topology node id) — i.e. Doctrine 05's topology mechanism exists or will exist to resolve `wired_to` targets.
- **A4**: The volume of intent records per project is bounded enough that supersession chains stay short (tens, not thousands, of records per bounded context). If intent volume explodes, the partial-readability principle (P4) requires an index, which is a mechanism extension, not a doctrine change.

## 6. Mechanisms

### 6.1 The intent record — machine-readable carrier

The atomic unit is the **intent record**, a structured object with these authored fields:

```
id                  # stable identity of the intent record
kind                # destination | adr | roadmap_item | contract
source_file         # the .md / .yaml carrying the intent
source_commit       # commit that introduced or last changed it
timestamp           # authored / last-amended time
title               # human label
status              # draft | accepted | superseded | fulfilled (closed enum, P6)
superseded_by       # id of the record that replaces this (P5); null if terminal
conditions          # the falsifiable end-state conditions (the intent payload)
binary_test         # the third-party-observable success test
wired_to            # links to implementation artefacts claimed to fulfil this (P3); or "pending"
owner               # accountable party
acceptance_cadence  # how often the intent is re-confirmed against reality
```

The first five fields (`id`, `kind`, `source_file`, `source_commit`, `timestamp`) are the **provenance envelope** shared with the other two mechanisms (Doctrines 05, 06). The remaining eight are the intent payload — the authored-promise fields that distinguish this mechanism (see Section 12, the Test D defence, for why this distinction is load-bearing).

### 6.2 The carrier formats

Intent records are not invented from scratch — they are a thin machine-readable layer over the M1-validated authoring patterns:

- **Destinations** (`DESTINATION.md`): a project-level intent record. `kind: destination`. The falsifiable end-state conditions ARE the `conditions` field; the binary success test IS the `binary_test` field. Authored by the `define-destination` skill.
- **ADRs** (`docs/adr/NNNN-*.md`): one architecturally-significant decision per record. `kind: adr`. The Decision section is the `conditions`; the Status header is the `status`; supersession links are `superseded_by`.
- **Roadmap intent** (`ROADMAP.md` items): `kind: roadmap_item`. The "Done When" column is the `binary_test`.
- **Contracts** (OpenAPI / JSON Schema): `kind: contract`. Machine-readable by construction; the schema IS the `conditions`.

The mechanism does not replace these formats — it indexes them into the common intent-record shape so a machine can query across all four kinds uniformly.

### 6.3 The `wired_to` link (the implementation bridge)

`wired_to` is the field that makes intent falsifiable. It links an intent record to the implementation artefacts (topology node ids, file paths, edge-function names) claimed to fulfil it. The link is authored — the author asserts the fulfilment claim. The link is the input to reconciliation: Doctrine 06's invariant takes `wired_to` as its `left_view` (the intended wiring) and resolves the named targets against Doctrine 05's topology graph as its `right_view` (the actual wiring). When the two disagree, reconciliation surfaces the drift. See Section 12 for the full cross-mechanism contract.

### 6.4 The supersession chain (intent versioning)

Intent change is modelled as a linked list, not an overwrite. Record A `superseded_by` B `superseded_by` C, where C's `superseded_by` is null, makes C the live intent. The **traversal contract** (Principle 5): a query for "current intent on topic X" filters to records matching X, then walks each candidate's `superseded_by` to its terminal, and returns the terminal record. If two candidates resolve to different non-null terminals on the same topic, that is a versioning conflict the mechanism must surface — never silently pick one.

### 6.5 The acceptance cadence (intent freshness)

`acceptance_cadence` records how often the intent should be re-confirmed against reality — distinct from reconciliation's check cadence (which is how often the *gap* is measured). Intent freshness is about the promise going stale (the world changed and the promise no longer reflects what we want); reconciliation cadence is about the *implementation* drifting from a still-valid promise. The two cadences are independent — a core reason intent and reconciliation are separate mechanisms (Section 12).

The independence is sharp and worth stating concretely. A destination condition can be perfectly *fresh* (the world has not changed; we still want exactly this) while its implementation has *drifted* badly (someone dropped the wiring). Conversely a condition can be perfectly *in-sync* (implementation matches the promise) while the promise itself has gone *stale* (we no longer want this; the market moved). The first case is reconciliation's domain; the second is intent freshness's domain. A mechanism that bundled the two cadences would be forced to re-check fresh-but-unchanged promises on the reconciliation cadence (wasteful) or let drift accumulate on the slow intent-freshness cadence (dangerous). Keeping them separate lets each run at its natural rate.

### 6.6 The computed layer — where derived values live (the Principle-2 escape valve)

Principle 2 forbids derived fields inside an intent record. But derived values about intent are genuinely useful — "what percentage of this destination's `wired_to` links currently resolve?", "how many days since this ADR was last re-confirmed?". These live in a **computed layer** keyed to the intent record's `id`, never inside the record. The computed layer is regenerated by a generator (it is derived, by definition); the intent record stays authored-only. A query that wants the derived value joins the computed layer to the intent record by `id` at read time. This keeps the authored/derived boundary clean at the field level while still serving the operator the derived view. The computed layer is NOT part of this doctrine's schema (Section 6.1) — it is a downstream consumer artefact, and its provenance envelope marks it `emitter`-stamped (derived), distinguishing it from the authored record.

### 6.7 The intent index — partial-readability at scale (Assumption A4's mechanism)

When intent volume grows past a few dozen records per bounded context, the partial-readability principle (P4) needs an index: a lightweight map from topic → terminal intent record id, regenerated on each intent change. A session asking about one topic hits the index, gets the terminal id, and reads exactly that record — never scanning the whole corpus. The index is itself a derived artefact (it lives in the computed layer, 6.6) — building it does not violate Principle 1 because it derives *over* authored records without altering them. Without the index, partial-readability degrades to a full-corpus scan at scale, and the corpus-dump anti-pattern (9.6) becomes the default.

### 6.8 The three-resolution query interface (the read API)

Principle 4 requires intent to be readable at three resolutions. The query interface exposes exactly three operations, and no more — keeping the surface small (a deep module, in Ousterhout's sense):

- **`get(topic) → terminal record`** (machine resolution): filter to the topic, walk supersession to the single terminal, return the structured record. Used by reconciliation and by AI sessions. Deterministic; surfaces a conflict (6.4) rather than guessing if two terminals exist.
- **`read(id) → human view`** (human resolution): return the record's prose `conditions` + `binary_test` in a legible form a non-technical operator can paste into a message. The same record, rendered for human consumption.
- **`slice(topic, fields) → partial`** (partial resolution): return only the named fields of the topic's terminal — e.g. `slice("billing", ["wired_to", "conditions"])` returns just the join inputs reconciliation needs, not the whole record. This is the operation that keeps an AI session's context bounded.

The interface is intentionally narrow: three reads, no writes (writes happen by authoring an artefact + re-indexing, never through the query API). A narrow read interface over a rich authored corpus is what makes intent a *deep* module — small surface, much behind it — and is what lets the other two mechanisms consume intent through a stable contract (Section 12.3) without coupling to its internals.

## 7. Leverage points — where this doctrine pays rent

### 7.1 The canonical cross-mechanism join (the highest-leverage point)

The single most valuable thing this doctrine defines is the contracted input it provides to reconciliation. Reconciliation's `left_view` IS an intent record's `wired_to` field (plus its `conditions`). This is not an incidental cross-reference — it is the primary consumer path for intent. By contracting it here (Section 12.3), the doctrine prevents the M3 mechanisms from improvising the join on every drift event (the bundling-in-disguise failure the council flagged). Intent emits; reconciliation consumes; the contract is fixed.

### 7.2 Projects where intent is currently scattered across prose

The doctrine pays the most rent where intent exists but is unaddressable — a project with a rich README, many design docs, and chat history, but no machine path to "is this promise still true?". Indexing that scattered intent into the common record shape converts invisible gaps into measurable ones.

### 7.3 Multi-author, multi-session projects where intent drifts silently

When many sessions (human + AI) touch a project, intent gets re-decided implicitly. The supersession chain (6.4) makes every intent change explicit and traversable, so a fresh session never anchors on a stale promise.

### 7.4 AI-operator-first projects (the destination's Condition 6)

The partial-readability principle (P4) is highest-leverage for AI operators: an `/autovibe` session asks for the intent slice relevant to its task, not the whole corpus, and acts on a structured answer without re-reading prose.

## 8. Failure modes — where this doctrine produces wrong results

### 8.1 Intent-as-documentation (the scope-creep failure)

If the doctrine is applied to prose that has no falsifiable success condition, it produces intent records that cannot be reconciled (no `binary_test`, no `wired_to`). The result is a corpus that looks like intent but cannot measure any gap. Detection signal: an intent record whose `binary_test` is empty or whose `wired_to` is permanently absent (not `pending`).

### 8.2 Derived-field contamination

If an intent record acquires a derived field (Principle 2 violation) — typically because a builder found it convenient to cache a computed value in the record — the record's provenance becomes ambiguous and Test D's separability from topology degrades. Detection signal: a field whose value changes without an author commit.

### 8.3 Theatre-of-trust via stale-intent anchoring

If the supersession chain is broken (no terminal, or ambiguous terminal), a query for current intent can return a superseded record. An agent acts on a promise that was already retracted. This is the destination's Element-4 "theatre-of-trust" scenario made concrete at the intent layer. Detection signal: two records on one topic both with `superseded_by: null`.

### 8.4 Dimension-degenerate silent emptiness

At an entity where intent lives entirely in a non-machine-readable store (e.g. Make.com scenario configuration, per the M1 Nirvana edge case), the intent mechanism returns an empty or unparseable corpus while the logs say "running." This is the vacuous-green-light failure. **Guard (per A5)**: the mechanism declares its minimum-viable source (at least one machine-readable intent artefact — a DESTINATION.md or an ADR directory) and, when the source is degenerate, declares-and-logs "intent dimension degenerate: no machine-readable carrier at this entity" rather than returning empty silently.

### 8.5 Fulfilled-without-verification

If `status: fulfilled` is set by an author without a reconciliation verdict backing it (Principle 6 violation), the intent claims completion that was never verified against actual state. Detection signal: a `fulfilled` record whose `wired_to` targets do not resolve in the current topology. **Recovery**: revert the status to `accepted`; require a reconciliation verdict before `fulfilled` can be re-asserted; this is the one status transition intent cannot make unilaterally.

### 8.6 Recovery procedures (per failure mode)

Each failure mode above has a defined recovery, so an operator (or M3 mechanism) is never left to improvise:

| Failure | Detection signal | Recovery |
|---------|------------------|----------|
| 8.1 Intent-as-documentation | `binary_test` empty OR `wired_to` permanently absent | Either add a falsifiable test + wiring, or reclassify the artefact as documentation (out of scope, Section 3.4) |
| 8.2 Derived-field contamination | Field value changes with `source_commit` unchanged | Move the value to the computed layer (6.6); reject the field from the record |
| 8.3 Stale-intent anchoring | Two terminals on one topic, OR a query returns a `superseded` record | Repair the supersession chain; surface the conflict; never return a non-terminal |
| 8.4 Dimension-degenerate silent emptiness | A known intent surface is unindexed but logs say "running" | Declare-and-log the degenerate dimension; scope downstream consumers to covered surface |
| 8.5 Fulfilled-without-verification | `fulfilled` status, `wired_to` unresolved | Revert to `accepted`; require a reconciliation verdict |

The recovery column is the operational payload — an M3 mechanism implements each row as an automated remediation or a structured operator prompt.

## 9. Anti-patterns

### 9.1 Overwrite-on-change

Editing an intent record in place when the promise changes, instead of creating a superseded successor. Destroys the audit trail and breaks the traversal contract. Right: always `superseded_by`.

### 9.2 Free-text status

Writing status as prose ("mostly done, pending review") instead of the closed enum. Defeats machine-addressability. Right: closed enum + a separate notes field if prose is needed.

### 9.3 Wishful wiring

Setting `wired_to` to an implementation that does not exist yet, without the `pending` marker — so reconciliation reports drift on a promise that was never meant to be live yet. Right: `wired_to: pending` for aspirational intent.

### 9.4 Intent-topology field bleed

Adding a derived field (a topology fact) into an intent record because it is convenient. Right: derived values live in a computed layer keyed to the intent id, never inside the record.

### 9.5 Orphan intent

An intent record with no `wired_to` and no `pending` marker — a promise with no path to verification. Right: every accepted intent either wires to an implementation or is explicitly marked pending.

### 9.6 Corpus-dump on query

Returning the whole intent corpus when a session asked about one topic, defeating partial-readability. Right: filter to the topic + walk supersession to the terminal, return the slice.

### 9.7 Intent-as-binding-spec overreach

Treating an intent record as a rigid specification the implementation must match field-for-field, rather than a promise whose fulfilment reconciliation evaluates. Intent states *what* must be true (the `conditions` + `binary_test`), not *how* the implementation achieves it. An intent record that dictates implementation detail has crossed into topology's territory (it is describing the actual graph, not the promise). Right: intent states the observable end-state; the implementation is free to satisfy it any way; reconciliation checks the end-state, not the method.

### 9.8 Silent acceptance-cadence lapse

Letting `acceptance_cadence` elapse with no re-confirmation and no flag, so a stale promise (6.5) sits `accepted` and `in_sync` forever while nobody asks whether it is still wanted. Right: an overdue acceptance-cadence is itself a surfaced signal (operator card, Appendix B) prompting the owner to re-confirm or supersede — staleness is made visible, not left to rot.

## 10. AI-operator implications

### 10.1 Intent as the AI session's contract

An autonomous session (e.g. `/autovibe`) reads intent records to learn what the project promised before acting. The structured `conditions` + `binary_test` give the session a machine-checkable goal without re-reading prose. The supersession traversal guarantees it acts on the live promise, not a retracted one.

### 10.2 The `wired_to` field as the AI's verification handle

When an AI session needs to know whether its change kept a promise, it reads the intent record's `wired_to`, hands it to reconciliation (Doctrine 06) as the `left_view`, and gets a verdict. The AI never re-derives the architecture — it consumes the contracted output.

### 10.3 Partial-readability prevents context blow-up

An AI session asks for the intent slice relevant to its task. Without partial-readability, every session would load the whole intent corpus into context — the re-discovery cost the destination's Condition 6 forbids.

### 10.4 AI-specific failure modes intent must guard against

Autonomous sessions fail in ways human readers do not, and the doctrine's principles are partly shaped to prevent them:

- **Stale-intent anchoring under compaction**: an AI session whose context was compacted may hold a *summary* of intent rather than the live record. If it acts on the summary, it can act on a superseded promise. Guard: P5 + 6.8's `get(topic)` always re-resolves to the terminal from source — the session must re-query, never trust a remembered summary. (This mirrors the workshop's compaction-aware-state discipline in `agentic-loop-guards.md`.)
- **Confident wrong-status reads**: an AI reading a free-text status ("mostly done") may parse it as `fulfilled` and skip work that is incomplete. Guard: P6's closed enum removes the parse ambiguity — `fulfilled` means a reconciliation verdict backed it, nothing softer.
- **Fabricated fulfilment**: an AI asked "is X done?" may infer `fulfilled` from the presence of code rather than from a verdict. Guard: 8.5 — `fulfilled` requires a reconciliation verdict; the AI must consume the contracted `left_view`/`right_view` join (12.3), not eyeball the codebase.
- **Whole-corpus context blow-up**: an AI without `slice()` loads all intent and exhausts its context before doing the task. Guard: 6.8's `slice(topic, fields)` returns only the join inputs needed.

These four guards are why the intent mechanism is built for AI operators as first-class consumers (destination Condition 6), not retrofitted for them.

## 11. Application checklist — what the M3 companion mechanism operationalises

The M3 intent-capture mechanism (a skill/substrate, not yet built) implements this checklist mechanically:

1. **Index**: scan the repo for the four intent kinds (destinations, ADRs, roadmap items, contracts); emit one intent record per artefact in the Section-6.1 shape.
2. **Resolve provenance**: populate the shared envelope (`id`, `kind`, `source_file`, `source_commit`, `timestamp`) from git.
3. **Extract payload**: parse the authored fields (`conditions`, `binary_test`, `wired_to`, `status`, `owner`, `acceptance_cadence`) from the artefact.
4. **Validate authored-only** (Principle 2): reject any field whose value would require a generator to compute. Flag derived-field contamination.
5. **Build the supersession index** (6.4): link records via `superseded_by`; verify each topic resolves to exactly one terminal; surface conflicts.
6. **Validate wiring** (Principle 3): every `accepted` record has a `wired_to` (resolved or `pending`); flag orphans (9.5).
7. **Answer queries** (P4): given a topic, return the terminal record's slice (machine fields + human conditions), never the whole corpus.
8. **Emit for reconciliation** (Section 12.3): expose `wired_to` + `conditions` as the contracted `left_view` for Doctrine 06.
9. **Degenerate-case guard** (8.4): if no machine-readable intent carrier exists at the entity, declare-and-log; never return empty silently.

## 12. Test D defence — separability of Intent Capture from Topology and Reconciliation

This section is mandatory for every Intent-Actual-Gap doctrine (programme spec §2). It defends, on internal grounds, that Intent Capture is a structurally separate mechanism from Topology-from-Source and Conservation-Law Verification — not a view of the same thing. The defence has three limbs: the schema limb (Test D proper), the falsification-condition limb (F2), and the operational-separability limb (the council's A1).

### 12.1 Schema limb — the Jaccard result

Intent Capture's machine-readable output schema (Section 6.1) has 13 fields. Pairwise field-name overlap with the sibling mechanisms (computed in `specs/13_M2_DOCTRINE_PLAN.md` Phase 1):

| Pair | Shared fields | Jaccard | < 50%? |
|------|---------------|---------|--------|
| Intent ∩ Topology | id, kind, source_file, source_commit, timestamp (5) | 5 / 18 = **27.8%** | yes |
| Intent ∩ Reconciliation | id, kind, source_file, source_commit, timestamp (5) | 5 / 23 = **21.7%** | yes |

The only shared fields are the 5-field provenance envelope every source-derived artefact carries. The 8 intent-payload fields (`title`, `status`, `superseded_by`, `conditions`, `binary_test`, `wired_to`, `owner`, `acceptance_cadence`) appear in no other mechanism's schema.

**F1 consolidation robustness check**: even folding the most-mergeable payload fields (treating `wired_to` as an "edge" field comparable to topology's `depends_on`), the Intent∩Topology intersection rises to at most 6, giving 6/18 = 33.3% — still well under 50%. No consolidation of the intent schema pushes any pair across the threshold.

**F4 citation discipline**: this separability is defended on the internal schema-divergence ground above, NOT on industry precedent. The M1 research found NO organisation maps these three dimensions as separate (Spotify's Backstage bundles intent + topology in `catalog-info.yaml`). Backstage is cited here as honest *counter*-evidence: it bundles precisely because it hand-authors both intent and topology in one YAML. The workshop separates them because topology is generated (Doctrine 05) while intent is authored (Principle 1) — see the falsification limb.

### 12.2 Falsification-condition limb (F2)

Intent Capture's separateness from Topology rests on the generator-not-author boundary (Principle 1). This is *conditional, not structural* — and stating the condition is what makes it falsifiable:

> **Intent Capture's separateness from Topology-from-Source fails if any intent record acquires a derived field, OR if topology nodes become hand-authored.** At either point the authored/derived boundary collapses, the schemas converge toward Backstage's bundled `catalog-info.yaml`, and Test D must be re-run. The doctrine's separability claim is valid only while the boundary holds.

**Test D re-run trigger (A5)**: any M3 implementation change that adds or renames a field in any of the three mechanism schemas triggers a mandatory Test D re-run. The result is appended to this section as a dated row. Test D is a living invariant, not a 2026-05-22 snapshot.

### 12.3 Operational-separability limb (the council's A1 — the load-bearing argument)

Schema separability is necessary but not sufficient (DESTINATION.md Element 4 scenario 5). Two mechanisms can have low field-name overlap yet be operationally one thing. This limb proves Intent Capture is *operationally* separate via three concrete artefacts.

**(a) Input/output contracts.** Intent Capture's cross-mechanism data flow is fully contracted, never improvised:

| Direction | Contract |
|-----------|----------|
| Intent **emits** for Reconciliation | `wired_to` (the intended implementation links) + `conditions` (the promise) → consumed by Doctrine 06 as its `left_view`. |
| Intent **emits** for Topology | nothing. Intent does not feed topology — topology is derived from source independently of any intent record. (This asymmetry is itself evidence of separation: a bundled mechanism would have intent and topology feeding each other.) |
| Intent **reads** from Topology | only at query time, to *resolve* a `wired_to` target into a live node — and this resolution is OPTIONAL. An intent record is valid and queryable with `wired_to` holding an unresolved reference; resolving it is reconciliation's job, not intent's. |
| Intent **reads** from Reconciliation | nothing at authoring time. (An intent record's `status: fulfilled` is *informed by* a reconciliation verdict, but the verdict is recorded by the author as a deliberate status transition — Principle 6 — not pulled live.) |

**(b) Independent-invocability check (mechanical, falsifiable).** "Invoking Intent Capture" = run the Section-11 index over the repo's intent artefacts and return intent records. This operation reads ONLY intent artefacts (destinations, ADRs, roadmap items, contracts) and git provenance. It does **not** require running the topology emitter and does **not** require running any reconciliation invariant. **Falsifier**: if, at M3, indexing intent records cannot complete without first generating the topology graph or running a reconciliation check, this limb has failed and the doctrine count reverts (Intent collapses into whichever mechanism it cannot run without).

**(c) Worked compound-drift example (composition, not bundling).** Consider the drift event: *a destination promises "authenticated users can access their own billing history"; a migration drops the row-level-security policy enforcing it; the billing UI still deploys.* Trace:

1. **Intent Capture** holds the destination record: `conditions` = "authed users access own billing"; `wired_to` = [the RLS policy node, the billing edge function, the billing UI route]; `status: accepted`. Intent's job is done at authoring — it recorded the promise and the claimed wiring. It does NOT detect the drift.
2. **Topology-from-Source** (Doctrine 05) regenerates from source and correctly shows the RLS policy node is gone.
3. **Conservation-Law Verification** (Doctrine 06) fires the invariant: `left_view` = Intent's `wired_to` (expects the RLS node); `right_view` = Topology's current subgraph (RLS node absent). Verdict: `drift`. `named_action: escalate` (a security-relevant promise is unwired).

Each mechanism did exactly its own job. The event was *resolved by composition* — reconciliation joined intent's output and topology's output via the contracted `left_view`/`right_view` path (12.3a). At no point did one mechanism do another's work. This is composition. **Bundling** would have been: a single artefact that records the promise AND derives the topology AND emits the verdict — which is exactly what the three separate mechanisms avoid. The operator asking "is my billing intent fulfilled?" issues one query to reconciliation, which transparently consumes the other two's contracted outputs — the operator does not perform an ad-hoc three-way read.

### 12.4 Test D defence verdict

Intent Capture is separable from Topology and Reconciliation on all three limbs: schema (21.7-27.8% overlap, robust to consolidation), falsification-condition (the generator-not-author boundary, with a stated re-run trigger), and operational (contracted I/O, a mechanical independent-invocability check, and a worked compound-drift event resolved by composition). **Separability: EARNED.**

## 13. Real-decision test appendix (Gate 3)

**Pre-nominated case (per council A2, sourced from history, not self-selected): the original "architecture blueprint" framing of this very programme**, rejected by `/reduce-to-first-principles` on 2026-05-22.

**Actual outcome (locked before applying the doctrine)**: the programme was initially framed as authoring a "master architecture blueprint" document. The framing audit reduced it and renamed the programme to the "Intent-Actual-Gap Mechanism," flagging "blueprint" as a smuggled representation-conclusion. The reframing happened via the framing-audit primitive.

**Doctrine applied**: run the Intent Capture doctrine against the "master blueprint" proposal. The doctrine asks: is this an intent record? It has no `binary_test` (a blueprint describes structure, it does not state a falsifiable success condition). It has no `wired_to` that an author commits to — a blueprint *describes* topology rather than *promising* it. By Principle 1, a "blueprint generated to describe the system" is topology mislabelled as intent; by Principle 3, a blueprint with no falsifiable wiring claim is documentation (Section 3.4), not intent.

**Counterfactual recommendation**: the Intent Capture doctrine would have rejected the "master blueprint" framing on the specific ground that *a blueprint is hand-authored topology masquerading as intent* — and would have pointed at the generator-not-author boundary (Principle 1) as the reason. This is a substantively different and better-grounded recommendation than the actual: the framing audit correctly rejected "blueprint" but on framing-smuggling grounds; the doctrine names the deeper structural reason (the blueprint conflated authored intent with derived topology), which is exactly the distinction the three-doctrine split exists to preserve.

**Verdict**: PASS (recommendation differs from actual AND is better-grounded — it identifies the structural conflation, not just the smuggled word). Confidence: the case was nominated by the council (a second party), not self-selected, so it approaches STRONG-PASS; full STRONG-PASS deferred pending an independent second-party confirmation of the counterfactual's superiority.

## 14. Deletion test appendix (Gate 1)

**Re-invention question**: would removing this doctrine force downstream work to be re-invented?

**Named downstream consumers**:

1. **The M3 intent-capture mechanism builder** (next milestone). Without this doctrine, the M3 builder must re-derive: the intent-record schema (Section 6.1), the authored-vs-derived boundary (Principles 1-2), the `wired_to` bridge to reconciliation (Section 12.3), the supersession traversal contract (6.4), and the degenerate-case guard (8.4). Every one of these is a non-trivial design decision the doctrine settles.
2. **The companion intent-capture skill** (M3+). The Section-11 application checklist is the skill's procedure. Without the doctrine, the skill author re-derives the index/resolve/validate/emit pipeline.
3. **Doctrine 06 (Conservation-Law Verification)**. Reconciliation's `left_view` contract (Section 12.3a) is *defined here*. Without this doctrine, Doctrine 06 would have to invent the intent-side of its comparison, guessing at what `wired_to` means.

**Verdict**: PASS. Three named consumers, each re-inventing non-trivial content. Removing the doctrine causes complexity to reappear across all three.

## 15. References

### 15.1 Primary sources (intent-capture patterns)
- Nygard, M. (2011), "Documenting Architecture Decisions" — https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions (the ADR pattern; cited for the record-per-decision component, NOT for the three-way separation)
- The workshop's `define-destination` skill + `DESTINATION.md` v2 (the destination intent-record pattern, the incumbent carrier)
- OpenAPI Initiative — https://github.com/OAI/OpenAPI-Specification (the `kind: contract` machine-readable carrier)
- JSON Schema 2020-12 — https://json-schema.org/ (the substrate for validating the intent-record shape)

### 15.2 Counter-evidence (cited honestly, per F4)
- Backstage `catalog-info.yaml` — https://backstage.io/docs/features/software-catalog/descriptor-format/ — BUNDLES intent + topology in one hand-authored YAML; cited as counter-evidence to the separation, never as support. The workshop separates them precisely because it does NOT hand-author topology.

### 15.3 Related workshop artefacts
- `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md` (programme spec)
- `DESTINATION.md` v2 (success contract — Element 1 Condition 4, Element 2 Test D, Element 4 scenario 5)
- `specs/research/architecture-blueprint-research-2026-05-22.md` (M1 evidence base)
- `specs/13_M2_DOCTRINE_PLAN.md` (Phase 1 Test D dry-run + grill + council amendments)
- `council/sessions/2026-05-22-m2-doctrine-authoring-plan.md` (the extended council)
- `docs/operational-doctrine/05_topology-from-source.md`, `06_conservation-law-verification.md` (sibling mechanisms)
- `.claude/rules/doctrine-verification-gate.md` (the triple gate)
- `.claude/rules/agentic-loop-guards.md` (the compaction-aware-state discipline cited in Section 10.4)

## Status Footer

- **Doctrine**: 04 — Intent Capture as Mechanism
- **Status**: authored 2026-05-22 (M2); triple gate — Gate 1 (deletion) PASS, Gate 3 (real-decision) PASS, Gate 2 (code-council) pending this session
- **Test D**: separability EARNED (schema 21.7-27.8%, falsification-condition stated, operational limb with contracted I/O + mechanical invocability check + worked compound-drift example)
- **schema-review-required: before-M3-ships** (A4 — re-read before M3 builds the mechanism; flag any field M3 won't expose)
- **Cross-doctrine consistency**: re-run the `doctrine-verification-gate.md` consistency check across doctrines 04/05/06 before any propagation event
- **Companion mechanism**: not yet built (M3)

---

## Appendix A — Worked examples

Eight worked examples instantiating the doctrine. Each follows the template: **situation → intent record → detection signal (what an operator observes) → what the doctrine says → what goes wrong without it → composition trace (how it interacts with Doctrines 05/06)**. The detection signals are the operational payload — a downstream operator or M3 mechanism applies them in real time without re-reading the doctrine body.

### A.1 A destination condition with full wiring (the healthy baseline)

**Situation**: BuyBox-AI's destination promises "the property list page loads in under 2 seconds."

**Intent record**: `kind: destination`; `conditions` = "list page TTFB < 2s"; `binary_test` = "a third party times the cold-cache list page and observes < 2s"; `wired_to` = [the list RPC node, the composite index node, the Vercel route node]; `status: accepted`; `owner: BuyBox lead`; `acceptance_cadence: monthly`.

**Detection signal (healthy)**: all three `wired_to` targets resolve to live topology nodes; `binary_test` is third-party-runnable; `status` is in the closed enum. An operator sees a green, fully-wired promise.

**What the doctrine says**: this is a well-formed intent record — falsifiable (the `binary_test` is observable), wired (three resolvable targets), machine-addressable (every field is structured). It is the reference shape every other example deviates from.

**Without it**: the 2-second promise lives in a chat message or a PR description; no machine can ask "is this still true?"; the 2026-04-25 list-page timeout regression (`loading-state-invariants.md`) recurs invisibly because there was no addressable promise to reconcile the slow query against.

**Composition trace**: reconciliation (Doctrine 06) takes this record's `wired_to` as `left_view`, resolves the composite-index node against topology (Doctrine 05) as `right_view`, and on each cadence confirms the index still exists. Three mechanisms, one promise, no bundling.

### A.2 An ADR superseded by a later decision (the traversal contract earns its keep)

**Situation**: ADR-0007 chose a wide database view as the list-data source; six weeks later ADR-0012 reversed it to a base-table RPC after the wide view caused a 51-second counts query.

**Intent record**: ADR-0007 → `status: superseded`, `superseded_by: adr-0012`. ADR-0012 → `status: accepted`, `superseded_by: null` (terminal).

**Detection signal**: a query for "current list-data decision" filtered to the topic returns exactly one terminal (ADR-0012). If it returns ADR-0007, the chain is mis-walked.

**What the doctrine says** (Principle 5 + 6.4): the traversal walks `superseded_by` to the single terminal and returns ADR-0012. The superseded record is preserved for audit but is never returned as current.

**Without it**: a fresh session reads ADR-0007 (the first chronological match), re-adopts the wide-view anti-pattern, and reintroduces the 51-second counts query — a real regression class documented in `loading-state-invariants.md`. Stale-intent anchoring (8.3) made live.

**Composition trace**: this is pure intent-layer — topology and reconciliation are not involved. The example shows intent's *independent invocability* (12.3b): resolving the current decision needs only the intent records and the supersession chain, no topology generation, no reconciliation check.

### A.3 Aspirational intent not yet wired (the `pending` marker prevents cried-wolf)

**Situation**: a roadmap item promises "AI co-pilot chat in the deal drawer," but the feature is not built yet.

**Intent record**: `kind: roadmap_item`; `conditions` = "operator can ask the drawer a free-text question and get a grounded answer"; `wired_to: pending`; `status: accepted`.

**Detection signal**: `wired_to` is the literal `pending` marker, not an absent field and not an unresolved reference. An operator sees a deliberately-unwired live promise.

**What the doctrine says** (Principle 3 exception + 9.3): `pending` tells reconciliation NOT to report drift — the promise is live and accepted but deliberately not yet implemented. The marker is the difference between "we haven't built it yet" (valid) and "we built it and the wiring broke" (drift).

**Without it**: reconciliation reports the co-pilot as "missing wiring" drift on every cadence run. The operator sees a persistent red that is not actually a problem, and within a week stops trusting drift alerts entirely (the cried-wolf failure that destroys the destination's Condition 2).

**Composition trace**: reconciliation reads `wired_to: pending` and emits `verdict: in_sync` (nothing to compare) rather than `drift`. The `pending` marker is the contract token that lets the two mechanisms stay separate without producing false positives.

### A.4 Derived-field contamination caught (Principle 2 at the field level)

**Situation**: an M3 builder, finding it convenient, adds a `coverage_pct` field to a destination record, caching "73% of `wired_to` links currently resolve to live topology."

**Intent record**: rejected at application-checklist validation step 4.

**Detection signal**: the field's value changes between two reads with no author commit in between (`source_commit` unchanged, value changed). That is the mechanical signature of a derived field hiding in an authored record.

**What the doctrine says** (Principle 2 + 6.6): `coverage_pct` is derived — a generator computes it from topology resolution. It belongs in the computed layer keyed to the intent `id`, never inside the authored record. The record stays authored-only; the derived view joins at read time.

**Without it**: the intent record's value changes without an author commit; its provenance becomes ambiguous (is this field authored or generated?); and — critically — Test D separability from topology degrades silently, because the record now carries a topology-derived value, inching the schemas toward the bundle the three-doctrine split exists to prevent.

**Composition trace**: this is the field-level guard on the generator-not-author boundary (12.2). The derived value still reaches the operator — via the computed layer (6.6) — but it never contaminates the authored record.

### A.5 Dimension-degenerate at a Make.com entity (declare, don't fake)

**Situation**: Nirvana Freight's operational intent lives largely in Make.com scenario configuration (a closed API, not machine-readable). The repo has a DESTINATION.md and a few ADRs, but the bulk of "what the trip-state machine is supposed to do" is locked in Make.com.

**Intent record**: the mechanism indexes the machine-readable carriers (destination + ADRs) successfully but cannot reach the Make.com intent.

**Detection signal**: the mechanism's minimum-viable-source check passes (a DESTINATION.md exists) but a known intent surface (the Make.com scenarios) is unreachable. Coverage is partial, not complete.

**What the doctrine says** (8.4 + A5 guard): declare-and-log "intent dimension partially degenerate: Make.com scenario intent is not machine-readable at this entity; indexed coverage is destination + ADRs only." Do NOT return the partial corpus as if it were complete.

**Without it**: the mechanism returns the Markdown-only intent, the logs say "intent: running," and the operator believes intent coverage is complete when half of it is dark. This is the destination's Element-4 vacuous-green-light scenario — Test A passes on the synthetic queries while real-work intent (the trip-state rules) is invisible.

**Composition trace**: reconciliation, told the intent dimension is partially degenerate, scopes its invariants to the covered surface and flags the uncovered surface as unverifiable rather than asserting in_sync. The honest degenerate-case declaration propagates to the other mechanisms.

### A.6 The supersession conflict surfaced (two terminals, never silently picked)

**Situation**: two parallel sessions independently amend the same destination condition (one tightens the latency target to 1.5s, the other adds a mobile-specific clause); both new records are written with `superseded_by: null`.

**Intent record**: two records on one topic, both claiming to be terminal.

**Detection signal**: the topic filter returns two records with `superseded_by: null`. That is a versioning conflict by definition.

**What the doctrine says** (6.4 traversal contract): surface the conflict explicitly — "two live terminals on topic 'list-page-latency': record X and record Y." Never silently pick one. The author resolves by superseding one with the other (or merging into a third).

**Without it**: a query returns whichever record sorts first by id or timestamp; the other session's intent is silently lost; an `/autovibe` run acts on half the intended change.

**Composition trace**: pure intent-layer (independent invocability again). The conflict is detected without any topology or reconciliation involvement — the intent mechanism polices its own versioning invariant.

### A.7 Fulfilled-without-verification caught (status integrity)

**Situation**: an author, believing the feature shipped, sets a destination condition to `status: fulfilled`.

**Intent record**: `status: fulfilled`, but the `wired_to` targets do not all resolve in the current topology graph.

**Detection signal**: a `fulfilled` record whose `wired_to` targets fail to resolve against the live topology. The status claims done; the wiring says otherwise.

**What the doctrine says** (Principle 6 + 8.5): a `fulfilled` status must be backed by a reconciliation verdict, not authored optimism. Until reconciliation confirms the wiring resolves and the `binary_test` passes, the status reverts to `accepted`. `fulfilled` is the one status transition intent does not get to assert unilaterally.

**Without it**: the intent claims completion that was never verified; the gap between promise and reality is hidden behind a false "done"; the destination's Condition 1 ("answers derived from source") returns a lie.

**Composition trace**: this is the one place intent *reads* a reconciliation result — but as a recorded, author-confirmed status transition (Principle 6), not a live pull. Reconciliation produces the verdict; the author records it as the `fulfilled` transition; the boundary stays clean.

### A.8 The contracted join under an /autovibe run (composition at full speed)

**Situation**: an autonomous `/autovibe` session at BuyBox-AI asks "are all accepted billing-related promises currently fulfilled?" before it begins a billing-adjacent change.

**Intent record**: the mechanism returns the terminal billing-intent records' `wired_to` + `conditions` as a partial-readable slice (P4) — not the whole intent corpus.

**Detection signal**: the session receives a bounded slice (the billing-topic terminals) in a structured form it can act on, with no prose to parse.

**What the doctrine says** (12.3 contract): the session hands each record's `wired_to` to reconciliation as `left_view`; reconciliation joins with topology's `right_view` and returns a per-promise verdict (`in_sync` / `drift` + `named_action`). The session acts on the verdicts without ever re-deriving the billing architecture.

**Without it**: the session re-discovers the billing architecture from raw source (reads migrations, traces edge functions, parses the UI) on every run — the exact re-discovery cost the destination's Condition 6 forbids, and the failure that makes autonomous operation expensive instead of cheap.

**Composition trace**: this is the canonical three-mechanism composition (12.3c) running in production: intent emits the slice, reconciliation consumes `wired_to` as `left_view`, topology supplies `right_view`, and the operator (here, an AI) issues *one* query and gets a joined answer. Three separate mechanisms, one consumer interface, zero bundling — the architecture the whole three-doctrine split was built to make possible.

### A.9 Contract-kind intent (OpenAPI as a machine-readable promise)

**Situation**: BuyBox-AI exposes a Supabase edge function with a documented request/response contract. The contract IS the intent — it promises a specific input/output shape to any consumer.

**Intent record**: `kind: contract`; `source_file` = `openapi.yaml`; `conditions` = the schema itself (machine-readable by construction); `binary_test` = "a contract-conformance run (Spectral lint + a request against the deployed function) passes"; `wired_to` = [the edge-function topology node]; `status: accepted`.

**Detection signal**: the contract file parses as valid OpenAPI AND its declared endpoint resolves to a live edge-function node. A drift signal is a contract whose endpoint no longer exists, or whose deployed shape no longer matches the schema.

**What the doctrine says** (6.2): a contract is intent of `kind: contract` — the only kind whose `conditions` are machine-readable without extraction, because the schema is already structured. The mechanism indexes it into the common record shape so it sits alongside destinations and ADRs uniformly. No special-casing at the consumer.

**Without it**: the contract is "just an API doc"; nobody reconciles the deployed function against it; the function's response shape drifts from the promised schema and downstream consumers break silently (the classic API-drift failure). The promise existed but was unaddressable.

**Composition trace**: reconciliation takes the contract schema as `left_view` and the deployed function's actual response shape (resolved via topology's edge-function node + a live probe) as `right_view`; a shape mismatch is `drift` with `named_action: reconcile` (regenerate the function or amend the contract). The contract-kind shows the doctrine's carrier-agnosticism: four kinds, one record shape, one reconciliation path.

### A.10 The intent index at scale (partial-readability when the corpus is large)

**Situation**: Agency-Main has accumulated ~80 ADRs + 4 destinations + dozens of roadmap items across several bounded contexts. A session asks about one narrow topic ("the KI pipeline relevance-scoring decision").

**Intent record**: many records exist; only one terminal is relevant.

**Detection signal**: a topic query that, without an index, would scan all ~120 records to find the relevant terminal — measurable as a slow, context-heavy read.

**What the doctrine says** (6.7 + P4): the intent index (a derived map from topic → terminal id, living in the computed layer) lets the session hit the index, get the terminal id, and read exactly one record. Partial-readability is preserved at scale.

**Without it**: the session loads the whole intent corpus into context to find one record (the corpus-dump anti-pattern, 9.6), blowing its context budget and re-reading 119 irrelevant records — exactly the cost partial-readability exists to avoid.

**Composition trace**: the index is intent-internal (a derived view over authored records, 6.6) — it does not touch topology or reconciliation. It is the mechanism's own answer to its own scaling problem, and its existence as a *derived* artefact (not an authored one) is itself an instance of the computed-layer pattern keeping Principle 1 intact.

### A.11 Acceptance-cadence staleness (the promise, not the implementation, went stale)

**Situation**: a destination condition promised "support Make.com as a first-class automation backend." Eighteen months later, Make.com is legacy and being sunset — the promise is stale even though its implementation still works perfectly.

**Intent record**: `status: accepted`; `wired_to` resolves fine (the implementation exists and works); but the `acceptance_cadence` (say, quarterly) has elapsed without re-confirmation.

**Detection signal**: `timestamp` + `acceptance_cadence` show the intent is overdue for re-confirmation, AND reconciliation reports `in_sync` (implementation matches promise). In-sync + overdue-acceptance = a stale promise, not a drift.

**What the doctrine says** (6.5): this is intent-freshness's domain, distinct from reconciliation. The implementation has NOT drifted — it matches the promise exactly. But the *promise itself* no longer reflects what we want. The acceptance-cadence flag prompts the owner to supersede the stale promise (mark it `superseded_by` a new "migrate off Make.com" intent), not to "fix" any drift.

**Without it**: reconciliation reports green (in_sync) forever; the operator never revisits the promise; the project keeps faithfully implementing something nobody wants anymore. This is the failure a reconciliation-only mechanism cannot catch — it is structurally invisible to drift detection because there is no drift.

**Composition trace**: this example is the sharpest evidence for intent-vs-reconciliation separability (6.5). Reconciliation says `in_sync`; intent-freshness says `stale`. A bundled mechanism running on one cadence would either miss the staleness (reconciliation cadence: implementation matches, all green) or thrash re-checking fresh promises. The two cadences are independent because the two failure modes are independent.

### A.12 Cross-entity propagation (the same doctrine, a different stack)

**Situation**: the intent-capture mechanism is propagated from the workshop to Nirvana Freight, whose stack (no n8n, Make.com automation, vendor dispatch app) differs sharply from BuyBox-AI's.

**Intent record**: at Nirvana, the carriers present are DESTINATION.md + a thin ADR set; the contract-kind and rich roadmap-intent that BuyBox-AI has are largely absent.

**Detection signal**: the mechanism's minimum-viable-source check (8.4) passes (a DESTINATION.md exists), but the indexed corpus is thinner and one surface (Make.com intent) is degenerate (A.5).

**What the doctrine says** (stack-agnosticism, destination Condition 5): the doctrine's record shape and principles are stack-independent — an intent record is an intent record whether the implementation it wires to is a Supabase RPC or a Make.com scenario. The mechanism indexes what is machine-readable, declares-and-logs what is degenerate, and serves the same query interface. The doctrine does not assume BuyBox-AI's stack.

**Without it**: a stack-specific intent mechanism (one that assumed Supabase + n8n) would silently produce an empty or broken corpus at Nirvana and the propagation would "peel off after the first week of novelty" — the exact failure the destination's Condition 7 (30-day sustain) forbids.

**Composition trace**: the degenerate-case declaration (A.5) propagates to reconciliation at Nirvana, which scopes its invariants to the covered surface. Stack-agnosticism is a property the three mechanisms share precisely because each reads source-of-truth artefacts generically (intent reads any of the four carrier kinds; topology reads any source emitter; reconciliation compares any two views) rather than hard-coding one stack.

---

## Appendix B — Quick-reference operator card

A one-screen summary an operator or M3 mechanism applies without reading the body.

| You observe | It means | Doctrine action |
|-------------|----------|-----------------|
| Intent record value changed, `source_commit` unchanged | Derived-field contamination (P2) | Move the value to the computed layer; reject the field |
| Two records on one topic, both `superseded_by: null` | Supersession conflict (6.4) | Surface both terminals; never auto-pick |
| `status: fulfilled` but `wired_to` targets don't resolve | Fulfilled-without-verification (8.5) | Revert to `accepted` until reconciliation confirms |
| `wired_to` absent (not `pending`) on an accepted record | Orphan intent (9.5) | Wire it or mark `pending`; else it's documentation |
| Reconciliation reports drift on an unbuilt feature | Missing `pending` marker (9.3) | Set `wired_to: pending` |
| Query returns the whole corpus for one topic | Corpus-dump (9.6) | Use the topic index → terminal slice |
| In_sync + acceptance-cadence overdue | Stale promise, not drift (6.5) | Owner supersedes the stale intent |
| Logs say "intent: running" but a known surface is unindexed | Dimension-degenerate (8.4) | Declare-and-log; don't return partial as complete |
| Intent record dictates implementation method, not end-state | Intent-as-binding-spec overreach (9.7) | Restate as observable end-state; leave method to the implementation |
| `acceptance_cadence` elapsed, no re-confirmation, no flag | Silent cadence lapse (9.8) | Surface the overdue signal; owner re-confirms or supersedes |
| `kind: contract` schema parses but endpoint node is gone | Contract drift (A.9) | Reconciliation flags drift; regenerate the function or amend the contract |
