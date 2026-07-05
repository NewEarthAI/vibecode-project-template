# Topology Substrate — Canonical Shape (schema source-of-truth)

> **Authority**: this file is derived VERBATIM from `docs/operational-doctrine/05_topology-from-source.md`
> §6.1 (the topology node) + §6.3 (the common graph shape) + §6.5.1 (the node-kind contract) + §6.6 (the
> source-orphan exception). It is the M3-v1 write-surface contract every topology emitter (M3 Sessions 2-5)
> targets and the health-check skill (M3 Session 6) reads.
>
> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 1. Spec `specs/14_NEWEARTH_MASTER_BLUEPRINT_BUILD_PLAN.md` §4.2.
> Contract `.claude/rules/intent-actual-gap-mechanism-alignment.md`. Doctrine cross-check `council/audits/2026-05-22-cross-doctrine-consistency-04-05-06.md`.

---

## LOAD-BEARING FINDING — why the node is 10 fields, not 17 (recorded for audit)

The M3-Session-1 continuation (`continuations/M3-SESSION-1-TOPOLOGY-SUBSTRATE-CONTINUATION-2026-05-23.md` §6)
carried a schema placeholder that embedded **17 reconciliation fields per topology node**. The mandated
`schema-review-required: before-M3-ships` doctrine re-read found this is a **conflation**, and the doctrines are
authoritative:

- Doctrine 06's **17 fields** are the **invariant record** — the output of the *reconciliation mechanism* (M4
  work). Doctrine 06 §6.1 + Appendix E confirm those fields belong to the comparator; reconciliation *reads*
  topology as its `right_view` (06 §3.2, §12.3a) and **never** pushes its fields into topology nodes.
- Doctrine 05 §6.1 defines the **topology node** as exactly **10 fields** (listed below).
- The cross-doctrine consistency audit (Check 1 + Check 6) establishes all three mechanisms share **only the
  5-field provenance envelope**, with deliberately divergent payloads — pairwise Jaccard overlap is
  Topology∩Intent 27.8%, Topology∩Reconciliation 22.7%, all far below the 50% separability ceiling.

Embedding Doctrine 06's 17 reconciliation fields into every topology node would **collapse the separability the
entire programme exists to earn** — a direct breach of the programme contract's "separability is EARNED, never
assumed" rule (alignment contract §programme-specific-load-bearing-rule).

**Resolution (no doctrine edit — the doctrines are internally consistent; only the continuation placeholder was
wrong)**: the substrate node carries Doctrine 05's **10 fields** plus **one forward-hook** — a nullable
`declared_intent_ref` pointer (null until M4 wires it) named by the continuation §8 Doctrine-Compliance-Map as
the sole intent linkage v1 needs. Reconciliation's 17-field records remain a **separate M4 record type** that
reads this substrate; they are not stored inside it.

---

## Top-level substrate shape

Doctrine 05 §6.3 mandates the canonical `{nodes, parent_map, child_map}` graph shape (the dbt `manifest.json`
discipline). The workshop wraps it in a thin heartbeat + coverage envelope required by the Reliability Engineer's
staleness audit (spec 14 §4.3) and Doctrine 05 Principle 6 (declared coverage, logged degeneracy).

```json
{
  "schema_version": "m3-v1",
  "entity": "<entity name, e.g. my-project>",
  "last_updated": "<ISO 8601 UTC — auto-bumped on every write>",

  "emitters": {
    "code":          {"last_emitted_at": "<ISO 8601 UTC | null>", "coverage": "<coverage enum>"},
    "supabase-live": {"last_emitted_at": "<ISO 8601 UTC | null>", "coverage": "<coverage enum>"},
    "n8n-cloud":     {"last_emitted_at": "<ISO 8601 UTC | null>", "coverage": "<coverage enum>"}
  },

  "missing_emitters": [
    {"name": "airtable",            "reason": "M4+ JV-partner scope (spec 14 §3)"},
    {"name": "follow-up-boss",      "reason": "M4+ JV-partner scope (spec 14 §3)"},
    {"name": "homepros-podio",      "reason": "M4+ — TRUE GAP, no Podio MCP; REST integration needed (spec 14 §3)"},
    {"name": "vercel-deploy-state", "reason": "M4+ — Vercel API integration (spec 14 §3)"},
    {"name": "external-api-graph",  "reason": "M4+ — edge-function static analysis needed (spec 14 §3)"}
  ],

  "nodes": [ /* array of topology nodes — see "Node shape" below */ ],
  "edges": [ /* array of edges — see "Edge shape" below */ ],

  "parent_map": { "<node_id>": ["<parent_node_id>", "..."] },
  "child_map":  { "<node_id>": ["<child_node_id>",  "..."] }
}
```

