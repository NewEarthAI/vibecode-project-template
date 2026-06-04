#!/usr/bin/env bash
# topology-substrate/scripts/substrate.sh — the canonical topology-graph read/write helper.
#
# Intent-Actual-Gap Mechanism Build Programme — M3 Session 1. Builds the Doctrine 05 §6.3
# canonical shape ({nodes, parent_map, child_map}) + the workshop heartbeat/coverage envelope.
# Schema authority: ../references/canonical-shape.md (10-field node per D05 §6.1 + one nullable
# declared_intent_ref forward-hook; NOT D06's 17 reconciliation fields — see that file's
# load-bearing finding).
#
# Concurrency: mirrors _shared/goals.sh (atomic mkdir lock + jq -n -> mktemp -> mv; 30m TTL,
# 60m clock-skew bound; symlink-TOCTOU guard; fail-closed on unreadable epoch) with ONE
# divergence: the substrate is a SINGLE JSON file, so the lock is whole-file (one lock, held =
# retry-then-fail), closer to autovibe/state.sh than to goals.sh's per-id retry-because-overlap-
# is-expected model.
#
# Portability target: macOS system bash 3.2.57 + jq 1.7. NO bash associative arrays, NO mapfile,
# NO ${var,,}. ALL structural manipulation is in jq; bash only orchestrates + holds the lock.
# Per .claude/rules/shell-portability.md: set -uo pipefail, mkdir lock (atomic on APFS),
# numeric normalisation before [ integer tests, namespaced locals (avoid zsh-reserved `status`).
#
# Usage:
#   substrate.sh init <entity>                       -> create empty substrate if absent (idempotent)
#   substrate.sh write-node '<node-json>'            -> atomic single-node upsert
#   substrate.sh write-edge '<edge-json>'            -> atomic single-edge add (endpoints must exist)
#   substrate.sh bulk-write '<nodes-json>' '<edges-json>' -> single locked batch write
#   substrate.sh mark-emitter-ran <name> <coverage>  -> update emitters.<name> heartbeat + coverage
#   substrate.sh read-topology ['<jq-filter>']       -> validate + print substrate (optional jq slice)
#   substrate.sh validate-schema                     -> PASS or a violation list
#
# Exit codes: 0 ok | 2 usage/bad-arg | 4 substrate not found (run init) | 5 lock held after retry
#             6 corrupt / jq-missing / write-failed / integrity-violation

set -uo pipefail

# --- configuration --------------------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SUBSTRATE_PATH="${TOPOLOGY_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/topology-graph.json}"
SUBSTRATE_DIR="$(dirname "$SUBSTRATE_PATH")"
# Filesystem-safety guards on the derived dir (the lock + mktemp + mv + rm -rf all live under it):
# an empty dir or a symlinked parent would let writes / rm escape the intended location.
if [ -z "$SUBSTRATE_DIR" ] || [ "$SUBSTRATE_DIR" = "/" ]; then
  echo "substrate.sh: SUBSTRATE_DIR resolves to empty or '/' (from TOPOLOGY_SUBSTRATE_PATH='${TOPOLOGY_SUBSTRATE_PATH:-}') — refusing" >&2
  exit 6
fi
if [ -L "$SUBSTRATE_DIR" ]; then
  echo "substrate.sh: SUBSTRATE_DIR '$SUBSTRATE_DIR' is a symlink — refusing (writes/rm could escape the intended location)" >&2
  exit 6
fi
LOCK_DIR="$SUBSTRATE_DIR/.topology-lock"
SCHEMA_VERSION="m3-v1"
TTL_MIN=30
FUTURE_TOLERANCE_MIN=60
LOCK_RETRIES=25          # ~5s ceiling (25 * 0.2s) before declaring the lock genuinely stuck
LOCK_SLEEP=0.2

