#!/usr/bin/env bash
# canonical-shape.sh — positive eval for the supabase-live emitter.
#
# Feeds a fixture catalogue (6 nodes — one per kind, plus the A.11 disabled-policy variant
# + 4 edges) through the emitter harness (emit.sh) and asserts the substrate ends up
# canonical-shape correct:
#   - validate-schema PASS
#   - supabase-live coverage transitions null -> covered (heartbeat advance proves the
#     emitter actually fired vs inheriting prior state)
#   - exactly one node of each of the 5 kinds (table, view, function, trigger, rls_policy),
#     plus a SECOND rls_policy with enabled:false to exercise the A.11 dangerous case
#   - every node carries the §6.5.1 attributes its kind requires
#   - every node carries emitter:"pg_depend" (D05 P4) + declared_intent_ref:null
#   - rls_policy.enabled flag round-trips both true AND false (A.11 — load-bearing)
#   - every edge endpoint exists in nodes (no danglers)
#   - parent_map / child_map derived correctly from depends_on / depended_on_by
#
# The eval uses a scratch substrate path via mktemp -d so it NEVER touches a real
# .understand-anything/ directory. Mirrors the substrate skill's eval discipline.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
EMIT_SH="$SCRIPT_DIR/../scripts/emit.sh"

if [ ! -f "$SUBSTRATE_SH" ] || [ ! -f "$EMIT_SH" ]; then
  echo "FAIL: substrate.sh or emit.sh missing" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t supabase-live-eval-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SRC_COMMIT="live:fixture-project:postgres"

# --- pre-emit baseline: confirm supabase-live coverage starts at declared-missing -----
# (init seeds emitters at declared-missing / last_emitted_at:null per the substrate's contract).
# This baseline lets us prove the emit caused the transition rather than the value being
# inherited from prior state — closes the "heartbeat silently no-op" failure class
# code-council flagged.
bash "$SUBSTRATE_SH" init "fixture-entity" >/dev/null 2>&1 || { echo "FAIL: substrate init" >&2; exit 1; }
PRE_COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters["supabase-live"].coverage' 2>/dev/null | tr -d '"')"
[ "$PRE_COV" = "declared-missing" ] || { echo "FAIL: pre-emit coverage = '$PRE_COV' (want 'declared-missing'); init did not seed the expected baseline" >&2; exit 1; }
PRE_TS="$(bash "$SUBSTRATE_SH" read-topology '.emitters["supabase-live"].last_emitted_at' 2>/dev/null | tr -d '"')"
[ "$PRE_TS" = "null" ] || { echo "FAIL: pre-emit last_emitted_at = '$PRE_TS' (want 'null')" >&2; exit 1; }

