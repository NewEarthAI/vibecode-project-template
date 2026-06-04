#!/usr/bin/env bash
# evals/concurrency.sh — the topology-substrate concurrency safety test.
# Launches N parallel write-node calls (distinct ids) against ONE substrate; asserts ALL land,
# the result is valid JSON, and validate-schema PASSES (no corruption, no lost write).
# This is the test a JSON eval manifest cannot express — it exercises the mkdir lock + tmp->mv
# atomic-write discipline under real contention.
# Writes to a mktemp -d scratch substrate; cleans up. Exit 0 = PASS.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SC="$HERE/../scripts/substrate.sh"
SCRATCH="$(mktemp -d)"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
trap 'rm -rf "$SCRATCH"' EXIT

fail() { echo "CONCURRENCY FAIL: $1" >&2; exit 1; }

# Number of parallel writers. 8 is enough to force lock contention without a long runtime.
N=8

bash "$SC" init "test-entity" >/dev/null || fail "init returned non-zero"

# Fire N writers in parallel, each writing a distinct node id. Capture each writer's rc.
pids=""
rc_dir="$SCRATCH/rc"; mkdir -p "$rc_dir"
i=1
while [ "$i" -le "$N" ]; do
  (
    node="{\"id\":\"n$i\",\"kind\":\"ts_module\",\"source_file\":\"f$i.ts\",\"source_commit\":\"c$i\",\"timestamp\":\"2026-05-25T10:00:0${i}Z\",\"source_line\":1,\"emitter\":\"dependency_cruiser\",\"depends_on\":[],\"depended_on_by\":[],\"attributes\":{\"is_entry\":false,\"export_count\":$i}}"
    bash "$SC" write-node "$node" >/dev/null 2>&1
    echo "$?" > "$rc_dir/$i"
  ) &
  pids="$pids $!"
  i=$((i + 1))
done

# Wait for all writers.
for p in $pids; do wait "$p"; done

# Every writer must have succeeded (rc 0) — no lost write, no lock-starvation failure.
i=1
while [ "$i" -le "$N" ]; do
  r="$(cat "$rc_dir/$i" 2>/dev/null || echo "MISSING")"
  [ "$r" = "0" ] || fail "writer n$i returned rc=$r (expected 0)"
  i=$((i + 1))
done

# The substrate must be valid JSON (no interleaved-byte corruption).
jq -e 'type == "object"' "$TOPOLOGY_SUBSTRATE_PATH" >/dev/null 2>&1 || fail "substrate is not valid JSON after concurrent writes"

# All N nodes must be present (no write silently dropped under contention).
NC="$(bash "$SC" read-topology '.nodes|length')" || fail "read nodes length failed"
[ "$NC" = "$N" ] || fail "expected $N nodes after concurrent writes, got $NC (a write was lost)"

# validate-schema must PASS (maps coherent, no partial-write artefact).
V="$(bash "$SC" validate-schema)" || fail "validate-schema returned non-zero: $V"
[ "$V" = "PASS" ] || fail "validate-schema did not print PASS (got: $V)"

# The lock must be released (no leftover lock dir).
[ ! -d "$SCRATCH/.topology-lock" ] || fail "lock dir leaked after concurrent writes"

echo "CONCURRENCY PASS ($N parallel writers, all landed, no corruption, lock released)"
exit 0
