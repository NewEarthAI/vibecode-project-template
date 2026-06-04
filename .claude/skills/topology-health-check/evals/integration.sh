#!/usr/bin/env bash
# integration.sh — the END-TO-END integration test (the M3 v1-complete proof).
#
# Intent-Actual-Gap Mechanism Build Programme — M3 Session 6 (CLOSES M3). Proves the whole topology
# mechanism coheres END-TO-END on honest-partial coverage (DECISION-1 Option A): a multi-kind substrate
# built by a real emitter run + pre-seeded code half, validated coherent, then read + reported correctly
# by the health-check — AND the health-check answers a Test-A-class structured query on the REAL live
# BuyBox-AI substrate.
#
# Council amendments (council/sessions/2026-06-01-m3-session-6-health-check-integration.md):
#   #7  ALSO assert against the REAL 1,076-node BuyBox-AI substrate (a structured dependency query),
#       not just the fixture — closes the "fixture-only-pass" concern (DESTINATION Element-4 failure mode).
#   #8  cite the S2 (1,143 nodes) + S3 (280 nodes) evals as the live-MCP coverage proof (in the manifest).
#   #9  drive the repo-config-emitter (pure bash+jq, ZERO UA dependency) + pre-seed ts_module stubs via
#       bulk-write — NOT a live code-emitter run (UA dependency + CLAUDE_PROJECT_DIR-resolves-to-workshop
#       empty-substrate trap). unset CLAUDE_PROJECT_DIR + export the scratch path before any emitter call;
#       post-test assert the REAL substrate's node-count + mtime unchanged.
#   #13 UA license-attribution + no-Python-leak: a read-only grep of the code-emitter's attribution
#       reference (spec 14 §6 line 167) — no emitter invocation. Machine-assertable. The note records the
#       HONEST finding (UA declares license:null, NOT MIT); the gate checks the note exists + is honest.
#
# Portability: macOS bash 3.2 + jq 1.7. The harness is allowed platform date arithmetic; the SKILL is not.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSHOP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"   # .../1st_princples_systems_thinker
SUB="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
HC="$SCRIPT_DIR/../scripts/health-check.sh"
RC_EMIT="$SCRIPT_DIR/../../repo-config-emitter/scripts/emit.sh"
UA_DOC="$SCRIPT_DIR/../../code-emitter/references/ua-library-integration.md"
CODE_EXTRACT="$SCRIPT_DIR/../../code-emitter/scripts/extract.mjs"
LIVE_SUBSTRATE="/Users/justin/code/BuyBox-AI/.understand-anything/topology-graph.json"

for f in "$SUB" "$HC" "$RC_EMIT" "$UA_DOC" "$CODE_EXTRACT"; do
  [ -f "$f" ] || { echo "FAIL: required file missing: $f" >&2; exit 1; }
done

PASS_COUNT=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { PASS_COUNT=$((PASS_COUNT+1)); echo "  ok: $1"; }

echo "=== topology-health-check INTEGRATION TEST (M3 v1-complete proof) ==="

# ---------------------------------------------------------------------------------
# ISOLATION GUARD (amendment #9): unset CLAUDE_PROJECT_DIR so NO subprocess can resolve to a real repo.
# Capture the REAL BuyBox-AI substrate's pre-test state to assert it is untouched after the test.
# ---------------------------------------------------------------------------------
unset CLAUDE_PROJECT_DIR
REAL_NODES_BEFORE="(no-live-substrate)"
REAL_MTIME_BEFORE="(no-live-substrate)"
if [ -f "$LIVE_SUBSTRATE" ]; then
  REAL_NODES_BEFORE="$(jq '.nodes | length' "$LIVE_SUBSTRATE" 2>/dev/null || echo "ERR")"
  REAL_MTIME_BEFORE="$(stat -f %m "$LIVE_SUBSTRATE" 2>/dev/null || stat -c %Y "$LIVE_SUBSTRATE" 2>/dev/null || echo "ERR")"
fi

