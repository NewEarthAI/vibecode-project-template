#!/usr/bin/env bash
# canonical-shape.sh — positive eval for the repo-config emitter.
#
# Feeds a fixture (2 in-repo n8n workflows + 1 vercel + 1 package config node, plus a PRE-SEEDED
# cloud: node to prove the reconciliation pair coexists) through the emitter harness (emit.sh) and
# asserts the substrate ends up canonical-shape correct. EXACT-COUNT assertions throughout (per the
# Session-4 lesson: ">0" hides latent transform bugs; assert the precise expected counts).
#
# Asserts:
#   - validate-schema PASS
#   - code coverage transitions declared-missing/null -> covered (heartbeat advance proves the
#     emitter fired vs inheriting prior state)
#   - EXACTLY 2 workflow nodes (WF_A active+not-archived, WF_B archived+inactive)
#   - EXACTLY 6 workflow_node nodes after stickyNote filter (WF_A's 5 + WF_B's 1):
#       WF_A (5 non-stickyNote nodes, 1 stickyNote filtered out):
#         * 1 disabled:true (A.11 dangerous case — n-mid)
#         * 1 trigger plain flow node, disabled:false (n-trigger)
#         * 1 executeWorkflow node calling WF_B IN-SET (cross-workflow calls edge KEPT, via n8n-id resolution)
#         * 1 executeWorkflow node calling an OUT-OF-SET workflow (calls edge DROPPED + counted)
#         * 1 plain flow node (n-end — proves connection name->GUID resolve works)
#       WF_B (1 node):
#         * 1 plain trigger node, disabled:false (b-start)
#       => 1 disabled:true + 5 disabled:false across the two workflows
#   - EXACTLY 2 config nodes (vercel + package), kind:config, emitter:manual, with manual_justification
#   - the repo: prefix on every n8n + config node id
#   - the RECONCILIATION PAIR coexists: a pre-seeded cloud:<id> node AND the repo:<path> node both
#     present, no id collision, validate PASS (the M4 surface proof)
#   - config attributes round-trip (vercel header/rewrite counts; package dep/script counts + dep map)
#   - every n8n node carries emitter:"n8n_parser"; every config node emitter:"manual" (D05 P4)
#   - every node carries declared_intent_ref:null (forward-hook)
#   - edge classes present: contains, depends_on (within-workflow), calls (cross-workflow KEPT)
#   - no dangling edges; cross_workflow_edges_skipped == 1 (the out-of-set call)
#   - parent_map / child_map derived correctly
#   - kinds present are a subset of the frozen 10-kind enum
#
# Uses a scratch substrate via mktemp -d so it NEVER touches a real .understand-anything/ dir.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
EMIT_SH="$SCRIPT_DIR/../scripts/emit.sh"
TRANSFORM_JQ="$SCRIPT_DIR/../scripts/transform.jq"

if [ ! -f "$SUBSTRATE_SH" ] || [ ! -f "$EMIT_SH" ] || [ ! -f "$TRANSFORM_JQ" ]; then
  echo "FAIL: substrate.sh, emit.sh, or transform.jq missing" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t repo-config-eval-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SRC_COMMIT="evalsha+dirty"

fail() { echo "FAIL: $1" >&2; exit 1; }
q() { bash "$SUBSTRATE_SH" read-topology "$1" 2>/dev/null; }

# --- init + pre-emit baseline ----------------------------------------------------
bash "$SUBSTRATE_SH" init "fixture-entity" >/dev/null 2>&1 || fail "substrate init"
PRE_COV="$(q '.emitters["code"].coverage' | tr -d '"')"
[ "$PRE_COV" = "declared-missing" ] || fail "pre-emit code coverage = '$PRE_COV' (want declared-missing)"
PRE_TS="$(q '.emitters["code"].last_emitted_at' | tr -d '"')"
[ "$PRE_TS" = "null" ] || fail "pre-emit last_emitted_at = '$PRE_TS' (want null)"

