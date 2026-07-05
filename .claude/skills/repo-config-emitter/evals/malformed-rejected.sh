#!/usr/bin/env bash
# malformed-rejected.sh — negative eval for the repo-config emitter.
#
# Asserts the substrate REJECTS each malformed payload class with a substrate-attributable
# diagnostic (not a harness crash that happens to be nonzero). Mirrors the Session-2/3/4 negative
# eval discipline: each scenario must fail at the substrate's validation, AND the error text must
# be attributable to the substrate (so a harness bug masquerading as a rejection is caught).
#
# Scenarios:
#   1. invalid kind (kind:"deploy_config" — not in the frozen 10-kind enum) -> REJECTED
#   2. dangling edge (edge endpoint not in nodes) -> REJECTED
#   3. config node (emitter:manual) WITHOUT manual_justification -> REJECTED (D05 §6.6)
#   4. config node carrying manual_justification but emitter != manual -> REJECTED at validate-schema
#      (bulk-write's fast batch validator does not check this inverse rule; the full validate-schema
#       that every emit.sh run calls does — so this class is asserted at the validate-schema layer)
#   5. (transform-level) a workflow record missing required .relpath -> transform ABORTS (no
#      degenerate "repo:" id) — the id-prefix key has no safe default; fail loud, not silent-collide
#
# Uses a scratch substrate via mktemp -d.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
[ -f "$SUBSTRATE_SH" ] || { echo "FAIL: substrate.sh missing" >&2; exit 1; }

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# assert_rejected <label> <nodes-json> <edges-json>
# A scenario passes if bulk-write returns nonzero AND the stderr is substrate-attributable.
assert_rejected() {
  local label="$1" nodes="$2" edges="$3"
  local scratch out rc
  scratch="$(mktemp -d -t repo-config-neg-XXXXXX)"
  export TOPOLOGY_SUBSTRATE_PATH="$scratch/topology-graph.json"
  bash "$SUBSTRATE_SH" init "neg-entity" >/dev/null 2>&1 || { echo "FAIL [$label]: init" >&2; rm -rf "$scratch"; exit 1; }
  out="$(bash "$SUBSTRATE_SH" bulk-write "$nodes" "$edges" 2>&1)"; rc=$?
  rm -rf "$scratch"
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [$label]: bulk-write ACCEPTED a malformed payload (rc=0)" >&2
    exit 1
  fi
  # substrate-attributable: the error mentions substrate.sh OR a known violation phrase
  if ! printf '%s\n' "$out" | grep -qiE "substrate\.sh|invalid kind|not in nodes|manual_justification|violation|invalid emitter"; then
    echo "FAIL [$label]: rejected (rc=$rc) but error not substrate-attributable: $out" >&2
    exit 1
  fi
  echo "ok [$label]: rejected (rc=$rc)"
}

# assert_rejected_at_validate <label> <nodes-json> <edges-json>
# For malformed classes that the FAST batch validator in `bulk-write` (_validate_nodes_batch)
# does not catch but the FULL `validate-schema` (_validate_core) does. The substrate deliberately
# splits validation: bulk-write runs a cheap single-pass batch check (invalid kind / missing
# fields / manual-without-justification); the full structural assertion (incl. the inverse rule
# "manual_justification present but emitter != manual", _validate_core ~line 451) runs in
# validate-schema. Every real emit (emit.sh) ALWAYS calls validate-schema after bulk-write, so a
# real emit DOES catch this class — the harness is the enforcement point, and this helper asserts
# at that point rather than at bulk-write. Editing the frozen substrate to duplicate the inverse
# check into the batch validator was rejected (do-not-touch-the-frozen-contract); the harness
# already enforces it. A scenario passes if bulk-write accepts (the batch validator's documented
# gap) BUT the subsequent validate-schema rejects with a substrate-attributable diagnostic.
assert_rejected_at_validate() {
  local label="$1" nodes="$2" edges="$3"
  local scratch wout wrc vout vrc
  scratch="$(mktemp -d -t repo-config-neg-XXXXXX)"
  export TOPOLOGY_SUBSTRATE_PATH="$scratch/topology-graph.json"
  bash "$SUBSTRATE_SH" init "neg-entity" >/dev/null 2>&1 || { echo "FAIL [$label]: init" >&2; rm -rf "$scratch"; exit 1; }
  wout="$(bash "$SUBSTRATE_SH" bulk-write "$nodes" "$edges" 2>&1)"; wrc=$?
  vout="$(bash "$SUBSTRATE_SH" validate-schema 2>&1)"; vrc=$?
  rm -rf "$scratch"
  # validate-schema MUST reject (nonzero AND not the PASS sentinel).
  if [ "$vrc" -eq 0 ] || printf '%s\n' "$vout" | grep -q '^PASS$'; then
    echo "FAIL [$label]: validate-schema ACCEPTED a malformed payload (bulk-write rc=$wrc, validate rc=$vrc)" >&2
    exit 1
  fi
  if ! printf '%s\n' "$vout" | grep -qiE "substrate\.sh|invalid kind|not in nodes|manual_justification|violation|invalid emitter|carries manual_justification"; then
    echo "FAIL [$label]: validate-schema rejected (rc=$vrc) but error not substrate-attributable: $vout" >&2
    exit 1
  fi
  echo "ok [$label]: rejected at validate-schema (bulk-write rc=$wrc, validate rc=$vrc)"
}

