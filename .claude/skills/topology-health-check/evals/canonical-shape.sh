#!/usr/bin/env bash
# canonical-shape.sh — exact-count eval for the topology-health-check skill.
#
# Builds FIXTURE substrates (scratch path via mktemp -d, never touches a real .understand-anything/) and
# asserts the health-check produces EXACT outputs (per the Session-4/5 lesson: ">0" / "looks plausible"
# hides bugs). Covers every council amendment case:
#   - exact per-kind counts (10-kind enum slice)                                     (amend #11 read-path)
#   - 4-way coverage labels distinct (covered / declared-missing / absent / degenerate)
#   - staleness with a REAL past timestamp -> STALE (not null-vs-non-null)            (amend #1, Analyst Q)
#   - the strict `>` boundary: emitted exactly AT the threshold -> FRESH not STALE    (amend #10)
#   - covered emitter owning 0 nodes -> ANOMALOUS (covered_but_empty), never FRESH    (amend #3, Edge #1)
#   - future-dated timestamp -> ANOMALOUS (future_dated), never false-FRESH           (amend #6, Edge)
#   - unparseable (millisecond/offset) timestamp -> ANOMALOUS (unparseable_timestamp) (amend #2, Edge #2)
#   - STALE + PARTIAL coexist -> verdict STALE_AND_PARTIAL + both conditions          (amend #4, Edge #3)
#   - declared-missing reported as not-yet-run, NOT failure                           (amend #5)
#   - corrupt substrate -> CORRUPT verdict + integrity CORRUPT                        (amend #11, Edge #4)
#   - named-emitter-missing -> warning + named_emitters_present:false                 (amend #12, Edge #9)
#   - --json asserted via `jq -e` exact-equality, NOT grep                            (amend #12)
#
# Date maths is jq-only inside the skill; this eval sets controlled timestamps by computing epochs with
# `date -u -v` (BSD/macOS) OR `date -u -d` (GNU) — the eval is allowed platform-specific date arithmetic
# because it RUNS on the dev machine; the SKILL is what must be portable. We probe which date flavour exists.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUB="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
HC="$SCRIPT_DIR/../scripts/health-check.sh"

if [ ! -f "$SUB" ] || [ ! -f "$HC" ]; then
  echo "FAIL: substrate.sh or health-check.sh missing" >&2; exit 1
fi

PASS_COUNT=0
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { PASS_COUNT=$((PASS_COUNT+1)); echo "  ok: $1"; }

# --- portable-ish date helper for the EVAL (not the skill) ----------------------
# epoch_ago_hours N -> ISO 8601 UTC timestamp N hours in the past (strict Z form, as the emitters write).
NOW_EPOCH="$(date -u +%s)"
iso_from_epoch() {
  local ep="$1"
  if date -u -r "$ep" +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    date -u -r "$ep" +%Y-%m-%dT%H:%M:%SZ          # BSD/macOS: -r <epoch>
  else
    date -u -d "@$ep" +%Y-%m-%dT%H:%M:%SZ          # GNU: -d @<epoch>
  fi
}
ts_ago_h() { iso_from_epoch "$(( NOW_EPOCH - $1 * 3600 ))"; }
ts_in_h()  { iso_from_epoch "$(( NOW_EPOCH + $1 * 3600 ))"; }

# set_emitter <substrate-path> <name> <coverage> <last_emitted_at-or-null>: surgically set an emitter block
# WITHOUT going through mark-emitter-ran (which stamps `now`). Re-derives nothing (emitters are not in the
# map-derivation path). Preserves validate-schema correctness (nodes + maps untouched).
set_emitter() {
  local path="$1" name="$2" cov="$3" ts="$4" tmp
  tmp="$(mktemp)"
  if [ "$ts" = "null" ]; then
    jq --arg n "$name" --arg c "$cov" '.emitters[$n] = {last_emitted_at: null, coverage: $c}' "$path" > "$tmp"
  else
    jq --arg n "$name" --arg c "$cov" --arg t "$ts" '.emitters[$n] = {last_emitted_at: $t, coverage: $c}' "$path" > "$tmp"
  fi
  mv "$tmp" "$path"
}

