#!/usr/bin/env bash
# code-emitter/scripts/emit.sh — the finishing harness for the in-repo code emitter.
#
# Intent-Actual-Gap Mechanism Build Programme, M3 Session 4. Takes pre-collected JSON inputs
# (the invoking Claude session runs the Node extractor driver `extract.mjs`, runs the frozen
# transform.jq, writes the resulting canonical-shape nodes/edges arrays to two files), then
# in sequence:
#   1. validates the inputs are JSON arrays
#   2. ensures the substrate exists (init is idempotent; caller may have run it already)
#   3. calls topology-substrate's bulk-write — a SINGLE call below the chunk budget, or a
#      chunked sequence (all node chunks, then all edge chunks) above it (ARG_MAX-safe)
#   4. calls mark-emitter-ran code covered  (only after ALL chunks succeed)
#   5. calls validate-schema (must print PASS)
# Each individual substrate.sh call is atomic (per-call lock); a multi-chunk emit as a whole
# is NOT transactional — see the chunking block + SKILL.md "Known limitations" #7.
#
# Schema authority: ../../topology-substrate/references/canonical-shape.md.
# Portability target: macOS system bash 3.2.57 + jq 1.7. set -uo pipefail per shell-portability.md.
# Shape is based on n8n-cloud-emitter/scripts/emit.sh, with an added ARG_MAX-aware chunking
# path (the CHUNK_BUDGET_BYTES branch + write_in_chunks) NOT present in that sibling; the
# emitter name (code) + entity env var also differ.
#
# Usage:
#   emit.sh <nodes-json-file> <edges-json-file> [entity]
# Args:
#   <nodes-json-file>   path to a file containing a JSON array of nodes (10 D05 §6.1 fields each)
#   <edges-json-file>   path to a file containing a JSON array of edges ({source,target,type,...})
#   [entity]            optional; defaults to env var CODE_EMITTER_ENTITY or 'my-project'
#                       (used to call substrate.sh init if the substrate is absent)
#
# Exit codes:
#   0  ok — bulk-write + mark-emitter-ran + validate-schema all succeeded
#   2  usage / bad-arg / inputs not JSON arrays / files unreadable
#   4  substrate not found AND init failed
#   6  bulk-write / mark-emitter-ran / validate-schema failed (inner stderr explains)

set -uo pipefail

NODES_FILE="${1:-}"
EDGES_FILE="${2:-}"
ENTITY="${3:-${CODE_EMITTER_ENTITY:-my-project}}"

if [ -z "$NODES_FILE" ] || [ -z "$EDGES_FILE" ]; then
  echo "emit.sh: usage: emit.sh <nodes-json-file> <edges-json-file> [entity]" >&2
  exit 2
fi
if [ ! -r "$NODES_FILE" ]; then
  echo "emit.sh: nodes file not readable: $NODES_FILE" >&2
  exit 2
fi
if [ ! -r "$EDGES_FILE" ]; then
  echo "emit.sh: edges file not readable: $EDGES_FILE" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "emit.sh: jq not found in PATH — required (brew install jq)" >&2
  exit 6
fi

# Resolve substrate.sh path relative to this script so the harness works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
if [ ! -f "$SUBSTRATE_SH" ]; then
  echo "emit.sh: substrate.sh not found at $SUBSTRATE_SH — refuse to proceed (the M3 Session-1 contract must be present)" >&2
  exit 6
fi

# --- input validation -----------------------------------------------------------
# Inputs MUST be JSON arrays. We don't re-validate the canonical-shape per-node — that's
# substrate.sh bulk-write's job (a single _validate_nodes_batch pass; fail-fast there).
if ! jq -e 'type == "array"' "$NODES_FILE" >/dev/null 2>&1; then
  echo "emit.sh: nodes file is not a JSON array: $NODES_FILE" >&2
  exit 2
fi
if ! jq -e 'type == "array"' "$EDGES_FILE" >/dev/null 2>&1; then
  echo "emit.sh: edges file is not a JSON array: $EDGES_FILE" >&2
  exit 2
fi

NODE_COUNT="$(jq 'length' "$NODES_FILE" 2>/dev/null)"
EDGE_COUNT="$(jq 'length' "$EDGES_FILE" 2>/dev/null)"
NODE_COUNT="$(printf '%s' "$NODE_COUNT" | tr -dc '0-9' | head -c 12)"; NODE_COUNT="${NODE_COUNT:-0}"
EDGE_COUNT="$(printf '%s' "$EDGE_COUNT" | tr -dc '0-9' | head -c 12)"; EDGE_COUNT="${EDGE_COUNT:-0}"

