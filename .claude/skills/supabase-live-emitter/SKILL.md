---
name: supabase-live-emitter
description: |
  The Postgres / Supabase topology emitter — the first M3 mapper. Reads a Supabase project's
  own catalogue (pg_depend + pg_catalog + information_schema + pg_policies) READ-ONLY,
  transforms the result into Doctrine 05 §6.1 canonical-shape nodes + edges, and writes them
  via ONE bulk-write to the topology substrate (the Session-1 contract). Emits 5 node kinds —
  table, view, function, trigger, rls_policy — with the §6.5.1 typed attributes per kind. The
  rls_policy.enabled flag is the load-bearing A.11 disabled-but-present signal. Marks
  supabase-live coverage covered (heartbeat) after a successful write.
  Use when: an operator wants to populate (or refresh) a project's Supabase topology in the
  substrate; "/supabase-emit", "emit the database topology", "run the pg_depend mapper",
  "what RLS policies exist on table X", "what does view Y depend on" (after a run);
  AND/OR after a migration that changed database structure (P3 regenerate-not-edit).
  Do NOT use for: writing to the database (read-only catalogue queries only); computing
  reconciliation / drift (M4 scope); n8n / TS / Vercel emitters (M3 Sessions 3-5); editing the
  substrate code (Session-1 contract is FROZEN — compose, do not reimplement).
allowed-tools: Bash, Read, mcp__supabase-buyboxai__execute_sql
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-05-26
programme: intent-actual-gap-mechanism
programme_session: M3-session-2-supabase-live-emitter
schema_authority: ../topology-substrate/references/canonical-shape.md
---

# Supabase Live Emitter (pg_depend → topology substrate)

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 2 of ~6. **The first
> M3 emitter**: the proof the constellation (real source → canonical nodes → substrate →
> queryable) works end-to-end. Doctrine 05 (topology-from-source) is the schema authority;
> §6.2 names this emitter; §6.5.1 fixes the per-kind attributes; Appendix C catalogues it.
> The substrate's frozen contract lives in 📄 `../topology-substrate/references/canonical-shape.md` —
> read it before extending the shape.

## What this is

A Claude Code skill that reads a Supabase project's **own dependency catalogue** (`pg_depend`
+ `pg_catalog` + `information_schema` + `pg_policies`) and writes the database's actual
structure — tables, views, functions, triggers, RLS policies, and the dependency edges
between them — into the topology substrate as canonical-shape nodes. **READ-ONLY**: every
catalogue query is a SELECT; the emitter never writes to the database.

One sentence: **the database describes itself; this emitter translates that into the
substrate's canonical shape.**

## When to invoke

- A fresh repo needs its Supabase topology populated (first run).
- A migration just landed → re-run to refresh nodes/edges + bump heartbeat (P3 regenerate-not-edit).
- The health-check skill (M3 Session 6) sees `supabase-live` stale → operator re-runs this emitter.
- An operator asks "what RLS policies exist on table X" / "what depends on view Y" — the
  answer lives in the substrate; this emitter ensures the substrate is current first.

## What it emits (the §6.5.1 contract — verbatim)

| kind | source catalogue | typed `attributes` | edges produced |
|---|---|---|---|
| `table` | `pg_class.relkind='r'` + `information_schema.columns` | `columns`, `row_estimate` | (none from this kind; tables are leaves; `depended_on_by` populated reverse) |
| `view` | `pg_class.relkind IN ('v','m')` + `pg_rewrite` + `pg_depend` | `is_materialized`, `definition_hash` | `depends_on` (tables / other views) |
| `function` | `pg_proc` (filtered: `prokind='f'` + NOT extension-owned) + `pg_language` | `language`, `volatility` | `depends_on` (tables — sparse for plpgsql; see Known limitations) |
| `trigger` | `pg_trigger` (filtered: `NOT tgisinternal`) | `timing`, `event` | `depends_on` (function + table) |
| `rls_policy` | `pg_policies` + `pg_class.relrowsecurity` | **`enabled`** (A.11), `command`, `role` | `depends_on` (table) |