# assert_transform_aborts <label> <n8n-workflows-json-array>
# For malformed INPUT classes the transform itself must reject BEFORE producing a node — the
# relpath-missing case (relpath is the repo: id prefix; a missing one would yield a degenerate
# "repo:" id that collides + is silently collapsed by the substrate upsert, while diagnostics
# overcount — Session-5 code-council CRITICAL). The transform must abort (rc != 0) via error(),
# not emit a degenerate node. A scenario passes if the transform exits nonzero with an
# attributable diagnostic. (Tests the transform, not the substrate — distinct from the helpers above.)
assert_transform_aborts() {
  local label="$1" n8n_arr="$2"
  local scratch transform out rc
  transform="$SCRIPT_DIR/../scripts/transform.jq"
  [ -f "$transform" ] || { echo "FAIL [$label]: transform.jq missing" >&2; exit 1; }
  scratch="$(mktemp -d -t repo-config-neg-XXXXXX)"
  printf '%s' "$n8n_arr" > "$scratch/n8n.json"
  printf 'null' > "$scratch/nul.json"
  out="$(jq -n --slurpfile n8n_workflows "$scratch/n8n.json" --slurpfile vercel "$scratch/nul.json" \
            --slurpfile package "$scratch/nul.json" --arg now "$NOW" --arg src_commit "evalsha" \
            -f "$transform" 2>&1)"; rc=$?
  rm -rf "$scratch"
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [$label]: transform ACCEPTED a malformed input (rc=0) — it should have aborted" >&2
    exit 1
  fi
  if ! printf '%s\n' "$out" | grep -qiE "relpath|repo-config-emitter"; then
    echo "FAIL [$label]: transform aborted (rc=$rc) but error not attributable: $out" >&2
    exit 1
  fi
  echo "ok [$label]: transform aborted (rc=$rc)"
}

base_node() {
  # base_node <id> <kind> <emitter> [extra-json]
  local id="$1" kind="$2" emitter="$3" extra="${4:-}"
  printf '{"id":"%s","kind":"%s","source_file":"x","source_commit":"c","timestamp":"%s","source_line":null,"emitter":"%s","depends_on":[],"depended_on_by":[],"attributes":{},"declared_intent_ref":null%s}' \
    "$id" "$kind" "$NOW" "$emitter" "$extra"
}

# 1. invalid kind
N1="[$(base_node "repo:bad1" "deploy_config" "manual" ',"manual_justification":"x"')]"
assert_rejected "invalid-kind" "$N1" "[]"

# 2. dangling edge (valid node, but an edge to a missing target)
N2="[$(base_node "repo:vercel.json" "config" "manual" ',"manual_justification":"x"')]"
E2='[{"source":"repo:vercel.json","target":"repo:nonexistent","type":"contains","direction":"forward","weight":1}]'
assert_rejected "dangling-edge" "$N2" "$E2"

# 3. config node (manual emitter) WITHOUT manual_justification
N3="[$(base_node "repo:bad3" "config" "manual")]"
assert_rejected "manual-without-justification" "$N3" "[]"

# 4. manual_justification present but emitter != manual.
# This class is caught by validate-schema (the inverse rule), NOT by bulk-write's fast batch
# validator — so it is asserted at the validate-schema layer (which every real emit.sh run calls).
N4="[$(base_node "repo:bad4" "config" "n8n_parser" ',"manual_justification":"x"')]"
assert_rejected_at_validate "justification-without-manual-emitter" "$N4" "[]"

# 5. (transform-level) a workflow record missing required .relpath → transform ABORTS (no degenerate
# "repo:" id). The id prefix is the one load-bearing key with no safe default; the transform must
# fail loud rather than emit a colliding node the substrate upsert silently collapses.
N5='[{"id":"WF1","name":"A","active":true,"isArchived":false,"tags":[],"nodes":[],"connections":{}}]'
assert_transform_aborts "relpath-missing" "$N5"

echo "PASS: repo-config malformed-rejected eval — 4 substrate-rejected classes + 1 transform-abort class, all with attributable diagnostics"
exit 0