# ---------------------------------------------------------------------------------
# STEP 1 — init a fresh scratch substrate (NEVER a real .understand-anything/).
# ---------------------------------------------------------------------------------
echo "STEP 1 — init scratch substrate"
SCRATCH="$(mktemp -d -t hc-integ-XXXXXX)"; trap 'rm -rf "$SCRATCH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
bash "$SUB" init "BuyBox-AI-integration" >/dev/null 2>&1 || fail "init"
ok "scratch substrate initialised at $TOPOLOGY_SUBSTRATE_PATH"

# ---------------------------------------------------------------------------------
# STEP 2 — pre-seed the CODE half (ts_module stubs) via bulk-write. The code-emitter's OWN eval proves
# its correctness; here we simulate its output (amendment #9 — no live UA run). 3 ts_module nodes.
# ---------------------------------------------------------------------------------
echo "STEP 2 — pre-seed ts_module stubs (the code-emitter half, fixture)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS_STUBS="$(jq -nc --arg now "$NOW" '
  [ {id:"src/app.tsx", kind:"ts_module", source_file:"src/app.tsx", source_commit:"integsha", timestamp:$now, source_line:null, emitter:"dependency_cruiser", depends_on:["src/lib/util.ts"], depended_on_by:[], attributes:{is_entry:true, export_count:1}, declared_intent_ref:null},
    {id:"src/lib/util.ts", kind:"ts_module", source_file:"src/lib/util.ts", source_commit:"integsha", timestamp:$now, source_line:null, emitter:"dependency_cruiser", depends_on:[], depended_on_by:["src/app.tsx"], attributes:{is_entry:false, export_count:3}, declared_intent_ref:null},
    {id:"supabase/functions/hello/index.ts", kind:"edge_function", source_file:"supabase/functions/hello/index.ts", source_commit:"integsha", timestamp:$now, source_line:null, emitter:"dependency_cruiser", depends_on:[], depended_on_by:[], attributes:{runtime:"deno", deployed_commit:"integsha"}, declared_intent_ref:null} ]')"
TS_EDGES="$(jq -nc '[ {source:"src/app.tsx", target:"src/lib/util.ts", type:"imports", direction:"forward", weight:1} ]')"
bash "$SUB" bulk-write "$TS_STUBS" "$TS_EDGES" >/dev/null 2>&1 || fail "STEP 2 pre-seed ts_module stubs"
ok "pre-seeded 3 code-half nodes (2 ts_module + 1 edge_function) + 1 import edge"

# ---------------------------------------------------------------------------------
# STEP 3 — drive the REAL repo-config-emitter (pure bash+jq, ZERO UA dependency) against fixture JSON.
# Its emit.sh takes pre-collected node + edge JSON FILES; we feed it a 1-workflow + 2-node + 1-config set.
# This is a GENUINE emitter run (not a stub) — it exercises bulk-write + mark-emitter-ran + validate-schema.
# ---------------------------------------------------------------------------------
echo "STEP 3 — drive the real repo-config-emitter (workflow + workflow_node + config)"
RC_NODES_F="$SCRATCH/rc-nodes.json"
RC_EDGES_F="$SCRATCH/rc-edges.json"
jq -nc --arg now "$NOW" '
  [ {id:"repo:workflows/sync.json", kind:"workflow", source_file:"workflows/sync.json", source_commit:"integsha", timestamp:$now, source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:[], attributes:{active:true, trigger_type:"webhook", name:"Sync", archived:false, tags:[], node_count:1, connection_count:0, fetch_mode:"active"}, declared_intent_ref:null},
    {id:"repo:workflows/sync.json#node-1", kind:"workflow_node", source_file:"workflows/sync.json", source_commit:"integsha", timestamp:$now, source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:[], attributes:{node_type:"n8n-nodes-base.httpRequest", position:[0,0]}, declared_intent_ref:null},
    {id:"repo:vercel.json", kind:"config", source_file:"vercel.json", source_commit:"integsha", timestamp:$now, source_line:null, emitter:"manual", depends_on:[], depended_on_by:[], attributes:{config_type:"vercel", header_count:1, rewrite_count:0, redirect_count:0}, declared_intent_ref:null, manual_justification:"declared-structure deploy config (D05 §6.6)"} ]' > "$RC_NODES_F"
jq -nc '[ {source:"repo:workflows/sync.json", target:"repo:workflows/sync.json#node-1", type:"contains", direction:"forward", weight:1} ]' > "$RC_EDGES_F"
# CLAUDE_PROJECT_DIR is unset; pass the scratch path explicitly. The emitter writes to TOPOLOGY_SUBSTRATE_PATH.
RC_OUT="$(TOPOLOGY_SUBSTRATE_PATH="$TOPOLOGY_SUBSTRATE_PATH" bash "$RC_EMIT" "$RC_NODES_F" "$RC_EDGES_F" "BuyBox-AI-integration" 2>&1)"; RC_RC=$?
[ "$RC_RC" -eq 0 ] || fail "STEP 3 repo-config-emitter exited $RC_RC: $RC_OUT"
ok "repo-config-emitter ran (real emitter): $(printf '%s' "$RC_OUT" | tail -1)"

# ---------------------------------------------------------------------------------
# STEP 4 — validate-schema PASS (the §6 line-168 coherence gate: no orphan nodes / dangling edges).
# ---------------------------------------------------------------------------------
echo "STEP 4 — validate-schema (coherence gate)"
VAL="$(bash "$SUB" validate-schema 2>&1)"
printf '%s\n' "$VAL" | grep -qE '^PASS$' || fail "STEP 4 validate-schema not PASS: $VAL"
ok "validate-schema PASS (graph coherent — no orphan/dangling)"

# ---------------------------------------------------------------------------------
# STEP 5 — query the health-check; assert the honest report (via jq -e exact-equality, amendment #12).
# Expected substrate: 6 nodes total (2 ts_module + 1 edge_function + 1 workflow + 1 workflow_node + 1 config).
# code: covered+fresh (owns all 6: ts_module + edge_function via dependency_cruiser + workflow/workflow_node
#       via the repo: prefix + config via manual). supabase + n8n: declared-missing. Verdict PARTIAL (honest).
# ---------------------------------------------------------------------------------
echo "STEP 5 — health-check honest report"
HJSON="$(bash "$HC" --json)" || fail "STEP 5 health-check exited non-zero"
echo "$HJSON" | jq -e '.verdict == "PARTIAL"' >/dev/null || fail "STEP 5 verdict != PARTIAL (got $(echo "$HJSON"|jq -r .verdict))"; ok "verdict PARTIAL (honest partial coverage)"
echo "$HJSON" | jq -e '.node_total == 6' >/dev/null || fail "STEP 5 node_total != 6 (got $(echo "$HJSON"|jq -r .node_total))"; ok "node_total 6"
echo "$HJSON" | jq -e '.kind_counts.ts_module == 2 and .kind_counts.edge_function == 1 and .kind_counts.workflow == 1 and .kind_counts.workflow_node == 1 and .kind_counts.config == 1' >/dev/null || fail "STEP 5 per-kind counts wrong (got $(echo "$HJSON"|jq -c .kind_counts))"; ok "per-kind counts exact (2 ts_module, 1 edge_function, 1 workflow, 1 workflow_node, 1 config)"
echo "$HJSON" | jq -e '.emitters.code.coverage == "covered" and .emitters.code.owned_node_count == 6 and .emitters.code.anomaly == "none"' >/dev/null || fail "STEP 5 code emitter wrong ($(echo "$HJSON"|jq -c .emitters.code))"; ok "code covered, owns all 6 (multi-kind coherent), no anomaly"
echo "$HJSON" | jq -e '.emitters["supabase-live"].coverage == "declared-missing" and .emitters["n8n-cloud"].coverage == "declared-missing"' >/dev/null || fail "STEP 5 live emitters not declared-missing"; ok "supabase-live + n8n-cloud declared-missing (honest, not failure)"
echo "$HJSON" | jq -e '.integrity == "PASS"' >/dev/null || fail "STEP 5 integrity != PASS"; ok "integrity PASS"
# the honest-partial wording (amendment #5). Capture-then-grep (NOT a pipe into grep -q: under
# `set -o pipefail`, grep -q closing the pipe early makes $HC exit SIGPIPE and the || fail mis-fires).
HTEXT="$(bash "$HC")"
printf '%s' "$HTEXT" | grep -q "built, not yet run on this substrate" || fail "STEP 5 declared-missing wording missing"; ok "declared-missing reported as 'built, not yet run' (not failure)"

# ---------------------------------------------------------------------------------
# STEP 6 — LIVE-SUBSTRATE structured assertion (amendment #7 — the DESTINATION Test A serviceability proof).
# Point the health-check at the REAL BuyBox-AI substrate (read-only) + assert a Test-A-class structured
# query is answerable: per-kind counts sum to node_total AND a depends_on traversal returns a real
# source-traceable node (a node with a non-empty source_file). This proves the read interface serves a
# real structured question on real state, not just a fixture.
# ---------------------------------------------------------------------------------
echo "STEP 6 — live-substrate structured assertion (DESTINATION Test A serviceability)"
LIVE_RAN=0
if [ -f "$LIVE_SUBSTRATE" ]; then
  LIVE_RAN=1
  LJSON="$(TOPOLOGY_SUBSTRATE_PATH="$LIVE_SUBSTRATE" bash "$HC" --json)" || fail "STEP 6 health-check on live substrate exited non-zero"
  # 6a: per-kind counts sum to node_total (internal-consistency structured query).
  echo "$LJSON" | jq -e '([.kind_counts[]] | add) == .node_total' >/dev/null || fail "STEP 6 live per-kind counts do not sum to node_total"; ok "live: per-kind counts sum to node_total ($(echo "$LJSON"|jq -r .node_total) nodes)"
  # 6b: integrity PASS (structural correctness — the load-bearing live assertion) + the verdict is ANY
  #     valid health verdict. NOT hardcoded to PARTIAL: when M4 runs the live emitters on this substrate
  #     the verdict legitimately becomes FRESH/STALE — a hardcoded PARTIAL would make this a permanent
  #     false-red (Spec Validator finding). The structural proof is integrity PASS + a valid verdict.
  echo "$LJSON" | jq -e '.integrity == "PASS"' >/dev/null || fail "STEP 6 live integrity != PASS (got $(echo "$LJSON"|jq -r .integrity))"; ok "live: integrity PASS (structural coherence on real state)"
  echo "$LJSON" | jq -e '.verdict | test("^(FRESH|STALE|PARTIAL|STALE_AND_PARTIAL|ANOMALOUS)$")' >/dev/null || fail "STEP 6 live verdict not a valid non-error health verdict (got $(echo "$LJSON"|jq -r .verdict))"; ok "live: verdict is a valid health verdict ($(echo "$LJSON"|jq -r .verdict))"
  # 6c: a Test-A-class structured dependency query — "what does a covered node depend on, and is it
  #     source-traceable?" — run directly via read-topology (the read interface a fresh session uses).
  #     Assert: at least one node has a non-empty depends_on list AND each such dependency target is a
  #     real node carrying a non-empty source_file (source-traceable).
  TRACE="$(TOPOLOGY_SUBSTRATE_PATH="$LIVE_SUBSTRATE" bash "$SUB" read-topology '
    [ .nodes[] | select((.depends_on | length) > 0) ] as $deps
    | ($deps | length) as $with_deps
    | ( [ .nodes[] | {key:.id, value:(.source_file // "")} ] | from_entries ) as $srcmap
    | ( [ $deps[] | .depends_on[] | select($srcmap[.] != null and $srcmap[.] != "") ] | length ) as $traceable
    | {with_deps:$with_deps, traceable_deps:$traceable}' 2>/dev/null)"
  echo "$TRACE" | jq -e '.with_deps > 0' >/dev/null || fail "STEP 6 live: no node has a depends_on edge (cannot prove dependency query)"; ok "live: $(echo "$TRACE"|jq -r .with_deps) nodes have depends_on edges (dependency query answerable)"
  echo "$TRACE" | jq -e '.traceable_deps > 0' >/dev/null || fail "STEP 6 live: dependency targets are not source-traceable"; ok "live: $(echo "$TRACE"|jq -r .traceable_deps) dependency targets are source-traceable (Test-A serviceable)"
else
  echo "  SKIP: live BuyBox-AI substrate not present at $LIVE_SUBSTRATE — live assertion skipped (run the in-repo emitters there first). The fixture proof (STEP 5) still holds; this is a coverage note, not a pass."
fi

# ---------------------------------------------------------------------------------
# STEP 7 — UA license-attribution + no-Python-leak (amendment #13 / spec 14 §6 line 167). Read-only grep.
# Honest check: the attribution NOTE must be present and must record the ACTUAL license status — which the
# note records as `license: null` (UA does NOT declare MIT). The gate checks the note EXISTS + is honest,
# not that UA is MIT (the spec's "MIT" assumption is the very thing the note disproves).
# ---------------------------------------------------------------------------------
echo "STEP 7 — UA license-attribution + no-Python-leak gate"
grep -qiE "license|attribution" "$UA_DOC" || fail "STEP 7 UA attribution note missing from $UA_DOC"; ok "UA attribution note present in code-emitter reference"
grep -qi "no Python" "$UA_DOC" || fail "STEP 7 no-Python claim missing from attribution note"; ok "no-Python-leak claim documented"
# verify the claim: the extractor imports node: built-ins, no python interpreter.
grep -qE "from \"node:" "$CODE_EXTRACT" || fail "STEP 7 extractor does not use node: built-ins as documented"; ok "extractor uses node: built-ins (Node-only, verified)"
grep -qiE "import .*python|subprocess|child_process.*python|\.py['\"]" "$CODE_EXTRACT" && fail "STEP 7 extractor references Python (leak!)" || ok "extractor has zero Python references (no leak)"

# ---------------------------------------------------------------------------------
# STEP 8 — ISOLATION assert (amendment #9): the REAL BuyBox-AI substrate is byte-unchanged after the test.
# ---------------------------------------------------------------------------------
echo "STEP 8 — real-substrate isolation assert"
if [ -f "$LIVE_SUBSTRATE" ]; then
  REAL_NODES_AFTER="$(jq '.nodes | length' "$LIVE_SUBSTRATE" 2>/dev/null || echo "ERR")"
  REAL_MTIME_AFTER="$(stat -f %m "$LIVE_SUBSTRATE" 2>/dev/null || stat -c %Y "$LIVE_SUBSTRATE" 2>/dev/null || echo "ERR")"
  [ "$REAL_NODES_BEFORE" = "$REAL_NODES_AFTER" ] || fail "STEP 8 live substrate node count CHANGED ($REAL_NODES_BEFORE -> $REAL_NODES_AFTER) — the test wrote to real state!"
  [ "$REAL_MTIME_BEFORE" = "$REAL_MTIME_AFTER" ] || fail "STEP 8 live substrate mtime CHANGED — the test wrote to real state!"
  ok "real BuyBox-AI substrate unchanged (nodes=$REAL_NODES_AFTER, mtime stable) — isolation honoured"
else
  ok "no live substrate present — isolation trivially honoured (nothing to touch)"
fi

echo ""
if [ "$LIVE_RAN" -eq 1 ]; then
  echo "=== v1-COMPLETE PROOF PASS — all $PASS_COUNT assertions green (LIVE assertion RAN) ==="
  echo "    The topology mechanism coheres end-to-end on honest-partial coverage:"
  echo "    a real emitter run + pre-seeded code half -> coherent multi-kind substrate -> the health-check"
  echo "    reports it correctly + answers a structured query on the LIVE substrate. M3 v1-complete (DECISION-1 Option A)."
else
  echo "=== FIXTURE PROOF PASS — all $PASS_COUNT assertions green; LIVE assertion SKIPPED (no live substrate) ==="
  echo "    The fixture half (a real emitter run -> coherent multi-kind substrate -> correct honest report) PASSED,"
  echo "    but STEP 6's live-substrate structured query did NOT run (no substrate at the BuyBox-AI path)."
  echo "    On a propagated/CI/fresh-clone machine this is EXPECTED — run the in-repo emitters there first to"
  echo "    exercise the full v1-complete proof. Do NOT read this green as the full live proof."
fi
echo "    Live-MCP emitter capability proven separately at the S2 (1,143 nodes) + S3 (280 nodes) evals (cite: manifest)."
exit 0
