#!/usr/bin/env bash
# canonical-shape.sh — positive eval for the n8n-cloud emitter.
#
# Feeds a fixture workflow set through the emitter harness (emit.sh) and asserts the
# substrate ends up canonical-shape correct:
#   - validate-schema PASS
#   - n8n-cloud coverage transitions declared-missing/null -> covered (heartbeat advance
#     proves the emitter actually fired vs inheriting prior state)
#   - exactly 2 workflow nodes (one active+normal, one archived+inactive)
#   - 5 workflow_node nodes after stickyNote filter:
#       * 1 with disabled:true (A.11 dangerous case — load-bearing)
#       * 1 with disabled:false (A.11 safe case)
#       * 1 executeWorkflow node calling an IN-SCOPE workflow (cross-workflow edge KEPT)
#       * 2 plain flow nodes (proves connection name->GUID resolve works)
#   - workflow.attributes.archived round-trips both true AND false
#   - every workflow_node carries emitter:"n8n_parser" (D05 P4)
#   - every node carries declared_intent_ref:null (forward-hook)
#   - 3 edge classes present: contains, depends_on (within-workflow), calls (cross-workflow)
#   - no dangling edges
#   - parent_map / child_map derived correctly
#   - the cloud: prefix discipline is honoured (every id starts cloud:)
#
# The eval uses a scratch substrate path via mktemp -d so it NEVER touches a real
# .understand-anything/ directory. Mirrors the Session-2 / substrate skill eval discipline.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
EMIT_SH="$SCRIPT_DIR/../scripts/emit.sh"
TRANSFORM_JQ="$SCRIPT_DIR/../scripts/transform.jq"

if [ ! -f "$SUBSTRATE_SH" ] || [ ! -f "$EMIT_SH" ] || [ ! -f "$TRANSFORM_JQ" ]; then
  echo "FAIL: substrate.sh, emit.sh, or transform.jq missing" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t n8n-cloud-eval-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- pre-emit baseline: confirm n8n-cloud coverage starts at declared-missing -----
# (init seeds emitters at declared-missing / last_emitted_at:null per the substrate's contract).
# This baseline lets us prove the emit caused the transition rather than the value being
# inherited from prior state — closes the "heartbeat silently no-op" failure class.
bash "$SUBSTRATE_SH" init "fixture-entity" >/dev/null 2>&1 || { echo "FAIL: substrate init" >&2; exit 1; }
PRE_COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters["n8n-cloud"].coverage' 2>/dev/null | tr -d '"')"
[ "$PRE_COV" = "declared-missing" ] || { echo "FAIL: pre-emit coverage = '$PRE_COV' (want 'declared-missing'); init did not seed the expected baseline" >&2; exit 1; }
PRE_TS="$(bash "$SUBSTRATE_SH" read-topology '.emitters["n8n-cloud"].last_emitted_at' 2>/dev/null | tr -d '"')"
[ "$PRE_TS" = "null" ] || { echo "FAIL: pre-emit last_emitted_at = '$PRE_TS' (want 'null')" >&2; exit 1; }

