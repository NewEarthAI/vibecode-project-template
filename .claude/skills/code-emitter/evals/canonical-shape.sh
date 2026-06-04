#!/usr/bin/env bash
# canonical-shape.sh — positive eval for the code emitter.
#
# Builds a minimal fixture repo (a handful of TS/TSX files + an edge function + a _shared
# helper), runs the FULL pipeline (extract.mjs -> transform.jq -> emit.sh) against a scratch
# substrate, and asserts the substrate ends up canonical-shape correct:
#   - validate-schema PASS
#   - code coverage transitions declared-missing/null -> covered (heartbeat advance proves the
#     emitter actually fired vs inheriting prior state)
#   - exactly the expected ts_module + edge_function counts
#   - is_entry: true round-trips for src/main.tsx; false for others
#   - language round-trips both "typescript" (.ts) AND "typescript-react" (.tsx)
#   - edge_function carries runtime:"deno" + deployed_commit:null (M4-deferred, shipped null)
#   - the _shared helper is emitted as a ts_module (so functions' ../_shared imports resolve)
#   - every node carries emitter:"dependency_cruiser" (D05 P4) + declared_intent_ref:null
#   - imports edges present; @/ alias + relative + extension-resolution all work
#   - an unresolved alias/relative import is COUNTED (surface-loud) and its dangling edge DROPPED
#   - external npm / Deno URL / asset imports are skipped + counted (NOT emitted as edges)
#   - repo: prefix discipline — every id starts repo:
#   - parent_map / child_map derived correctly (validate-schema enforces map equality)
#
# Uses a scratch substrate path via mktemp -d so it NEVER touches a real .understand-anything/.
# Requires the UA plugin installed (the driver imports it); UA_PLUGIN_DIST may override the path.
# Mirrors the Session-2 / Session-3 eval discipline. macOS bash 3.2 + jq 1.7 + node.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"
EMIT_SH="$SCRIPT_DIR/../scripts/emit.sh"
EXTRACT_MJS="$SCRIPT_DIR/../scripts/extract.mjs"
TRANSFORM_JQ="$SCRIPT_DIR/../scripts/transform.jq"

if [ ! -f "$SUBSTRATE_SH" ] || [ ! -f "$EMIT_SH" ] || [ ! -f "$EXTRACT_MJS" ] || [ ! -f "$TRANSFORM_JQ" ]; then
  echo "FAIL: substrate.sh, emit.sh, extract.mjs, or transform.jq missing" >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "FAIL: node not found in PATH (required for extract.mjs)" >&2
  exit 1
fi

# Skip cleanly if UA is not installed — the eval needs the real library to parse.
UA_DIST="${UA_PLUGIN_DIST:-/Users/justin/.claude/plugins/cache/understand-anything/understand-anything/2.7.4/packages/core/dist/index.js}"
if [ ! -f "$UA_DIST" ]; then
  echo "SKIP: Understand-Anything not installed at $UA_DIST — code emitter eval needs UA to parse fixtures" >&2
  exit 0
fi

SCRATCH="$(mktemp -d -t code-emit-eval-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"

FIXTURE="$SCRATCH/repo"
WORK="$SCRATCH/work"
mkdir -p "$FIXTURE/src/hooks" "$FIXTURE/src/components" "$FIXTURE/supabase/functions/demo-fn" "$FIXTURE/supabase/functions/_shared" "$WORK"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- pre-emit baseline: code coverage starts declared-missing / last_emitted_at:null -----
bash "$SUBSTRATE_SH" init "fixture-entity" >/dev/null 2>&1 || { echo "FAIL: substrate init" >&2; exit 1; }
PRE_COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters.code.coverage' 2>/dev/null | tr -d '"')"
[ "$PRE_COV" = "declared-missing" ] || { echo "FAIL: pre-emit code coverage = '$PRE_COV' (want 'declared-missing')" >&2; exit 1; }
PRE_TS="$(bash "$SUBSTRATE_SH" read-topology '.emitters.code.last_emitted_at' 2>/dev/null | tr -d '"')"
[ "$PRE_TS" = "null" ] || { echo "FAIL: pre-emit last_emitted_at = '$PRE_TS' (want 'null')" >&2; exit 1; }

