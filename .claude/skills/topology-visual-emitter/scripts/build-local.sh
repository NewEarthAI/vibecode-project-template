#!/usr/bin/env bash
# topology-visual-emitter/scripts/build-local.sh
# Wave 1 — the local floor. Reads the FROZEN substrate + reconcile, runs the two transforms, writes the
# two render JSONs into the local viewer's public dir, and (optionally) launches the viewer.
#
#   bash build-local.sh [<entity-label>] [--no-serve]
#
# If no real substrate/reconcile is available (e.g. running in the workshop itself, which has no
# substrate), it falls back to the golden fixtures so the viewer always has something to render.
# READ-ONLY over the substrate + reconcile (composes their read helpers; never writes either).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
WORKSHOP="$(cd "$SKILL/../../.." && pwd)"
VIEWER="$WORKSHOP/topology-viewer"
SUB_SH="$WORKSHOP/.claude/skills/topology-substrate/scripts/substrate.sh"
REC_SH="$WORKSHOP/.claude/skills/topology-reconcile/scripts/reconcile.sh"
FIX="$SKILL/evals/fixtures"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

ENTITY="${1:-}"
SERVE=1
for a in "$@"; do [ "$a" = "--no-serve" ] && SERVE=0; done

WORK="$(mktemp -d -t topo-visual.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
SUB_JSON="$WORK/substrate.json"
REC_JSON="$WORK/reconcile.json"

# --- source substrate + reconcile from ONE provenance (both live or both fixture). Mixing a fixture
#     substrate with live reconcile output (or vice-versa) produces a node-id mismatch where the overlay
#     references nodes that aren't in the graph — so the two are coupled, never sourced independently. ---
# TOPO_FIXTURE=<name> forces a named fixture PAIR (substrate-<name>.json + reconcile-<name>.json) and
# skips the live probe — e.g. TOPO_FIXTURE=cross-system renders the Phase-2 cross-system demo.
LIVE=0
FORCED=0
if [ -n "${TOPO_FIXTURE:-}" ]; then
  # allowlist — TOPO_FIXTURE is interpolated into a file path; reject anything but [a-z0-9_-]
  # (blocks path traversal like ../../etc when wired into an automated runner). bash 3.2 safe.
  case "$TOPO_FIXTURE" in *[!a-z0-9_-]*) echo "✗ TOPO_FIXTURE must match [a-z0-9_-]" >&2; exit 1;; esac
  FSUB="$FIX/substrate-$TOPO_FIXTURE.json"; FREC="$FIX/reconcile-$TOPO_FIXTURE.json"
  if [ -f "$FSUB" ] && [ -f "$FREC" ]; then
    cp "$FSUB" "$SUB_JSON"; cp "$FREC" "$REC_JSON"; FORCED=1
    echo "• source: named fixture pair (TOPO_FIXTURE=$TOPO_FIXTURE)"
  else
    echo "✗ TOPO_FIXTURE=$TOPO_FIXTURE but $FSUB / $FREC not found" >&2; exit 1
  fi
fi

if [ "$FORCED" -eq 0 ]; then
  if [ -f "$SUB_SH" ] && bash "$SUB_SH" read-topology '.' > "$SUB_JSON" 2>/dev/null && [ -s "$SUB_JSON" ]; then
    NODES="$(jq '.nodes | length' "$SUB_JSON" 2>/dev/null)"; NODES="$(printf '%s' "${NODES:-0}" | tr -dc '0-9')"; NODES="${NODES:-0}"
    [ "$NODES" -gt 0 ] && LIVE=1
  fi

  if [ "$LIVE" -eq 1 ] && [ -f "$REC_SH" ] && bash "$REC_SH" --json > "$REC_JSON" 2>/dev/null && [ -s "$REC_JSON" ]; then
    echo "• source: live substrate + live reconcile (same provenance)"
  else
    cp "$FIX/substrate.json" "$SUB_JSON"
    cp "$FIX/reconcile.json" "$REC_JSON"
    echo "• source: golden fixtures (no live substrate+reconcile pair found — both from fixtures, kept consistent)"
  fi
fi

# --- run the two transforms ---
mkdir -p "$VIEWER/public"
if ! jq --arg now "$NOW" -f "$SKILL/scripts/graph-transform.jq" "$SUB_JSON" > "$VIEWER/public/graph.json"; then
  echo "✗ graph-transform failed" >&2; exit 1
fi
if ! jq --arg now "$NOW" --slurpfile sub "$SUB_JSON" -f "$SKILL/scripts/drift-overlay-transform.jq" "$REC_JSON" > "$VIEWER/public/drift-overlay.json"; then
  echo "✗ drift-overlay-transform failed" >&2; exit 1
fi

N="$(jq '.nodes|length' "$VIEWER/public/graph.json")"
D="$(jq '.driftCount' "$VIEWER/public/drift-overlay.json")"
S="$(jq -r '.summary' "$VIEWER/public/drift-overlay.json")"
CS="$(jq '[.edges[]|select(.cross_system)]|length' "$VIEWER/public/graph.json" 2>/dev/null)"; CS="${CS:-0}"
BS="$(jq -r '.has_blind_spot_edges // false' "$VIEWER/public/graph.json" 2>/dev/null)"; BS="${BS:-false}"
[ -n "$ENTITY" ] && echo "• entity label: $ENTITY"
echo "• wrote graph.json ($N nodes) + drift-overlay.json (summary=$S, drift=$D) → topology-viewer/public/"
echo "• cross-system edges: $CS (blind-spot present: $BS)"

if [ "$SERVE" -eq 0 ]; then
  echo "• --no-serve: skipping launch. Open the viewer with:  cd topology-viewer && npm install && npm run dev"
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "• npm not found — open the viewer manually:  cd topology-viewer && npm install && npm run dev"
  exit 0
fi

cd "$VIEWER" || exit 1
[ -d node_modules ] || { echo "• installing viewer deps (first run)…"; npm install; }
echo "• launching the viewer (Ctrl-C to stop)…"
npm run dev