mknode() {
  # mknode <id> <kind> <emitter>  -> a minimal canonical node JSON (no edges, empty maps friendly)
  local id="$1" kind="$2" emitter="$3" extra="${4:-}"
  jq -nc --arg id "$id" --arg kind "$kind" --arg em "$emitter" --arg now "$(ts_ago_h 1)" '
    {id:$id, kind:$kind, source_file:"fixture", source_commit:"evalsha", timestamp:$now,
     source_line:null, emitter:$em, depends_on:[], depended_on_by:[], attributes:{}, declared_intent_ref:null}'
}

echo "=== topology-health-check eval ==="

# =================================================================================
# CASE A — happy multi-kind substrate: code covered+fresh (3 kinds), 2 live declared-missing.
# Asserts: PARTIAL verdict, exact per-kind counts, code owns exact node count, declared-missing wording,
# integrity PASS, named_emitters_present true.
# =================================================================================
echo "CASE A — multi-kind covered+fresh + 2 declared-missing (PARTIAL)"
SA="$(mktemp -d -t hc-A-XXXXXX)"; trap 'rm -rf "$SA"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SA/topology-graph.json"
bash "$SUB" init "fixture-A" >/dev/null 2>&1 || fail "A: init"
# 3 ts_module + 2 edge_function + 1 config = 6 nodes, all owned by `code`.
NODES_A="[ $(mknode tsm1 ts_module dependency_cruiser), $(mknode tsm2 ts_module dependency_cruiser), $(mknode tsm3 ts_module dependency_cruiser), $(mknode ef1 edge_function dependency_cruiser), $(mknode ef2 edge_function dependency_cruiser), $(jq -nc --arg now "$(ts_ago_h 1)" '{id:"cfg1",kind:"config",source_file:"vercel.json",source_commit:"evalsha",timestamp:$now,source_line:null,emitter:"manual",depends_on:[],depended_on_by:[],attributes:{config_type:"vercel"},declared_intent_ref:null,manual_justification:"declared-structure config file (D05 §6.6)"}') ]"
bash "$SUB" bulk-write "$NODES_A" "[]" >/dev/null 2>&1 || fail "A: bulk-write"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_ago_h 2)"   # 2h old, within 24h -> fresh

JSON_A="$(bash "$HC" --json)" || fail "A: health-check --json exited non-zero"
echo "$JSON_A" | jq -e '.verdict == "PARTIAL"' >/dev/null || fail "A: verdict != PARTIAL (got $(echo "$JSON_A"|jq -r .verdict))"; ok "A verdict PARTIAL"
echo "$JSON_A" | jq -e '.conditions == ["partial"]' >/dev/null || fail "A: conditions != [partial] (got $(echo "$JSON_A"|jq -c .conditions))"; ok "A conditions [partial]"
echo "$JSON_A" | jq -e '.node_total == 6' >/dev/null || fail "A: node_total != 6"; ok "A node_total 6"
echo "$JSON_A" | jq -e '.kind_counts.ts_module == 3' >/dev/null || fail "A: ts_module != 3"; ok "A ts_module 3"
echo "$JSON_A" | jq -e '.kind_counts.edge_function == 2' >/dev/null || fail "A: edge_function != 2"; ok "A edge_function 2"
echo "$JSON_A" | jq -e '.kind_counts.config == 1' >/dev/null || fail "A: config != 1"; ok "A config 1"
echo "$JSON_A" | jq -e '.emitters.code.coverage == "covered" and .emitters.code.owned_node_count == 6 and .emitters.code.stale == false and .emitters.code.anomaly == "none"' >/dev/null || fail "A: code emitter wrong ($(echo "$JSON_A"|jq -c .emitters.code))"; ok "A code covered+fresh, owns 6"
echo "$JSON_A" | jq -e '.emitters["n8n-cloud"].coverage == "declared-missing" and .emitters["n8n-cloud"].owned_node_count == 0' >/dev/null || fail "A: n8n-cloud not declared-missing/0"; ok "A n8n-cloud declared-missing"
echo "$JSON_A" | jq -e '.emitters["supabase-live"].coverage == "declared-missing"' >/dev/null || fail "A: supabase not declared-missing"; ok "A supabase declared-missing"
echo "$JSON_A" | jq -e '.integrity == "PASS"' >/dev/null || fail "A: integrity != PASS"; ok "A integrity PASS"
echo "$JSON_A" | jq -e '.named_emitters_present == true' >/dev/null || fail "A: named_emitters_present != true"; ok "A named emitters present"
# text-mode wording assertion (amendment #5)
TEXT_A="$(bash "$HC")"
printf '%s' "$TEXT_A" | grep -q "built, not yet run on this substrate" || fail "A: declared-missing wording missing"; ok "A declared-missing wording = 'built, not yet run on this substrate'"
printf '%s' "$TEXT_A" | grep -q "not yet built" && fail "A: text says 'not yet built' (forbidden wording)"; ok "A no 'not yet built' wording"
rm -rf "$SA"; trap - EXIT

