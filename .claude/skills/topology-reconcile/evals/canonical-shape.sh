#!/usr/bin/env bash
# topology-reconcile — exact-verdict fixture eval.
#
# Asserts EXACT verdicts (the Session-4/5/6 lesson: ">0" hides bugs). Covers every verdict-taxonomy path
# + the council-added cases (C1-C5/S1-S6): incomparable-provenance, null/ambiguous join, State B
# (covered-but-absent), multi-invariant single-pass (no jq .-scope cross-contamination), cyclic
# depended_on_by (no hang), derivation drift, the discriminated-union cross-field invariant, the
# read-only byte-untouched assert, and oscillation-never-fires-in-v1.
#
# Pattern mirrors the health-check eval: mktemp scratch + TOPOLOGY_SUBSTRATE_PATH override + jq -e exact.
# bash 3.2 + jq 1.7 target. set -u (NOT -e — assertions must report, not abort).

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUB="$SKILL_DIR/../topology-substrate/scripts/substrate.sh"
RC="$SKILL_DIR/scripts/reconcile.sh"
INV_DIR="$SKILL_DIR/references/invariants"

PASS_COUNT=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { PASS_COUNT=$((PASS_COUNT+1)); echo "  ok: $1"; }

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---- helpers ------------------------------------------------------------------------------------------
# mknode <id> <kind> <emitter> <attrs-json> <source_commit> : a canonical-shape node.
mknode() {
  jq -nc --arg id "$1" --arg kind "$2" --arg em "$3" --argjson attrs "$4" --arg sc "$5" --arg now "$NOW" '
    {id:$id, kind:$kind, source_file:"fixture", source_commit:$sc, timestamp:$now,
     source_line:null, emitter:$em, depends_on:[], depended_on_by:[], attributes:$attrs,
     declared_intent_ref:null}'
}
# a workflow node (repo or cloud) with a node_count + n8n_id.
mkwf() {  # <id> <n8n_id-or-null> <node_count> <source_commit>
  local nid="$2"
  if [ "$nid" = "null" ]; then nid_json="null"; else nid_json="\"$nid\""; fi
  jq -nc --arg id "$1" --argjson nid "$nid_json" --argjson nc "$3" --arg sc "$4" --arg now "$NOW" '
    {id:$id, kind:"workflow", source_file:"fixture", source_commit:$sc, timestamp:$now,
     source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:[],
     attributes:{name:"wf", active:true, node_count:$nc, n8n_id:$nid}, declared_intent_ref:null}'
}
# write the single structural invariant set (1 versioning + 1 derivation = liveness OK).
seed_struct_invariants() { :; }  # the real references/invariants/ already carry them; we use --invariant.

setup() {  # creates a fresh scratch substrate; echoes its DIR. Caller MUST then set+export
           # TOPOLOGY_SUBSTRATE_PATH in the PARENT shell (an export inside $(setup) dies with the subshell).
  local d; d="$(mktemp -d -t recon-XXXXXX)"
  TOPOLOGY_SUBSTRATE_PATH="$d/topology-graph.json" bash "$SUB" init "fixture" >/dev/null 2>&1 || { echo "init failed" >&2; return 1; }
  echo "$d"
}
# use_scratch <dir> : set the env var in the PARENT shell after a $(setup) call.
use_scratch() { export TOPOLOGY_SUBSTRATE_PATH="$1/topology-graph.json"; }

echo "=== topology-reconcile canonical-shape eval ==="

