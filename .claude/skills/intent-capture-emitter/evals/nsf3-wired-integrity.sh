#!/usr/bin/env bash
# evals/nsf3-wired-integrity.sh — NSF-3 wired_to referential-integrity + batch-heuristic eval.
#
# Drives nsf3-wired-integrity.sh through every branch with synthetic intent ledgers + topology fixtures:
# FULL vs PARTIAL vs absent coverage, shape violations (orphan/malformed), the batch heuristic, status
# filtering (draft/superseded skipped, fulfilled checked), and the honest confident-vs-unverifiable label.
#
# Portable: bash 3.2, fresh mktemp scratch (no destructive rm of fixed paths).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GATE="$SCRIPT_DIR/../scripts/nsf3-wired-integrity.sh"
PASS=0; FAIL=0
SCRATCH="$(mktemp -d /tmp/nsf3-eval.XXXXXX)"
export INTENT_SUBSTRATE_PATH="$SCRATCH/intent-ledger.json"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topo.json"

# FULL-coverage topology with the given node ids
topo_full() { printf '{"nodes":%s,"emitters":{"code":{"coverage":"covered"},"supabase-live":{"coverage":"covered"}}}' \
  "$(printf '%s' "$1" | jq -c 'map({id:.})')" > "$TOPOLOGY_SUBSTRATE_PATH"; }
# PARTIAL-coverage topology (supabase declared-missing)
topo_partial() { printf '{"nodes":%s,"emitters":{"code":{"coverage":"covered"},"supabase-live":{"coverage":"declared-missing"}}}' \
  "$(printf '%s' "$1" | jq -c 'map({id:.})')" > "$TOPOLOGY_SUBSTRATE_PATH"; }
topo_none() { rm -f "$TOPOLOGY_SUBSTRATE_PATH"; }
led() { printf '{"schema_version":"1","records":%s}' "$1" > "$INTENT_SUBSTRATE_PATH"; }

chk() { # $1 desc  $2 expected_verdict  $3 expected_rc
  local out rc verdict
  out="$(bash "$GATE" --json 2>/dev/null)"; rc=$?
  verdict="$(printf '%s' "$out" | jq -r '.verdict' 2>/dev/null)"
  if [ "$verdict" = "$2" ] && [ "$rc" = "$3" ]; then PASS=$((PASS+1));
  else FAIL=$((FAIL+1)); echo "  FAIL: $1 — got verdict=$verdict rc=$rc, expected $2 rc=$3"; echo "        $out"; fi
}
chkfield() { # $1 desc  $2 jq-filter  $3 expected
  local out got
  out="$(bash "$GATE" --json 2>/dev/null)"
  got="$(printf '%s' "$out" | jq -r "$2" 2>/dev/null)"
  if [ "$got" = "$3" ]; then PASS=$((PASS+1));
  else FAIL=$((FAIL+1)); echo "  FAIL: $1 — '$2' got '$got', expected '$3'"; echo "        $out"; fi
}

