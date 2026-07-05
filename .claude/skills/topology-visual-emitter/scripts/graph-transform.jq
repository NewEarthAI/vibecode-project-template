# topology-visual-emitter/scripts/graph-transform.jq
# Transform the FROZEN topology substrate (read-topology '.' output) into the render-target-agnostic
# graph.json. Output contract: references/graph-shape.md. READ-ONLY over the substrate.
#
# Intent-Actual-Gap Mechanism Build Programme, visual layer. Mirrors the multi-pass structure +
# defensive coercion of code-emitter/scripts/transform.jq.
#
# Phase 2 (2026-06-06, council 2026-06-06-visual-layer-phase-2-renderer-gate.md) added the cross-system
# render layer: external_endpoint render mapping + per-edge cross_system/confidence derivation + the
# has_blind_spot_edges chip signal. Amendments A1/A2/A5/A8 from that council are implemented here.
#
# INVOCATION:
#   bash .claude/skills/topology-substrate/scripts/substrate.sh read-topology '.' \
#     | jq --arg now "$NOW" -f .claude/skills/topology-visual-emitter/scripts/graph-transform.jq
#
#   $now  ISO 8601 UTC of this run — graph.json generated_at
# OUTPUT: the graph.json envelope ({schema_version, entity, generated_at, ..., nodes, edges, layers, ...}).

# ===== helpers (defensive coercion at the input boundary — degrade, never abort) =====
def as_str: if type == "string" then . else "" end;
def as_arr: if type == "array"  then . else []  end;

# short human label: last segment after the final ':' then the final '/'
def label_of: as_str | (split(":") | last) | (split("/") | last);

# kind -> render_kind (the visual class the viewer dispatches shape/colour on)
def render_kind:
  {"table":"table","view":"schema","function":"function","trigger":"service",
   "rls_policy":"policy","edge_function":"service","workflow":"group",
   "workflow_node":"code","ts_module":"code","config":"config",
   "external_endpoint":"external"}[.] // "node";

# kind -> category (the filter bucket)
def category_of:
  {"table":"data","view":"data","function":"data","trigger":"data","rls_policy":"data",
   "edge_function":"automation","workflow":"automation","workflow_node":"automation",
   "ts_module":"code","config":"config","external_endpoint":"external"}[.] // "code";