# ---- CASE A — structural DRIFT (33 repo vs 34 cloud), action reconcile, discriminated union -----------
DA="$(setup)" || fail "A setup"
use_scratch "$DA"
NODES_A="[ $(mkwf "repo:wf-a" "ID_A" 33 "abc123+dirty"), $(mkwf "cloud:ID_A" null 34 "live:honeybird:ID_A") ]"
bash "$SUB" bulk-write "$NODES_A" "[]" >/dev/null 2>&1 || fail "A bulk-write"
JA="$(bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json)" || fail "A reconcile rc"
echo "$JA" | jq -e '.invariants[0].verdict == "drift"' >/dev/null || fail "A: verdict != drift ($(echo "$JA"|jq -c .invariants[0].verdict))"; ok "A drift fires (33 vs 34)"
echo "$JA" | jq -e '.invariants[0].named_action == "reconcile"' >/dev/null || fail "A: action != reconcile"; ok "A action=reconcile (repo authoritative)"
echo "$JA" | jq -e '.invariants[0].drift_detail.specifics.structural.repo == 33 and .invariants[0].drift_detail.specifics.structural.cloud == 34' >/dev/null || fail "A: structural detail wrong"; ok "A structural detail repo=33 cloud=34"
echo "$JA" | jq -e '.invariants[0].drift_detail.specifics.commit_time.reason == "incomparable_provenance"' >/dev/null || fail "A: commit-time sub-verdict not incomparable_provenance"; ok "A commit-time incomparable-provenance (dirty vs live) — C1"
rm -rf "$DA"

# ---- CASE B — structural IN_SYNC (33 == 33), named_action null (discriminated union) ------------------
DB="$(setup)" || fail "B setup"
use_scratch "$DB"
NODES_B="[ $(mkwf "repo:wf-b" "ID_B" 33 "abc+dirty"), $(mkwf "cloud:ID_B" null 33 "live:honeybird:ID_B") ]"
bash "$SUB" bulk-write "$NODES_B" "[]" >/dev/null 2>&1 || fail "B bulk-write"
JB="$(bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json)" || fail "B reconcile rc"
echo "$JB" | jq -e '.invariants[0].verdict == "in_sync"' >/dev/null || fail "B: verdict != in_sync"; ok "B in_sync (33 == 33)"
echo "$JB" | jq -e '.invariants[0].named_action == null' >/dev/null || fail "B: named_action not null on non-drift"; ok "B named_action null (discriminated union — C4)"
rm -rf "$DB"

# ---- CASE C — null join key → inconclusive: right-view-absent (NEVER a silent wrong-match) ------------
DC="$(setup)" || fail "C setup"
use_scratch "$DC"
NODES_C="[ $(mkwf "repo:wf-c" "null" 33 "abc+dirty") ]"
bash "$SUB" bulk-write "$NODES_C" "[]" >/dev/null 2>&1 || fail "C bulk-write"
JC="$(bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json)" || fail "C reconcile rc"
echo "$JC" | jq -e '.invariants[0].verdict == "inconclusive"' >/dev/null || fail "C: verdict != inconclusive ($(echo "$JC"|jq -c .invariants[0].verdict))"; ok "C null-join → inconclusive (C2 — never silent wrong-match)"
echo "$JC" | jq -e '.invariants[0].named_action == null' >/dev/null || fail "C: action not null"; ok "C named_action null"
rm -rf "$DC"

# ---- CASE D — ambiguous join (two repo nodes share one n8n_id) → inconclusive classification_uncertain -
DD="$(setup)" || fail "D setup"
use_scratch "$DD"
NODES_D="[ $(mkwf "repo:wf-d1" "ID_D" 30 "abc+dirty"), $(mkwf "repo:wf-d2" "ID_D" 31 "abc+dirty"), $(mkwf "cloud:ID_D" null 30 "live:honeybird:ID_D") ]"
bash "$SUB" bulk-write "$NODES_D" "[]" >/dev/null 2>&1 || fail "D bulk-write"
JD="$(bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json)" || fail "D reconcile rc"
echo "$JD" | jq -e '.invariants[0].verdict == "inconclusive"' >/dev/null || fail "D: verdict != inconclusive"; ok "D ambiguous-join → inconclusive"
echo "$JD" | jq -e '.invariants[0].inconclusive_reason == "classification_uncertain"' >/dev/null || fail "D: inconclusive_reason not classification_uncertain"; ok "D inconclusive_reason classification_uncertain (no silent double-match)"
echo "$JD" | jq -e '.invariants[0].drift_detail == null' >/dev/null || fail "D: drift_detail not null on non-drift"; ok "D drift_detail null on inconclusive (§6.3 discriminated union)"
rm -rf "$DD"

