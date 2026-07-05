# repo-config-emitter/scripts/transform.jq
# The one-pass jq transform that produces Doctrine 05 §6.1 canonical-shape nodes + edges from
# TWO in-repo source classes:
#   Part A — in-repo n8n workflow JSON files (workflow + workflow_node nodes, repo: prefix).
#            This MIRRORS the Session-3 n8n-cloud-emitter transform.jq with three changes:
#              (1) data source is a FILE, so nodes/connections live at TOP LEVEL — accessor is
#                  `$wf.nodes` / `$wf.connections`, NOT `$wf.body.nodes` (Session 3's MCP shape
#                  wrapped them under `body`).
#              (2) id prefix is `repo:<relpath>` (Session 3 used `cloud:<id>`).
#              (3) provenance is a REAL git commit (Session 3 used a live: marker).
#   Part B — vercel.json + package.json config files (one `config` node each, kind added M3
#            Session 5; emitter:manual + manual_justification; NO edges in v1).
#
# Intent-Actual-Gap Mechanism Build Programme, M3 Session 5. Schema authority:
# .claude/skills/topology-substrate/references/canonical-shape.md.
#
# INVOCATION (the Claude session driving the emit assembles the inputs; this file is the
# authoritative artefact). One worked pattern:
#
#   jq -n \
#     --slurpfile n8n_workflows /tmp/m3-session-5-emit/n8n-workflows.json \
#     --slurpfile vercel        /tmp/m3-session-5-emit/vercel.json \
#     --slurpfile package        /tmp/m3-session-5-emit/package.json \
#     --arg now "$NOW" \
#     --arg src_commit "$SRC_COMMIT" \
#     -f .claude/skills/repo-config-emitter/scripts/transform.jq \
#     > combined.json
#   jq '.nodes' combined.json > nodes.json
#   jq '.edges' combined.json > edges.json
#   bash .claude/skills/repo-config-emitter/scripts/emit.sh nodes.json edges.json "my-project"
#
# Input contract:
#   $n8n_workflows  slurped array whose single element is an array of objects, each:
#     [{
#       "relpath": "workflows/gmail-clozers-comps.json",  // repo-relative path (REQUIRED — the id prefix)
#       "id":      "<workflow id from the file>",          // n8n id (used only for attributes, NOT the node id)
#       "name":    "<human-readable>",
#       "active":  <bool>,
#       "isArchived": <bool | null>,                       // in-repo files often have null -> defaults to false
#       "tags":    [<string>, ...] OR [{name, ...}, ...],  // accepts both; transform normalises to strings
#       "nodes":   [ ... ],                                // TOP LEVEL (not under body)
#       "connections": { ... }                             // TOP LEVEL
#     }, ...]
#   $vercel   slurped array whose single element is the parsed vercel.json object (or [] if absent)
#   $package  slurped array whose single element is the parsed package.json object (or [] if absent)
#   $now          ISO 8601 UTC when this run started — the node timestamp
#   $src_commit   git short SHA of the repo (+dirty if uncommitted) — the node source_commit
#                 (in-repo files have a real commit, unlike the live MCP emitters)
#
# OUTPUT:
#   {nodes: [...], edges: [...], diagnostics: {...}} — the substrate bulk-write contract + counters

# ----- helpers -----

# A node with the 10 D05 §6.1 fields + the declared_intent_ref forward-hook. The optional
# $manual_justification arg is added ONLY for config nodes (emitter:manual); for n8n nodes it is
# passed as null and the key is omitted (a non-manual node carrying manual_justification is a
# validate-schema violation — substrate.sh line ~449).
def make_node($id; $kind; $src_file; $src_commit; $emitter; $attrs; $manual_justification):
  ({
    id: $id,
    kind: $kind,
    source_file: $src_file,
    source_commit: $src_commit,
    timestamp: $now,
    source_line: null,
    emitter: $emitter,
    depends_on: [],
    depended_on_by: [],
    attributes: $attrs,
    declared_intent_ref: null
  })
  + (if $manual_justification != null then {manual_justification: $manual_justification} else {} end);

