#!/usr/bin/env bash
# evals/nsf1-staleness.sh — NSF-1 intent-staleness watchdog eval.
#
# Drives nsf1-staleness-gate.sh through every verdict branch with synthetic ledgers carrying
# epoch-relative timestamps (so "200 days ago" is deterministic regardless of run date — no fixture
# rot). Builds minimal ledgers (the gate reads only id/status/timestamp/acceptance_cadence).
#
# Portable: bash 3.2, jq-only ISO via todateiso8601, fresh mktemp scratch (no destructive rm of fixed paths).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GATE="$SCRIPT_DIR/../scripts/nsf1-staleness-gate.sh"
NOW="$(date -u +%s)"
PASS=0; FAIL=0

# build a ledger at $LEDGER from a JSON array of partial records, expanding $D (days-ago) markers to ISO.
# a record is {id, status, cad, days}  (days null => timestamp null; negative => future-dated)
mk() { # $1 = records-json (jq array of {id,status,cad,days})
  printf '%s' "$1" | jq -c --argjson now "$NOW" '
    { schema_version:"1", entity:"test", last_updated:"x",
      records: [ .[] | {
        id, status,
        acceptance_cadence: (.cad // null),
        timestamp: (if .days == null then null else (($now - (.days*86400)) | todateiso8601) end)
      } ],
      emitters:{} }' > "$LEDGER"
}
chk() { # $1 desc  $2 expected_verdict  $3 expected_rc
  local out rc verdict
  out="$(INTENT_SUBSTRATE_PATH="$LEDGER" bash "$GATE" --json 2>/dev/null)"; rc=$?
  verdict="$(printf '%s' "$out" | jq -r '.verdict' 2>/dev/null)"
  if [ "$verdict" = "$2" ] && [ "$rc" = "$3" ]; then
    PASS=$((PASS+1)); # echo "  PASS: $1"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $1 — got verdict=$verdict rc=$rc, expected verdict=$2 rc=$3"; echo "        out: $out"
  fi
}

SCRATCH="$(mktemp -d /tmp/nsf1-eval.XXXXXX)"; LEDGER="$SCRATCH/intent-ledger.json"

# 1 fresh: accepted, 10d ago, monthly(30)
mk '[{"id":"a","status":"accepted","cad":"monthly","days":10}]';                chk "fresh within monthly cadence" fresh_intent 0
# 2 stale: accepted, 200d ago, quarterly(90)
mk '[{"id":"a","status":"accepted","cad":"quarterly","days":200}]';             chk "stale beyond quarterly cadence" stale_intent 1
# 3 stale via default: accepted, 100d ago, cadence null (default 90)
mk '[{"id":"a","status":"accepted","cad":null,"days":100}]';                    chk "stale via 90d default" stale_intent 1
# 4 fresh via default: accepted, 30d ago, cadence null (default 90)
mk '[{"id":"a","status":"accepted","cad":null,"days":30}]';                     chk "fresh via 90d default" fresh_intent 0
# 5 anomaly no timestamp
mk '[{"id":"a","status":"accepted","cad":"monthly","days":null}]';             chk "anomaly: null timestamp" anomalous 3
# 6 anomaly future-dated (5d in future)
mk '[{"id":"a","status":"accepted","cad":"monthly","days":-5}]';               chk "anomaly: future-dated" anomalous 3
# 7 anomaly unrecognised cadence
mk '[{"id":"a","status":"accepted","cad":"whenever","days":10}]';              chk "anomaly: unrecognised cadence" anomalous 3
# 8 draft NOT checked (500d-old draft + fresh accepted) => fresh
mk '[{"id":"d","status":"draft","cad":"daily","days":500},{"id":"a","status":"accepted","cad":"monthly","days":3}]'; chk "draft skipped, accepted fresh" fresh_intent 0
# 9 no accepted (only superseded)
mk '[{"id":"s","status":"superseded","cad":"monthly","days":500}]';            chk "no accepted records" no_accepted_intent 4
# 10 uninitialised (no ledger file)
rm -f "$LEDGER"; chk "uninitialised (no ledger)" uninitialised 4
# 11 corrupt (.records is an object, not array)
printf '{"schema_version":"1","records":{"a":1}}' > "$LEDGER";                  chk "corrupt: .records not array" corrupt 6
# 12 numeric cadence "90d", 100d ago => stale
mk '[{"id":"a","status":"accepted","cad":"90d","days":100}]';                   chk "numeric 90d cadence stale" stale_intent 1
# 13 daily cadence, 2d ago => stale
mk '[{"id":"a","status":"accepted","cad":"daily","days":2}]';                   chk "daily cadence stale at 2d" stale_intent 1
# 14 multiple overdue listed (both accepted, both stale)
mk '[{"id":"a","status":"accepted","cad":"monthly","days":100},{"id":"b","status":"accepted","cad":"monthly","days":200}]'
out="$(INTENT_SUBSTRATE_PATH="$LEDGER" bash "$GATE" --json 2>/dev/null)"
n_over="$(printf '%s' "$out" | jq -r '.overdue | length' 2>/dev/null)"
if [ "$n_over" = "2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL: lists all overdue — got $n_over, expected 2"; fi
# 15 --json carries the required fields
mk '[{"id":"a","status":"accepted","cad":"monthly","days":10}]'
out="$(INTENT_SUBSTRATE_PATH="$LEDGER" bash "$GATE" --json 2>/dev/null)"
ok="$(printf '%s' "$out" | jq -r 'has("verdict") and has("overdue") and has("anomalies") and has("accepted_count") and has("observed_at")' 2>/dev/null)"
if [ "$ok" = "true" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL: --json shape — $out"; fi
# 16 semiannual recognised (182d): accepted 100d ago => fresh (within 182)
mk '[{"id":"a","status":"accepted","cad":"semiannually","days":100}]';         chk "semiannual within window" fresh_intent 0
# 17 annual recognised (365): accepted 400d ago => stale
mk '[{"id":"a","status":"accepted","cad":"annually","days":400}]';             chk "annual stale at 400d" stale_intent 1

echo "== NSF-1 RESULT: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
