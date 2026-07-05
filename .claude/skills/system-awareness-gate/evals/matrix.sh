#!/usr/bin/env bash
# system-awareness-gate/evals/matrix.sh — the anti-theatre eval for /topology align's honest-degradation matrix.
#
# Asserts the R0–R7 governing-rule matrix (spec §3.3) via the dependency-injection seam
# (TOPOLOGY_ALIGN_HEALTH_JSON + TOPOLOGY_ALIGN_RECONCILE_JSON) — no live substrate needed. Every rule has a
# fixture; the four named false-green/masking cells (C1 STALE_AND_PARTIAL×INCONCLUSIVE, C2 FRESH×reconcile-
# never-ran, C3 ANOMALOUS×IN_SYNC, T1 STALE×UNVERIFIABLE) have dedicated fixtures. A universal sweep proves
# NO fixture except R7 (FRESH+IN_SYNC) ever sets licensed_aligned=true.
#
# NB: assertions read licensed_aligned with an explicit true/false/ERR conditional, NEVER `// "ERR"` —
# jq's `//` treats a genuine `false` as empty and would rewrite it to the fallback (the false-coalescing trap).
#
# Exit 0 if all pass, 1 if any fail. Mirrors the topology-health-check eval style.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALIGN="$SCRIPT_DIR/../scripts/topology-align.sh"

PASS=0; FAIL=0
echo "system-awareness-gate matrix eval"
echo "================================="

# bool-read that does NOT fall into jq's false-coalescing trap
BOOLQ='if .licensed_aligned==true then "true" elif .licensed_aligned==false then "false" else "ERR" end'

# health fixtures
H_UNINIT='{"verdict":"UNINITIALISED","emitters":{},"node_total":0}'
H_CORRUPT='{"verdict":"CORRUPT","emitters":{},"node_total":0,"integrity_detail":"orphan edge edge_x->missing"}'
H_ANOM='{"verdict":"ANOMALOUS","conditions":["anomalous"],"emitters":{"code":{"coverage":"covered"},"supabase-live":{"coverage":"declared-missing"},"n8n-cloud":{"coverage":"declared-missing"}},"node_total":50}'
H_FRESH='{"verdict":"FRESH","emitters":{"code":{"coverage":"covered"},"supabase-live":{"coverage":"covered"},"n8n-cloud":{"coverage":"covered"}},"node_total":2423,"last_updated":"2026-06-06T00:00:00Z"}'
H_STALE='{"verdict":"STALE","emitters":{"code":{"coverage":"covered","stale":true},"supabase-live":{"coverage":"covered"},"n8n-cloud":{"coverage":"covered"}},"node_total":2423}'
H_PARTIAL='{"verdict":"PARTIAL","emitters":{"code":{"coverage":"covered"},"supabase-live":{"coverage":"declared-missing"},"n8n-cloud":{"coverage":"declared-missing"}},"node_total":988}'
H_SAP='{"verdict":"STALE_AND_PARTIAL","emitters":{"code":{"coverage":"covered","stale":true},"supabase-live":{"coverage":"declared-missing"},"n8n-cloud":{"coverage":"declared-missing"}},"node_total":988}'
H_BOGUS='{"verdict":"BOGUS_VERDICT","emitters":{},"node_total":0}'
H_MALFORMED='not json at all {{{'

# reconcile fixtures
R_INSYNC='{"summary":"IN_SYNC","drift_count":0,"invariants":[]}'
R_DRIFT='{"summary":"DRIFT","drift_count":2,"invariants":[{"id":"workflow-n8n","verdict":"drift","named_action":"reconcile","affected_nodes":["n1","n2"]}]}'
R_PARTIAL='{"summary":"PARTIAL","drift_count":1,"invariants":[]}'
R_INCONC='{"summary":"INCONCLUSIVE","drift_count":0,"invariants":[]}'
R_UNVERIF='{"summary":"UNVERIFIABLE","drift_count":0,"invariants":[]}'
R_UNINIT='{"summary":"UNINITIALISED","drift_count":0,"invariants":[]}'
R_NOINV='{"summary":"no-invariants-registered","drift_count":0,"invariants":[]}'
R_NOSUMMARY='{"drift_count":0,"invariants":[]}'
R_CORRUPT='{"summary":"CORRUPT","drift_count":0,"invariants":[]}'
R_PENDING='{"summary":"pending_verification","drift_count":0,"invariants":[]}'
R_WEIRD='{"summary":"WEIRD_VAL","drift_count":0,"invariants":[]}'