# --- fixture workflow set ---------------------------------------------------------
# Two workflows:
#   WF_A: active + not-archived; contains 6 non-sticky nodes including:
#         - 1 executeWorkflow node calling WF_B with PLAIN-STRING workflowId
#           (in-scope -> calls edge KEPT)
#         - 1 executeWorkflow node calling WF_B with RESOURCE-LOCATOR object shape
#           (in-scope -> calls edge KEPT; tests both forms of extract_workflow_id —
#           Session-3 code-council CRITICAL #2)
#         - 1 executeWorkflow node calling WF_NONEXISTENT (out-of-scope -> calls
#           edge SKIPPED; tests the idset-filter dangling-target SKIP path —
#           Session-3 code-council CRITICAL #3)
#         - 1 disabled:true node (A.11 dangerous case)
#         - 1 stickyNote (must be filtered out)
#         - 2 normal flow nodes (proves name->GUID lookup)
#   WF_B: inactive + archived; 1 plain node (proves archived workflows are emitted)
#   Tag shape: WF_A uses OBJECT tags (the real n8n MCP shape) to verify the
#   transform's defensive flatten — Session-3 code-council CRITICAL #1.
cat > "$SCRATCH/workflows.json" <<'EOF'
[
  {
    "id": "WF_A",
    "name": "Fixture Workflow A",
    "active": true,
    "isArchived": false,
    "tags": [
      {"id": "tag_buybox", "name": "buybox", "createdAt": "2026-01-01T00:00:00Z", "updatedAt": "2026-01-01T00:00:00Z"},
      {"id": "tag_ingestion", "name": "ingestion", "createdAt": "2026-01-01T00:00:00Z", "updatedAt": "2026-01-01T00:00:00Z"}
    ],
    "fetch_mode": "active",
    "body": {
      "nodes": [
        {"id": "g1", "name": "Start", "type": "n8n-nodes-base.manualTrigger", "position": [0, 0], "disabled": false},
        {"id": "g2", "name": "Process", "type": "n8n-nodes-base.set", "position": [100, 0], "disabled": false},
        {"id": "g3", "name": "Call B (string)", "type": "n8n-nodes-base.executeWorkflow", "position": [200, 0], "disabled": false, "parameters": {"workflowId": "WF_B"}},
        {"id": "g3rl", "name": "Call B (resource-locator)", "type": "n8n-nodes-base.executeWorkflow", "position": [250, 0], "disabled": false, "parameters": {"workflowId": {"__rl": true, "value": "WF_B", "mode": "id"}}},
        {"id": "g3oos", "name": "Call NONEXISTENT (out of scope)", "type": "n8n-nodes-base.executeWorkflow", "position": [275, 0], "disabled": false, "parameters": {"workflowId": "WF_NONEXISTENT"}},
        {"id": "g4", "name": "Quiet Node", "type": "n8n-nodes-base.set", "position": [300, 0], "disabled": true},
        {"id": "g5", "name": "Doc Sticky", "type": "n8n-nodes-base.stickyNote", "position": [400, 400], "disabled": false}
      ],
      "connections": {
        "Start": {"main": [[{"node": "Process", "type": "main", "index": 0}]]},
        "Process": {"main": [[{"node": "Call B (string)", "type": "main", "index": 0}]]},
        "Call B (string)": {"main": [[{"node": "Call B (resource-locator)", "type": "main", "index": 0}]]},
        "Call B (resource-locator)": {"main": [[{"node": "Call NONEXISTENT (out of scope)", "type": "main", "index": 0}]]},
        "Call NONEXISTENT (out of scope)": {"main": [[{"node": "Quiet Node", "type": "main", "index": 0}]]}
      }
    }
  },
  {
    "id": "WF_B",
    "name": "Fixture Workflow B (archived)",
    "active": false,
    "isArchived": true,
    "tags": ["enrichment"],
    "fetch_mode": "full",
    "body": {
      "nodes": [
        {"id": "h1", "name": "Webhook B", "type": "n8n-nodes-base.webhook", "position": [0, 0], "disabled": false}
      ],
      "connections": {}
    }
  }
]
EOF

# --- run the transform + harness ---------------------------------------------
jq -n \
  --slurpfile workflows "$SCRATCH/workflows.json" \
  --arg now "$NOW" \
  --arg src_commit_prefix "live:fixture-honeybird:" \
  -f "$TRANSFORM_JQ" \
  > "$SCRATCH/combined.json" 2>"$SCRATCH/transform-err"
TRANSFORM_RC=$?
if [ "$TRANSFORM_RC" -ne 0 ]; then
  echo "FAIL: transform.jq exited nonzero ($TRANSFORM_RC)"
  cat "$SCRATCH/transform-err" >&2
  exit 1
fi

