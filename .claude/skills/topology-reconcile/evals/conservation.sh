#!/usr/bin/env bash
# topology-reconcile — M6 CONSERVATION-class unit eval (the safety-critical additive branch).
#
# Exact-verdict fixtures (the Session-4/5/6 lesson: ">0" hides bugs). Proves the conservation branch
# (compute_conservation in reconcile.sh) against SYNTHETIC scratch fixtures — NO your project, NO live state.
# Covers council A4 (the assertion's FAILING side: enabled:false -> drift), A3 (emitter-level NO_MAP, two
# reason codes), A9 (partial wired_to list), A11 (field-level freshness: dirty + stale + the no-over-gate
# field-scoping case), Gate-1 (absent target -> escalate), the empty/pending + intent-source guards, and
# the P2 read-only byte-untouched assert.
#
# Pattern mirrors canonical-shape.sh + integration.sh: mktemp scratch + env overrides + jq -e exact verdict.
# bash 3.2 + jq 1.7 target. set -u (NOT -e — assertions must report, not abort).

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUB="$SKILL_DIR/../topology-substrate/scripts/substrate.sh"
IST="$SKILL_DIR/../intent-capture-emitter/scripts/intent-store.sh"
RC="$SKILL_DIR/scripts/reconcile.sh"
INV=inv-intent-conservation-rls

PASS_COUNT=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { PASS_COUNT=$((PASS_COUNT+1)); echo "  ok: $1"; }

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OLD="2020-01-01T00:00:00Z"   # safely before NOW (for the staleness cases)

# ---- fixture builders --------------------------------------------------------------------------------
# an rls_policy node. enabled: "true" | "false" | "OMIT" (no attribute). ts = node timestamp.
mkrls() {
  if [ "$2" = "OMIT" ]; then
    jq -nc --arg id "$1" --arg ts "$3" '{id:$id, kind:"rls_policy", source_file:"db", source_commit:"sha",
      timestamp:$ts, source_line:null, emitter:"pg_depend", depends_on:[], depended_on_by:[],
      attributes:{command:"SELECT", role:"authenticated"}, declared_intent_ref:null}'
  else
    jq -nc --arg id "$1" --argjson en "$2" --arg ts "$3" '{id:$id, kind:"rls_policy", source_file:"db",
      source_commit:"sha", timestamp:$ts, source_line:null, emitter:"pg_depend", depends_on:[], depended_on_by:[],
      attributes:{enabled:$en, command:"SELECT", role:"authenticated"}, declared_intent_ref:null}'
  fi
}
# an accepted intent record wired to <wired_to-json>.
mkintent() {
  jq -nc --arg id "$1" --argjson w "$2" --arg st "${3:-accepted}" --arg now "$NOW" '{id:$id, kind:"destination",
    source_file:"DESTINATION.md", source_commit:"sha2", timestamp:$now, title:"own-billing promise", status:$st,
    superseded_by:null, conditions:"users see own billing only", binary_test:"third-party SELECT denied",
    falsifier:null, wired_to:$w, owner:"j", acceptance_cadence:"90d", emitter:"destination_parser"}'
}
# an intent-computed.json: <record-id> <freshness_status> <wired_to_date> <conditions_date> [title_date]
mkcomputed() {
  jq -nc --arg id "$1" --arg fs "$2" --arg wd "$3" --arg cd "$4" --arg td "${5:-}" '
    {schema_version:"1", emitter:"intent_computed_generator", provenance:"derived", freshness_basis:"committed-state-only",
     records: { ($id): { source_file:"DESTINATION.md", freshness_status:$fs, commits_scanned:2,
       fields: ( {wired_to:{last_changed_commit:"c1", last_changed_date:$wd},
                  conditions:{last_changed_commit:"c1", last_changed_date:$cd}}
                 + (if $td=="" then {} else {title:{last_changed_commit:"c2", last_changed_date:$td}} end) ) } } }'
}

