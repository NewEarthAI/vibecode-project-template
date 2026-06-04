# Topology-from-Source — Operational Doctrine

> **Doctrine 05 of the operational-doctrine set.** Companion doctrines: `04_intent-capture.md` (the authored promise), `06_conservation-law-verification.md` (the cross-system invariants). This doctrine is the second of the three Intent-Actual-Gap mechanisms (programme spec `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`; success contract `DESTINATION.md` v2).
>
> **Authored**: 2026-05-22 (M2, Intent-Actual-Gap Mechanism Build Programme). **Verification**: triple gate (`doctrine-verification-gate.md`) — see Sections 13-14. **Separability**: defended in Section 12 (Test D).
> **schema-review-required: before-M3-ships** — the machine-readable node schema in Section 6 + Section 12 is a pre-M3 design commitment; before M3 ships the topology mechanism, re-read this doctrine and flag any field the implementation will not expose.

---

## 1. Purpose

Topology-from-Source is the mechanism that produces the **actual dependency graph of a system**, generated from source-of-truth artefacts (git history, database schema, workflow JSON, deployed config), never hand-authored, with every node and edge traceable back to the exact source row, file, commit, or config key that produced it.

The doctrine governs the *actual* half of the intended-vs-actual gap. It does not record what the system was supposed to do (that is intent, Doctrine 04) and it does not measure the gap (that is reconciliation, Doctrine 06). It governs the artefact that says *what the system actually is, right now, derived from its own sources*: which database objects depend on which, which workflow node feeds which, which module imports which, which deployed function the route actually calls.

The doctrine exists because the actual structure of a running system is almost never written down accurately — and when it is hand-drawn (a diagram, an architecture doc), it is stale the moment it is saved. The only trustworthy source of "what actually depends on what" is the system's own source artefacts: the database's own dependency catalogue, the workflow's own connection graph, the codebase's own import statements, the deploy config's own routing table. Topology-from-Source reads those sources and emits a machine-addressable graph. The single discipline that makes it trustworthy is captured in one phrase: **the generator is not the author.**

## 2. Why this doctrine earned its slot

The M1 research (`specs/research/architecture-blueprint-research-2026-05-22.md`) found that the leading topology tools split sharply into two camps: hand-authored models (C4 + Structurizr, where an architect writes the DSL) and generated graphs (dbt's `manifest.json`, Postgres `pg_depend`, dependency-cruiser, Lyft's Cartography, where a tool reads source and emits the graph). The destination demands the second camp explicitly: "generated from source artefacts, in seconds, with each answer traceable back to the source rows / files / commits / config keys that produced it" (Condition 1). A hand-authored model cannot satisfy "traceable to the source that produced it" because no source produced it — a human did.

This doctrine earns its slot because the generator-not-author principle is a load-bearing design commitment that neither Doctrine 04 (intent, which is authored) nor Doctrine 06 (reconciliation, which compares) makes. It is also the principle that *earns the three-way separability* on internal grounds (Section 12): because topology is generated and intent is authored, their schemas necessarily diverge — which is exactly why the workshop separates what Spotify's Backstage bundles.

## 3. Scope boundary — what this doctrine does NOT do

### 3.1 Recording the intended dependency graph (→ Doctrine 04, Intent Capture)

When an intent record's `wired_to` says "the billing UI depends on the billing edge function," that is an *authored claim* about intended structure. Topology-from-Source does NOT author claims — it derives the *actual* graph. The intended-vs-actual comparison is reconciliation's job (Doctrine 06). Topology supplies only the actual side.

### 3.2 Measuring the gap (→ Doctrine 06, Conservation-Law Verification)

Topology emits the actual graph as one of the two views reconciliation compares (the `right_view` — Section 12.3). It does NOT assert that the actual matches the intended. A topology graph is a factual snapshot, not a verdict.

### 3.3 Hand-authored architecture models (delegated to the intent layer)

A C4 model, a Structurizr DSL file, a Mermaid diagram an architect drew — these are *authored* statements of intended or idealised structure. They belong to Doctrine 04 (intent), to be diffed against this doctrine's generated graph. Topology-from-Source never produces or consumes a hand-authored model as its source of truth (the one bounded exception is the source-orphan node class, Section 6.6 + 8.4, which is explicitly flagged, justified, and review-gated precisely because it breaches the generator-not-author boundary).

### 3.4 Symbol-level code intelligence (a different problem class)

Go-to-definition, find-references, type resolution (Sourcegraph SCIP, LSP-based indexing) operate at the symbol level (function → callers). Topology-from-Source operates at the system level (table → views → functions → triggers; workflow → workflow). The M1 research flagged these as distinct problem classes. Symbol-level intelligence is out of scope; if a future need arises it is a separate mechanism, not an extension of this one.

### 3.5 Runtime tracing / observability

What actually executed at runtime (traces, spans, logs — Sentry, PostHog) is a different signal from what the source artefacts declare. Topology-from-Source derives the *declared* structure (the n8n connection graph says node A feeds node B); runtime tracing observes the *executed* structure (node A actually fired node B 412 times today). The declared graph is this doctrine's domain; runtime is observability's.

## 4. Governing principles

Each principle is paired with a falsification condition.

### Principle 1: The generator is not the author (topology is derived, never authored input)

Every topology node and edge is produced by a generator reading a source-of-truth artefact. No node is hand-typed as a primary fact. This is the doctrine's root principle and the basis of its separability from intent (Doctrine 04, where intent IS authored).

**Falsification**: if a topology node exists that no generator can reproduce from a source artefact (it was hand-typed and has no source to regenerate from), the principle is violated for that node — it is intent (an authored claim) mislabelled as topology. (The bounded exception — the source-orphan node — is the explicitly-flagged breach, Section 6.6, which is why it carries a mandatory `emitter: "manual"` marker that makes the breach visible rather than silent.)

### Principle 2: Every node and edge traces to its source

Each node carries the source artefact (file, DDL statement, workflow JSON, config key), the source line where applicable, and the source commit that last changed it. A topology fact you cannot trace to its origin is not trustworthy — it could be stale, wrong, or invented.

**Falsification**: if a node cannot answer "which source artefact + commit produced you?", it fails the destination's Condition 1 (traceable to source) and must be treated as untrustworthy until its provenance is resolved.

### Principle 3: Topology is regenerated, not incrementally edited

When source changes, the affected portion of the graph is regenerated from the new source — never patched in place. A patched graph drifts from its source; a regenerated graph cannot. (Incremental *regeneration* — re-running only the emitter whose source changed — is allowed and encouraged for speed; incremental *editing* of the graph independent of source is forbidden.)

**Falsification**: if the graph and the source disagree after a source change (because the graph was edited but not regenerated, or regenerated but the edit was preserved), the principle is violated and the graph is stale.

### Principle 4: One node, one source-of-truth emitter

Each node is produced by exactly one emitter (the Postgres emitter produces database nodes; the n8n emitter produces workflow nodes; the TS emitter produces module nodes). No node is produced by two emitters claiming different provenance. The `emitter` field records which one. This keeps provenance unambiguous and makes the multi-emitter pipeline (Section 6.2) composable.

**Falsification**: if a node's `emitter` is ambiguous or two emitters both claim to have produced the same node id, provenance is broken and the node's traceability (P2) is unreliable.

### Principle 5: The graph is machine-addressable, not a rendered diagram

Topology's primary output is a queryable graph (structured JSON / a graph store), not a PNG or a rendered Mermaid diagram. Diagrams are a *downstream rendering* of the graph; the graph itself is the artefact reconciliation and AI sessions query. A diagram-only topology fails the destination's Condition 1 (structured answers without reading prose) and Condition 6 (machine-addressable for AI).

**Falsification** (anchored to the §6.5 query API, not a restatement): P5 is falsified if `dependents(node_id)` cannot return a node-id list without rendering a diagram — i.e. if the only way to answer "what depends on table X?" is to read an image. The test is mechanical: call `dependents(node_id)` and check it returns structured ids, not a rendered artefact.

### Principle 6: Coverage is declared, degeneracy is logged

The graph declares which source emitters ran and which sources they covered. When an emitter finds no source (a project with no n8n workflows → the n8n emitter produces nothing), that degeneracy is logged, not silently treated as "no dependencies." An empty result from a missing source is different from an empty result from a source with no dependencies, and the graph must distinguish them.

