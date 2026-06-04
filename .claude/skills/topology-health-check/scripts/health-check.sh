#!/usr/bin/env bash
# topology-health-check/scripts/health-check.sh — the operator-facing READ layer for the topology substrate.
#
# Intent-Actual-Gap Mechanism Build Programme — M3 Session 6 (CLOSES M3). Composes the FROZEN substrate
# helpers (read-topology + validate-schema) and adds the judgment layer: configurable per-emitter staleness
# thresholds, a 4-way coverage report, per-kind counts (the frozen 10-kind enum), anomaly flags
# (covered-but-empty / future-dated / unparseable-timestamp / named-emitter-missing), an integrity relay,
# and a single COMPOUND freshness verdict. READ-ONLY: never writes to the substrate, never edits substrate
# code, never extends the schema.
#
# Council amendments folded in (council/sessions/2026-06-01-m3-session-6-health-check-integration.md):
#   #1  staleness maths is jq-only (date -u +%s for now-epoch integer + $ts|fromdateiso8601 in jq).
#       NEVER `date -d` (GNU-only, FAILS on macOS bash 3.2).
#   #2  fromdateiso8601 wrapped in try/catch -> TIMESTAMP_UNPARSEABLE, never silent-skip / false-CORRUPT.
#   #3  per-emitter node-count check: covered emitter owning 0 nodes -> ANOMALOUS (covered_but_empty),
#       never FRESH. AND the inverse (code-council CRITICAL): an emitter owning >0 nodes but coverage
#       declared-missing/absent -> ANOMALOUS (owned_but_uncovered) — the crash-after-bulk-write-before-
#       mark-emitter-ran case, which must NOT be reported as "not yet run / all clear".
#   #4  compound verdict: STALE + PARTIAL coexist (the live state in 24h) -> render BOTH; --json conditions[].
#   #5  declared-missing wording: "built, not yet run on this substrate", not "not yet built".
#   #6  future-dated timestamp clamp: now - ts < 0 -> ANOMALOUS, never false-FRESH.
#   #10 strict `>` staleness boundary (a just-emitted-at-threshold substrate is FRESH, not STALE).
#   #11 ALL node reads via read-topology only (no direct file read); read-topology rc 6 -> CORRUPT verdict.
#   #12 named-emitter presence check; --json schema defined in SKILL.md; integration asserts via jq -e.
#
# Portability target: macOS system bash 3.2.57 + jq 1.7. NO bash assoc arrays, NO mapfile, NO ${var,,}.
# ALL date/structure maths is in jq; bash only orchestrates. Per .claude/rules/shell-portability.md:
# set -uo pipefail, numeric normalisation before [ integer tests, namespaced locals (avoid zsh `status`).
#
# Usage:
#   health-check.sh           -> plain-English operator report (layman chat surface)
#   health-check.sh --json    -> machine-readable JSON (the SKILL.md --json schema)
#
# Exit codes: 0 ok (verdict may be STALE/PARTIAL/ANOMALOUS — those are healthy REPORTS, not failures)
#             2 usage/bad-arg | 6 jq missing / unexpected script failure
# (substrate rc 4 -> UNINITIALISED verdict at rc 0; substrate rc 6 -> CORRUPT verdict at rc 0.)

set -uo pipefail

# --- locate the FROZEN substrate helper ----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUB="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"

if [ ! -f "$SUB" ]; then
  echo "health-check.sh: substrate helper not found at $SUB (expected the Session-1 topology-substrate skill)" >&2
  exit 6
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "health-check.sh: jq not found in PATH — required dependency (brew install jq)" >&2
  exit 6
fi

# --- args ----------------------------------------------------------------------
MODE="text"
case "${1:-}" in
  --json) MODE="json";;
  ''|--text) MODE="text";;
  -h|--help)
    grep -E '^#( |$)' "$0" | sed -E 's/^# ?//' | sed -n '1,30p'
    exit 0;;
  *) echo "health-check.sh: unknown arg '${1:-}' (use --json or no arg)" >&2; exit 2;;
esac

