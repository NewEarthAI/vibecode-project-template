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
#   jq -n \
#     --slurpfile records /tmp/code-emit/records.json \
#     --arg now "$NOW" \
#     --arg src_commit "$SRC_COMMIT" \
#     --argjson alias_map '{"@":"src"}' \
#     -f .claude/skills/code-emitter/scripts/transform.jq \
#     > /tmp/code-emit/combined.json
#   jq '.nodes' /tmp/code-emit/combined.json > /tmp/code-emit/nodes.json
#   jq '.edges' /tmp/code-emit/combined.json > /tmp/code-emit/edges.json
#   bash .claude/skills/code-emitter/scripts/emit.sh nodes.json edges.json "BuyBox-AI"
#
# Input contract ($records is a slurped array whose single element is the array of records):
#   Each record (one per file, from extract.mjs):
#     { "kind": "ts_module"|"edge_function",
#       "rel_path": "<repo-relative, forward-slashed>",
#       "byte_size": N,
#       "language": "typescript"|"typescript-react",
#       "analysis": { functions:[...], classes:[...],
#                     imports:[{source,specifiers,lineNumber}...], exports:[{name,...}...] },
#       "extractor_error": "<msg>"? }            // present ONLY on parse failure
#   The trailing { "__diagnostics": {...} } footer record is DROPPED here.
#
#   $now          ISO 8601 UTC of this run — the node timestamp
#   $src_commit   git short SHA (with optional +dirty) — applied to all nodes
#   $alias_map    tsconfig paths aliases as {"<alias-prefix>": "<dir>"} (BuyBox-AI: {"@":"src"})
#
# OUTPUT:  {nodes: [...], edges: [...], diagnostics: {...}}

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

| { nodes: $nodes_final, edges: $all_edges, diagnostics: $diagnostics }