### Top-level envelope field meanings

| Field | Meaning | Source |
|---|---|---|
| `schema_version` | the substrate contract version; `validate-schema` checks against it | workshop (versioning discipline) |
| `entity` | which entity this substrate maps (my-project at M3-v1) | spec 14 §3 |
| `last_updated` | top-level heartbeat, auto-bumped on ANY write; the health-check skill reads it | spec 14 §4.3 (Reliability Engineer heartbeat) |
| `emitters.<name>.last_emitted_at` | per-emitter heartbeat; health-check surfaces "emitter X stale by N hours" | spec 14 §4.3 |
| `emitters.<name>.coverage` | per-emitter coverage classification (enum below) | D05 Principle 6 / §8.4 |
| `missing_emitters` | the 5 declared-coverage MISSING_EMITTER markers; makes absence operator-visible | D05 P6 + spec 14 §3 P6 markers |

**`coverage` enum** (per D05 P6 / §8.4 — degeneracy must be logged distinctly from emptiness):

| value | meaning |
|---|---|
| `covered` | the emitter ran and found source it could read |
| `absent` | the source type does not exist at this entity (e.g. your project has no n8n) — D05 §8.4 |
| `degenerate` | the source exists but is unreadable (access missing) — D05 A5 (distinct from `absent`) |
| `declared-missing` | the emitter has not yet run on THIS substrate (run it to populate). The default for all 3 at `init`. The substrate is ephemeral: a prior session may have proven coverage (e.g. S2 emitted 1,143 nodes, S3 emitted 280) but a fresh `init` resets every slot to this state — so `declared-missing` means "not yet run against this substrate instance", NOT "the emitter does not exist". (Amended M3 Session 6: the original gloss "not yet built" was accurate at Session 1 when the emitters were genuinely unbuilt; by Session 6 all 4 are built — the health-check reports this value as "emitter built, not yet run on this substrate".) |

At M3-v1 `init`, all three emitters start at `coverage: "declared-missing"`, `last_emitted_at: null`.

**Why exactly 5 `missing_emitters`, not 6**: spec 14 §3 lists a sixth deferred item — runtime tracing
(Sentry / PostHog) — but it is NOT a `missing_emitters` entry. Runtime tracing is **out of scope** for topology
entirely (D05 §3.5: declared structure vs observed execution are different signal classes), not a deferred-but-
planned emitter. The 5 markers are JV-partner/integration emitters that WILL be built at M4+; runtime tracing is
a separate future mechanism, never a topology emitter.

---

## Node shape — Doctrine 05 §6.1 (the 10 fields, VERBATIM) + 1 forward-hook

```json
{
  "id":              "<stable node identity>",
  "kind":            "<node kind — see kind enum>",
  "source_file":     "<file / DDL / workflow JSON that produced the node>",
  "source_commit":   "<commit the node's source was last changed in>",
  "timestamp":       "<ISO 8601 UTC — when THIS graph was generated (derivation time)>",
  "source_line":     "<integer line within source_file | null>",
  "emitter":         "<which generator produced it — see emitter enum>",
  "depends_on":      ["<node_id>", "..."],
  "depended_on_by":  ["<node_id>", "..."],
  "attributes":      { /* typed per-kind payload — see §6.5.1 */ },

  "declared_intent_ref": null
}
```

### Field-by-field (with Doctrine 05 §6.1 cross-references)