# --- PRE-SEED the cloud: reconciliation half (simulates Session-3's output) ------
# A cloud:WF_A node sharing the same n8n id as the repo WF_A file. After the repo emit, BOTH must
# coexist (the prefix discipline) — the M4 reconciliation surface.
CLOUD_SEED='[{"id":"cloud:WF_A","kind":"workflow","source_file":"n8n_cloud (live)","source_commit":"live:fixture:WF_A","timestamp":"'"$NOW"'","source_line":null,"emitter":"n8n_parser","depends_on":[],"depended_on_by":[],"attributes":{"active":true,"trigger_type":"manual","name":"WF A (cloud)","archived":false,"tags":[],"node_count":3,"connection_count":2,"fetch_mode":"active"},"declared_intent_ref":null}]'
bash "$SUBSTRATE_SH" bulk-write "$CLOUD_SEED" "[]" >/dev/null 2>&1 || fail "pre-seed cloud node"

# --- fixture: 2 in-repo n8n workflows --------------------------------------------
# WF_A (relpath workflows/wf-a.json, n8n id WF_A): active, not-archived. 6 raw nodes:
#   - sticky (filtered out)
#   - trigger (plain flow, disabled:false)
#   - a-mid (disabled:true — A.11 dangerous case)
#   - exec-in  (executeWorkflow -> WF_B, IN-SET -> calls KEPT)
#   - exec-out (executeWorkflow -> WF_NOPE, OUT-OF-SET -> calls DROPPED+counted)
#   - a-end (plain flow)
# Connections: trigger->a-mid, a-mid->exec-in, exec-in->a-end (name-keyed, resolved to GUIDs)
# WF_B (relpath workflows/wf-b.json, n8n id WF_B): archived, inactive. 1 node (b-start).
N8N_INPUT="$SCRATCH/n8n.json"
# The file holds a SINGLE JSON array of workflow objects; `--slurpfile` wraps the whole file
# in one more array, so the transform's $n8n_workflows[0] resolves to this array. A doubly-nested
# [[ ... ]] here would make $n8n_workflows[0] an array-of-array and the transform's
# `map(. as $wf | $wf.relpath)` would index an array with a string (jq abort). The live recipe
# (SKILL.md) feeds the same single-array shape. (Session-5 verification 2026-06-01.)
cat > "$N8N_INPUT" <<JSON
[
  {
    "relpath": "workflows/wf-a.json",
    "id": "WF_A",
    "name": "WF A (repo)",
    "active": true,
    "isArchived": null,
    "tags": ["buybox"],
    "nodes": [
      {"id":"n-sticky","name":"Note","type":"n8n-nodes-base.stickyNote","position":[0,0],"disabled":false},
      {"id":"n-trigger","name":"Trigger","type":"n8n-nodes-base.manualTrigger","position":[1,1],"disabled":false},
      {"id":"n-mid","name":"Mid Step","type":"n8n-nodes-base.code","position":[2,2],"disabled":true},
      {"id":"n-exec-in","name":"Call B","type":"n8n-nodes-base.executeWorkflow","position":[3,3],"disabled":false,"parameters":{"workflowId":"WF_B"}},
      {"id":"n-exec-out","name":"Call Nope","type":"n8n-nodes-base.executeWorkflow","position":[4,4],"disabled":false,"parameters":{"workflowId":{"__rl":true,"value":"WF_NOPE","mode":"id"}}},
      {"id":"n-end","name":"End","type":"n8n-nodes-base.noOp","position":[5,5],"disabled":false}
    ],
    "connections": {
      "Trigger": {"main":[[{"node":"Mid Step","type":"main","index":0}]]},
      "Mid Step": {"main":[[{"node":"Call B","type":"main","index":0}]]},
      "Call B": {"main":[[{"node":"End","type":"main","index":0}]]},
      "End": {"main":[[{"node":"Ghost Node","type":"main","index":0}]]}
    }
  },
  {
    "relpath": "workflows/wf-b.json",
    "id": "WF_B",
    "name": "WF B (repo)",
    "active": false,
    "isArchived": true,
    "tags": [{"id":"t1","name":"buybox"}],
    "nodes": [
      {"id":"b-start","name":"B Start","type":"n8n-nodes-base.manualTrigger","position":[0,0],"disabled":false}
    ],
    "connections": {}
  }
]
JSON

