#!/usr/bin/env bash
# Eval: the Phase-2 cross-system render layer.
# graph-transform.jq + drift-overlay-transform.jq over the cross-system fixture pair.
# Asserts council 2026-06-06 amendments A1/A2/A5/A8/A10/A11 + R5 (blast-absent) + R8 (byte-untouched).
# bash 3.2 + jq target. No apostrophes inside single-quoted jq programs (shell-portability rule 7).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
SUB="$HERE/fixtures/substrate-cross-system.json"
REC="$HERE/fixtures/reconcile-cross-system.json"
GJQ="$SKILL/scripts/graph-transform.jq"
OJQ="$SKILL/scripts/drift-overlay-transform.jq"
G="$(mktemp -t xs-graph.XXXXXX)"
O="$(mktemp -t xs-overlay.XXXXXX)"
trap 'rm -f "$G" "$O" "$G.err" "$O.err"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s\n     expected: %s\n     got:      %s\n' "$1" "$2" "$3"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }

md5_of() { if command -v md5 >/dev/null 2>&1; then md5 -q "$1"; else md5sum "$1" | awk '{print $1}'; fi; }

echo "cross-system-render eval — graph-transform.jq + drift-overlay-transform.jq"

# R8 (A10/A12): capture fixture checksum BEFORE the read path runs
SUM_BEFORE="$(md5_of "$SUB")"

if ! jq --arg now "2026-06-06T12:00:00Z" -f "$GJQ" "$SUB" > "$G" 2>"$G.err"; then
  echo "  ✗ graph-transform did not run cleanly:"; cat "$G.err"; exit 1
fi
if ! jq --arg now "2026-06-06T12:00:00Z" --slurpfile sub "$SUB" -f "$OJQ" "$REC" > "$O" 2>"$O.err"; then
  echo "  ✗ drift-overlay-transform did not run cleanly:"; cat "$O.err"; exit 1
fi

# ---- envelope ----
eq "schema_version visual-v1"            "visual-v1"      "$(jq -r '.schema_version' "$G")"
eq "entity carried verbatim"             "demo-xsystem"   "$(jq -r '.entity' "$G")"
eq "all 19 nodes present"                "19"             "$(jq '.nodes|length' "$G")"
eq "19 edges, none dropped (never-drop)" "19"             "$(jq '.edges|length' "$G")"
eq "15 cross-system edges"               "15"             "$(jq '[.edges[]|select(.cross_system)]|length' "$G")"
eq "4 within-system edges"               "4"              "$(jq '[.edges[]|select(.cross_system|not)]|length' "$G")"

# ---- A1: has_blind_spot_edges chip signal ----
eq "A1 has_blind_spot_edges true"        "true"           "$(jq '.has_blind_spot_edges' "$G")"

# ---- external_endpoint render mapping (A8) ----
eq "external_endpoint -> external/external" "external external" \
   "$(jq -r '.nodes[]|select(.id=="external_endpoint:external-api:api.stripe.com/v1/charges")|"\(.render_kind) \(.category)"' "$G")"
eq "A8 layer:external name = External APIs" "External APIs"  "$(jq -r '.layers[]|select(.id=="layer:external")|.name' "$G")"
eq "5 layers derived"                    "5"              "$(jq '.layers|length' "$G")"
eq "external layer holds 5 endpoints"    "5"              "$(jq '.layers[]|select(.id=="layer:external")|.nodeIds|length' "$G")"
eq "2 blind-spot classification nodes"   "2"              "$(jq '[.nodes[]|select(.attributes.classification=="blind-spot")]|length' "$G")"

# ---- A2 KEYSTONE: unknown-confidence cross-system edge forced to blind-spot (never green) ----
eq "A2 Reports->deals (attrs null) cross_system" "true" \
   "$(jq -r '.edges[]|select(.source=="ts_module:src/pages/Reports.tsx" and .target=="table:public.deals")|.cross_system' "$G")"
eq "A2 Reports->deals confidence forced blind-spot" "blind-spot" \
   "$(jq -r '.edges[]|select(.source=="ts_module:src/pages/Reports.tsx" and .target=="table:public.deals")|.confidence' "$G")"
eq "A2 NO cross-system edge has null confidence" "0" \
   "$(jq '[.edges[]|select(.cross_system and .confidence==null)]|length' "$G")"

# ---- A11: confidence carried VERBATIM per edge (not just presence) ----
eq "declared-high invoke (Deals->notify)" "declared-high" \
   "$(jq -r '.edges[]|select(.source=="ts_module:src/pages/Deals.tsx" and .target=="edge_function:notify")|.confidence' "$G")"
eq "declared-medium read (Deals->deals reads_from)" "declared-medium" \
   "$(jq -r '.edges[]|select(.source=="ts_module:src/pages/Deals.tsx" and .target=="table:public.deals" and .type=="reads_from")|.confidence' "$G")"
eq "blind-spot edge (Settings->dynamic-1)" "blind-spot" \
   "$(jq -r '.edges[]|select(.target=="external_endpoint:blind-spot:dynamic-1")|.confidence' "$G")"
eq "cross-system edge carries derivation attribute" "supabase.functions.invoke('notify')" \
   "$(jq -r '.edges[]|select(.source=="ts_module:src/pages/Deals.tsx" and .target=="edge_function:notify")|.attributes.derivation' "$G")"

