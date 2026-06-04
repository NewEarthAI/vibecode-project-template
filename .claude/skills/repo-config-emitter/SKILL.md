---
name: repo-config-emitter
description: |
  The in-repo n8n + config topology emitter — the fourth M3 mapper. Reads a NewEarth entity's
  in-repo n8n workflow JSON files + vercel.json + package.json READ-ONLY (pure file reads, NO
  MCP), transforms them into Doctrine 05 §6.1 canonical-shape nodes — workflow + workflow_node
  (the repo: counterpart to Session-3's cloud: workflows) + config (the kind added M3 Session 5
  for declared-structure config files) — and writes them via ONE bulk-write to the topology
  substrate (the Session-1 contract). The repo: n8n nodes pair with Session-3's cloud: nodes as
  the M4 cloud-vs-repo reconciliation surface. Emits 3 node kinds — workflow, workflow_node,
  config — with §6.5.1 typed attributes per kind plus honest extensions. Marks `code` coverage
  covered (heartbeat) after a successful write.
  Use when: an operator wants to populate (or refresh) a project's in-repo n8n workflow topology
  + deploy config + dependency manifest in the substrate; "/repo-config-emit", "emit the in-repo
  n8n topology", "map vercel.json and package.json", "what in-repo workflows exist", "what does
  the repo say this workflow is" (after a run); AND/OR after an in-repo workflow JSON / vercel.json
  / package.json change landed (P3 regenerate-not-edit).
  Do NOT use for: live cloud n8n (that is Session-3's n8n-cloud-emitter — this reads the in-repo
  JSON FILES); computing reconciliation / cloud-vs-repo drift (M4 scope); per-dependency nodes
  or vercel route->function deploy-binding edges (v1.1 / M4); writing to the repo (read-only);
  editing the substrate code (Session-1 contract FROZEN — compose, do not reimplement); editing
  the Session-2/3/4 emitters (frozen reference patterns).
allowed-tools: Bash, Read
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-05-27
last_verified: 2026-06-01
programme: intent-actual-gap-mechanism
programme_session: M3-session-5-repo-config-emitter
schema_authority: ../topology-substrate/references/canonical-shape.md
---

# Repo Config Emitter — in-repo n8n JSON + vercel.json + package.json → topology substrate

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 5 of ~6.
> **The fourth M3 emitter**: completes the in-repo half of v1. With it, "everything on the
> BuyBox-AI GitHub repo perfectly mapped" (build-plan §5 row 1, §6 line 146) is DONE — only
> Session 6 (health-check + integration) remains. Crucially it opens the **cloud-vs-repo n8n
> reconciliation surface** M4 depends on: the in-repo `repo:workflows/gmail-clozers-comps.json`
> node pairs with Session-3's `cloud:Gz8EKN9CWxIDcGXcoCmYq` node (same workflow, two sources).
> Doctrine 05 (topology-from-source) is the schema authority; §1 + §3 + Appendix C name "deploy
> config" as a read source artefact (placing vercel.json + package.json in scope as DECLARED
> structure — §3.5 is the runtime-tracing EXCLUSION, not the in-scope clause); §6.2 describes the
> n8n emitter (§6.5.1 / Appendix C name it `n8n_parser`); §6.5.1 fixes the per-kind attributes;
> §6.6 is the source-orphan rule the `config` kind rides on. The
> substrate's frozen contract lives in 📄 `../topology-substrate/references/canonical-shape.md`
> — read it before extending the shape.

## What this is

A Claude Code skill that reads a NewEarth entity's **in-repo n8n workflow JSON files +
`vercel.json` + `package.json`** and writes their declared structure — the in-repo workflows,
the nodes inside them, the within-workflow connections, the workflow→workflow_node containment
edges, the cross-workflow `calls` edges, and one `config` node each for the deploy config + the
dependency manifest — into the topology substrate as canonical-shape nodes. **READ-ONLY, NO MCP**:
every read is a plain file read; the emitter never writes to the repo and never calls a live
service.

One sentence: **the repo's own files describe their structure; this emitter translates that into
the substrate's canonical shape.**

## When to invoke

