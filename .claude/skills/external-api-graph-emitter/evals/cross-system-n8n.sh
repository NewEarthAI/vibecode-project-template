#!/usr/bin/env bash
# external-api-graph-emitter/evals/cross-system-n8n.sh — Phase 1b.
#
# Verifies the n8n HTTP-request-node parser (transform.jq) against the council resolutions
# (2026-06-05): URL classification (Supabase REST read/write, function invoke, external API, blind-spot
# for runtime/expression URLs), R2 routing (unresolved Supabase target -> blind-spot UNLESS coverage
# == covered, then a counted drop; coverage absent -> blind-spot — the fail-safe), R9 normalisation,
# and an end-to-end emit + R8 byte-untouched resolution read.
#
# Portability: macOS bash 3.2 + jq 1.7. set -uo pipefail. Exit 0 = all pass; 1 = a FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRANSFORM_JQ="$SCRIPT_DIR/../scripts/transform.jq"
EMIT_SH="$SCRIPT_DIR/../scripts/emit.sh"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
for f in "$TRANSFORM_JQ" "$EMIT_SH" "$SUBSTRATE_SH"; do [ -f "$f" ] || { echo "FAIL: missing $f" >&2; exit 1; }; done
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not found" >&2; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1" >&2; }
eq()  { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got '$2' want '$3'"; fi; }

SCRATCH="$(mktemp -d -t ext-api-eval-XXXXXX)"; trap 'rm -rf "$SCRATCH"' EXIT
NOW="2026-06-05T00:00:00Z"

cat > "$SCRATCH/wfs.json" <<'JSON'
[ { "id": "WF1", "nodes": [
    { "id": "n1", "name": "Get Deals",   "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "https://abcd.supabase.co/rest/v1/deals?select=*", "method": "GET" } },
    { "id": "n2", "name": "Insert Lead", "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "https://abcd.supabase.co/rest/v1/public.leads", "method": "POST" } },
    { "id": "n3", "name": "Call Enrich", "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "https://abcd.supabase.co/functions/v1/enrich", "method": "POST" } },
    { "id": "n4", "name": "Stripe",      "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "https://api.stripe.com/v1/charges", "method": "POST" } },
    { "id": "n5", "name": "Dynamic",     "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "={{ $json.webhook_url }}", "method": "POST" } },
    { "id": "n6", "name": "Ghost",       "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "https://abcd.supabase.co/rest/v1/ghost", "method": "GET" } },
    { "id": "n7", "name": "Sticky",      "type": "n8n-nodes-base.stickyNote",  "parameters": {} },
    { "id": "n8", "name": "Unparseable", "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "localhost:3000/internal-hook", "method": "POST" } },
    { "id": "n9", "name": "BasicAuth",   "type": "n8n-nodes-base.httpRequest", "parameters": { "url": "https://user:pass@api.internal/v1/sync", "method": "POST" } }
  ] } ]
JSON

xs() {  # xs <substrate_ids> <coverage>
  jq -n --slurpfile workflows "$SCRATCH/wfs.json" --arg now "$NOW" --arg src_commit "live:test:WF1" \
    --argjson substrate_ids "$1" --arg supabase_coverage "$2" -f "$TRANSFORM_JQ"
}
SUBIDS='["public.deals","public.leads","repo:supabase/functions/enrich"]'

echo "Part 1 — classification + routing (covered):"
COV="$(xs "$SUBIDS" covered)"
eq "A1 stickyNote ignored (8 http nodes, not 9)" "$(echo "$COV" | jq '.diagnostics.http_nodes_seen')" "8"
eq "A2 reads_from public.deals declared-MEDIUM (REST table ref)"  "$(echo "$COV" | jq '[.edges[]|select(.target=="public.deals" and .type=="reads_from" and .attributes.confidence=="declared-medium")]|length')" "1"
eq "A3 writes_to public.leads declared-medium (POST -> write)" "$(echo "$COV" | jq '[.edges[]|select(.target=="public.leads" and .type=="writes_to" and .attributes.confidence=="declared-medium")]|length')" "1"
eq "A4 R9 no public.public.leads double-prefix" "$(echo "$COV" | jq '[.edges[]|select(.target=="public.public.leads")]|length')" "0"
eq "A5 invokes enrich edge fn declared-HIGH"    "$(echo "$COV" | jq '[.edges[]|select(.target=="repo:supabase/functions/enrich" and .type=="invokes" and .attributes.confidence=="declared-high")]|length')" "1"
eq "A6 external-api endpoint node (stripe)"     "$(echo "$COV" | jq '[.nodes[]|select(.attributes.classification=="external-api" and .attributes.url_host=="api.stripe.com")]|length')" "1"
eq "A7 external-api edge type==calls"           "$(echo "$COV" | jq '[.edges[]|select(.target=="ext:external-api:api.stripe.com/v1/charges" and .type=="calls")]|length')" "1"
eq "A8 dynamic URL -> blind-spot node, type calls" "$(echo "$COV" | jq '[.edges[]|select(.target=="ext:blind-spot:n8n:WF1:n5" and .type=="calls" and .attributes.confidence=="blind-spot")]|length')" "1"
eq "A9 covered: ghost (unresolved) -> COUNTED DROP" "$(echo "$COV" | jq '.diagnostics.cross_system_counted_drops')" "1"
eq "A10 every external_endpoint node emitter==external_api_parser" "$(echo "$COV" | jq '[.nodes[]|select(.emitter!="external_api_parser")]|length')" "0"
# code-council 2026-06-05 fixes:
eq "A11 ACCOUNTING: every http node accounted (no silent vanish)" "$(echo "$COV" | jq '.diagnostics.accounted == .diagnostics.http_nodes_seen')" "true"
eq "A12 unparseable URL (localhost:3000) -> blind-spot, NOT vanished" "$(echo "$COV" | jq '[.nodes[]|select(.id=="ext:blind-spot:n8n:WF1:n8" and .attributes.classification=="blind-spot")]|length')" "1"
eq "A13 userinfo stripped: host==api.internal (no user:pass leak in node id)" "$(echo "$COV" | jq -r '[.nodes[]|select(.attributes.classification=="external-api" and .attributes.url_host=="api.internal")]|length')" "1"
eq "A14 NO credential leak: no node id contains 'user:pass'" "$(echo "$COV" | jq '[.nodes[]|select(.id|test("user:pass"))]|length')" "0"

echo "Part 2 — R2 fail-safe (declared-missing + coverage-absent):"
MISS="$(xs "$SUBIDS" declared-missing)"
eq "B1 declared-missing: ghost -> blind-spot, 0 drops" "$(echo "$MISS" | jq '.diagnostics.cross_system_counted_drops')" "0"
eq "B2 declared-missing: 3 blind-spots (dynamic + ghost + unparseable)" "$(echo "$MISS" | jq '.diagnostics.cross_system_blind_spots')" "3"
eq "B3 unresolved ghost blind-spot id present" "$(echo "$MISS" | jq '[.nodes[]|select(.id=="ext:blind-spot:public.ghost")]|length')" "1"
ABSENT="$(xs "$SUBIDS" "")"
eq "B4 coverage-absent: 0 drops (no silent drop)" "$(echo "$ABSENT" | jq '.diagnostics.cross_system_counted_drops')" "0"

echo "Part 3 — end-to-end + byte-untouched (R8):"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
bash "$SUBSTRATE_SH" init "fixture-entity" >/dev/null 2>&1
# Seed the source workflow_nodes (n8n-cloud convention) + the Supabase targets so edges can write.
bash "$SUBSTRATE_SH" bulk-write "$(jq -n --arg now "$NOW" '
  [ "n1","n2","n3","n4","n5","n6","n8","n9" ]
  | map({ id: ("cloud:WF1:" + .), kind:"workflow_node", source_file:"wf.json", source_commit:"c",
          timestamp:$now, source_line:1, emitter:"n8n_parser", attributes:{} })
  + [ {id:"public.deals",kind:"table",source_file:"m.sql",source_commit:"c",timestamp:$now,source_line:1,emitter:"pg_depend",attributes:{}},
      {id:"public.leads",kind:"table",source_file:"m.sql",source_commit:"c",timestamp:$now,source_line:1,emitter:"pg_depend",attributes:{}},
      {id:"repo:supabase/functions/enrich",kind:"edge_function",source_file:"supabase/functions/enrich/index.ts",source_commit:"c",timestamp:$now,source_line:1,emitter:"dependency_cruiser",attributes:{}} ]')" '[]' >/dev/null 2>&1
bash "$SUBSTRATE_SH" mark-emitter-ran supabase-live covered >/dev/null 2>&1
bash "$SUBSTRATE_SH" mark-emitter-ran n8n-cloud covered >/dev/null 2>&1

HASH_BEFORE="$(shasum -a 256 "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
LIVE_IDS="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[].id]' 2>/dev/null)"
LIVE_COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters["supabase-live"].coverage' 2>/dev/null | tr -d '"')"
HASH_AFTER="$(shasum -a 256 "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
eq "C1 R8 substrate byte-untouched by resolution read" "$HASH_BEFORE" "$HASH_AFTER"

FULL="$(xs "$LIVE_IDS" "$LIVE_COV")"
echo "$FULL" | jq '.nodes' > "$SCRATCH/nodes.json"
echo "$FULL" | jq '.edges' > "$SCRATCH/edges.json"
EMIT_RC=0; bash "$EMIT_SH" "$SCRATCH/nodes.json" "$SCRATCH/edges.json" "fixture-entity" >/dev/null 2>&1 || EMIT_RC=$?
eq "C2 emit.sh rc==0" "$EMIT_RC" "0"
LANDED_HI="$(bash "$SUBSTRATE_SH" read-topology '[.edges[]|select(.attributes.confidence=="declared-high")]|length' 2>/dev/null)"
eq "C3 declared-high edges landed (enrich invoke + stripe + api.internal = 3)" "$LANDED_HI" "3"
LANDED_MED="$(bash "$SUBSTRATE_SH" read-topology '[.edges[]|select(.attributes.confidence=="declared-medium")]|length' 2>/dev/null)"
eq "C3b declared-medium REST edges landed (deals + leads = 2)" "$LANDED_MED" "2"
EXTNODE="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[]|select(.kind=="external_endpoint")]|length' 2>/dev/null)"
eq "C4 external_endpoint nodes landed (stripe + api.internal + dynamic + unparseable = 4)" "$EXTNODE" "4"
VAL="$(bash "$SUBSTRATE_SH" validate-schema 2>&1 | tail -1)"
eq "C5 validate-schema PASS after external-api write" "$VAL" "PASS"

echo "Part 4 — dedicated Supabase node (n8n-nodes-base.supabase) — follow-up #4:"
# Isolated fixture (its own workflow) so Part-1/2/3 diagnostics are untouched. Covers: literal tableId
# (string + resourceLocator) resolution, operation->read/write, expression tableId -> blind-spot, an
# unresolved table (R2 routing), the supabaseTrigger exclusion, the kind-aware derivation, and the
# extended accounting invariant (accounted == http + supabase source nodes).
cat > "$SCRATCH/wfs-sb.json" <<'JSON'
[ { "id": "WFSB", "nodes": [
    { "id": "s1", "name": "Get Deal",    "type": "n8n-nodes-base.supabase", "parameters": { "operation": "get",    "tableId": "deals" } },
    { "id": "s2", "name": "Add Lead",    "type": "n8n-nodes-base.supabase", "parameters": { "operation": "create", "tableId": "leads" } },
    { "id": "s3", "name": "List Deals",  "type": "n8n-nodes-base.supabase", "parameters": { "operation": "getAll", "tableId": { "__rl": true, "value": "deals", "mode": "list" } } },
    { "id": "s4", "name": "Dyn Table",   "type": "n8n-nodes-base.supabase", "parameters": { "operation": "update", "tableId": "={{ $json.table }}" } },
    { "id": "s5", "name": "Ghost Row",   "type": "n8n-nodes-base.supabase", "parameters": { "operation": "get",    "tableId": "ghost" } },
    { "id": "s6", "name": "Dyn Read",    "type": "n8n-nodes-base.supabase", "parameters": { "operation": "get",    "tableId": "={{ $json.t }}" } },
    { "id": "st", "name": "Realtime",    "type": "n8n-nodes-base.supabaseTrigger", "parameters": { "tableId": "deals" } }
  ] } ]
JSON
xssb() {  # xssb <substrate_ids> <coverage>
  jq -n --slurpfile workflows "$SCRATCH/wfs-sb.json" --arg now "$NOW" --arg src_commit "live:test:WFSB" \
    --argjson substrate_ids "$1" --arg supabase_coverage "$2" -f "$TRANSFORM_JQ"
}
SBCOV="$(xssb "$SUBIDS" covered)"
eq "D1 supabase_nodes_seen==6 (trigger excluded)"  "$(echo "$SBCOV" | jq '.diagnostics.supabase_nodes_seen')" "6"
eq "D2 reads_from public.deals declared-medium ==2 (string s1 + resourceLocator s3 both resolve)" \
   "$(echo "$SBCOV" | jq '[.edges[]|select(.target=="public.deals" and .type=="reads_from" and .attributes.confidence=="declared-medium")]|length')" "2"
eq "D3 writes_to public.leads declared-medium ==1 (create s2)" \
   "$(echo "$SBCOV" | jq '[.edges[]|select(.target=="public.leads" and .type=="writes_to" and .attributes.confidence=="declared-medium")]|length')" "1"
eq "D4 expression tableId WRITE (s4) -> blind-spot node, confidence blind-spot" \
   "$(echo "$SBCOV" | jq '[.edges[]|select(.target=="ext:blind-spot:n8n:WFSB:s4" and .attributes.confidence=="blind-spot")]|length')" "1"
eq "D5 supabaseTrigger (st) never a source (excluded)" \
   "$(echo "$SBCOV" | jq '[.edges[]|select(.source=="cloud:WFSB:st")]|length')" "0"
eq "D6 covered: unresolved ghost (s5) -> COUNTED DROP ==1" \
   "$(echo "$SBCOV" | jq '.diagnostics.cross_system_counted_drops')" "1"
eq "D7 kind-aware derivation says 'n8n Supabase node' (not httpRequest)" \
   "$(echo "$SBCOV" | jq '[.edges[]|select(.source=="cloud:WFSB:s1")|select(.attributes.derivation|test("n8n Supabase node"))]|length')" "1"
eq "D8 ACCOUNTING: accounted == total_source_nodes_seen (http 0 + supabase 6)" \
   "$(echo "$SBCOV" | jq '.diagnostics.accounted == .diagnostics.total_source_nodes_seen')" "true"
eq "D9 every external_endpoint node still emitter==external_api_parser" \
   "$(echo "$SBCOV" | jq '[.nodes[]|select(.kind=="external_endpoint" and .emitter!="external_api_parser")]|length')" "0"
# D11 — false-green lock (code-council 2026-06-06 IMPORTANT). The fixture deliberately has a READ-op dynamic
# tableId (s6) as well as a WRITE-op one (s4): a regression that resolved a read-op dynamic tableId to a
# confident green edge would pass D4 (which only checks s4). D11/D11b lock the read path; D11c is the
# universal sweep (the analogue of fetch-external's B14/B15) — NO blind-spot-target edge may carry a
# non-blind-spot confidence, on EITHER node family.
eq "D11 read-op dynamic tableId (s6) -> blind-spot edge (read-dynamic path exercised)" \
   "$(echo "$SBCOV" | jq '[.edges[]|select(.source=="cloud:WFSB:s6" and .attributes.confidence=="blind-spot")]|length')" "1"
eq "D11b CRITICAL: read-op dynamic (s6) has ZERO non-blind-spot edges (never resolves to a real table)" \
   "$(echo "$SBCOV" | jq '[.edges[]|select(.source=="cloud:WFSB:s6" and .attributes.confidence!="blind-spot")]|length')" "0"
eq "D11c CRITICAL: every blind-spot-target edge is blind-spot confidence (never green)" \
   "$(echo "$SBCOV" | jq -r '[.edges[]|select(.target|startswith("ext:blind-spot:"))|.attributes.confidence]|unique|join(",")')" "blind-spot"
SBMISS="$(xssb "$SUBIDS" declared-missing)"
eq "D10 declared-missing fail-safe: ghost+2 expr -> 3 blind-spots, 0 drops" \
   "$(echo "$SBMISS" | jq '[.diagnostics.cross_system_blind_spots, .diagnostics.cross_system_counted_drops]|@csv')" '"3,0"'
# (declared-missing: s4 expr-write + s5 ghost + s6 expr-read = 3 blind-spots, 0 drops)

echo "-------------------------------------------"
echo "cross-system-n8n.sh: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