# --- ensure substrate exists ----------------------------------------------------
# init is idempotent: a present-substrate exit is success with an "already exists" message
# on stdout. A real failure (corrupt parent dir, lock contention, jq missing) lands as a
# nonzero rc with diagnostic on stderr. Capture both streams so the operator sees the
# actual first-failure cause — re-running visibly would mask the original error if the
# first attempt left partial state (CRITICAL finding from Session-2 code-council review).
INIT_OUT="$(bash "$SUBSTRATE_SH" init "$ENTITY" 2>&1)"
INIT_RC=$?
if [ "$INIT_RC" -ne 0 ]; then
  echo "emit.sh: substrate init failed for entity '$ENTITY' (rc=$INIT_RC):" >&2
  echo "$INIT_OUT" >&2
  exit 4
fi

# --- bulk-write (ARG_MAX-aware, chunked) ----------------------------------------
# substrate.sh bulk-write takes its arguments as JSON STRINGS via shell argv, not file paths.
# macOS ARG_MAX is ~1 MB TOTAL across argv+env, so a single call with both arrays inline fails
# ("Argument list too long") once the combined payload approaches that cap. At my-project v1
# scale the node array alone (~1 MB, fattened by the re-derived depends_on/depended_on_by
# adjacency lists) plus the edges array (~700 KB) is ~1.7 MB — well over the cap.
#
# substrate.sh bulk-write is idempotent: nodes upsert by id (incoming wins) and edges dedupe
# by (source,target,type). So a full emit can be applied as a SEQUENCE of bulk-write calls,
# each under the cap, with identical end state to one big call:
#   - First write ALL node chunks (edges []). The substrate re-derives parent_map/child_map
#     from each chunk's node adjacency arrays; the union accumulates across chunks.
#   - THEN write edge chunks (nodes []). By now every node exists, so the edge endpoint
#     integrity check (existing ∪ incoming) passes for every edge.
# A chunk budget of 600 KB per array leaves headroom for the second arg + env + jq overhead
# under the 1,048,576-byte cap. Single-call fast-path is preserved when the payload is small
# (the common case for smaller repos / the eval fixtures). The budget is env-overridable so
# the eval can force the chunked path on a tiny fixture (set CHUNK_BUDGET_BYTES low).
CHUNK_BUDGET_BYTES="${CHUNK_BUDGET_BYTES:-600000}"
NODES_BYTES="$(wc -c < "$NODES_FILE" | tr -dc '0-9')"; NODES_BYTES="${NODES_BYTES:-0}"
EDGES_BYTES="$(wc -c < "$EDGES_FILE" | tr -dc '0-9')"; EDGES_BYTES="${EDGES_BYTES:-0}"
TOTAL_BYTES=$(( NODES_BYTES + EDGES_BYTES ))

# Byte-measurement sanity floor: a non-empty array whose measured byte size is implausibly
# small means wc failed (truncated read, fallback fired) — and a too-small divisor would
# inflate the chunk size past ARG_MAX, defeating the whole purpose. Halt loud rather than
# compute a chunk size from a bad measurement. (An empty array is legitimately ~2 bytes "[]".)
if [ "$NODE_COUNT" -gt 0 ] && [ "$NODES_BYTES" -lt 2 ]; then
  echo "emit.sh: node byte-size measurement failed (count=$NODE_COUNT bytes=$NODES_BYTES) — refusing to chunk from a bad divisor" >&2
  exit 6
fi
if [ "$EDGE_COUNT" -gt 0 ] && [ "$EDGES_BYTES" -lt 2 ]; then
  echo "emit.sh: edge byte-size measurement failed (count=$EDGE_COUNT bytes=$EDGES_BYTES) — refusing to chunk from a bad divisor" >&2
  exit 6
fi

echo "emit.sh: writing $NODE_COUNT nodes + $EDGE_COUNT edges to substrate (entity=$ENTITY)..."