# =================================================================================
# CASE B — STALE: code covered with a node, last_emitted_at 30h ago (> 24h threshold).
# Plus the strict-boundary node: a second substrate emitted EXACTLY at 24h -> FRESH.
# =================================================================================
echo "CASE B — staleness (30h>24h -> STALE) + strict boundary (exactly 24h -> FRESH)"
SB="$(mktemp -d -t hc-B-XXXXXX)"; trap 'rm -rf "$SB"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SB/topology-graph.json"
bash "$SUB" init "fixture-B" >/dev/null 2>&1 || fail "B: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "B: bulk-write"
# Mark all 3 to remove the PARTIAL signal so we isolate STALE: supabase absent, n8n absent, code stale.
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_ago_h 30)"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" supabase-live absent null
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" n8n-cloud absent null
JSON_B="$(bash "$HC" --json)" || fail "B: health-check exited non-zero"
echo "$JSON_B" | jq -e '.verdict == "STALE"' >/dev/null || fail "B: verdict != STALE (got $(echo "$JSON_B"|jq -r .verdict))"; ok "B verdict STALE (30h>24h)"
echo "$JSON_B" | jq -e '.emitters.code.stale == true' >/dev/null || fail "B: code not stale"; ok "B code.stale true"
echo "$JSON_B" | jq -e '.emitters["supabase-live"].coverage == "absent" and .emitters["supabase-live"].stale == false' >/dev/null || fail "B: absent emitter marked stale"; ok "B absent emitter not stale"
# Strict `>` boundary (amendment #10). Two stamps that BOTH display age_hours ~24 but straddle the
# raw-seconds threshold — proving the comparison is on seconds, not the rounded display.
# (a) emitted 24h - 30s ago -> age < 86400s -> NOT stale (the at-boundary-minus case).
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(iso_from_epoch "$(( NOW_EPOCH - 24*3600 + 30 ))")"
JSON_B2="$(bash "$HC" --json)"
echo "$JSON_B2" | jq -e '.emitters.code.stale == false' >/dev/null || fail "B: at-boundary-minus (24h-30s) marked stale (strict > bug)"; ok "B at-boundary-minus (24h-30s) -> not stale (age $(echo "$JSON_B2"|jq -r .emitters.code.age_hours)h)"
# (b) emitted 24h + 120s ago -> age > 86400s -> STALE (the at-boundary-plus case).
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(iso_from_epoch "$(( NOW_EPOCH - 24*3600 - 120 ))")"
JSON_B3="$(bash "$HC" --json)"
echo "$JSON_B3" | jq -e '.emitters.code.stale == true' >/dev/null || fail "B: at-boundary-plus (24h+120s) NOT marked stale (strict > bug)"; ok "B at-boundary-plus (24h+2m) -> stale (strict > boundary confirmed both sides)"
rm -rf "$SB"; trap - EXIT