# ---- CASE E — unverifiable_dimension (the supabase-rls invariant reads a declared-missing dimension) ---
DE="$(setup)" || fail "E setup"
use_scratch "$DE"
# fresh init: supabase-live is declared-missing. The invariant reads it → unverifiable_dimension.
JE="$(bash "$RC" --invariant inv-supabase-rls-coverage --json)" || fail "E reconcile rc"
echo "$JE" | jq -e '.invariants[0].verdict == "unverifiable_dimension"' >/dev/null || fail "E: verdict != unverifiable_dimension ($(echo "$JE"|jq -c .invariants[0].verdict))"; ok "E declared-missing dimension → unverifiable_dimension (C3/P6)"
echo "$JE" | jq -e '.invariants[0].named_action == null' >/dev/null || fail "E: action not null"; ok "E named_action null"
rm -rf "$DE"

# ---- CASE F — derivation IN_SYNC (every depends_on resolves) ------------------------------------------
DF="$(setup)" || fail "F setup"
use_scratch "$DF"
N1="$(mknode "n1" "ts_module" "dependency_cruiser" '{}' "abc+dirty")"
N2="$(mknode "n2" "ts_module" "dependency_cruiser" '{}' "abc+dirty")"
# n1 depends_on n2 (resolves). write nodes then an edge.
bash "$SUB" bulk-write "[ $N1, $N2 ]" '[{"source":"n1","target":"n2","type":"imports","direction":"forward","weight":1}]' >/dev/null 2>&1 || fail "F bulk-write"
JF="$(bash "$RC" --invariant inv-every-depends-on-resolves --json)" || fail "F reconcile rc"
echo "$JF" | jq -e '.invariants[0].verdict == "in_sync"' >/dev/null || fail "F: verdict != in_sync ($(echo "$JF"|jq -c .invariants[0].verdict))"; ok "F derivation in_sync (every depends_on resolves)"
rm -rf "$DF"

# ---- CASE G — derivation DRIFT (a depends_on target that does not exist) ------------------------------
# The substrate rejects dangling edges at write — so we inject the dangling reference via a node's
# depends_on array directly (a node whose depends_on names a missing id). bulk-write integrity checks
# EDGES, not the depends_on array, so this is the realistic "hand-edited / out-of-band" dangling case.
DG="$(setup)" || fail "G setup"
use_scratch "$DG"
NG="$(jq -nc --arg now "$NOW" '{id:"ng1", kind:"ts_module", source_file:"fixture", source_commit:"abc+dirty",
  timestamp:$now, source_line:null, emitter:"dependency_cruiser", depends_on:["ng-MISSING"],
  depended_on_by:[], attributes:{}, declared_intent_ref:null}')"
# bulk-write with NO edges (the dangling is only in depends_on, which bulk-write does not cross-check).
bash "$SUB" bulk-write "[ $NG ]" "[]" >/dev/null 2>&1 || fail "G bulk-write"
JG="$(bash "$RC" --invariant inv-every-depends-on-resolves --json)" || fail "G reconcile rc"
echo "$JG" | jq -e '.invariants[0].verdict == "drift"' >/dev/null || fail "G: verdict != drift ($(echo "$JG"|jq -c .invariants[0].verdict))"; ok "G derivation drift (dangling depends_on) — exercises the drift path (Devil's Advocate #2)"
echo "$JG" | jq -e '.invariants[0].named_action == "escalate"' >/dev/null || fail "G: action != escalate"; ok "G derivation drift action=escalate (source-orphan masquerade)"
rm -rf "$DG"