The `rls_policy.enabled` attribute is **load-bearing** — Doctrine 05 A.11 names the
disabled-but-present RLS policy as a real silent failure mode. Presence in `pg_policies` ≠
effectiveness; only `pg_class.relrowsecurity` on the policy's table determines whether the
policy is enforced. This emitter records both via the `enabled` flag.

## How a run works (the orchestration)

A run is **driven by the invoking Claude session** because the catalogue queries flow through
the MCP (Claude calls `mcp__supabase-<entity>__execute_sql`, parses the JSON result, runs the
jq transform in 📄 `scripts/transform.jq`, writes the resulting nodes/edges arrays to temp
files, then shells the harness). The shell script `scripts/emit.sh` is the **finishing
harness** — it takes pre-collected JSON inputs and does the validate + bulk-write + mark-ran
+ verify sequence atomically.

1. **Init the substrate** (idempotent — the harness does this itself, but calling it
   up-front is fine):
   ```bash
   bash .claude/skills/topology-substrate/scripts/substrate.sh init "<entity, e.g. BuyBox-AI>"
   ```
2. **Run the 6 catalogue queries** via `mcp__supabase-<entity>__execute_sql` (the SQL is in
   📄 `scripts/queries.sql`; see 📄 `references/pg-depend-query-map.md` for the per-query
   join discipline).
3. **Assemble canonical-shape nodes + edges via the frozen jq transform** in
   📄 `scripts/transform.jq` (one pass, no per-row fork). This is the authoritative
   spec-to-output translation — committed in the skill so the transform doesn't drift
   between invocations.
4. **Run the harness**:
   ```bash
   bash .claude/skills/supabase-live-emitter/scripts/emit.sh <nodes.json> <edges.json>
   ```
   The harness: validates the inputs are JSON arrays, calls `substrate.sh bulk-write` in ONE
   call, calls `substrate.sh mark-emitter-ran supabase-live covered`, then `substrate.sh
   validate-schema` (must return `PASS` as a complete line — anchored `^PASS$` match).

> **One `bulk-write`, not a `write-node` loop.** At BuyBox-AI scale (~1,143 nodes), a
> `write-node` loop is O(N²); `bulk-write` is one lock + one map-derivation. The substrate
> SKILL.md mandates this.

## Provenance for live catalogue rows (the design call)

A live `pg_depend` row has no git commit — there is no "the migration file that produced
this view at this commit" without resolving the migration history (deferred to a future
enhancement). To satisfy D05 §6.1 (`source_file` + `source_commit` required, validate-schema
enforces it), this emitter uses a **declared live-provenance marker**:

```
source_file:   "pg_catalog (live)"
source_commit: "live:<project-ref>:<datname>"   e.g. "live:rkjbdjxihppklvlbfywp:postgres"
source_line:   null                              (catalogue is not line-addressable)
emitter:       "pg_depend"
timestamp:     "<ISO 8601 UTC of this run>"
```

The convention is **honest by default**: anyone reading the substrate sees `"pg_catalog
(live)"` and knows the node was derived from a live catalogue read, not from a migration
file. The `live:<project-ref>:<datname>` form is deterministic per database so multi-database
substrates downstream can disambiguate. This satisfies D05 P2 (every node traces to source)
without fabricating a git commit. A future enhancement (Session 2.1 or M4) can resolve the
migration file + commit for objects whose names match a known migration row.

## Filtering decisions (LOCKED for v1 — documented per F4 anti-anchoring)