newcase() { mktemp -d -t cons-XXXXXX; }
usecase() {
  export TOPOLOGY_SUBSTRATE_PATH="$1/topology-graph.json"
  export INTENT_SUBSTRATE_PATH="$1/intent-ledger.json"
  export INTENT_COMPUTED_PATH="$1/intent-computed.json"
}
# init a scratch topology with supabase-live coverage = $2, and a scratch intent ledger.
init_both() {  # <dir> <coverage>
  bash "$SUB" init "cons" >/dev/null 2>&1 || fail "topo init"
  [ "$2" = "declared-missing" ] || bash "$SUB" mark-emitter-ran supabase-live "$2" >/dev/null 2>&1 || fail "mark-emitter $2"
  bash "$IST" init "cons" >/dev/null 2>&1 || fail "intent init"
}
verdict() { echo "$1" | jq -r '.invariants[0].verdict'; }

echo "=== topology-reconcile M6 conservation unit eval ==="
RID="intent:destination:own-billing"
POL="public.deals.own_billing"

# ---- CASE 1 — enabled:true → in_sync (A4: the verdict relied on a REAL enabled read, not a default) ----
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "1 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "1 intent write"
J1="$(bash "$RC" --invariant "$INV" --json)" || fail "1 reconcile rc"
[ "$(verdict "$J1")" = "in_sync" ] || fail "1 verdict $(verdict "$J1") != in_sync"; ok "1 enabled:true → in_sync"
echo "$J1" | jq -e '.invariants[0].named_action == null and .invariants[0].drift_detail == null' >/dev/null || fail "1 non-drift not clean"; ok "1 in_sync carries named_action null + drift_detail null (discriminated union)"
rm -rf "$D"

# ---- CASE 2 — enabled:false → drift (A4 FAILING SIDE — the dead-assertion guard), escalate -------------
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" false "$NOW") ]" "[]" >/dev/null 2>&1 || fail "2 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "2 intent write"
J2="$(bash "$RC" --invariant "$INV" --json)" || fail "2 reconcile rc"
[ "$(verdict "$J2")" = "drift" ] || fail "2 verdict $(verdict "$J2") != drift"; ok "2 enabled:false → drift (A4: the assertion's failing side is exercised — not dead)"
echo "$J2" | jq -e '.invariants[0].named_action == "escalate"' >/dev/null || fail "2 action != escalate"; ok "2 action=escalate (rls_policy = security control = HIGH consequence, §11 step 3)"
echo "$J2" | jq -e '.invariants[0].drift_detail.specifics.reason == "wired_target_disabled" and (.invariants[0].drift_detail.specifics.disabled_targets | index("'"$POL"'") != null)' >/dev/null || fail "2 drift_detail wrong"; ok "2 drift_detail names wired_target_disabled + the disabled node id"
rm -rf "$D"

# ---- CASE 3 — absent target → drift (Gate 1), escalate, reason wired_to_target_absent ------------------
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "3 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"public.deals.ghost\"]") ]" >/dev/null 2>&1 || fail "3 intent write"
J3="$(bash "$RC" --invariant "$INV" --json)" || fail "3 reconcile rc"
[ "$(verdict "$J3")" = "drift" ] || fail "3 verdict $(verdict "$J3") != drift"; ok "3 absent wired_to target → drift"
echo "$J3" | jq -e '.invariants[0].named_action == "escalate" and .invariants[0].drift_detail.specifics.reason == "wired_to_target_absent"' >/dev/null || fail "3 escalate/reason wrong"; ok "3 escalate + reason wired_to_target_absent (Gate 1 — M6 never auto-repoints; operator supersedes)"
echo "$J3" | jq -e '.invariants[0].drift_detail.specifics.absent_targets | index("public.deals.ghost") != null' >/dev/null || fail "3 absent_targets not enumerated"; ok "3 absent_targets enumerates the unresolved id"
rm -rf "$D"

# ---- CASE 4 — partial wired_to list (one present+enabled, one absent) → drift + absent_targets (A9) -----
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "4 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\",\"public.deals.ghost\"]") ]" >/dev/null 2>&1 || fail "4 intent write"
J4="$(bash "$RC" --invariant "$INV" --json)" || fail "4 reconcile rc"
[ "$(verdict "$J4")" = "drift" ] || fail "4 verdict $(verdict "$J4") != drift"; ok "4 partial list (one absent member) → drift (A9 — never silent in_sync on partial resolution)"
echo "$J4" | jq -e '(.invariants[0].drift_detail.specifics.absent_targets | length) == 1 and (.invariants[0].drift_detail.specifics.absent_targets | index("public.deals.ghost") != null)' >/dev/null || fail "4 absent_targets wrong"; ok "4 drift_detail.absent_targets enumerates ONLY the unresolved id"
rm -rf "$D"