# Frozen contract enums (single source of truth — keep in lockstep with canonical-shape.md).
# kind = the 10 D05 §6.1 domain kinds (config added M3 Session 5 for declared-structure config
# files — vercel.json / package.json — via the doctrine-verification-gate triple gate; record:
# council/code-reviews/2026-06-01-m3-session-5-repo-config-emitter.md). `manual` is an EMITTER
# value (the source-orphan marker, D05 §6.6), NOT a kind — a manual node still carries one of the
# 10 domain kinds (a config node is always emitter:manual + manual_justification).
VALID_KINDS="table view function trigger rls_policy edge_function workflow workflow_node ts_module config"
VALID_EMITTERS="pg_depend n8n_parser dependency_cruiser vercel_api manual"
KNOWN_EMITTER_NAMES="code supabase-live n8n-cloud"
VALID_COVERAGE="covered absent degenerate declared-missing"
# Top-level frozen key set (jq array literal) — single source of truth for validate-schema.
TOPLEVEL_KEYS_JSON='["schema_version","entity","last_updated","emitters","missing_emitters","nodes","edges","parent_map","child_map"]'
# Node frozen key set (10 D05 §6.1 fields + the declared_intent_ref forward-hook).
NODE_KEYS_JSON='["id","kind","source_file","source_commit","timestamp","source_line","emitter","depends_on","depended_on_by","attributes","declared_intent_ref"]'

ts_now()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
ts_epoch() { date -u +%s; }

if ! command -v jq >/dev/null 2>&1; then
  echo "substrate.sh: jq not found in PATH — required dependency (brew install jq)" >&2
  exit 6
fi

# --- whole-file mkdir lock ------------------------------------------------------
# Mirrors goals.sh _acquire: atomic mkdir, symlink-TOCTOU guard, TTL stale takeover,
# future-date clock-skew refusal, fail-closed on unreadable epoch, bounded retry.
# Caller MUST _release on every exit path. Single lock (whole-file), not per-id.
_acquire() {
  local attempt=0 acq now age
  mkdir -p "$SUBSTRATE_DIR" 2>/dev/null || true
  if [ -L "$LOCK_DIR" ]; then
    echo "substrate.sh: $LOCK_DIR is a symlink — refusing (potential TOCTOU)" >&2
    return 6
  fi
  while [ "$attempt" -le "$LOCK_RETRIES" ]; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      date -u +%s > "$LOCK_DIR/acquired_epoch" 2>/dev/null || true
      return 0
    fi
    # Held. One-time stale inspection on the first sighting only.
    if [ "$attempt" -eq 0 ]; then
      acq="$(cat "$LOCK_DIR/acquired_epoch" 2>/dev/null || echo '')"
      now="$(ts_epoch)"
      if ! echo "$acq" | grep -qE '^[0-9]+$'; then
        # Epoch unreadable — a live holder may be mid-write before its stamp landed.
        # FAIL CLOSED: never take over on an unreadable stamp.
        echo "substrate.sh: lock $LOCK_DIR present, epoch unreadable — treating as fresh, not taking over" >&2
      elif [ "$acq" -gt "$((now + FUTURE_TOLERANCE_MIN * 60))" ]; then
        echo "substrate.sh: lock $LOCK_DIR future-dated (clock skew) — refusing; inspect/rm manually" >&2
        return 5
      else
        age=$(( (now - acq) / 60 ))
        if [ "$age" -ge "$TTL_MIN" ]; then
          # Stale. Race-safe reclaim: rmdir (NOT rm -rf), then a single mkdir.
          rm -f "$LOCK_DIR/acquired_epoch" 2>/dev/null || true
          rmdir "$LOCK_DIR" 2>/dev/null || true
          if mkdir "$LOCK_DIR" 2>/dev/null; then
            date -u +%s > "$LOCK_DIR/acquired_epoch" 2>/dev/null || true
            echo "substrate.sh: reclaimed stale lock (age ${age}min)" >&2
            return 0
          fi
        fi
      fi
    fi
    attempt=$((attempt + 1))
    sleep "$LOCK_SLEEP" 2>/dev/null || sleep 1
  done
  echo "substrate.sh: lock still held after ${LOCK_RETRIES} retries — another op is stuck; inspect $LOCK_DIR" >&2
  return 5
}
_release() {
  # Containment guard (defence-in-depth): only ever rm the named lock under SUBSTRATE_DIR.
  case "$LOCK_DIR" in
    "$SUBSTRATE_DIR"/.topology-lock) rm -rf "$LOCK_DIR" 2>/dev/null || true;;
    *) echo "substrate.sh: _release: lock path '$LOCK_DIR' unexpected — refusing rm" >&2;;
  esac
}