| # | Field | Envelope/payload | Doctrine cross-ref | Notes |
|---|---|---|---|---|
| 1 | `id` | envelope | D05 §6.1 | stable identity; the shared 5-field provenance envelope (audit Check 1) |
| 2 | `kind` | envelope | D05 §6.1 | one of the kind enum below |
| 3 | `source_file` | envelope | D05 §6.1, P2 | the artefact the node was derived from |
| 4 | `source_commit` | envelope | D05 §6.1, P2 | commit the source last changed in (git commit-time, not wall-clock — D06 A11) |
| 5 | `timestamp` | envelope | D05 §6.1, §8.1 | generation time; the **freshness signal** — a node whose `timestamp` predates its `source_commit` is stale (D05 §8.1) |
| 6 | `source_line` | payload | D05 §6.1, P2 | line within `source_file` (nullable where not line-addressable) |
| 7 | `emitter` | payload | D05 §6.1, P4 | exactly one emitter owns each node (P4: one node, one emitter) |
| 8 | `depends_on` | payload | D05 §6.1, §6.5 | outgoing-edge node ids |
| 9 | `depended_on_by` | payload | D05 §6.1, §6.5, A.17 | reverse-edge node ids; the fan-in count IS the impact signal D06's `impact_rank` walks |
| 10 | `attributes` | payload | D05 §6.1, §6.5.1, §9.10 | **typed per-kind** object — presence ≠ effectiveness (the `enabled` flag on `rls_policy` is what catches the disabled-policy drift, D05 A.11) |
| + | `declared_intent_ref` | forward-hook | continuation §8; D04 §6.3 | nullable pointer to a Doctrine 04 intent record; **always null at M3-v1**; M4 wires it. The ONLY non-§6.1 node field, and it is a *pointer*, never a reconciliation payload field. |

