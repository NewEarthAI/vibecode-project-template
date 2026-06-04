#!/usr/bin/env bash
# malformed-rejected.sh — negative eval for the n8n-cloud emitter.
#
# Proves the emitter respects the substrate's contract: substrate.sh bulk-write rejects
# malformed inputs LOUD (nonzero exit). Three malformed scenarios:
#   1. missing kind  -> substrate rejects (rc 2, bad-arg)
#   2. dangling edge -> substrate rejects (rc 6, integrity)
#   3. invalid kind  -> substrate rejects (rc 2, bad-arg)
# All three must exit nonzero AND the substrate's state must remain consistent
# (validate-schema still PASS on whatever state existed before the bad attempt).
#
# Each scenario captures stderr to a per-scenario log + requires a substrate-attributable
# diagnostic — closing the negative-eval false-positive class the Session-2 code-council
# flagged (a transform / harness error would otherwise be conflated with a substrate rejection).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
EMIT_SH="$SCRIPT_DIR/../scripts/emit.sh"

SCRATCH="$(mktemp -d -t n8n-cloud-neg-eval-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SRC_COMMIT="live:fixture-honeybird:wfX"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Each scenario runs through this helper, which captures stderr to a per-scenario log so
# a future regression where emit.sh exits nonzero for an UNRELATED reason (jq missing,
# substrate.sh missing, init failed) can be distinguished from a substrate-originated
# REJECTION. The helper asserts BOTH (a) nonzero exit AND (b) stderr mentions a
# substrate-rejection sentinel ("bulk-write" or "validate" or "kind" or "endpoint") —
# closing the negative-eval false-positive class the Session-2 code-council flagged.
assert_rejected() {
  local label="$1" nodes_path="$2" edges_path="$3"
  local err_log="$SCRATCH/$label.err"
  if bash "$EMIT_SH" "$nodes_path" "$edges_path" "neg-eval-entity" >/dev/null 2>"$err_log"; then
    fail "[$label] emit.sh exited 0 — expected rejection"
  fi
  # Stderr must mention something substrate-attributable, not just a usage error.
  if ! grep -qiE 'bulk-write|validate|kind|endpoint|integrity' "$err_log"; then
    echo "--- captured stderr for $label ---" >&2
    cat "$err_log" >&2
    fail "[$label] emit.sh exited nonzero but stderr lacks a substrate-rejection sentinel (the eval was passing for the wrong reason)"
  fi
}

# Initialise the substrate with one valid node so we can prove negative attempts
# don't corrupt existing state.
bash "$SUBSTRATE_SH" init "neg-eval-entity" >/dev/null 2>&1 || fail "substrate init"
cat > "$SCRATCH/good-nodes.json" <<EOF
[{"id":"cloud:wfX","kind":"workflow","source_file":"n8n_cloud (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"n8n_parser","depends_on":[],"depended_on_by":[],"attributes":{"active":true,"trigger_type":"manual","name":"Baseline","archived":false,"tags":[],"node_count":0,"connection_count":0},"declared_intent_ref":null}]
EOF
bash "$SUBSTRATE_SH" bulk-write "$(cat "$SCRATCH/good-nodes.json")" '[]' >/dev/null 2>&1 \
  || fail "baseline good bulk-write should succeed"

# Create empty-edges.json once up front so every scenario has a valid edges path —
# eliminates the "first invocation rejects on missing file, not on the malformed node"
# false-positive class.
echo '[]' > "$SCRATCH/empty-edges.json"

# Scenario 1: node missing required kind ----------------------------------
cat > "$SCRATCH/bad1-nodes.json" <<EOF
[{"id":"cloud:bad1","source_file":"n8n_cloud (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"n8n_parser","depends_on":[],"depended_on_by":[],"attributes":{},"declared_intent_ref":null}]
EOF
assert_rejected "missing-kind" "$SCRATCH/bad1-nodes.json" "$SCRATCH/empty-edges.json"

# Scenario 2: dangling edge (target not in nodes ∪ existing) --------------
cat > "$SCRATCH/bad2-nodes.json" <<EOF
[{"id":"cloud:lonely","kind":"workflow","source_file":"n8n_cloud (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"n8n_parser","depends_on":[],"depended_on_by":[],"attributes":{"active":false,"trigger_type":"manual","name":"Lonely","archived":false,"tags":[],"node_count":0,"connection_count":0},"declared_intent_ref":null}]
EOF
cat > "$SCRATCH/bad2-edges.json" <<'EOF'
[{"source":"cloud:lonely","target":"cloud:does_not_exist","type":"calls","direction":"forward","weight":1}]
EOF
assert_rejected "dangling-edge" "$SCRATCH/bad2-nodes.json" "$SCRATCH/bad2-edges.json"

# Scenario 3: invalid kind enum value -------------------------------------
cat > "$SCRATCH/bad3-nodes.json" <<EOF
[{"id":"cloud:bad3","kind":"NOT_A_KIND","source_file":"n8n_cloud (live)","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"n8n_parser","depends_on":[],"depended_on_by":[],"attributes":{},"declared_intent_ref":null}]
EOF
assert_rejected "invalid-kind" "$SCRATCH/bad3-nodes.json" "$SCRATCH/empty-edges.json"

# Substrate state must still be sound after all the bad attempts.
if ! bash "$SUBSTRATE_SH" validate-schema 2>&1 | grep -q '^PASS$'; then
  fail "substrate became invalid after rejected attempts"
fi
# The original baseline workflow node must still be the only node.
N="$(bash "$SUBSTRATE_SH" read-topology '.nodes | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
[ "$N" = "1" ] || fail "expected 1 node remaining after rejections, got $N"

echo "PASS: malformed-rejected eval — missing-kind / dangling-edge / invalid-kind all rejected with substrate-attributable diagnostics; substrate state intact"
exit 0