# Assert diagnostics block — surfaces the out-of-scope SKIP count (Session-3
# code-council CRITICAL #3). The transform writes its diagnostics into the
# `.diagnostics` field of combined.json; the harness (emit.sh) reads + prints
# them at the end of every emit run. Asserting them here proves the transform
# correctly tallies the SKIP path WITHOUT a leak.
fail_diag() { echo "FAIL: diagnostics — $*" >&2; exit 1; }
DIAG_SKIPPED="$(jq '.diagnostics.cross_workflow_edges_skipped' "$SCRATCH/combined.json" 2>/dev/null | tr -dc '0-9' | head -c 5)"
DIAG_SKIPPED="${DIAG_SKIPPED:-X}"
[ "$DIAG_SKIPPED" = "1" ] || fail_diag "cross_workflow_edges_skipped = '$DIAG_SKIPPED' (want 1 — WF_NONEXISTENT target should be SKIPPED via idset filter)"
DIAG_KEPT="$(jq '.diagnostics.cross_workflow_edges_kept' "$SCRATCH/combined.json" 2>/dev/null | tr -dc '0-9' | head -c 5)"
DIAG_KEPT="${DIAG_KEPT:-X}"
[ "$DIAG_KEPT" = "2" ] || fail_diag "cross_workflow_edges_kept = '$DIAG_KEPT' (want 2 — both shapes of workflowId targeting WF_B should KEEP their edges)"
DIAG_UNRESOLVED="$(jq '.diagnostics.within_edges_unresolved' "$SCRATCH/combined.json" 2>/dev/null | tr -dc '0-9' | head -c 5)"
DIAG_UNRESOLVED="${DIAG_UNRESOLVED:-X}"
[ "$DIAG_UNRESOLVED" = "0" ] || fail_diag "within_edges_unresolved = '$DIAG_UNRESOLVED' (want 0 — fixture connections are all to valid filtered-node names)"

jq '.nodes' "$SCRATCH/combined.json" > "$SCRATCH/nodes.json"
jq '.edges' "$SCRATCH/combined.json" > "$SCRATCH/edges.json"

if ! bash "$EMIT_SH" "$SCRATCH/nodes.json" "$SCRATCH/edges.json" "fixture-entity" >/dev/null 2>"$SCRATCH/harness-err"; then
  echo "FAIL: emit.sh harness exited nonzero"
  cat "$SCRATCH/harness-err" >&2
  exit 1
fi

# --- assertions --------------------------------------------------------------
fail() { echo "FAIL: $*" >&2; exit 1; }

# 1. validate-schema PASS
if ! bash "$SUBSTRATE_SH" validate-schema 2>&1 | grep -q '^PASS$'; then
  fail "validate-schema did not return PASS"
fi

# 2. emitter heartbeat — coverage advanced AND last_emitted_at became non-null on this run.
# Asserting the TRANSITION (pre-emit: declared-missing/null -> post-emit: covered/timestamp)
# closes the "mark-emitter-ran silently no-op" failure class.
COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters["n8n-cloud"].coverage' 2>/dev/null | tr -d '"')"
[ "$COV" = "covered" ] || fail "n8n-cloud coverage = '$COV' (want 'covered')"
TS="$(bash "$SUBSTRATE_SH" read-topology '.emitters["n8n-cloud"].last_emitted_at' 2>/dev/null | tr -d '"')"
[ -n "$TS" ] && [ "$TS" != "null" ] || fail "n8n-cloud last_emitted_at is null/empty (heartbeat did not advance)"
# Format check: ISO 8601 UTC (YYYY-MM-DDTHH:MM:SSZ)
printf '%s' "$TS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
  || fail "n8n-cloud last_emitted_at = '$TS' is not ISO 8601 UTC"

# 3. kind counts — 2 workflow nodes; 7 workflow_node nodes (8 raw nodes in WF_A - 1 sticky filtered = 6, + 1 from WF_B = 7)
N_WF="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(.kind=="workflow")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_WF="${N_WF:-0}"
[ "$N_WF" = "2" ] || fail "expected exactly 2 workflow nodes, got $N_WF"

