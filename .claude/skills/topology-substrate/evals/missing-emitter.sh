#!/usr/bin/env bash
# evals/missing-emitter.sh — the P6 declared-coverage marker test.
# Asserts a freshly-init'd substrate carries: (a) exactly the 5 missing_emitters markers from
# spec 14 §3, (b) the 3 emitters at coverage "declared-missing" with null heartbeats, and that
# mark-emitter-ran flips one emitter to "covered" with a timestamp. This is the failure-visibility
# guarantee (Reliability Engineer) — absence is operator-visible, not silent.
# Writes to a mktemp -d scratch substrate; cleans up. Exit 0 = PASS.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SC="$HERE/../scripts/substrate.sh"
SCRATCH="$(mktemp -d)"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
trap 'rm -rf "$SCRATCH"' EXIT

fail() { echo "MISSING-EMITTER FAIL: $1" >&2; exit 1; }

bash "$SC" init "test-entity" >/dev/null || fail "init returned non-zero"

# Exactly 5 missing_emitters, with the spec-14 names.
MC="$(bash "$SC" read-topology '.missing_emitters|length')" || fail "read missing_emitters failed"
[ "$MC" = "5" ] || fail "expected 5 missing_emitters, got $MC"

EXPECTED_NAMES="airtable follow-up-boss homepros-podio vercel-deploy-state external-api-graph"
for name in $EXPECTED_NAMES; do
  HIT="$(bash "$SC" read-topology --arg n "$name" '[.missing_emitters[]|select(.name==$n)]|length' 2>/dev/null)" \
    || HIT="$(bash "$SC" read-topology ".missing_emitters[]|select(.name==\"$name\").name" 2>/dev/null)"
  case "$HIT" in
    "1"|"\"$name\"") : ;;
    *) fail "missing_emitter marker '$name' not present (got '$HIT')" ;;
  esac
done

# The 3 emitters start at declared-missing with null heartbeat.
for em in code supabase-live n8n-cloud; do
  COV="$(bash "$SC" read-topology ".emitters[\"$em\"].coverage")" || fail "read emitter $em coverage failed"
  LEA="$(bash "$SC" read-topology ".emitters[\"$em\"].last_emitted_at")" || fail "read emitter $em last_emitted_at failed"
  [ "$COV" = '"declared-missing"' ] || fail "emitter $em coverage expected declared-missing, got $COV"
  [ "$LEA" = "null" ] || fail "emitter $em last_emitted_at expected null at init, got $LEA"
done

# mark-emitter-ran flips one emitter to covered with a non-null timestamp + bumps last_updated.
BEFORE_UPDATED="$(bash "$SC" read-topology '.last_updated')"
sleep 1   # ensure a distinct second so the timestamp visibly advances
bash "$SC" mark-emitter-ran "supabase-live" "covered" >/dev/null || fail "mark-emitter-ran returned non-zero"
COV="$(bash "$SC" read-topology '.emitters["supabase-live"].coverage')"
LEA="$(bash "$SC" read-topology '.emitters["supabase-live"].last_emitted_at')"
[ "$COV" = '"covered"' ] || fail "after mark-emitter-ran, coverage expected covered, got $COV"
[ "$LEA" != "null" ] || fail "after mark-emitter-ran, last_emitted_at still null (heartbeat not set)"
AFTER_UPDATED="$(bash "$SC" read-topology '.last_updated')"
[ "$AFTER_UPDATED" != "$BEFORE_UPDATED" ] || fail "top-level last_updated heartbeat did not advance on write"

echo "MISSING-EMITTER PASS (5 P6 markers, 3 emitters declared-missing/null at init, heartbeat advances on mark)"
exit 0