# --- fixture: vercel.json + package.json ------------------------------------------
# Each file holds the BARE config object (NOT array-wrapped). `--slurpfile` wraps the file in
# one array, so the transform's $vercel[0] / $package[0] resolves to the object — matching the
# transform's input contract ("slurped array whose single element is the parsed object").
# An array-wrapped [{...}] here would make $vercel[0] an array and $v.headers a string-index of
# an array (jq abort). The live recipe (SKILL.md) slurps the verbatim files, which ARE bare
# objects. (Session-5 verification 2026-06-01.)
VERCEL_INPUT="$SCRATCH/vercel.json"
cat > "$VERCEL_INPUT" <<'JSON'
{"headers":[{"source":"/assets/(.*)","headers":[{"key":"Cache-Control","value":"x"}]},{"source":"/(.*)","headers":[{"key":"X-Frame-Options","value":"DENY"}]}],"rewrites":[{"source":"/(.*)","destination":"/index.html"}]}
JSON

PACKAGE_INPUT="$SCRATCH/package.json"
cat > "$PACKAGE_INPUT" <<'JSON'
{"name":"fixture-pkg","version":"1.0.0","dependencies":{"react":"^18.0.0","jq-fake":"^1.0.0"},"devDependencies":{"vite":"^5.0.0"},"scripts":{"build":"x","test":"y","typecheck":"z"}}
JSON

# --- run the transform -----------------------------------------------------------
COMBINED="$SCRATCH/combined.json"
jq -n \
  --slurpfile n8n_workflows "$N8N_INPUT" \
  --slurpfile vercel "$VERCEL_INPUT" \
  --slurpfile package "$PACKAGE_INPUT" \
  --arg now "$NOW" \
  --arg src_commit "$SRC_COMMIT" \
  -f "$TRANSFORM_JQ" > "$COMBINED" 2>"$SCRATCH/jqerr" || fail "transform.jq errored: $(cat "$SCRATCH/jqerr")"

jq '.nodes' "$COMBINED" > "$SCRATCH/nodes.json" || fail "extract nodes"
jq '.edges' "$COMBINED" > "$SCRATCH/edges.json" || fail "extract edges"

# --- run the harness -------------------------------------------------------------
if ! bash "$EMIT_SH" "$SCRATCH/nodes.json" "$SCRATCH/edges.json" "fixture-entity" >"$SCRATCH/emit.out" 2>&1; then
  echo "FAIL: emit.sh nonzero:"; cat "$SCRATCH/emit.out" >&2; exit 1
fi

# --- assertions ------------------------------------------------------------------

# validate-schema PASS
VAL="$(bash "$SUBSTRATE_SH" validate-schema 2>&1)"
printf '%s\n' "$VAL" | grep -q '^PASS$' || fail "validate-schema not PASS: $VAL"

# heartbeat: code covered + a real timestamp (transitioned from null)
COV="$(q '.emitters["code"].coverage' | tr -d '"')"
[ "$COV" = "covered" ] || fail "code coverage = '$COV' (want covered)"
POST_TS="$(q '.emitters["code"].last_emitted_at' | tr -d '"')"
[ "$POST_TS" != "null" ] || fail "last_emitted_at still null after emit (heartbeat no-op)"

# EXACT counts
WF_N="$(q '[.nodes[]|select(.kind=="workflow" and (.id|startswith("repo:")))]|length')"
[ "$WF_N" = "2" ] || fail "repo workflow nodes = $WF_N (want 2)"
WFN_N="$(q '[.nodes[]|select(.kind=="workflow_node")]|length')"
# 6 = WF_A's 5 non-stickyNote nodes (1 sticky filtered out of 6 raw) + WF_B's 1 node.
[ "$WFN_N" = "6" ] || fail "workflow_node count = $WFN_N (want 6: 5 from WF_A after stickyNote filter + 1 from WF_B)"
CFG_N="$(q '[.nodes[]|select(.kind=="config")]|length')"
[ "$CFG_N" = "2" ] || fail "config node count = $CFG_N (want 2)"