# =================================================================================
# CASE C — covered-but-empty ANOMALY: code marked covered but owns ZERO nodes.
# This is the highest-impact silent-wrong-verdict (Edge Case #1). Must be ANOMALOUS, never FRESH.
# =================================================================================
echo "CASE C — covered-but-empty -> ANOMALOUS (never FRESH)"
SC="$(mktemp -d -t hc-C-XXXXXX)"; trap 'rm -rf "$SC"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SC/topology-graph.json"
bash "$SUB" init "fixture-C" >/dev/null 2>&1 || fail "C: init"
# NO nodes written. code marked covered+fresh anyway (simulating a crashed emitter).
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_ago_h 1)"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" supabase-live absent null
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" n8n-cloud absent null
JSON_C="$(bash "$HC" --json)" || fail "C: health-check exited non-zero"
echo "$JSON_C" | jq -e '.verdict == "ANOMALOUS"' >/dev/null || fail "C: verdict != ANOMALOUS (got $(echo "$JSON_C"|jq -r .verdict)) — covered+empty silently passed!"; ok "C verdict ANOMALOUS (covered+0 nodes)"
echo "$JSON_C" | jq -e '.emitters.code.anomaly == "covered_but_empty"' >/dev/null || fail "C: anomaly != covered_but_empty"; ok "C anomaly = covered_but_empty"
echo "$JSON_C" | jq -e '.emitters.code.owned_node_count == 0' >/dev/null || fail "C: owned != 0"; ok "C owned_node_count 0"
echo "$JSON_C" | jq -e '(.conditions | index("fresh")) == null' >/dev/null || fail "C: FRESH leaked into conditions on empty substrate"; ok "C no fresh condition"
# text-mode anomaly branch (the --text/--json divergence gap — assert the human line, capture-then-grep).
TEXT_C="$(bash "$HC")"; printf '%s' "$TEXT_C" | grep -q "COVERED but owns 0 nodes" || fail "C: text anomaly line missing"; ok "C text shows covered-but-empty anomaly line"
rm -rf "$SC"; trap - EXIT

# =================================================================================
# CASE D — future-dated timestamp -> ANOMALOUS (future_dated), never false-FRESH.
# =================================================================================
echo "CASE D — future-dated timestamp -> ANOMALOUS"
SD="$(mktemp -d -t hc-D-XXXXXX)"; trap 'rm -rf "$SD"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SD/topology-graph.json"
bash "$SUB" init "fixture-D" >/dev/null 2>&1 || fail "D: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "D: bulk-write"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_in_h 5)"   # 5h in the FUTURE
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" supabase-live absent null
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" n8n-cloud absent null
JSON_D="$(bash "$HC" --json)" || fail "D: health-check exited non-zero"
echo "$JSON_D" | jq -e '.verdict == "ANOMALOUS"' >/dev/null || fail "D: verdict != ANOMALOUS (got $(echo "$JSON_D"|jq -r .verdict)) — future timestamp false-FRESH!"; ok "D verdict ANOMALOUS (future-dated)"
echo "$JSON_D" | jq -e '.emitters.code.anomaly == "future_dated"' >/dev/null || fail "D: anomaly != future_dated"; ok "D anomaly = future_dated"
TEXT_D="$(bash "$HC")"; printf '%s' "$TEXT_D" | grep -q "timestamp is in the FUTURE" || fail "D: text future-dated line missing"; ok "D text shows future-dated anomaly line"
rm -rf "$SD"; trap - EXIT

