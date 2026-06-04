---
name: n8n-cloud-emitter
description: |
  The n8n cloud topology emitter — the second M3 mapper. Reads a NewEarth entity's
  live n8n cloud instance (via the entity's n8n MCP, e.g. mcp__n8n-mcp-honeybird for
  BuyBox-AI) READ-ONLY, transforms the result into Doctrine 05 §6.1 canonical-shape
  workflow + workflow_node nodes + cross-workflow `calls` edges, and writes them via
  ONE bulk-write to the topology substrate (the Session-1 contract). Scoping is
  tag-union (operator-curated tag set) + id-override (safety net for untagged
  workflows). Emits 2 node kinds — workflow, workflow_node — with the §6.5.1 typed
  attributes per kind plus honest extensions. The workflow_node.disabled flag is the
  load-bearing A.11 disabled-but-present signal (presence ≠ effectiveness). Marks
  n8n-cloud coverage covered (heartbeat) after a successful write.
  Use when: an operator wants to populate (or refresh) a project's n8n cloud topology
  in the substrate; "/n8n-cloud-emit", "emit the n8n topology", "run the n8n parser",
  "what workflows call workflow X", "what does this workflow trigger" (after a run);
  AND/OR after a workflow edit / new workflow / archive landed in cloud (P3
  regenerate-not-edit).
  Do NOT use for: writing to n8n cloud (read-only structure queries only); reading
  execution data (out of scope — runtime signal, not structural); computing
  reconciliation / drift (M4 scope); supabase / TS / Vercel emitters (M3 Sessions
  2/4-5); editing the substrate code (Session-1 contract is FROZEN — compose, do not
  reimplement); editing the supabase-live emitter (Session-2 contract is FROZEN as
  the reference pattern).
allowed-tools: Bash, Read, mcp__n8n-mcp-honeybird__n8n_health_check, mcp__n8n-mcp-honeybird__n8n_list_workflows, mcp__n8n-mcp-honeybird__n8n_get_workflow
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-05-26
programme: intent-actual-gap-mechanism
programme_session: M3-session-3-n8n-cloud-emitter
schema_authority: ../topology-substrate/references/canonical-shape.md
---

# n8n Cloud Emitter (live n8n workflows → topology substrate)

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 3 of ~6.
> **The second M3 emitter**: completes the cloud-workflow-coverage half of v1. Pairs
> with Session-2's pg_depend emitter and Session-5's in-repo n8n JSON walker (the
> `repo:` prefix counterpart that M4 reconciliation compares against `cloud:`).
> Doctrine 05 (topology-from-source) is the schema authority; §6.2 names this emitter;
> §6.5.1 fixes the per-kind attributes; §7.3 names cross-workflow edges as a
> load-bearing leverage point; Appendix C catalogues it. The substrate's frozen contract
> lives in 📄 `../topology-substrate/references/canonical-shape.md` — read it before
> extending the shape.

## What this is

A Claude Code skill that reads a NewEarth entity's **live n8n cloud workflows**, scoped
by an operator-curated tag set + an id-override safety net, and writes the workflow
structure — workflows, the nodes inside them, the within-workflow connections, the
workflow→workflow_node containment edges, and the cross-workflow `executeWorkflow`
`calls` edges — into the topology substrate as canonical-shape nodes. **READ-ONLY**:
every MCP call is `n8n_list_workflows` / `n8n_get_workflow` / `n8n_health_check`; the
emitter never writes to n8n cloud.

One sentence: **n8n cloud describes its own workflows; this emitter translates that into
the substrate's canonical shape.**

## When to invoke

- A fresh repo / entity needs its n8n cloud topology populated (first run).
- A workflow was edited, created, archived, or had a node disabled → re-run to refresh.
- The health-check skill (M3 Session 6) sees `n8n-cloud` stale → operator re-runs.
- An operator asks "what workflows call X" / "what does Y trigger" — the answer lives
  in the substrate; this emitter ensures it is current.

## What it emits (the §6.5.1 contract + honest extensions)

