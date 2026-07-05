#!/usr/bin/env bash
# intent-capture-emitter/scripts/emit.sh — index ONE intent carrier into the intent store (M6 S2b).
#
# Pipeline (mirrors the topology emitters: extract -> transform.jq -> store bulk-write -> mark-ran
# -> validate): parse the carrier, resolve git provenance, map to the §6.1 record, upsert it into
# the ledger at INTENT_SUBSTRATE_PATH, mark the parser ran, and validate the ledger.
#
# git provenance uses COMMIT-TIME (never wall-clock — shell-portability + D06 §6.7/A11): the
# carrier last-change commit + its committer-date ISO. An UNCOMMITTED carrier is stamped
# `uncommitted+dirty` + now, so the downstream freshness precondition (council A11) can return
# `inconclusive: uncommitted-changes` rather than a false in_sync.
#
# Usage:  emit.sh <destination|adr|roadmap_item> <carrier-file> [<entity>]
# Exit:   0 ok | 2 usage/bad-arg | 6 extract/transform/store failure
#
# Portability: set -o pipefail, namespaced locals, numeric-safe; no apostrophes in inline jq.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
EXTRACT="$SCRIPT_DIR/extract.mjs"
TRANSFORM="$SCRIPT_DIR/transform.jq"
STORE="$SCRIPT_DIR/intent-store.sh"

kind="${1:-}"; carrier="${2:-}"; entity="${3:-}"
[ -n "$kind" ] && [ -n "$carrier" ] || { echo "emit.sh: usage: emit.sh <destination|adr|roadmap_item> <carrier-file> [entity]" >&2; exit 2; }
[ -f "$carrier" ] || { echo "emit.sh: carrier not found: $carrier" >&2; exit 2; }
command -v jq   >/dev/null 2>&1 || { echo "emit.sh: jq not found" >&2; exit 6; }
command -v node >/dev/null 2>&1 || { echo "emit.sh: node not found" >&2; exit 6; }

# --- 1. git provenance (commit-time, never wall-clock) --------------------------
src_commit="$(git log -1 --format=%H -- "$carrier" 2>/dev/null || echo '')"
ts=""
if [ -n "$src_commit" ]; then
  # Dirty-state guard: if the carrier has uncommitted edits, the committed sha is stale for it.
  if ! git diff --quiet -- "$carrier" 2>/dev/null; then
    src_commit="${src_commit}+dirty"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  else
    ts="$(git log -1 --format=%cI -- "$carrier" 2>/dev/null || echo '')"
  fi
else
  src_commit="uncommitted+dirty"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi
[ -n "$ts" ] || ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- 2. extract -> transform ----------------------------------------------------
raw="$(node "$EXTRACT" "$kind" "$carrier")" || { echo "emit.sh: extract failed" >&2; exit 6; }
out="$(printf '%s' "$raw" | jq -f "$TRANSFORM" --arg source_commit "$src_commit" --arg timestamp "$ts" 2>/dev/null)" \
  || { echo "emit.sh: transform failed" >&2; exit 6; }

record="$(printf '%s' "$out" | jq -c '.record')"
[ -n "$record" ] && [ "$record" != "null" ] || { echo "emit.sh: transform produced no record" >&2; exit 6; }

# --- 3. init (idempotent) + bulk-write + mark-ran + validate --------------------
if [ -n "$entity" ]; then bash "$STORE" init "$entity" >/dev/null 2>&1 || true; fi
bash "$STORE" bulk-write "[$record]" || { echo "emit.sh: store bulk-write failed" >&2; exit 6; }
bash "$STORE" mark-emitter-ran "${kind}_parser" covered >/dev/null 2>&1 || true
vr="$(bash "$STORE" validate-schema 2>&1)"
if [ "$vr" != "PASS" ]; then echo "emit.sh: ledger validation FAILED after write:" >&2; echo "$vr" >&2; exit 6; fi

# --- 4. surface diagnostics (the prose-falsifier note — honest, not silent) -----
diag="$(printf '%s' "$out" | jq -r '.diagnostics | .wired_to_note + " " + .note' 2>/dev/null || echo '')"
echo "emit.sh: indexed $kind carrier -> record. $diag"
echo "emit.sh: OK — $kind carrier indexed, ledger validates PASS (record id: $(printf '%s' "$record" | jq -r '.id'))"