# --- fixture files ---------------------------------------------------------------
# src/main.tsx           — the entry (is_entry:true); imports ./App (relative, extension-resolved)
# src/App.tsx            — imports @/hooks/useThing (alias), ./components/Widget (relative),
#                          react (external npm), @/missing/gone (alias UNRESOLVED -> counted),
#                          ./logo.svg (asset -> counted)
# src/hooks/useThing.ts  — a .ts module (language "typescript"); no imports
# src/components/Widget.tsx — a .tsx module (language "typescript-react"); imports react
# supabase/functions/demo-fn/index.ts — edge_function; imports ../_shared/util.ts (relative ->
#                          resolves to the _shared ts_module) + a Deno URL (external URL -> counted)
# supabase/functions/_shared/util.ts  — ts_module (proves _shared helpers are nodes)

cat > "$FIXTURE/src/main.tsx" <<'EOF'
import { App } from "./App";
const x = App;
EOF

cat > "$FIXTURE/src/App.tsx" <<'EOF'
import { useThing } from "@/hooks/useThing";
import { Widget } from "./components/Widget";
import React from "react";
import { Gone } from "@/missing/gone";
import "./logo.svg";
export function App() { return useThing() + Widget + React + Gone; }
EOF

cat > "$FIXTURE/src/hooks/useThing.ts" <<'EOF'
export function useThing() { return 42; }
EOF

cat > "$FIXTURE/src/components/Widget.tsx" <<'EOF'
import React from "react";
export const Widget = React;
EOF

cat > "$FIXTURE/supabase/functions/demo-fn/index.ts" <<'EOF'
import { util } from "../_shared/util.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
export function handler() { return util() + createClient; }
EOF

cat > "$FIXTURE/supabase/functions/_shared/util.ts" <<'EOF'
export function util() { return "shared"; }
EOF

# --- run the pipeline ------------------------------------------------------------
node "$EXTRACT_MJS" "$FIXTURE" > "$WORK/extracted.jsonl" 2>"$WORK/extract-err"
EXTRACT_RC=$?
if [ "$EXTRACT_RC" -ne 0 ]; then
  echo "FAIL: extract.mjs exited nonzero ($EXTRACT_RC)"
  cat "$WORK/extract-err" >&2
  exit 1
fi

jq -s '.' "$WORK/extracted.jsonl" > "$WORK/records.json"
jq -n \
  --slurpfile records "$WORK/records.json" \
  --arg now "$NOW" \
  --arg src_commit "fixture123" \
  --argjson alias_map '{"@":"src"}' \
  -f "$TRANSFORM_JQ" \
  > "$WORK/combined.json" 2>"$WORK/transform-err"
TRANSFORM_RC=$?
if [ "$TRANSFORM_RC" -ne 0 ]; then
  echo "FAIL: transform.jq exited nonzero ($TRANSFORM_RC)"
  cat "$WORK/transform-err" >&2
  exit 1
fi

# --- diagnostics assertions (surface-loud discipline) ----------------------------
fail_diag() { echo "FAIL: diagnostics — $*" >&2; exit 1; }
diag() { jq ".diagnostics.$1" "$WORK/combined.json" 2>/dev/null | tr -dc '0-9' | head -c 6; }

D_TSM="$(diag ts_module_count)";        D_TSM="${D_TSM:-X}"
# ts_module: main.tsx, App.tsx, useThing.ts, Widget.tsx, _shared/util.ts = 5
[ "$D_TSM" = "5" ] || fail_diag "ts_module_count = '$D_TSM' (want 5)"
D_EFN="$(diag edge_function_count)";    D_EFN="${D_EFN:-X}"
[ "$D_EFN" = "1" ] || fail_diag "edge_function_count = '$D_EFN' (want 1)"
D_FAIL="$(diag ts_files_extractor_failed)"; D_FAIL="${D_FAIL:-X}"
[ "$D_FAIL" = "0" ] || fail_diag "ts_files_extractor_failed = '$D_FAIL' (want 0)"
D_UNRES="$(diag unresolved_imports)";   D_UNRES="${D_UNRES:-X}"
# @/missing/gone is an alias import that resolves to nothing -> exactly 1 unresolved
[ "$D_UNRES" = "1" ] || fail_diag "unresolved_imports = '$D_UNRES' (want 1 — @/missing/gone should surface loud)"
D_ASSET="$(diag asset_imports_skipped)"; D_ASSET="${D_ASSET:-X}"
[ "$D_ASSET" = "1" ] || fail_diag "asset_imports_skipped = '$D_ASSET' (want 1 — ./logo.svg)"
D_URL="$(diag external_url_imports_skipped)"; D_URL="${D_URL:-X}"
[ "$D_URL" = "1" ] || fail_diag "external_url_imports_skipped = '$D_URL' (want 1 — the esm.sh import)"
D_ENTRY="$(diag entry_points_marked)";  D_ENTRY="${D_ENTRY:-X}"
[ "$D_ENTRY" = "1" ] || fail_diag "entry_points_marked = '$D_ENTRY' (want 1 — src/main.tsx)"