- A fresh repo / entity needs its in-repo n8n + config topology populated (first run).
- An in-repo workflow JSON, `vercel.json`, or `package.json` changed → re-run to refresh
  (P3 regenerate-not-edit; the emitter is idempotent + re-runnable).
- The health-check skill (M3 Session 6) sees `code` stale → operator re-runs.
- An operator asks "what does the repo version of workflow X look like" / "what's in our deploy
  config" / "what version of React are we on" — the answer lives in the substrate; this emitter
  keeps it current.

## What it emits (the §6.5.1 contract + honest extensions)

| kind | source | typed `attributes` (§6.5.1 base + honest extensions) | edges produced |
|---|---|---|---|
| `workflow` | in-repo n8n JSON file (`workflows/*.json` + `n8n-workflows/*.json`) | **§6.5.1 base**: `active`, `trigger_type`. **Extensions**: `name`, `archived`, `tags[]`, `node_count`, `connection_count`, `source_kind: "repo"`, `n8n_id` | `contains` (→ each workflow_node); `calls` populated when its executeWorkflow nodes target another in-repo workflow |
| `workflow_node` | in-repo n8n JSON `nodes[]` (after stickyNote filter) | **§6.5.1 base**: `node_type`, `position`. **Extensions**: `name`, `disabled` (A.11), `workflow_id`, `parent_workflow_name` | `depends_on` (within-workflow, via `connections`); `calls` (executeWorkflow → target in-repo workflow) |
| `config` | `vercel.json` + `package.json` | **vercel**: `config_type:"vercel"`, `header_count`, `rewrite_count`, `redirect_count`. **package**: `config_type:"package"`, `name`, `version`, `dependency_count`, `dev_dependency_count`, `script_count`, `dependencies{}` | NONE in v1 (no machine dependency-emitter for config files; deploy-binding edges are M4) |

### The `config` kind (added M3 Session 5)