| kind | source | typed `attributes` (§6.5.1 base + honest extensions) | edges produced |
|---|---|---|---|
| `workflow` | `n8n_get_workflow` body + `list_workflows` metadata | **§6.5.1 base**: `active`, `trigger_type`. **Extensions**: `name`, `archived`, `tags[]`, `node_count`, `connection_count`, `fetch_mode` | `contains` (→ each of its workflow_nodes); `depended_on_by` populated when other workflows' executeWorkflow nodes target it |
| `workflow_node` | `n8n_get_workflow.body.nodes[]` (after stickyNote filter) | **§6.5.1 base**: `node_type`, `position`. **Extensions**: `name`, **`disabled`** (A.11), `workflow_id`, `parent_workflow_name` | `depends_on` (within-workflow, via `connections`); `calls` (when type=executeWorkflow → target workflow) |

### Honest extensions — documented, not amendments

The §6.5.1 BASE contract is `{active, trigger_type}` for workflow and `{node_type,
position}` for workflow_node. This emitter ships **additive extensions** — same discipline
as Session 2's overload-collapse documentation. The extensions are optional, downstream
consumers can ignore them, and they pass the "honest extension" test:

| Extension | Why it earns its keep |
|---|---|
| `workflow.name` | Operator readability — every console + query needs human-readable workflow names |
| `workflow.archived` | M4 reconciliation must distinguish graveyard from live (operator's archived workflows are still BuyBox-folder surface, NOT gone) |
| `workflow.tags[]` | The scoping signal itself surfaced for diagnostic queries ("which workflows are tagged X?") |
| `workflow.node_count` | O(1) freshness signal the health-check skill reads without traversing the whole substrate; recomputed post-stickyNote filter (differs from n8n's verbatim `nodeCount`) |
| `workflow.connection_count` | Same — O(1) edge-count freshness signal |
| `workflow.fetch_mode` | `"active"` (published graph) vs `"full"` (draft, fallback for never-activated) — provenance honesty per D05 P1 |
| `workflow_node.name` | Operator readability |
| `workflow_node.disabled` | **Load-bearing A.11 analogue** — presence ≠ effectiveness, the canonical dangerous case this emitter must surface |
| `workflow_node.workflow_id` | Lets the substrate be queried by "show me all nodes in workflow X" without a full graph walk |
| `workflow_node.parent_workflow_name` | Operator readability when reading the substrate directly |

### The load-bearing flag: `disabled`

The `workflow_node.disabled` attribute is **the** A.11 analogue. A disabled node is in
the workflow body but its connections are not executed when the workflow runs. This is
the n8n equivalent of an RLS policy with `enabled: false` — presence ≠ effectiveness.
Doctrine 05 A.11 names this as a real silent failure mode. This emitter records every
non-stickyNote node's `disabled` flag faithfully; reconciliation (M4) interprets the
meaning.

## How a run works (the orchestration)

A run is **driven by the invoking Claude session** because the workflow body fetches flow
through the n8n MCP (Claude calls `mcp__n8n-mcp-honeybird__*`, parses JSON results, runs
the jq transform in 📄 `scripts/transform.jq`, writes the resulting nodes/edges arrays to
temp files, then shells the harness). The shell script `scripts/emit.sh` is the
**finishing harness** — it takes pre-collected JSON inputs and does the validate +
bulk-write + mark-ran + verify sequence atomically.

1. **Init the substrate** (idempotent — the harness does this itself):
   ```bash
   bash .claude/skills/topology-substrate/scripts/substrate.sh init "<entity, e.g. BuyBox-AI>"
   ```
2. **Health-check the n8n MCP** (Phase 0 — session-driven, NOT inside emit.sh):
   ```
   mcp__n8n-mcp-honeybird__n8n_health_check(mode="status")
   ```
   Expected: `success=true`, `status=ok`. If the MCP is unreachable, do NOT run
   emit.sh; instead the **invoking Claude session** marks the emitter degenerate
   directly:
   ```bash
   bash .claude/skills/topology-substrate/scripts/substrate.sh \
        mark-emitter-ran n8n-cloud degenerate
   ```
   per Doctrine 05 P6 / §8.4 (source exists at the entity but unreadable). The
   harness emit.sh never writes `degenerate` — it is the session's responsibility
   when the source is unreachable. Session-3 code-council IMPORTANT.
3. **Discover the workflow scope via tag union** (Phase 1): one
   `n8n_list_workflows(tags=[<one_tag>], limit=100)` call per tag in
   📄 `references/entity-scope.json#tags`. Union the returned ids + the
   `additional_workflow_ids` array, dedupe by id. The result is the **scope**.
4. **Fetch each workflow's structure** (Phase 2): one
   `n8n_get_workflow(id=<wf_id>, mode="active")` call per workflow in the scope. If the
   call errors with "never activated" / `NO_LIVE_VERSION`, fall back to `mode="full"`
   and record `fetch_mode: "full"` on the workflow node.
5. **Assemble canonical-shape nodes + edges via the frozen jq transform** in
   📄 `scripts/transform.jq` (one pass, no per-row fork). This is the authoritative
   spec-to-output translation — committed in the skill so the transform doesn't drift
   between invocations.
6. **Run the harness**:
   ```bash
   bash .claude/skills/n8n-cloud-emitter/scripts/emit.sh <nodes.json> <edges.json>
   ```
   The harness: validates the inputs are JSON arrays, calls `substrate.sh bulk-write` in
   ONE call, calls `substrate.sh mark-emitter-ran n8n-cloud covered`, then
   `substrate.sh validate-schema` (must return `PASS` as a complete line — anchored
   `^PASS$` match).
7. **Print the completeness diagnostic** (the operator's safety net): the transform
   writes a `.diagnostics` field to `combined.json` containing 7 counters
   (workflow_count, workflow_node_count, containment_edges, within_edges_kept,
   within_edges_unresolved, cross_workflow_edges_kept, cross_workflow_edges_skipped).
   The harness (`emit.sh`) takes nodes + edges files and does NOT read combined.json —
   it is the **invoking Claude session's responsibility** to print this block AFTER
   emit.sh exits 0. Recipe:

   ```bash
   jq '.diagnostics' /tmp/m3-session-3-emit/combined.json
   ```

   The 7 counters MUST be surfaced verbatim to the operator. Non-zero values in
   `within_edges_unresolved` or `cross_workflow_edges_skipped` are operator-actionable
   signals (catalogue bug or stale id-override scope, respectively). Silent omission
   of this step is a Doctrine 05 P6 ("declared coverage") breach — Session-3
   code-council IMPORTANT.

> **One `bulk-write`, not a `write-node` loop.** At BuyBox-AI v1 scale (11 workflows,
> ~250 workflow_nodes after stickyNote filter, ~400 edges), a `write-node` loop is
> O(N²); `bulk-write` is one lock + one map-derivation. The substrate SKILL.md mandates
> this.

## The schema gotcha — `connections` is keyed by NAME, not GUID

n8n's `connections` object is keyed by node **name**, both at the top level and inside
each branch's target list. n8n names are user-editable and renameable; only the per-node
`id` GUID is stable. The transform builds a `name → id` lookup ONCE per workflow from
`nodes[]`, then resolves every `connections` source + target name to its GUID before
emitting an edge.

If a name fails to resolve, the transform emits the edge with a synthetic
`unresolved:<name>` target so the substrate's bulk-write integrity check surfaces it
loud, NOT silent-drop. The completeness diagnostic counts these. Investigate any
non-zero count — it's a real n8n catalogue bug (usually an orphaned reference from an
aborted rename).

See 📄 `references/n8n-workflow-shape.md` for the full schema reference.

## Provenance for live n8n rows (the design call)

A live n8n workflow has no git commit — the workflow is the editor's last state, not a
file in a repo. To satisfy D05 §6.1 (`source_file` + `source_commit` required;
validate-schema enforces it), this emitter uses a **declared live-provenance marker**:

```
source_file:   "n8n_cloud (live)"
source_commit: "live:honeybird:<workflow_id>"
source_line:   null                              (workflows are JSON, not line-addressable usefully)
emitter:       "n8n_parser"
timestamp:     "<ISO 8601 UTC of this run>"
```

The convention is **honest by default**: anyone reading the substrate sees `"n8n_cloud
(live)"` and knows the node was derived from a live n8n read, not from a repo file. The
`live:honeybird:<workflow_id>` form is deterministic per workflow so a multi-workflow
substrate downstream can disambiguate. This satisfies D05 P2 (every node traces to
source) without fabricating a git commit. A future enhancement (M4 or later) could
correlate workflow ids to a workflow-export history.

## The cloud:/repo: prefix discipline

This emitter writes ids prefixed `cloud:` (e.g. `cloud:Gz8EKN9CWxIDcGXcoCmYq` for the
workflow itself, `cloud:Gz8EKN9CWxIDcGXcoCmYq:<node-guid>` for each contained node).
Session-5's in-repo n8n JSON walker will write the SAME workflows from the in-repo source
with the `repo:` prefix. The cloud node and the repo node are DISTINCT substrate nodes
— that distinction is the whole point of the intent-vs-actual gap mechanism. M4
reconciliation compares them and emits drift records (Doctrine 06 territory).

If a workflow exists in cloud but not in repo, only `cloud:<id>` is emitted; M4 surfaces
the absence. If a workflow exists in repo but not in cloud, only `repo:<id>` is emitted
(by Session 5); M4 surfaces the absence. Both signals are operator-actionable.

## Filtering decisions (LOCKED for v1 — documented per F4 anti-anchoring)

| Filter | Rule | Reason |
|---|---|---|
| Scope | tag union (from `entity-scope.json#tags`) + `additional_workflow_ids` array, deduped | Operator's "don't miss any" contract. Tag is the primary signal; id-override is the safety net for untagged workflows the operator knows belong in the scope |
| Sticky notes | `node.type === 'n8n-nodes-base.stickyNote'` excluded | Documentation, not flow. Has no connections in/out. Doctrine 05 surface is structural flow only |
| Archived workflows | EMITTED with `attributes.archived: true` IF in scope | Archived BuyBox-folder workflows are still BuyBox surface (operator's contract). Archived non-BuyBox workflows are out-of-scope by definition (no BuyBox tag, not in id-override) |
| Disabled nodes | EMITTED with `attributes.disabled: true` | Presence ≠ effectiveness; A.11 load-bearing signal. The disabled-but-present case is exactly what the substrate exists to surface |
| Execution data | NOT read | Runtime signal, out of D05 scope (§3.5). The MCP exposes it via `n8n_executions`; we never call that tool |
| Credentials | NOT emitted as separate kind v1 | Future enhancement (Session 5 has same question for in-repo workflows); credential-as-node deferred |
| Pinned data | NOT emitted | Dev-mode test fixture, not topology |
| Branch index | NOT preserved | Multiple branches collapse to one edge per `(source, target, type)` triple (deduped). Future enhancement: emit as edge attribute, deferred |
| Non-`main` connection groups | DROPPED v1 (`error`, `ai_languageModel`, `ai_tool`, `ai_memory`, etc.) | The transform walks only `.main` connections. n8n LangChain AI-Agent nodes have sidecar connection groups (`ai_languageModel`, `ai_tool`) that are not main-flow execution edges; `error` connections are the on-error flow. v1 emits the main-flow topology only. v1.1 enhancement: walk all groups, tag edges with `connection_group` attribute, count dropped groups in diagnostics. Session-3 code-council IMPORTANT |

## Propagation — how to rebind to a non-BuyBox-AI entity

The frontmatter's `allowed-tools` list names `mcp__n8n-mcp-honeybird__*` — BuyBox-AI's
instance. When `/push-to-template` propagates this skill and another entity (Agency-Main,
Nirvana) runs `/update-latest`, the operator must:

1. Update `allowed-tools` in the SKILL.md frontmatter to the receiving entity's MCP
   (e.g. `mcp__n8n-mcp-newearthai__*` for Agency-Main).
2. Update 📄 `references/entity-scope.json`:
   - `entity` → the entity name (e.g. "Agency-Main")
   - `mcp_server` → the MCP server name (e.g. "mcp__n8n-mcp-newearthai")
   - `tags` → the per-entity tag set (each NewEarth entity has its own folder/tag
     convention; operator-curated at first propagation)
   - `additional_workflow_ids` → start empty; populate as untagged workflows surface
3. Update the `--arg src_commit_prefix` value when invoking transform.jq to
   `"live:<entity-instance-slug>:"` (e.g. `"live:newearthai-cloud:"` — whatever the
   receiving instance's slug is in operator nomenclature).

The template-push pipeline should substitute the MCP server name as a placeholder; the
tag set, id-override, and prefix must be operator-confirmed at first run per entity.
**Nirvana has no n8n** (uses Make.com only); on Nirvana, the emitter should NOT be run —
the substrate's `n8n-cloud` slot stays at `coverage: "absent"` (D05 §8.4 — the source
type does not exist at this entity).

## Scale ceiling (v1)

The harness passes the assembled nodes + edges JSON via shell argv to `substrate.sh
bulk-write`. macOS argv has a per-argument cap of roughly 1 MB and a total-argv cap near
2 MB. At BuyBox-AI v1 (11 workflows, ~250 workflow_nodes, ~400 edges) the two argv
strings total ~150 KB — comfortably under the cap. The same Session-2 ceiling applies:
at roughly 3-5× scale (≈ 5,000+ nodes per emitter) the argv would approach the ceiling;
before propagating to a larger n8n instance, **either** confirm the workflow set
produces under 500 KB of JSON per array, **or** the substrate's `bulk-write` gains a
stdin variant (`bulk-write-stdin`) that takes the same payload via stdin and removes
the argv constraint. This is a flagged v1 ceiling, not a v1 bug.

## Known limitations (v1, documented honestly)

1. **Cross-workflow target out-of-scope SKIPPED, not stubbed.** A BuyBox workflow that
   calls a non-BuyBox workflow produces a `calls` edge whose target is not in our
   substrate. v1 SKIPS the edge with a logged warning + count in the completeness
   diagnostic. Alternative considered: emit a stub workflow node for out-of-scope
   targets with `attributes.out_of_scope: true`. Rejected v1 because the stub would lie
   about coverage. The diagnostic surfaces the count honestly; M4 can revisit.
2. **Multiple-branch collapse.** Switch / If nodes with multiple output branches that
   all reach the same target via different branches produce ONE edge after dedup. Branch
   index is not preserved. Future enhancement.
3. **`fetch_mode` is per-workflow honesty, not per-node.** When `mode="active"` errors
   and falls back to `mode="full"`, the entire workflow's nodes carry the same
   provenance (the draft graph). A finer-grained per-node `staged_in_draft` flag is
   deferred.
4. **No credential / no-API-graph emission.** The credential bindings on n8n nodes
   (`node.credentials`) and the external services nodes call (HTTP Request → Supabase
   REST, Twilio, Wassenger, etc.) are NOT emitted as substrate nodes. v1 emits only
   the workflow + workflow_node structure. The external-API-graph is one of the 5
   declared-missing emitters (per `canonical-shape.md` §missing_emitters) — M4+ scope.
5. **Trigger type is heuristic.** `attributes.trigger_type` is derived from the first
   non-stickyNote node matching a trigger pattern. Operator can override by inspecting
   the workflow in the n8n UI.

## Composition map

| Composes with | How |
|---|---|
| `topology-substrate` skill (Session 1) | Calls `init` / `bulk-write` / `mark-emitter-ran` / `validate-schema` / `read-topology` via `substrate.sh`. **NEVER** edits substrate code. If a substrate bug surfaces, file it as a substrate issue — do not patch in this emitter. |
| `supabase-live-emitter` skill (Session 2) | NEVER edits it. References it as the reference pattern for the harness + transform.jq shape. The two emitters write to the SAME substrate; their nodes coexist (table + workflow nodes share `id` namespace via prefix discipline — `public.X` vs `cloud:Y`). |
| `mcp__n8n-mcp-honeybird__*` (BuyBox-AI) | Read-only workflow queries (`n8n_health_check`, `n8n_list_workflows`, `n8n_get_workflow`). The emitter's allowed-tools list MUST be tightened per-entity (swap to `mcp__n8n-mcp-<entity>__*` at propagation). |
| Goal-ledger (`.claude/goals/`) | Optional v1.1 enhancement: an emitter run could append an "n8n-cloud topology emitted for entity X at T" row via `goals.sh`. Out of scope for v1 unless trivial — recorded as a future enhancement. |

## What this skill must NOT do (the no-go list)

- Author intent (Doctrine 04) or compute drift (Doctrine 06) — emits the actual side only.
- Edit `substrate.sh` / the substrate schema / Doctrines 04/05/06 — frozen contracts.
- Edit the Session-2 `supabase-live-emitter` skill — frozen reference pattern.
- Add Doctrine 06's 17 reconciliation fields per node — the load-bearing finding
  (collapses three-way separability).
- Write to n8n cloud. Use any of `n8n_create_workflow`, `n8n_update_full_workflow`,
  `n8n_update_partial_workflow`, `n8n_delete_workflow`, `n8n_deploy_template`,
  `n8n_test_workflow`, `n8n_autofix_workflow`, `n8n_manage_credentials`,
  `n8n_manage_datatable`.
- Read execution data (out of structural-topology scope).
- Loop `write-node` (use `bulk-write`).
- Leave the provenance envelope empty (validate-schema requires it).
- Defend a schema choice on "industry does this" (F4 — M1 falsifier proved no precedent).
- Silent-drop an unresolved connection name — surface it loud with the synthetic
  `unresolved:<name>` target so the substrate's integrity check catches it.
- Emit sticky-note nodes.

## Concurrency model

This emitter inherits the substrate's atomic write discipline — the substrate's
whole-file `mkdir` lock guarantees a parallel Claude session running a different emitter
(e.g. Session 2's supabase-live) never corrupts the substrate. The emitter itself takes
no additional lock; all atomicity is in `substrate.sh`.

## Exit codes (the harness)

`emit.sh` returns:
- `0` ok — `bulk-write` succeeded + `mark-emitter-ran` succeeded + `validate-schema` PASS
- `2` usage / bad-arg / inputs not JSON arrays
- `4` substrate not initialised AND init failed
- `6` `bulk-write` / `validate-schema` / `mark-emitter-ran` failed (the inner script's
  stderr explains)

## References

- 📄 `../topology-substrate/references/canonical-shape.md` — the frozen schema (read first)
- 📄 `../topology-substrate/SKILL.md` — the helper API + bulk-write mandate
- 📄 `../supabase-live-emitter/` — Session 2 worked pattern (the shape this skill mirrors)
- 📄 `references/entity-scope.json` — per-entity tag set + id-override
- 📄 `references/n8n-workflow-shape.md` — n8n MCP payload schema reference
- 📄 `scripts/queries.md` — the MCP recipe + read-only contract
- 📄 `scripts/transform.jq` — the frozen one-pass jq transform from MCP payloads to
  canonical-shape nodes + edges
- 📄 `scripts/emit.sh` — the finishing harness (validate + bulk-write + mark-ran + verify)
- `docs/operational-doctrine/05_topology-from-source.md` — §6.2 (this emitter), §6.5.1
  (per-kind contract), §7.3 (cross-workflow edges = the leverage point), Appendix C
  (the emitter catalogue), A.11 (presence-vs-effectiveness)
- `specs/14_NEWEARTH_MASTER_BLUEPRINT_BUILD_PLAN.md` — §3 (scope), §5 (sequence)
- `.claude/rules/intent-actual-gap-mechanism-alignment.md` — the programme contract
- `.claude/rules/n8n-patterns.md` — project-wide n8n discipline (resource-locator, etc.)