# the workflow a workflow_node belongs to: its first depends_on target whose kind is workflow
def wf_parent($n; $nodemap):
  (($n.depends_on | as_arr) | map(select(($nodemap[.] // {}).kind == "workflow")) | first);

# layer id for a node (design §2.1 container model)
def layer_id($n; $nodemap):
  if ($n.kind) == "workflow" then "layer:workflow:" + ($n.id | as_str)
  elif ($n.kind) == "workflow_node" then
    (wf_parent($n; $nodemap) as $wf
     | if $wf != null then "layer:workflow:" + $wf else "layer:automation" end)
  elif ($n.kind) == "external_endpoint" then "layer:external"
  else "layer:" + (($n.kind | as_str) | category_of) end;

def layer_name:
  if   . == "layer:data"       then "Database"
  elif . == "layer:automation" then "Automation & Deploy"
  elif . == "layer:code"       then "Code"
  elif . == "layer:config"     then "Config"
  elif . == "layer:external"   then "External APIs"
  elif (startswith("layer:workflow:")) then (ltrimstr("layer:workflow:") | label_of)
  else . end;

# ===== pass 1 — collect: substrate + node map + id set =====
. as $sub
| ($sub.nodes | as_arr) as $nodes
| (reduce $nodes[] as $n ({}; .[$n.id | as_str] = $n)) as $nodemap
| (reduce $nodes[] as $n ({}; .[$n.id | as_str] = true)) as $idset

# ===== pass 2 — map nodes to render nodes =====
| ($nodes | map(
    . as $n
    | { id:          ($n.id | as_str),
        kind:        ($n.kind | as_str),
        render_kind: (($n.kind | as_str) | render_kind),
        category:    (($n.kind | as_str) | category_of),
        label:       ($n.id | label_of),
        emitter:     ($n.emitter // "manual"),
        coverage:    "covered",                                  # presence ⇒ emitted (dark dims carry no nodes)
        layer:       layer_id($n; $nodemap),
        source:      (($n.source_file | as_str) + "@" + ($n.source_commit | as_str)),
        attributes:  ($n.attributes // {}) }
  )) as $render_nodes

# ===== pass 2b — id -> layer map (A5: reduce, NEVER map+add — add on [] is null; this is safe on []) =====
# Built from the COMPLETED $render_nodes (which already resolved each node's layer), as its own binding
# BEFORE the edge pass. The idset pre-filter in pass 3 guarantees both endpoints are present render nodes,
# so the lookup never legitimately hits null; if it ever did, the OR-with-confidence keeps cross-system
# classification correct (a confidence-bearing edge is still cross_system even with a layer-map miss).
| (reduce $render_nodes[] as $rn ({}; .[$rn.id] = $rn.layer)) as $layermap

# ===== pass 3 — edges, idset-filtered (drop danglers — defensive, mirrors code-emitter step 4) =====
# Phase 2: carry attributes (cross-system only) + derive cross_system + confidence.
#   cross_system = the edge carries a confidence attribute (the data contract writes {derivation,confidence}
#                  ONLY on cross-system edges)  OR  its endpoints sit in different layers  OR  EITHER
#                  endpoint is an external_endpoint. The third test is load-bearing: an external→external
#                  edge has both endpoints in layer:external, so the layer-diff test alone would MISS it
#                  and silently render it as a within-system grey line (a confidence-less such edge would
#                  not be caught by the first test either). The kind test closes that hole; combined with
#                  the A2 fail-safe below, a confidence-less cross-system edge becomes a blind-spot, never
#                  a silent within-system downgrade.
#   confidence   = the carried confidence; A2 KEYSTONE FAIL-SAFE: a cross-system edge with an UNKNOWN
#                  confidence (attributes null/missing) is forced to "blind-spot" (amber) — unknown
#                  confidence must fail TOWARD the amber marker, NEVER toward green/declared-high.
| (($sub.edges | as_arr) | map(select($idset[.source] and $idset[.target]))
   | map(
       . as $e
       | ($e.attributes // null) as $attr
       | ($attr.confidence // null) as $raw_conf
       | ( ($raw_conf != null)
           or ($layermap[$e.source] != $layermap[$e.target])
           or ((($nodemap[$e.source] // {}).kind // "") == "external_endpoint")
           or ((($nodemap[$e.target] // {}).kind // "") == "external_endpoint") ) as $xs
       | ( if $xs and ($raw_conf == null) then "blind-spot" else $raw_conf end ) as $conf
       | { source:       $e.source,
           target:       $e.target,
           type:         ($e.type // "depends_on"),
           weight:       ($e.weight // 1),
           cross_system: $xs,
           confidence:   $conf,
           attributes:   (if $xs then $attr else null end) }
     )) as $render_edges

# ===== pass 4 — derive layers from the render nodes' layer ids =====
| ($render_nodes | group_by(.layer) | map(
    { id:       .[0].layer,
      name:     (.[0].layer | layer_name),
      category: .[0].category,
      nodeIds:  (map(.id)) }
  )) as $layers

# ===== pass 5 — assemble the envelope; parent_map/child_map carried verbatim (substrate-validated) =====
| { schema_version:      "visual-v1",
    entity:              ($sub.entity // "unknown"),
    generated_at:        ($now // ""),
    source_last_updated: ($sub.last_updated // null),
    coverage: { emitters:         (($sub.emitters // {}) | map_values(.coverage)),
                missing_emitters: ($sub.missing_emitters // []) },
    has_blind_spot_edges: ($render_edges | any(.confidence == "blind-spot")),   # A1: chip fail-safe signal
    nodes:      $render_nodes,
    edges:      $render_edges,
    layers:     $layers,
    parent_map: ($sub.parent_map // {}),
    child_map:  ($sub.child_map  // {}) }
