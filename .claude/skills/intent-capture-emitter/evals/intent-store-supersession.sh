#!/usr/bin/env bash
# evals/intent-store-supersession.sh — intent-store.sh supersession + read-API eval (council A8).
# Promoted from the build-time smoke test. Exercises the hardest store paths: terminal chain, 2-node
# cycle, self-supersede, broken pointer, two-terminals conflict, the orphan guard, and get/read/slice.
# Portable: bash 3.2, fresh mktemp scratch (no destructive rm of fixed paths).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
STORE="$SCRIPT_DIR/../scripts/intent-store.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
scratch() { export INTENT_SUBSTRATE_PATH="$(mktemp -d /tmp/intent-store-eval.XXXXXX)/intent-ledger.json"; }

mkrec() { # id kind title status superseded_by
  jq -n --arg id "$1" --arg kind "$2" --arg title "$3" --arg status "$4" --arg sb "$5" '
    {id:$id, kind:$kind, source_file:"DESTINATION.md", source_commit:"abc123", timestamp:"2026-06-07T00:00:00Z",
     title:$title, status:$status, superseded_by: (if $sb=="" then null else $sb end),
     conditions:"the promise", binary_test:"a third party checks X", falsifier:null,
     wired_to:"public.deals", owner:"lead", acceptance_cadence:"90d", emitter:"destination_parser"}'
}

# 0. syntax + apostrophe balance
bash -n "$STORE" && ok || bad "bash -n clean"
q=$(grep -o "'" "$STORE" | wc -l | tr -d ' '); [ $((q % 2)) -eq 0 ] && ok || bad "single-quotes balanced ($q)"

# A. clean ledger: R1 superseded_by R2 (terminal); get/read/slice
scratch
bash "$STORE" init buybox-ai >/dev/null && ok || bad "init"
bash "$STORE" bulk-write "[$(mkrec R1 destination 'billing access old' accepted R2),$(mkrec R2 destination 'billing access' accepted '')]" >/dev/null && ok || bad "bulk-write 2"
[ "$(bash "$STORE" validate-schema)" = "PASS" ] && ok || bad "validate PASS"
[ "$(bash "$STORE" get billing | jq -r '.record.id // .verdict')" = "R2" ] && ok || bad "get(billing) -> terminal R2"
bash "$STORE" get nonexistent-topic >/dev/null 2>&1; [ $? -eq 7 ] && ok || bad "get(missing) rc7"
[ "$(bash "$STORE" read R2 | jq -r '.title')" = "billing access" ] && ok || bad "read(R2)"
[ "$(bash "$STORE" slice billing 'wired_to,falsifier' | jq -r '.wired_to')" = "public.deals" ] && ok || bad "slice(billing)"

# B. 2-node cycle C1<->C2: validate PASS (cycle is not a broken pointer); get -> chain_broken rc7
scratch; bash "$STORE" init buybox-ai >/dev/null
bash "$STORE" bulk-write "[$(mkrec C1 adr 'cycle topic' accepted C2),$(mkrec C2 adr 'cycle topic' accepted C1)]" >/dev/null
[ "$(bash "$STORE" validate-schema)" = "PASS" ] && ok || bad "validate PASS (cycle not broken pointer)"
GV=$(bash "$STORE" get cycle | jq -r '.verdict'); bash "$STORE" get cycle >/dev/null 2>&1; GRC=$?
{ [ "$GV" = "supersession_chain_broken" ] && [ "$GRC" -eq 7 ]; } && ok || bad "get(cycle) -> chain_broken rc7 (got $GV rc$GRC)"

# B2. self-supersede A->A
scratch; bash "$STORE" init buybox-ai >/dev/null
bash "$STORE" bulk-write "[$(mkrec SELF adr 'self loop' accepted SELF)]" >/dev/null
[ "$(bash "$STORE" get 'self loop' | jq -r '.verdict')" = "supersession_chain_broken" ] && ok || bad "self-supersede -> chain_broken"

# C. broken pointer B1->ghost: validate VIOLATION; get -> chain_broken
scratch; bash "$STORE" init buybox-ai >/dev/null
bash "$STORE" bulk-write "[$(mkrec B1 adr 'broken topic' accepted ghost-nonexistent)]" >/dev/null
[ "$(bash "$STORE" validate-schema 2>/dev/null | head -1)" = "VIOLATIONS:" ] && ok || bad "validate flags broken pointer"
[ "$(bash "$STORE" get 'broken topic' | jq -r '.verdict')" = "supersession_chain_broken" ] && ok || bad "get(broken) -> chain_broken"

# D. two terminals on one topic -> conflict
scratch; bash "$STORE" init buybox-ai >/dev/null
bash "$STORE" bulk-write "[$(mkrec T1 destination 'dup topic' accepted ''),$(mkrec T2 destination 'dup topic' accepted '')]" >/dev/null
[ "$(bash "$STORE" get 'dup topic' | jq -r '.verdict')" = "supersession_conflict" ] && ok || bad "get(dup) -> conflict"

# E. orphan guard: accepted + wired_to null -> rejected rc2
scratch; bash "$STORE" init buybox-ai >/dev/null
ORPH=$(jq -n '{id:"O1",kind:"destination",source_file:"D.md",source_commit:"x",timestamp:"2026-06-07T00:00:00Z",title:"orphan",status:"accepted",superseded_by:null,conditions:"c",binary_test:"b",falsifier:null,wired_to:null,owner:"o",acceptance_cadence:"90d"}')
bash "$STORE" bulk-write "[$ORPH]" >/dev/null 2>&1; [ $? -eq 2 ] && ok || bad "orphan rejected rc2"

# F. upsert-by-id (D8): re-write same id updates in place, never auto-marks supersession
scratch; bash "$STORE" init buybox-ai >/dev/null
bash "$STORE" bulk-write "[$(mkrec U1 destination 'upsert topic' accepted '')]" >/dev/null
bash "$STORE" bulk-write "[$(mkrec U1 destination 'upsert topic v2' accepted '')]" >/dev/null
n=$(bash "$STORE" read-intent | jq -r '.records | length'); [ "$n" = "1" ] && ok || bad "upsert-by-id keeps 1 record (got $n)"
[ "$(bash "$STORE" read U1 | jq -r '.title')" = "upsert topic v2" ] && ok || bad "upsert updates in place"
[ "$(bash "$STORE" read U1 | jq -r '.superseded_by')" = "null" ] && ok || bad "upsert never auto-marks supersession (D8)"

echo "== INTENT-STORE RESULT: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