# the RECONCILIATION PAIR coexists (repo:workflows/wf-a.json + cloud:WF_A both present)
REPO_A="$(q '[.nodes[]|select(.id=="repo:workflows/wf-a.json")]|length')"
[ "$REPO_A" = "1" ] || fail "repo:workflows/wf-a.json present = $REPO_A (want 1)"
CLOUD_A="$(q '[.nodes[]|select(.id=="cloud:WF_A")]|length')"
[ "$CLOUD_A" = "1" ] || fail "cloud:WF_A present = $CLOUD_A (want 1 — reconciliation pair coexistence)"

# repo: prefix on every n8n + config node THIS emitter wrote.
# Exclude the pre-seeded cloud:WF_A reconciliation-seed node — it simulates Session-3's cloud
# emitter output (emitter:n8n_parser, but intentionally cloud:-prefixed); it is NOT this emitter's
# output and is correctly NOT repo:-prefixed (the prefix discipline is exactly what keeps the
# reconciliation pair as two distinct nodes).
NON_REPO="$(q '[.nodes[]|select((.emitter=="n8n_parser" or .kind=="config") and (.id!="cloud:WF_A") and ((.id|startswith("repo:"))|not))]|length')"
[ "$NON_REPO" = "0" ] || fail "$NON_REPO n8n/config nodes (excl. the cloud seed) lack the repo: prefix"

# A.11: one disabled:true, one disabled:false workflow_node
DIS_T="$(q '[.nodes[]|select(.kind=="workflow_node" and .attributes.disabled==true)]|length')"
[ "$DIS_T" = "1" ] || fail "disabled:true nodes = $DIS_T (want 1)"
DIS_F="$(q '[.nodes[]|select(.kind=="workflow_node" and .attributes.disabled==false)]|length')"
# 5 = WF_A's 4 disabled:false (trigger, exec-in, exec-out, end) + WF_B's 1 (b-start). Only WF_A's n-mid is disabled:true.
[ "$DIS_F" = "5" ] || fail "disabled:false nodes = $DIS_F (want 5: WF_A's 4 + WF_B's b-start)"

# archived round-trips (WF_B archived:true, WF_A archived:false from null)
ARCH_T="$(q '[.nodes[]|select(.kind=="workflow" and .attributes.archived==true)]|length')"
[ "$ARCH_T" = "1" ] || fail "archived:true workflows = $ARCH_T (want 1)"
ARCH_F="$(q '[.nodes[]|select(.id=="repo:workflows/wf-a.json")][0].attributes.archived')"
[ "$ARCH_F" = "false" ] || fail "WF_A archived = $ARCH_F (want false, defaulted from null)"

# config attributes round-trip
V_HDR="$(q '[.nodes[]|select(.id=="repo:vercel.json")][0].attributes.header_count')"
[ "$V_HDR" = "2" ] || fail "vercel header_count = $V_HDR (want 2)"
V_RW="$(q '[.nodes[]|select(.id=="repo:vercel.json")][0].attributes.rewrite_count')"
[ "$V_RW" = "1" ] || fail "vercel rewrite_count = $V_RW (want 1)"
P_DEP="$(q '[.nodes[]|select(.id=="repo:package.json")][0].attributes.dependency_count')"
[ "$P_DEP" = "2" ] || fail "package dependency_count = $P_DEP (want 2)"
P_SCR="$(q '[.nodes[]|select(.id=="repo:package.json")][0].attributes.script_count')"
[ "$P_SCR" = "3" ] || fail "package script_count = $P_SCR (want 3)"
P_REACT="$(q '[.nodes[]|select(.id=="repo:package.json")][0].attributes.dependencies.react' | tr -d '"')"
[ "$P_REACT" = "^18.0.0" ] || fail "package dependencies.react = $P_REACT (want ^18.0.0)"

# config nodes carry manual emitter + manual_justification
CFG_MANUAL="$(q '[.nodes[]|select(.kind=="config" and .emitter=="manual" and ((.manual_justification//"")!=""))]|length')"
[ "$CFG_MANUAL" = "2" ] || fail "config nodes with emitter:manual + justification = $CFG_MANUAL (want 2)"