| Filter | Rule | Reason |
|---|---|---|
| Schemas | `public`, `dd_clean`, `dd_v3` (BuyBox-AI's user schemas) | The goal is the project's OWN topology, not the Supabase platform. `pg_catalog`, `information_schema`, `auth`, `storage`, `realtime`, `extensions`, `cron`, `pgbouncer`, `pgsodium`, `vault`, `graphql*`, `net`, `supabase_*` are platform/extension surface — out of scope. (For other projects, pass the schema list at invocation.) |
| Functions | `prokind='f'` AND NOT extension-owned (`pg_depend.deptype='e'`) | Skips aggregates (`prokind='a'`) and window funcs (`prokind='w'`) that came from PostGIS / pgcrypto / etc. The 801 extension-owned + 23 aggregate + 2 window functions in BuyBox-AI's `public` are platform noise, not user code. |
| Triggers | `NOT tgisinternal` | Skips PostgreSQL-internal triggers (e.g. foreign-key constraint enforcement triggers) that are catalogue artefacts, not user-authored rules. |
| Views | `relkind IN ('v','m')` | Standard views + materialised views. `is_materialized` distinguishes (A.14 stale-MV failure mode). |

## Propagation — how to rebind to a non-BuyBox-AI entity

The frontmatter's `allowed-tools` list names `mcp__supabase-buyboxai__execute_sql` —
BuyBox-AI's MCP. When `/push-to-template` propagates this skill and another entity (Nirvana,
Agency-Main) runs `/update-latest`, the operator must:

1. Update `allowed-tools` in the SKILL.md frontmatter to the receiving entity's MCP
   (e.g. `mcp__supabase-newearthai__execute_sql` for Agency-Main).
2. Update `$SRC_COMMIT` when invoking transform.jq to `live:<that-entity-project-ref>:postgres`.
3. Update the `WHERE … IN ('public', 'dd_clean', 'dd_v3')` schema filter in
   📄 `scripts/queries.sql` to that entity's user-relevant schemas (typically discoverable
   via `mcp__supabase-<entity>__list_tables` — schemas to keep are the project's own;
   skip platform schemas `pg_catalog`, `information_schema`, `auth`, `storage`, `realtime`,
   `extensions`, `cron`, `pgbouncer`, `pgsodium`, `vault`, `graphql*`, `net`, `supabase_*`).

The template-push pipeline should substitute the MCP server name as a placeholder; the
schema list and project-ref must be operator-confirmed at first run per entity.

## Scale ceiling (v1)

The harness passes the assembled nodes + edges JSON via shell argv to `substrate.sh
bulk-write`. macOS argv has a per-argument cap of roughly 1 MB and a total-argv cap near 2
MB. At BuyBox-AI today (~1,143 nodes, ~610 edges) the two argv strings total roughly
300 KB — comfortably under the cap. At roughly 3-5× scale (≈ 5,000+ nodes) the argv would
approach the ceiling; before propagating to a larger entity, **either** confirm the
catalogue size produces under 500 KB of JSON per array, **or** the substrate's `bulk-write`
gains a stdin variant (`bulk-write-stdin`) that takes the same payload via stdin and
removes the argv constraint. This is a flagged v1 ceiling, not a v1 bug.

## Known limitations (v1, documented honestly)

1. **plpgsql function→table edges are SPARSE.** Postgres's `pg_depend` does not record
   dependencies inside `plpgsql` function bodies (the body is opaque SQL to the catalogue;
   only the function's argument/return types and SQL-language function bodies leave
   pg_depend traces). BuyBox-AI's functions are dominantly `plpgsql` (per the Q3 sample), so
   most function nodes will have empty `depends_on tables`. This is a **Postgres limitation,
   not a v1 gap** — the substrate honestly reflects what the catalogue actually exposes. A
   future enhancement could parse plpgsql bodies (out of scope for v1 + Session 2.1+).
2. **Migration file/commit not yet resolved.** v1 uses the live-provenance marker (above).
   The richer "this view's last DDL was in migration `0123_add_view_X.sql` at commit `abc1234`"
   provenance is deferred.
3. **RPC ≠ separate kind.** A Supabase RPC is just a plpgsql function with API-exposed
   permissions. v1 emits it as `kind: function`; RPC-vs-internal distinction is a downstream
   attribute (e.g. via `pg_proc.proacl` parsing) — deferred.
