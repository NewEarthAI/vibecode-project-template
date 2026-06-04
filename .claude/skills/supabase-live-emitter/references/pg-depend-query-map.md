# pg_depend Query Map — the OID-resolution discipline

> **Authority**: derived from Doctrine 05 §6.2 + §6.5.1 + Appendix C, and the SQL in
> 📄 `../scripts/queries.sql`. This file is the **why** for each catalogue join the queries
> make. It is NOT user-facing — it is a reviewer's reference + a future emitter author's
> field guide.

---

## Why pg_depend is fiddly

`pg_depend` records dependencies between catalogue objects as `(classid, objid, refclassid,
refobjid)` quadruples — each id is a Postgres OID. OIDs are not human-meaningful (they
change on DDL replay). To produce canonical-shape nodes whose ids are stable (`schema.name`
instead of OID), every pg_depend join must resolve OIDs back through the appropriate
catalogue table:

| `classid` / `refclassid` value | Resolves through | Yields |
|---|---|---|
| `'pg_class'::regclass` | `pg_class` + `pg_namespace` | a relation (table/view/index/sequence) — kind = relkind |
| `'pg_proc'::regclass` | `pg_proc` + `pg_namespace` + `pg_language` | a function |
| `'pg_trigger'::regclass` | `pg_trigger` + `pg_class` (its table) + `pg_proc` (its function) | a trigger |
| `'pg_rewrite'::regclass` | `pg_rewrite` + `pg_class` (its view) | a view's rewrite rule (the path to base-table edges) |
| `'pg_policy'::regclass` | `pg_policies` (a system view that pre-joins pg_policy + pg_class + pg_namespace) | an RLS policy |
| `'pg_attribute'::regclass` | `pg_attribute` + `pg_class` | a column (we don't emit columns as nodes; we record the table's column list as `attributes.columns`) |