# --- fixture inputs: one node per kind + A.11 disabled-policy variant + 4 edges -------
# Six nodes: the canonical 5 (table, view, function, trigger, rls_policy with enabled:true)
# plus a SECOND rls_policy with enabled:false. The A.11 dangerous case (Doctrine 05 §6.5.1
# + canonical-shape.md A.11) is the load-bearing signal — the rls_policy enabled flag
# distinguishes presence-in-catalogue from effectiveness-on-the-table. A regression that
# silently coerces enabled:false -> true (or drops the field) would ship undetected
# without this fixture. Code-council CRITICAL #8 — fixed.
cat > "$SCRATCH/nodes.json" <<EOF
[
  {"id":"public.fix_table","kind":"table","source_file":"pg_catalog (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"pg_depend","depends_on":[],"depended_on_by":["public.fix_view","public.fix_table.fix_trigger","public.fix_table.fix_policy_enabled","public.fix_table.fix_policy_disabled"],"attributes":{"columns":["id","name"],"row_estimate":100},"declared_intent_ref":null},
  {"id":"public.fix_view","kind":"view","source_file":"pg_catalog (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"pg_depend","depends_on":["public.fix_table"],"depended_on_by":[],"attributes":{"is_materialized":false,"definition_hash":"abc123"},"declared_intent_ref":null},
  {"id":"public.fix_function","kind":"function","source_file":"pg_catalog (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"pg_depend","depends_on":[],"depended_on_by":["public.fix_table.fix_trigger"],"attributes":{"language":"plpgsql","volatility":"volatile"},"declared_intent_ref":null},
  {"id":"public.fix_table.fix_trigger","kind":"trigger","source_file":"pg_catalog (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"pg_depend","depends_on":["public.fix_table","public.fix_function"],"depended_on_by":[],"attributes":{"timing":"BEFORE","event":"UPDATE"},"declared_intent_ref":null},
  {"id":"public.fix_table.fix_policy_enabled","kind":"rls_policy","source_file":"pg_catalog (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"pg_depend","depends_on":["public.fix_table"],"depended_on_by":[],"attributes":{"enabled":true,"command":"SELECT","role":["authenticated"]},"declared_intent_ref":null},
  {"id":"public.fix_table.fix_policy_disabled","kind":"rls_policy","source_file":"pg_catalog (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"pg_depend","depends_on":["public.fix_table"],"depended_on_by":[],"attributes":{"enabled":false,"command":"SELECT","role":["authenticated"]},"declared_intent_ref":null}
]
EOF
cat > "$SCRATCH/edges.json" <<EOF
[
  {"source":"public.fix_view","target":"public.fix_table","type":"depends_on","direction":"forward","weight":1},
  {"source":"public.fix_table.fix_trigger","target":"public.fix_table","type":"depends_on","direction":"forward","weight":1},
  {"source":"public.fix_table.fix_trigger","target":"public.fix_function","type":"depends_on","direction":"forward","weight":1},
  {"source":"public.fix_table.fix_policy_enabled","target":"public.fix_table","type":"depends_on","direction":"forward","weight":1},
  {"source":"public.fix_table.fix_policy_disabled","target":"public.fix_table","type":"depends_on","direction":"forward","weight":1}
]
EOF

# --- run the harness ---------------------------------------------------------
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
# closes the "mark-emitter-ran silently no-op" failure class — code-council CRITICAL.
COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters["supabase-live"].coverage' 2>/dev/null | tr -d '"')"
[ "$COV" = "covered" ] || fail "supabase-live coverage = '$COV' (want 'covered')"
TS="$(bash "$SUBSTRATE_SH" read-topology '.emitters["supabase-live"].last_emitted_at' 2>/dev/null | tr -d '"')"
[ -n "$TS" ] && [ "$TS" != "null" ] || fail "supabase-live last_emitted_at is null/empty (heartbeat did not advance)"
# Format check: ISO 8601 UTC (YYYY-MM-DDTHH:MM:SSZ)
printf '%s' "$TS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
  || fail "supabase-live last_emitted_at = '$TS' is not ISO 8601 UTC"

# 3. kind counts — exactly the fixture shape (1 of each except rls_policy which has 2)
for kind in table view function trigger; do
  N="$(bash "$SUBSTRATE_SH" read-topology "[.nodes[] | select(.kind==\"$kind\")] | length" 2>/dev/null)"
  N="$(printf '%s' "$N" | tr -dc '0-9' | head -c 5)"; N="${N:-0}"
  [ "$N" = "1" ] || fail "expected exactly 1 node of kind '$kind', got $N"
done
N_RLS="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(.kind=="rls_policy")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
N_RLS="${N_RLS:-0}"
[ "$N_RLS" = "2" ] || fail "expected exactly 2 rls_policy nodes (one enabled, one disabled — A.11), got $N_RLS"

# 4. typed attributes per §6.5.1 — every kind spot-checked (not just the rls_policy + view).
# Tables — columns + row_estimate
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_table") | .attributes.columns | length' 2>/dev/null | grep -q '^2$'; then
  fail "table fixture node missing or wrong .attributes.columns length"
fi
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_table") | .attributes.row_estimate' 2>/dev/null | grep -q '^100$'; then
  fail "table fixture node missing or wrong .attributes.row_estimate"
fi
# Views — is_materialized + definition_hash
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_view") | .attributes.definition_hash' 2>/dev/null | grep -q 'abc123'; then
  fail "view fixture node missing .attributes.definition_hash"
fi
# Functions — language + volatility (the SQL-decoded form, not raw 'i'/'s'/'v')
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_function") | .attributes.language' 2>/dev/null | grep -q 'plpgsql'; then
  fail "function fixture node missing or wrong .attributes.language"
fi
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_function") | .attributes.volatility' 2>/dev/null | grep -q 'volatile'; then
  fail "function fixture node missing or wrong .attributes.volatility (should be decoded string, not raw 'v')"
fi
# Triggers — timing + event
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_table.fix_trigger") | .attributes.timing' 2>/dev/null | grep -q 'BEFORE'; then
  fail "trigger fixture node missing or wrong .attributes.timing"
fi
# RLS policies — BOTH enabled:true (safe case) AND enabled:false (A.11 dangerous case)
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_table.fix_policy_enabled") | .attributes.enabled' 2>/dev/null | grep -q '^true$'; then
  fail "rls_policy[enabled] fixture node missing or wrong .attributes.enabled (expected true)"
fi
if ! bash "$SUBSTRATE_SH" read-topology '.nodes[] | select(.id=="public.fix_table.fix_policy_disabled") | .attributes.enabled' 2>/dev/null | grep -q '^false$'; then
  fail "rls_policy[disabled] fixture node missing or wrong .attributes.enabled (A.11 dangerous case must round-trip enabled:false intact)"
fi

# 4b. D05 P4 — every node must carry emitter:"pg_depend" (one node, one emitter)
WRONG_EMITTER="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(.emitter != "pg_depend")] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
WRONG_EMITTER="${WRONG_EMITTER:-X}"
[ "$WRONG_EMITTER" = "0" ] || fail "$WRONG_EMITTER nodes carry emitter != 'pg_depend' (D05 P4 violation)"

# 4c. forward-hook — every node carries declared_intent_ref (null at M3-v1)
MISSING_HOOK="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[] | select(has("declared_intent_ref") | not)] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
MISSING_HOOK="${MISSING_HOOK:-X}"
[ "$MISSING_HOOK" = "0" ] || fail "$MISSING_HOOK nodes missing declared_intent_ref forward-hook"

# 5. no dangling edges (every endpoint is in nodes). Use object-membership for jq portability
# (jq 1.6's `select` + `index` against an as-bound array can mis-bind .source/.target).
DANGLING="$(bash "$SUBSTRATE_SH" read-topology '([.nodes[].id] | map({(.):true}) | add) as $idset | [.edges[] | select(($idset[.source] != true) or ($idset[.target] != true))] | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
DANGLING="${DANGLING:-X}"
[ "$DANGLING" = "0" ] || fail "found $DANGLING dangling edges (want 0)"

# 6. parent_map / child_map match nodes' depended_on_by / depends_on.
# Bind both sides via `as` from the root object — piping through `| sort` first changes the
# context input so the right-hand side's `.nodes[...]` would otherwise look up `.nodes` on
# the sorted array (jq pipeline precedence trap).
PM_OK="$(bash "$SUBSTRATE_SH" read-topology '(.parent_map["public.fix_table"] | sort) as $pm | ([.nodes[]|select(.id=="public.fix_table")][0].depended_on_by | sort) as $dob | $pm == $dob' 2>/dev/null)"
[ "$PM_OK" = "true" ] || fail "parent_map[public.fix_table] does not match node.depended_on_by"
CM_OK="$(bash "$SUBSTRATE_SH" read-topology '(.child_map["public.fix_view"] | sort) as $cm | ([.nodes[]|select(.id=="public.fix_view")][0].depends_on | sort) as $do | $cm == $do' 2>/dev/null)"
[ "$CM_OK" = "true" ] || fail "child_map[public.fix_view] does not match node.depends_on"

echo "PASS: canonical-shape eval — 6 nodes emitted (incl. A.11 disabled-policy), §6.5.1 attributes for every kind, D05 P4 emitter, declared_intent_ref forward-hook, heartbeat transitioned declared-missing -> covered with ISO-8601 timestamp, edges sound, maps consistent"
exit 0