**Falsification**: if the graph returns "no workflow dependencies" identically whether the project has zero workflows or has workflows the emitter failed to read, Principle 6 is violated and the vacuous-green-light failure (8.4) is live.

### Principle interaction — how the six compose

The principles form a dependency chain an M3 builder implements together, not piecemeal:

- **P1 (generator-not-author) is the root.** Everything depends on it — it is the boundary that separates topology (derived) from intent (authored, Doctrine 04) and the basis of Test D separability (Section 12). P2 (traceability) is how P1 is *verified*: a node traces to its source precisely because a generator produced it from that source. Violate P1 (hand-author a node) and P2 has nothing to trace to — which is exactly why the source-orphan exception (6.6) forces a `manual_justification` to stand in for the missing source.
- **P3 (regenerate-not-edit) is what makes P1 hold over time.** A node can be correctly generated once (P1) and then drift if the graph is hand-patched. P3 forbids the patch; the node stays faithful to source across changes.
- **P4 (one node, one emitter) is what makes the multi-emitter pipeline composable.** Without unambiguous provenance, two emitters fight over a node and P2's traceability collapses (8.5).
- **P5 (machine-addressable, not diagram) is what lets the other two mechanisms consume topology.** Reconciliation's `right_view` (12.3) must be a queryable graph; a diagram cannot be joined to intent's `wired_to`. P5 is the contract-enabling principle.
- **P6 (declared coverage, logged degeneracy) is what makes topology trustworthy at propagation.** Across entities with different stacks (BuyBox-AI vs Nirvana), the same mechanism produces different coverage; P6 makes the difference visible rather than letting a Postgres-only graph masquerade as complete.

Practical order for M3: implement P1+P2 first (the derived-and-traceable core), then P4 (unambiguous emitters), then P3 (regeneration), then P5 (the query API), then P6 (coverage declaration). An implementation that builds a pretty diagram (violating P5) before the derived-and-traceable core (P1+P2) has built a rendering of facts whose provenance is already unverifiable.

## 5. Assumptions