4. **Cross-schema function references resolved by name.** The trigger→function edge uses the
   function's schema-qualified name (`<fn_schema>.<fn_name>`) so the same-named function in
   two schemas does not collide. If a function is overloaded (same name, different signatures),
   v1 uses the OID-bound row from `pg_trigger.tgfoid` to disambiguate.
5. **Function overloading collapses to one node.** Postgres allows two functions with the same
   `schema.name` but different argument signatures. The canonical id scheme (`schema.name`)
   collapses them — `bulk-write` keeps the last-write-wins record. Observed at BuyBox-AI:
   544 catalogue rows → 537 distinct ids (7 overloaded pairs). For v1 this is acceptable; a
   future enhancement could append an OID-derived suffix when a name collision is detected.
   The honest count is recoverable from the catalogue query (q3) row count vs the substrate's
   function-node count — drift is observable, not hidden.

## Composition map

| Composes with | How |
|---|---|
| `topology-substrate` skill (Session 1) | Calls `init` / `bulk-write` / `mark-emitter-ran` / `validate-schema` / `read-topology` via `substrate.sh`. **NEVER** edits substrate code. If a substrate bug surfaces, file it as a substrate issue — do not patch in this emitter. |
| `mcp__supabase-buyboxai__execute_sql` | Read-only catalogue queries (the 6 SELECTs in 📄 `scripts/queries.sql`). The emitter's allowed-tools list MUST be tightened per-entity (e.g. swap to `mcp__supabase-<entity>__execute_sql` at propagation). |
| Goal-ledger (`.claude/goals/`) | Optional v1.1 enhancement: an emitter run could append a "supabase-live topology emitted for entity X at T" row via `goals.sh`. Out of scope for v1 unless trivial — recorded as a future enhancement. |

## What this skill must NOT do (the no-go list)

- Author intent (Doctrine 04) or compute drift (Doctrine 06) — emits the actual side only.
- Edit `substrate.sh` / the substrate schema / Doctrines 04/05/06 — frozen contracts.
- Add Doctrine 06's 17 reconciliation fields per node — the load-bearing finding (collapses
  three-way separability).
- Write to the database. Read application-table DATA (only structure). Use `apply_migration`.
- Loop `write-node` (use `bulk-write`).
- Leave the provenance envelope empty (validate-schema requires it).
- Defend a schema choice on "industry does this" (F4 — M1 falsifier proved no precedent).

## Concurrency model

This emitter inherits the substrate's atomic write discipline — the substrate's whole-file
`mkdir` lock guarantees a parallel Claude session running a different emitter (M3 Sessions
3-5 once they exist) never corrupts the substrate. The emitter itself takes no additional
lock; all atomicity is in `substrate.sh`.

## Exit codes (the harness)

`emit.sh` returns:
- `0` ok — `bulk-write` succeeded + `mark-emitter-ran` succeeded + `validate-schema` PASS
- `2` usage / bad-arg / inputs not JSON arrays
- `4` substrate not initialised (run `substrate.sh init <entity>` first)
- `6` `bulk-write` / `validate-schema` / `mark-emitter-ran` failed (the inner script's stderr explains)

## References

- 📄 `../topology-substrate/references/canonical-shape.md` — the frozen schema (read first)
- 📄 `../topology-substrate/SKILL.md` — the helper API + bulk-write mandate
- 📄 `references/pg-depend-query-map.md` — the per-query OID-resolution discipline
- 📄 `scripts/queries.sql` — the 6 catalogue SELECTs (verbatim, read-only, server-side filtered + decoded)
- 📄 `scripts/transform.jq` — the frozen one-pass jq transform from catalogue rows to canonical-shape nodes + edges
- `docs/operational-doctrine/05_topology-from-source.md` — §6.2 (this emitter), §6.5.1
  (per-kind contract), Appendix C (the emitter catalogue), A.11 + A.14 + A.17
- `specs/14_NEWEARTH_MASTER_BLUEPRINT_BUILD_PLAN.md` — §5 (sequence; note the §3-vs-§5 MCP-name contradiction)
- `.claude/rules/intent-actual-gap-mechanism-alignment.md` — the programme contract