jq '.nodes' "$WORK/combined.json" > "$WORK/nodes.json"
jq '.edges' "$WORK/combined.json" > "$WORK/edges.json"

if ! bash "$EMIT_SH" "$WORK/nodes.json" "$WORK/edges.json" "fixture-entity" >/dev/null 2>"$WORK/harness-err"; then
  echo "FAIL: emit.sh harness exited nonzero"
  cat "$WORK/harness-err" >&2
  exit 1
fi

# --- substrate assertions --------------------------------------------------------
fail() { echo "FAIL: $*" >&2; exit 1; }
rt() { bash "$SUBSTRATE_SH" read-topology "$1" 2>/dev/null; }

# 1. validate-schema PASS
bash "$SUBSTRATE_SH" validate-schema 2>&1 | grep -q '^PASS$' || fail "validate-schema did not return PASS"

# 2. heartbeat transition declared-missing/null -> covered/timestamp
COV="$(rt '.emitters.code.coverage' | tr -d '"')"
[ "$COV" = "covered" ] || fail "code coverage = '$COV' (want 'covered')"
TS="$(rt '.emitters.code.last_emitted_at' | tr -d '"')"
[ -n "$TS" ] && [ "$TS" != "null" ] || fail "code last_emitted_at is null/empty (heartbeat did not advance)"
printf '%s' "$TS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
  || fail "code last_emitted_at = '$TS' is not ISO 8601 UTC"

# 3. kind counts
N_TSM="$(rt '[.nodes[]|select(.kind=="ts_module")]|length' | tr -dc '0-9' | head -c 5)"; N_TSM="${N_TSM:-0}"
[ "$N_TSM" = "5" ] || fail "expected 5 ts_module nodes, got $N_TSM"
N_EFN="$(rt '[.nodes[]|select(.kind=="edge_function")]|length' | tr -dc '0-9' | head -c 5)"; N_EFN="${N_EFN:-0}"
[ "$N_EFN" = "1" ] || fail "expected 1 edge_function node, got $N_EFN"

# 3b. repo: prefix discipline — every id starts repo:
NON_REPO="$(rt '[.nodes[]|select(.id|startswith("repo:")|not)]|length' | tr -dc '0-9' | head -c 5)"; NON_REPO="${NON_REPO:-X}"
[ "$NON_REPO" = "0" ] || fail "$NON_REPO node ids are NOT prefixed 'repo:' (prefix discipline broken)"

# 4. is_entry round-trips — true for main.tsx, false for App.tsx
ENTRY_MAIN="$(rt '.nodes[]|select(.id=="repo:src/main.tsx")|.attributes.is_entry')"
[ "$ENTRY_MAIN" = "true" ] || fail "src/main.tsx is_entry = '$ENTRY_MAIN' (want true)"
ENTRY_APP="$(rt '.nodes[]|select(.id=="repo:src/App.tsx")|.attributes.is_entry')"
[ "$ENTRY_APP" = "false" ] || fail "src/App.tsx is_entry = '$ENTRY_APP' (want false)"

# 5. language round-trips both forms
LANG_TS="$(rt '.nodes[]|select(.id=="repo:src/hooks/useThing.ts")|.attributes.language' | tr -d '"')"
[ "$LANG_TS" = "typescript" ] || fail "useThing.ts language = '$LANG_TS' (want typescript)"
LANG_TSX="$(rt '.nodes[]|select(.id=="repo:src/components/Widget.tsx")|.attributes.language' | tr -d '"')"
[ "$LANG_TSX" = "typescript-react" ] || fail "Widget.tsx language = '$LANG_TSX' (want typescript-react)"