# --- the canonical jq transforms ------------------------------------------------
# Re-derive parent_map / child_map from nodes' edges. ONE jq expression so the maps can
# never drift from nodes by construction (D05 §6.3). Reads a full substrate object on stdin,
# emits it with parent_map/child_map recomputed.
#   child_map[N]  = N.depends_on        (what N depends on — below it)
#   parent_map[N] = N.depended_on_by    (what depends on N — above it)
JQ_REDERIVE_MAPS='
  .child_map  = ( [ .nodes[] | {key: .id, value: (.depends_on // [])} ]     | from_entries )
| .parent_map = ( [ .nodes[] | {key: .id, value: (.depended_on_by // [])} ] | from_entries )
'

# Atomic write: take a jq filter (operating on the current substrate), apply it, bump
# last_updated, re-derive maps, write via mktemp -> mv. Args: <jq-filter> [jq --argjson pairs...]
# Caller holds the lock. Returns 6 on any failure (and leaves the original file intact).
_atomic_apply() {
  local filter="$1"; shift
  local tmp jqerr now
  now="$(ts_now)"
  if [ ! -f "$SUBSTRATE_PATH" ]; then
    echo "substrate.sh: substrate not found at $SUBSTRATE_PATH (run: init <entity>)" >&2
    return 4
  fi
  tmp="$(mktemp "${SUBSTRATE_DIR}/.topology-tmp.XXXXXX")"   || { echo "substrate.sh: mktemp failed" >&2; return 6; }
  # Error capture goes under SUBSTRATE_DIR (mktemp), NOT a predictable /tmp path — the predictable
  # name was a symlink-write surface on shared hosts (council finding).
  jqerr="$(mktemp "${SUBSTRATE_DIR}/.topology-jqerr.XXXXXX")" || { rm -f "$tmp"; echo "substrate.sh: mktemp failed" >&2; return 6; }
  if jq "$@" --arg _now "$now" \
       "( $filter ) | .last_updated = \$_now | $JQ_REDERIVE_MAPS" \
       "$SUBSTRATE_PATH" > "$tmp" 2>"$jqerr"; then
    # Defence: confirm the tmp is a JSON OBJECT before the rename. Not a size check — jq can exit 0
    # while emitting `null` or a bare scalar (valid JSON, wrong shape); the object-type guard catches it.
    if jq -e 'type == "object"' "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$SUBSTRATE_PATH" || { echo "substrate.sh: mv failed" >&2; rm -f "$tmp" "$jqerr"; return 6; }
      rm -f "$jqerr" 2>/dev/null || true
      return 0
    fi
    echo "substrate.sh: post-transform output was not a JSON object — write aborted" >&2
    rm -f "$tmp" "$jqerr"; return 6
  fi
  echo "substrate.sh: jq transform failed: $(cat "$jqerr" 2>/dev/null)" >&2
  rm -f "$tmp" "$jqerr" 2>/dev/null || true
  return 6
}

_in_list() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

# --- node / edge input validation (pre-lock, fail fast) -------------------------
# Returns 0 if the node JSON is structurally valid, else 2 with a message.
_validate_node_json() {
  local node="$1" id kind emitter manual_just
  if ! echo "$node" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "substrate.sh: node is not a JSON object" >&2; return 2
  fi
  id="$(echo "$node"      | jq -r '.id // empty')"
  kind="$(echo "$node"    | jq -r '.kind // empty')"
  emitter="$(echo "$node" | jq -r '.emitter // empty')"
  [ -n "$id" ]      || { echo "substrate.sh: node missing .id" >&2; return 2; }
  [ -n "$kind" ]    || { echo "substrate.sh: node missing .kind" >&2; return 2; }
  [ -n "$emitter" ] || { echo "substrate.sh: node missing .emitter" >&2; return 2; }
  _in_list "$kind" "$VALID_KINDS"       || { echo "substrate.sh: invalid kind '$kind' (one of: $VALID_KINDS)" >&2; return 2; }
  _in_list "$emitter" "$VALID_EMITTERS" || { echo "substrate.sh: invalid emitter '$emitter' (one of: $VALID_EMITTERS)" >&2; return 2; }
  # Source-orphan rule (D05 §6.6): emitter==manual REQUIRES a non-empty manual_justification.
  if [ "$emitter" = "manual" ]; then
    manual_just="$(echo "$node" | jq -r '.manual_justification // empty')"
    [ -n "$manual_just" ] || { echo "substrate.sh: manual node '$id' missing required manual_justification (D05 §6.6)" >&2; return 2; }
  fi
  return 0
}

# _validate_nodes_batch <nodes-json-array>: validate ALL nodes in ONE jq pass (no per-node fork).
# Same rules as _validate_node_json; used by bulk-write so an N-node batch costs 1 jq fork, not 4N.
# Returns 0 if clean, 2 with the violation list on stderr otherwise.
_validate_nodes_batch() {
  local nodes="$1" violations
  violations="$(printf '%s' "$nodes" | jq -r \
      --arg kinds "$VALID_KINDS" --arg emitters "$VALID_EMITTERS" '
    ($kinds | split(" ")) as $VK | ($emitters | split(" ")) as $VE |
    .[] | . as $n |
    ( if (($n | type) != "object") then "a node is not a JSON object" else empty end ),
    ( if (($n.id // "") == "")      then "a node is missing .id"                         else empty end ),
    ( if (($n.kind // "") == "")    then "node \($n.id // "?") missing .kind"            else empty end ),
    ( if (($n.emitter // "") == "") then "node \($n.id // "?") missing .emitter"         else empty end ),
    ( if (($n.kind != null) and (($VK | index($n.kind)) == null))       then "node \($n.id // "?") invalid kind \($n.kind)"       else empty end ),
    ( if (($n.emitter != null) and (($VE | index($n.emitter)) == null)) then "node \($n.id // "?") invalid emitter \($n.emitter)" else empty end ),
    ( if ($n.emitter == "manual" and (($n.manual_justification // "") == ""))
        then "node \($n.id // "?") manual node missing required manual_justification (D05 §6.6)" else empty end )
  ' 2>/dev/null)"
  if [ -n "$violations" ]; then
    echo "$violations" >&2
    return 2
  fi
  return 0
}

# --- subcommands ----------------------------------------------------------------

cmd_init() {
  local entity="${1:-}"
  [ -n "$entity" ] || { echo "substrate.sh: init requires <entity>" >&2; return 2; }
  _acquire || return $?
  if [ -f "$SUBSTRATE_PATH" ]; then
    _release
    echo "substrate.sh: substrate already exists at $SUBSTRATE_PATH (init is idempotent — no change)"
    return 0
  fi
  local tmp now
  now="$(ts_now)"
  tmp="$(mktemp "${SUBSTRATE_DIR}/.topology-tmp.XXXXXX")" || { _release; echo "substrate.sh: mktemp failed" >&2; return 6; }
  # Build the whole skeleton in one jq -n pass: 3 emitters at declared-missing/null, 5 P6 markers.
  if jq -n \
      --arg sv "$SCHEMA_VERSION" \
      --arg entity "$entity" \
      --arg now "$now" '
    {
      schema_version: $sv,
      entity: $entity,
      last_updated: $now,
      emitters: {
        "code":          { last_emitted_at: null, coverage: "declared-missing" },
        "supabase-live": { last_emitted_at: null, coverage: "declared-missing" },
        "n8n-cloud":     { last_emitted_at: null, coverage: "declared-missing" }
      },
      missing_emitters: [
        { name: "airtable",            reason: "M4+ JV-partner scope (spec 14 §3)" },
        { name: "follow-up-boss",      reason: "M4+ JV-partner scope (spec 14 §3)" },
        { name: "homepros-podio",      reason: "M4+ — TRUE GAP, no Podio MCP; REST integration needed (spec 14 §3)" },
        { name: "vercel-deploy-state", reason: "M4+ — Vercel API integration (spec 14 §3)" },
        { name: "external-api-graph",  reason: "M4+ — edge-function static analysis needed (spec 14 §3)" }
      ],
      nodes: [],
      edges: [],
      parent_map: {},
      child_map: {}
    }' > "$tmp" 2>/dev/null; then
    mv "$tmp" "$SUBSTRATE_PATH" || { rm -f "$tmp"; _release; echo "substrate.sh: mv failed" >&2; return 6; }
    _release
    echo "substrate.sh: initialised substrate for '$entity' at $SUBSTRATE_PATH"
    return 0
  fi
  rm -f "$tmp"; _release
  echo "substrate.sh: init jq build failed" >&2
  return 6
}

cmd_write_node() {
  local node="${1:-}"
  [ -n "$node" ] || { echo "substrate.sh: write-node requires '<node-json>'" >&2; return 2; }
  _validate_node_json "$node" || return 2
  _acquire || return $?
  # Upsert: drop any existing node with the same id, append the new one. Normalise the array
  # fields + forward-hook so downstream consumers always see a uniform shape.
  _atomic_apply '
    .nodes = ( [ .nodes[] | select(.id != ($node.id)) ]
               + [ $node
                   | .depends_on        = (.depends_on // [])
                   | .depended_on_by    = (.depended_on_by // [])
                   | .attributes        = (.attributes // {})
                   | .declared_intent_ref = (.declared_intent_ref // null) ] )
  ' --argjson node "$node"
  local rc=$?
  _release
  [ "$rc" -eq 0 ] && echo "substrate.sh: wrote node $(echo "$node" | jq -r '.id')"
  return "$rc"
}

cmd_write_edge() {
  local edge="${1:-}"
  [ -n "$edge" ] || { echo "substrate.sh: write-edge requires '<edge-json>'" >&2; return 2; }
  if ! echo "$edge" | jq -e 'type == "object" and (.source|type=="string") and (.target|type=="string")' >/dev/null 2>&1; then
    echo "substrate.sh: edge must be an object with string .source and .target" >&2; return 2
  fi
  _acquire || return $?
  # Integrity check INSIDE the locked transform: both endpoints must exist, or fail loud.
  # jq emits a sentinel error string we detect; we never write a dangling edge.
  local tmp now src tgt
  now="$(ts_now)"
  if [ ! -f "$SUBSTRATE_PATH" ]; then _release; echo "substrate.sh: substrate not found (run init)" >&2; return 4; fi
  src="$(echo "$edge" | jq -r '.source')"
  tgt="$(echo "$edge" | jq -r '.target')"
  # Endpoint existence check (read, pre-write).
  if ! jq -e --arg s "$src" --arg t "$tgt" \
        '([.nodes[].id] | (index($s) != null) and (index($t) != null))' \
        "$SUBSTRATE_PATH" >/dev/null 2>&1; then
    _release
    echo "substrate.sh: write-edge integrity check failed — source '$src' and/or target '$tgt' not present in nodes" >&2
    return 6
  fi
  _atomic_apply '
    .edges += [ $edge
                | .type      = (.type // "depends_on")
                | .direction = (.direction // "forward")
                | .weight    = (.weight // 1) ]
  ' --argjson edge "$edge"
  local rc=$?
  _release
  [ "$rc" -eq 0 ] && echo "substrate.sh: wrote edge $src -> $tgt"
  return "$rc"
}

# bulk-write is the path emitters MUST use for a full run — one lock, one jq write, maps re-derived
# ONCE. Calling write-node in a loop over N nodes is O(N^2) (maps re-derived N times). See SKILL.md.
cmd_bulk_write() {
  local nodes="${1:-}" edges="${2:-}"
  [ -n "$nodes" ] || { echo "substrate.sh: bulk-write requires '<nodes-json>' '<edges-json>'" >&2; return 2; }
  edges="${edges:-[]}"
  if ! printf '%s' "$nodes" | jq -e 'type == "array"' >/dev/null 2>&1; then echo "substrate.sh: nodes must be a JSON array" >&2; return 2; fi
  if ! printf '%s' "$edges" | jq -e 'type == "array"' >/dev/null 2>&1; then echo "substrate.sh: edges must be a JSON array" >&2; return 2; fi
  # Validate ALL nodes in ONE jq pass before taking the lock (fail fast; no fork-per-node).
  _validate_nodes_batch "$nodes" || { echo "substrate.sh: bulk-write aborted — invalid node(s) above" >&2; return 2; }
  # Pre-compute counts for the success message (avoids two post-write jq forks on the full payload).
  local node_count edge_count
  node_count="$(printf '%s' "$nodes" | jq 'length')"
  edge_count="$(printf '%s' "$edges" | jq 'length')"
  _acquire || return $?
  if [ ! -f "$SUBSTRATE_PATH" ]; then _release; echo "substrate.sh: substrate not found (run init)" >&2; return 4; fi
  # Edge endpoint integrity against the UNION (existing ∪ incoming). all($edges[]; cond) binds . per
  # edge inside cond — the prior `$edges | all(cond)` form ran cond once on the whole array (broken).
  # Membership via a set object ({id:true}) is O(N+E), not O(N*E) index() scans.
  if ! jq -e --argjson nodes "$nodes" --argjson edges "$edges" '
        ( [ (.nodes[].id), ($nodes[].id) ] | map({key: ., value: true}) | from_entries ) as $idset
        | all($edges[]; . as $e | ($idset[$e.source] == true) and ($idset[$e.target] == true))
      ' "$SUBSTRATE_PATH" >/dev/null 2>&1; then
    _release
    echo "substrate.sh: bulk-write integrity check failed — an edge references a node not in (existing ∪ incoming)" >&2
    return 6
  fi
  # Node upsert: incoming wins (reverse BEFORE unique_by so the LAST occurrence of each id survives —
  # the prior `unique_by | reverse | unique_by` kept the FIRST/stale record). Edges deduped by
  # (source,target,type) so re-emits don't grow the edge list unbounded.
  _atomic_apply '
    .nodes = ( ( [ .nodes[] ] + [ $nodes[]
                   | .depends_on        = (.depends_on // [])
                   | .depended_on_by    = (.depended_on_by // [])
                   | .attributes        = (.attributes // {})
                   | .declared_intent_ref = (.declared_intent_ref // null) ] )
               | reverse | unique_by(.id) )
  | .edges = ( ( .edges + ( $edges | map( .type = (.type // "depends_on") | .direction = (.direction // "forward") | .weight = (.weight // 1) ) ) )
               | unique_by([.source, .target, .type]) )
  ' --argjson nodes "$nodes" --argjson edges "$edges"
  local rc=$?
  _release
  [ "$rc" -eq 0 ] && echo "substrate.sh: bulk-write applied ($node_count nodes, $edge_count edges)"
  return "$rc"
}

cmd_mark_emitter_ran() {
  local name="${1:-}" coverage="${2:-}"
  [ -n "$name" ] || { echo "substrate.sh: mark-emitter-ran requires <name> <coverage>" >&2; return 2; }
  [ -n "$coverage" ] || { echo "substrate.sh: mark-emitter-ran requires a <coverage> value (one of: $VALID_COVERAGE)" >&2; return 2; }
  _in_list "$name" "$KNOWN_EMITTER_NAMES" || { echo "substrate.sh: unknown emitter '$name' (known: $KNOWN_EMITTER_NAMES)" >&2; return 2; }
  _in_list "$coverage" "$VALID_COVERAGE"  || { echo "substrate.sh: invalid coverage '$coverage' (one of: $VALID_COVERAGE)" >&2; return 2; }
  _acquire || return $?
  _atomic_apply '
    .emitters[$name] = { last_emitted_at: $now2, coverage: $cov }
  ' --arg name "$name" --arg cov "$coverage" --arg now2 "$(ts_now)"
  local rc=$?
  _release
  [ "$rc" -eq 0 ] && echo "substrate.sh: emitter '$name' marked ran (coverage=$coverage)"
  return "$rc"
}

cmd_read_topology() {
  local filter="${1:-.}"
  if [ ! -f "$SUBSTRATE_PATH" ]; then
    echo "substrate.sh: substrate not found at $SUBSTRATE_PATH (run: init <entity>)" >&2
    return 4
  fi
  # Validate before serving (read-path trust — never hand back a corrupt substrate silently).
  if ! _validate_core >/dev/null 2>&1; then
    echo "substrate.sh: substrate failed validation — refusing to serve (run validate-schema for details)" >&2
    return 6
  fi
  jq "$filter" "$SUBSTRATE_PATH" 2>/dev/null || { echo "substrate.sh: jq filter failed" >&2; return 6; }
}

# _validate_core: the structural assertion engine. Echoes "PASS" (rc 0) or a violation list (rc 6).
# No lock (read-only). Re-derives the maps and asserts equality, enforces frozen keys + enums +
# the manual->justification rule + edge endpoint integrity.
_validate_core() {
  if [ ! -f "$SUBSTRATE_PATH" ]; then echo "MISSING: $SUBSTRATE_PATH (run init)"; return 6; fi
  if ! jq -e 'type == "object"' "$SUBSTRATE_PATH" >/dev/null 2>&1; then echo "CORRUPT: not valid JSON / not an object"; return 6; fi
  local violations jqrc jqerr
  jqerr="$(mktemp "${SUBSTRATE_DIR}/.topology-valerr.XXXXXX" 2>/dev/null || echo "/tmp/.topology-valerr.$$")"
  # Capture jq's exit code SEPARATELY. A jq abort mid-evaluation (e.g. a type surprise the clause
  # guards missed) must read as CORRUPT, never as an empty-violations PASS (the fail-open bug).
  violations="$(jq -r \
      --argjson tkeys "$TOPLEVEL_KEYS_JSON" \
      --argjson nkeys "$NODE_KEYS_JSON" \
      --arg sv "$SCHEMA_VERSION" \
      --arg kinds "$VALID_KINDS" \
      --arg emitters "$VALID_EMITTERS" \
      --arg coverage "$VALID_COVERAGE" '
    ($kinds    | split(" ")) as $VK |
    ($emitters | split(" ")) as $VE |
    ($coverage | split(" ")) as $VC |
    [
      # top-level key set (exact)
      (if (keys_unsorted | sort) != ($tkeys | sort)
        then "top-level keys mismatch: got \(keys_unsorted|sort) want \($tkeys|sort)" else empty end),
      (if .schema_version != $sv then "schema_version != \($sv) (got \(.schema_version))" else empty end),
      (if (.entity // "") == "" then "entity is empty" else empty end),
      (if (.last_updated // "") == "" then "last_updated is empty" else empty end),
      (if (.nodes|type) != "array" then "nodes is not an array" else empty end),
      (if (.edges|type) != "array" then "edges is not an array" else empty end),
      (if (.parent_map|type) != "object" then "parent_map is not an object" else empty end),
      (if (.child_map|type) != "object" then "child_map is not an object" else empty end),
      (if (.missing_emitters|type) != "array" then "missing_emitters is not an array" else empty end),

      # per-node checks
      # Key check: the 11 frozen keys MUST all be present. ONE conditional extra key is
      # permitted — manual_justification — and ONLY on a manual node (D05 §6.6). Any other
      # extra key, or a missing frozen key, is a violation.
      ( .nodes[]? as $n |
        ( ($n | keys_unsorted) as $have |
          ( ($nkeys - $have) as $missing |
            if ($missing | length) > 0 then "node \($n.id // "?") missing keys \($missing)" else empty end ),
          ( ($have - ($nkeys + ["manual_justification"])) as $extra |
            if ($extra | length) > 0 then "node \($n.id // "?") has unexpected keys \($extra)" else empty end ),
          ( if (($have | index("manual_justification")) != null) and ($n.emitter != "manual")
              then "node \($n.id // "?") carries manual_justification but emitter is not manual" else empty end )
        ),
        ( if ($n.kind as $k | $VK | index($k)) == null then "node \($n.id) invalid kind \($n.kind)" else empty end ),
        ( if ($n.emitter as $e | $VE | index($e)) == null then "node \($n.id) invalid emitter \($n.emitter)" else empty end ),
        ( if $n.emitter == "manual" and (($n.manual_justification // "") == "")
            then "node \($n.id) is manual but has no manual_justification (D05 §6.6)" else empty end )
      ),

      # emitters must be an object (guard before to_entries derefs)
      ( if (.emitters|type) != "object" then "emitters is not an object" else empty end ),
      # per-emitter: value must be an object; coverage must be in the enum (type-guarded so a
      # corrupt emitter value — e.g. a string — yields a VIOLATION string, never a jq abort).
      ( if (.emitters|type) == "object" then ( .emitters | to_entries[] |
          ( if (.value|type) != "object" then "emitter \(.key) value is not an object"
            elif ((.value.coverage // null) as $c | ($c == null) or (($VC | index($c)) == null))
              then "emitter \(.key) invalid coverage \(.value.coverage)"
            else empty end )
        ) else empty end ),

      # edge endpoint integrity (every edge endpoint exists in nodes). Capture the edge as $e first —
      # `($ids | index(.source))` would re-bind . to $ids and index the array with a string (abort).
      # Membership via a set object is O(N+E), not O(N*E).
      ( ( [.nodes[].id] | map({key: ., value: true}) | from_entries ) as $idset |
        .edges[]? | . as $e |
        ( if ($idset[$e.source] != true) then "edge source \($e.source) not in nodes" else empty end ),
        ( if ($idset[$e.target] != true) then "edge target \($e.target) not in nodes" else empty end )
      ),

      # parent_map / child_map equality with the re-derived views
      ( ( [ .nodes[] | {key:.id, value:(.depends_on // [])} ]     | from_entries ) as $expChild |
        ( [ .nodes[] | {key:.id, value:(.depended_on_by // [])} ] | from_entries ) as $expParent |
        ( if (.child_map  | to_entries | sort) != ($expChild  | to_entries | sort)
            then "child_map drifted from nodes.depends_on" else empty end ),
        ( if (.parent_map | to_entries | sort) != ($expParent | to_entries | sort)
            then "parent_map drifted from nodes.depended_on_by" else empty end )
      )
    ] | .[]
  ' "$SUBSTRATE_PATH" 2>"$jqerr")"
  jqrc=$?
  if [ "$jqrc" -ne 0 ]; then
    echo "CORRUPT: validation engine aborted (jq exit $jqrc): $(cat "$jqerr" 2>/dev/null)"
    rm -f "$jqerr" 2>/dev/null || true
    return 6
  fi
  rm -f "$jqerr" 2>/dev/null || true
  if [ -z "$violations" ]; then
    echo "PASS"
    return 0
  fi
  echo "VIOLATIONS:"
  echo "$violations"
  return 6
}

cmd_validate_schema() {
  _validate_core
}

# --- dispatch -------------------------------------------------------------------
main() {
  local cmd="${1:-}"
  shift 2>/dev/null || true
  case "$cmd" in
    init)             cmd_init "$@";;
    write-node)       cmd_write_node "$@";;
    write-edge)       cmd_write_edge "$@";;
    bulk-write)       cmd_bulk_write "$@";;
    mark-emitter-ran) cmd_mark_emitter_ran "$@";;
    read-topology)    cmd_read_topology "$@";;
    validate-schema)  cmd_validate_schema "$@";;
    ''|-h|--help|help)
      grep -E '^#( |$)' "$0" | sed -E 's/^# ?//' | sed -n '1,40p'
      return 0;;
    *)
      echo "substrate.sh: unknown command '$cmd' (run: substrate.sh help)" >&2
      return 2;;
  esac
}

main "$@"
