---
name: topology-substrate
description: |
  The canonical write-and-read surface for the Master Blueprint topology graph — a single
  per-repo JSON file (.understand-anything/topology-graph.json) holding the actual dependency
  structure of a system, derived from source by emitters. Defines the Doctrine 05 §6.3 canonical
  shape ({nodes, parent_map, child_map} + heartbeat + coverage), exposes 7 atomic helpers
  (init / write-node / write-edge / bulk-write / mark-emitter-ran / read-topology / validate-schema),
  and concurrency-safe writing (single mkdir lock + jq -n -> tmp -> mv) so parallel emitter
  sessions never corrupt the substrate.
  Use when: an emitter needs to write topology nodes/edges; the health-check skill needs to read
  heartbeats; "/topology", "init the topology substrate", "write a topology node", "read the
  topology graph", "validate the topology substrate", "what does the substrate cover".
  Do NOT use for: authoring intent records (Doctrine 04 / define-destination); computing
  intent-vs-actual drift (Doctrine 06 reconciliation, M4); building the emitters themselves
  (M3 Sessions 2-5); linking topology into Obsidian (obsidian-second-brain skill consumes this
  substrate, it is not this skill).
allowed-tools: Bash, Read
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-05-25
programme: intent-actual-gap-mechanism
programme_session: M3-session-1-topology-substrate
schema_authority: references/canonical-shape.md
---

# Topology Substrate

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 1 (the foundation the M3-2..6
> emitters/health-check write to). Doctrine 05 (topology-from-source) is the schema authority. The
> verbatim schema lives in 📄 `references/canonical-shape.md` — read it before extending the shape.

## What this is

The substrate is the **single shared JSON file** every topology emitter writes to and the health-check skill
reads from. It is NOT an emitter (it derives nothing from source) and NOT a reconciler (it computes no drift).
It is the **write surface only** — the canonical graph shape (Doctrine 05 §6.3) plus a heartbeat + coverage
envelope, with atomic concurrency-safe helpers so parallel emitter sessions cannot corrupt it.

One sentence: **emitters produce nodes; this substrate stores them safely and answers "what's in the graph and
how fresh is it?".**

## When to invoke

- An emitter (M3 Sessions 2-5) needs to write nodes/edges → it calls `write-node` / `write-edge` / `bulk-write`
  via the Skill tool (keeps the atomic-write discipline centralised).
- An emitter finishes a run → it calls `mark-emitter-ran <name> <coverage>` to update its heartbeat.
- The health-check skill (M3 Session 6) reads `last_updated` + per-emitter `last_emitted_at` to surface stale-
  emitter warnings.
- The operator runs `/topology status` / `/topology validate` / `/topology read` for a plain-English view.

## The schema (summary — full spec in references/canonical-shape.md)

Top-level: `{schema_version, entity, last_updated, emitters, missing_emitters, nodes, edges, parent_map, child_map}`.

A **node** is the Doctrine 05 §6.1 **10-field** shape — `id, kind, source_file, source_commit, timestamp,
source_line, emitter, depends_on, depended_on_by, attributes` — plus **one nullable forward-hook**
`declared_intent_ref` (M4 wires it to a Doctrine 04 intent record; always null at M3-v1).

`kind` is one of the **9 domain kinds** (`table, view, function, trigger, rls_policy, edge_function, workflow,
workflow_node, ts_module`). `manual` is an **emitter** value (the source-orphan marker, D05 §6.6), NOT a kind —
a manual node still carries one of the 9 domain kinds, plus a required `manual_justification`.

`child_map[N]` = N's dependencies (what N depends on); `parent_map[N]` = N's dependents (what depends on N).
Emitters and the health-check skill MUST use these names + this direction verbatim — it is part of the frozen contract.

> **Why 10, not 17**: Doctrine 06's 17 fields are the *reconciliation invariant record* (M4), which *reads*
> this substrate as its `right_view`. Embedding them here would collapse the three-way separability the
> programme exists to earn (cross-doctrine audit: < 23% Jaccard overlap). The full rationale is the
> load-bearing finding at the top of 📄 `references/canonical-shape.md`.

`parent_map` / `child_map` are **derived redundant views** recomputed from the nodes on every write (so they
can never drift); `validate-schema` re-derives and asserts equality.

## Helper API

Run the helper script directly (or invoke this skill and call it):

```bash
bash .claude/skills/topology-substrate/scripts/substrate.sh <command> [args]
```