# ---- CASE H — multi-invariant single-pass (no jq .-scope cross-contamination — Session-4 bug class) ---
DH="$(setup)" || fail "H setup"
use_scratch "$DH"
NODES_H="[ $(mkwf "repo:wf-h" "ID_H" 33 "abc+dirty"), $(mkwf "cloud:ID_H" null 34 "live:honeybird:ID_H"), $(mknode "h1" "ts_module" "dependency_cruiser" '{}' "abc+dirty") ]"
bash "$SUB" bulk-write "$NODES_H" "[]" >/dev/null 2>&1 || fail "H bulk-write"
JH="$(bash "$RC" --json)" || fail "H reconcile rc"   # ALL invariants, one pass
# the structural invariant must report drift; the derivation invariant must report in_sync; independently.
echo "$JH" | jq -e '[.invariants[] | select(.kind=="versioning")][0].verdict == "drift"' >/dev/null || fail "H: versioning not drift in multi-pass"; ok "H versioning=drift in multi-invariant pass"
echo "$JH" | jq -e '[.invariants[] | select(.id=="inv-every-depends-on-resolves")][0].verdict == "in_sync"' >/dev/null || fail "H: derivation not in_sync in multi-pass"; ok "H derivation=in_sync in same pass (no .-scope cross-contamination — S4)"
echo "$JH" | jq -e '(.invariants | length) == 3' >/dev/null || fail "H: not 3 invariants"; ok "H all 3 invariants computed independently"
rm -rf "$DH"

# ---- CASE I — read-only: substrate byte-untouched after a reconcile run ------------------------------
DI="$(setup)" || fail "I setup"
use_scratch "$DI"
NODES_I="[ $(mkwf "repo:wf-i" "ID_I" 33 "abc+dirty"), $(mkwf "cloud:ID_I" null 34 "live:honeybird:ID_I") ]"
bash "$SUB" bulk-write "$NODES_I" "[]" >/dev/null 2>&1 || fail "I bulk-write"
MD5_BEFORE="$(md5 -q "$TOPOLOGY_SUBSTRATE_PATH" 2>/dev/null || md5sum "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
bash "$RC" --json >/dev/null 2>&1 || fail "I reconcile rc"
MD5_AFTER="$(md5 -q "$TOPOLOGY_SUBSTRATE_PATH" 2>/dev/null || md5sum "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
[ "$MD5_BEFORE" = "$MD5_AFTER" ] || fail "I: substrate CHANGED after reconcile — read-only VIOLATED"; ok "I substrate byte-untouched (read-only invariant — P2)"
rm -rf "$DI"

# ---- CASE J — discriminated-union invariant across ALL cases: drift⇒action, non-drift⇒null -----------
# (re-uses CASE A drift + CASE B in_sync results captured above structurally; assert the global invariant)
DJ="$(setup)" || fail "J setup"
use_scratch "$DJ"
NODES_J="[ $(mkwf "repo:wf-j" "ID_J" 33 "abc+dirty"), $(mkwf "cloud:ID_J" null 34 "live:honeybird:ID_J"), $(mknode "j1" "ts_module" "dependency_cruiser" '{}' "abc+dirty") ]"
bash "$SUB" bulk-write "$NODES_J" "[]" >/dev/null 2>&1 || fail "J bulk-write"
JJ="$(bash "$RC" --json)" || fail "J reconcile rc"
echo "$JJ" | jq -e 'all(.invariants[]; (.verdict=="drift") == (.named_action != null))' >/dev/null || fail "J: discriminated-union invariant VIOLATED (drift without action, or action without drift)"; ok "J discriminated-union holds across all invariants (named_action != null IFF drift — C4)"
echo "$JJ" | jq -e 'all(.invariants[]; (.verdict=="drift") == (.drift_detail != null))' >/dev/null || fail "J: drift_detail not null IFF drift VIOLATED"; ok "J drift_detail != null IFF verdict==drift (§6.3 — Type Analyzer fix)"
rm -rf "$DJ"