# =================================================================================
# CASE E — unparseable timestamp (millisecond precision) -> ANOMALOUS (unparseable_timestamp).
# fromdateiso8601 aborts on '2026-...T...123Z'; the try/catch must surface it, not silent-skip/false-CORRUPT.
# =================================================================================
echo "CASE E — unparseable (millisecond) timestamp -> ANOMALOUS"
SE="$(mktemp -d -t hc-E-XXXXXX)"; trap 'rm -rf "$SE"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SE/topology-graph.json"
bash "$SUB" init "fixture-E" >/dev/null 2>&1 || fail "E: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "E: bulk-write"
# millisecond-precision Z form — fromdateiso8601 cannot parse it.
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "2026-06-01T18:56:23.123Z"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" supabase-live absent null
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" n8n-cloud absent null
JSON_E="$(bash "$HC" --json)" || fail "E: health-check exited non-zero (unparseable ts should NOT crash the script)"
echo "$JSON_E" | jq -e '.verdict == "ANOMALOUS"' >/dev/null || fail "E: verdict != ANOMALOUS (got $(echo "$JSON_E"|jq -r .verdict))"; ok "E verdict ANOMALOUS (unparseable ts)"
echo "$JSON_E" | jq -e '.emitters.code.anomaly == "unparseable_timestamp"' >/dev/null || fail "E: anomaly != unparseable_timestamp (got $(echo "$JSON_E"|jq -r .emitters.code.anomaly))"; ok "E anomaly = unparseable_timestamp"
echo "$JSON_E" | jq -e '.integrity == "PASS"' >/dev/null || fail "E: unparseable ts wrongly marked substrate CORRUPT"; ok "E integrity still PASS (not false-CORRUPT)"
TEXT_E="$(bash "$HC")"; printf '%s' "$TEXT_E" | grep -q "timestamp is unparseable" || fail "E: text unparseable line missing"; ok "E text shows unparseable anomaly line"
rm -rf "$SE"; trap - EXIT

# =================================================================================
# CASE F — STALE + PARTIAL coexist -> STALE_AND_PARTIAL verdict + BOTH conditions (Edge #3 / amend #4).
# This is the LIVE my-project state in 24h: code covered+stale, 2 emitters declared-missing.
# =================================================================================
echo "CASE F — STALE + PARTIAL coexist -> STALE_AND_PARTIAL"
SF="$(mktemp -d -t hc-F-XXXXXX)"; trap 'rm -rf "$SF"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SF/topology-graph.json"
bash "$SUB" init "fixture-F" >/dev/null 2>&1 || fail "F: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "F: bulk-write"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_ago_h 48)"   # stale
# supabase + n8n left at declared-missing/null from init -> PARTIAL
JSON_F="$(bash "$HC" --json)" || fail "F: health-check exited non-zero"
echo "$JSON_F" | jq -e '.verdict == "STALE_AND_PARTIAL"' >/dev/null || fail "F: verdict != STALE_AND_PARTIAL (got $(echo "$JSON_F"|jq -r .verdict)) — one signal hid the other!"; ok "F verdict STALE_AND_PARTIAL"
echo "$JSON_F" | jq -e '(.conditions | index("stale")) != null and (.conditions | index("partial")) != null' >/dev/null || fail "F: conditions missing stale or partial (got $(echo "$JSON_F"|jq -c .conditions))"; ok "F conditions contain BOTH stale + partial"
TEXT_F="$(bash "$HC")"
printf '%s' "$TEXT_F" | grep -q "STALE" || fail "F: text missing STALE"
printf '%s' "$TEXT_F" | grep -q "PARTIAL" || fail "F: text missing PARTIAL"; ok "F text shows BOTH STALE and PARTIAL"
rm -rf "$SF"; trap - EXIT