# ---- CASE 5 — declared-missing emitter → unverifiable_dimension reason topology_emitter_not_run (A3) ----
D="$(newcase)"; usecase "$D"; init_both "$D" declared-missing
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "5 intent write"
J5="$(bash "$RC" --invariant "$INV" --json)" || fail "5 reconcile rc"
[ "$(verdict "$J5")" = "unverifiable_dimension" ] || fail "5 verdict $(verdict "$J5") != unverifiable_dimension"; ok "5 declared-missing supabase-live → unverifiable_dimension (A3 — never a false drift over a dark surface)"
echo "$J5" | jq -e '.invariants[0].inconclusive_reason == "topology_emitter_not_run" and .invariants[0].named_action == null' >/dev/null || fail "5 reason != topology_emitter_not_run"; ok "5 reason topology_emitter_not_run (actionable: run the emitter)"
rm -rf "$D"

# ---- CASE 6 — absent emitter → unverifiable_dimension reason no_topology_source_at_entity (A3) ---------
D="$(newcase)"; usecase "$D"; init_both "$D" absent
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "6 intent write"
J6="$(bash "$RC" --invariant "$INV" --json)" || fail "6 reconcile rc"
[ "$(verdict "$J6")" = "unverifiable_dimension" ] || fail "6 verdict $(verdict "$J6") != unverifiable_dimension"; ok "6 absent supabase-live → unverifiable_dimension"
echo "$J6" | jq -e '.invariants[0].inconclusive_reason == "no_topology_source_at_entity"' >/dev/null || fail "6 reason != no_topology_source_at_entity"; ok "6 reason no_topology_source_at_entity (the source type structurally cannot exist here — distinct from emitter-not-run)"
rm -rf "$D"

# ---- CASE 7 — intent store absent → inconclusive: intent-source-absent (never false in_sync/drift) -----
D="$(newcase)"; usecase "$D"
bash "$SUB" init "cons" >/dev/null 2>&1 || fail "7 topo init"
bash "$SUB" mark-emitter-ran supabase-live covered >/dev/null 2>&1 || fail "7 mark"
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "7 topo write"
# deliberately do NOT init the intent ledger → INTENT_SUBSTRATE_PATH points at a non-existent file.
J7="$(bash "$RC" --invariant "$INV" --json)" || fail "7 reconcile rc"
[ "$(verdict "$J7")" = "inconclusive" ] || fail "7 verdict $(verdict "$J7") != inconclusive"; ok "7 intent store absent → inconclusive (NOT a false in_sync/drift)"
echo "$J7" | jq -e '.invariants[0].inconclusive_reason == "intent-source-absent"' >/dev/null || fail "7 reason != intent-source-absent"; ok "7 reason intent-source-absent"
rm -rf "$D"

# ---- CASE 8 — A11 dirty carrier (computed reports uncommitted) → inconclusive: uncommitted-changes ------
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "8 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "8 intent write"
mkcomputed "$RID" "inconclusive: uncommitted-changes" "" "" > "$INTENT_COMPUTED_PATH"
J8="$(bash "$RC" --invariant "$INV" --json)" || fail "8 reconcile rc"
[ "$(verdict "$J8")" = "inconclusive" ] || fail "8 verdict $(verdict "$J8") != inconclusive"; ok "8 dirty carrier → inconclusive (A11 binding: committed-state-only, never false in_sync over an uncommitted edit)"
echo "$J8" | jq -e '.invariants[0].inconclusive_reason == "uncommitted-changes"' >/dev/null || fail "8 reason != uncommitted-changes"; ok "8 reason uncommitted-changes"
rm -rf "$D"

