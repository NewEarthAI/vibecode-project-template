#!/usr/bin/env bash
# Eval: drift-overlay-transform.jq over the golden fixtures.
# Asserts the references/drift-overlay-shape.md contract: the 5 states + precedence + the honesty
# guards (verbatim summary, blind-spot != in-sync) + the negative vacuous-green-light test.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
SUB="$HERE/fixtures/substrate.json"
JQF="$SKILL/scripts/drift-overlay-transform.jq"
OUT="$(mktemp -t overlay-out.XXXXXX)"
OUT2="$(mktemp -t overlay-partial.XXXXXX)"
trap 'rm -f "$OUT" "$OUT2"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s\n     expected: %s\n     got:      %s\n' "$1" "$2" "$3"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }

run() { jq --arg now "2026-06-04T12:00:00Z" --slurpfile sub "$SUB" -f "$JQF" "$1"; }

echo "drift-overlay-shape eval — drift-overlay-transform.jq"

if ! run "$HERE/fixtures/reconcile.json" > "$OUT" 2>"$OUT.err"; then
  echo "  ✗ transform did not run cleanly:"; cat "$OUT.err"; rm -f "$OUT.err"; exit 1
fi
rm -f "$OUT.err"

# --- the 5 states (design §4.1) ---
eq "summary carried verbatim from reconcile" "DRIFT" "$(jq -r '.summary' "$OUT")"
eq "driftCount carried"                  "1" "$(jq '.driftCount' "$OUT")"
eq "driftNodeIds = the drift verdict node" "workflow:repo:wf-gmail" "$(jq -r '.driftNodeIds|join(",")' "$OUT")"
eq "blastRadius = depended_on_by walk"   "workflow_node:wf-gmail:node1" "$(jq -r '.blastRadiusNodeIds|join(",")' "$OUT")"
eq "blastRadiusPartial true (rank partial)" "true" "$(jq '.blastRadiusPartial' "$OUT")"
eq "blindSpot = unverifiable_dimension node" "edge_function:notify" "$(jq -r '.blindSpotNodeIds|join(",")' "$OUT")"
eq "unverifiable = spot + inconclusive nodes" "config:vercel.json,function:public.fn_old" "$(jq -r '.unverifiableNodeIds|sort|join(",")' "$OUT")"

# --- precedence: red > orange > amber > grey (the drift node ALSO appears in an inconclusive
#     invariant's affected_nodes; it MUST stay red, never grey) ---
eq "precedence: drift node NOT in unverifiable" "false" "$(jq '.unverifiableNodeIds|index("workflow:repo:wf-gmail")!=null' "$OUT")"
eq "precedence: each node in <= 1 set"   "true" \
  "$(jq '([.driftNodeIds,.blastRadiusNodeIds,.blindSpotNodeIds,.unverifiableNodeIds]|add) as $all | ($all|length)==($all|unique|length)' "$OUT")"

# --- actions: the "decide the next move" payload ---
eq "drift node carries a named_action"   "reconcile" "$(jq -r '.actions["workflow:repo:wf-gmail"].named_action' "$OUT")"
eq "action carries source provenance"    "references/invariants/repo-vs-cloud-n8n-structural.json@fff601" \
  "$(jq -r '.actions["workflow:repo:wf-gmail"].provenance' "$OUT")"

# --- the negative vacuous-green-light test: no drift, but an inconclusive present -> NOT IN_SYNC,
#     and the inconclusive node renders grey, never absent/green (Doctrine 06 §8.4) ---
if ! run "$HERE/fixtures/reconcile-partial.json" > "$OUT2" 2>"$OUT2.err"; then
  echo "  ✗ partial-fixture transform did not run:"; cat "$OUT2.err"; rm -f "$OUT2.err"; exit 1
fi
rm -f "$OUT2.err"
eq "vacuous-green: summary is NOT IN_SYNC" "PARTIAL" "$(jq -r '.summary' "$OUT2")"
eq "vacuous-green: no drift in the partial fixture" "0" "$(jq '.driftNodeIds|length' "$OUT2")"
eq "vacuous-green: the inconclusive node is grey, not absent" "workflow:repo:wf-gmail" \
  "$(jq -r '.unverifiableNodeIds|join(",")' "$OUT2")"

echo "drift-overlay-shape: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
