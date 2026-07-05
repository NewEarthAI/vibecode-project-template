#!/usr/bin/env bash
# external-api-graph-emitter/scripts/emit.sh — the finishing harness for the external-api-graph emitter.
#
# Intent-Actual-Gap Mechanism Build Programme — visual-layer Phase 1b. Takes pre-collected JSON inputs
# (the invoking Claude session reads the entity's n8n workflow JSON READ-ONLY, runs transform.jq with
# the live substrate node-ids + supabase coverage, writes the resulting external_endpoint nodes +
# cross-system edges arrays to two files), then:
#   1. validates the inputs are JSON arrays
#   2. ensures the substrate exists (init is idempotent; caller may have run it already)
#   3. calls topology-substrate's bulk-write
#   4. calls validate-schema (must print PASS)
#
# NO mark-emitter-ran: `external-api-graph` is declared in the substrate's `missing_emitters` and is
# NOT yet a registered emitter SLOT (KNOWN_EMITTER_NAMES = code / supabase-live / n8n-cloud). Promoting
# it to a slot (+ a coverage heartbeat) is M5-GATED (the live-cloud run). At [NOW] scope the emitter
# PRODUCES external_endpoint nodes (emitter external_api_parser) + cross-system edges and validates
# them; coverage tracking for this emitter lands with the M5 live run.
#
# Schema authority: ../../topology-substrate/references/canonical-shape.md.
# Portability target: macOS system bash 3.2.57 + jq 1.7. set -uo pipefail per shell-portability.md.
#
# Usage:   emit.sh <nodes-json-file> <edges-json-file> [entity]
# Exit codes:
#   0  ok — bulk-write + validate-schema succeeded
#   2  usage / bad-arg / inputs not JSON arrays / files unreadable
#   4  substrate not found AND init failed
#   6  bulk-write / validate-schema failed (inner stderr explains)

set -uo pipefail

NODES_FILE="${1:-}"
EDGES_FILE="${2:-}"
ENTITY="${3:-${EXTERNAL_API_GRAPH_ENTITY:-my-project}}"

[ -n "$NODES_FILE" ] && [ -n "$EDGES_FILE" ] || { echo "emit.sh: usage: emit.sh <nodes-json-file> <edges-json-file> [entity]" >&2; exit 2; }
[ -r "$NODES_FILE" ] || { echo "emit.sh: nodes file not readable: $NODES_FILE" >&2; exit 2; }
[ -r "$EDGES_FILE" ] || { echo "emit.sh: edges file not readable: $EDGES_FILE" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "emit.sh: jq not found in PATH (brew install jq)" >&2; exit 6; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
[ -f "$SUBSTRATE_SH" ] || { echo "emit.sh: substrate.sh not found at $SUBSTRATE_SH (the M3 Session-1 contract must be present)" >&2; exit 6; }

# --- input validation: must be JSON arrays --------------------------------------
jq -e 'type == "array"' "$NODES_FILE" >/dev/null 2>&1 || { echo "emit.sh: nodes file is not a JSON array: $NODES_FILE" >&2; exit 2; }
jq -e 'type == "array"' "$EDGES_FILE" >/dev/null 2>&1 || { echo "emit.sh: edges file is not a JSON array: $EDGES_FILE" >&2; exit 2; }

NODE_COUNT="$(jq 'length' "$NODES_FILE" 2>/dev/null | tr -dc '0-9' | head -c 12)"; NODE_COUNT="${NODE_COUNT:-0}"
EDGE_COUNT="$(jq 'length' "$EDGES_FILE" 2>/dev/null | tr -dc '0-9' | head -c 12)"; EDGE_COUNT="${EDGE_COUNT:-0}"

# --- ensure substrate exists ----------------------------------------------------
INIT_OUT="$(bash "$SUBSTRATE_SH" init "$ENTITY" 2>&1)"; INIT_RC=$?
if [ "$INIT_RC" -ne 0 ]; then
  echo "emit.sh: substrate init failed for entity '$ENTITY' (rc=$INIT_RC):" >&2
  echo "$INIT_OUT" >&2
  exit 4
fi

echo "emit.sh: writing $NODE_COUNT external_endpoint nodes + $EDGE_COUNT cross-system edges (entity=$ENTITY)..."

# --- bulk-write -----------------------------------------------------------------
# external-api payloads are small (external_endpoint nodes + cross-system edges only, never the full
# code/db graph), so a single bulk-write stays well under ARG_MAX. Nodes first so edge endpoints exist.
if ! bash "$SUBSTRATE_SH" bulk-write "$(cat "$NODES_FILE")" "$(cat "$EDGES_FILE")"; then
  echo "emit.sh: bulk-write failed — see substrate.sh stderr above" >&2
  exit 6
fi

# --- validate-schema ------------------------------------------------------------
VALIDATE_OUT="$(bash "$SUBSTRATE_SH" validate-schema 2>&1)"; VALIDATE_RC=$?
if [ "$VALIDATE_RC" -ne 0 ]; then
  echo "emit.sh: validate-schema returned nonzero ($VALIDATE_RC)" >&2; echo "$VALIDATE_OUT" >&2; exit 6
fi
if ! printf '%s\n' "$VALIDATE_OUT" | grep -q '^PASS$'; then
  echo "emit.sh: validate-schema did not print PASS sentinel — substrate may be corrupt" >&2; echo "$VALIDATE_OUT" >&2; exit 6
fi

echo "emit.sh: PASS — emitted $NODE_COUNT external_endpoint nodes, $EDGE_COUNT cross-system edges (no coverage heartbeat — external-api-graph slot registration is M5-gated)"
exit 0