The frozen 9-kind enum had no home for a config file. The continuation's first idea — `kind:
"manual"` — is impossible: **`manual` is an EMITTER value, not a kind** (substrate.sh; every node
still carries one of the domain kinds). Doctrine 05 names "deploy config" as a read source
artefact in §1 + §3 + Appendix C (the `vercel_api` row), placing `vercel.json` (the declared FILE,
not the deployed state) and `package.json` (the dependency manifest) in scope as DECLARED
structure — §3.5's boundary is *runtime tracing* (the deployed-state binding), which stays OUT.
The kind enum simply never gave the declared config FILE a home. M3 Session 5 added one `config`
kind via the doctrine-verification-gate triple gate (deletion-as-re-invention + `/code-council`
on the doctrine delta + real-decision test against the live `Gz8…` cloud-vs-repo drift; Test D
re-checked — the `config_type` attribute family touches topology's schema only, all pairwise
Jaccard overlaps unchanged < 50%), recorded in
📄 `council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md`. A `config` node is always
`emitter: "manual"` + a mandatory `manual_justification`: unlike `pg_depend` / `n8n_parser` /
`dependency_cruiser`, no machine emitter parses a config file into a dependency graph in v1, so a
config node is a §6.6 source-orphan-class node (named source artefact, no derived edges). The
`config_type` discriminator sub-classifies the file without enum growth (future config files —
tsconfig, env schema — are new `config_type` values, not new kinds).

### Honest extensions — documented, not amendments

The §6.5.1 BASE contract is `{active, trigger_type}` for workflow and `{node_type, position}` for
workflow_node — same discipline as Sessions 2/3/4. The extensions are optional + downstream
consumers can ignore them:

| Extension | Why it earns its keep |
|---|---|
| `workflow.source_kind: "repo"` | Lets the substrate be queried for repo-vs-cloud without parsing the id prefix (the cloud emitter used `fetch_mode` for the same provenance-honesty role) |
| `workflow.n8n_id` | The n8n workflow id (distinct from the node id which is `repo:<path>`) — needed to resolve cross-workflow `calls` between in-repo workflows + for M4 to pair with the `cloud:<n8n_id>` node |
| `workflow.{name, archived, tags, node_count, connection_count}` | Same roles as Session 3 (operator readability + O(1) freshness signals + the scoping signal surfaced) |
| `workflow_node.disabled` | The load-bearing A.11 analogue — presence ≠ effectiveness |
| `workflow_node.{name, workflow_id, parent_workflow_name}` | Operator readability + queryability without a full graph walk |
| `config.config_type` + the per-type summary counts | Operator-readable summary of the deploy config / dependency tree without re-parsing the file |
| `config.dependencies{}` | The dependency tree as queryable data (one node, NOT 94 per-dep nodes — the enum has no `dependency` kind and they're not in-repo code; v1.1 if M4 wants per-dep nodes) |

## How a run works (the orchestration)

A run is **driven by the invoking Claude session**: the session reads the 6 in-repo files via
`Bash`/`Read`, assembles them into the transform's input shape, runs the frozen jq transform
(📄 `scripts/transform.jq`), writes the resulting nodes/edges arrays to temp files, then shells
the harness (📄 `scripts/emit.sh`). The harness is the finishing step (validate + bulk-write +
mark-ran + verify). NO MCP is involved at any step — pure file reads.

1. **Verify the repo path + surfaces + the substrate gitignore** (Phase 0):
   ```bash
   test -d "$REPO_ROOT" && ls "$REPO_ROOT"/workflows/*.json "$REPO_ROOT"/n8n-workflows/*.json 2>/dev/null
   test -f "$REPO_ROOT/vercel.json"; test -f "$REPO_ROOT/package.json"
   # GUARD (Session-5 code-council IMPORTANT): the substrate writes to $REPO_ROOT/.understand-anything/,
   # which is INSIDE the target repo's working tree. Confirm it is gitignored BEFORE emitting, or a
   # later `git add -A` would commit the substrate JSON (workflow node names + the dep tree) into the
   # target repo's history. If this prints nothing, the entry is MISSING — add `.understand-anything/`
   # to the target repo's .gitignore (an operator action on the target repo) before a committed run.
   git -C "$REPO_ROOT" check-ignore -v .understand-anything/ || echo "WARN: .understand-anything/ NOT gitignored on $REPO_ROOT — add it before emitting"
   ```
   A missing config file is honest-empty (the transform emits no node for it); a missing n8n
   directory means that source class is absent at this entity.

2. **Compute provenance** (one git call, applied to all nodes):
   ```bash
   SRC_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
   [ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ] && SRC_COMMIT="${SRC_COMMIT}+dirty"
   ```
   In-repo files DO have a git commit (unlike the live MCP emitters) — honest by default.

3. **Assemble the transform inputs.** For each in-repo n8n JSON file, build a record carrying its
   `relpath` (the repo-relative path — the id prefix), `id`, `name`, `active`, `isArchived`,
   `tags`, and the TOP-LEVEL `nodes` + `connections` (the in-repo file shape is top-level — there
   is NO `body` wrapper, unlike Session-3's MCP shape). Slurp `vercel.json` + `package.json`
   verbatim.

4. **Run the frozen jq transform** (📄 `scripts/transform.jq`) → `{nodes, edges, diagnostics}`.

5. **Run the harness**:
   ```bash
   TOPOLOGY_SUBSTRATE_PATH="$REPO_ROOT/.understand-anything/topology-graph.json" \
     bash .claude/skills/repo-config-emitter/scripts/emit.sh nodes.json edges.json "<entity>"
   ```
   The harness validates the inputs are JSON arrays, calls `bulk-write` (chunked above 600 KB),
   calls `mark-emitter-ran code covered` (the `code` slot — OPEN-1), then `validate-schema`
   (anchored `^PASS$`).

6. **Print the completeness diagnostic** (the operator's safety net): the transform writes a
   `.diagnostics` field to `combined.json`. The harness does NOT read it — it is the **invoking
   session's responsibility** to print it AFTER emit.sh exits 0:
   ```bash
   jq '.diagnostics' /tmp/m3-session-5-emit/combined.json
   ```
   Counters: `workflow_count`, `workflow_node_count`, `config_node_count`, `containment_edges`,
   `within_edges_kept`, `within_edges_unresolved`, `cross_workflow_edges_kept`,
   `cross_workflow_edges_skipped`. A non-zero `within_edges_unresolved` is an operator-actionable
   signal (a connection name that didn't resolve to a node — a catalogue bug in the exported
   JSON). Silent omission is a Doctrine 05 P6 ("declared coverage") breach.

> **One `bulk-write`, not a `write-node` loop.** At BuyBox-AI v1 scale (4 workflows, ~78
> workflow_nodes after stickyNote filter, 2 config nodes, ~120 edges) the payload is small (well
> under the chunk budget → fast-path) but the chunked harness is copied verbatim from Session 4
> for correctness + propagation. The substrate SKILL.md mandates `bulk-write` over a `write-node`
> loop (O(N²)).

## The schema gotchas

### In-repo n8n JSON is TOP-LEVEL, not body-wrapped
Session-3's n8n MCP returned `nodes`/`connections` under a `body` wrapper; the in-repo JSON files
have them at the TOP LEVEL (`$wf.nodes`, `$wf.connections`). The transform's accessor differs
accordingly. (Verified live 2026-05-27 — the 4 files have `nodes`/`connections`/`id`/`name`/
`active`/`isArchived`/`tags` at top level.)

### `connections` is keyed by NODE NAME, not GUID (same as Session 3)
n8n names are user-editable; only the per-node `id` GUID is stable. The transform builds a
`name → id` lookup ONCE per workflow, resolves every connection source + target name to its GUID
before emitting an edge. An unresolved name → synthetic `unresolved:<name>` target so the
substrate's integrity check surfaces it loud, NOT silent-drop. Counted in the diagnostic.

### Cross-workflow `calls` resolve via the n8n-id ↔ repo-path indirection
An executeWorkflow node references its target by **n8n workflow id**, but the in-repo node id is
`repo:<filepath>`. The transform builds an `n8n_id → repo_node_id` map across the emit set and
resolves each `calls` edge through it. A target outside the in-repo set becomes
`unresolved-workflow:<id>` (dropped by the idset filter, counted in `cross_workflow_edges_skipped`).
This is the one genuinely novel bit Session 3 didn't need (cloud ids WERE the node ids).

### `isArchived` is often `null` on in-repo files
The exported files carry `isArchived: null` (not `false`); the transform defaults it to `false`
(`.isArchived // false`).

### `config` nodes require `manual_justification`
`validate-schema` rejects a `manual`-emitter node without a non-empty `manual_justification`. The
transform always populates it for config nodes.

## Provenance for in-repo rows (the easiest of any M3 emitter)

In-repo files DO have a git commit — unlike the live MCP emitters (Sessions 2 + 3). So:

```
source_file:   "<repo-relative-path>"      (e.g. "workflows/gmail-clozers-comps.json", "vercel.json")
source_commit: "<git short SHA>"           ("+dirty" appended if uncommitted changes)
source_line:   null                         (file-level node)
emitter:       "n8n_parser" (workflows) | "manual" (config)
timestamp:     "<ISO 8601 UTC of this run>"
```

## The repo: prefix discipline + the reconciliation pair

This emitter writes ids prefixed `repo:`:
- `repo:<relpath>` for the workflow (e.g. `repo:workflows/gmail-clozers-comps.json`)
- `repo:<relpath>:<node-guid>` for each workflow_node
- `repo:vercel.json` / `repo:package.json` for config nodes

Session-3's n8n-cloud emitter wrote the SAME workflow from the live cloud source with the `cloud:`
prefix (`cloud:Gz8EKN9CWxIDcGXcoCmYq`). The cloud node and the repo node are DISTINCT substrate
nodes — that distinction is the whole point of the intent-vs-actual gap mechanism. M4 reconciliation
compares them and emits drift records (Doctrine 06 territory). The recon at build time already
found a real drift: the repo `gmail-clozers-comps.json` (id `Gz8…`) is named "Gmail -> Clozers
Comps" with 33 nodes, while the LIVE cloud workflow with the same id is now named "BuyBox -
Ingestion to Enriched" with 34 nodes — exactly the kind of gap M4 surfaces.

## Filtering decisions (LOCKED for v1 — documented per F4 anti-anchoring)

| Filter | Rule | Reason |
|---|---|---|
| In-repo n8n scope | `workflows/*.json` + `n8n-workflows/*.json` ONLY | The two canonical export dirs. Exclude `specs/**` backups (e.g. `specs/gmail-parser-hardening/workflow_backup_pre_v2_fix.json` is a backup, not live repo topology) |
| Sticky notes | `node.type === 'n8n-nodes-base.stickyNote'` excluded | Documentation, not flow (same as Session 3) |
| Archived in-repo workflows | EMITTED with `attributes.archived: true` IF present | The repo file is the repo surface regardless of cloud archive state |
| Disabled nodes | EMITTED with `attributes.disabled: true` | A.11 presence ≠ effectiveness |
| package.json deps | ONE config node with the dep tree as `attributes.dependencies` | NOT 94 per-dep nodes — no `dependency` kind + not in-repo code; v1.1 if M4 wants per-dep nodes |
| vercel.json deploy binding | NOT emitted as edges | The vercel route→edge_function binding is the M4 `vercel_api` OBSERVED-state emitter (§3.5) |
| Cross-substrate edges (`ts_module → workflow`, `repo:n8n ↔ cloud:n8n`) | NOT emitted v1 | M4 reconciliation scope |
| Non-`main` connection groups (`error`, `ai_languageModel`, etc.) | DROPPED v1 | Walk only `.main` (same as Session 3); v1.1 walks all groups with a `connection_group` attribute |

## Propagation — how to rebind to a non-BuyBox-AI entity

This emitter is path-based (no MCP), so propagation is the simplest of the four:

1. Confirm the receiving repo's in-repo n8n directories (BuyBox-AI uses `workflows/` +
   `n8n-workflows/`; another entity may use a different convention — read the repo at first run).
2. Confirm `vercel.json` + `package.json` exist at the repo root (a non-Vercel entity has no
   `vercel.json` → no vercel config node; honest-empty).
3. Confirm the entity name passed to `emit.sh` matches the substrate's `entity` field.
4. **Nirvana has no n8n** (uses Make.com); on Nirvana the in-repo n8n part emits nothing — the
   `config` part still emits if `vercel.json`/`package.json` exist. The `code` slot stays
   `covered` if any surface emitted, or the operator marks it `absent` if NO in-repo code/config
   exists.

## Scale ceiling — SOLVED via harness chunking (inherited from Session 4)

The harness chunks the bulk-write above a 600 KB budget (ALL node chunks first, THEN edges; the
substrate's idempotent upsert makes the sequence equivalent to one call). Session-5's payload is
small (fast-path), but the chunked harness is copied verbatim for correctness + propagation. See
the code-emitter SKILL.md "Scale ceiling" for the full rationale.

## Known limitations (v1, documented honestly)

1. **Cross-workflow `calls` resolve only WITHIN the emit set.** An in-repo workflow calling a
   workflow NOT in `workflows/` or `n8n-workflows/` produces an `unresolved-workflow:<id>` target,
   dropped + counted. v1 does not stub out-of-set targets (would lie about coverage).
2. **No cross-substrate / no cloud-vs-repo edges.** `repo:n8n ↔ cloud:n8n` reconciliation edges +
   `ts_module → workflow` edges are M4 scope. The substrate CAN hold them; only the inference is
   deferred.
3. **package.json dep tree is ONE node, not per-dep nodes.** v1.1 if M4 needs per-dependency
   granularity (would need a `dependency` kind — a separate doctrine amendment).
4. **vercel.json → edge_function deploy binding NOT emitted.** That's the M4 `vercel_api`
   observed-state emitter; this emitter models the DECLARED file only (§3.5).
5. **Trigger type is heuristic** (same as Session 3 — first node matching a trigger pattern).
6. **Non-`main` connection groups dropped** (same as Session 3 — v1.1 walks all groups).

## Composition map

| Composes with | How |
|---|---|
| `topology-substrate` skill (Session 1) | Calls `init` / `bulk-write` / `mark-emitter-ran` / `validate-schema` / `read-topology`. **NEVER** edits substrate code. The `config` kind was added to the frozen contract via the doctrine-verification-gate triple gate (M3 Session 5, recorded in 📄 `council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md`), NOT an inline patch. |
| `n8n-cloud-emitter` skill (Session 3) | NEVER edits it. The DIRECT template for the in-repo n8n transform (same kinds, same edge classes; this skill swaps the data source file-read for MCP, the `repo:` prefix for `cloud:`, and a real git commit for the live marker). The `cloud:` node it wrote + the `repo:` node this skill writes are the M4 reconciliation pair. |
| `code-emitter` skill (Session 4) | NEVER edits it. The harness + chunked-write reference (this skill's `emit.sh` is a near-verbatim copy). Both write to the SAME substrate + mark the SAME `code` slot. |
| `supabase-live-emitter` skill (Session 2) | NEVER edits it. A second reference shape. |
| The receiving repo's in-repo files | Read-only file reads. NO MCP. |
| Goal-ledger (`.claude/goals/`) | OPTIONAL v1.1: an emit run could append a "repo-config topology emitted for entity X at T" row. Out of scope for v1 unless trivial. |

## What this skill must NOT do (the no-go list)

- Author intent (Doctrine 04) or compute drift (Doctrine 06) — emits the actual repo side only.
- Edit `substrate.sh` behaviour / Doctrines 04/06 — frozen contracts. (Doctrine 05 + the
  substrate's VALID_KINDS gained the `config` kind via the M3 Session-5 doctrine-verification-gate
  triple gate (recorded in the council review cited in the `config`-kind section);
  that is the ONLY frozen-contract change, and it is a one-kind additive edit, not a behaviour
  change.)
- Edit the Session-2/3/4 emitter skills — frozen reference patterns.
- Add Doctrine 06's 17 reconciliation fields per node — collapses three-way separability.
- Write to the repo. (Read-only.)
- Use any MCP — this is pure file-reading. (Session-3's n8n-cloud-emitter is the MCP one.)
- Loop `write-node` (use `bulk-write`).
- Leave the provenance envelope empty, or a `config` node without `manual_justification`.
- Defend a schema choice on "industry does this" (F4 — M1 falsifier proved no precedent).
- Silent-drop an unresolved connection name — surface it loud (`unresolved:<name>`, counted).
- Emit a kind outside the frozen 10-kind enum, or explode package.json deps into per-dep nodes.

## Concurrency model

Inherits the substrate's atomic write discipline — the whole-file `mkdir` lock guarantees a
parallel session running a different emitter never corrupts the substrate. The emitter takes no
additional lock.

## Exit codes (the harness)

`emit.sh` returns:
- `0` ok — `bulk-write` + `mark-emitter-ran` + `validate-schema` PASS
- `2` usage / bad-arg / inputs not JSON arrays
- `4` substrate not initialised AND init failed
- `6` `bulk-write` / `mark-emitter-ran` / `validate-schema` failed (inner stderr explains)

## References

- 📄 `../topology-substrate/references/canonical-shape.md` — the frozen schema (read first; the
  `config` kind is documented there)
- 📄 `../topology-substrate/SKILL.md` — the helper API + bulk-write mandate
- 📄 `../n8n-cloud-emitter/` — Session 3 worked pattern (the in-repo n8n transform mirrors it);
  `references/n8n-workflow-shape.md` is the n8n JSON shape reference (reused)
- 📄 `../code-emitter/` — Session 4 worked pattern (the harness + chunked-write reference)
- 📄 `references/repo-config-shape.md` — the in-repo n8n FILE shape (top-level) + vercel/package
  shapes + the config-kind rationale
- 📄 `scripts/transform.jq` — the frozen one-pass transform (Part A n8n + Part B config)
- 📄 `scripts/emit.sh` — the finishing harness (validate + bulk-write + mark-ran + verify)
- `docs/operational-doctrine/05_topology-from-source.md` — §1 + §3 + Appendix C ("deploy config"
  as a read source artefact = the declared-structure in-scope grounding for vercel.json +
  package.json; §3.5 is the runtime-tracing EXCLUSION), §6.2 (the n8n emitter), §6.5.1 (per-kind
  contract incl. `config`),
  §6.6 (source-orphan / manual), A.11 (presence-vs-effectiveness), Appendix C (emitter catalogue)
- `specs/14_NEWEARTH_MASTER_BLUEPRINT_BUILD_PLAN.md` — §5 row 1+5 + §6 line 146 (names the 3
  surfaces as expected substrate contents)
- `.claude/rules/intent-actual-gap-mechanism-alignment.md` — the programme contract
- `.claude/rules/n8n-patterns.md` — project-wide n8n discipline (resource-locator, etc.)
