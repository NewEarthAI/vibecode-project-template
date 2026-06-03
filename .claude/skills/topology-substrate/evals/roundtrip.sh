#!/usr/bin/env bash
# evals/roundtrip.sh — the topology-substrate round-trip test.
# init -> write 3 nodes (one each: ts_module / table / workflow_node, with typed attributes)
# -> write 2 edges -> validate-schema PASS -> read-back confirms 3 nodes, 2 edges, coherent maps.
# Writes to a mktemp -d scratch substrate (never the real .understand-anything/ path); cleans up.
# Exit 0 = PASS; any non-zero = FAIL with the failing assertion named.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SC="$HERE/../scripts/substrate.sh"
SCRATCH="$(mktemp -d)"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
trap 'rm -rf "$SCRATCH"' EXIT

fail() { echo "ROUNDTRIP FAIL: $1" >&2; exit 1; }

bash "$SC" init "test-entity" >/dev/null   || fail "init returned non-zero"

# 3 nodes, one of each representative kind, each with kind-appropriate typed attributes.
bash "$SC" write-node '{"id":"src/App.tsx","kind":"ts_module","source_file":"src/App.tsx","source_commit":"c1","timestamp":"2026-05-25T10:00:00Z","source_line":1,"emitter":"dependency_cruiser","depends_on":["public.properties"],"depended_on_by":[],"attributes":{"is_entry":true,"export_count":3}}' >/dev/null \
  || fail "write-node ts_module returned non-zero"
bash "$SC" write-node '{"id":"public.properties","kind":"table","source_file":"migrations/001_init.sql","source_commit":"c2","timestamp":"2026-05-25T10:00:00Z","source_line":12,"emitter":"pg_depend","depends_on":[],"depended_on_by":["src/App.tsx","wf1:node3"],"attributes":{"columns":["id","address"],"row_estimate":5000}}' >/dev/null \
  || fail "write-node table returned non-zero"
bash "$SC" write-node '{"id":"wf1:node3","kind":"workflow_node","source_file":"workflows/sync.json","source_commit":"c3","timestamp":"2026-05-25T10:00:00Z","source_line":null,"emitter":"n8n_parser","depends_on":["public.properties"],"depended_on_by":[],"attributes":{"node_type":"postgres","position":[640,300]}}' >/dev/null \
  || fail "write-node workflow_node returned non-zero"

# 2 edges (both endpoints exist).
bash "$SC" write-edge '{"source":"src/App.tsx","target":"public.properties","type":"imports"}' >/dev/null \
  || fail "write-edge 1 returned non-zero"
bash "$SC" write-edge '{"source":"wf1:node3","target":"public.properties","type":"depends_on"}' >/dev/null \
  || fail "write-edge 2 returned non-zero"

# validate-schema must PASS.
V="$(bash "$SC" validate-schema)" || fail "validate-schema returned non-zero: $V"
[ "$V" = "PASS" ] || fail "validate-schema did not print PASS (got: $V)"

# read-back assertions.
NC="$(bash "$SC" read-topology '.nodes|length')"   || fail "read nodes length failed"
EC="$(bash "$SC" read-topology '.edges|length')"   || fail "read edges length failed"
[ "$NC" = "3" ] || fail "expected 3 nodes, got $NC"
[ "$EC" = "2" ] || fail "expected 2 edges, got $EC"

# map coherence: App.tsx's child is properties; properties' parents include App.tsx + wf1:node3.
APP_CHILD="$(bash "$SC" read-topology '.child_map["src/App.tsx"][0]')" || fail "read child_map failed"
[ "$APP_CHILD" = '"public.properties"' ] || fail "child_map[App.tsx] != properties (got $APP_CHILD)"
PROP_PARENTS="$(bash "$SC" read-topology '.parent_map["public.properties"]|length')" || fail "read parent_map failed"
[ "$PROP_PARENTS" = "2" ] || fail "parent_map[properties] expected 2 parents, got $PROP_PARENTS"

# typed attributes survived the round-trip (per-kind, not flattened).
ROWEST="$(bash "$SC" read-topology '.nodes[]|select(.id=="public.properties").attributes.row_estimate')" || fail "read attributes failed"
[ "$ROWEST" = "5000" ] || fail "table row_estimate attribute lost (got $ROWEST)"

# declared_intent_ref forward-hook present and null at v1.
INTENT="$(bash "$SC" read-topology '.nodes[]|select(.id=="src/App.tsx").declared_intent_ref')" || fail "read declared_intent_ref failed"
[ "$INTENT" = "null" ] || fail "declared_intent_ref should be null at v1 (got $INTENT)"

echo "ROUNDTRIP PASS (3 nodes, 2 edges, maps coherent, typed attributes + forward-hook intact)"
exit 0
