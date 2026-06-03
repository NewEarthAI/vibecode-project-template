# supabase-live-emitter/scripts/transform.jq
# The one-pass jq transform from the 6 catalogue query results into Doctrine 05 §6.1
# canonical-shape nodes + edges.
#
# Intent-Actual-Gap Mechanism Build Programme, M3 Session 2. Schema authority:
# .claude/skills/topology-substrate/references/canonical-shape.md.
#
# INVOCATION (the Claude session driving the emit assembles this in-memory; this file is the
# authoritative artefact). One worked pattern:
#
#   jq -n \
#     --slurpfile q1 q1-tables.json \
#     --slurpfile q2 q2-views.json \
#     --slurpfile q3 q3-functions.json \
#     --slurpfile q4 q4-triggers.json \
#     --slurpfile q5 q5-rls.json \
#     --slurpfile q6 q6-edges.json \
#     --arg now "$NOW" \
#     --arg src_commit "$SRC_COMMIT" \
#     -f .claude/skills/supabase-live-emitter/scripts/transform.jq \
#     > combined.json
#   jq '.nodes' combined.json > nodes.json
#   jq '.edges' combined.json > edges.json
#   bash .claude/skills/supabase-live-emitter/scripts/emit.sh nodes.json edges.json "$ENTITY"
#
# Provenance constants (lifted into the jq scope via --arg):
#   $now         ISO 8601 UTC when this run started — the node timestamp
#   $src_commit  e.g. "live:<project-ref>:postgres" (per the SKILL.md §4 decision)
#
# Source convention: every node carries the live marker — source_file "pg_catalog (live)",
# source_line null, emitter "pg_depend", declared_intent_ref null (M4 will wire it).

def make_node($id; $kind; $attrs):
  {
    id: $id,
    kind: $kind,
    source_file: "pg_catalog (live)",
    source_commit: $src_commit,
    timestamp: $now,
    source_line: null,
    emitter: "pg_depend",
    depends_on: [],
    depended_on_by: [],
    attributes: $attrs,
    declared_intent_ref: null
  };

# Tables (Q1): id = schema.name; attributes = {columns, row_estimate}
($q1[0] | map(
  make_node(.schema + "." + .name; "table";
            {columns: .columns, row_estimate: .row_estimate})
)) as $table_nodes

# Views (Q2): id = schema.name; attributes = {is_materialized, definition_hash}
| ($q2[0] | map(
  make_node(.schema + "." + .name; "view";
            {is_materialized: .is_materialized, definition_hash: .definition_hash})
)) as $view_nodes

# Functions (Q3): id = schema.name; attributes = {language, volatility (decoded server-side)}
# Note: Q3 volatility is now decoded in SQL (CASE on provolatile -> immutable/stable/volatile),
# so the value here is already the canonical-shape string — no jq decode needed.
| ($q3[0] | map(
  make_node(.schema + "." + .name; "function";
            {language: .language, volatility: .volatility})
)) as $function_nodes

# Triggers (Q4): id = SQL-pre-formed schema.table.name (collision-safe across tables);
# attributes = {timing, event}.
| ($q4[0] | map(
  make_node(.id; "trigger";
            {timing: .timing, event: .event})
)) as $trigger_nodes

# RLS policies (Q5): id = SQL-pre-formed schema.table.policy_name (collision-safe across
# tables); attributes = {enabled, command, role}. The `enabled` flag is the A.11
# load-bearing signal (presence != effectiveness — only true when the table's
# pg_class.relrowsecurity is on).
| ($q5[0] | map(
  make_node(.id; "rls_policy";
            {enabled: .enabled, command: .command, role: .role})
)) as $rls_nodes

# Concatenate all nodes for the substrate.
| ($table_nodes + $view_nodes + $function_nodes + $trigger_nodes + $rls_nodes) as $all_nodes

# Edges (4 sources):
# (a) view -> base relation (Q6's source_id/target_id are already schema.name)
| ($q6[0] | map({source: .source_id, target: .target_id, type: .edge_type,
                 direction: "forward", weight: 1})) as $view_edges

# (b) trigger -> function (Q4.id -> function_schema.function_name)
| ($q4[0] | map({source: .id,
                 target: (.function_schema + "." + .function_name),
                 type: "depends_on", direction: "forward", weight: 1})) as $trigger_fn_edges

# (c) trigger -> table (Q4.id -> schema.table_name)
| ($q4[0] | map({source: .id,
                 target: (.schema + "." + .table_name),
                 type: "depends_on", direction: "forward", weight: 1})) as $trigger_table_edges

# (d) rls_policy -> table (Q5.id -> schema.table_name)
| ($q5[0] | map({source: .id,
                 target: (.schema + "." + .table_name),
                 type: "depends_on", direction: "forward", weight: 1})) as $rls_table_edges

# Concatenate + dedupe by (source, target, type) — re-emits + repeated targets collapse.
| ($view_edges + $trigger_fn_edges + $trigger_table_edges + $rls_table_edges
   | unique_by([.source, .target, .type])) as $all_edges_raw

# Defensive filter: drop edges whose endpoints are not in the nodes array. The queries are
# designed to keep endpoints in user-schemas (Q4/Q5 join through pg_namespace; Q6 has the
# schema filter on both endpoints), so this should never fire — but a future filter drift
# would silently emit dangling edges into the substrate, which then loud-rejects via the
# bulk-write integrity check. Better to drop here with the safe-fail rather than fail the
# whole emit. Uses object-membership for O(N+E), not O(N*E) index() scans.
| ([ $all_nodes[].id ] | map({(.):true}) | add // {}) as $idset
| ($all_edges_raw | map(select(($idset[.source] == true) and ($idset[.target] == true))))
    as $all_edges

# Re-derive depends_on / depended_on_by per node from the final edges set. This makes the
# node arrays the source-of-truth for the substrate's parent_map / child_map derivation.
| ($all_edges | group_by(.source)
              | map({key: .[0].source, value: (map(.target) | unique)})
              | from_entries) as $deps_by_src
| ($all_edges | group_by(.target)
              | map({key: .[0].target, value: (map(.source) | unique)})
              | from_entries) as $rev_by_tgt
| ($all_nodes | map(
    .depends_on        = ($deps_by_src[.id] // [])
    | .depended_on_by  = ($rev_by_tgt[.id] // [])
  )) as $nodes_final

| {nodes: $nodes_final, edges: $all_edges}
