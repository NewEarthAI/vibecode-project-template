# code-emitter/scripts/transform.jq
# The one-pass jq transform from the extractor driver's JSONL (extract.mjs output) into
# Doctrine 05 §6.1 canonical-shape ts_module + edge_function nodes + within-repo `imports`
# edges.
#
# Intent-Actual-Gap Mechanism Build Programme, M3 Session 4. Schema authority:
# .claude/skills/topology-substrate/references/canonical-shape.md.
#
# INVOCATION (the Claude session driving the emit):
#
#   jq -s '.' /tmp/code-emit/extracted.jsonl > /tmp/code-emit/records.json
#   # Phase 1a cross-system resolution inputs — read READ-ONLY from the LIVE substrate BEFORE this
#   # emit writes (the cross-system targets — tables, edge fns — are resolved against existing nodes).
#   # Both are OPTIONAL (omit them for a within-repo-only emit): the transform reads them via
#   # $ARGS.named with safe defaults [] / "" so a caller that omits them never errors.
#   SUBSTRATE_IDS="$(bash .../topology-substrate/scripts/substrate.sh read-topology '[.nodes[].id]' 2>/dev/null || echo '[]')"
#   SB_COV="$(bash .../topology-substrate/scripts/substrate.sh read-topology '.emitters["supabase-live"].coverage' 2>/dev/null | tr -d '"')"
#   jq -n \
#     --slurpfile records /tmp/code-emit/records.json \
#     --arg now "$NOW" \
#     --arg src_commit "$SRC_COMMIT" \
#     --argjson alias_map '{"@":"src"}' \
#     --argjson substrate_ids "$SUBSTRATE_IDS" \
#     --arg supabase_coverage "$SB_COV" \
#     -f .claude/skills/code-emitter/scripts/transform.jq \
#     > /tmp/code-emit/combined.json
#   jq '.nodes' /tmp/code-emit/combined.json > /tmp/code-emit/nodes.json
#   jq '.edges' /tmp/code-emit/combined.json > /tmp/code-emit/edges.json
#   bash .claude/skills/code-emitter/scripts/emit.sh nodes.json edges.json "my-project"
#
# Input contract ($records is a slurped array whose single element is the array of records):
#   Each record (one per file, from extract.mjs):
#     { "kind": "ts_module"|"edge_function",
#       "rel_path": "<repo-relative, forward-slashed>",
#       "byte_size": N,
#       "language": "typescript"|"typescript-react",
#       "analysis": { functions:[...], classes:[...],
#                     imports:[{source,specifiers,lineNumber}...], exports:[{name,...}...] },
#       "supabase_calls": [ {call:"from"|"invoke", op:"read"|"write", dynamic:bool,
#                            literal:"<str>"|null, line:N}, ... ],   // Phase 1a; [] when absent
#       "fetch_calls":    [ {url:"<str>"|null, method:"GET"|..., dynamic:bool, line:N}, ... ],
#                                                                    // follow-up #1; [] when absent
#       "extractor_error": "<msg>"? }            // present ONLY on parse failure
#   The trailing { "__diagnostics": {...} } footer record is DROPPED here.
#
#   $now              ISO 8601 UTC of this run — the node timestamp
#   $src_commit       git short SHA (with optional +dirty) — applied to all nodes
#   $alias_map        tsconfig paths aliases as {"<alias-prefix>": "<dir>"} (my-project: {"@":"src"})
#   $substrate_ids    (OPTIONAL, via $ARGS.named; default []) the LIVE substrate node-id array —
#                     the resolution universe for cross-system targets (read READ-ONLY pre-emit).
#   $supabase_coverage (OPTIONAL, via $ARGS.named; default "") the supabase-live emitter coverage —
#                     drives the R2 unresolved-target routing (covered=counted-drop; else=blind-spot).
#
# OUTPUT:  {nodes: [... + blind-spot external_endpoint nodes], edges: [... within-repo imports +
#          cross-system reads_from/writes_to/invokes edges with .attributes{derivation,confidence}],
#          diagnostics: {... + cross_system_* counters}}. Cross-system edges live ONLY in .edges
#          (a separate render layer) and do NOT enter node depends_on/depended_on_by (R5).