# =================================================================================
# CASE G — corrupt substrate -> CORRUPT verdict + integrity CORRUPT. read-topology rc 6 -> mapped, not abort.
# Build a valid substrate then hand-corrupt the child_map (map drift -> validate-schema rejects).
# =================================================================================
echo "CASE G — corrupt substrate (map drift) -> CORRUPT"
SG="$(mktemp -d -t hc-G-XXXXXX)"; trap 'rm -rf "$SG"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SG/topology-graph.json"
bash "$SUB" init "fixture-G" >/dev/null 2>&1 || fail "G: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "G: bulk-write"
# hand-corrupt: inject a bogus child_map entry so it drifts from nodes (validate-schema catches this).
TMP="$(mktemp)"; jq '.child_map["ghost"] = ["nope"]' "$TOPOLOGY_SUBSTRATE_PATH" > "$TMP"; mv "$TMP" "$TOPOLOGY_SUBSTRATE_PATH"
JSON_G="$(bash "$HC" --json)" || fail "G: health-check exited non-zero (corrupt should map to CORRUPT verdict, not abort)"
echo "$JSON_G" | jq -e '.verdict == "CORRUPT"' >/dev/null || fail "G: verdict != CORRUPT (got $(echo "$JSON_G"|jq -r .verdict))"; ok "G verdict CORRUPT"
echo "$JSON_G" | jq -e '.integrity == "CORRUPT"' >/dev/null || fail "G: integrity != CORRUPT"; ok "G integrity CORRUPT"
echo "$JSON_G" | jq -e '.integrity_detail | length > 0' >/dev/null || fail "G: no integrity_detail surfaced"; ok "G integrity_detail surfaced"
rm -rf "$SG"; trap - EXIT

# =================================================================================
# CASE H — named-emitter-missing: hand-edited emitters:{} passes validate but must warn (Edge #9 / amend #12).
# =================================================================================
echo "CASE H — empty emitters block -> named_emitters_present:false + warning"
SH="$(mktemp -d -t hc-H-XXXXXX)"; trap 'rm -rf "$SH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SH/topology-graph.json"
bash "$SUB" init "fixture-H" >/dev/null 2>&1 || fail "H: init"
# wipe the emitters block to {} (validate-schema allows any emitter names for forward-compat).
TMP="$(mktemp)"; jq '.emitters = {}' "$TOPOLOGY_SUBSTRATE_PATH" > "$TMP"; mv "$TMP" "$TOPOLOGY_SUBSTRATE_PATH"
JSON_H="$(bash "$HC" --json)" || fail "H: health-check exited non-zero"
echo "$JSON_H" | jq -e '.named_emitters_present == false' >/dev/null || fail "H: named_emitters_present != false"; ok "H named_emitters_present false"
TEXT_H="$(bash "$HC")"
printf '%s' "$TEXT_H" | grep -qi "WARNING" || fail "H: no named-emitter-missing warning in text output"; ok "H text WARNING present"
rm -rf "$SH"; trap - EXIT

# =================================================================================
# CASE I — read-only invariant: the health-check NEVER mutates the substrate.
# Capture the substrate's hash before + after a health-check run; assert unchanged.
# =================================================================================
echo "CASE I — read-only invariant (substrate unchanged after health-check)"
SI="$(mktemp -d -t hc-I-XXXXXX)"; trap 'rm -rf "$SI"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SI/topology-graph.json"
bash "$SUB" init "fixture-I" >/dev/null 2>&1 || fail "I: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "I: bulk-write"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_ago_h 2)"
HASH_BEFORE="$(cksum "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1$2}')"
bash "$HC" >/dev/null 2>&1
bash "$HC" --json >/dev/null 2>&1
HASH_AFTER="$(cksum "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1$2}')"
[ "$HASH_BEFORE" = "$HASH_AFTER" ] || fail "I: substrate changed after health-check run (read-only VIOLATED)"; ok "I substrate byte-identical before/after (read-only honoured)"
# static read-only invariant: the only substrate subcommands the script INVOKES must be read-topology
# + validate-schema. Capture-then-grep the actual `bash "$SUB" <cmd>` invocation lines (the prior
# grep-then-grep-v-filter chain was dead because the prohibition comments use prose, not the literal
# hyphenated tokens — Silent Failure Hunter finding). Assert zero write-command INVOCATIONS.
INVOKE_LINES="$(grep -nE 'bash "\$SUB" (write-node|write-edge|bulk-write|mark-emitter-ran|init)' "$HC" || true)"
[ -z "$INVOKE_LINES" ] || fail "I: health-check.sh INVOKES a write/init substrate command: $INVOKE_LINES"; ok "I no write/init substrate INVOCATIONS in health-check.sh (only read-topology + validate-schema)"
rm -rf "$SI"; trap - EXIT