N_WFN="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(.kind=="workflow_node")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_WFN="${N_WFN:-0}"
# WF_A has 7 raw nodes (g1, g2, g3, g3rl, g3oos, g4, g5-sticky); sticky filtered => 6.
# WF_B has 1 (h1) => 1. Total = 7.
[ "$N_WFN" = "7" ] || fail "expected exactly 7 workflow_node nodes (after stickyNote filter), got $N_WFN"

# 3b. cloud: prefix discipline — every node id must start "cloud:"
NON_CLOUD="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(.id | startswith("cloud:") | not)] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
NON_CLOUD="${NON_CLOUD:-X}"
[ "$NON_CLOUD" = "0" ] || fail "$NON_CLOUD nodes have ids NOT prefixed 'cloud:' (prefix discipline broken)"

# 4. workflow attributes — D05 §6.5.1 base (active, trigger_type) + extensions (name, archived, tags, node_count, connection_count)
# WF_A: active=true, archived=false
WF_A_ACTIVE="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A") | .attributes.active' 2>/dev/null)"
[ "$WF_A_ACTIVE" = "true" ] || fail "workflow WF_A .attributes.active = '$WF_A_ACTIVE' (want true)"
WF_A_ARCHIVED="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A") | .attributes.archived' 2>/dev/null)"
[ "$WF_A_ARCHIVED" = "false" ] || fail "workflow WF_A .attributes.archived = '$WF_A_ARCHIVED' (want false)"
WF_A_NCOUNT="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A") | .attributes.node_count' 2>/dev/null | tr -dc '0-9' | head -c 5)"
WF_A_NCOUNT="${WF_A_NCOUNT:-0}"
[ "$WF_A_NCOUNT" = "6" ] || fail "workflow WF_A node_count = $WF_A_NCOUNT (want 6 — sticky note excluded from 7 raw)"

# WF_A.attributes.tags MUST be normalised to ["buybox", "ingestion"] — the input
# fixture used the OBJECT shape (the real n8n MCP shape). This proves the
# transform's defensive flatten works (Session-3 code-council CRITICAL #1).
WF_A_TAGS="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A") | .attributes.tags' 2>/dev/null)"
expected_tags='["buybox","ingestion"]'
# Normalise whitespace for comparison.
WF_A_TAGS_NORM="$(printf '%s' "$WF_A_TAGS" | tr -d ' \n\t')"
[ "$WF_A_TAGS_NORM" = "$expected_tags" ] || fail "workflow WF_A .attributes.tags = '$WF_A_TAGS_NORM' (want '$expected_tags' — n8n MCP object-shape tags MUST normalise to strings)"

# WF_B: active=false, archived=true (the A.11 analogue for archived workflows — round-trip)
WF_B_ACTIVE="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_B") | .attributes.active' 2>/dev/null)"
[ "$WF_B_ACTIVE" = "false" ] || fail "workflow WF_B .attributes.active = '$WF_B_ACTIVE' (want false)"
WF_B_ARCHIVED="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_B") | .attributes.archived' 2>/dev/null)"
[ "$WF_B_ARCHIVED" = "true" ] || fail "workflow WF_B .attributes.archived = '$WF_B_ARCHIVED' (want true — archived must round-trip)"

# 5. workflow_node — D05 §6.5.1 base (node_type, position) + extensions (name, disabled, workflow_id)
# A.11 LOAD-BEARING: disabled:true MUST round-trip intact. A regression that coerces
# disabled:false (or drops the field) would silently miss the canonical dangerous case
# the emitter exists to surface.
G4_DISABLED="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A:g4") | .attributes.disabled' 2>/dev/null)"
[ "$G4_DISABLED" = "true" ] || fail "workflow_node g4 .attributes.disabled = '$G4_DISABLED' (A.11 dangerous case must round-trip enabled:false intact)"
G1_DISABLED="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A:g1") | .attributes.disabled' 2>/dev/null)"
[ "$G1_DISABLED" = "false" ] || fail "workflow_node g1 .attributes.disabled = '$G1_DISABLED' (A.11 safe case must round-trip enabled:true intact)"