# ---- CASE O — manual source-orphan right_view → unverifiable_spot, NOT drift (P6/§8.5 — Spec/Test) -----
DO="$(setup)" || fail "O setup"
use_scratch "$DO"
# a cloud node with emitter:"manual" + manual_justification, joined to a repo node with a count drift.
MANUAL_CLOUD="$(jq -nc --arg now "$NOW" '{id:"cloud:ID_O", kind:"workflow", source_file:"manual", source_commit:"manual:ID_O", timestamp:$now, source_line:null, emitter:"manual", manual_justification:"hand-maintained workflow, no generator", depends_on:[], depended_on_by:[], attributes:{name:"wf", active:true, node_count:34, n8n_id:null}, declared_intent_ref:null}')"
NODES_O="[ $(mkwf "repo:wf-o" "ID_O" 33 "abc+dirty"), $MANUAL_CLOUD ]"
bash "$SUB" bulk-write "$NODES_O" "[]" >/dev/null 2>&1 || fail "O bulk-write"
JO="$(bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json)" || fail "O reconcile rc"
echo "$JO" | jq -e '.invariants[0].verdict == "unverifiable_spot"' >/dev/null || fail "O: verdict != unverifiable_spot (got $(echo "$JO"|jq -c .invariants[0].verdict)) — must NOT be drift over a manual node"; ok "O manual source-orphan right_view → unverifiable_spot (P6 — never drift→reconcile over a hand-maintained node)"
echo "$JO" | jq -e '.invariants[0].named_action == null' >/dev/null || fail "O: action not null"; ok "O named_action null on unverifiable_spot"
rm -rf "$DO"

# ---- CASE P — stale input beyond the window → inconclusive:stale-input-broken (P4/§6.7 freshness) ------
DP="$(setup)" || fail "P setup"
use_scratch "$DP"
# both git-resolvable (so commit-time is comparable), counts match — but the cloud node is 200h stale.
STALE_TS="$(jq -nr --argjson ago 720000 'now - $ago | todateiso8601' 2>/dev/null || echo "2025-01-01T00:00:00Z")"
REPO_P="$(jq -nc --arg now "$NOW" '{id:"repo:wf-p", kind:"workflow", source_file:"f", source_commit:"aaa111", timestamp:$now, source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:[], attributes:{name:"wf", active:true, node_count:33, n8n_id:"ID_P"}, declared_intent_ref:null}')"
CLOUD_P="$(jq -nc --arg ts "$STALE_TS" '{id:"cloud:ID_P", kind:"workflow", source_file:"f", source_commit:"bbb222", timestamp:$ts, source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:[], attributes:{name:"wf", active:true, node_count:33, n8n_id:null}, declared_intent_ref:null}')"
bash "$SUB" bulk-write "[ $REPO_P, $CLOUD_P ]" "[]" >/dev/null 2>&1 || fail "P bulk-write"
JP="$(TOPOLOGY_RECONCILE_STALE_H=168 bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json)" || fail "P reconcile rc"
echo "$JP" | jq -e '.invariants[0].verdict == "inconclusive"' >/dev/null || fail "P: verdict != inconclusive (got $(echo "$JP"|jq -c .invariants[0].verdict)) — stale input must NOT report in_sync (§8.1)"; ok "P stale-beyond-window → inconclusive (NOT a false in_sync over a stale snapshot — §8.1 theatre-of-trust defence)"
echo "$JP" | jq -e '.invariants[0].inconclusive_reason == "stale-input-broken"' >/dev/null || fail "P: inconclusive_reason != stale-input-broken"; ok "P inconclusive_reason stale-input-broken (the freshness precondition is LIVE — \$window exercised)"
rm -rf "$DP"