# 6. edge_function attributes — runtime:deno, deployed_commit:null (M4-deferred shipped null)
EFN_RUNTIME="$(rt '.nodes[]|select(.kind=="edge_function")|.attributes.runtime' | tr -d '"')"
[ "$EFN_RUNTIME" = "deno" ] || fail "edge_function runtime = '$EFN_RUNTIME' (want deno)"
EFN_DEPLOY="$(rt '.nodes[]|select(.kind=="edge_function")|.attributes.deployed_commit')"
[ "$EFN_DEPLOY" = "null" ] || fail "edge_function deployed_commit = '$EFN_DEPLOY' (want null — M4-deferred, shipped null not dropped)"
EFN_NAME="$(rt '.nodes[]|select(.kind=="edge_function")|.attributes.function_name' | tr -d '"')"
[ "$EFN_NAME" = "demo-fn" ] || fail "edge_function function_name = '$EFN_NAME' (want demo-fn)"

# 7. the _shared helper is a ts_module node (so ../_shared/util.ts resolves)
SHARED_KIND="$(rt '.nodes[]|select(.id=="repo:supabase/functions/_shared/util.ts")|.kind' | tr -d '"')"
[ "$SHARED_KIND" = "ts_module" ] || fail "_shared/util.ts kind = '$SHARED_KIND' (want ts_module)"

# 8. every node carries emitter:"dependency_cruiser" + declared_intent_ref:null
BAD_EMITTER="$(rt '[.nodes[]|select(.emitter!="dependency_cruiser")]|length' | tr -dc '0-9' | head -c 5)"; BAD_EMITTER="${BAD_EMITTER:-X}"
[ "$BAD_EMITTER" = "0" ] || fail "$BAD_EMITTER nodes have emitter != dependency_cruiser (D05 P4)"
BAD_INTENT="$(rt '[.nodes[]|select(.declared_intent_ref!=null)]|length' | tr -dc '0-9' | head -c 5)"; BAD_INTENT="${BAD_INTENT:-X}"
[ "$BAD_INTENT" = "0" ] || fail "$BAD_INTENT nodes have declared_intent_ref != null (forward-hook must be null at M3-v1)"

# 9. imports edges resolve correctly:
#    main.tsx -> App.tsx (relative, extension-resolved)
EDGE_MAIN_APP="$(rt '[.edges[]|select(.source=="repo:src/main.tsx" and .target=="repo:src/App.tsx" and .type=="imports")]|length' | tr -dc '0-9' | head -c 5)"; EDGE_MAIN_APP="${EDGE_MAIN_APP:-0}"
[ "$EDGE_MAIN_APP" = "1" ] || fail "missing imports edge main.tsx -> App.tsx (relative resolution broken)"
#    App.tsx -> useThing.ts (@/ alias resolution)
EDGE_APP_HOOK="$(rt '[.edges[]|select(.source=="repo:src/App.tsx" and .target=="repo:src/hooks/useThing.ts")]|length' | tr -dc '0-9' | head -c 5)"; EDGE_APP_HOOK="${EDGE_APP_HOOK:-0}"
[ "$EDGE_APP_HOOK" = "1" ] || fail "missing imports edge App.tsx -> useThing.ts (@/ alias resolution broken)"
#    demo-fn -> _shared/util.ts (edge-function relative import into _shared)
EDGE_FN_SHARED="$(rt '[.edges[]|select(.source=="repo:supabase/functions/demo-fn" and .target=="repo:supabase/functions/_shared/util.ts")]|length' | tr -dc '0-9' | head -c 5)"; EDGE_FN_SHARED="${EDGE_FN_SHARED:-0}"
[ "$EDGE_FN_SHARED" = "1" ] || fail "missing imports edge demo-fn -> _shared/util.ts (edge-fn relative resolution broken)"

# 10. NO dangling edge to the unresolved alias target (it was counted, the edge dropped)
DANGLING="$(rt '[.edges[]|select(.target|startswith("unresolved:"))]|length' | tr -dc '0-9' | head -c 5)"; DANGLING="${DANGLING:-X}"
[ "$DANGLING" = "0" ] || fail "$DANGLING dangling unresolved: edges survived the idset filter (should be dropped, counted only)"

# 11. NO external npm edge (react must not be a node/edge)
REACT_NODE="$(rt '[.nodes[]|select(.id|test("react"))]|length' | tr -dc '0-9' | head -c 5)"; REACT_NODE="${REACT_NODE:-X}"
[ "$REACT_NODE" = "0" ] || fail "external npm 'react' leaked into the substrate as a node"