# node_type spot-checks
G3_TYPE="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A:g3") | .attributes.node_type' 2>/dev/null | tr -d '"')"
[ "$G3_TYPE" = "n8n-nodes-base.executeWorkflow" ] || fail "workflow_node g3 .attributes.node_type = '$G3_TYPE' (want n8n-nodes-base.executeWorkflow)"

# workflow_id back-pointer
G3_PARENT="$(bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="cloud:WF_A:g3") | .attributes.workflow_id' 2>/dev/null | tr -d '"')"
[ "$G3_PARENT" = "cloud:WF_A" ] || fail "workflow_node g3 .attributes.workflow_id = '$G3_PARENT' (want cloud:WF_A)"

# 6. sticky note exclusion — fixture had g5 (stickyNote); MUST be absent from substrate
G5_EXISTS="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(.id=="cloud:WF_A:g5")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
G5_EXISTS="${G5_EXISTS:-X}"
[ "$G5_EXISTS" = "0" ] || fail "stickyNote g5 leaked into substrate ($G5_EXISTS nodes, want 0 — filter broke)"

# 7. cross-workflow `calls` edges — TWO kept (g3 + g3rl both target WF_B with
# different parameter shapes) AND ONE skipped (g3oos targets WF_NONEXISTENT,
# which is out of scope; idset filter drops it). Tests BOTH:
#   - Session-3 CRITICAL #2: resource-locator workflowId shape resolves identically
#   - Session-3 CRITICAL #3: out-of-scope target SKIP path (idset filter)
N_CALLS="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select(.type=="calls")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_CALLS="${N_CALLS:-0}"
[ "$N_CALLS" = "2" ] || fail "expected exactly 2 calls edges (g3->WF_B string + g3rl->WF_B resource-locator; g3oos->WF_NONEXISTENT must be SKIPPED), got $N_CALLS"

# Specific source-target assertion for the STRING-shape workflowId (g3)
N_CALLS_STR="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select(.type=="calls" and .source=="cloud:WF_A:g3" and .target=="cloud:WF_B")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_CALLS_STR="${N_CALLS_STR:-0}"
[ "$N_CALLS_STR" = "1" ] || fail "string-shape workflowId: calls edge cloud:WF_A:g3 -> cloud:WF_B missing"

# Specific source-target assertion for the RESOURCE-LOCATOR-shape workflowId (g3rl)
N_CALLS_RL="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select(.type=="calls" and .source=="cloud:WF_A:g3rl" and .target=="cloud:WF_B")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_CALLS_RL="${N_CALLS_RL:-0}"
[ "$N_CALLS_RL" = "1" ] || fail "resource-locator-shape workflowId: calls edge cloud:WF_A:g3rl -> cloud:WF_B missing (extract_workflow_id object-branch broken)"

# OUT-OF-SCOPE assertion: NO calls edge to WF_NONEXISTENT may leak past the idset filter
N_CALLS_OOS="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select(.type=="calls" and .target=="cloud:WF_NONEXISTENT")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_CALLS_OOS="${N_CALLS_OOS:-X}"
[ "$N_CALLS_OOS" = "0" ] || fail "out-of-scope calls edge leaked into substrate: $N_CALLS_OOS edges to cloud:WF_NONEXISTENT (idset filter broken)"

# 8. containment edges — one per workflow_node (7 total: 6 in WF_A + 1 in WF_B)
N_CONTAINS="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select(.type=="contains")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_CONTAINS="${N_CONTAINS:-0}"
[ "$N_CONTAINS" = "7" ] || fail "expected exactly 7 contains edges (one per workflow_node), got $N_CONTAINS"

# 9. within-workflow depends_on edges — name->GUID resolved correctly
# WF_A has 5 connections (Start->Process, Process->Call B (string),
# Call B (string)->Call B (resource-locator), Call B (resource-locator)->Call NONEXISTENT,
# Call NONEXISTENT->Quiet Node)
N_DEPS="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select(.type=="depends_on")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_DEPS="${N_DEPS:-0}"
[ "$N_DEPS" = "5" ] || fail "expected exactly 5 depends_on edges, got $N_DEPS"