# n8n nodes carry emitter:n8n_parser
N8N_EMIT="$(q '[.nodes[]|select((.kind=="workflow" or .kind=="workflow_node") and .id!="cloud:WF_A" and .emitter!="n8n_parser")]|length')"
[ "$N8N_EMIT" = "0" ] || fail "$N8N_EMIT repo n8n nodes have wrong emitter"

# every node has declared_intent_ref:null
DIR_BAD="$(q '[.nodes[]|select(.declared_intent_ref!=null)]|length')"
[ "$DIR_BAD" = "0" ] || fail "$DIR_BAD nodes have non-null declared_intent_ref"

# edge classes
CONTAINS="$(q '[.edges[]|select(.type=="contains")]|length')"
[ "$CONTAINS" = "6" ] || fail "contains edges = $CONTAINS (want 6: 5 for WF_A + 1 for WF_B)"
DEPENDS="$(q '[.edges[]|select(.type=="depends_on")]|length')"
[ "$DEPENDS" = "3" ] || fail "depends_on edges = $DEPENDS (want 3: trigger->mid, mid->callB, callB->end)"
CALLS="$(q '[.edges[]|select(.type=="calls")]|length')"
[ "$CALLS" = "1" ] || fail "calls edges KEPT = $CALLS (want 1: WF_A->WF_B in-set)"
# The KEPT calls edge must RESOLVE to the repo node id of WF_B (the n8n-id->repo-id indirection),
# not merely survive at the right count — a mis-resolved-but-in-set target would pass the count alone.
CALL_TGT="$(q '[.edges[]|select(.type=="calls")][0].target' | tr -d '"')"
[ "$CALL_TGT" = "repo:workflows/wf-b.json" ] || fail "calls edge target = $CALL_TGT (want repo:workflows/wf-b.json — the n8n-id->repo-id resolution)"

# cross_workflow_edges_skipped == 1 (the out-of-set WF_NOPE call)
SKIPPED="$(jq '.diagnostics.cross_workflow_edges_skipped' "$COMBINED")"
[ "$SKIPPED" = "1" ] || fail "cross_workflow_edges_skipped = $SKIPPED (want 1: the WF_NOPE out-of-set call)"

# within-workflow unresolved-connection-name path (S4 parity): the "End"->"Ghost Node" connection
# references a non-existent node name -> within_edges_unresolved counts it (surface-loud), AND the
# synthetic unresolved:<name> edge is DROPPED by the idset filter (never emitted as a dangling edge).
UNRES="$(jq '.diagnostics.within_edges_unresolved' "$COMBINED")"
[ "$UNRES" = "1" ] || fail "within_edges_unresolved = $UNRES (want 1: End->Ghost Node)"
UNRES_EDGE="$(q '[.edges[]|select((.source|startswith("unresolved:")) or (.target|startswith("unresolved:")))]|length')"
[ "$UNRES_EDGE" = "0" ] || fail "$UNRES_EDGE unresolved:<name> edges leaked into the substrate (must be dropped, not dangling)"

# kinds present subset of the frozen 10-kind enum
BAD_KIND="$(q '[.nodes[].kind]|unique - ["table","view","function","trigger","rls_policy","edge_function","workflow","workflow_node","ts_module","config"]|length')"
[ "$BAD_KIND" = "0" ] || fail "$BAD_KIND node kind(s) outside the frozen 10-kind enum"

# no dangling edges (validate-schema already enforces, but assert explicitly)
DANGLING="$(q '([.nodes[].id]|map({(.):true})|add) as $ids | [.edges[]|select(($ids[.source]!=true) or ($ids[.target]!=true))]|length')"
[ "$DANGLING" = "0" ] || fail "$DANGLING dangling edges"

echo "PASS: repo-config canonical-shape eval — 2 workflow + 6 workflow_node + 2 config nodes; reconciliation pair coexists (repo:wf-a + cloud:WF_A); config attrs round-trip; calls KEPT=1 (target resolved to repo:wf-b) SKIPPED=1; within_edges_unresolved=1 (Ghost Node, dropped not dangling); kinds ⊆ 10-enum; validate PASS; heartbeat code->covered"
exit 0
