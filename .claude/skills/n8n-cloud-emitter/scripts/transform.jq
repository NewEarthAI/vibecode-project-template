# n8n-cloud-emitter/scripts/transform.jq
# The one-pass jq transform from n8n MCP workflow payloads into Doctrine 05 §6.1
# canonical-shape nodes + edges.
#
# Intent-Actual-Gap Mechanism Build Programme, M3 Session 3. Schema authority:
# .claude/skills/topology-substrate/references/canonical-shape.md.
#
# INVOCATION (the Claude session driving the emit assembles this in-memory; this file is
# the authoritative artefact). One worked pattern:
#
#   jq -n \
#     --slurpfile workflows /tmp/m3-session-3-emit/workflows.json \
#     --arg now "$NOW" \
#     --arg src_commit_prefix "live:<instance>:" \
#     -f .claude/skills/n8n-cloud-emitter/scripts/transform.jq \
#     > combined.json
#   jq '.nodes' combined.json > nodes.json
#   jq '.edges' combined.json > edges.json
#   bash .claude/skills/n8n-cloud-emitter/scripts/emit.sh nodes.json edges.json "your-entity"
#
# Input contract:
#   $workflows is a slurped array whose single element is an array of objects:
#     [{
#       "id": "<workflow_id>",
#       "name": "<human-readable>",
#       "active": <bool>,
#       "isArchived": <bool>,
#       "tags": [<string>, ...] OR [{id, name, ...}, ...],  // accepts both shapes;
#                                                            // n8n MCP returns objects,
#                                                            // transform normalises to strings
#       "fetch_mode": "active|full",     // which mode succeeded (harness MUST set explicitly)
#       "body": {                        // REQUIRED wrapper; the MCP returns nodes/connections
#         "nodes": [ ... ],              // at top level — Claude session must wrap them
#         "connections": { ... }         // under "body" before passing to transform
#       }
#     }, ...]
#
#   $now           ISO 8601 UTC when this run started — the node timestamp
#   $src_commit_prefix  "live:<instance>:" — the per-workflow id is concatenated by the
#                       transform to produce the per-node source_commit
#
# OUTPUT:
#   {nodes: [...], edges: [...]} — the substrate bulk-write contract

# ----- helpers -----

def make_node($id; $kind; $src_commit; $attrs):
  {
    id: $id,
    kind: $kind,
    source_file: "n8n_cloud (live)",
    source_commit: $src_commit,
    timestamp: $now,
    source_line: null,
    emitter: "n8n_parser",
    depends_on: [],
    depended_on_by: [],
    attributes: $attrs,
    declared_intent_ref: null
  };

# Extract a workflow id from an executeWorkflow node's parameters.workflowId.
# Returns the id string OR null if missing / unrecognised shape.
def extract_workflow_id($wf_id_value):
  if ($wf_id_value | type) == "string" then $wf_id_value
  elif ($wf_id_value | type) == "object" then
    if ($wf_id_value | has("value")) then $wf_id_value.value
    else null
    end
  else null
  end;

# Derive the trigger_type from the first non-stickyNote node whose type carries a
# trigger / webhook / schedule marker. n8n workflows have an implicit "trigger type" =
# the type of the entry node. We use a simple heuristic: first node whose type
# matches a known trigger pattern. Returns the type string or "manual" as a safe default.
def derive_trigger_type($filtered_nodes):
  # The Trigger$ alternate already matches manualTrigger, scheduleTrigger,
  # errorTrigger, executeWorkflowTrigger, gmailTrigger, twilioTrigger, etc.
  ($filtered_nodes
   | map(select(.type | test("Trigger$|webhook$|cron$|schedule$"; "i")))
   | first) as $trig
  | if $trig == null then "manual"
    else $trig.type
    end;

# ----- main transform -----