# assert_verdict <name> <health> <reconcile> <expected_av> <expected_aligned>
assert_verdict() {
  name="$1"; hj="$2"; rj="$3"; exp_av="$4"; exp_al="$5"
  out="$(TOPOLOGY_ALIGN_HEALTH_JSON="$hj" TOPOLOGY_ALIGN_RECONCILE_JSON="$rj" bash "$ALIGN" --json 2>/dev/null)"
  av="$(printf '%s' "$out" | jq -r '.alignment_verdict // "ERR"' 2>/dev/null)"
  al="$(printf '%s' "$out" | jq -r "$BOOLQ" 2>/dev/null)"
  if [ "$av" = "$exp_av" ] && [ "$al" = "$exp_al" ]; then
    echo "  PASS  $name  (av=$av aligned=$al)"; PASS=$((PASS+1))
  else
    echo "  FAIL  $name  (got av=$av aligned=$al; want av=$exp_av aligned=$exp_al)"; FAIL=$((FAIL+1))
  fi
}

# assert_headline <name> <health> <reconcile> <substring>
assert_headline() {
  name="$1"; hj="$2"; rj="$3"; needle="$4"
  out="$(TOPOLOGY_ALIGN_HEALTH_JSON="$hj" TOPOLOGY_ALIGN_RECONCILE_JSON="$rj" bash "$ALIGN" --json 2>/dev/null)"
  hl="$(printf '%s' "$out" | jq -r '.headline // ""' 2>/dev/null)"
  case "$hl" in
    *"$needle"*) echo "  PASS  $name"; PASS=$((PASS+1));;
    *) echo "  FAIL  $name  (headline missing '$needle')"; FAIL=$((FAIL+1));;
  esac
}

# assert_text <name> <health> <reconcile> <present> <forbidden|->
assert_text() {
  name="$1"; hj="$2"; rj="$3"; needle="$4"; forbid="$5"
  out="$(TOPOLOGY_ALIGN_HEALTH_JSON="$hj" TOPOLOGY_ALIGN_RECONCILE_JSON="$rj" bash "$ALIGN" 2>/dev/null)"
  ok=1
  case "$out" in *"$needle"*) :;; *) ok=0;; esac
  if [ "$forbid" != "-" ]; then case "$out" in *"$forbid"*) ok=0;; esac; fi
  if [ "$ok" = "1" ]; then echo "  PASS  $name"; PASS=$((PASS+1)); else echo "  FAIL  $name  (want '$needle', forbid '$forbid')"; FAIL=$((FAIL+1)); fi
}

echo "-- governing rules R0-R7 --"
assert_verdict "R1 UNINITIALISED -> NO_MAP"            "$H_UNINIT"   "$R_INSYNC"  "NO_MAP"              "false"
assert_verdict "R2 CORRUPT -> MAP_CORRUPT"             "$H_CORRUPT"  "$R_INSYNC"  "MAP_CORRUPT"         "false"
assert_verdict "R3/C3 ANOMALOUS x IN_SYNC suppressed"  "$H_ANOM"     "$R_INSYNC"  "MAP_ANOMALOUS"       "false"
assert_verdict "R3 ANOMALOUS x DRIFT"                  "$H_ANOM"     "$R_DRIFT"   "MAP_ANOMALOUS_DRIFT" "false"
assert_verdict "R4 FRESH x INCONCLUSIVE -> NO_CLAIM"   "$H_FRESH"    "$R_INCONC"  "NO_CLAIM"            "false"
assert_verdict "R4/C1 STALE_AND_PARTIAL x INCONCLUSIVE" "$H_SAP"     "$R_INCONC"  "NO_CLAIM"            "false"
assert_verdict "R4/C2 FRESH x reconcile-never-ran"     "$H_FRESH"    "$R_NOSUMMARY" "NO_CLAIM"          "false"
assert_verdict "R4/C2b FRESH x reconcile-UNINITIALISED" "$H_FRESH"   "$R_UNINIT"  "NO_CLAIM"            "false"
assert_verdict "R4/T1 STALE x UNVERIFIABLE"            "$H_STALE"    "$R_UNVERIF" "NO_CLAIM"            "false"
assert_verdict "R4 FRESH x no-invariants-registered"   "$H_FRESH"    "$R_NOINV"   "NO_CLAIM"            "false"
assert_verdict "R4 FRESH x reconcile-CORRUPT"          "$H_FRESH"    "$R_CORRUPT" "NO_CLAIM"            "false"
assert_verdict "R4 FRESH x pending_verification"       "$H_FRESH"    "$R_PENDING" "NO_CLAIM"            "false"
assert_verdict "R5 FRESH x DRIFT"                      "$H_FRESH"    "$R_DRIFT"   "DRIFT"               "false"
assert_verdict "R5 STALE x DRIFT (compound)"           "$H_STALE"    "$R_DRIFT"   "DRIFT"               "false"
assert_verdict "R6 reconcile PARTIAL"                  "$H_FRESH"    "$R_PARTIAL" "PARTIAL_IN_SYNC"     "false"
assert_verdict "R6 STALE x IN_SYNC"                    "$H_STALE"    "$R_INSYNC"  "PARTIAL_IN_SYNC"     "false"
assert_verdict "R6 PARTIAL x IN_SYNC"                  "$H_PARTIAL"  "$R_INSYNC"  "PARTIAL_IN_SYNC"     "false"
assert_verdict "R7 FRESH x IN_SYNC -> ALIGNED"         "$H_FRESH"    "$R_INSYNC"  "ALIGNED"             "true"
assert_verdict "R0 FRESH x unknown-summary"            "$H_FRESH"    "$R_WEIRD"   "UNEXPECTED"          "false"
assert_verdict "R0 unknown-health"                     "$H_BOGUS"    "$R_INSYNC"  "UNEXPECTED"          "false"
assert_verdict "UNREADABLE health"                     "$H_MALFORMED" "$R_INSYNC" "UNEXPECTED"          "false"

