# external-api-graph-emitter/scripts/transform.jq
# Parses TWO n8n node families from your project's workflow JSON into cross-system
# external_endpoint nodes + cross-system edges:
#   (a) HTTP-request nodes (n8n-nodes-base.httpRequest) — URL-classified
#   (b) dedicated Supabase nodes (n8n-nodes-base.supabase) — operation+tableId-classified (follow-up #4)
#   n8n workflow_node  --reads_from/writes_to-->  Supabase REST table  (public.<table>)
#                      --invokes-->               Supabase edge function (repo:supabase/functions/<name>)
#                      --calls-->                 an external API        (ext:external-api:<host><path>)
#                      --calls (blind-spot)-->    a runtime-constructed URL (={{ ... }} / {{ ... }})
#                                                 or a dedicated-Supabase-node expression tableId
# It OWNS the external_endpoint kind (emitter external_api_parser); the code emitter is the
# documented joint-attribution co-producer (canonical-shape.md "joint-attribution exception").
#
# Intent-Actual-Gap Mechanism Build Programme — visual-layer Phase 1b. Schema authority:
# ../../topology-substrate/references/canonical-shape.md. Doctrine 05 §6.5.1 (the external_endpoint row).
#
# INVOCATION (the Claude session driving the emit):
#   # $substrate_ids + $supabase_coverage read READ-ONLY from the LIVE substrate BEFORE this emit
#   # (the cross-system Supabase targets resolve against the existing table / edge_function nodes).
#   jq -n --slurpfile workflows /tmp/wfs.json \
#         --arg now "$NOW" --arg src_commit "$SRC_COMMIT" \
#         --argjson substrate_ids "$SUBSTRATE_IDS" --arg supabase_coverage "$SB_COV" \
#         -f transform.jq > combined.json
#   jq '.nodes' combined.json > nodes.json ; jq '.edges' combined.json > edges.json
#   bash emit.sh nodes.json edges.json "my-project"
#
# Input ($workflows[0] is the array of n8n workflow objects — the n8n_get_workflow shape, each with
#   .id + .nodes[]; an httpRequest node is .type matching "httpRequest", URL in .parameters.url,
#   method in .parameters.method // .parameters.requestMethod, default GET):
#
#   $now              ISO 8601 UTC of this run — node timestamp
#   $src_commit       provenance commit string (e.g. "live:<your-instance>:<wf>" or a repo SHA)
#   $substrate_ids    (OPTIONAL via $ARGS.named; default []) live substrate node-id array (resolution universe)
#   $supabase_coverage(OPTIONAL via $ARGS.named; default "") supabase-live coverage — drives R2 routing
#
# OUTPUT: {nodes:[external_endpoint...], edges:[cross-system... with .attributes{derivation,confidence}],
#          diagnostics:{...}}. Cross-system edges live ONLY in .edges (a separate render layer, R5);
#          they do NOT enter node depends_on/depended_on_by. Source workflow_node ids (cloud:<wf>:<node>)
#          must exist in the substrate (n8n-cloud emitter) for the edge write to pass referential integrity.

def as_str: if type == "string" then . else "" end;

# R9 table-literal normalisation (shared discipline with the code emitter).
def normalise_table($lit):
  ( ($lit | as_str) | ltrimstr("public.") ) as $s
  | if ($s | contains(".")) then $s else "public." + $s end;

def make_ext_node($id; $line; $relpath; $attrs):
  { id: $id, kind: "external_endpoint", source_file: $relpath, source_commit: $src_commit,
    timestamp: $now, source_line: $line, emitter: "external_api_parser",
    depends_on: [], depended_on_by: [], attributes: $attrs, declared_intent_ref: null };