# 12. parent_map / child_map round-trip (port of the reference eval's map-equality assertion).
# App.tsx has an outbound edge (-> useThing.ts, -> Widget.tsx, -> Card? no) AND an inbound edge
# (main.tsx -> App.tsx). Assert the maps mirror the node's adjacency. (validate-schema also
# enforces this, but assert directly so a self-consistent-but-wrong derivation is caught.)
CHILD_APP="$(rt '.child_map["repo:src/App.tsx"]|length' | tr -dc '0-9' | head -c 5)"; CHILD_APP="${CHILD_APP:-0}"
DEPS_APP="$(rt '.nodes[]|select(.id=="repo:src/App.tsx")|.depends_on|length' | tr -dc '0-9' | head -c 5)"; DEPS_APP="${DEPS_APP:-0}"
[ "$CHILD_APP" = "$DEPS_APP" ] && [ "$CHILD_APP" != "0" ] || fail "child_map[App.tsx] ($CHILD_APP) != App.tsx.depends_on ($DEPS_APP), or zero"
PARENT_APP="$(rt '.parent_map["repo:src/App.tsx"]|length' | tr -dc '0-9' | head -c 5)"; PARENT_APP="${PARENT_APP:-0}"
REV_APP="$(rt '.nodes[]|select(.id=="repo:src/App.tsx")|.depended_on_by|length' | tr -dc '0-9' | head -c 5)"; REV_APP="${REV_APP:-0}"
[ "$PARENT_APP" = "$REV_APP" ] || fail "parent_map[App.tsx] ($PARENT_APP) != App.tsx.depended_on_by ($REV_APP)"

# ===========================================================================================
# SUB-TEST 2 — the ARG_MAX chunked-write path (CONFIRMED zero-coverage gap; the code that had
# the live "Argument list too long" failure). Re-run the SAME fixture through emit.sh with a
# tiny CHUNK_BUDGET_BYTES to FORCE the chunked branch, against a FRESH scratch substrate, and
# assert the end state is identical to the fast-path run above (same node + edge counts,
# validate PASS, heartbeat covered). Proves the documented idempotence claim — chunked
# sequence reaches the same end state as one big call — instead of only asserting it in prose.
# ===========================================================================================
CHUNK_SUB="$SCRATCH/chunk-graph.json"
( export TOPOLOGY_SUBSTRATE_PATH="$CHUNK_SUB"
  bash "$SUBSTRATE_SH" init "fixture-entity-chunked" >/dev/null 2>&1 || exit 1
  CHUNK_BUDGET_BYTES=200 bash "$EMIT_SH" "$WORK/nodes.json" "$WORK/edges.json" "fixture-entity-chunked" >"$WORK/chunk-emit.out" 2>&1
) || { echo "FAIL: chunked-path emit.sh exited nonzero"; cat "$WORK/chunk-emit.out" >&2; exit 1; }
# Confirm it actually took the chunked branch (not the fast path) — the budget=200 message.
grep -q "writing in chunks" "$WORK/chunk-emit.out" || fail "chunked sub-test did NOT take the chunked branch (CHUNK_BUDGET_BYTES override ineffective)"
rtc() { TOPOLOGY_SUBSTRATE_PATH="$CHUNK_SUB" bash "$SUBSTRATE_SH" read-topology "$1" 2>/dev/null; }
TOPOLOGY_SUBSTRATE_PATH="$CHUNK_SUB" bash "$SUBSTRATE_SH" validate-schema 2>&1 | grep -q '^PASS$' || fail "chunked-path substrate failed validate-schema"
CHUNK_COV="$(rtc '.emitters.code.coverage' | tr -d '"')"
[ "$CHUNK_COV" = "covered" ] || fail "chunked-path code coverage = '$CHUNK_COV' (want covered — heartbeat must fire after all chunks)"
C_NODES="$(rtc '.nodes|length' | tr -dc '0-9' | head -c 5)"; C_NODES="${C_NODES:-0}"
C_EDGES="$(rtc '.edges|length' | tr -dc '0-9' | head -c 5)"; C_EDGES="${C_EDGES:-0}"
F_NODES="$(rt '.nodes|length' | tr -dc '0-9' | head -c 5)"; F_NODES="${F_NODES:-0}"
F_EDGES="$(rt '.edges|length' | tr -dc '0-9' | head -c 5)"; F_EDGES="${F_EDGES:-0}"
[ "$C_NODES" = "$F_NODES" ] || fail "chunked-path node count ($C_NODES) != fast-path ($F_NODES) — chunked write is NOT equivalent"
[ "$C_EDGES" = "$F_EDGES" ] || fail "chunked-path edge count ($C_EDGES) != fast-path ($F_EDGES) — chunked write is NOT equivalent"