The first **5 fields** (`id`, `kind`, `source_file`, `source_commit`, `timestamp`) are the **provenance envelope**
shared with Doctrines 04 and 06 (audit Check 1). The next **5** (`source_line`, `emitter`, `depends_on`,
`depended_on_by`, `attributes`) are the topology-specific payload that distinguishes this mechanism (D05 §12.1 —
they appear in no other mechanism's schema).

### `kind` enum (Doctrine 05 §6.1 + §6.5.1)

```
table | view | function | trigger | rls_policy | edge_function | workflow | workflow_node | ts_module | config | external_endpoint
```

(`config` was added M3 Session 5 for declared-structure config files — `vercel.json` / `package.json` — via the doctrine-verification-gate triple gate; record: `council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md`. A `config` node is always `emitter: "manual"` + `manual_justification`.)

(`external_endpoint` was added 2026-06-05 by the **visual-layer schema delta** — the cross-system dependency-edge layer + its blind-spot honesty marker — via the same triple gate; record: `council/code-reviews/2026-06-05-visual-layer-schema-delta.md`. See "The `external_endpoint` kind" note below.)

`manual` is an EMITTER value (the source-orphan class, §6.6 — see below), NOT a kind — every node, including a config node, carries one of the kinds above.

### `emitter` enum (Doctrine 05 §6.1 + Appendix C)

```
pg_depend | n8n_parser | dependency_cruiser | vercel_api | manual | external_api_parser
```

(`external_api_parser` added 2026-06-05 with the visual-layer delta — owns `external_endpoint` nodes emitted by the `external-api-graph` emitter. See the joint-attribution exception in the `external_endpoint` note below.)

### Typed per-kind `attributes` (Doctrine 05 §6.5.1 — the M3 emitter contract)

The substrate must NOT enforce a single flat `attributes` shape — each `kind` carries its own typed payload.
`validate-schema` accepts the per-kind variation; emitters populate the kind-appropriate keys.

| kind | key `attributes` (D05 §6.5.1) |
|---|---|
| `table` | `columns`, `row_estimate` |
| `view` | `is_materialized`, `definition_hash` |
| `function` | `language`, `volatility` |
| `trigger` | `timing`, `event` |
| `rls_policy` | `enabled`, `command`, `role` (the `enabled` flag is the A.11 disabled-policy signal) |
| `edge_function` | `runtime`, `deployed_commit` (the A.15 Cedar-Hurst deploy-drift signal) |
| `workflow` | `active`, `trigger_type` |
| `workflow_node` | `node_type`, `position` |
| `ts_module` | `is_entry`, `export_count` |
| `config` | `config_type` + per-type summary (vercel: `header_count`, `rewrite_count`, `redirect_count`; package: `dependency_count`, `dev_dependency_count`, `script_count`, `dependencies`) — always `emitter: "manual"` + `manual_justification` |
| `external_endpoint` | `url_host`, `url_path_template`, `method`, `classification` (`supabase-rest` / `supabase-function` / `external-api` / `blind-spot`). A `blind-spot` classification means the wiring target is runtime-constructed/unresolvable (D05 §3.5) — rendered amber, never green, never dropped. Emitter is `external_api_parser` (1b n8n URLs) OR `dependency_cruiser` (1a frontend blind-spots + follow-up #1 `fetch()` endpoints — the documented joint-attribution exception). |

### Source-orphan rule (Doctrine 05 §6.6 — the one place hand-authoring is allowed)

A node may carry `emitter: "manual"` ONLY IF it also carries a non-empty `manual_justification` string (why no
machine-readable source artefact exists). This converts a silent generator-not-author breach into a logged,
queryable, review-gated exception (D05 §6.6, §8.2). `validate-schema` enforces this conditional: a `manual` node
without `manual_justification` is a schema violation.

---

## The `external_endpoint` kind + cross-system edges (visual-layer delta, 2026-06-05)

> **Added by the visual-layer schema delta** (downstream application #1 of the Intent-Actual-Gap
> mechanism) via the doctrine-verification-gate triple gate; record:
> `council/code-reviews/2026-06-05-visual-layer-schema-delta.md`. Doctrine 05 §6.5.1 carries the
> matching kind-enum row + note.

The visual layer's headline feature is **cross-system dependency edges** — wiring that crosses a
system boundary (frontend `ts_module` → Supabase `table`/`edge_function`; n8n `workflow_node` →
Supabase REST; edge function → external API). These are **statically derivable from source**
(~65–70% of real cases per the M1 feasibility scout); the rest is runtime-constructed and out of
reach (D05 §3.5).

**The two honesty boundaries this kind enforces (LOCKED — `/reduce-to-first-principles` reframe,
plan §"framing audit"):**

1. **Declared-wiring-only + blind-spots, never green, never dropped.** A cross-system edge target
   that resolves to a real substrate node id is a real edge carrying a `confidence` (see
   `edge.attributes` below). A target that is **runtime-constructed / unresolvable** (an env-var URL,
   a `supabase.from(variable)`, a computed function name) is rendered as a **`blind-spot`
   `external_endpoint` node** (amber, hollow) — it is **never silently dropped** (that reads as "no
   connection") and **never green**. The map never claims a complete cross-system picture.

2. **The blind-spot routing rule (R2 — fail safe toward visibility):** when an emitter cannot resolve
   a cross-system target against the live substrate node-id set:
   - emit a `blind-spot` `external_endpoint` node (and an edge to it) **whenever the relevant source
     emitter's coverage is NOT definitively `covered`** — i.e. `declared-missing`, `degenerate`,
     `absent`, the emitter key absent, or a null coverage read. Fail toward the amber marker.
   - record a **counted drop** (a logged diagnostic, no node, no edge) **only when** that source
     emitter's coverage is definitively `covered` — then an unresolved target is a genuine dangling
     reference the operator should see as a diagnostic, not a blind-spot.
   This fail-safe direction is deliberate: an absent/unknown coverage state can NEVER cause a silent
   drop (the M3 `owned_but_uncovered` / M4 dead-freshness silent-failure class).

**Joint-attribution exception (Doctrine 05 P4 — one node, one emitter):** the `external_endpoint`
*kind* has two legitimate producers. The `external-api-graph` emitter (Phase 1b, `external_api_parser`)
**owns** the kind and emits classified endpoints from **n8n HTTP-node URLs**. The code emitter (Phase 1a +
follow-up #1, `dependency_cruiser`) **also** emits `external_endpoint` nodes — `blind-spot` markers for
unresolved frontend Supabase targets, and (follow-up #1) classified `external-api` + `blind-spot` endpoints
for **edge-function / frontend `fetch()` calls** (detection lives in the code emitter because only it parses
the TypeScript source; the fetch URL classifier is pinned to the n8n `classify_url` by a parity eval). Each
*node* still carries exactly one emitter (P4 holds at the node level); the *kind* has two producers. This is
**recorded as a named exception** so the health-check's `owned_but_uncovered` anomaly detector does NOT fire
when `external-api-graph` has not yet run live (M5-gated) but `external_endpoint` nodes already exist from a
code-emitter-only run. It is an exception, not a normalisation: no other kind has two producers.

## Edge shape

```json
{
  "source":     "<node_id>",
  "target":     "<node_id>",
  "type":       "<contains | imports | calls | triggers | depends_on | reads_from | writes_to | invokes | ...>",
  "direction":  "forward",
  "weight":     1,
  "attributes": null
}
```

`write-edge` enforces referential integrity: both `source` and `target` MUST already exist in `nodes`, or the
write fails loud (exit nonzero). A dangling edge is a real source-derived fact only at the *emitter* level
(D05 A.10 / A.13); at the *substrate* level we reject edges whose endpoints are not present, so the graph is
always internally consistent. (Emitters that observe a genuinely dangling source reference record it via a
`manual`/attribute signal on the node, not via an orphan edge.) **This is exactly why an unresolved
cross-system target must be materialised as a `blind-spot` `external_endpoint` node first, then the edge drawn
to it — the integrity check makes "never silently drop" structurally enforced, not merely a convention.**

**`type`** is free-form. The visual-layer delta documents **four cross-system edge type values** (no code
change — `type` was already free-form): `reads_from`, `writes_to`, `calls`, `invokes`.

**`edge.attributes`** (additive, nullable — **no `substrate.sh` change**, the edge writer already passes
arbitrary fields through). On a **cross-system edge** it is mandatory and carries:

```json
{ "derivation": "<one-line how this edge was derived from source>",
  "confidence": "declared-high | declared-medium | blind-spot" }
```

| `confidence` | meaning | render |
|---|---|---|
| `declared-high` | ≈95% — a static string literal resolved to a known node id (e.g. `supabase.functions.invoke('foo')` → `repo:supabase/functions/foo`) | solid, confident |
| `declared-medium` | ≈70% — a heuristic / queryKey inference (e.g. `supabase.from('deals')` → `public.deals`) | visibly less confident |
| `blind-spot` | runtime-constructed / unresolvable target (D05 §3.5) | dashed + amber, incident to a `blind-spot` `external_endpoint` |

A within-system edge carries `attributes: null` (or omits it) — only cross-system edges carry the
`{derivation, confidence}` payload. This is **topology-only payload** (it does not appear in the intent or
reconciliation schemas), so it strengthens — never threatens — Test-D separability (see the Doctrine 04 §12.1
re-run row dated 2026-06-05).

---

## `parent_map` / `child_map` — derived, redundant views (Doctrine 05 §6.3)

`parent_map` and `child_map` are **redundant views derived from the nodes' `depends_on` / `depended_on_by`**, kept
in the substrate for fast traversal. They are recomputed **inside a single jq pass on every write**, so they can
**never drift** from the `nodes` array by construction:

- `child_map[N]` = the list of nodes `N` depends on (forward) — i.e. `N`'s `depends_on`.
- `parent_map[N]` = the list of nodes that depend on `N` (reverse) — i.e. `N`'s `depended_on_by`.

`validate-schema` re-derives both maps from `nodes` and asserts equality with the stored maps; a mismatch is a
schema violation (catches any out-of-band hand edit).

> **Naming note**: this substrate adopts the literal Doctrine 05 §6.3 names `parent_map` / `child_map`. "Parent"
> = depended-on-by (the things above you that rely on you); "child" = depends-on (the things below you that you
> rely on). Emitters and the health-check skill MUST use these names verbatim — they are part of the frozen
> contract.

---

## Helper API (implemented in `scripts/substrate.sh`)

| Helper | Purpose | Lock |
|---|---|---|
| `init <entity>` | create empty substrate if absent (idempotent); seed 5 `missing_emitters` + 3 `emitters` at `declared-missing`/null | write |
| `write-node <node-json>` | atomic single-node upsert; bump `last_updated`; recompute maps | write |
| `write-edge <edge-json>` | atomic single-edge add; both-endpoints-exist integrity check; recompute maps | write |
| `bulk-write <nodes-json> <edges-json>` | single locked batch write (emitter efficiency); recompute maps once | write |
| `mark-emitter-ran <name> <coverage>` | set `emitters.<name>.last_emitted_at = now` + coverage; reject unknown name | write |
| `read-topology [jq-filter]` | validate + print substrate (optional jq projection) | read |
| `validate-schema` | full structural assertion (frozen keys, map equality, manual→justification); PASS or violation list | read |

> **Emitters MUST use `bulk-write` for a full emitter run.** `write-node` / `write-edge` are interactive
> single-node helpers. Calling `write-node` in a loop over N nodes is O(N²) — each call takes the lock and
> re-derives `parent_map`/`child_map` over all nodes. `bulk-write` does it once. At ~1,500 nodes the loop path is
> ~150s; `bulk-write` is one write.

**Substrate path**: `${TOPOLOGY_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/topology-graph.json}` (spec 14
§4.2). Per-repo, gitignored, machine-readable. The env-var override lets evals write to a scratch path.

**Concurrency**: a single whole-file `mkdir` lock with TTL + clock-skew bound + symlink-TOCTOU guard +
fail-closed-on-unreadable-epoch + bounded retry — mirroring `.claude/skills/_shared/goals.sh`. Writes are
`jq -n` → `mktemp` → `mv` (atomic rename). bash 3.2 + jq-1.7 target: all structure work is in jq, never bash
arrays.

---

## What this substrate is NOT (scope boundaries)

- **Not the reconciliation record** — Doctrine 06's 17-field invariant records are an M4 record type that *reads*
  this substrate; they are not stored here (see the load-bearing finding above).
- **Not the goal-ledger** — `.claude/goals/` tracks goal/intent for collision detection; this tracks system state.
  Separate concerns per `dont-conflate-inflight-programme.md`.
- **Not the Obsidian vault** — the `obsidian-second-brain` skill *reads* this JSON and links it into the vault;
  the substrate writes JSON only (spec 14 §4.2).
- **Not coupled to Understand-Anything's plugin** — UA's TS extractor is imported as a Node *library* inside the
  code emitter at M3 Sessions 4-5; it does not touch the substrate skill (spec 14 §4.1, §4.5).
- **Not runtime tracing** — runtime behaviour (Sentry/PostHog) is out of scope per D05 §3.5.

---

## References

- `docs/operational-doctrine/05_topology-from-source.md` — §6.1 (node), §6.3 (common shape), §6.5.1 (kind contract), §6.6 (source-orphan), Appendix C (emitter catalogue), Appendix E (M3 handoff)
- `docs/operational-doctrine/06_conservation-law-verification.md` — §6.1 (the 17-field invariant record this substrate does NOT carry), §12.3a (the `right_view` contract this substrate fulfils)
- `docs/operational-doctrine/04_intent-capture.md` — §6.3 (the intent record `declared_intent_ref` will point to at M4)
- `council/audits/2026-05-22-cross-doctrine-consistency-04-05-06.md` — confirms the 5-field shared envelope + the < 50% Jaccard separability
- `specs/14_NEWEARTH_MASTER_BLUEPRINT_BUILD_PLAN.md` — §4.2 (substrate decision), §4.3 (heartbeat), §3 (P6 markers)
- `.claude/skills/_shared/goals.sh` — the atomic-write concurrency pattern this substrate mirrors