# Extract a workflow id from an executeWorkflow node's parameters.workflowId.
# Returns the id string OR null. Handles both the plain-string and resource-locator shapes.
def extract_workflow_id($wf_id_value):
  if ($wf_id_value | type) == "string" then $wf_id_value
  elif ($wf_id_value | type) == "object" then
    (if ($wf_id_value | has("value")) then $wf_id_value.value else null end)
  else null
  end;

# Derive trigger_type from the first non-stickyNote node whose type carries a trigger marker.
# Returns the type string or "manual" as a safe default. (Same heuristic as Session 3.)
def derive_trigger_type($filtered_nodes):
  ($filtered_nodes
   | map(select(.type | test("Trigger$|webhook$|cron$|schedule$"; "i")))
   | first) as $trig
  | if $trig == null then "manual" else $trig.type end;

# ===================================================================================
# PART A — in-repo n8n workflows (mirrors Session 3; top-level accessor; repo: prefix)
# ===================================================================================

(($n8n_workflows[0] // []) | map(
  . as $wf
  # FAIL LOUD on a missing/empty relpath. relpath is the id prefix (repo:<relpath>); an absent
  # relpath would make "repo:" + null == "repo:" — a degenerate id that collides across every
  # relpath-less workflow and gets collapsed by the substrate's unique_by(.id), silently dropping
  # workflows while the diagnostics overcount them (the canonical silent-data-loss class — Session-5
  # code-council CRITICAL). error() aborts the whole transform with rc != 0; the eval + the SKILL
  # recipe both wrap the transform in `|| fail`, so a degenerate-id emit can never reach the substrate.
  | (if (($wf.relpath // "") | length) == 0
       then error("repo-config-emitter: workflow record missing required .relpath (n8n id=\($wf.id // "?"), name=\($wf.name // "?")) — relpath is the repo: id prefix; refusing to emit a degenerate \"repo:\" id")
       else . end)
  | ($wf.relpath) as $relpath
  | ("repo:" + $relpath) as $wf_id
  # FILE shape: nodes/connections at TOP LEVEL (Session 3's MCP wrapped them under .body).
  | ($wf.nodes // []) as $raw_nodes
  | ($raw_nodes | map(select(.type != "n8n-nodes-base.stickyNote"))) as $filtered_nodes
  | ($wf.connections // {}) as $connections
  # name -> id lookup (filtered nodes only). node ids are coerced to string (tostring) so a numeric
  # n8n node id resolves consistently with the workflow_node id builder below (which also tostrings)
  # — Session-5 code-council IMPORTANT (un-coerced ids aborted startswith()/string-concat downstream).
  | ($filtered_nodes | map({key: .name, value: (.id | tostring)}) | from_entries) as $name_to_id
  # tags shape normalisation (defensive — in-repo files are usually flat already, but propagation-safe).
  # Guard the ITERATION too: a bare-string `tags` (malformed but possible) would abort `(.tags//[])[]`
  # before the per-element type guard runs — Session-5 code-council IMPORTANT.
  | ([(if (($wf.tags // []) | type) == "array" then ($wf.tags // []) else [] end)[]
      | if (type == "object") then .name else . end]) as $flat_tags

  # the workflow node itself
  | make_node($wf_id; "workflow"; $relpath; $src_commit; "n8n_parser"; {
      active: ($wf.active // false),
      trigger_type: derive_trigger_type($filtered_nodes),
      name: ($wf.name // "<unnamed>"),
      archived: ($wf.isArchived // false),
      tags: $flat_tags,
      node_count: ($filtered_nodes | length),
      connection_count: ([$connections | to_entries[] | .value.main[]? | .[]?] | length),
      source_kind: "repo",
      n8n_id: ($wf.id // null)
    }; null) as $workflow_node

  # workflow_node nodes (id = repo:<relpath>:<node-guid>)
  | ($filtered_nodes | map(
      . as $n
      | make_node(
          ($wf_id + ":" + ($n.id | tostring));
          "workflow_node"; $relpath; $src_commit; "n8n_parser";
          {
            node_type: $n.type,
            position: ($n.position // [0, 0]),
            name: ($n.name // "<unnamed-node>"),
            disabled: ($n.disabled // false),
            workflow_id: $wf_id,
            parent_workflow_name: ($wf.name // "<unnamed>")
          };
          null)
    )) as $workflow_nodes

  # containment edges — workflow -> each workflow_node
  | ($workflow_nodes | map({
      source: $wf_id, target: .id, type: "contains", direction: "forward", weight: 1
    })) as $containment_edges

  # within-workflow edges — from connections (resolve name -> GUID, prefix repo:<relpath>:)
  | ([
      $connections | to_entries[] | . as $conn_entry
      | ($conn_entry.value.main // [])
      | .[] | .[]?
      | {source_name: $conn_entry.key, target_name: .node}
    ]) as $raw_within_edge_pairs

  | ($raw_within_edge_pairs | map(
      . as $pair
      | ($name_to_id[$pair.source_name] // ("unresolved:" + $pair.source_name)) as $src_guid
      | ($name_to_id[$pair.target_name] // ("unresolved:" + $pair.target_name)) as $tgt_guid
      | {
          source: (if ($src_guid | startswith("unresolved:")) then $src_guid else $wf_id + ":" + $src_guid end),
          target: (if ($tgt_guid | startswith("unresolved:")) then $tgt_guid else $wf_id + ":" + $tgt_guid end),
          type: "depends_on", direction: "forward", weight: 1
        }
    )) as $within_edges_raw

  # cross-workflow edges — executeWorkflow nodes target ANOTHER workflow.
  # In-repo targets are referenced by n8n id; the corresponding repo node id is repo:<that-file>.
  # We cannot know the target's relpath from the id alone, so we target the n8n id directly via a
  # synthetic "repo-n8n-id:<id>" form and let the idset filter resolve it ONLY if a workflow node
  # carries that n8n id. To keep v1 simple + honest, we resolve cross-workflow calls by matching
  # the target n8n id against the n8n_id attribute of workflows in THIS emit set (built below).
  | ([
      $filtered_nodes[]
      | select(.type == "n8n-nodes-base.executeWorkflow")
      | . as $exec_node
      | (extract_workflow_id($exec_node.parameters.workflowId)) as $target_n8n_id
      | select($target_n8n_id != null)
      | {
          source: ($wf_id + ":" + ($exec_node.id | tostring)),
          target_n8n_id: $target_n8n_id,
          type: "calls", direction: "forward", weight: 1
        }
    ]) as $cross_workflow_edges_raw

  | {
      workflow_node: $workflow_node,
      workflow_nodes: $workflow_nodes,
      containment_edges: $containment_edges,
      within_edges_raw: $within_edges_raw,
      cross_workflow_edges_raw: $cross_workflow_edges_raw,
      n8n_id: ($wf.id // null),
      wf_id: $wf_id
    }
)) as $per_wf

# n8n-id -> repo node id map, for resolving cross-workflow calls within this emit set.
# Keys are coerced to string (tostring): from_entries aborts on a numeric object key, and a numeric
# n8n workflow id is possible in hand-edited / older-format exports — Session-5 code-council IMPORTANT.
| ([$per_wf[] | select(.n8n_id != null) | {key: (.n8n_id | tostring), value: .wf_id}] | from_entries) as $n8n_id_to_repo_id

# resolve cross-workflow calls: target the repo node id if the target n8n id is in this set,
# else a synthetic "unresolved-workflow:<id>" (dropped by the idset filter + counted). The target
# n8n id is coerced to string for both the map lookup and the synthetic-id concat (a numeric id
# would abort the string concat) — Session-5 code-council IMPORTANT.
| ([$per_wf[].cross_workflow_edges_raw[]
    | . as $e
    | ($e.target_n8n_id | tostring) as $tgt_n8n_id_str
    | {
        source: $e.source,
        target: ($n8n_id_to_repo_id[$tgt_n8n_id_str] // ("unresolved-workflow:" + $tgt_n8n_id_str)),
        type: "calls", direction: "forward", weight: 1
      }
   ]) as $cross_workflow_edges_resolved

# ===================================================================================
# PART B — vercel.json + package.json config nodes (config kind; emitter:manual)
# ===================================================================================

| (($vercel[0] // null) as $v
   | if $v == null then []
     else [ make_node(
         "repo:vercel.json"; "config"; "vercel.json"; $src_commit; "manual";
         {
           config_type: "vercel",
           header_count: (($v.headers // []) | length),
           rewrite_count: (($v.rewrites // []) | length),
           redirect_count: (($v.redirects // []) | length)
         };
         "vercel deploy config (the declared FILE, D05 §3.5 in-scope structure); no machine dependency-emitter parses config files into edges in v1, so this is a §6.6 source-orphan-class node (emitter:manual). The deployed-state route->function binding is the M4 vercel_api OBSERVED-state emitter."
       ) ]
     end) as $vercel_nodes

| (($package[0] // null) as $p
   | if $p == null then []
     else [ make_node(
         "repo:package.json"; "config"; "package.json"; $src_commit; "manual";
         {
           config_type: "package",
           name: ($p.name // null),
           version: ($p.version // null),
           dependency_count: (($p.dependencies // {}) | length),
           dev_dependency_count: (($p.devDependencies // {}) | length),
           script_count: (($p.scripts // {}) | length),
           dependencies: ($p.dependencies // {})
         };
         "npm dependency manifest (the declared FILE, D05 §3.5 in-scope structure); no machine dependency-emitter explodes the dep tree into per-dependency nodes in v1, so this is a §6.6 source-orphan-class node (emitter:manual). Per-dependency nodes + a `dependency` kind are a v1.1 concern if M4 needs them."
       ) ]
     end) as $package_nodes

# ===================================================================================
# Assemble — flatten across all sources
# ===================================================================================

| ([$per_wf[].workflow_node]
   + [$per_wf[].workflow_nodes[]]
   + $vercel_nodes
   + $package_nodes) as $all_nodes

| ([$per_wf[].containment_edges[]]
   + [$per_wf[].within_edges_raw[]]
   + $cross_workflow_edges_resolved
   | unique_by([.source, .target, .type])) as $all_edges_raw

# Defensive idset filter — drop edges whose endpoints are not in the nodes array (out-of-scope
# cross-workflow targets + unresolved names). Count the drops for the diagnostic.
| ([ $all_nodes[].id ] | map({(.):true}) | add // {}) as $idset
| ($all_edges_raw | map(select(($idset[.source] == true) and ($idset[.target] == true)))) as $all_edges

# Diagnostic counts
| {
    workflow_count: ([$per_wf[].workflow_node] | length),
    workflow_node_count: ([$per_wf[].workflow_nodes[]] | length),
    config_node_count: (($vercel_nodes | length) + ($package_nodes | length)),
    containment_edges: ([$per_wf[].containment_edges[]] | length),
    within_edges_kept: ([$all_edges[] | select(.type == "depends_on")] | length),
    within_edges_unresolved: ([$per_wf[].within_edges_raw[] | select((.source | startswith("unresolved:")) or (.target | startswith("unresolved:")))] | length),
    cross_workflow_edges_kept: ([$all_edges[] | select(.type == "calls")] | length),
    cross_workflow_edges_skipped: (([$cross_workflow_edges_resolved[] | select(.target | startswith("unresolved-workflow:"))] | length))
  } as $diagnostics

# Re-derive depends_on / depended_on_by per node from the final edge set (the substrate's
# parent_map/child_map are recomputed from these).
| ($all_edges | group_by(.source)
              | map({key: .[0].source, value: (map(.target) | unique)})
              | from_entries) as $deps_by_src
| ($all_edges | group_by(.target)
              | map({key: .[0].target, value: (map(.source) | unique)})
              | from_entries) as $rev_by_tgt
| ($all_nodes | map(
    .depends_on       = ($deps_by_src[.id] // [])
    | .depended_on_by = ($rev_by_tgt[.id] // [])
  )) as $nodes_final

| {nodes: $nodes_final, edges: $all_edges, diagnostics: $diagnostics}
