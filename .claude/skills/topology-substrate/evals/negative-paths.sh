#!/usr/bin/env bash
# evals/negative-paths.sh — the rejection + corruption-detection coverage.
# Added after the 2026-05-25 code-council found validate-schema's corruption detection (its whole
# reason to exist) was untested AND fails-open when its own jq aborts. This eval proves every
# rejection path returns the right exit code AND that validate-schema DETECTS injected corruption
# rather than silently blessing it. Writes to a mktemp -d scratch substrate; cleans up. Exit 0 = PASS.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SC="$HERE/../scripts/substrate.sh"
SCRATCH="$(mktemp -d)"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
trap 'rm -rf "$SCRATCH"' EXIT

fail() { echo "NEGATIVE-PATHS FAIL: $1" >&2; exit 1; }
# expect_rc <expected> <label> <command...>
expect_rc() {
  local exp="$1" label="$2"; shift 2
  "$@" >/dev/null 2>&1
  local rc=$?
  [ "$rc" -eq "$exp" ] || fail "$label: expected rc $exp, got $rc"
}
SUB() { bash "$SC" "$@"; }
VALID_NODE='{"id":"n","kind":"table","source_file":"m.sql","source_commit":"c","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":[],"attributes":{}}'

# --- pre-init: read/write before init returns rc 4 (not found) ---
expect_rc 4 "read before init returns 4" SUB read-topology
expect_rc 4 "write-edge before init returns 4" SUB write-edge '{"source":"a","target":"b"}'

SUB init "test-entity" >/dev/null || fail "init returned non-zero"

# --- write-node validation rejections (rc 2) ---
expect_rc 2 "invalid kind rejected"    SUB write-node '{"id":"x","kind":"banana","source_file":"f","source_commit":"c","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":[],"attributes":{}}'
expect_rc 2 "invalid emitter rejected" SUB write-node '{"id":"x","kind":"table","source_file":"f","source_commit":"c","timestamp":"t","source_line":1,"emitter":"redis","depends_on":[],"depended_on_by":[],"attributes":{}}'
expect_rc 2 "kind=manual rejected (manual is emitter, not kind)" SUB write-node '{"id":"x","kind":"manual","source_file":"f","source_commit":"c","timestamp":"t","source_line":1,"emitter":"manual","depends_on":[],"depended_on_by":[],"attributes":{},"manual_justification":"j"}'
expect_rc 2 "manual emitter WITHOUT justification rejected (D05 §6.6)" SUB write-node '{"id":"x","kind":"workflow","source_file":null,"source_commit":null,"timestamp":"t","source_line":null,"emitter":"manual","depends_on":[],"depended_on_by":[],"attributes":{}}'

# --- manual emitter WITH justification + a domain kind SUCCEEDS (rc 0) ---
expect_rc 0 "manual emitter WITH justification accepted" SUB write-node '{"id":"orphan","kind":"workflow","source_file":null,"source_commit":null,"timestamp":"t","source_line":null,"emitter":"manual","depends_on":[],"depended_on_by":[],"attributes":{},"manual_justification":"infra daemon, no source artefact"}'

# --- write-edge dangling endpoint rejected (rc 6), substrate unchanged ---
EDGES0="$(SUB read-topology '.edges|length')"
expect_rc 6 "write-edge dangling endpoint rejected" SUB write-edge '{"source":"orphan","target":"ghost"}'
[ "$(SUB read-topology '.edges|length')" = "$EDGES0" ] || fail "rejected write-edge mutated .edges"

# --- mark-emitter-ran rejections ---
expect_rc 2 "unknown emitter name rejected"  SUB mark-emitter-ran redis covered
expect_rc 2 "invalid coverage value rejected" SUB mark-emitter-ran code banana

# === CORRUPTION DETECTION — validate-schema must DETECT each injected corruption (rc 6), not PASS ===
# Helper: write a clean baseline, inject corruption via jq directly on the file, assert validate fails.
inject_and_expect_fail() {
  local label="$1" jqmut="$2"
  # rebuild a clean 2-node + 1-edge substrate first
  rm -f "$TOPOLOGY_SUBSTRATE_PATH"
  SUB init "test-entity" >/dev/null
  SUB bulk-write '[{"id":"a","kind":"table","source_file":"m","source_commit":"c","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":["b"],"attributes":{}},{"id":"b","kind":"view","source_file":"m","source_commit":"c","timestamp":"t","source_line":2,"emitter":"pg_depend","depends_on":["a"],"depended_on_by":[],"attributes":{}}]' '[{"source":"b","target":"a","type":"depends_on"}]' >/dev/null
  [ "$(SUB validate-schema)" = "PASS" ] || fail "$label: baseline was not PASS before injection"
  # inject the corruption directly on the file (bypassing the helpers)
  jq "$jqmut" "$TOPOLOGY_SUBSTRATE_PATH" > "$SCRATCH/mut.json" 2>/dev/null || fail "$label: jq mutation itself failed"
  mv "$SCRATCH/mut.json" "$TOPOLOGY_SUBSTRATE_PATH"
  SUB validate-schema >/dev/null 2>&1 && fail "$label: validate-schema returned PASS on corrupt substrate (FAIL-OPEN regression)"
}

inject_and_expect_fail "drifted child_map"        '.child_map["a"] = ["bogus-id"]'
inject_and_expect_fail "drifted parent_map"       '.parent_map = {}'
inject_and_expect_fail "invalid node kind"        '.nodes[0].kind = "garbage"'
inject_and_expect_fail "extra unexpected node key" '.nodes[0].sneaky = "field"'
inject_and_expect_fail "missing top-level key"    'del(.missing_emitters)'
inject_and_expect_fail "emitter value not object" '.emitters.code = "oops-a-string"'
inject_and_expect_fail "invalid coverage enum"    '.emitters.code.coverage = "weird"'
inject_and_expect_fail "schema_version wrong"     '.schema_version = "v99"'

# --- read-topology refuses to serve a corrupt substrate (rc 6) ---
expect_rc 6 "read-topology refuses corrupt substrate" SUB read-topology

echo "NEGATIVE-PATHS PASS (pre-init rc4, write-node rejections, manual-rule, dangling edge, mark-emitter rejections, 8 corruption classes detected, read refuses corrupt)"
exit 0