# ---- CASE 9 — A11 committed-but-stale (topology OLDER than the wired_to change) → inconclusive:stale ----
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$OLD") ]" "[]" >/dev/null 2>&1 || fail "9 topo write"   # node ts OLD
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "9 intent write"
mkcomputed "$RID" "committed" "$NOW" "$NOW" > "$INTENT_COMPUTED_PATH"   # wired_to changed NOW (after topology)
J9="$(bash "$RC" --invariant "$INV" --json)" || fail "9 reconcile rc"
[ "$(verdict "$J9")" = "inconclusive" ] || fail "9 verdict $(verdict "$J9") != inconclusive"; ok "9 topology older than the read field → inconclusive (A11 field-level freshness precondition fires)"
echo "$J9" | jq -e '.invariants[0].inconclusive_reason == "stale-input"' >/dev/null || fail "9 reason != stale-input"; ok "9 reason stale-input (the §6.7 precondition is LIVE — not a dead freshness gate)"
rm -rf "$D"

# ---- CASE 10 — A11 field-scoping: only a NON-read field is recent (wired_to/conditions OLD) → NO gate ---
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "10 topo write"   # node ts NOW
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "10 intent write"
# wired_to + conditions changed long ago (OLD); only `title` is recent (NOW). Conservation reads ONLY
# wired_to + conditions → topology(NOW) is NOT older than them → must NOT gate → proceeds → in_sync.
mkcomputed "$RID" "committed" "$OLD" "$OLD" "$NOW" > "$INTENT_COMPUTED_PATH"
J10="$(bash "$RC" --invariant "$INV" --json)" || fail "10 reconcile rc"
[ "$(verdict "$J10")" = "in_sync" ] || fail "10 verdict $(verdict "$J10") != in_sync"; ok "10 a recent edit to a NON-read field (title) does NOT gate this invariant → in_sync (A11/A6 field-scoping — no system-wide blackout)"
rm -rf "$D"

# ---- CASE 11 — present but NO enabled attribute → inconclusive (A4 assert-before-rely, fail-safe) -------
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" OMIT "$NOW") ]" "[]" >/dev/null 2>&1 || fail "11 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "11 intent write"
J11="$(bash "$RC" --invariant "$INV" --json)" || fail "11 reconcile rc"
[ "$(verdict "$J11")" = "inconclusive" ] || fail "11 verdict $(verdict "$J11") != inconclusive"; ok "11 present node lacking attributes.enabled → inconclusive (cannot assert the control is active — never a false in_sync/drift)"
echo "$J11" | jq -e '.invariants[0].inconclusive_reason == "wired_target_missing_enabled_attribute"' >/dev/null || fail "11 reason wrong"; ok "11 reason wired_target_missing_enabled_attribute (A4 assert-before-rely)"
rm -rf "$D"

# ---- CASE 12 — all wired_to pending → inconclusive (0c empty left_view) --------------------------------
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "12 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "\"pending\"") ]" >/dev/null 2>&1 || fail "12 intent write"
J12="$(bash "$RC" --invariant "$INV" --json)" || fail "12 reconcile rc"
[ "$(verdict "$J12")" = "inconclusive" ] || fail "12 verdict $(verdict "$J12") != inconclusive"; ok "12 wired_to=pending → inconclusive (0c empty left_view — never a vacuous in_sync over an unwired promise)"
echo "$J12" | jq -e '.invariants[0].inconclusive_reason == "left-view-empty-or-pending"' >/dev/null || fail "12 reason wrong"; ok "12 reason left-view-empty-or-pending"
rm -rf "$D"

# ---- CASE 13 — P2 / read-only: topology substrate + intent store byte-untouched after a reconcile run --
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "13 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "13 intent write"
md5of() { md5 -q "$1" 2>/dev/null || md5sum "$1" | awk '{print $1}'; }
T_BEFORE="$(md5of "$TOPOLOGY_SUBSTRATE_PATH")"; I_BEFORE="$(md5of "$INTENT_SUBSTRATE_PATH")"
bash "$RC" --invariant "$INV" --json >/dev/null 2>&1 || fail "13 reconcile rc"
T_AFTER="$(md5of "$TOPOLOGY_SUBSTRATE_PATH")"; I_AFTER="$(md5of "$INTENT_SUBSTRATE_PATH")"
[ "$T_BEFORE" = "$T_AFTER" ] || fail "13 topology substrate CHANGED — read-only VIOLATED"; ok "13 topology substrate byte-untouched (P2 read-only)"
[ "$I_BEFORE" = "$I_AFTER" ] || fail "13 intent store CHANGED — reconcile must never write intent"; ok "13 intent store byte-untouched (compute consumes the view, never authors — Doctrine 06 P2)"
rm -rf "$D"