# ---- CASE Q — both-sides-null node_count → inconclusive, NOT a false in_sync (§8.4 vacuous-green-light) -
DQ="$(setup)" || fail "Q setup"
use_scratch "$DQ"
REPO_Q="$(jq -nc --arg now "$NOW" '{id:"repo:wf-q", kind:"workflow", source_file:"f", source_commit:"abc+dirty", timestamp:$now, source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:[], attributes:{name:"wf", active:true, n8n_id:"ID_Q"}, declared_intent_ref:null}')"
CLOUD_Q="$(jq -nc --arg now "$NOW" '{id:"cloud:ID_Q", kind:"workflow", source_file:"f", source_commit:"live:honeybird:ID_Q", timestamp:$now, source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:[], attributes:{name:"wf", active:true, n8n_id:null}, declared_intent_ref:null}')"
bash "$SUB" bulk-write "[ $REPO_Q, $CLOUD_Q ]" "[]" >/dev/null 2>&1 || fail "Q bulk-write"
JQJ="$(bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json)" || fail "Q reconcile rc"
echo "$JQJ" | jq -e '.invariants[0].verdict == "inconclusive"' >/dev/null || fail "Q: both-null node_count gave $(echo "$JQJ"|jq -c .invariants[0].verdict) — MUST NOT be a false in_sync (§8.4)"; ok "Q both-null node_count → inconclusive (NOT a vacuous in_sync over absent fields — §8.4)"
rm -rf "$DQ"

# ---- CASE R — derivation drift on a PARTIAL substrate → rank_completeness partial (§8.7 — Spec/Test) ---
DR="$(setup)" || fail "R setup"
use_scratch "$DR"
# fresh init: supabase-live + n8n-cloud are declared-missing → the substrate IS partial. A dangling derivation
# drift must therefore carry rank_completeness:partial (never present a partial fan-in as authoritative).
NR_NODE="$(jq -nc --arg now "$NOW" '{id:"nr1", kind:"ts_module", source_file:"f", source_commit:"abc+dirty", timestamp:$now, source_line:null, emitter:"dependency_cruiser", depends_on:["nr-MISSING"], depended_on_by:[], attributes:{}, declared_intent_ref:null}')"
bash "$SUB" bulk-write "[ $NR_NODE ]" "[]" >/dev/null 2>&1 || fail "R bulk-write"
JR="$(bash "$RC" --invariant inv-every-depends-on-resolves --json)" || fail "R reconcile rc"
echo "$JR" | jq -e '.invariants[0].verdict == "drift"' >/dev/null || fail "R: verdict != drift"; ok "R derivation drift on partial substrate"
echo "$JR" | jq -e '.invariants[0].impact_rank.rank_completeness == "partial"' >/dev/null || fail "R: derivation rank_completeness != partial (got $(echo "$JR"|jq -c .invariants[0].impact_rank.rank_completeness)) — §8.7 violated"; ok "R derivation rank_completeness=partial on a declared-missing substrate (§8.7 — was hardcoded complete)"
rm -rf "$DR"

# ---- CASE S — --invariant with NO value → usage error (rc 2), NOT an infinite-loop hang (bash 3.2) -----
( bash "$RC" --invariant </dev/null >/dev/null 2>&1 ) & SPID=$!
selapsed=0
while kill -0 "$SPID" 2>/dev/null; do sleep 1; selapsed=$((selapsed+1)); if [ "$selapsed" -ge 8 ]; then kill -9 "$SPID" 2>/dev/null; fail "S: --invariant (no value) HUNG (>8s) — bash 3.2 shift-2 infinite loop"; fi; done
wait "$SPID"; SRC=$?
[ "$SRC" -eq 2 ] || fail "S: --invariant (no value) rc=$SRC, expected 2 (usage)"; ok "S --invariant no-value → rc 2 usage error, no hang (bash 3.2 shift-2 guard)"

# ---- CASE K — cyclic depended_on_by does NOT hang the impact_rank walk -------------------------------
DK="$(setup)" || fail "K setup"
use_scratch "$DK"
# two workflow nodes in a depended_on_by cycle + a structural drift to trigger the walk.
CYC1="$(jq -nc --arg now "$NOW" '{id:"cloud:ID_K", kind:"workflow", source_file:"fixture", source_commit:"live:honeybird:ID_K",
  timestamp:$now, source_line:null, emitter:"n8n_parser", depends_on:[], depended_on_by:["cyc2"],
  attributes:{name:"wf", active:true, node_count:34, n8n_id:null}, declared_intent_ref:null}')"