# ===== helpers =====

# Defensive coercion at the transform's INPUT boundary. The transform's only documented
# caller is extract.mjs (which normalises every field), but the transform is the contract
# boundary and must not assume that. A non-string import source or a non-array analysis field
# from a future UA version (or any other caller) would otherwise throw inside test()/
# startswith()/map()/length and abort the ENTIRE emit on one bad record. These coercers
# degrade a bad value to a safe empty rather than aborting.
def as_str: if type == "string" then . else "" end;
def as_arr: if type == "array" then . else [] end;

# Asset extensions — imports of these are skipped (not code).
def is_asset($src):
  ($src | test("\\.(css|scss|sass|less|svg|png|jpe?g|gif|webp|json|md|txt|woff2?|ttf|eot|ico)$"; "i"));

# Deno / external URL import.
def is_url($src):
  ($src | test("^https?://"));

# Is this an alias import for one of the alias_map keys? Returns the matched alias key or null.
# Matches `<alias>` bare or `<alias>/...`. The `@` ambiguity (alias vs npm scope) is resolved
# here: alias key "@" matches "@/x" (startswith "@/") but NOT "@scope/x".
def alias_match($src):
  ( $alias_map
    | to_entries
    | map(.key)
    | sort_by(-(length))                          # longest alias first (avoid short-key shadowing)
    # bind the element to $k — inside `$src | startswith(...)` a bare `.` would refer to
    # $src (the pipe input), NOT the array element, so the test must use $k explicitly.
    | map(. as $k | select($src == $k or ($src | startswith($k + "/"))))
    | first ) // null;

def is_relative($src):
  ($src | (startswith("./") or startswith("../")));

# Normalise a path with . and .. segments. Input is a "/"-joined path; output is normalised.
# e.g. "src/components/../lib/x" -> "src/lib/x"; "src/./y" -> "src/y".
def normalise_path($p):
  ( $p | split("/")
       | reduce .[] as $seg ([];
           if   $seg == "" or $seg == "." then .
           elif $seg == ".." then (if (length > 0 and .[-1] != "..") then .[0:-1] else . + [$seg] end)
           else . + [$seg] end)
       | join("/") );

# dirname for a "/"-joined relpath. "src/a/b.ts" -> "src/a"; "x.ts" -> "".
def dirof($p):
  ( $p | split("/") | if length <= 1 then "" else .[0:-1] | join("/") end );

# Resolve an alias/relative import SOURCE to a base path (no extension applied yet),
# given the importing file's rel_path. Returns the base path string, or null if the
# source is neither alias nor relative (caller should have classified it external first).
def resolve_base($src; $importer_relpath):
  ( alias_match($src) ) as $ak
  | if $ak != null then
      # strip the alias key, prepend its mapped dir
      ( $src | ltrimstr($ak) | ltrimstr("/") ) as $rest
      | normalise_path( ($alias_map[$ak]) + (if $rest == "" then "" else "/" + $rest end) )
    elif is_relative($src) then
      normalise_path( (dirof($importer_relpath)) + "/" + $src )
    else null
    end;

# Given a base path and the set of known file relpaths ($known as an object {relpath:true}),
# try the TS resolution order and return the first matching relpath, or null.
def resolve_ext($base; $known):
  ( [ $base, ($base + ".ts"), ($base + ".tsx"),
      ($base + "/index.ts"), ($base + "/index.tsx") ]
    | map(select($known[.] == true))
    | first ) // null;