# 1 ok: all resolved on a FULL map
topo_full '["public.deals","src/a.ts"]'
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":["public.deals"]}]'
chk "all resolved, FULL map" referential_integrity_ok 0
# 2 broken on FULL: unresolved target -> broken_pointers
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":["public.ghost"]}]'
chk "unresolved on FULL map" broken_pointers 1
chkfield "label is confident on FULL" '.unresolved_label' "wired_to_target_absent"
# 3 unverifiable on PARTIAL: unresolved target -> unverifiable (NOT broken)
topo_partial '["public.deals"]'
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":["rls.deals.select"]}]'
chk "unresolved on PARTIAL map" referential_integrity_unverifiable 0
chkfield "label is unverifiable on PARTIAL" '.unresolved_label' "wired_to_target_unverifiable"
# 4 pending -> ok
topo_full '["public.deals"]'
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":"pending"}]'
chk "pending wired_to" referential_integrity_ok 0
# 5 orphan: accepted, wired_to null -> broken (shape)
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":null}]'
chk "orphan (accepted, null wired_to)" broken_pointers 1
# 6 malformed: empty array
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":[]}]'
chk "malformed (empty array)" broken_pointers 1
# 7 malformed: non-string entry
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":[123]}]'
chk "malformed (non-string entry)" broken_pointers 1
# 8 topology_unavailable: no topo, shape clean
topo_none
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":["public.deals"]}]'
chk "topology absent, shape clean" topology_unavailable 0
# 8b topology absent BUT shape violation still surfaces as broken
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":null}]'
chk "topology absent + orphan -> broken" broken_pointers 1
# 9 uninitialised: no ledger
rm -f "$INTENT_SUBSTRATE_PATH"
chk "uninitialised (no ledger)" uninitialised 4
# 10 corrupt: .records not array
printf '{"schema_version":"1","records":{"a":1}}' > "$INTENT_SUBSTRATE_PATH"
chk "corrupt (.records not array)" corrupt 6
# 11 batch heuristic on FULL: 5 same (emitter,kind) unresolved -> possible_emitter_id_format_change
topo_full '["x"]'
led "$(jq -nc '[range(0;5) | {id:("r\(.)"),status:"accepted",emitter:"roadmap_parser",kind:"roadmap_item",wired_to:["ghost\(.)"]}]')"
chk "batch on FULL: 5 same group" broken_pointers 1
chkfield "batch flag fires (>=5)" '.batch_flags | length' "1"
chkfield "batch flag names the group" '.batch_flags[0].count' "5"
# 12 batch heuristic also on PARTIAL (pattern detector regardless of confidence)
topo_partial '["x"]'
led "$(jq -nc '[range(0;6) | {id:("r\(.)"),status:"accepted",emitter:"adr_parser",kind:"adr",wired_to:["ghost\(.)"]}]')"
chk "batch on PARTIAL still fires" referential_integrity_unverifiable 0
chkfield "batch flag fires on PARTIAL" '.batch_flags | length' "1"
# 13 below threshold: 4 same group -> NO batch flag
topo_full '["x"]'
led "$(jq -nc '[range(0;4) | {id:("r\(.)"),status:"accepted",emitter:"roadmap_parser",kind:"roadmap_item",wired_to:["ghost\(.)"]}]')"
chkfield "below threshold: no batch flag" '.batch_flags | length' "0"
# 14 draft + superseded skipped; only fulfilled+accepted checked
topo_full '["real"]'
led '[{"id":"d","status":"draft","emitter":"destination_parser","kind":"destination","wired_to":["ghost"]},{"id":"s","status":"superseded","emitter":"destination_parser","kind":"destination","wired_to":["ghost"]},{"id":"f","status":"fulfilled","emitter":"destination_parser","kind":"destination","wired_to":["real"]}]'
chk "draft+superseded skipped, fulfilled resolved" referential_integrity_ok 0
chkfield "checked_count excludes draft+superseded" '.checked_count' "1"
# 15 fulfilled with unresolved target IS flagged
led '[{"id":"f","status":"fulfilled","emitter":"destination_parser","kind":"destination","wired_to":["ghost"]}]'
chk "fulfilled unresolved -> broken (FULL)" broken_pointers 1
# 16 bare-string wired_to single id resolves
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":"real"}]'
chk "bare-string wired_to resolves" referential_integrity_ok 0
# 17 --json carries required fields
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":["ghost"]}]'
chkfield "--json has the contract fields" '(has("verdict") and has("unresolved") and has("batch_flags") and has("shape_violations") and has("unresolved_label") and has("topology_coverage") and has("observed_at"))' "true"
# 18 A9 partial-list: multi-element wired_to, ONE member absent -> flagged, ONLY the absent one enumerated (never silent ok)
topo_full '["public.deals","public.users"]'
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":["public.deals","public.ghost"]}]'
chk "A9 partial list: one absent member flagged" broken_pointers 1
chkfield "A9: only the absent target enumerated" '.unresolved[0].unresolved_targets | join(",")' "public.ghost"
# 19 A9 partial-list all-present -> ok (no false flag when every member resolves)
led '[{"id":"a","status":"accepted","emitter":"destination_parser","kind":"destination","wired_to":["public.deals","public.users"]}]'
chk "A9 partial list: all members resolve -> ok" referential_integrity_ok 0

echo "== NSF-3 RESULT: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