# Classify one httpRequest URL. Returns an object describing the target + edge.
#   class ∈ "blindspot" | "supabase_rest" | "supabase_func" | "external"
def classify_url($url; $method):
  ( ($method | as_str | ascii_upcase) ) as $m
  | ( if ($m == "POST" or $m == "PUT" or $m == "PATCH" or $m == "DELETE") then "write" else "read" end ) as $op
  | ($url | as_str) as $u
  # n8n expression URL (runtime-constructed) -> blind-spot (D05 §3.5). Edge type is the generic
  # "calls": the HTTP node DOES make a call, but the target (and thus read/write semantics) is unknown.
  | if ($u == "") or ($u | startswith("=")) or ($u | test("\\{\\{"))
    then { class: "blindspot", op: $op, etype: "calls" }
    elif ($u | test("supabase\\.co/rest/v1/"))
      then ( $u | capture("rest/v1/(?<t>[^/?#]+)").t ) as $tbl
           | { class: "supabase_rest", op: $op, table: $tbl,
               etype: (if $op == "write" then "writes_to" else "reads_from" end) }
    elif ($u | test("supabase\\.co/functions/v1/"))
      then ( $u | capture("functions/v1/(?<f>[^/?#]+)").f ) as $fn
           | { class: "supabase_func", op: $op, fn: $fn, etype: "invokes" }
    else # an external literal URL — host + path become the external_endpoint. An UNPARSEABLE URL
         # (no scheme / no host: "localhost:3000", "10.0.0.5/x", protocol-relative "//cdn", a relative
         # path) routes to a BLIND-SPOT, it NEVER vanishes — the R2 no-silent-drop guarantee extended
         # to the external branch (code-council 2026-06-05 CRITICAL: capture() on no-match emits an
         # empty stream, which inside map() would silently collapse the element). Userinfo (user:pass@)
         # is stripped BEFORE the host capture so credentials never leak into the on-disk node id.
      ( ( $u | capture("^[a-zA-Z][a-zA-Z0-9+.-]*://(?:[^@/?#]*@)?(?<host>[^@/?#:]+)(?::[0-9]+)?(?<path>[^?#]*)") ) // null ) as $cap
      | if ($cap == null) or (($cap.host // "") == "")
        then { class: "blindspot", op: $op, etype: "calls", reason: "unparseable-url" }
        else { class: "external", op: $op, host: $cap.host, path: ($cap.path // ""), method: $m, etype: "calls" }
        end
    end;

# follow-up #4 — the dedicated n8n Supabase node (n8n-nodes-base.supabase).
# n8n resourceLocator (__rl) unwrap: a tableId may be a plain string OR a {__rl,value,mode} object.
# A null/non-rl tableId degrades to "" (-> treated as dynamic below), never throws.
def rl_value($v):
  if ($v | type) == "object" then ($v.value // "") else ($v // "") end;

# Classify one dedicated Supabase node by its operation + tableId. Mirrors classify_url's supabase_rest
# branch: read/write is INFERRED from the operation (a heuristic -> declared-medium downstream, same as the
# REST-URL path), a literal tableId -> resolved REST target, an expression/empty tableId -> blind-spot
# (never green, never dropped — the R2 no-silent-drop guarantee). The dedicated node addresses a TABLE row,
# never an edge function, so it only ever yields supabase_rest or blindspot (never supabase_func/external).
#   class ∈ "supabase_rest" | "blindspot"
def classify_supabase_node($table_raw; $operation):
  ( $operation | as_str | ascii_downcase ) as $opv
  | ( if ($opv | test("^(create|insert|update|upsert|delete)$")) then "write" else "read" end ) as $op
  | ( $table_raw | as_str ) as $t
  # An n8n expression tableId ("={{ }}" / "{{ }}") or an empty value is runtime-constructed -> blind-spot.
  | if ($t == "") or ($t | startswith("=")) or ($t | test("\\{\\{"))
    then { class: "blindspot", op: $op, etype: "calls", reason: "dynamic-table" }
    else { class: "supabase_rest", op: $op, table: $t,
           etype: (if $op == "write" then "writes_to" else "reads_from" end) }
    end;

# ===== main =====
( ($ARGS.named.substrate_ids // []) | if type=="array" then . else [] end ) as $substrate_ids
| ( ($ARGS.named.supabase_coverage // "") | as_str ) as $sbcov
| ( $substrate_ids | map({(.):true}) | add // {} ) as $universe
| ( ($workflows[0] // []) | if type=="array" then . else [] end ) as $wfs

# 1. Pull every httpRequest node across all workflows into a flat call list.
| ( [ $wfs[]
      | . as $wf
      | (($wf.nodes // []) | if type=="array" then . else [] end)[]
      | . as $n
      | select(($n.type // "") | test("httpRequest"; "i"))
      | ($n.parameters // {}) as $p
      | { wf_id: ($wf.id // "?"), node_id: ($n.id // "?"), node_name: ($n.name // ""),
          url: ($p.url // $p.endpoint // ""),
          method: ($p.method // $p.requestMethod // "GET") }
    ] ) as $http_calls

# 1b. Pull every dedicated Supabase node (follow-up #4). Matched by a `.supabase`-suffixed type so the
#     ACTION node (n8n-nodes-base.supabase) is included but the supabaseTrigger node (a trigger, not a
#     call) is NOT. tableId may be a string or an n8n resourceLocator object; operation drives read/write.
| ( [ $wfs[]
      | . as $wf
      | (($wf.nodes // []) | if type=="array" then . else [] end)[]
      | . as $n
      | select(($n.type // "") | test("\\.supabase$"; "i"))
      | ($n.parameters // {}) as $p
      | { wf_id: ($wf.id // "?"), node_id: ($n.id // "?"), node_name: ($n.name // ""),
          table_raw: rl_value($p.tableId),
          operation: ($p.operation // "") }
    ] ) as $sb_node_calls

# 2. Classify + route each call. HTTP nodes (URL-classified) + Supabase nodes (operation+tableId-classified)
#    are tagged with node_kind so step 3/4 build honest derivations, then merged into one $classified list
#    that the downstream routing/node/edge builders handle uniformly (both yield supabase_rest / blindspot
#    outcomes the existing routing already covers).
| ( $http_calls | map(
      . as $c
      | classify_url($c.url; $c.method) as $cl
      | ($c + $cl + { node_kind: "httpRequest" })
      | . as $r
      # source workflow_node id (n8n-cloud-emitter convention)
      | .source_id  = ("cloud:" + $r.wf_id + ":" + $r.node_id)
      | .src_ref    = ("n8n:" + $r.wf_id + ":" + $r.node_id)
    ) ) as $http_classified
| ( $sb_node_calls | map(
      . as $c
      | classify_supabase_node($c.table_raw; $c.operation) as $cl
      | ($c + $cl + { node_kind: "supabase" })
      | . as $r
      | .source_id  = ("cloud:" + $r.wf_id + ":" + $r.node_id)
      | .src_ref    = ("n8n:" + $r.wf_id + ":" + $r.node_id)
    ) ) as $sb_classified
| ( $http_classified + $sb_classified ) as $classified
| ( $classified | map(
      . as $r
      | if   $r.class == "blindspot"
        then .outcome = "blindspot_runtime"
             | .tgt = ("ext:blind-spot:n8n:" + $r.wf_id + ":" + $r.node_id)
             | .conf = "blind-spot"
        elif $r.class == "external"
        then .outcome = "external"
             | .tgt = ("ext:external-api:" + $r.host + $r.path)
             | .conf = "declared-high"
        else  # supabase_rest | supabase_func
          ( if $r.class == "supabase_rest" then normalise_table($r.table)
            else ("repo:supabase/functions/" + $r.fn) end ) as $tid
          | .tgt = $tid
          # confidence matches the code emitter + canonical-shape enum: a resolved REST TABLE ref is
          # declared-medium (read/write semantics inferred from the HTTP method — a heuristic), a
          # resolved FUNCTION invoke is declared-high (the function name is an unambiguous URL segment).
          | ( if ($universe[$tid] == true)
              then (.outcome = "edge" | .conf = (if $r.class == "supabase_rest" then "declared-medium" else "declared-high" end))
              elif ($sbcov == "covered")   then (.outcome = "drop"  | .conf = "n/a")
              else (.outcome = "blindspot_unresolved" | .tgt = ("ext:blind-spot:" + $tid) | .conf = "blind-spot")
              end )
        end
    ) ) as $routed

# 3. external_endpoint nodes: external-api (resolved external) + blind-spots.
| ( [ $routed[]
      | select(.outcome == "external" or .outcome == "blindspot_runtime" or .outcome == "blindspot_unresolved")
      | if .outcome == "external"
        then make_ext_node(.tgt; null; .src_ref;
               { url_host: .host, url_path_template: .path, method: .method, classification: "external-api" })
        elif .outcome == "blindspot_runtime"
        then make_ext_node(.tgt; null; .src_ref;
               { url_host: null,
                 url_path_template: (if (.node_kind // "httpRequest") == "supabase"
                                     then ("supabase node " + (.operation | as_str | if . == "" then "op?" else . end) + " (dynamic table)")
                                     else (.url | as_str) end),
                 method: null, classification: "blind-spot" })
        else make_ext_node(.tgt; null; .src_ref;
               { url_host: null, url_path_template: (.tgt | ltrimstr("ext:blind-spot:")), method: null, classification: "blind-spot" })
        end
    ] | unique_by(.id) ) as $xs_nodes

# 4. cross-system edges (drops produce none).
| ( [ $routed[]
      | select(.outcome != "drop")
      | { source: .source_id, target: .tgt, type: .etype, direction: "forward", weight: 1,
          attributes: {
            derivation: ( if (.node_kind // "httpRequest") == "supabase"
                          then ((.node_name | as_str | if . == "" then "n8n Supabase node" else "n8n Supabase node: " + . end)
                                + " -> " + (.operation | as_str | if . == "" then "op?" else . end)
                                + " " + (.table_raw | as_str | if . == "" then "<dynamic table>" else . end))
                          else ((.node_name | as_str | if . == "" then "n8n httpRequest" else "n8n httpRequest: " + . end)
                                + " -> " + (.url | as_str | if . == "" then "<no url>" else . end))
                          end ),
            confidence: .conf } }
    ] | unique_by([.source, .target, .type]) ) as $xs_edges

| { nodes: $xs_nodes,
    edges: $xs_edges,
    diagnostics: ( {
      http_nodes_seen:        ($http_calls | length),
      supabase_nodes_seen:    ($sb_node_calls | length),
      cross_system_edges_declared_high:   ([ $routed[] | select((.outcome=="edge" or .outcome=="external") and .conf=="declared-high") ]   | length),
      cross_system_edges_declared_medium: ([ $routed[] | select(.outcome=="edge" and .conf=="declared-medium") ] | length),
      cross_system_blind_spots:           ([ $routed[] | select(.outcome=="blindspot_runtime" or .outcome=="blindspot_unresolved") ] | length),
      cross_system_counted_drops:         ([ $routed[] | select(.outcome=="drop") ] | length),
      external_api_endpoints:             ([ $routed[] | select(.outcome=="external") ] | length),
      supabase_coverage_seen:             $sbcov
    } as $d
    # accounting invariant: EVERY source node (HTTP + Supabase) is ROUTED to an outcome (edge | blind-spot |
    # drop) — no silent vanish at classification time (code-council 2026-06-05; extended to Supabase nodes in
    # follow-up #4). $d.accounted MUST equal $d.total_source_nodes_seen (= http_nodes_seen + supabase_nodes_seen).
    # PRECISION (code-council 2026-06-06): "accounted" counts ROUTED calls (pre-dedup). Two source nodes that
    # collide on an identical (source_id, target, type) — possible ONLY when both lack an `id` (both then get
    # source_id "cloud:<wf>:?") — collapse to one edge under the later unique_by, and this counter does not
    # separately surface that degenerate collapse. Real n8n nodes always carry ids; a hand-built/malformed
    # workflow omitting them is the only trigger. Pre-existing on the HTTP path, not introduced here; see
    # SKILL.md "Known limitations". The surviving edge is honest (never a false-green), so the invariant's
    # core promise (no UNROUTED call) holds; only the rare id-less dedup is invisible.
    | ($d.http_nodes_seen + $d.supabase_nodes_seen) as $total
    | $d + { total_source_nodes_seen: $total,
             accounted: ($d.cross_system_edges_declared_high + $d.cross_system_edges_declared_medium
                         + $d.cross_system_blind_spots + $d.cross_system_counted_drops) } ) }