| Command | Purpose |
|---|---|
| `init <entity>` | create the empty substrate if absent (idempotent); seeds the 5 `missing_emitters` + 3 `emitters` at `declared-missing`/null |
| `write-node '<node-json>'` | atomic single-node upsert; bumps `last_updated`; recomputes the maps |
| `write-edge '<edge-json>'` | atomic single-edge add; fails loud if either endpoint is absent; recomputes the maps |
| `bulk-write '<nodes-json>' '<edges-json>'` | single locked batch write (emitter efficiency); recomputes the maps once |
| `mark-emitter-ran <name> <coverage>` | set `emitters.<name>.last_emitted_at = now` + coverage; rejects an unknown emitter name |
| `read-topology ['<jq-filter>']` | validate + print the substrate (optional jq projection for slicing) |
| `validate-schema` | full structural assertion (frozen keys, map equality, manual→justification); prints `PASS` or a violation list |

> **Emitters MUST use `bulk-write` for a full emitter run. `write-node` / `write-edge` are for interactive,
> single-node operations only.** Calling `write-node` in a loop over N nodes is O(N²) — the lock is taken and the
> `parent_map`/`child_map` are re-derived once per call (N times). `bulk-write` takes the lock once, validates all
> nodes in a single pass, and re-derives the maps once. At my-project scale (~1,500 nodes) the loop path is ~150s;
> `bulk-write` is one write.

**Substrate path**: `${TOPOLOGY_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/topology-graph.json}`. Per-repo,
gitignored, machine-readable. Override `TOPOLOGY_SUBSTRATE_PATH` to point at a scratch file (the evals do this).

**Exit codes**: `0` ok · `2` usage/bad-arg · `4` substrate not found (run `init`) · `5` lock held after retry ·
`6` corrupt / jq-missing / write-failed / integrity-violation.

## Concurrency model

Parallel Claude sessions can run different emitters against different worktrees of the same repo. The substrate
is a **single JSON file**, so it uses a **single whole-file `mkdir` lock** (atomic on APFS) with: a 30-minute TTL
(crashed-session self-heal), a 60-minute future-date clock-skew bound, a symlink-TOCTOU guard, fail-closed on an
unreadable lock epoch, and bounded retry. Writes are `jq -n` → `mktemp` → `mv` (atomic rename). This mirrors
`.claude/skills/_shared/goals.sh`, with the one divergence that the lock is whole-file (one substrate), not
per-id.

**Portability**: target is macOS system **bash 3.2** + **jq-1.7**. ALL structural manipulation is in jq (no bash
associative arrays). Per `.claude/rules/shell-portability.md`.

## Evals

```bash
bash .claude/skills/topology-substrate/evals/roundtrip.sh        # init -> write 3 nodes + 2 edges -> validate PASS
bash .claude/skills/topology-substrate/evals/concurrency.sh      # 8 parallel writers -> all land, no corruption
bash .claude/skills/topology-substrate/evals/missing-emitter.sh  # init substrate carries the 5 P6 markers
bash .claude/skills/topology-substrate/evals/bulk-write.sh       # bulk-write: edge accepted, re-emit wins, dedup, rejections
bash .claude/skills/topology-substrate/evals/negative-paths.sh   # every rejection rc + 8 corruption classes detected
```

Each writes to a `mktemp -d` scratch substrate and cleans up; none touches the real `.understand-anything/` path.

## Composition

- **Emitters (M3-2..5)** call the write helpers via the Skill tool.
- **Health-check (M3-6)** reads the heartbeats.
- **Reconciliation (M4)** reads this substrate as Doctrine 06's `right_view`; it does not write here.
- **obsidian-second-brain** reads the JSON and links nodes into the vault.
- **Goal-ledger** is a separate concern — an emitter run may append a "topology emit X completed" row to
  `.claude/goals/`, but the ledger is not the substrate (`dont-conflate-inflight-programme.md`).

## What this skill must NOT do

- Author intent (Doctrine 04) or compute drift (Doctrine 06) — it stores topology only.
- Carry Doctrine 06's 17 reconciliation fields per node (see the load-bearing finding).
- Add NewClaw/NewMem fields, Airtable/FUB/Podio emitter hooks, or UA-plugin coupling (spec 14 §4 locked answers).
- Use naïve overwrite (concurrency requirement) or defend a schema choice on "industry does this" (programme F4).

## References

- 📄 `references/canonical-shape.md` — the verbatim schema + the load-bearing finding
- `docs/operational-doctrine/05_topology-from-source.md` — §6.1/§6.3/§6.5.1/§6.6 + Appendix C/E
- `docs/operational-doctrine/06_conservation-law-verification.md` — the `right_view` consumer (M4)
- `specs/14_NEWEARTH_MASTER_BLUEPRINT_BUILD_PLAN.md` — §4.2 substrate decision, §4.3 heartbeat, §3 P6 markers
- `.claude/skills/_shared/goals.sh` — the atomic-write pattern mirrored here
- `.claude/rules/intent-actual-gap-mechanism-alignment.md` — the programme contract