- **A1**: The system's structure is genuinely recoverable from source artefacts — the database exposes its dependency catalogue (`pg_depend`), the workflow stores its connection graph (n8n JSON), the code declares its imports (TS modules), the deploy config declares its routes. A system whose structure exists only at runtime (dynamic dispatch with no static signal) is partially out of reach (3.5).
- **A2**: Each source type has a generator (an emitter) capable of reading it. Where no emitter exists for a source type, that dimension is degenerate (P6) until an emitter is built — not silently absent.
- **A3**: The provenance envelope (source_file, source_commit) is resolvable from git for file-based sources, and from the live system for runtime-config sources (a deployed Vercel route's provenance is the deploy id + the route config).
- **A4**: Graph size per project is bounded enough to regenerate in seconds (the destination's Condition 1 "in seconds"). Where a graph grows large, incremental regeneration (P3) keeps re-derivation fast by re-running only the changed emitter.
- **A5**: The emitters have read access to the sources. The Postgres emitter needs a DB connection (a Supabase MCP server or service key); the n8n emitter needs the workflow JSON (repo or n8n API); the Vercel emitter needs the deploy API. Where access is missing, that dimension is degenerate by *access* rather than by *absence* — and the two must be logged distinctly (a source that exists but is unreadable is a different signal from a source that does not exist). This is a sharper case of P6.
- **A6**: Source artefacts are the authoritative structure. Where a system's true structure diverges from what its source artefacts declare (a manually-applied database change with no migration — itself a drift reconciliation should catch), topology reports what the *live source-of-truth* says (the live catalogue via `pg_depend`), not what the repo migrations say. The repo-vs-live divergence is itself a reconciliation invariant (Doctrine 06), and topology supplies the live side of it.

## 6. Mechanisms

### 6.1 The topology node — machine-readable graph element

The atomic unit is the **topology node**, generated (never authored) with these fields:

```
id              # stable identity of a topology node
kind            # table | view | function | trigger | rls_policy | edge_function | workflow | workflow_node | ts_module | config
source_file     # file / DDL / workflow JSON that produced the node
source_commit   # commit the node's source was last changed in
timestamp       # when this graph was generated (derivation time)
source_line     # line within source_file (node provenance precision)
emitter         # which generator produced it: pg_depend | n8n_parser | dependency_cruiser | vercel_api | manual
depends_on      # array of node ids — the outgoing edges
depended_on_by  # array of node ids — the reverse edges (child map)
attributes      # node-kind-specific properties (typed payload)
```

The first five fields (`id`, `kind`, `source_file`, `source_commit`, `timestamp`) are the **provenance envelope** shared with the other two mechanisms. The remaining five are the topology payload — the derivation-specific fields (`source_line`, `emitter`, `depends_on`, `depended_on_by`, `attributes`) that distinguish this mechanism (Section 12).

### 6.2 The multi-emitter pipeline (the core mechanism)

Topology is produced by a set of small, independent **emitters**, each reading one source type and writing into a common graph shape (the dbt `manifest.json` pattern the M1 research identified as the cleanest):

- **Postgres emitter** (`pg_depend`): a single SQL query against the database's own dependency catalogue (`pg_depend` + `information_schema`) emits the schema topology — tables, views, functions, triggers, RLS policies, and the foreign-key + dependency edges between them. Each node traces to its DDL via the system catalogue. Highest-fit emitter for the workshop's Supabase stack (zero new infrastructure, one query per project).
- **n8n emitter** (workflow JSON parser): each n8n workflow IS a directed graph — the `connections` object is the edge list keyed by source-node name. The emitter walks `workflow.nodes[]` + `workflow.connections{}` and emits per-workflow node graphs plus cross-workflow edges (Execute Workflow targets, webhook URLs). The graph is the source; "derivation" is parsing.
- **TS emitter** (dependency-cruiser-style): reads `*.ts/*.tsx` imports and emits the module dependency graph. Single-language; one emitter among several.
- **Deploy emitter** (Vercel API): reads the deployed routing config and emits route → function edges, with the deploy id as provenance.

Each emitter is independently runnable (P4) and writes into the common node shape (6.1). The pipeline composes by union of emitter outputs; incremental regeneration re-runs only the emitter whose source changed (P3).

### 6.3 The common graph shape (the manifest pattern)

All emitters target one canonical JSON shape: `{nodes: [...], parent_map: {...}, child_map: {...}}`, where each node carries its provenance envelope + `depends_on`/`depended_on_by`. This is the dbt `manifest.json` discipline: compile (run the emitters) → emit a canonical graph JSON with nodes + edges + provenance. The shape is emitter-agnostic — a consumer querying "what depends on X?" does not care whether X is a Postgres table or an n8n node.

### 6.4 The traceability path (Principle 2 mechanism)

Every node answers "where did you come from?" via the envelope: `source_file` + `source_line` + `source_commit` + `emitter`. For a Postgres view node, that resolves to the migration file + line + commit that created the view, plus `emitter: pg_depend`. For an n8n node, the workflow JSON file + the node id within it + the commit + `emitter: n8n_parser`. This is what makes the destination's "traceable to the source rows/files/commits that produced it" mechanically true.

### 6.5 The query interface (the read API)

Topology exposes a small read surface (a deep module):

- **`dependents(node_id) → [node_id]`**: what depends on this node (reverse edges). Answers "what breaks if I change table X?"
- **`dependencies(node_id) → [node_id]`**: what this node depends on (forward edges).
- **`subgraph(filter) → graph`**: the slice of the graph matching a filter (a bounded context, an emitter, a kind) — partial-readability for AI sessions.
- **`provenance(node_id) → envelope`**: the source artefact + commit + line + emitter that produced the node.

No write operations: the graph changes only by regeneration from source (P3), never through the query API.

### 6.5.1 Node-kind reference (the M3 emitter contract)

Each node `kind` is produced by a defined emitter, traces to a defined source, and carries a defined `attributes` payload. This table is the M3 emitter contract:

| kind | emitter | source artefact | edges it produces | key `attributes` |
|------|---------|-----------------|-------------------|------------------|
| `table` | pg_depend | migration DDL | depended_on_by (views/functions) | columns, row-estimate |
| `view` | pg_depend | migration DDL | depends_on (tables/views) | is_materialized, definition_hash |
| `function` | pg_depend | migration DDL | depends_on (tables), depended_on_by (triggers) | language, volatility |
| `trigger` | pg_depend | migration DDL | depends_on (function, table) | timing, event |
| `rls_policy` | pg_depend | migration DDL | depends_on (table) | enabled, command, role |
| `edge_function` | vercel_api / supabase | deploy config | depended_on_by (routes) | runtime, deployed_commit |
| `workflow` | n8n_parser | workflow JSON | depends_on (other workflows) | active, trigger_type |
| `workflow_node` | n8n_parser | workflow JSON node | depends_on (within-workflow) | node_type, position |
| `ts_module` | dependency_cruiser | `*.ts/*.tsx` | depends_on (imports) | is_entry, export_count |
| `config` | manual | declared config file (deploy config, dependency manifest) | (none v1 — no machine dependency-emitter parses config files into edges yet) | config_type + per-type summary (e.g. `header_count`/`rewrite_count` for vercel; `dependency_count`/`script_count` for package) |

> **The `config` kind (added M3 Session 5, 2026-06-01 — triple-gate record:
> `council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md`)** is the home for
> declared-structure config artefacts this doctrine already places in scope — `vercel.json`
> (deploy config, the FILE not the deployed state) and `package.json` (the dependency manifest
> tree). The doctrine names "deploy config" as a read source artefact in §1 + §3 + Appendix C
> (the `vercel_api` emitter row); §3.5's boundary is *runtime tracing*, which is what stays OUT
> of scope (the deployed-state route→function binding is the M4 `vercel_api` OBSERVED-state
> concern). The kind enum simply never had a home for the declared config FILE until this row
> closed that contract gap. This was added via the doctrine-verification-gate triple gate
> (deletion-as-re-invention + `/code-council` on the doctrine delta + real-decision test against
> the live `Gz8…` cloud-vs-repo drift), recorded in the council review cited above; Test D
> separability was re-checked (the `config` kind adds the `config_type` attribute family to
> topology's schema ONLY, leaving the intent + reconciliation schemas untouched, so all three
> pairwise Jaccard overlaps are unchanged and remain < 50%). A `config` node carries
> `emitter: "manual"` + a mandatory `manual_justification` (§6.6): unlike `pg_depend` /
> `n8n_parser` / `dependency_cruiser`, no machine emitter parses a config file into a
> dependency graph in v1, so the config node is a source-orphan-class node (its source artefact
> exists and is named in `source_file`, but no generator derives edges from it yet). `config_type`
> sub-discriminates the file class without enum growth (future config files — tsconfig, env
> schema — are new `config_type` values, not new kinds). v1 emits config nodes with NO edges;
> the deploy-binding edges (vercel route → edge_function) are the M4 `vercel_api` emitter's
> OBSERVED-state concern (§3.5), distinct from this DECLARED-state file node.
>
> **Falsification condition** (the config-kind principle is wrong if): a `config` node's
> `source_file` cannot be read from the repo at derivation time (the declared source does not
> exist — the node is a stale summary, not a live-derived fact), OR the node's `attributes`
> summary keys (e.g. `dependency_count`, `header_count`) disagree with the source file's actual
> content on a fresh read (the node drifted from its source between emits). Either condition means
> the node is an unverifiable summary rather than a generated-from-source fact — the generator-not-
> author principle (P1) is breached. This is distinct from the §6.6 source-orphan rule (which
> covers nodes with NO machine-readable source artefact at all): a config node DOES have a named
> source file; its falsifier is content-divergence from that file, not absence of a source.

The `attributes` payload is where node-kind-specific effectiveness lives (the `enabled` flag on `rls_policy` is what catches the disabled-policy drift in A.11). The envelope + edges are uniform; `attributes` is the typed per-kind extension.

### 6.6 The source-orphan node class (the bounded generator-not-author exception)

Some real system elements have no machine-readable source artefact — an infrastructure-only DigitalOcean droplet that `pg_depend` cannot see, no n8n workflow references, and no deploy config names. Excluding it leaves the graph incomplete; hand-authoring it as a normal node silently breaches the generator-not-author principle (the council's Edge Case Finder EC2). The doctrine resolves this with an explicit, flagged exception:

A source-orphan node carries `emitter: "manual"` + a mandatory `manual_justification` field (why no source artefact exists) + a special review cadence (it must be re-confirmed periodically because no generator will catch its drift). The `emitter: "manual"` value makes the breach **visible and queryable** — a consumer can ask "show me all manual nodes" and audit them. This converts a silent foundation-collapse (a hand-authored node masquerading as derived) into a logged, justified, review-gated exception. The generator-not-author principle holds for every node except those explicitly marked `manual`, and the marker is the falsification condition (12.2) made concrete.

## 7. Leverage points — where this doctrine pays rent

### 7.1 The contracted output to reconciliation (the highest-leverage point)

Topology's primary consumer is reconciliation (Doctrine 06), which takes a topology subgraph as its `right_view`. By contracting this output here (Section 12.3), the doctrine prevents the M3 mechanisms from improvising the join. Topology emits the actual graph; reconciliation compares it against intent's `wired_to`; the contract is fixed.

### 7.2 "What breaks if I change X?" — the dependents query

The single most valuable operator question topology answers. Before changing a hot database table, `dependents(table_X)` returns every view, function, trigger, and RLS policy that depends on it — derived from `pg_depend`, traceable to each one's DDL. This is the question whose absence caused the 2026-04-25 list-page timeout (Gate 3, Section 13).

### 7.3 Cross-workflow dependency tracing (n8n)

In a project with many n8n workflows calling each other via Execute Workflow nodes, the cross-workflow edges are invisible without topology. The n8n emitter surfaces them, so an operator can ask "what triggers this workflow?" and "what does it call?" across the whole automation surface.

### 7.4 AI-session architecture grounding (Condition 6)

An `/autovibe` session asks `subgraph(billing)` and gets the actual billing dependency graph — derived, current, traceable — without re-discovering the architecture from raw source. This is the re-discovery cost the destination forbids.

### 7.5 Anti-leverage — where topology does NOT pay rent

Topology earns nothing (and may mislead) in these situations:

- **Single-file or pre-structure systems**: a project small enough to hold in one file has no dependency graph worth deriving. The mechanism's overhead exceeds its value.
- **Purely dynamic dispatch**: a system whose structure exists only at runtime (reflection, dynamic plugin loading with no static signal) cannot be derived from source — topology returns a sparse graph that *looks* complete but misses the runtime-resolved edges (a P2 trap: the derived facts are true but radically incomplete).
- **Questions about behaviour, not structure**: "why is this slow?" / "what did this actually do?" are runtime/observability questions (3.5), not structure questions. Topology answers "what depends on what," never "what happened."
- **Intent questions**: "what were we supposed to build here?" is intent (Doctrine 04). Topology answers "what is actually wired," never "what was promised."

Naming the anti-leverage prevents the over-application failure: a mechanism applied where it pays no rent erodes trust in it everywhere.

## 8. Failure modes — where this doctrine produces wrong results

### 8.1 Stale graph (regeneration lag)

If the graph is queried after a source change but before the affected emitter re-ran, it returns the pre-change structure. Detection signal: a node's `timestamp` (generation time) predates its `source_commit` (last source change). **Recovery**: regenerate the affected emitter; never serve a graph whose timestamp predates its source.

### 8.2 Source-orphan masquerade

A hand-authored node that omits the `emitter: "manual"` marker (Principle 1 violation) sits in the graph looking derived. Detection signal: a node whose `source_file` + `source_line` do not actually contain the declared element when checked. **Recovery**: mark it `emitter: "manual"` with justification (6.6), or remove it if it was spurious.

### 8.3 Diagram-as-topology

If the mechanism's output is a rendered diagram rather than a queryable graph (Principle 5 violation), reconciliation cannot consume it and AI sessions cannot query it. Detection signal: "what depends on X?" requires reading an image. **Recovery**: emit the structured graph; render diagrams as a downstream view of it, never as the primary artefact.

### 8.4 Dimension-degenerate silent emptiness

At an entity where a source type is absent (Nirvana: no n8n, no TS), the corresponding emitters produce nothing. If the graph returns "no workflow/module dependencies" identically to a project that has those sources but the emitter failed, the degeneracy is silent (Principle 6 violation). Detection signal: an emitter reports zero nodes without declaring whether the source was absent or unread. **Recovery (A5 guard)**: declare-and-log "topology dimension degenerate at this entity: no n8n source / no TS source; covered emitters: pg_depend, vercel_api"; never present a Postgres-only graph as a complete topology.

### 8.5 Ambiguous provenance (two emitters, one node)

If two emitters both claim a node (Principle 4 violation) — e.g. a database function exposed both as a `pg_depend` node and as an `edge_function` node — provenance is ambiguous and traceability breaks. Detection signal: two nodes with the same logical identity but different `emitter` values. **Recovery**: define the canonical emitter for that element class; the other emitter references it by id rather than re-emitting.

### 8.6 Recovery procedures (per failure mode)

Each failure mode has a defined recovery, so an operator or M3 mechanism never improvises:

| Failure | Detection signal | Recovery |
|---------|------------------|----------|
| 8.1 Stale graph | node `timestamp` predates its `source_commit` | Regenerate the affected emitter; mark stale at query time until done |
| 8.2 Source-orphan masquerade | declared `source_file`/`source_line` doesn't contain the element | Mark `emitter: "manual"` + justify (6.6), or remove if spurious |
| 8.3 Diagram-as-topology | "what depends on X?" requires reading an image | Emit the structured graph; render diagrams downstream only |
| 8.4 Degenerate silent emptiness | emitter returns zero, source-presence unknown | Declare which emitters covered which sources; log degeneracy distinctly |
| 8.5 Ambiguous provenance | two nodes, same element, different `emitter` | Canonical emitter owns the node; others reference by id |

The recovery column is the operational payload — an M3 mechanism implements each row as an automated remediation or a structured operator prompt.

## 9. Anti-patterns

### 9.1 Hand-edit-the-graph

Editing the emitted graph directly to "fix" a wrong-looking edge, instead of fixing the source the emitter reads. The edit is lost on the next regeneration (P3) and the graph silently disagrees with source until then. Right: fix the source; regenerate.

### 9.2 Diagram-first

Building a Mermaid/PlantUML renderer as the primary output and treating the graph as an afterthought. Right: graph-first; diagram is a downstream rendering.

### 9.3 Silent-orphan

Hand-adding an infra node without the `emitter: "manual"` marker (8.2). Right: every non-derived node is explicitly `manual` + justified + review-gated.

### 9.4 Emitter-coupling

Writing a consumer that knows whether a node came from `pg_depend` or `n8n_parser` and branches on it. Right: consumers query the common graph shape (6.3); the emitter is provenance metadata, not a type the consumer dispatches on.

### 9.5 Empty-equals-none

Treating an empty emitter result as "no dependencies" without checking whether the source was present (8.4). Right: declare degeneracy distinctly from genuine emptiness.

### 9.6 Stale-serve

Serving a graph whose `timestamp` predates a `source_commit` (8.1). Right: regenerate-on-source-change or mark the graph stale at query time.

### 9.7 Topology-states-intent overreach

Annotating a topology node with what it is *supposed* to do (an authored claim). That is intent (Doctrine 04), not topology. A topology node states what the source *actually declares*, never what it *should* declare. Right: keep authored claims in intent records; topology is derived fact only.

### 9.8 Runtime-as-declared confusion

Feeding runtime traces (what executed) into the declared-structure graph (what the source says). The two are different signals (3.5). Right: the declared graph comes from source; runtime observation is a separate overlay, never merged into the topology nodes.

### 9.9 Whole-graph regeneration on every change

Re-running every emitter on every tiny source change, blowing the "in seconds" budget (Condition 1). Right: incremental regeneration (P3, A.9) — re-run only the emitter whose source changed.

### 9.10 Existence-equals-effectiveness

Recording only that a node exists, not its effective state (an RLS policy present but disabled, A.11). Right: the `attributes` payload (6.1) carries the node-kind effectiveness state derived from the source; presence ≠ effectiveness.

## 10. AI-operator implications

### 10.1 Topology as the AI session's map

An autonomous session reads the topology subgraph for its task area and learns the actual structure — derived, current, traceable — without re-discovering it from raw source. The `dependents()` query tells it what its change will affect before it makes the change.

### 10.2 Provenance as the AI's trust handle

When an AI session needs to trust a topology fact, it calls `provenance(node)` and gets the source file + commit + line. It can verify the fact against source rather than trusting an opaque assertion. This is what makes topology output authoritative enough to act on (Condition 6).

### 10.3 Subgraph slicing prevents context blow-up

An AI session asks `subgraph(billing)` not `whole_graph()`. Partial-readability bounds its context — the same discipline intent's `slice()` provides (Doctrine 04, 6.8).

### 10.4 AI-specific failure modes topology must guard against

- **Acting on a stale graph**: an AI that queries before regeneration acts on pre-change structure. Guard: 8.1 — the graph is marked stale if its timestamp predates source.
- **Trusting a source-orphan as derived**: an AI that treats a `manual` node as if a generator verified it. Guard: 6.6 — the `emitter: "manual"` marker is queryable; the AI can filter manual nodes and treat them with appropriate caution.
- **Confusing declared with executed**: an AI that reads the declared graph and assumes those paths actually fired. Guard: 9.8 — topology is declared structure; runtime is a separate signal the AI must not conflate.

## 11. Application checklist — what the M3 companion mechanism operationalises

1. **Run emitters**: execute each available emitter (pg_depend SQL, n8n parser, TS cruiser, Vercel API) against the entity's sources.
2. **Resolve provenance** (P2): populate each node's envelope (`source_file`, `source_line`, `source_commit`, `emitter`) from the source + git.
3. **Build edges**: populate `depends_on` + `depended_on_by` from the emitter's edge output; union across emitters into the common shape (6.3).
4. **Declare coverage** (P6): record which emitters ran and which sources they covered; log degeneracy distinctly (8.4).
5. **Flag orphans** (6.6): any node without a machine-readable source is `emitter: "manual"` + justification + review cadence, or it is rejected.
6. **Detect staleness** (8.1): mark any node whose `timestamp` predates its `source_commit`.
7. **Answer queries** (6.5): `dependents` / `dependencies` / `subgraph` / `provenance` over the common graph.
8. **Emit for reconciliation** (12.3): expose the relevant subgraph as the contracted `right_view` for Doctrine 06.

## 12. Test D defence — separability of Topology from Intent and Reconciliation

Mandatory per programme spec §2. Three limbs: schema (Test D proper), falsification-condition (F2), operational-separability (the council's A1).

### 12.1 Schema limb — the Jaccard result

Topology's output schema (Section 6.1) has 10 fields. Pairwise field-name overlap (per `specs/13_M2_DOCTRINE_PLAN.md` Phase 1):

| Pair | Shared fields | Jaccard | < 50%? |
|------|---------------|---------|--------|
| Topology ∩ Intent | id, kind, source_file, source_commit, timestamp (5) | 5 / 18 = **27.8%** | yes |
| Topology ∩ Reconciliation | id, kind, source_file, source_commit, timestamp (5) | 5 / 20 = **25.0%** | yes |

The only shared fields are the 5-field provenance envelope. Topology's 5 payload fields (`source_line`, `emitter`, `depends_on`, `depended_on_by`, `attributes`) appear in no other mechanism's schema — they are derivation artefacts intent (authored) and reconciliation (comparison) do not carry.

**F1 consolidation robustness**: folding `depends_on`/`depended_on_by` into one `edges` field (the most aggressive honest consolidation) drops topology to 9 fields and changes nothing material — Topology∩Intent stays at 5/17 = 29.4%, Topology∩Reconciliation at 5/19 = 26.3%. No consolidation crosses 50%.

**F4 citation discipline**: separability is defended on the schema-divergence + generator-not-author grounds below, NOT on industry precedent. The M1 research found Spotify's Backstage BUNDLES topology with intent in one hand-authored `catalog-info.yaml` — cited here as honest counter-evidence. The workshop separates them precisely because topology is generated (P1) while intent is authored — the divergence is a consequence of the generator-not-author commitment, not an industry pattern the workshop copied.

### 12.2 Falsification-condition limb (F2)

> **Topology-from-Source's separateness from Intent Capture fails if any topology node becomes hand-authored without the `emitter: "manual"` marker** — at that point the node is an authored claim (intent) masquerading as derived fact (topology), the authored/derived boundary collapses, the schemas converge toward Backstage's bundled `catalog-info.yaml`, and Test D must be re-run. The source-orphan exception (6.6) is the controlled breach: it makes hand-authoring *visible* via the `manual` marker rather than letting it happen silently. Separability holds for every node except explicitly-marked `manual` nodes, and the marker is the audit handle.

**Test D re-run trigger (A5)**: any M3 change that adds/renames a field in any of the three schemas triggers a mandatory Test D re-run, appended here as a dated row. Test D is a living invariant.

| Date | Change | Re-run result |
|------|--------|---------------|
| 2026-06-01 | M3 Session 5 added the `config` kind (vercel.json / package.json declared-config files). | **NO field added/renamed** — `config` is a new VALUE in the existing `kind` enum, and `config_type` + its per-type summary ride inside the existing `attributes` object (a single counted field). Topology's field-name set (the 10 §6.1 fields + `declared_intent_ref`) is unchanged, so all three pairwise Jaccard overlaps are identical to the prior row: Topology∩Intent 27.8%, Topology∩Reconciliation 22.7% (against D06's post-amendment 17-field count), Intent∩Reconciliation 20.0% — all < 50%. Separability HELD. Recorded in `council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md` Gate-2. (The §12.1 table above cites the pre-D06-amendment Topology∩Reconciliation count 5/20 = 25.0%; against D06's current 17-field schema it is 5/22 = 22.7% per `council/audits/2026-05-22-cross-doctrine-consistency-04-05-06.md` Check 6 — both < 50% with margin; the table is left at its authored value per the living-invariant "dated row" convention rather than rewritten in place.) |

### 12.3 Operational-separability limb (the council's A1)

**(a) Input/output contracts:**

| Direction | Contract |
|-----------|----------|
| Topology **emits** for Reconciliation | a node subgraph (the actual structure) → consumed by Doctrine 06 as its `right_view`. |
| Topology **emits** for Intent | nothing. Topology does not feed intent — intent is authored independently of any generated graph. (The asymmetry is evidence of separation: a bundled mechanism would have them feed each other, as Backstage's single YAML does.) |
| Topology **reads** from Intent | nothing. Topology derives from source artefacts, never from intent records. An intent record's `wired_to` is a *claim*; topology does not consult it — it independently derives the actual graph, and reconciliation compares the two. |
| Topology **reads** from Reconciliation | nothing. |

Topology's input is *only* source artefacts (database, workflow JSON, code, deploy config). It reads neither sibling mechanism. This is the strongest input-independence of the three.

**(b) Independent-invocability check (mechanical):** "Invoking Topology" = run the emitters over the entity's sources and return the graph. This operation reads ONLY source artefacts + git. It does **not** require reading any intent record and does **not** require running any reconciliation invariant. **Falsifier**: if, at M3, generating the topology graph cannot complete without first reading intent records, this limb fails and topology is not independently invocable — the doctrine count reverts.

**(c) Worked compound-drift example (composition, not bundling):** the same RLS-drop event from Doctrine 04 (A.1 / 12.3c), traced from topology's seat:

1. **Intent** holds the destination promise (authed users access own billing) with `wired_to` naming the RLS policy node. Topology does not read this.
2. **Topology** regenerates from source after the migration that dropped the RLS policy: the `pg_depend` emitter no longer finds the policy, so the RLS node is absent from the new graph. Topology's job is done — it emitted the *actual* current structure, derived and traceable. It does NOT know the RLS node was *supposed* to be there (that is intent's knowledge) and it does NOT flag the absence (that is reconciliation's job).
3. **Reconciliation** joins intent's `wired_to` (`left_view`, expects the RLS node) with topology's current subgraph (`right_view`, RLS node absent) → `verdict: drift`.

Topology did exactly its own job — derive the actual graph — and emitted it through the contracted `right_view` path. It composed with the other two; it did not bundle. A bundled mechanism would have had topology *know the intent* and flag the drift itself — collapsing two mechanisms into one. The separation is what lets topology stay a pure source-derived fact generator.

### 12.4 Test D defence verdict

Topology is separable on all three limbs: schema (25.0-27.8%, robust to consolidation), falsification-condition (the generator-not-author boundary made concrete via the `manual` marker), operational (source-only input — the strongest input-independence of the three, a mechanical invocability check, and a worked compound-drift event resolved by composition). **Separability: EARNED.**

## 13. Real-decision test appendix (Gate 3)

**Pre-nominated case (council A2, sourced from history): the 2026-04-25 property-list-page 27-second timeout** (`loading-state-invariants.md`).

**Actual outcome (locked before applying the doctrine)**: the list page timed out at 27 seconds; counts showed zero; the site was unusable for affected data shapes. Root cause: stale planner statistics on a hot table (`dd_property_enriched`) whose `last_autoanalyze` was NULL since creation. The fix was found by an ad-hoc diagnostic descent (UI → React → query → DB) that eventually ran `EXPLAIN ANALYZE` and `pg_stat_user_tables`.

**Doctrine applied**: run Topology-from-Source's `dependents(dd_property_enriched)` before or during the incident. The `pg_depend` emitter would have returned, in seconds, every view, function, RPC, and RLS policy depending on the hot table — including the list-counts RPC that was timing out — each traceable to its DDL. The doctrine's `provenance` + `dependents` queries make "what is on the hot path of this table?" a one-query, source-traceable answer.

**Counterfactual recommendation**: with topology, the diagnostic order inverts. Instead of descending UI → React → query → DB (90% of the time wasted above the DB, per `loading-state-invariants.md`'s own diagnostic-order rule), the operator queries `dependents(dd_property_enriched)`, immediately sees the counts RPC + the list query on the hot path, and goes straight to the DB-level check (planner stats). The topology mechanism would have surfaced the dependency structure that the incident took manual descent to reconstruct — changing the diagnostic *order* from top-down-guessing to dependency-first.

**Verdict**: PASS (recommendation differs — dependency-first diagnosis vs top-down descent — AND is better-grounded: it cites the specific `dependents` query that collapses the hypothesis space, the concrete-evidence-beats-theory principle from the workshop's own layman-mode rule). Confidence: the case was council-nominated (second party), approaching STRONG-PASS; full STRONG-PASS deferred pending independent confirmation that dependency-first would have beaten the actual descent on wall-clock.

## 14. Deletion test appendix (Gate 1)

**Named downstream consumers**:

1. **The M3 topology mechanism builder** (next milestone). Without this doctrine, the M3 builder re-derives: the node schema (6.1), the multi-emitter pipeline + common shape (6.2-6.3), the generator-not-author boundary (P1) and the source-orphan exception (6.6), the traceability path (6.4), and the degeneracy-declaration discipline (P6/8.4). Every one is a non-trivial design decision the doctrine settles.
2. **The companion topology skill** (M3+). The Section-11 application checklist is the skill's procedure.
3. **Doctrine 06 (Conservation-Law Verification)**. Reconciliation's `right_view` contract (12.3a) is defined here. Without this doctrine, Doctrine 06 would invent the actual-side of its comparison, guessing at what a topology subgraph contains.

**Re-invention specifics** (what each consumer would have to rebuild from scratch without this doctrine):

- The generator-not-author boundary (P1) and its bounded exception (6.6) — without it, M3 would either hand-author topology nodes freely (silently breaching separability) or have no policy for source-orphan elements at all.
- The multi-emitter-into-common-shape architecture (6.2-6.3) — without it, M3 would likely build one monolithic scanner per stack, which does not compose and does not propagate across entities with different stacks (the A.12 / Appendix D failure).
- The node-kind contract (6.5.1) — without it, each emitter would invent its own node shape and the consumer interface would have to branch per emitter (the emitter-coupling anti-pattern, 9.4).
- The `right_view` contract to reconciliation (12.3a) — without it, Doctrine 06 cannot know what shape of actual-structure to expect.

**Verdict**: PASS. Three named consumers, each re-inventing non-trivial content; the four re-invention specifics above are each a multi-decision design problem the doctrine settles once.

## 15. References

### 15.1 Primary sources (topology-from-source patterns)
- PostgreSQL `pg_depend` dependency display — https://wiki.postgresql.org/wiki/Pg_depend_display (the Postgres emitter; cited for the component, not the three-way split)
- dbt `manifest.json` — https://docs.getdbt.com/reference/artifacts/manifest-json (the compile-once-emit-canonical-graph-JSON pattern, the common-shape discipline)
- n8n connections format — https://docs.n8n.io/workflows/components/connections/ (the n8n emitter: the workflow IS the graph)
- dependency-cruiser — https://github.com/sverweij/dependency-cruiser (the TS emitter)
- Lyft Cartography — https://github.com/lyft/cartography (the maximalist multi-source graph store, if a single Neo4j store is later wanted)

### 15.2 Counter-evidence (cited honestly, per F4)
- Backstage `catalog-info.yaml` — https://backstage.io/docs/features/software-catalog/descriptor-format/ — BUNDLES topology with intent in one hand-authored YAML; cited as counter-evidence to the separation. The workshop separates them because topology is generated, not authored.
- Structurizr DSL (C4) — https://docs.structurizr.com/dsl — HAND-AUTHORED topology; cited as the model this doctrine explicitly rejects as a source of truth (3.3) — it belongs to the intent layer as an authored claim to be diffed against the generated graph.

### 15.3 Related workshop artefacts
- `specs/13_INTENT_ACTUAL_GAP_MECHANISM_PROGRAMME.md`, `DESTINATION.md` v2, `specs/research/architecture-blueprint-research-2026-05-22.md`
- `specs/13_M2_DOCTRINE_PLAN.md` (Phase 1 Test D dry-run + grill + council amendments)
- `council/sessions/2026-05-22-m2-doctrine-authoring-plan.md`
- `loading-state-invariants.md` (the 2026-04-25 incident — the Gate 3 case; also the wide-view-as-list-source anti-pattern topology helps detect)
- `n8n-patterns.md` (the HTTP-Request-as-data-sink trap — the A.18 case; the immutable-node-name rule the n8n emitter relies on for stable node ids)
- `verify-shipped` skill (the deploy-vs-source drift class — the A.15 Cedar Hurst case topology makes a first-class signal)
- `docs/operational-doctrine/04_intent-capture.md`, `06_conservation-law-verification.md` (sibling mechanisms)
- `docs/operational-doctrine/02_systems-thinking.md` (the quality + length + structure template this doctrine mirrors)
- `.claude/rules/doctrine-verification-gate.md` (the triple gate)
- `.claude/rules/diagnostic-skill-anti-anchoring.md` (the anti-anchoring pattern the M3 companion skill will carry, since "what depends on X?" can take an operator-supplied hypothesis)

## Status Footer

- **Doctrine**: 05 — Topology-from-Source
- **Status**: authored 2026-05-22 (M2); M2 triple gate — Gate 1 (deletion) PASS, Gate 3 (real-decision) PASS, Gate 2 (code-council) ADVISORY (partial agent return at M2; 3 CRITICAL schema findings patched pre-commit). **Amended 2026-06-01 (M3 Session 5)**: added the `config` kind (vercel.json / package.json) via the doctrine-verification-gate triple gate — Gate 1 (deletion) PASS, Gate 2 (code-council, 9 agents) PASS post-remediation, Gate 3 (real-decision, the live `Gz8…` cloud-vs-repo drift) STRONG-PASS; Test D re-run = unchanged < 50%. Record: `council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md`.
- **Test D**: separability EARNED (schema 25.0-27.8%, falsification-condition via the `manual` marker, operational limb with source-only input + mechanical invocability check + worked compound-drift example). Re-confirmed unchanged at the 2026-06-01 config-kind amendment (see §12 dated re-run row — `config` adds no field, so the field-name sets are unchanged).
- **schema-review-required: before-M3-ships** (A4)
- **Cross-doctrine consistency**: re-run the `doctrine-verification-gate.md` consistency check across doctrines 04/05/06 before any propagation event
- **Companion mechanism**: not yet built (M3) — build order + handoff notes in Appendix E
- **Emitter catalogue**: Appendix C (the M3 emitter contract); **degeneracy matrix**: Appendix D (per-entity expected coverage)
- **Sibling doctrines**: 04 (intent, the `left_view` source), 06 (reconciliation, the `right_view` consumer — pending M2 follow-up)
- **Test D re-run log**: (2026-05-22 — initial computation, all pairs < 50%; 2026-06-01 — config-kind amendment re-run, NO field added, all pairs unchanged < 50% — see §12 dated re-run table; append a dated row on any M3 schema field add/rename)

---

## Appendix A — Worked examples

Eight worked examples. Template: **situation → topology output → detection signal → what the doctrine says → what goes wrong without it → composition trace**.

### A.1 The dependents query that prevents a hot-table outage

**Situation**: an operator is about to add a column to `dd_property_enriched`, a hot table. **Topology output**: `dependents(dd_property_enriched)` returns the list-counts RPC, three views, two triggers, five RLS policies — each traceable to its DDL. **Detection signal**: a non-empty dependents list on a table about to be altered = a change-impact warning. **What the doctrine says** (7.2): query dependents before altering a hot table; the source-derived list is authoritative. **Without it**: the operator alters the table blind; the 2026-04-25 plan-cache-invalidation outage recurs (altering a hot table invalidated cached plans across ~50 backends). **Composition trace**: reconciliation can compare these actual dependents against intent's `wired_to` claims to flag undocumented dependencies.

### A.2 The cross-workflow edge that was invisible

**Situation**: an n8n workflow silently stopped firing; nobody knew what triggered it. **Topology output**: the n8n emitter's cross-workflow edges show Workflow A's Execute-Workflow node targets Workflow B; the trigger chain is explicit. **Detection signal**: a workflow node with no inbound cross-workflow edge = an orphaned trigger. **What the doctrine says** (7.3): the n8n emitter surfaces Execute-Workflow + webhook edges as the cross-workflow graph. **Without it**: the trigger relationship lives only in someone's memory; debugging the silent failure means reading every workflow JSON by hand. **Composition trace**: intent's `wired_to` may claim Workflow A triggers B; topology confirms or refutes from the actual JSON; reconciliation flags the gap if A's Execute node was removed.

### A.3 The source-orphan node, flagged not faked

**Situation**: an infra-only DigitalOcean droplet runs a daemon no `pg_depend`, n8n, or deploy config references. **Topology output**: a node with `emitter: "manual"`, `manual_justification: "infra daemon, no machine-readable source artefact; provenance is the DO console + the deploy runbook"`, review cadence monthly. **Detection signal**: `emitter: "manual"` — queryable, auditable. **What the doctrine says** (6.6): the node is included but explicitly marked as the controlled generator-not-author breach. **Without it**: either the droplet is invisible (incomplete graph) or it is hand-added as a normal node (silent breach — Test D separability degrades undetected). **Composition trace**: the `manual` marker tells reconciliation this node has no generator to catch its drift, so reconciliation applies the special review cadence rather than continuous derivation comparison.

### A.4 Stale graph caught by timestamp

**Situation**: a migration adds a view at commit `abc123`; the graph was last generated before that commit. **Topology output**: a query returns the pre-migration graph (no new view). **Detection signal**: the graph's `timestamp` predates the head `source_commit` of the migrations directory. **What the doctrine says** (8.1, P3): mark the graph stale; regenerate the Postgres emitter. **Without it**: the operator acts on a graph missing the new view; reconciliation compares against stale actual state and produces a false verdict. **Composition trace**: a stale topology poisons reconciliation's `right_view` — the freshness ordering (Doctrine 06's failure mode) depends on topology being regenerated before reconciliation fires.

### A.5 Dimension-degenerate at Nirvana (Postgres-only)

**Situation**: Nirvana Freight has no n8n, no TS frontend, automation in Make.com. **Topology output**: the Postgres emitter produces the schema graph; the n8n, TS, and Vercel emitters produce nothing. **Detection signal**: three emitters report zero nodes; the coverage declaration says "n8n source absent, TS source absent, Vercel source absent." **What the doctrine says** (P6/8.4): declare-and-log the degenerate dimensions; present the Postgres graph as "topology: Postgres-only at this entity," never as a complete topology. **Without it**: the Postgres-only graph looks complete; an operator believes there are no workflow dependencies when really there is no workflow *emitter coverage* (vacuous green). **Composition trace**: reconciliation, told topology is Postgres-only here, scopes its invariants to the schema surface and flags the automation surface as unverifiable.

### A.6 The diagram that wasn't topology

**Situation**: a previous effort produced a hand-drawn Mermaid architecture diagram and called it the topology. **Topology output**: none queryable — the diagram is a PNG-equivalent. **Detection signal**: "what depends on table X?" requires a human to read the image. **What the doctrine says** (P5/8.3): a rendered diagram is not topology; emit the structured graph, render diagrams downstream. **Without it**: reconciliation cannot consume the diagram; AI sessions cannot query it; the destination's Condition 1 (structured answers) fails. **Composition trace**: only a machine-addressable graph can serve as reconciliation's `right_view`; a diagram cannot be joined to intent's `wired_to`.

### A.7 The ambiguous-provenance node

**Situation**: a Postgres function is also deployed as a Supabase edge function; both the `pg_depend` emitter and a deploy emitter claim it. **Topology output**: two nodes, same logical identity, different `emitter`. **Detection signal**: two nodes resolving to the same element with conflicting `emitter` values (8.5, P4). **What the doctrine says**: define the canonical emitter for that element class; the other references it by id. **Without it**: provenance is ambiguous; `provenance(node)` returns two answers; traceability (P2) breaks. **Composition trace**: reconciliation needs one authoritative actual-node per element to compare against one intent claim; ambiguous provenance produces ambiguous verdicts.

### A.8 The /autovibe subgraph slice

**Situation**: an `/autovibe` session begins a billing change and asks `subgraph(billing)`. **Topology output**: the billing-area node graph (tables, functions, the edge function, the route) with edges and provenance — not the whole graph. **Detection signal**: a bounded subgraph returned, sized to the task. **What the doctrine says** (6.5/10.3): partial-readability bounds the session's context; it gets exactly the billing structure, traceable, current. **Without it**: the session loads the whole topology (context blow-up) or re-discovers the billing architecture from raw source (the re-discovery cost Condition 6 forbids). **Composition trace**: the session hands the billing subgraph to reconciliation as `right_view` and intent's billing `wired_to` as `left_view`, getting a per-promise verdict — the canonical three-mechanism composition at full speed.

### A.9 Incremental regeneration after a single migration

**Situation**: a developer adds one migration creating a new view; the rest of the schema is unchanged. **Topology output**: only the Postgres emitter re-runs (its source — the migrations directory — changed); the n8n, TS, and Vercel subgraphs are reused unchanged. **Detection signal**: one emitter's source commit advanced; the others' did not. **What the doctrine says** (P3, A4): regenerate incrementally — re-run only the emitter whose source changed — to keep re-derivation within the destination's "in seconds" budget. Incremental *regeneration* is allowed; incremental *editing* (P3) is not. **Without it**: either the whole graph regenerates on every tiny change (slow, breaking the seconds budget) or the graph is hand-patched with the new view (forbidden — drifts from source). **Composition trace**: reconciliation queries the freshly-regenerated Postgres subgraph as `right_view`; because regeneration was scoped, the freshness ordering (Doctrine 06 failure mode) is satisfied cheaply.

### A.10 The deploy-config route that points nowhere

**Situation**: a Vercel route in the deploy config points to an edge function that was renamed in a later commit. **Topology output**: the Vercel emitter emits a route node whose `depends_on` references an edge-function node id that the Postgres/edge emitter no longer produces (the function was renamed). **Detection signal**: a `depends_on` edge whose target node id does not exist in the current graph — a dangling edge. **What the doctrine says** (P2, P4): the route node traces to the deploy config (its source); the dangling edge is a real, source-derived fact (the config genuinely points at a now-missing function). Topology reports it faithfully; it does not "fix" it (9.1). **Without it**: the dangling route is invisible until a user hits a 404; no source-derived signal surfaces the broken wiring. **Composition trace**: reconciliation compares the route's intended target (intent's `wired_to`) against the actual dangling edge (topology's `right_view`) and emits `drift` with `named_action: revert` (restore the function name) or `reconcile` (update the route).

### A.11 The RLS policy that exists but is disabled

**Situation**: a row-level-security policy exists in the schema but was disabled (not dropped) by a migration. **Topology output**: the `pg_depend` emitter emits the RLS-policy node (it still exists) with an `attributes` field recording `enabled: false`. **Detection signal**: an `rls_policy` node present in the graph but with `attributes.enabled = false`. **What the doctrine says** (6.1 `attributes`): the node-kind-specific payload (`attributes`) carries the enabled/disabled state derived from the catalogue; the node is present (it exists) but its attribute records that it is inert. Presence ≠ effectiveness. **Without it**: a graph that only records node existence would show the policy as present and imply protection that is actually disabled — a dangerous false sense of security. **Composition trace**: reconciliation comparing intent ("authed users access own billing, enforced by this RLS policy") against topology sees the policy node present but `enabled: false`, and emits `drift` with `named_action: escalate` (a security control is silently inert) — a subtler drift than outright deletion that only the attribute-level derivation catches.

### A.12 Cross-entity propagation (the same emitters, a different stack)

**Situation**: the topology mechanism propagates from the workshop to Agency-Main, whose stack includes the KI pipeline (heavy Supabase + n8n) but a different frontend arrangement. **Topology output**: the Postgres + n8n emitters produce rich graphs; the TS emitter's coverage differs; the Vercel emitter may be absent. **Detection signal**: the coverage declaration lists which emitters found source at this entity — different from BuyBox-AI's profile. **What the doctrine says** (P6, stack-agnosticism / destination Condition 5): the emitters are stack-agnostic — `pg_depend` reads any Postgres, the n8n parser reads any workflow JSON — and the coverage declaration makes the per-entity profile explicit. The mechanism does not assume one entity's stack. **Without it**: a mechanism hard-coded to BuyBox-AI's emitter set would silently under-cover Agency-Main and the propagation would peel off (Condition 7 failure). **Composition trace**: the per-entity coverage declaration propagates to reconciliation, which scopes its invariants to the emitters that actually ran — the same stack-agnostic discipline all three mechanisms share.

---

### A.13 The trigger that depends on a dropped function

- **Situation**: a database trigger fires a function; a migration drops the function but leaves the trigger.
- **Topology output**: the trigger node's `depends_on` references a function node id that `pg_depend` no longer produces.
- **Detection signal**: a `trigger` node with a dangling `depends_on` edge (target id absent from the graph).
- **What the doctrine says** (P2, 8.5): the trigger traces to its DDL; the dangling edge is a real source-derived fact (the catalogue genuinely records a trigger pointing at a dropped function — a latent runtime error).
- **Without it**: the broken trigger surfaces only when it next fires and errors; no source-derived signal warns of it.
- **Composition trace**: reconciliation flags the dangling edge against any intent that promised the trigger's behaviour, with `named_action: escalate` (a latent error in a derived dependency).

### A.14 The materialized view that is stale at the source level

- **Situation**: a materialized view caches an expensive aggregate; its base tables changed but the view was not refreshed.
- **Topology output**: the `view` node carries `attributes.is_materialized: true` + a `last_refresh` derived from the catalogue, plus `depends_on` edges to its base tables.
- **Detection signal**: a materialized-view node whose `last_refresh` predates the `source_commit` of a base table it depends on.
- **What the doctrine says** (6.1 attributes): the materialization state is a derived attribute; topology reports the staleness as a structural fact without judging it (judging is reconciliation's job).
- **Without it**: the stale aggregate serves wrong numbers and nothing structural surfaces the staleness.
- **Composition trace**: reconciliation treats "materialized view older than its base tables" as a derivation-class invariant breach → `named_action: reconcile` (refresh the view).

### A.15 The edge function deployed from a stale commit (the Cedar Hurst class)

- **Situation**: an edge function's deployed version is older than the function source in the repo (source-vs-deployed drift).
- **Topology output**: the `edge_function` node carries `attributes.deployed_commit`; the node's `source_commit` (repo) differs from `deployed_commit` (live).
- **Detection signal**: `source_commit ≠ deployed_commit` on an edge-function node.
- **What the doctrine says** (P2): topology derives BOTH the repo provenance and the deployed provenance and records the divergence as a fact — it does not reconcile them.
- **Without it**: the deployed-vs-source drift is invisible (the exact silent-killer class the workshop's `verify-shipped` skill exists to catch) until behaviour diverges from the code under review.
- **Composition trace**: reconciliation compares `source_commit` vs `deployed_commit` as a versioning-class invariant → `drift` with `named_action: reconcile` (redeploy) or `escalate` (if the divergence is consequential). This is the topology-side input that makes deploy-drift a first-class, source-derived signal rather than a manual audit.

### A.16 The repo migration that was never applied (live-vs-repo, the A6 case)

- **Situation**: a migration file exists in the repo declaring a new index, but it was never applied to the live database.
- **Topology output**: the `pg_depend` emitter reads the LIVE catalogue (A6) — the index node is absent, because the live database does not have it.
- **Detection signal**: a repo migration declares an object the live-derived graph does not contain.
- **What the doctrine says** (A6): topology reports the live source-of-truth (the index is genuinely not there), not the repo's aspiration. The repo-vs-live gap is real and is reconciliation's to flag.
- **Without it**: an operator trusts the migration file and assumes the index exists; queries stay slow; the unapplied migration is invisible.
- **Composition trace**: reconciliation takes the repo migrations as one view and topology's live graph as the other → `drift` (migration declared, not applied) with `named_action: reconcile` (apply it) — the inverse of the deployed-from-stale-commit case (A.15).

### A.17 The fan-in node that reconciliation will rank by impact

- **Situation**: a single base table is depended on by 40 downstream objects (a high fan-in hub).
- **Topology output**: the table node's `depended_on_by` lists all 40; the fan-in count is derivable from the edge list.
- **Detection signal**: a node with a large `depended_on_by` cardinality — a structural impact hub.
- **What the doctrine says** (7.2): topology surfaces the fan-in faithfully; the *ranking* of impact (which drift matters most) is reconciliation's job, but it is computed FROM topology's edge counts.
- **Without it**: drift on the hub table is treated with the same urgency as drift on a leaf node; impact-ranking (destination Condition 2) has no structural basis.
- **Composition trace**: reconciliation's `impact_rank` field (Doctrine 06) is computed by walking topology's `depended_on_by` from the drifted node — the fan-in count IS the impact signal. Topology supplies the structure; reconciliation supplies the ranking; intent supplies which promises the hub serves.

### A.18 The HTTP-Request node that breaks the n8n data lineage

- **Situation**: an n8n workflow has an HTTP Request node mid-chain; downstream nodes reference upstream data that the HTTP node replaced (a known n8n data-sink trap).
- **Topology output**: the n8n emitter emits the connection edges faithfully (node A → HTTP node → node C); the `attributes` of the HTTP node record `node_type: httpRequest`.
- **Detection signal**: a downstream node referencing upstream data across an HTTP Request node — a structural lineage break the connection graph makes visible.
- **What the doctrine says** (n8n emitter, 6.2): topology emits the *declared* connection structure; the HTTP-node-as-data-sink hazard is visible as a node-type attribute on the path, lettable a consumer reason about lineage breaks.
- **Without it**: the lineage break lives only in the n8n patterns rule and an engineer's memory; nothing structural surfaces which downstream nodes are at risk.
- **Composition trace**: an intent record may promise "the classification flows to the database write"; topology shows the HTTP node sits between them; reconciliation can flag the lineage-break risk where intent claims a data path that crosses a data sink.

## Appendix B — Quick-reference operator card

| You observe | It means | Doctrine action |
|-------------|----------|-----------------|
| Node `timestamp` predates its `source_commit` | Stale graph (8.1) | Regenerate the affected emitter; don't serve stale |
| Node's `source_file`/`source_line` don't contain the declared element | Source-orphan masquerade (8.2) | Mark `emitter: "manual"` + justify, or remove |
| "What depends on X?" needs reading a diagram | Diagram-as-topology (8.3) | Emit the structured graph; render downstream |
| Emitter returns zero nodes | Degenerate OR genuinely empty (8.4) | Declare which; never conflate absent-source with no-dependencies |
| Two nodes, same element, different `emitter` | Ambiguous provenance (8.5) | Pick the canonical emitter; other references by id |
| A node with no source artefact and no `manual` marker | Silent generator-not-author breach (9.3) | Add `emitter: "manual"` + justification + review cadence |
| A topology node annotated with what it "should" do | Topology-states-intent overreach (9.7) | Move the claim to an intent record |
| Runtime trace data merged into the declared graph | Runtime-as-declared confusion (9.8) | Keep runtime as a separate overlay |
| Whole graph regenerates on a one-line source change | Whole-graph regeneration (9.9) | Incremental regeneration — only the changed emitter |
| Node recorded as present but its disabled state is lost | Existence-equals-effectiveness (9.10) | Derive effectiveness into `attributes`; presence ≠ effective |
| `depends_on` edge target id does not exist in the graph | Dangling edge (A.10) | Report faithfully; reconciliation flags revert/reconcile |
| Same element claimed by `pg_depend` and a deploy emitter | Ambiguous provenance (8.5) | Canonical emitter owns it; other references by id |

## Appendix C — The emitter catalogue (M3 reference)

The emitters the M3 mechanism implements, each independently runnable (P4):

| Emitter | Source read | Node kinds produced | Provenance | Fit |
|---------|-------------|---------------------|------------|-----|
| `pg_depend` | Postgres system catalogue (`pg_depend` + `information_schema`) | table, view, function, trigger, rls_policy | migration file + DDL + commit | highest (Supabase IS Postgres; one query/project) |
| `n8n_parser` | workflow JSON `connections` object | workflow, workflow_node | workflow JSON file + node id + commit | high (n8n is a workshop runtime) |
| `dependency_cruiser` | `*.ts/*.tsx` imports | ts_module | file + line + commit | medium (single-language; TS layer only) |
| `vercel_api` | deployed routing config | route → function edges | deploy id + route config key | medium (greenfield emitter work) |
| `manual` | none (the bounded exception, 6.6) | any (source-orphan) — incl. the `config` kind (deploy config + dependency manifest files have a named source artefact but no machine dependency-emitter in v1) | `manual_justification` + review cadence | exception only — flagged + audited |

Each emitter writes into the common manifest shape (6.3). The pipeline composes by union; incremental regeneration (P3/9.9) re-runs only the emitter whose source changed. New source types (a future Make.com emitter, an Airtable emitter) are added as new emitters without touching the others — the multi-emitter design is open for extension, closed for modification of existing emitters.

## Appendix D — Degeneracy matrix across the canonical entities

Topology coverage differs per entity stack. The matrix below is the M3/M4 expectation — it tells the proving run what "complete coverage" means at each entity, so a degenerate dimension is *expected and declared* (P6/8.4), never mistaken for an empty system:

| Entity | pg_depend | n8n_parser | dependency_cruiser | vercel_api | Expected degenerate |
|--------|-----------|------------|--------------------|------------|---------------------|
| BuyBox-AI | rich | present | rich (React/Vite) | present | none |
| Agency-Main | rich (KI pipeline) | rich | partial | partial | possibly Vercel |
| Nirvana Freight | present | ABSENT (Make.com) | ABSENT (vendor app) | ABSENT | n8n, TS, Vercel — Postgres-only topology expected |

At Nirvana, a Postgres-only topology is the *correct* output, declared as such — not a failure. The matrix is the reference that prevents the vacuous-green-light failure (8.4) at propagation: an operator at Nirvana sees "topology: Postgres-only (n8n/TS/Vercel emitters: no source at this entity)" and knows that is expected, not broken.

## Appendix E — M3 handoff notes

For the M3 session that builds the topology mechanism from this doctrine:

- **Build order** (from the principle-interaction analysis): the `pg_depend` emitter first (highest fit, zero new infrastructure, validates the common-shape contract against the richest source), then the n8n emitter (the second workshop runtime), then the common-shape consumer interface (6.5), then the remaining emitters.
- **The common shape is the contract** (6.3): build it before any second emitter, so the second emitter targets a fixed shape rather than co-evolving with the first.
- **`schema-review-required: before-M3-ships`**: the first M3 step is to re-read this doctrine and confirm the node schema (6.1) + node-kind table (6.5.1) match what the implementation will actually expose. Flag any field the implementation will not produce — that flag triggers a Test D re-run (12.2).
- **The source-orphan exception (6.6) is the one place hand-authoring is allowed** — build the `emitter: "manual"` path with the mandatory `manual_justification` + review cadence, and make `manual` nodes queryable so they can be audited.
- **Incremental regeneration (P3/9.9) is a performance requirement, not a nicety** — the destination's "in seconds" budget (Condition 1) depends on re-running only the changed emitter; design the pipeline so each emitter's output is independently cacheable and replaceable.
- **The contracted output to reconciliation (12.3a) is `right_view`** — expose `subgraph(filter)` so Doctrine 06 can request exactly the actual-structure slice it needs to compare against intent's `wired_to`.