echo "-- headline content (anti-masking, A4 legibility) --"
assert_headline "C1 names DOUBLE-degraded"   "$H_SAP"     "$R_INCONC"    "DOUBLE-degraded"
assert_headline "C2 names NEVER assessed"    "$H_FRESH"   "$R_NOSUMMARY" "NEVER been assessed"
assert_headline "C3 names NOT reliable"      "$H_ANOM"    "$R_INSYNC"    "NOT reliable"
assert_headline "R5 names also STALE"        "$H_STALE"   "$R_DRIFT"     "also STALE"
assert_headline "R6 names coverage ratio"    "$H_PARTIAL" "$R_INSYNC"    "of 3 emitters"

echo "-- text-mode surface --"
assert_text "FROM-SCRATCH offers build, no false-green" "$H_UNINIT" "$R_INSYNC" "Run the topology emitters" "fully alignment-checkable"
assert_text "R7 text says fully alignment-checkable"    "$H_FRESH"  "$R_INSYNC" "fully alignment-checkable" "-"
assert_text "R6 partial text says partial coverage only" "$H_STALE" "$R_INSYNC" "partial coverage only" "-"

echo "-- UNIVERSAL SWEEP: only R7 licenses aligned=true --"
SWEEP_FAIL=0
sweep_one() {
  hlabel="$1"; hjson="$2"; rlabel="$3"; rjson="$4"
  a="$(TOPOLOGY_ALIGN_HEALTH_JSON="$hjson" TOPOLOGY_ALIGN_RECONCILE_JSON="$rjson" bash "$ALIGN" --json 2>/dev/null | jq -r "$BOOLQ")"
  if [ "$hlabel" = "FRESH" ] && [ "$rlabel" = "IN_SYNC" ]; then
    [ "$a" = "true" ] || { echo "  FAIL sweep $hlabel x $rlabel expected true got $a"; SWEEP_FAIL=$((SWEEP_FAIL+1)); }
  else
    [ "$a" = "false" ] || { echo "  FAIL sweep $hlabel x $rlabel leaked aligned=$a"; SWEEP_FAIL=$((SWEEP_FAIL+1)); }
  fi
}
for HROW in "FRESH" "STALE" "PARTIAL" "SAP" "ANOM" "CORRUPT" "UNINIT" "BOGUS"; do
  case "$HROW" in
    FRESH) HJ="$H_FRESH";; STALE) HJ="$H_STALE";; PARTIAL) HJ="$H_PARTIAL";; SAP) HJ="$H_SAP";;
    ANOM) HJ="$H_ANOM";; CORRUPT) HJ="$H_CORRUPT";; UNINIT) HJ="$H_UNINIT";; BOGUS) HJ="$H_BOGUS";;
  esac
  for RROW in "IN_SYNC" "DRIFT" "PARTIAL" "INCONC" "UNVERIF" "UNINIT" "NOINV" "NOSUM" "CORRUPT" "PENDING" "WEIRD"; do
    case "$RROW" in
      IN_SYNC) RJ="$R_INSYNC";; DRIFT) RJ="$R_DRIFT";; PARTIAL) RJ="$R_PARTIAL";; INCONC) RJ="$R_INCONC";;
      UNVERIF) RJ="$R_UNVERIF";; UNINIT) RJ="$R_UNINIT";; NOINV) RJ="$R_NOINV";; NOSUM) RJ="$R_NOSUMMARY";;
      CORRUPT) RJ="$R_CORRUPT";; PENDING) RJ="$R_PENDING";; WEIRD) RJ="$R_WEIRD";;
    esac
    sweep_one "$HROW" "$HJ" "$RROW" "$RJ"
  done
done
if [ "$SWEEP_FAIL" = "0" ]; then echo "  PASS  universal sweep (88 cells: only FRESH x IN_SYNC licensed aligned)"; PASS=$((PASS+1)); else echo "  FAIL  universal sweep ($SWEEP_FAIL leak(s))"; FAIL=$((FAIL+1)); fi

echo "================================="
if [ "$FAIL" = "0" ]; then
  echo "system-awareness-gate matrix eval: ALL PASS ($PASS checks)"; exit 0
fi
echo "system-awareness-gate matrix eval: $FAIL FAILURE(S) ($PASS passed)" >&2; exit 1
