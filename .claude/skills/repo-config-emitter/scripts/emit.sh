#!/usr/bin/env bash
# repo-config-emitter/scripts/emit.sh — the finishing harness for the in-repo n8n + config emitter.
#
# Intent-Actual-Gap Mechanism Build Programme, M3 Session 5 (the FOURTH emitter). Takes
# pre-collected JSON inputs (the invoking Claude session reads the 4 in-repo n8n JSON files +
# vercel.json + package.json, runs the frozen transform.jq, writes the resulting canonical-shape
# nodes/edges arrays to two files), then in sequence:
#   1. validates the inputs are JSON arrays
#   2. ensures the substrate exists (init is idempotent; caller may have run it already)
#   3. calls topology-substrate's bulk-write — a SINGLE call below the chunk budget, or a
#      chunked sequence (all node chunks, then all edge chunks) above it (ARG_MAX-safe)
#   4. calls mark-emitter-ran code covered  (only after ALL chunks succeed)
#      -> the heartbeat marks the `code` slot: all 3 Session-5 surfaces (in-repo n8n + vercel +
#         package) are in-repo code/config; the frozen 3-slot emitters block has no `n8n-repo`
#         slot (OPEN-1 resolved: mark `code`, same slot Session 4 used).
#   5. calls validate-schema (must print PASS)
# Each individual substrate.sh call is atomic (per-call lock); a multi-chunk emit as a whole
# is NOT transactional — see the chunking block + SKILL.md "Known limitations".
#
# Schema authority: ../../topology-substrate/references/canonical-shape.md.
# Portability target: macOS system bash 3.2.57 + jq 1.7. set -uo pipefail per shell-portability.md.
# Shape is a near-verbatim copy of code-emitter/scripts/emit.sh (Session 4's proven ARG_MAX-aware
# chunked harness). The only BEHAVIOURAL-class difference is the entity env-var name
# (REPO_CONFIG_ENTITY vs CODE_EMITTER_ENTITY); the rest are cosmetic string differences: the
# comment header (Session 5, the 3 surfaces), the chunk-split mktemp template prefix
# (repo-config-split- vs code-emit-split-), and the final PASS echo's surface-list suffix. The
# heartbeat call is IDENTICAL (mark-emitter-ran code covered) — both emitters mark the `code` slot.
#
# Usage:
#   emit.sh <nodes-json-file> <edges-json-file> [entity]
# Args:
#   <nodes-json-file>   path to a file containing a JSON array of nodes (10 D05 §6.1 fields each)
#   <edges-json-file>   path to a file containing a JSON array of edges ({source,target,type,...})
#   [entity]            optional; defaults to env var REPO_CONFIG_ENTITY or 'my-project'
#
# Exit codes:
#   0  ok — bulk-write + mark-emitter-ran + validate-schema all succeeded
#   2  usage / bad-arg / inputs not JSON arrays / files unreadable
#   4  substrate not found AND init failed
#   6  bulk-write / mark-emitter-ran / validate-schema failed (inner stderr explains)

set -uo pipefail

NODES_FILE="${1:-}"
EDGES_FILE="${2:-}"
ENTITY="${3:-${REPO_CONFIG_ENTITY:-my-project}}"

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
# init is idempotent; capture both streams so the operator sees the actual first-failure cause.
INIT_OUT="$(bash "$SUBSTRATE_SH" init "$ENTITY" 2>&1)"
INIT_RC=$?
if [ "$INIT_RC" -ne 0 ]; then
  echo "emit.sh: substrate init failed for entity '$ENTITY' (rc=$INIT_RC):" >&2
  echo "$INIT_OUT" >&2
  exit 4
fi

# --- bulk-write (ARG_MAX-aware, chunked) ----------------------------------------
# substrate.sh bulk-write takes its arguments as JSON STRINGS via shell argv. macOS ARG_MAX is
# ~1 MB TOTAL across argv+env, so a single call with both arrays inline fails once the combined
# payload approaches that cap. bulk-write is idempotent (nodes upsert by id; edges dedupe by
# (source,target,type)), so a full emit applies as a SEQUENCE of sub-cap calls with identical
# end state: ALL node chunks first (edges []), THEN edge chunks (nodes []).
# Session-5 payload is small (4 workflows + ~78 nodes + 2 config nodes) so the fast-path fires —
# but the chunked harness is copied verbatim for correctness + propagation to larger entities.
CHUNK_BUDGET_BYTES="${CHUNK_BUDGET_BYTES:-600000}"
NODES_BYTES="$(wc -c < "$NODES_FILE" | tr -dc '0-9')"; NODES_BYTES="${NODES_BYTES:-0}"
EDGES_BYTES="$(wc -c < "$EDGES_FILE" | tr -dc '0-9')"; EDGES_BYTES="${EDGES_BYTES:-0}"
TOTAL_BYTES=$(( NODES_BYTES + EDGES_BYTES ))

# Byte-measurement sanity floor — refuse to chunk from a bad divisor (wc failure).
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
write_in_chunks() {
  local arr_file="$1" kind="$2" chunk_size="$3"
  local split_dir piece nodes_arg edges_arg rc
  split_dir="$(mktemp -d "${TMPDIR:-/tmp}/repo-config-split-XXXXXX")" || {
    echo "emit.sh: mktemp failed for chunk split" >&2; return 6; }
  if ! jq -c --argjson n "$chunk_size" \
        '[ range(0; ((length/$n)|ceil)) as $i | .[$i*$n : ($i+1)*$n] ] | .[]' \
        "$arr_file" > "$split_dir/chunks.jsonl" 2>"$split_dir/jqerr"; then
    echo "emit.sh: jq chunk-split failed for $kind: $(cat "$split_dir/jqerr" 2>/dev/null)" >&2
    rm -rf "$split_dir"; return 6
  fi
  rc=0
  while IFS= read -r piece; do
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
  # Fast path: single call (the common case for Session-5's small payload + the eval fixtures).
  if ! bash "$SUBSTRATE_SH" bulk-write "$(cat "$NODES_FILE")" "$(cat "$EDGES_FILE")"; then
    echo "emit.sh: bulk-write failed — see substrate.sh stderr above" >&2
    exit 6
  fi
else
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
# OPEN-1: marks the `code` slot (in-repo n8n + vercel + package are all in-repo code/config;
# the frozen emitters block has no n8n-repo slot). Same slot Session 4 used.
if ! bash "$SUBSTRATE_SH" mark-emitter-ran code covered; then
  echo "emit.sh: mark-emitter-ran code covered failed — substrate write succeeded but heartbeat did NOT register (Reliability-Engineer NON-SHIPPABLE state — investigate immediately)" >&2
  exit 6
fi

# --- validate-schema ------------------------------------------------------------
VALIDATE_OUT="$(bash "$SUBSTRATE_SH" validate-schema 2>&1)"
VALIDATE_RC=$?
if [ "$VALIDATE_RC" -ne 0 ]; then
  echo "emit.sh: validate-schema returned nonzero ($VALIDATE_RC)" >&2
  echo "$VALIDATE_OUT" >&2
  exit 6
fi
if ! printf '%s\n' "$VALIDATE_OUT" | grep -q '^PASS$'; then
  echo "emit.sh: validate-schema did not print PASS sentinel — substrate may be corrupt" >&2
  echo "$VALIDATE_OUT" >&2
  exit 6
fi

echo "emit.sh: PASS — emitted $NODE_COUNT nodes, $EDGE_COUNT edges; code coverage=covered (in-repo n8n + vercel + package)"
exit 0