# ---- within-system edges carry NULL attributes (never {} — the truthy-guard trap) ----
eq "within-system edge attributes is null" "null" \
   "$(jq -c '.edges[]|select(.source=="view:public.v_deals" and .target=="table:public.deals")|.attributes' "$G")"
eq "within-system edge confidence null"   "null" \
   "$(jq -r '.edges[]|select(.source=="view:public.v_deals" and .target=="table:public.deals")|.confidence' "$G")"
eq "NO within-system edge has empty-object attributes" "0" \
   "$(jq '[.edges[]|select((.cross_system|not) and .attributes=={})]|length' "$G")"

# ---- A5 / Edge-case #3: external->external edge IS cross-system ----
eq "A5 ext->ext edge cross_system true"  "true" \
   "$(jq -r '.edges[]|select(.source=="external_endpoint:external-api:api.stripe.com/v1/charges" and .target=="external_endpoint:external-api:api.openai.com/v1/chat")|.cross_system' "$G")"

# ---- kind-guard (code-council R1): a CONFIDENCE-LESS external->external edge is still cross-system
#      (via the endpoint-kind test) AND forced to blind-spot (A2) — never a silent within-system grey line ----
eq "kind-guard: confidence-less ext->ext cross_system" "true" \
   "$(jq -r '.edges[]|select(.source=="external_endpoint:external-api:api.openai.com/v1/chat" and .target=="external_endpoint:supabase-rest:unresolved-table")|.cross_system' "$G")"
eq "kind-guard: confidence-less ext->ext forced blind-spot" "blind-spot" \
   "$(jq -r '.edges[]|select(.source=="external_endpoint:external-api:api.openai.com/v1/chat" and .target=="external_endpoint:supabase-rest:unresolved-table")|.confidence' "$G")"

# ---- A7 parallel pair, DIFFERENT confidence (the amber-hidden-behind-solid scenario inputs) ----
eq "A7 parallel pair Home->openai has 2 edges" "2" \
   "$(jq '[.edges[]|select(.source=="ts_module:src/pages/Home.tsx" and .target=="external_endpoint:external-api:api.openai.com/v1/chat")]|length' "$G")"
eq "A7 parallel pair confidences differ" "blind-spot declared-high" \
   "$(jq -r '[.edges[]|select(.source=="ts_module:src/pages/Home.tsx" and .target=="external_endpoint:external-api:api.openai.com/v1/chat")|.confidence]|sort|join(" ")' "$G")"

# ---- A10: unknown edge type survives + is cross-system (degrade, never drop) ----
eq "A10 unknown type subscribes_to present" "subscribes_to" \
   "$(jq -r '.edges[]|select(.type=="subscribes_to")|.type' "$G")"
eq "A10 unknown type edge is cross_system" "true" \
   "$(jq -r '.edges[]|select(.type=="subscribes_to")|.cross_system' "$G")"

# ---- every confidence class is exercised by the fixture (A11 coverage) ----
eq "fixture exercises declared-high"     "true" "$(jq '[.edges[].confidence]|any(.=="declared-high")' "$G")"
eq "fixture exercises declared-medium"   "true" "$(jq '[.edges[].confidence]|any(.=="declared-medium")' "$G")"
eq "fixture exercises blind-spot"        "true" "$(jq '[.edges[].confidence]|any(.=="blind-spot")' "$G")"
# ---- every cross-system edge type is exercised ----
eq "edge types: reads_from present"      "true" "$(jq '[.edges[]|select(.cross_system).type]|any(.=="reads_from")' "$G")"
eq "edge types: writes_to present"       "true" "$(jq '[.edges[]|select(.cross_system).type]|any(.=="writes_to")' "$G")"
eq "edge types: invokes present"         "true" "$(jq '[.edges[]|select(.cross_system).type]|any(.=="invokes")' "$G")"
eq "edge types: calls present"           "true" "$(jq '[.edges[]|select(.cross_system).type]|any(.=="calls")' "$G")"

# ---- coverage envelope (chip inputs) ----
eq "external-api-graph in missing_emitters" "true" \
   "$(jq '[.coverage.missing_emitters[].name]|any(.=="external-api-graph")' "$G")"
eq "n8n-cloud coverage declared-missing" "declared-missing" "$(jq -r '.coverage.emitters["n8n-cloud"]' "$G")"

# ---- idset integrity: all edge endpoints are present nodes ----
NODESET="$(jq -c '[.nodes[].id]' "$G")"
eq "all edge endpoints are present nodes" "0" \
  "$(jq --argjson ids "$NODESET" '[.edges[]|.source as $s|.target as $t|select(($ids|index($s))==null or ($ids|index($t))==null)]|length' "$G")"

# ---- R5: no external_endpoint id appears in any overlay drift/blast set ----
eq "R5 summary carried verbatim"         "DRIFT"          "$(jq -r '.summary' "$O")"
eq "R5 NO external id in drift/blast/blind/unverifiable sets" "0" \
  "$(jq '[(.driftNodeIds+.blastRadiusNodeIds+.blindSpotNodeIds+.unverifiableNodeIds)[]|select(startswith("external_endpoint:"))]|length' "$O")"

# ---- R8: fixture byte-untouched by the read path ----
SUM_AFTER="$(md5_of "$SUB")"
eq "R8 cross-system fixture byte-untouched" "$SUM_BEFORE" "$SUM_AFTER"

echo "cross-system-render: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