# ---- CASE 14 — malformed intent-computed.json (.records a non-empty ARRAY) → STILL the conservation -----
#      comparator + the real enabled:false drift caught; NEVER the versioning fallthrough (CRITICAL fix).
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" false "$NOW") ]" "[]" >/dev/null 2>&1 || fail "14 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "14 intent write"
printf '%s' '{"schema_version":"1","records":[{"id":"x"}]}' > "$INTENT_COMPUTED_PATH"   # .records is an ARRAY
J14="$(bash "$RC" --invariant "$INV" --json)" || fail "14 reconcile rc"
echo "$J14" | jq -e '.invariants[0].kind == "conservation"' >/dev/null || fail "14 routed AWAY from conservation (versioning fallthrough!)"; ok "14 malformed computed → STILL kind==conservation (never the versioning-comparator fallthrough — the code-council CRITICAL is closed)"
[ "$(verdict "$J14")" = "drift" ] || fail "14 verdict $(verdict "$J14") != drift — the real enabled:false drift was laundered"; ok "14 the real enabled:false drift is STILL caught (the crecs guard normalised the malformed .records to an empty object → freshness skipped → assertion ran)"
# the discriminator is the drift_detail SHAPE: the conservation assertion emits reason:wired_target_disabled;
# the versioning comparator would emit drift_detail.specifics.structural.node_count. (missing_dimensions is the
# shared enrichment tail honestly reporting the partial map — it appears on EITHER branch, so it is not a tell.)
echo "$J14" | jq -e '.invariants[0].drift_detail.specifics.reason == "wired_target_disabled" and (.invariants[0].drift_detail.specifics.structural // null) == null' >/dev/null || fail "14 drift_detail is the versioning structural shape — versioning comparator ran!"; ok "14 drift_detail.specifics.reason == wired_target_disabled, no structural.node_count (proof: the CONSERVATION assertion ran, not the versioning comparator)"
rm -rf "$D"

# ---- CASE 15 — a conservation invariant with left_source != intent → conservation-requires-intent-source --
#      (a misconfiguration is NEVER topology-aliased, NEVER the versioning fallthrough — the IMPORTANT fix).
D="$(newcase)"; usecase "$D"; init_both "$D" covered
bash "$SUB" bulk-write "[ $(mkrls "$POL" true "$NOW") ]" "[]" >/dev/null 2>&1 || fail "15 topo write"
bash "$IST" bulk-write "[ $(mkintent "$RID" "[\"$POL\"]") ]" >/dev/null 2>&1 || fail "15 intent write"
IVD="$D/inv"; mkdir -p "$IVD"
jq -nc '{id:"inv-cons-bad-lsource", kind:"conservation", source_file:"f", source_commit:"x", left_source:"topology",
  reads_dimension:"supabase-live", right_view_kind:"rls_policy", left_view_filter:"x", right_view_filter:"x",
  assertion:"x", cadence:"on-demand", source_of_truth_ref:"x"}' > "$IVD/bad.json"
J15="$(TOPOLOGY_RECONCILE_INVARIANT_DIR="$IVD" bash "$RC" --invariant inv-cons-bad-lsource --json)" || fail "15 reconcile rc"
echo "$J15" | jq -e '.invariants[0].kind == "conservation"' >/dev/null || fail "15 not conservation kind (versioning fallthrough!)"; ok "15 left_source:topology conservation invariant STAYS the conservation comparator (no fallthrough)"
[ "$(verdict "$J15")" = "inconclusive" ] || fail "15 verdict $(verdict "$J15") != inconclusive"; ok "15 left_source != intent → inconclusive (misconfiguration, never a verdict over aliased topology)"
echo "$J15" | jq -e '.invariants[0].inconclusive_reason == "conservation-requires-intent-source"' >/dev/null || fail "15 reason wrong"; ok "15 reason conservation-requires-intent-source"
rm -rf "$D"

echo ""
echo "=== PASS — all $PASS_COUNT conservation assertions green ==="