Get the wrong join and you produce **phantom edges** (an edge whose endpoint OID resolves
to something other than what you expected — e.g. a sequence OID instead of a function OID)
or **missing edges** (a real dependency dropped because the join didn't match).

---

## The 6 queries — what each does + the pitfall it dodges

### Q1 — tables (`pg_class.relkind='r'`)

**Joins**: `pg_class` → `pg_namespace` (schema name) → `pg_attribute LEFT JOIN` (columns).

**Pitfall**: `pg_attribute` includes system columns (`ctid`, `xmin`, etc.) at `attnum < 0`,
and dropped columns at `attisdropped=true`. Both must be filtered or the `columns` payload
becomes noise. The query's `WHERE a.attnum > 0 AND NOT a.attisdropped` does this.

**`row_estimate`**: `reltuples` is the planner's estimate after the last `ANALYZE`. Value
`-1` means autovacuum has never analysed (BuyBox-AI's typical state for many tables). This
is informational only — the topology emitter records the value but does not interpret it.

### Q2 — views (`pg_class.relkind IN ('v','m')`)

**Joins**: `pg_class` → `pg_namespace`.

**`is_materialized`**: distinguishes regular views (`'v'`) from materialised views (`'m'`).
D05 A.14 names the stale materialised view as a real failure mode (the source table
changed, the MV's body is unchanged, the MV's data is stale — the substrate records the
distinction so reconciliation can later flag staleness).

**`definition_hash`**: `md5(pg_get_viewdef(oid, true))` — a stable fingerprint of the view
body. Reconciliation will compare this against intent's expected hash; drift in the hash
means the view body was edited without an intent record (a real Class A.14-adjacent signal).
The `true` argument to `pg_get_viewdef` requests pretty-printed output so whitespace
normalisation is consistent across Postgres versions.

### Q3 — functions (`pg_proc.prokind='f'`, NOT extension-owned)

**Joins**: `pg_proc` → `pg_namespace` → `pg_language`. The extension filter is a `LEFT JOIN`
against `pg_depend` on `(objid=pg_proc.oid AND classid='pg_proc'::regclass AND deptype='e')`
with an `IS NULL` check.

**Server-side decode**: the `provolatile` character (`'i'`/`'s'`/`'v'`) is decoded into the
canonical-shape string (`"immutable"`/`"stable"`/`"volatile"`) via a `CASE` expression at
the SQL layer. The transform receives the decoded string and writes it through verbatim —
no jq decode step. This keeps the canonical-shape contract documented at the data-source
layer (where it belongs), not buried in the transform.

**Pitfall (the big one)**: Supabase installs extensions (PostGIS, pgcrypto, uuid-ossp,
pgvector, etc.) that surface ~800 functions into `public`. Without the extension filter, the
emitter would treat all of them as user code and explode the function-node count. The
`deptype='e'` row in `pg_depend` marks objects that "belong to" an extension; we exclude
them.

**Why `prokind='f'` only**: `pg_proc` includes aggregates (`'a'`) and window functions (`'w'`)
— these are functions in the Postgres sense but are almost always extension-installed in
practice, and §6.5.1 only specifies the `function` kind (no separate aggregate kind). v1
scope.

### Q4 — triggers (`NOT tgisinternal`)

**Joins**: `pg_trigger` → `pg_class` (the table the trigger fires on) → `pg_namespace`
(table's schema) → `pg_proc` (the function the trigger calls) → `pg_namespace` (function's
schema).

**`tgtype` bitmask decode**: see `queries.sql` Q4 comment for the bit values. Two pitfalls:
1. **`INSTEAD OF` triggers** (bit 64) are timing + only-on-views — we surface them with
   `timing: 'INSTEAD OF'` and the event bits (typical: INSERT/UPDATE/DELETE on a view that's
   not normally writable).
2. **`tgisinternal=true`** marks Postgres-internal triggers (e.g. foreign-key constraint
   enforcement). These are catalogue artefacts, not user-authored rules — excluding them
   keeps the trigger node list to what an operator actually wrote.

**Cross-schema function ref**: `function_schema` + `function_name` (resolved via the
`pg_proc → pg_namespace` join) so the trigger→function edge can be built with a
schema-qualified function id — same-named functions in different schemas do not collide.

**Server-side `id` pre-formation**: a same-named trigger on two different tables in the
same schema would collide if the canonical id were `schema.name`. Q4 pre-forms the id at
the SQL layer as `cn.nspname || '.' || c.relname || '.' || t.tgname` so the canonical id
includes the owning table. The transform writes it through verbatim.

### Q5 — rls_policies (`pg_policies` + `pg_class.relrowsecurity`)

**Joins**: `pg_policies` (a pre-joined system view) → `pg_class` (the policy's table) →
`pg_namespace` (table's schema).

**The load-bearing field — `enabled`**: this is **NOT** "is this policy in the catalogue"
(that's just presence in `pg_policies`). It is "is RLS *enforced* on this policy's table"
(`pg_class.relrowsecurity = true`). D05 A.11 names this exact distinction: a table can have
12 policies and still serve un-filtered rows if `relrowsecurity` is false. The substrate
records both — the policy node is in the graph, and its `enabled` attribute tells the truth
about whether it's load-bearing.

**`role`**: `pg_policies.roles` is a `text[]` of role names; we cast via `to_jsonb` so the
JSON serialisation through the MCP yields a clean JSON array (not a Postgres-array string
literal like `{authenticated}`). The source column is plural (`roles`); the alias is
singular (`role`) to match Doctrine 05 §6.5.1's attribute name. The rename is a one-time
mapping at the SQL alias and is deliberate.

**Server-side `id` pre-formation**: a same-named policy on two different tables in the same
schema would collide if the canonical id were `schema.name`. Q5 pre-forms the id at the
SQL layer as `pol.schemaname || '.' || pol.tablename || '.' || pol.policyname` so the
canonical id includes the owning table.

### Q6 — edges via `pg_rewrite` (view → base relation)

**Joins**: `pg_depend` → `pg_rewrite` (the view's rewrite rule) → `pg_class` (the view) →
`pg_namespace`; and `pg_depend.refobjid` → `pg_class` (the base relation) → `pg_namespace`.

**Pitfall 1 — column-level vs relation-level dependencies**: `pg_depend` records ONE row
per column referenced by the rewrite rule. A view that joins two tables on 5 columns total
produces ~5 rows. We `GROUP BY` the resolved relation pair so the emitter sees ONE edge per
(view, base) pair, not 5.

**Pitfall 2 — self-reference**: A view's own definition includes a reference to itself in
some catalogue paths (the rewrite rule's `ev_class` is the view). The filter `v.oid <> t.oid`
strips the self-edge.

**Pitfall 3 — cross-schema noise**: A view that references `pg_catalog.<something>` would
produce an edge whose target is in `pg_catalog`. The schema filter on BOTH endpoints
(`vn.nspname IN (:schemas) AND tn.nspname IN (:schemas)`) keeps the edge graph closed over
user schemas.

---

## Edge sources at v1 (where each edge type comes from)

| Edge type | Source | Notes |
|---|---|---|
| view → base table/view | Q6 (pg_rewrite + pg_depend) | clean for all view bodies; ~150 edges expected at BuyBox-AI |
| trigger → function | Q4 (`function_oid` + resolution) | direct catalogue ref; never missing |
| trigger → table | Q4 (`tgrelid` + resolution) | direct catalogue ref; never missing |
| rls_policy → table | Q5 (`schema` + `tablename`) | direct catalogue ref; never missing |
| function → table | **DEGENERATE for plpgsql** | Postgres limitation; v1 emits empty depends_on for plpgsql functions; documented in SKILL.md |
| table → (anything) | none (tables are leaves) | `depended_on_by` is populated by the reverse edges from the four above |

The reverse direction (`depended_on_by`) is computed once in the jq transform from the
forward edges — every edge `A -> B` produces `B.depended_on_by += [A]` so the substrate's
fan-in queries (D05 A.17 — impact ranking) work.

---

## A note on RPCs

Supabase's "RPC" is a marketing label, not a catalogue distinction. An RPC is just a
function (`pg_proc` row) that the PostgREST layer exposes through the API. v1 emits all
user functions as `kind: function`; the RPC-vs-internal distinction is a downstream
attribute (could be derived from `pg_proc.proacl` parsing or PostgREST's discovery rules)
and is deferred. Operators querying the substrate for "all RPCs" can filter by their own
RPC naming convention (e.g. `name starts with bb_` at BuyBox-AI) until a proper RPC
attribute lands.

---

## What this query map deliberately does NOT do

- **Does not emit index nodes.** Indexes are `pg_class.relkind='i'`. Spec 14 §5 estimates
  ~291 SQL nodes including indexes, but D05 §6.5.1 does not list `index` as a kind — only
  table/view/function/trigger/rls_policy + edge_function/workflow/workflow_node/ts_module.
  v1 scope.
- **Does not emit sequence nodes.** `pg_class.relkind='S'`. Same reason — not in §6.5.1.
- **Does not emit foreign-key edges.** FKs are `pg_constraint` rows; surfacing them as
  table→table edges would be valuable (D05 §6.4) but is v1 deferred (the catalogue noise
  vs signal ratio needs design work).
- **Does not parse migration files.** The provenance is the live-catalogue marker only.
  Resolving "which migration file introduced this view" is a real future capability —
  deferred to Session 2.1+ or M4.

These are noted here so a future emitter author does not silently add them; D05 §6.5.1 is
the frozen contract.
