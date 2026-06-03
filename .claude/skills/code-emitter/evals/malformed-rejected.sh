#!/usr/bin/env bash
# malformed-rejected.sh — negative eval for the code emitter.
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
# Mirrors the n8n-cloud / supabase-live negative-eval discipline. macOS bash 3.2 + jq 1.7.
#
# These scenarios drive emit.sh with hand-written malformed node/edge files directly — they do
# NOT run extract.mjs (no UA needed), so this eval runs even where UA is uninstalled.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
EMIT_SH="$SCRIPT_DIR/../scripts/emit.sh"

if [ ! -f "$SUBSTRATE_SH" ] || [ ! -f "$EMIT_SH" ]; then
  echo "FAIL: substrate.sh or emit.sh missing" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t code-emit-neg-eval-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SRC_COMMIT="fixture123"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Each scenario runs through this helper, which captures stderr to a per-scenario log so a
# future regression where emit.sh exits nonzero for an UNRELATED reason (jq missing,
# substrate.sh missing, init failed) can be distinguished from a substrate-originated
# REJECTION. The helper asserts BOTH (a) nonzero exit AND (b) stderr mentions a
# substrate-rejection sentinel — closing the negative-eval false-positive class.
assert_rejected() {
  local label="$1" nodes_path="$2" edges_path="$3"
  local err_log="$SCRATCH/$label.err"
  if bash "$EMIT_SH" "$nodes_path" "$edges_path" "neg-eval-entity" >/dev/null 2>"$err_log"; then
    fail "[$label] emit.sh exited 0 — expected rejection"
  fi
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
[{"id":"repo:src/baseline.ts","kind":"ts_module","source_file":"src/baseline.ts","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"dependency_cruiser","depends_on":[],"depended_on_by":[],"attributes":{"is_entry":false,"export_count":0,"language":"typescript","file_size_bytes":10,"function_count":0,"class_count":0,"import_count":0,"source_file_relpath":"src/baseline.ts"},"declared_intent_ref":null}]
EOF
bash "$SUBSTRATE_SH" bulk-write "$(cat "$SCRATCH/good-nodes.json")" '[]' >/dev/null 2>&1 \
  || fail "baseline good bulk-write should succeed"

# Create empty-edges.json once up front so every scenario has a valid edges path —
# eliminates the "first invocation rejects on missing file, not on the malformed node"
# false-positive class.
echo '[]' > "$SCRATCH/empty-edges.json"

# Scenario 1: node missing required kind ----------------------------------
cat > "$SCRATCH/bad1-nodes.json" <<EOF
[{"id":"repo:src/bad1.ts","source_file":"src/bad1.ts","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"dependency_cruiser","depends_on":[],"depended_on_by":[],"attributes":{},"declared_intent_ref":null}]
EOF
assert_rejected "missing-kind" "$SCRATCH/bad1-nodes.json" "$SCRATCH/empty-edges.json"

# Scenario 2: dangling edge (target not in nodes ∪ existing) --------------
cat > "$SCRATCH/bad2-nodes.json" <<EOF
[{"id":"repo:src/lonely.ts","kind":"ts_module","source_file":"src/lonely.ts","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"dependency_cruiser","depends_on":[],"depended_on_by":[],"attributes":{"is_entry":false,"export_count":0,"language":"typescript","file_size_bytes":10,"function_count":0,"class_count":0,"import_count":1,"source_file_relpath":"src/lonely.ts"},"declared_intent_ref":null}]
EOF
cat > "$SCRATCH/bad2-edges.json" <<'EOF'
[{"source":"repo:src/lonely.ts","target":"repo:src/does_not_exist.ts","type":"imports","direction":"forward","weight":1}]
EOF
assert_rejected "dangling-edge" "$SCRATCH/bad2-nodes.json" "$SCRATCH/bad2-edges.json"

# Scenario 3: invalid kind enum value -------------------------------------
cat > "$SCRATCH/bad3-nodes.json" <<EOF
[{"id":"repo:src/bad3.ts","kind":"NOT_A_KIND","source_file":"src/bad3.ts","source_commit":"$SRC_COMMIT","timestamp":"$NOW","source_line":null,"emitter":"dependency_cruiser","depends_on":[],"depended_on_by":[],"attributes":{},"declared_intent_ref":null}]
EOF
assert_rejected "invalid-kind" "$SCRATCH/bad3-nodes.json" "$SCRATCH/empty-edges.json"

# Substrate state must still be sound after all the bad attempts.
if ! bash "$SUBSTRATE_SH" validate-schema 2>&1 | grep -q '^PASS$'; then
  fail "substrate became invalid after rejected attempts"
fi
# The original baseline ts_module node must still be the only node.
N="$(bash "$SUBSTRATE_SH" read-topology '.nodes | length' 2>/dev/null | tr -dc '0-9' | head -c 5)"
[ "$N" = "1" ] || fail "expected 1 node remaining after rejections, got $N"

echo "PASS: malformed-rejected eval — missing-kind / dangling-edge / invalid-kind all rejected with substrate-attributable diagnostics; substrate state intact"
exit 0