# 9b. name->GUID resolve worked — assert specific edge: cloud:WF_A:g1 (Start) -> cloud:WF_A:g2 (Process)
RESOLVE_OK="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select(.type=="depends_on" and .source=="cloud:WF_A:g1" and .target=="cloud:WF_A:g2")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
RESOLVE_OK="${RESOLVE_OK:-0}"
[ "$RESOLVE_OK" = "1" ] || fail "name->GUID resolve broken: Start (g1) -> Process (g2) edge missing"

# 9c. no unresolved-name edges — every endpoint must NOT start with "unresolved:"
UNRESOLVED="$(bash "$SUBSTRATE_SH" read-topology '[.edges[] | select((.source | startswith("unresolved:")) or (.target | startswith("unresolved:")))] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
UNRESOLVED="${UNRESOLVED:-X}"
[ "$UNRESOLVED" = "0" ] || fail "$UNRESOLVED edges have unresolved:<name> endpoints (transform's name->GUID resolve failed)"

# 10. D05 P4 — every node must carry emitter:"n8n_parser" (one node, one emitter)
WRONG_EMITTER="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(.emitter != "n8n_parser")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
WRONG_EMITTER="${WRONG_EMITTER:-X}"
[ "$WRONG_EMITTER" = "0" ] || fail "$WRONG_EMITTER nodes carry emitter != 'n8n_parser' (D05 P4 violation)"

# 11. forward-hook — every node carries declared_intent_ref (null at M3-v1)
MISSING_HOOK="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(has("declared_intent_ref") | not)] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
MISSING_HOOK="${MISSING_HOOK:-X}"
[ "$MISSING_HOOK" = "0" ] || fail "$MISSING_HOOK nodes missing declared_intent_ref forward-hook"

# 12. no dangling edges (every endpoint is in nodes). Use object-membership for jq portability.
DANGLING="$(bash "$SUBSTRATE_SH" read-topology '([.nodes[].id] | map({(.):true}) | add) as $idset | [.edges[] | select(($idset[.source] != true) or ($idset[.target] != true))] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
DANGLING="${DANGLING:-X}"
[ "$DANGLING" = "0" ] || fail "found $DANGLING dangling edges (want 0)"

# 13. parent_map / child_map match nodes' depended_on_by / depends_on.
PM_OK="$(bash "$SUBSTRATE_SH" read-topology '(.parent_map["cloud:WF_A:g2"] | sort) as $pm | ([.nodes[]|select(.id=="cloud:WF_A:g2")][0].depended_on_by | sort) as $dob | $pm == $dob' 2>/dev/null)"
[ "$PM_OK" = "true" ] || fail "parent_map[cloud:WF_A:g2] does not match node.depended_on_by"
CM_OK="$(bash "$SUBSTRATE_SH" read-topology '(.child_map["cloud:WF_A:g3"] | sort) as $cm | ([.nodes[]|select(.id=="cloud:WF_A:g3")][0].depends_on | sort) as $do | $cm == $do' 2>/dev/null)"
[ "$CM_OK" = "true" ] || fail "child_map[cloud:WF_A:g3] does not match node.depends_on"

echo "PASS: canonical-shape eval — 2 workflows + 7 workflow_nodes (incl. A.11 disabled-node + archived workflow + OBJECT-shape tags normalised to strings), §6.5.1 attributes + honest extensions, D05 P4 emitter, declared_intent_ref forward-hook, BOTH workflowId shapes (string + resource-locator) resolve to cross-workflow calls edges, out-of-scope target (WF_NONEXISTENT) SKIPPED via idset filter + surfaced in diagnostics, name->GUID resolve sound, stickyNote filtered, cloud: prefix discipline honoured, heartbeat transitioned declared-missing -> covered with ISO-8601 timestamp, edges sound, maps consistent"
exit 0