# ===========================================================================================
# SUB-TEST 3 — source-orphan / extractor_error -> emitter:"manual" path (CONFIRMED zero-coverage
# gap). Feed a synthetic JSONL record carrying extractor_error directly to transform.jq (no UA
# needed), confirm the emitted node has emitter:"manual" + a non-empty manual_justification,
# AND that emit.sh + the substrate ACCEPT it (the substrate requires manual_justification on a
# manual node — validate-schema would fail otherwise). This proves Doctrine 05 §6.6.
# ===========================================================================================
ORPHAN_DIR="$SCRATCH/orphan"; mkdir -p "$ORPHAN_DIR"
ORPHAN_SUB="$ORPHAN_DIR/graph.json"
cat > "$ORPHAN_DIR/records.jsonl" <<'EOF'
{"kind":"ts_module","rel_path":"src/broken.ts","byte_size":500,"language":"typescript","analysis":{"functions":[],"classes":[],"imports":[],"exports":[]},"extractor_error":"analyzeFile failed: synthetic parse error for eval"}
{"__diagnostics":{"walked":1,"parsed":0,"extractor_failed":1,"ts_module_count":1,"edge_function_count":0}}
EOF
jq -s '.' "$ORPHAN_DIR/records.jsonl" > "$ORPHAN_DIR/records.json"
jq -n --slurpfile records "$ORPHAN_DIR/records.json" --arg now "$NOW" --arg src_commit "fixture123" --argjson alias_map '{"@":"src"}' \
  -f "$TRANSFORM_JQ" > "$ORPHAN_DIR/combined.json" 2>"$ORPHAN_DIR/transform-err" \
  || { echo "FAIL: transform.jq failed on the orphan record"; cat "$ORPHAN_DIR/transform-err" >&2; exit 1; }
# Assert the emitted node is a manual node with a justification.
O_EMITTER="$(jq -r '.nodes[]|select(.id=="repo:src/broken.ts")|.emitter' "$ORPHAN_DIR/combined.json")"
[ "$O_EMITTER" = "manual" ] || fail "orphan node emitter = '$O_EMITTER' (want manual — §6.6 source-orphan path)"
O_JUST="$(jq -r '.nodes[]|select(.id=="repo:src/broken.ts")|.manual_justification // ""' "$ORPHAN_DIR/combined.json")"
[ -n "$O_JUST" ] || fail "orphan node has empty manual_justification (substrate requires it on manual nodes)"
O_DIAG_FAILED="$(jq '.diagnostics.ts_files_extractor_failed' "$ORPHAN_DIR/combined.json" | tr -dc '0-9' | head -c 5)"; O_DIAG_FAILED="${O_DIAG_FAILED:-0}"
[ "$O_DIAG_FAILED" = "1" ] || fail "diagnostics.ts_files_extractor_failed = '$O_DIAG_FAILED' (want 1 — the failed file must be counted)"
# And the substrate must ACCEPT it (validate-schema PASS via the harness).
jq '.nodes' "$ORPHAN_DIR/combined.json" > "$ORPHAN_DIR/nodes.json"
jq '.edges' "$ORPHAN_DIR/combined.json" > "$ORPHAN_DIR/edges.json"
( export TOPOLOGY_SUBSTRATE_PATH="$ORPHAN_SUB"
  bash "$SUBSTRATE_SH" init "fixture-orphan" >/dev/null 2>&1 || exit 1
  bash "$EMIT_SH" "$ORPHAN_DIR/nodes.json" "$ORPHAN_DIR/edges.json" "fixture-orphan" >"$ORPHAN_DIR/emit.out" 2>&1
) || { echo "FAIL: substrate rejected the manual node — §6.6 round-trip broken"; cat "$ORPHAN_DIR/emit.out" >&2; exit 1; }
TOPOLOGY_SUBSTRATE_PATH="$ORPHAN_SUB" bash "$SUBSTRATE_SH" validate-schema 2>&1 | grep -q '^PASS$' || fail "orphan substrate failed validate-schema (manual node not accepted)"

echo "PASS: code-emitter canonical-shape eval — 5 ts_module + 1 edge_function, alias+relative+_shared resolution, unresolved surfaced+dropped, map round-trip, CHUNKED-path equivalence, source-orphan manual node accepted, heartbeat advanced, validate PASS"
exit 0
