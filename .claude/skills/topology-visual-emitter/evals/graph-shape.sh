#!/usr/bin/env bash
# Eval: graph-transform.jq over the golden substrate fixture.
# Asserts the references/graph-shape.md contract. bash 3.2 + jq target.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
FIX="$HERE/fixtures/substrate.json"
JQF="$SKILL/scripts/graph-transform.jq"
OUT="$(mktemp -t graph-out.XXXXXX)"
trap 'rm -f "$OUT"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ✗ %s\n     expected: %s\n     got:      %s\n' "$1" "$2" "$3"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }

echo "graph-shape eval — graph-transform.jq"

if ! jq --arg now "2026-06-04T12:00:00Z" -f "$JQF" "$FIX" > "$OUT" 2>"$OUT.err"; then
  echo "  ✗ transform did not run cleanly:"; cat "$OUT.err"; rm -f "$OUT.err"; exit 1
fi
rm -f "$OUT.err"

eq "schema_version is visual-v1"      "visual-v1" "$(jq -r '.schema_version' "$OUT")"
eq "entity carried verbatim"          "demo"      "$(jq -r '.entity' "$OUT")"
eq "generated_at set from --now"      "2026-06-04T12:00:00Z" "$(jq -r '.generated_at' "$OUT")"
eq "all 10 substrate nodes present"   "10"        "$(jq '.nodes|length' "$OUT")"
eq "4 edges (no danglers added)"      "4"         "$(jq '.edges|length' "$OUT")"

# render_kind / category mapping (design §3)
eq "rls_policy -> policy/data"        "policy data"    "$(jq -r '.nodes[]|select(.id=="rls_policy:deals_owner")|"\(.render_kind) \(.category)"' "$OUT")"
eq "workflow -> group/automation"     "group automation" "$(jq -r '.nodes[]|select(.id=="workflow:repo:wf-gmail")|"\(.render_kind) \(.category)"' "$OUT")"
eq "config -> config/config"          "config config"  "$(jq -r '.nodes[]|select(.id=="config:vercel.json")|"\(.render_kind) \(.category)"' "$OUT")"
eq "edge_function -> service/automation" "service automation" "$(jq -r '.nodes[]|select(.id=="edge_function:notify")|"\(.render_kind) \(.category)"' "$OUT")"

# layers: data(5) + a workflow group(2) + automation(1) + code(1) + config(1)
eq "5 layers derived"                 "5"         "$(jq '.layers|length' "$OUT")"
eq "Database layer holds 5 data nodes" "5"        "$(jq '.layers[]|select(.id=="layer:data")|.nodeIds|length' "$OUT")"
eq "workflow group holds 2 (wf+node)" "2"         "$(jq '[.layers[]|select(.id|startswith("layer:workflow:"))|.nodeIds|length]|add' "$OUT")"

# provenance present (NOT an LLM summary — the genuine delta over the competitor)
eq "node carries source provenance"   "supabase/migrations/0005_rls.sql@aaa115" "$(jq -r '.nodes[]|select(.id=="rls_policy:deals_owner")|.source' "$OUT")"
eq "no LLM summary field on nodes"    "0"         "$(jq '[.nodes[]|select(has("summary"))]|length' "$OUT")"

# coverage envelope: the blind-spot dimension is declared-missing (Doctrine 05 P6 honesty)
eq "n8n-cloud coverage declared-missing" "declared-missing" "$(jq -r '.coverage.emitters["n8n-cloud"]' "$OUT")"
eq "1 missing_emitter carried"        "1"         "$(jq '.coverage.missing_emitters|length' "$OUT")"

# parent_map/child_map carried verbatim (substrate-validated, never recomputed)
eq "parent_map carried verbatim"      "$(jq -cS '.parent_map' "$FIX")" "$(jq -cS '.parent_map' "$OUT")"
eq "child_map carried verbatim"       "$(jq -cS '.child_map'  "$FIX")" "$(jq -cS '.child_map'  "$OUT")"

# every edge endpoint is a present node (idset integrity — the danglers-dropped guarantee)
NODESET="$(jq -c '[.nodes[].id]' "$OUT")"
eq "all edge endpoints are present nodes" "0" \
  "$(jq --argjson ids "$NODESET" '[.edges[] | .source as $s | .target as $t | select(($ids|index($s))==null or ($ids|index($t))==null)] | length' "$OUT")"

echo "graph-shape: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