# write_in_chunks <array-file> <node-or-edge> <chunk-size>
# Pre-splits the JSON array into <chunk-size>-element pieces with ONE jq pass (writing each
# piece to a temp file), then issues one bulk-write per piece. This is O(N) total parse work
# — NOT the O(N^2) of re-reading the whole file per slice. Each piece is written as the
# relevant kind with the OTHER kind empty []. Returns nonzero on the first failed chunk.
write_in_chunks() {
  local arr_file="$1" kind="$2" chunk_size="$3"
  local split_dir piece nodes_arg edges_arg rc
  split_dir="$(mktemp -d "${TMPDIR:-/tmp}/code-emit-split-XXXXXX")" || {
    echo "emit.sh: mktemp failed for chunk split" >&2; return 6; }
  # ONE jq pass: emit each chunk as a compact JSON array on its own line; split into files.
  # `range(0; (length/$n)|ceil)` indexes the chunks; `.[$i*$n : ($i+1)*$n]` slices each.
  if ! jq -c --argjson n "$chunk_size" \
        '[ range(0; ((length/$n)|ceil)) as $i | .[$i*$n : ($i+1)*$n] ] | .[]' \
        "$arr_file" > "$split_dir/chunks.jsonl" 2>"$split_dir/jqerr"; then
    echo "emit.sh: jq chunk-split failed for $kind: $(cat "$split_dir/jqerr" 2>/dev/null)" >&2
    rm -rf "$split_dir"; return 6
  fi
  rc=0
  while IFS= read -r piece; do
    # Guard against an empty/malformed slice feeding bulk-write a non-array.
    case "$piece" in ""|"null") echo "emit.sh: empty $kind chunk slice — aborting" >&2; rc=6; break;; esac
    if [ "$kind" = "nodes" ]; then nodes_arg="$piece"; edges_arg="[]";
    else nodes_arg="[]"; edges_arg="$piece"; fi
    if ! bash "$SUBSTRATE_SH" bulk-write "$nodes_arg" "$edges_arg"; then
      echo "emit.sh: bulk-write failed on a $kind chunk — see substrate.sh stderr above" >&2
      rc=6; break
    fi
  done < "$split_dir/chunks.jsonl"
  rm -rf "$split_dir"
  return "$rc"
}

if [ "$TOTAL_BYTES" -le "$CHUNK_BUDGET_BYTES" ]; then
  # Fast path: single call (small payloads — smaller repos, eval fixtures).
  if ! bash "$SUBSTRATE_SH" bulk-write "$(cat "$NODES_FILE")" "$(cat "$EDGES_FILE")"; then
    echo "emit.sh: bulk-write failed — see substrate.sh stderr above" >&2
    exit 6
  fi
else
  # Chunked path: ALL nodes first (so edge integrity passes), THEN edges.
  # Element-count chunk sizes are derived from the byte budget so each slice stays under cap:
  # chunk = budget * count / total_bytes  (proportional to the per-element average size).
  echo "emit.sh: payload ${TOTAL_BYTES}B exceeds ${CHUNK_BUDGET_BYTES}B chunk budget — writing in chunks (ARG_MAX-safe)"
  NODE_CHUNK=$(( NODE_COUNT > 0 ? CHUNK_BUDGET_BYTES * NODE_COUNT / NODES_BYTES : 0 ))
  EDGE_CHUNK=$(( EDGE_COUNT > 0 ? CHUNK_BUDGET_BYTES * EDGE_COUNT / EDGES_BYTES : 0 ))
  [ "$NODE_CHUNK" -lt 1 ] && NODE_CHUNK=1
  [ "$EDGE_CHUNK" -lt 1 ] && EDGE_CHUNK=1
  if [ "$NODE_COUNT" -gt 0 ]; then
    if ! write_in_chunks "$NODES_FILE" nodes "$NODE_CHUNK"; then exit 6; fi
  fi
  if [ "$EDGE_COUNT" -gt 0 ]; then
    if ! write_in_chunks "$EDGES_FILE" edges "$EDGE_CHUNK"; then exit 6; fi
  fi
fi

# --- mark-emitter-ran -----------------------------------------------------------
if ! bash "$SUBSTRATE_SH" mark-emitter-ran code covered; then
  echo "emit.sh: mark-emitter-ran code covered failed — substrate write succeeded but heartbeat did NOT register (Reliability-Engineer NON-SHIPPABLE state — investigate immediately)" >&2
  exit 6
fi

# --- validate-schema ------------------------------------------------------------
# Capture stdout so we can inspect for the PASS sentinel without grep -q swallowing it.
VALIDATE_OUT="$(bash "$SUBSTRATE_SH" validate-schema 2>&1)"
VALIDATE_RC=$?
if [ "$VALIDATE_RC" -ne 0 ]; then
  echo "emit.sh: validate-schema returned nonzero ($VALIDATE_RC)" >&2
  echo "$VALIDATE_OUT" >&2
  exit 6
fi
# Anchored match — the substrate's validate-schema prints exactly "PASS" on its own line on
# success, otherwise a violation list. A loose `grep -q 'PASS'` would falsely accept any
# violation-list line containing the substring "PASS". Matches the eval's anchored discipline
# (canonical-shape.sh) — Session-2 code-council CRITICAL.
if ! printf '%s\n' "$VALIDATE_OUT" | grep -q '^PASS$'; then
  echo "emit.sh: validate-schema did not print PASS sentinel — substrate may be corrupt" >&2
  echo "$VALIDATE_OUT" >&2
  exit 6
fi

echo "emit.sh: PASS — emitted $NODE_COUNT nodes, $EDGE_COUNT edges; code coverage=covered"
exit 0