# --- frozen contract constants (lockstep with canonical-shape.md) --------------
KNOWN_EMITTER_NAMES="code supabase-live n8n-cloud"

# Configurable staleness thresholds (hours). Defaults per spec 14 §4.3. Env override per emitter.
# Normalise to integers (strip non-digits) before use — a malformed env var must not crash the [ test.
_int() { local v; v="$(printf '%s' "${1:-}" | tr -dc '0-9')"; printf '%s' "${v:-$2}"; }
TH_CODE="$(_int "${TOPOLOGY_STALE_CODE_H:-}" 24)"
TH_SUPABASE="$(_int "${TOPOLOGY_STALE_SUPABASE_H:-}" 168)"
TH_N8N="$(_int "${TOPOLOGY_STALE_N8N_H:-}" 24)"
TH_DEFAULT=24

NOW_EPOCH="$(date -u +%s)"   # macOS-safe; jq does ALL ISO-8601 parsing (amendment #1).

# --- read the substrate (amendment #11: via read-topology only; map rc) --------
SUBSTRATE_JSON=""
READ_RC=0
SUBSTRATE_JSON="$(bash "$SUB" read-topology '.' 2>/dev/null)"; READ_RC=$?

# rc 4 = not-initialised -> UNINITIALISED verdict. rc 6 = corrupt (read-topology self-validates).
if [ "$READ_RC" -eq 4 ]; then
  if [ "$MODE" = "json" ]; then
    jq -n '{verdict:"UNINITIALISED", conditions:["uninitialised"], entity:null, last_updated:null,
            node_total:0, kind_counts:{}, emitters:{}, missing_emitters:[],
            named_emitters_present:false, integrity:"UNKNOWN", integrity_detail:"substrate not found"}'
  else
    echo "UNINITIALISED — no topology substrate found. Run: bash $SUB init <entity>  then run the emitters."
  fi
  exit 0
fi
if [ "$READ_RC" -ne 0 ] || [ -z "$SUBSTRATE_JSON" ]; then
  # read-topology rc 6 (corrupt) or any other non-zero with no data -> CORRUPT. Pull the violation detail.
  DETAIL="$(bash "$SUB" validate-schema 2>&1 | tr '\n' ' ' | sed -E 's/  +/ /g')"
  [ -n "$DETAIL" ] || DETAIL="substrate unreadable (read-topology rc $READ_RC)"
  if [ "$MODE" = "json" ]; then
    jq -n --arg d "$DETAIL" '{verdict:"CORRUPT", conditions:["corrupt"], entity:null, last_updated:null,
            node_total:0, kind_counts:{}, emitters:{}, missing_emitters:[],
            named_emitters_present:false, integrity:"CORRUPT", integrity_detail:$d}'
  else
    echo "CORRUPT — the substrate failed validation. $DETAIL"
    echo "  Run: bash $SUB validate-schema   for the full violation list."
  fi
  exit 0
fi

# --- integrity (amendment: relay validate-schema, never re-implement) ----------
# read-topology (above) ALREADY ran validate-schema internally and refused to serve a corrupt
# substrate (rc 6 -> the CORRUPT early-exit). So reaching this point means the substrate is valid:
# we can record PASS without a second full read+validate of the whole file (which on a 10k-node
# substrate is a wasted parse — performance-reviewer finding). The CORRUPT path captured its detail
# in the early-exit block above; here the only reachable state is PASS. A belt-and-braces re-check is
# kept ONLY behind a debug toggle for paranoia, off by default.
INTEGRITY="PASS"; INTEGRITY_DETAIL=""
if [ "${TOPOLOGY_HC_DOUBLE_VALIDATE:-}" = "1" ]; then
  VAL_OUT="$(bash "$SUB" validate-schema 2>&1)"; VAL_RC=$?
  if [ "$VAL_RC" -ne 0 ]; then
    INTEGRITY="CORRUPT"
    INTEGRITY_DETAIL="$(printf '%s' "$VAL_OUT" | tr '\n' ' ' | sed -E 's/  +/ /g')"
  fi
fi