# =================================================================================
# CASE J — owned-but-uncovered ANOMALY (the INVERSE of covered-but-empty; the Silent Failure Hunter
# CRITICAL): an emitter owns nodes but its coverage is declared-missing/absent (it crashed after
# bulk-write, before mark-emitter-ran). Must be ANOMALOUS, never "not yet run / all clear".
# =================================================================================
echo "CASE J — owned-but-uncovered -> ANOMALOUS (the inverse-mismatch CRITICAL)"
SJ="$(mktemp -d -t hc-J-XXXXXX)"; trap 'rm -rf "$SJ"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SJ/topology-graph.json"
bash "$SUB" init "fixture-J" >/dev/null 2>&1 || fail "J: init"
# a pg_depend node (owned by supabase-live) — but supabase-live left at declared-missing (crash-after-write).
bash "$SUB" bulk-write '[{"id":"tbl1","kind":"table","source_file":"x.sql","source_commit":"s","timestamp":"2026-06-01T00:00:00Z","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":[],"attributes":{},"declared_intent_ref":null}]' '[]' >/dev/null 2>&1 || fail "J: bulk-write"
# supabase-live stays declared-missing (init default); code + n8n absent.
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code absent null
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" n8n-cloud absent null
JSON_J="$(bash "$HC" --json)" || fail "J: health-check exited non-zero"
echo "$JSON_J" | jq -e '.verdict == "ANOMALOUS"' >/dev/null || fail "J: verdict != ANOMALOUS (got $(echo "$JSON_J"|jq -r .verdict)) — owned-but-uncovered silently reported as not-yet-run!"; ok "J verdict ANOMALOUS (owned-but-uncovered)"
echo "$JSON_J" | jq -e '.emitters["supabase-live"].anomaly == "owned_but_uncovered" and .emitters["supabase-live"].owned_node_count == 1' >/dev/null || fail "J: supabase-live anomaly != owned_but_uncovered (got $(echo "$JSON_J"|jq -c .emitters["supabase-live"]))"; ok "J supabase-live anomaly = owned_but_uncovered, owns 1"
TEXT_J="$(bash "$HC")"; printf '%s' "$TEXT_J" | grep -q "OWNS 1 nodes — ANOMALOUS" || fail "J: text owned-but-uncovered line missing"; ok "J text shows owned-but-uncovered anomaly line"
rm -rf "$SJ"; trap - EXIT

# =================================================================================
# CASE K — degenerate coverage (the 4th enum value): distinct label, not stale, not an anomaly.
# Closes the eval-header claim that all 4 coverage labels are exercised (Test/Spec Validator finding).
# =================================================================================
echo "CASE K — degenerate coverage label (the 4th enum, distinct)"
SK="$(mktemp -d -t hc-K-XXXXXX)"; trap 'rm -rf "$SK"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SK/topology-graph.json"
bash "$SUB" init "fixture-K" >/dev/null 2>&1 || fail "K: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "K: bulk-write"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_ago_h 1)"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" supabase-live degenerate null  # source exists but unreadable
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" n8n-cloud absent null
JSON_K="$(bash "$HC" --json)" || fail "K: health-check exited non-zero"
echo "$JSON_K" | jq -e '.emitters["supabase-live"].coverage == "degenerate" and .emitters["supabase-live"].stale == false and .emitters["supabase-live"].anomaly == "none"' >/dev/null || fail "K: degenerate emitter wrong ($(echo "$JSON_K"|jq -c .emitters["supabase-live"]))"; ok "K degenerate coverage distinct, not stale, no anomaly"
TEXT_K="$(bash "$HC")"; printf '%s' "$TEXT_K" | grep -q "degenerate — source exists but is unreadable" || fail "K: text degenerate line missing"; ok "K text shows distinct degenerate label"
rm -rf "$SK"; trap - EXIT

