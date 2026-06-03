#!/usr/bin/env bash
# n8n-cloud-emitter/scripts/emit.sh — the finishing harness for the n8n cloud emitter.
#
# Intent-Actual-Gap Mechanism Build Programme, M3 Session 3. Takes pre-collected JSON inputs
# (the invoking Claude session runs the MCP calls via mcp__n8n-mcp-<instance>__*, runs the
# frozen transform.jq, writes the resulting canonical-shape nodes/edges arrays to two files),
# then atomically:
#   1. validates the inputs are JSON arrays
#   2. ensures the substrate exists (init is idempotent; caller may have run it already)
#   3. calls topology-substrate's bulk-write in ONE call
#   4. calls mark-emitter-ran n8n-cloud covered
#   5. calls validate-schema (must print PASS)
#
# Schema authority: ../../topology-substrate/references/canonical-shape.md.
# Portability target: macOS system bash 3.2.57 + jq 1.7. set -uo pipefail per shell-portability.md.
#
# Usage:
#   emit.sh <nodes-json-file> <edges-json-file> [entity]
# Args:
#   <nodes-json-file>   path to a file containing a JSON array of nodes (10 D05 §6.1 fields each)
#   <edges-json-file>   path to a file containing a JSON array of edges ({source,target,type,...})
#   [entity]            optional; defaults to env var N8N_CLOUD_ENTITY or 'your-entity'
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
ENTITY="${3:-${N8N_CLOUD_ENTITY:-your-entity}}"

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

# --- bulk-write -----------------------------------------------------------------
# substrate.sh bulk-write takes its arguments as JSON STRINGS, not file paths — pass the
# contents via $(cat). Using cat keeps the args within shell argv limits at typical entity scale
# (11 workflows, ~250 workflow_nodes, ~400 edges => well under macOS ARG_MAX of ~1MB).
echo "emit.sh: writing $NODE_COUNT nodes + $EDGE_COUNT edges to substrate (entity=$ENTITY)..."
if ! bash "$SUBSTRATE_SH" bulk-write "$(cat "$NODES_FILE")" "$(cat "$EDGES_FILE")"; then
  echo "emit.sh: bulk-write failed — see substrate.sh stderr above" >&2
  exit 6
fi

# --- mark-emitter-ran -----------------------------------------------------------
if ! bash "$SUBSTRATE_SH" mark-emitter-ran n8n-cloud covered; then
  echo "emit.sh: mark-emitter-ran n8n-cloud covered failed — substrate write succeeded but heartbeat did NOT register (Reliability-Engineer NON-SHIPPABLE state — investigate immediately)" >&2
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
# violation-list line containing the substring "PASS" (e.g. a hypothetical "field PASS missing").
# This matches the eval's anchored discipline (canonical-shape.sh) — Session-2 code-council CRITICAL.
if ! printf '%s\n' "$VALIDATE_OUT" | grep -q '^PASS$'; then
  echo "emit.sh: validate-schema did not print PASS sentinel — substrate may be corrupt" >&2
  echo "$VALIDATE_OUT" >&2
  exit 6
fi

echo "emit.sh: PASS — emitted $NODE_COUNT nodes, $EDGE_COUNT edges; n8n-cloud coverage=covered"
exit 0