REPOK="$(mkwf "repo:wf-k" "ID_K" 33 "abc+dirty")"
CYC2="$(jq -nc --arg now "$NOW" '{id:"cyc2", kind:"ts_module", source_file:"fixture", source_commit:"abc+dirty",
  timestamp:$now, source_line:null, emitter:"dependency_cruiser", depends_on:[], depended_on_by:["cloud:ID_K"],
  attributes:{}, declared_intent_ref:null}')"
bash "$SUB" bulk-write "[ $REPOK, $CYC1, $CYC2 ]" "[]" >/dev/null 2>&1 || fail "K bulk-write"
# guard against a hang: run with a background-kill watchdog (no GNU timeout on macOS).
( bash "$RC" --invariant inv-repo-vs-cloud-n8n-structural --json > "$DK/out.json" 2>/dev/null ) & RCPID=$!
elapsed=0
while kill -0 "$RCPID" 2>/dev/null; do sleep 1; elapsed=$((elapsed+1)); if [ "$elapsed" -ge 15 ]; then kill -9 "$RCPID" 2>/dev/null; fail "K: reconcile HUNG on cyclic depended_on_by (>15s) — cycle guard missing"; fi; done
wait "$RCPID"
JK="$(cat "$DK/out.json")"
echo "$JK" | jq -e '.invariants[0].verdict == "drift"' >/dev/null || fail "K: verdict != drift"; ok "K cyclic depended_on_by: reconcile completes (no hang — S4 depth-limit)"
echo "$JK" | jq -e '.invariants[0].impact_rank.rank_completeness == "partial"' >/dev/null || fail "K: rank not partial on cycle"; ok "K cycle → rank_completeness partial"
rm -rf "$DK"

# ---- CASE L — oscillation_detected NEVER fires in v1 (no auto-exec populates action_outcome) ----------
DL="$(setup)" || fail "L setup"
use_scratch "$DL"
NODES_L="[ $(mkwf "repo:wf-l" "ID_L" 33 "abc+dirty"), $(mkwf "cloud:ID_L" null 34 "live:honeybird:ID_L") ]"
bash "$SUB" bulk-write "$NODES_L" "[]" >/dev/null 2>&1 || fail "L bulk-write"
JL="$(bash "$RC" --json)" || fail "L reconcile rc"
echo "$JL" | jq -e 'all(.invariants[]; (.drift_detail.reason_class // "") != "oscillation_detected")' >/dev/null || fail "L: oscillation_detected fired in v1 (must be v2-gated)"; ok "L oscillation_detected never fires in v1 (S2 — no auto-exec)"
echo "$JL" | jq -e 'all(.invariants[]; .action_outcome == [])' >/dev/null || fail "L: action_outcome not empty in v1"; ok "L action_outcome always [] in v1 (S1 — propose-only)"
rm -rf "$DL"

# ---- CASE M — no-invariants-registered (liveness gate — in_sync PROHIBITED over empty registry) -------
DM="$(setup)" || fail "M setup"
use_scratch "$DM"
JM="$(bash "$RC" --invariant inv-DOES-NOT-EXIST --json)" || fail "M reconcile rc"
echo "$JM" | jq -e '.verdict == "no-invariants-registered" or .summary == "no-invariants-registered"' >/dev/null || fail "M: empty registry not no-invariants-registered ($(echo "$JM"|jq -c '.verdict // .summary'))"; ok "M empty registry → no-invariants-registered (§6.8 — in_sync prohibited)"
rm -rf "$DM"

# ---- CASE N — UNINITIALISED substrate (rc 4 mapping) -------------------------------------------------
DN="$(mktemp -d -t recon-N-XXXXXX)"
export TOPOLOGY_SUBSTRATE_PATH="$DN/topology-graph.json"   # never init'd
JN="$(bash "$RC" --json)" || fail "N reconcile rc"
echo "$JN" | jq -e '.verdict == "UNINITIALISED"' >/dev/null || fail "N: not UNINITIALISED ($(echo "$JN"|jq -c .verdict))"; ok "N uninitialised substrate → UNINITIALISED (rc 4 mapping)"
rm -rf "$DN"

echo ""
echo "=== PASS — all $PASS_COUNT assertions green ==="