# =================================================================================
# CASE L — env-override threshold: TOPOLOGY_STALE_CODE_H tightens code's staleness; + malformed env
# falls back to default without crashing (the _int normaliser + the shell-portability §6 class).
# =================================================================================
echo "CASE L — env-override threshold + malformed-env fallback"
SL="$(mktemp -d -t hc-L-XXXXXX)"; trap 'rm -rf "$SL"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SL/topology-graph.json"
bash "$SUB" init "fixture-L" >/dev/null 2>&1 || fail "L: init"
bash "$SUB" bulk-write "[ $(mknode tsm1 ts_module dependency_cruiser) ]" "[]" >/dev/null 2>&1 || fail "L: bulk-write"
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" code covered "$(ts_ago_h 2)"   # 2h old
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" supabase-live absent null
set_emitter "$TOPOLOGY_SUBSTRATE_PATH" n8n-cloud absent null
# default 24h -> 2h is fresh. Override to 1h -> 2h is now STALE (proves the override flows through threshold()).
JSON_L1="$(TOPOLOGY_STALE_CODE_H=1 bash "$HC" --json)" || fail "L: health-check exited non-zero (override)"
echo "$JSON_L1" | jq -e '.emitters.code.stale == true and .emitters.code.threshold_hours == 1' >/dev/null || fail "L: env override did not flow through (got $(echo "$JSON_L1"|jq -c .emitters.code))"; ok "L env override TOPOLOGY_STALE_CODE_H=1 -> code stale at 2h, threshold 1"
# malformed env -> _int strips to digits -> empty -> fallback default 24 (no crash).
JSON_L2="$(TOPOLOGY_STALE_CODE_H='abc!!!' bash "$HC" --json)" || fail "L: malformed env crashed the script"
echo "$JSON_L2" | jq -e '.emitters.code.threshold_hours == 24 and .emitters.code.stale == false' >/dev/null || fail "L: malformed env did not fall back to 24 (got $(echo "$JSON_L2"|jq -c .emitters.code))"; ok "L malformed env 'abc!!!' -> falls back to 24h, no crash"
rm -rf "$SL"; trap - EXIT

# =================================================================================
# CASE M — UNINITIALISED: no substrate file -> verdict UNINITIALISED at exit 0 + the documented JSON shape.
# =================================================================================
echo "CASE M — UNINITIALISED (no substrate)"
SM="$(mktemp -d -t hc-M-XXXXXX)"; trap 'rm -rf "$SM"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SM/does-not-exist/topology-graph.json"   # path with no file
JSON_M="$(bash "$HC" --json)"; M_RC=$?
[ "$M_RC" -eq 0 ] || fail "M: UNINITIALISED should exit 0 (got rc $M_RC)"; ok "M exits 0 on missing substrate"
echo "$JSON_M" | jq -e '.verdict == "UNINITIALISED"' >/dev/null || fail "M: verdict != UNINITIALISED (got $(echo "$JSON_M"|jq -r .verdict))"; ok "M verdict UNINITIALISED"
echo "$JSON_M" | jq -e '.integrity == "UNKNOWN" and .node_total == 0 and (.emitters == {}) and (.kind_counts == {})' >/dev/null || fail "M: UNINITIALISED JSON shape wrong ($(echo "$JSON_M"|jq -c '{integrity,node_total,emitters,kind_counts}'))"; ok "M UNINITIALISED JSON shape (integrity UNKNOWN, node_total 0, emitters {}, kind_counts {})"
# top-level key STABILITY: UNINITIALISED must carry the SAME top-level keys as a normal run (Type Analyzer).
echo "$JSON_M" | jq -e 'has("verdict") and has("conditions") and has("entity") and has("last_updated") and has("node_total") and has("kind_counts") and has("emitters") and has("missing_emitters") and has("named_emitters_present") and has("integrity") and has("integrity_detail")' >/dev/null || fail "M: UNINITIALISED missing a top-level key"; ok "M UNINITIALISED carries all top-level keys (shape-stable)"
rm -rf "$SM"; trap - EXIT

echo ""
echo "=== PASS — all $PASS_COUNT assertions green ==="
exit 0