# 1. Per-workflow processing — produce {workflow_node, workflow_node_nodes[], edges[], stats}
($workflows[0] | map(
  . as $wf
  | ($wf.body.nodes // []) as $raw_nodes
  | ($raw_nodes | map(select(.type != "n8n-nodes-base.stickyNote"))) as $filtered_nodes
  | ($wf.body.connections // {}) as $connections
  # Build name -> id lookup for this workflow (filtered_nodes only — connections from /
  # to stickyNotes would be malformed n8n anyway).
  | ($filtered_nodes | map({key: .name, value: .id}) | from_entries) as $name_to_id
  | ($src_commit_prefix + $wf.id) as $wf_src_commit
  | ("cloud:" + $wf.id) as $wf_id

  # workflow node itself
  # tags shape normalisation: n8n MCP returns tags as ARRAY OF OBJECTS
  # (`[{id, name, createdAt, updatedAt}, ...]`); the substrate stores them as
  # ARRAY OF STRINGS for operator-readability + downstream query simplicity.
  # The Claude session SHOULD pre-flatten, but the transform also normalises
  # defensively here so the contract is enforced at the transform boundary
  # rather than verbally in queries.md (Session-3 code-council CRITICAL —
  # "tags shape verbal-contract" failure class).
  | ([($wf.tags // [])[] | if (type == "object") then .name else . end]) as $flat_tags
  | make_node($wf_id; "workflow"; $wf_src_commit; {
      active: ($wf.active // false),
      trigger_type: derive_trigger_type($filtered_nodes),
      name: ($wf.name // "<unnamed>"),
      archived: ($wf.isArchived // false),
      tags: $flat_tags,
      node_count: ($filtered_nodes | length),
      connection_count: ([$connections | to_entries[] | .value.main[]? | .[]?] | length),
      fetch_mode: ($wf.fetch_mode // "unknown")
    }) as $workflow_node

  # workflow_node nodes (the individual flow nodes inside this workflow)
  | ($filtered_nodes | map(
      . as $n
      | make_node(
          "cloud:" + $wf.id + ":" + $n.id;
          "workflow_node";
          $wf_src_commit;
          {
            node_type: $n.type,
            position: ($n.position // [0, 0]),
            name: ($n.name // "<unnamed-node>"),
            disabled: ($n.disabled // false),
            workflow_id: $wf_id,
            parent_workflow_name: ($wf.name // "<unnamed>")
          }
        )
    )) as $workflow_nodes

  # containment edges — workflow -> each of its workflow_nodes
  | ($workflow_nodes | map({
      source: $wf_id,
      target: .id,
      type: "contains",
      direction: "forward",
      weight: 1
    })) as $containment_edges

  # within-workflow edges — derived from connections (resolve name -> GUID)
  | ([
      $connections
      | to_entries[]                       # {key: <source_name>, value: {main: [...]}}
      | . as $conn_entry
      | ($conn_entry.value.main // [])     # array of branches
      | .[]                                 # iterate branches (collapsed to one edge per (src,tgt) at end)
      | .[]?                                # iterate targets in a branch
      | {
          source_name: $conn_entry.key,
          target_name: .node
        }
    ]) as $raw_within_edge_pairs

  | ($raw_within_edge_pairs | map(
      . as $pair
      | ($name_to_id[$pair.source_name] // ("unresolved:" + $pair.source_name)) as $src_guid
      | ($name_to_id[$pair.target_name] // ("unresolved:" + $pair.target_name)) as $tgt_guid
      | {
          source: (if ($src_guid | startswith("unresolved:")) then $src_guid else "cloud:" + $wf.id + ":" + $src_guid end),
          target: (if ($tgt_guid | startswith("unresolved:")) then $tgt_guid else "cloud:" + $wf.id + ":" + $tgt_guid end),
          type: "depends_on",
          direction: "forward",
          weight: 1
        }
    )) as $within_edges_raw

  # cross-workflow edges — from executeWorkflow nodes
  | ([
      $filtered_nodes[]
      | select(.type == "n8n-nodes-base.executeWorkflow")
      | . as $exec_node
      | (extract_workflow_id($exec_node.parameters.workflowId)) as $target_wf_id
      | select($target_wf_id != null)
      | {
          source: ("cloud:" + $wf.id + ":" + $exec_node.id),
          target: ("cloud:" + $target_wf_id),
          type: "calls",
          direction: "forward",
          weight: 1
        }
    ]) as $cross_workflow_edges_raw

  | {
      workflow_node: $workflow_node,
      workflow_nodes: $workflow_nodes,
      containment_edges: $containment_edges,
      within_edges_raw: $within_edges_raw,
      cross_workflow_edges_raw: $cross_workflow_edges_raw
    }
)) as $per_wf

# 2. Flatten across all workflows
| ([$per_wf[].workflow_node] + [$per_wf[].workflow_nodes[]]) as $all_nodes
| ([$per_wf[].containment_edges[]]
   + [$per_wf[].within_edges_raw[]]
   + [$per_wf[].cross_workflow_edges_raw[]]
   | unique_by([.source, .target, .type])) as $all_edges_raw

# 3. Defensive idset filter — drop edges whose endpoints are not in the nodes array.
# Cross-workflow "calls" edges may target an out-of-scope workflow id (not present in our
# substrate); those are SKIPPED here. Unresolved-name edges (synthetic "unresolved:<name>"
# targets) are also dropped — and we count them so the completeness diagnostic can surface
# them. Uses object-membership for O(N+E), not O(N*E) index() scans.
| ([ $all_nodes[].id ] | map({(.):true}) | add // {}) as $idset
| ($all_edges_raw | map(select(($idset[.source] == true) and ($idset[.target] == true))))
    as $all_edges

# 4. Diagnostic counts — for the harness to print
| {
    workflow_count: ([$per_wf[].workflow_node] | length),
    workflow_node_count: ([$per_wf[].workflow_nodes[]] | length),
    containment_edges: ([$per_wf[].containment_edges[]] | length),
    within_edges_kept: ([$all_edges[] | select(.type == "depends_on")] | length),
    within_edges_unresolved: ([$per_wf[].within_edges_raw[] | select((.source | startswith("unresolved:")) or (.target | startswith("unresolved:")))] | length),
    cross_workflow_edges_kept: ([$all_edges[] | select(.type == "calls")] | length),
    cross_workflow_edges_skipped: (([$per_wf[].cross_workflow_edges_raw[]] | length) - ([$all_edges[] | select(.type == "calls")] | length))
  } as $diagnostics

# 5. Re-derive depends_on / depended_on_by per node from the final edges set. This makes
# the node arrays the source-of-truth for the substrate's parent_map / child_map.
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

| {nodes: $nodes_final, edges: $all_edges, diagnostics: $diagnostics}
