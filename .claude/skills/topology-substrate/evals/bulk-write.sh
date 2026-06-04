#!/usr/bin/env bash
# evals/bulk-write.sh — coverage for the bulk-write helper (the path emitters MUST use).
# Added after the 2026-05-25 code-council found TWO CRITICAL bugs in bulk-write that shipped green
# because no eval exercised it: (1) node dedup kept the STALE record on re-emit, (2) the edge
# integrity check always errored and rejected every edge. This eval locks both fixed behaviours.
# Writes to a mktemp -d scratch substrate; cleans up. Exit 0 = PASS.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SC="$HERE/../scripts/substrate.sh"
SCRATCH="$(mktemp -d)"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
trap 'rm -rf "$SCRATCH"' EXIT

fail() { echo "BULK-WRITE FAIL: $1" >&2; exit 1; }

bash "$SC" init "test-entity" >/dev/null || fail "init returned non-zero"

# --- happy path: bulk-write nodes + a valid edge in one call ---
bash "$SC" bulk-write \
  '[{"id":"a","kind":"table","source_file":"m.sql","source_commit":"c1","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":["b"],"attributes":{"columns":["id"]}},{"id":"b","kind":"view","source_file":"m.sql","source_commit":"c1","timestamp":"t","source_line":2,"emitter":"pg_depend","depends_on":["a"],"depended_on_by":[],"attributes":{"is_materialized":false}}]' \
  '[{"source":"b","target":"a","type":"depends_on"}]' >/dev/null \
  || fail "bulk-write of 2 nodes + 1 valid edge returned non-zero (CRITICAL-2 regression: edge rejected)"
[ "$(bash "$SC" read-topology '.nodes|length')" = "2" ] || fail "expected 2 nodes after bulk-write"
[ "$(bash "$SC" read-topology '.edges|length')" = "1" ] || fail "expected 1 edge after bulk-write (CRITICAL-2: edge was not written)"
[ "$(bash "$SC" validate-schema)" = "PASS" ] || fail "validate-schema not PASS after bulk-write"

# --- CRITICAL-1 lock: re-emit an existing node with a NEW commit; incoming MUST win ---
bash "$SC" bulk-write \
  '[{"id":"a","kind":"table","source_file":"m.sql","source_commit":"c2-NEW","timestamp":"t2","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":["b"],"attributes":{"columns":["id","addr"]}}]' \
  '[]' >/dev/null || fail "bulk-write re-emit returned non-zero"
COMMIT="$(bash "$SC" read-topology '.nodes[]|select(.id=="a").source_commit')"
[ "$COMMIT" = '"c2-NEW"' ] || fail "CRITICAL-1 regression: re-emit did NOT win — a.source_commit=$COMMIT (expected c2-NEW; stale record kept)"
[ "$(bash "$SC" read-topology '.nodes|length')" = "2" ] || fail "re-emit created a duplicate node (expected 2 total)"

# --- duplicate id WITHIN one batch: last occurrence wins ---
bash "$SC" bulk-write \
  '[{"id":"c","kind":"function","source_file":"m.sql","source_commit":"first","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":[],"attributes":{}},{"id":"c","kind":"function","source_file":"m.sql","source_commit":"LAST","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":[],"attributes":{}}]' \
  '[]' >/dev/null || fail "bulk-write with intra-batch dup returned non-zero"
CCOMMIT="$(bash "$SC" read-topology '.nodes[]|select(.id=="c").source_commit')"
[ "$CCOMMIT" = '"LAST"' ] || fail "intra-batch dup: last occurrence did not win (c.source_commit=$CCOMMIT, expected LAST)"

# --- edge endpoint that exists ONLY in the incoming batch (union check) ---
bash "$SC" bulk-write \
  '[{"id":"d","kind":"trigger","source_file":"m.sql","source_commit":"c","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":["a"],"depended_on_by":[],"attributes":{}}]' \
  '[{"source":"d","target":"a","type":"triggers"}]' >/dev/null \
  || fail "bulk-write edge with incoming-only endpoint rejected (union check broken)"

# --- IMPORTANT: re-emitting the same edge must NOT grow the edge list (dedup) ---
EDGES_BEFORE="$(bash "$SC" read-topology '.edges|length')"
bash "$SC" bulk-write '[]' '[{"source":"b","target":"a","type":"depends_on"}]' >/dev/null || fail "edge re-emit returned non-zero"
EDGES_AFTER="$(bash "$SC" read-topology '.edges|length')"
[ "$EDGES_AFTER" = "$EDGES_BEFORE" ] || fail "edge dedup broken: count grew from $EDGES_BEFORE to $EDGES_AFTER on re-emit"

# --- negative: dangling edge (endpoint in neither existing nor incoming) must FAIL, leave file unchanged ---
NODES_BEFORE="$(bash "$SC" read-topology '.nodes|length')"
bash "$SC" bulk-write '[]' '[{"source":"ghost","target":"a"}]' >/dev/null 2>&1 && fail "dangling-edge bulk-write should have failed (rc 6)"
[ "$(bash "$SC" read-topology '.nodes|length')" = "$NODES_BEFORE" ] || fail "failed bulk-write mutated the substrate"
[ "$(bash "$SC" validate-schema)" = "PASS" ] || fail "substrate corrupt after a rejected bulk-write"

# --- negative: an invalid node in the batch must FAIL fast (rc 2), leave file unchanged ---
bash "$SC" bulk-write '[{"id":"bad","kind":"banana","source_file":"f","source_commit":"c","timestamp":"t","source_line":1,"emitter":"pg_depend","depends_on":[],"depended_on_by":[],"attributes":{}}]' '[]' >/dev/null 2>&1 && fail "invalid-kind bulk-write should have failed (rc 2)"
[ "$(bash "$SC" read-topology '.nodes|length')" = "$NODES_BEFORE" ] || fail "rejected invalid-node batch still mutated the substrate"

echo "BULK-WRITE PASS (valid edge accepted, re-emit wins, intra-batch last-wins, union edge, edge dedup, dangling+invalid rejected without mutation)"
exit 0