# --- the single jq pass: coverage + staleness + anomalies + counts -------------
# One jq program builds the full structured health object. ALL date arithmetic + anomaly classification
# lives here (bash cannot parse ISO-8601 portably). Amendments #1/#2/#3/#5/#6/#10/#12 are all in this jq.
#
# Per-emitter logic:
#   owned_node_count = count of nodes whose .emitter maps to this emitter NAME (see name->emitter map below).
#   age_hours: jq-only. fromdateiso8601 in a try/catch -> null + anomaly="unparseable_timestamp" on abort.
#   anomaly precedence: unparseable > future_dated > covered_but_empty > none.
#   stale: coverage in {covered} AND age != null AND age >= 0 AND (age/3600) > threshold (strict >, amend #10).
#          declared-missing / absent / degenerate are NEVER "stale" (nothing ran to be stale).
#
# name->emitter-value map (the substrate stores node .emitter as a generator value, not the emitter NAME):
#   code         -> dependency_cruiser (ts_module/edge_function) + vercel_api + manual (config). Repo n8n
#                   nodes are emitter=n8n_parser but carry a repo: id prefix -> attributed to `code`.
#   supabase-live-> pg_depend
#   n8n-cloud    -> n8n_parser WITHOUT a repo: id prefix (the live cloud nodes).
HEALTH="$(printf '%s' "$SUBSTRATE_JSON" | jq \
    --argjson now "$NOW_EPOCH" \
    --arg known "$KNOWN_EMITTER_NAMES" \
    --argjson th_code "$TH_CODE" \
    --argjson th_supabase "$TH_SUPABASE" \
    --argjson th_n8n "$TH_N8N" \
    --argjson th_default "$TH_DEFAULT" '
  ($known | split(" ")) as $KNOWN |
  . as $root |
  def threshold($name):
    if   $name == "code"          then $th_code
    elif $name == "supabase-live" then $th_supabase
    elif $name == "n8n-cloud"     then $th_n8n
    else $th_default end ;
  def owned($name):
    [ $root.nodes[]
      | . as $n
      | if   $name == "supabase-live" then (if $n.emitter == "pg_depend" then 1 else empty end)
        elif $name == "n8n-cloud"     then (if ($n.emitter == "n8n_parser") and ((($n.id // "") | startswith("repo:")) | not) then 1 else empty end)
        elif $name == "code"          then (if ($n.emitter == "dependency_cruiser") or ($n.emitter == "vercel_api") or ($n.emitter == "manual") or (($n.emitter == "n8n_parser") and (($n.id // "") | startswith("repo:"))) then 1 else empty end)
        else empty end
    ] | length ;
  def emitter_health($name; $rec):
    ($rec.coverage // "declared-missing") as $cov |
    ($rec.last_emitted_at // null) as $ts |
    owned($name) as $owned |
    ( if $ts == null then {age: null, parse_err: false}
      else ( try ({age: ($now - ($ts | fromdateiso8601)), parse_err: false})
             catch {age: null, parse_err: true} )
      end ) as $a |
    ( if $a.parse_err then "unparseable_timestamp"
      elif ($a.age != null) and ($a.age < 0) then "future_dated"
      elif ($cov == "covered") and ($owned == 0) then "covered_but_empty"
      elif ($cov != "covered") and ($owned > 0) then "owned_but_uncovered"
      else "none" end ) as $anom |
    ( ($cov == "covered")
      and ($a.age != null)
      and ($a.age >= 0)
      and (($a.age / 3600) > threshold($name)) ) as $stale |
    {
      coverage: $cov,
      last_emitted_at: $ts,
      age_hours: (if $a.age == null then null else (($a.age / 3600) * 100 | round / 100) end),
      threshold_hours: threshold($name),
      stale: $stale,
      owned_node_count: $owned,
      anomaly: $anom
    } ;
  ( ($root.emitters // {}) ) as $em |
  ( [ $KNOWN[], ($em | keys[]) ] | unique ) as $allnames |
  ( reduce $allnames[] as $name ({};
      .[$name] = emitter_health($name; ($em[$name] // {coverage:"declared-missing", last_emitted_at:null})) )
  ) as $emitters |
  ( ($KNOWN | map($em[.] != null) | all) ) as $named_present |
  ( reduce ($root.nodes[]? | .kind) as $k ({}; .[$k] = ((.[$k] // 0) + 1)) ) as $kind_counts |
  ( $root.nodes | length ) as $node_total |
  ( [ $emitters | to_entries[] | select(.value.stale) | .key ] ) as $stale_list |
  ( [ $emitters | to_entries[] | select(.value.coverage == "declared-missing") | .key ] ) as $missing_list |
  ( [ $emitters | to_entries[] | select(.value.anomaly != "none") | {name: .key, anomaly: .value.anomaly} ] ) as $anomalies |
  ( ($emitters | to_entries | map(select(.value.coverage == "covered" and .value.owned_node_count > 0)) | length) > 0 ) as $any_covered_nonempty |
  ( ($stale_list | length) > 0 ) as $is_stale |
  ( ($missing_list | length) > 0 ) as $is_partial |
  ( ($anomalies | length) > 0 ) as $is_anomalous |
  ( ($KNOWN | length) ) as $m |
  ( ($KNOWN | map(select($em[.] != null and (($em[.].coverage // "") == "covered"))) | length) ) as $n_covered |
  ( [ (if $is_anomalous then "anomalous" else empty end),
      (if $is_stale then "stale" else empty end),
      (if $is_partial then "partial" else empty end),
      (if (($is_stale or $is_partial or $is_anomalous) | not) and $any_covered_nonempty then "fresh" else empty end),
      (if ($named_present | not) then "named_emitter_missing" else empty end) ] ) as $conditions |
  ( if $is_anomalous then "ANOMALOUS"
    elif $is_stale and $is_partial then "STALE_AND_PARTIAL"
    elif $is_stale then "STALE"
    elif $is_partial then "PARTIAL"
    elif $any_covered_nonempty then "FRESH"
    else "PARTIAL" end ) as $verdict |
  {
    verdict: $verdict,
    conditions: $conditions,
    entity: ($root.entity // null),
    last_updated: ($root.last_updated // null),
    node_total: $node_total,
    kind_counts: $kind_counts,
    emitters: $emitters,
    missing_emitters: ($root.missing_emitters // []),
    named_emitters_present: $named_present,
    stale_list: $stale_list,
    missing_list: $missing_list,
    anomalies: $anomalies,
    n_covered: $n_covered,
    m_known: $m
  }
' 2>/dev/null)"

if [ -z "$HEALTH" ]; then
  echo "health-check.sh: failed to compute health (jq transform produced no output) — substrate may be malformed" >&2
  exit 6
fi

# splice in the integrity verdict (computed in bash from validate-schema rc).
HEALTH="$(printf '%s' "$HEALTH" | jq --arg integ "$INTEGRITY" --arg detail "$INTEGRITY_DETAIL" '
  .integrity = $integ | .integrity_detail = $detail
  | (if $integ == "CORRUPT" then .verdict = "CORRUPT" | .conditions = (["corrupt"] + .conditions) else . end)
')"

# --- emit -----------------------------------------------------------------------
if [ "$MODE" = "json" ]; then
  printf '%s' "$HEALTH" | jq '{
    verdict, conditions, entity, last_updated, node_total, kind_counts,
    emitters: (.emitters | to_entries | map({key, value: (.value | {coverage, last_emitted_at, age_hours, threshold_hours, stale, owned_node_count, anomaly})}) | from_entries),
    missing_emitters, named_emitters_present, integrity, integrity_detail
  }'
  exit 0
fi

# --- text mode: layman-voice operator report -----------------------------------
VERDICT="$(printf '%s' "$HEALTH" | jq -r '.verdict')"
STALE_LIST="$(printf '%s' "$HEALTH" | jq -r '.stale_list | join(", ")')"
MISSING_LIST="$(printf '%s' "$HEALTH" | jq -r '.missing_list | join(", ")')"
N_COVERED="$(printf '%s' "$HEALTH" | jq -r '.n_covered')"
M_KNOWN="$(printf '%s' "$HEALTH" | jq -r '.m_known')"

case "$VERDICT" in
  FRESH)            echo "FRESH — the topology map is current and coherent.";;
  STALE)            echo "STALE — re-emit: ${STALE_LIST}.";;
  PARTIAL)          echo "PARTIAL — ${N_COVERED} of ${M_KNOWN} emitters covered; not yet run: ${MISSING_LIST}.";;
  STALE_AND_PARTIAL) echo "STALE — re-emit: ${STALE_LIST};  PARTIAL — not yet run: ${MISSING_LIST}.";;
  ANOMALOUS)        echo "ANOMALOUS — the map has an inconsistency that needs attention (see anomalies below).";;
  CORRUPT)          echo "CORRUPT — the substrate failed integrity validation (see integrity below).";;
  UNINITIALISED)    echo "UNINITIALISED — no substrate. Run init + the emitters.";;
  *)                echo "$VERDICT";;
esac

echo ""
echo "Entity: $(printf '%s' "$HEALTH" | jq -r '.entity // "(unknown)"')   |   Total nodes: $(printf '%s' "$HEALTH" | jq -r '.node_total')   |   Last updated: $(printf '%s' "$HEALTH" | jq -r '.last_updated // "(never)"')"
echo ""
echo "Emitters (coverage · freshness):"
printf '%s' "$HEALTH" | jq -r '
  .emitters | to_entries[] |
  .key as $name | .value as $v |
  ( if $v.coverage == "covered" then
      ( if $v.anomaly == "covered_but_empty" then "  - \($name): COVERED but owns 0 nodes — ANOMALOUS, re-emit to repair"
        elif $v.anomaly == "future_dated"      then "  - \($name): covered, but timestamp is in the FUTURE (clock skew?) — treat as stale"
        elif $v.anomaly == "unparseable_timestamp" then "  - \($name): covered, but its timestamp is unparseable — staleness unknown"
        elif $v.stale then "  - \($name): covered, STALE (\($v.owned_node_count) nodes, \($v.age_hours)h old > \($v.threshold_hours)h threshold) — re-emit"
        else "  - \($name): covered, fresh (\($v.owned_node_count) nodes, \($v.age_hours)h old)" end )
    elif $v.anomaly == "owned_but_uncovered" then "  - \($name): \($v.coverage) but OWNS \($v.owned_node_count) nodes — ANOMALOUS (emitter likely crashed after writing nodes, before recording its run) — re-emit to repair"
    elif $v.coverage == "declared-missing" then "  - \($name): declared-missing — emitter built, not yet run on this substrate (run it to populate)"
    elif $v.coverage == "absent"   then "  - \($name): absent — this source type does not exist at this entity"
    elif $v.coverage == "degenerate" then "  - \($name): degenerate — source exists but is unreadable (access missing)"
    else "  - \($name): \($v.coverage)" end )
'

if [ "$(printf '%s' "$HEALTH" | jq -r '.named_emitters_present')" != "true" ]; then
  echo "  ! WARNING: one or more of the 3 named emitters (code, supabase-live, n8n-cloud) is missing from the substrate's emitters block — substrate may be hand-edited."
fi

echo ""
echo "Per-kind node counts:"
printf '%s' "$HEALTH" | jq -r '.kind_counts | to_entries | sort_by(.key)[] | "  - \(.key): \(.value)"'
if [ "$(printf '%s' "$HEALTH" | jq -r '.kind_counts | length')" = "0" ]; then
  echo "  (no nodes — the substrate is empty)"
fi

echo ""
echo "Not-yet-built emitters (M4+ scope):"
printf '%s' "$HEALTH" | jq -r '.missing_emitters[]? | "  - \(.name): \(.reason)"'

echo ""
if [ "$INTEGRITY" = "PASS" ]; then
  echo "Integrity: PASS (graph is internally coherent — no orphan nodes / dangling edges / map drift)."
else
  echo "Integrity: CORRUPT — $INTEGRITY_DETAIL"
fi

exit 0