# Build a canonical node.
def make_node($id; $kind; $relpath; $attrs):
  {
    id: $id,
    kind: $kind,
    source_file: $relpath,
    source_commit: $src_commit,
    timestamp: $now,
    source_line: null,
    emitter: "dependency_cruiser",
    depends_on: [],
    depended_on_by: [],
    attributes: $attrs,
    declared_intent_ref: null
  };

# A source-orphan node (UA could not parse the file) — §6.6: emitter "manual" + justification.
def make_manual_node($id; $kind; $relpath; $attrs; $why):
  ( make_node($id; $kind; $relpath; $attrs)
    | .emitter = "manual"
    | .manual_justification = $why );

# ===== cross-system helpers (Phase 1a, visual-layer cross-system edges) =====

# R9 — table-literal -> substrate table node id, normalised so a schema-qualified literal is not
# double-prefixed. 'deals' -> 'public.deals'; 'public.deals' -> 'public.deals'; 'app.deals' -> 'app.deals'.
def normalise_table($lit):
  ( ($lit | as_str) | ltrimstr("public.") ) as $stripped
  | if ($stripped | contains(".")) then $stripped else "public." + $stripped end;

# One-line human-readable derivation string for an edge.attributes.derivation field. Operates on a
# routed call record carrying {call, dynamic, literal, op}.
def xs_derivation:
  ( ( if .call == "invoke"
      then "supabase.functions.invoke(" + (if .dynamic then "<dynamic>" else "'" + (.literal // "") + "'" end) + ")"
      else "supabase.from("            + (if .dynamic then "<dynamic>" else "'" + (.literal // "") + "'" end) + ")"
           + (if .op == "write" then " [write]" else " [read]" end)
      end )
    # Follow-up #2: DI (this.<conv> client) is convention-inferred, not import-bound — surface the weaker
    # provenance in the human-readable derivation. The cap itself is enforced in the routing map above
    # (conf -> declared-medium); this marker is only the observable signal the eval keys on (substring "DI").
    + (if .di then " [DI: convention-inferred client]" else "" end) );

# A blind-spot external_endpoint node (D05 §3.5 honesty marker) — the code-emitter joint-attribution
# producer (emitter dependency_cruiser; the kind is owned by external-api-graph / external_api_parser).
def make_blindspot_node($id; $relpath; $line; $tmpl):
  {
    id: $id, kind: "external_endpoint",
    source_file: $relpath, source_commit: $src_commit, timestamp: $now,
    source_line: $line, emitter: "dependency_cruiser",
    depends_on: [], depended_on_by: [],
    attributes: { url_host: null, url_path_template: $tmpl, method: null, classification: "blind-spot" },
    declared_intent_ref: null
  };

# An external-api external_endpoint node from a fetch() to a literal external URL (code-emitter
# joint-attribution producer; emitter dependency_cruiser, the kind owned by external-api-graph).
def make_fetch_external_node($id; $relpath; $line; $host; $path; $method):
  {
    id: $id, kind: "external_endpoint",
    source_file: $relpath, source_commit: $src_commit, timestamp: $now,
    source_line: $line, emitter: "dependency_cruiser",
    depends_on: [], depended_on_by: [],
    attributes: { url_host: $host, url_path_template: $path, method: $method, classification: "external-api" },
    declared_intent_ref: null
  };

# Strip credentials (user:pass@), query string, and fragment from a URL before it lands in a human-readable
# derivation string or a blind-spot url_path_template. The node id + url_host/url_path are ALREADY credential-
# and query-stripped by classify_fetch_url's capture; this guards the two places that re-expand the raw
# literal, so a hard-coded credential or an api-key query param in scanned source is never persisted a second
# time into the substrate. A relative/opaque literal (no scheme, no userinfo, no query) passes through intact.
def sanitise_url($u):
  ( $u | as_str
       | gsub("://(?:[^@/?#]*@)"; "://")   # drop userinfo
       | split("?")[0]                     # drop query string
       | split("#")[0] );                  # drop fragment

# Classify ONE static fetch() URL literal (follow-up #1). Dynamic URLs are pre-flagged in extract.mjs and
# never reach here. SIBLING of the external-api emitter's classify_url($url;$method) — kept SEPARATE
# because the input contracts differ (no n8n {{ }}/= expression branch here; dynamic is JS-detected). The
# supabase-rest / supabase-func / external / unparseable classification is pinned IDENTICAL to classify_url
# by the fetch-external eval's parity drift-lock. Every capture() is `// null`-guarded so a no-match emits a
# BLIND-SPOT (the R2 no-silent-drop guarantee — a capture on an empty stream inside map() would otherwise
# collapse the element). Userinfo (user:pass@) is stripped before the host capture so credentials never
# enter an on-disk node id.  class ∈ "supabase_rest" | "supabase_func" | "external" | "blindspot"
def classify_fetch_url($url):
  ( $url | as_str ) as $u
  | if ($u == "")
    then { class: "blindspot", reason: "empty-url" }
    elif ($u | test("supabase\\.co/rest/v1/"))
      then ( ($u | capture("rest/v1/(?<t>[^/?#]+)")) // null ) as $cap
           | if $cap == null then { class: "blindspot", reason: "supabase-rest-no-table" }
             else { class: "supabase_rest", table: $cap.t } end
    elif ($u | test("supabase\\.co/functions/v1/"))
      then ( ($u | capture("functions/v1/(?<f>[^/?#]+)")) // null ) as $cap
           | if $cap == null then { class: "blindspot", reason: "supabase-fn-no-name" }
             else { class: "supabase_func", fn: $cap.f } end
    else
      # host class excludes `@` so a double-userinfo URL (user@a@host) cannot leak an `@` into the node id;
      # the host is the authority AFTER the last userinfo `@` (RFC 3986). Kept identical to the n8n
      # classify_url (the fetch-external parity eval pins both).
      ( ( $u | capture("^[a-zA-Z][a-zA-Z0-9+.-]*://(?:[^@/?#]*@)?(?<host>[^@/?#:]+)(?::[0-9]+)?(?<path>[^?#]*)") ) // null ) as $cap
      | if ($cap == null) or (($cap.host // "") == "")
        then { class: "blindspot", reason: "unparseable-url" }
        else { class: "external", host: $cap.host, path: ($cap.path // "") }
        end
    end;

# ===== main =====

# 0. The records (drop the footer diagnostics record).
( $records[0] | map(select(has("__diagnostics") | not)) ) as $files

# 1. Build the id + the known-relpath set from every file (the resolvable universe).
#    ts_module id = "repo:<relpath>"; edge_function id = "repo:supabase/functions/<name>".
| ( $files
    | map(
        . as $f
        | if $f.kind == "edge_function"
          then { relpath: $f.rel_path,
                 id: ("repo:supabase/functions/" + ($f.rel_path | ltrimstr("supabase/functions/") | sub("/index\\.ts$"; ""))) }
          else { relpath: $f.rel_path, id: ("repo:" + $f.rel_path) }
          end
      ) ) as $idrows
| ( $idrows | map({ (.relpath): .id }) | add // {} ) as $relpath_to_id
| ( $idrows | map({ (.relpath): true }) | add // {} ) as $known

# 2. Per-file node + per-file edges + per-file import classification counts.
| ( $files | map(
    . as $f
    | ($f.rel_path) as $rel
    | ($relpath_to_id[$rel]) as $nid
    | ($f.analysis // {functions:[],classes:[],imports:[],exports:[]}) as $an
    | (($an.imports // []) | as_arr) as $imports
    | (($an.functions // []) | as_arr) as $functions
    | (($an.classes // []) | as_arr) as $classes
    | (($an.exports // []) | as_arr) as $exports

    # node attributes (per kind), §6.5.1 base + honest extensions
    | ( if $f.kind == "edge_function"
        then {
          runtime: "deno",
          deployed_commit: null,
          function_name: ($rel | ltrimstr("supabase/functions/") | sub("/index\\.ts$"; "")),
          source_file_relpath: $rel,
          function_count: ($functions | length),
          import_count: ($imports | length)
        }
        else {
          is_entry: ($rel == "src/main.tsx"),
          export_count: ($exports | length),
          language: ($f.language // "typescript"),
          file_size_bytes: ($f.byte_size // 0),
          function_count: ($functions | length),
          class_count: ($classes | length),
          import_count: ($imports | length),
          source_file_relpath: $rel
        }
        end ) as $attrs

    # node (manual if the extractor failed on this file — §6.6)
    | ( if ($f.extractor_error // null) != null
        then make_manual_node($nid; $f.kind; $rel; $attrs; ("extractor failed: " + $f.extractor_error))
        else make_node($nid; $f.kind; $rel; $attrs)
        end ) as $node

    # classify + resolve each import
    | ( $imports | map(
        . as $imp
        | (($imp.source // "") | as_str) as $src
        | if ($src == "") then { class: "external" }       # missing/non-string source -> treat as external (dropped, counted), never abort
          elif is_asset($src) then { class: "asset" }
          elif is_url($src) then { class: "url" }
          elif (alias_match($src) != null) or is_relative($src) then
            ( resolve_base($src; $rel) ) as $base
            | ( if $base == null then null else resolve_ext($base; $known) end ) as $hit
            | if $hit != null
              then { class: "internal", target: $relpath_to_id[$hit] }
              else { class: "unresolved", target: ("unresolved:" + $src) }
              end
          else { class: "external" }
          end
      ) ) as $classified

    # internal + unresolved produce candidate edges (unresolved dropped by idset filter later)
    | ( $classified
        | map(select(.class == "internal" or .class == "unresolved"))
        | map({ source: $nid, target: .target, type: "imports", direction: "forward", weight: 1 }) ) as $edges

    | {
        node: $node,
        edges: $edges,
        counts: {
          imports_total: ($imports | length),
          internal:    ([$classified[] | select(.class == "internal")]   | length),
          unresolved:  ([$classified[] | select(.class == "unresolved")] | length),
          external:    ([$classified[] | select(.class == "external")]   | length),
          asset:       ([$classified[] | select(.class == "asset")]      | length),
          url:         ([$classified[] | select(.class == "url")]        | length)
        }
      }
  ) ) as $per_file

# 3. Flatten.
| ( [$per_file[].node] ) as $all_nodes
| ( [$per_file[].edges[]] | unique_by([.source, .target, .type]) ) as $all_edges_raw

# 4. Defensive idset filter — drop edges whose endpoints are not both real nodes.
#    Unresolved edges (target "unresolved:<src>") are dropped here; counted in diagnostics.
| ( [ $all_nodes[].id ] | map({(.):true}) | add // {} ) as $node_idset
| ( $all_edges_raw | map(select(($node_idset[.source] == true) and ($node_idset[.target] == true))) ) as $all_edges

# 4b. CROSS-SYSTEM PASS (Phase 1a). Map each file's supabase_calls to cross-system edges, resolving
#     each target against the UNION of (this emit's node ids ∪ the LIVE substrate node-id set passed
#     in as $substrate_ids, read READ-ONLY). Council resolutions: R3 dynamic-arg -> blind-spot;
#     R2 unresolved-literal -> blind-spot UNLESS supabase-live coverage is definitively "covered"
#     (then a counted drop = a genuine dangling reference); R9 id normalisation. Cross-system edges
#     live ONLY in .edges (a separate render layer) and deliberately do NOT enter node depends_on/
#     depended_on_by — the within-system maps stay clean and the drift blast-walk is unaffected (R5,
#     the cross-system blast-follow is a v2 item).
# $substrate_ids + $supabase_coverage are referenced via $ARGS.named so a caller that omits them
# (the within-repo-only path, and the pre-existing evals) gets the safe defaults [] / "" — jq would
# hard-error on a bare undefined $var. With no substrate ids + empty coverage, every cross-system
# target falls through to a blind-spot (fail-safe), and fixtures without supabase_calls produce none.
| ( ($ARGS.named.substrate_ids // []) | as_arr ) as $substrate_ids
| ( [ $all_nodes[].id ] + $substrate_ids | map({(.):true}) | add // {} ) as $universe
| ( ($ARGS.named.supabase_coverage // "") | as_str ) as $sbcov
| ( [ $files[]
      | . as $f
      | ($relpath_to_id[$f.rel_path]) as $caller
      | (($f.supabase_calls // []) | as_arr)[]
      | . as $c
      | { caller: $caller, src_file: $f.rel_path, line: ($c.line // null),
          call: ($c.call // ""), op: ($c.op // "read"),
          dynamic: ($c.dynamic // false), literal: ($c.literal // null),
          di: ($c.di // false) } ] ) as $calls_raw
| ( $calls_raw | map(
      . as $c
      | ( if $c.call == "invoke"
          # DI invoke is convention-inferred, not import-bound -> capped at declared-medium (never -high).
          then { tgt: ("repo:supabase/functions/" + ($c.literal // "")), etype: "invokes",
                 conf: (if $c.di then "declared-medium" else "declared-high" end) }
          else { tgt: (normalise_table($c.literal // "")),
                 etype: (if $c.op == "write" then "writes_to" else "reads_from" end),
                 conf: "declared-medium" }
          end ) as $r
      | $c + $r
      | .dyn_bs_id   = ("ext:blind-spot:" + .call + ":" + .src_file + ":" + ((.line // 0) | tostring))
      | .dyn_bs_tmpl = ("supabase/" + (if .call == "invoke" then "functions" else "from" end) + "/<dynamic>")
    ) ) as $resolved
| ( $resolved | map(
      if   .dynamic                  then .outcome = "blindspot_dynamic"
      elif ($universe[.tgt] == true) then .outcome = "edge"
      elif ($sbcov == "covered")     then .outcome = "drop"
      else                                .outcome = "blindspot_unresolved" end
    ) ) as $routed
| ( [ $routed[]
      | select(.outcome == "blindspot_dynamic" or .outcome == "blindspot_unresolved")
      | if .outcome == "blindspot_dynamic"
        then make_blindspot_node(.dyn_bs_id; .src_file; .line; .dyn_bs_tmpl)
        else make_blindspot_node(("ext:blind-spot:" + .tgt); .src_file; .line; .tgt) end
    ] | unique_by(.id) ) as $xs_nodes
| ( [ $routed[]
      | select(.outcome != "drop")
      | . as $r
      | ( if   $r.outcome == "edge"             then $r.tgt
          elif $r.outcome == "blindspot_dynamic" then $r.dyn_bs_id
          else ("ext:blind-spot:" + $r.tgt) end ) as $tgt
      | ( if $r.outcome == "edge" then $r.conf else "blind-spot" end ) as $conf
      | { source: $r.caller, target: $tgt, type: $r.etype, direction: "forward", weight: 1,
          attributes: { derivation: ($r | xs_derivation), confidence: $conf } }
    ] | unique_by([.source, .target, .type]) ) as $xs_edges
| ( {
      supabase_calls_total:               ($routed | length),
      cross_system_edges_declared_high:   ([ $routed[] | select(.outcome=="edge" and .conf=="declared-high") ]   | length),
      cross_system_edges_declared_medium: ([ $routed[] | select(.outcome=="edge" and .conf=="declared-medium") ] | length),
      cross_system_blind_spots:           ([ $routed[] | select(.outcome=="blindspot_dynamic" or .outcome=="blindspot_unresolved") ] | length),
      cross_system_counted_drops:         ([ $routed[] | select(.outcome=="drop") ] | length),
      supabase_coverage_seen:             $sbcov
    } ) as $xs_diag

# 4c. FETCH PASS (follow-up #1 — edge-function / frontend external-API surface). Map each file's
#     fetch_calls through classify_fetch_url, resolving supabase targets against the SAME universe +
#     R2 coverage routing as 4b. external_endpoint nodes carry emitter dependency_cruiser (the detecting
#     emitter) — the documented joint-attribution exception (canonical-shape § external_endpoint). A
#     dynamic / unparseable / empty url -> blind-spot (never dropped, never green). Like 4b these edges
#     live ONLY in .edges (separate render layer) and do NOT enter depends_on / the drift blast walk (R5).
| ( [ $files[]
      | . as $f
      | ($relpath_to_id[$f.rel_path]) as $caller
      | (($f.fetch_calls // []) | as_arr)[]
      | . as $c
      | { caller: $caller, src_file: $f.rel_path, line: ($c.line // null),
          url: ($c.url // null), method: ($c.method // "GET"), dynamic: ($c.dynamic // false) } ] ) as $fcalls_raw
| ( $fcalls_raw | map(
      . as $c
      | ( if $c.dynamic then { class: "blindspot", reason: "dynamic-url" }
          else classify_fetch_url($c.url) end ) as $cl
      | $c + { fclass: $cl.class,
               fhost: ($cl.host // null), fpath: ($cl.path // null),
               ftable: ($cl.table // null), ffn: ($cl.fn // null) }
    ) ) as $fclassified
| ( $fclassified | map(
      . as $c
      | ( if   $c.fclass == "external"
          then { tgt: ("ext:external-api:" + $c.fhost + $c.fpath), etype: "calls", conf: "declared-high", outcome: "external" }
          elif $c.fclass == "supabase_func"
          then { tgt: ("repo:supabase/functions/" + $c.ffn), etype: "invokes", conf: "declared-high", outcome: "supabase" }
          elif $c.fclass == "supabase_rest"
          then { tgt: (normalise_table($c.ftable)),
                 etype: ( (($c.method // "GET") | ascii_upcase) as $m
                          | if ($m=="POST" or $m=="PUT" or $m=="PATCH" or $m=="DELETE") then "writes_to" else "reads_from" end ),
                 conf: "declared-medium", outcome: "supabase" }
          else { tgt: ("ext:blind-spot:fetch:" + $c.src_file + ":" + (($c.line // 0) | tostring)),
                 etype: "calls", conf: "blind-spot", outcome: "blindspot",
                 tmpl: (if $c.dynamic then "fetch(<dynamic>)" else sanitise_url($c.url // "") end) }
          end ) as $r
      | $c + $r
    ) ) as $frouted0
# resolve supabase outcomes against the universe + R2 coverage routing (mirrors 4b)
| ( $frouted0 | map(
      if .outcome == "supabase"
      then ( if   ($universe[.tgt] == true) then .outcome = "edge"
             elif ($sbcov == "covered")     then .outcome = "drop"
             else .outcome = "blindspot_unresolved" | .bs_tgt = ("ext:blind-spot:" + .tgt) end )
      else . end
    ) ) as $frouted
# external_endpoint nodes: external-api + per-site blind-spots + unresolved-supabase blind-spots
| ( [ $frouted[]
      | if   .outcome == "external"
        then make_fetch_external_node(.tgt; .src_file; .line; .fhost; .fpath; ((.method // "GET") | ascii_upcase))
        elif .outcome == "blindspot"
        then make_blindspot_node(.tgt; .src_file; .line; .tmpl)
        elif .outcome == "blindspot_unresolved"
        then make_blindspot_node(.bs_tgt; .src_file; .line; .tgt)
        else empty end
    ] | unique_by(.id) ) as $fetch_nodes
# cross-system edges (drops produce none). An unresolved-supabase target is a blind-spot: its edge
# confidence is DOWNGRADED to "blind-spot" (mirrors the 4b sibling line) — never a green edge to an amber
# node. The derivation URL is sanitise_url'd so a credential / api-key never re-enters the substrate.
| ( [ $frouted[]
      | select(.outcome != "drop")
      | ( if .outcome == "blindspot_unresolved" then .bs_tgt else .tgt end ) as $tgt
      | ( if .outcome == "blindspot_unresolved" then "blind-spot" else .conf end ) as $conf
      | { source: .caller, target: $tgt, type: .etype, direction: "forward", weight: 1,
          attributes: {
            derivation: ( "fetch(" + (if .dynamic then "<dynamic>" else "'" + sanitise_url(.url // "") + "'" end) + ")"
                          + ( ((.method // "GET") | ascii_upcase) as $m | if $m != "GET" then " [" + $m + "]" else "" end ) ),
            confidence: $conf } }
    ] | unique_by([.source, .target, .type]) ) as $fetch_edges
| ( {
      fetch_calls_total:           ($frouted | length),
      fetch_external_endpoints:    ([ $frouted[] | select(.outcome=="external") ] | length),
      fetch_edges_declared_high:   ([ $frouted[] | select((.outcome=="external" or .outcome=="edge") and .conf=="declared-high") ]   | length),
      fetch_edges_declared_medium: ([ $frouted[] | select(.outcome=="edge" and .conf=="declared-medium") ] | length),
      fetch_blind_spots:           ([ $frouted[] | select(.outcome=="blindspot" or .outcome=="blindspot_unresolved") ] | length),
      fetch_counted_drops:         ([ $frouted[] | select(.outcome=="drop") ] | length)
    } ) as $fetch_diag

# 5. Diagnostics.
| {
    ts_module_count:           ([$all_nodes[] | select(.kind == "ts_module")]    | length),
    edge_function_count:       ([$all_nodes[] | select(.kind == "edge_function")]| length),
    ts_files_extractor_failed: ([$all_nodes[] | select(.emitter == "manual")]    | length),
    imports_total:             ([$per_file[].counts.imports_total] | add // 0),
    within_repo_edges_kept:    ($all_edges | length),
    external_imports_skipped:  ([$per_file[].counts.external] | add // 0),
    asset_imports_skipped:     ([$per_file[].counts.asset]    | add // 0),
    external_url_imports_skipped: ([$per_file[].counts.url]   | add // 0),
    unresolved_imports:        ([$per_file[].counts.unresolved] | add // 0),
    entry_points_marked:       ([$all_nodes[] | select(.kind == "ts_module" and .attributes.is_entry == true)] | length)
  } as $diagnostics

# 6. Re-derive depends_on / depended_on_by per node from the final edge set.
| ( $all_edges | group_by(.source)
              | map({key: .[0].source, value: (map(.target) | unique)})
              | from_entries) as $deps_by_src
| ( $all_edges | group_by(.target)
              | map({key: .[0].target, value: (map(.source) | unique)})
              | from_entries) as $rev_by_tgt
| ( $all_nodes | map(
      .depends_on       = ($deps_by_src[.id] // [])
    | .depended_on_by   = ($rev_by_tgt[.id] // [])
  ) ) as $nodes_final

# 7. Merge the cross-system layer: blind-spot + external-api external_endpoint nodes into nodes (deduped),
#    the cross-system edges (supabase 4b + fetch 4c) into edges. Cross-system edges are NOT re-derived
#    into depends_on (step 6 ran over within-repo edges only) — they are a separate render layer (R5).
| ( ($nodes_final + $xs_nodes + $fetch_nodes) | unique_by(.id) ) as $nodes_out
| ( $all_edges + $xs_edges + $fetch_edges ) as $edges_out

| { nodes: $nodes_out, edges: $edges_out, diagnostics: ($diagnostics + $xs_diag + $fetch_diag) }
