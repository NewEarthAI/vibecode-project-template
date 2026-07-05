#!/usr/bin/env bash
# code-emitter/evals/fetch-external.sh — visual-layer follow-up #1 (edge-function/frontend fetch()
# external-API surface). Verifies the bare-global-fetch AST scan (extract.mjs) + the fetch cross-system
# pass (transform.jq classify_fetch_url + 4c) against the LOCKED honesty boundaries:
#   - bare global fetch() matched; a member x.fetch() + a commented fetch are NEVER matched (R13 AST).
#   - a static literal external URL -> external_endpoint (classification external-api) + declared-high.
#   - a static literal supabase REST/fn URL -> resolved to the table/edge_function node (declared-medium/high).
#   - a DYNAMIC url (identifier / template-with-sub / no arg) -> blind-spot (never dropped, never green).
#   - an UNPARSEABLE static url (no scheme/host, relative) -> blind-spot (the R2 no-silent-drop fail-safe).
#   - R2 coverage routing: unresolved supabase literal -> blind-spot UNLESS supabase-live coverage=="covered"
#     (then a counted drop); coverage absent/empty -> blind-spot (no silent drop).
#   - PARITY DRIFT-LOCK: a fixed URL set classifies IDENTICALLY through the fetch path (classify_fetch_url)
#     and the external-api path (classify_url) — pins the supabase/external regexes against future drift.
#   - R8: the substrate node-id resolution read is READ-ONLY (byte-untouched).
#
# Portability: macOS bash 3.2 + jq 1.7. set -uo pipefail per shell-portability.md.
# Exit 0 = all assertions pass (or clean SKIP if UA absent); 1 = a FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRANSFORM_JQ="$SCRIPT_DIR/../scripts/transform.jq"
EXTRACT_MJS="$SCRIPT_DIR/../scripts/extract.mjs"
EXT_TRANSFORM_JQ="$SCRIPT_DIR/../../external-api-graph-emitter/scripts/transform.jq"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"

for f in "$TRANSFORM_JQ" "$EXTRACT_MJS" "$EXT_TRANSFORM_JQ" "$SUBSTRATE_SH"; do
  [ -f "$f" ] || { echo "FAIL: missing $f" >&2; exit 1; }
done
command -v jq   >/dev/null 2>&1 || { echo "FAIL: jq not found" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "FAIL: node not found" >&2; exit 1; }

UA_DIST="${UA_PLUGIN_DIST:-/Users/justin/.claude/plugins/cache/understand-anything/understand-anything/2.7.4/packages/core/dist/index.js}"
if [ ! -f "$UA_DIST" ]; then
  echo "SKIP: Understand-Anything not installed at $UA_DIST — fetch-external eval needs UA to parse fixtures" >&2
  exit 0
fi

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL - $1" >&2; }
eq()   { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got '$2' want '$3'"; fi; }

SCRATCH="$(mktemp -d -t code-emit-fetch-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
FIXTURE="$SCRATCH/repo"; WORK="$SCRATCH/work"
mkdir -p "$FIXTURE/src" "$WORK"
NOW="2026-06-06T00:00:00Z"

# Substrate resolution universe: the deals table + the enrich edge fn exist; ghost_table does NOT.
SUBIDS='["public.deals","repo:supabase/functions/enrich"]'

# ===== Part 1 — the AST scan (extract.mjs fetch detection) =====================
# Every fetch branch + the two non-matches (commented + member call). NO supabase import: the supabase
# scan stays silent (hasClient=false), so this isolates fetch detection.
cat > "$FIXTURE/src/calls.ts" <<'EOF'
export async function run(u: string, id: string, client: any) {
  // fetch('https://commented.out/x') — must be IGNORED (R13 AST comment-skip)
  await fetch('https://api.openai.com/v1/chat/completions');
  await fetch('https://db.supabase.co/rest/v1/deals');
  await fetch('https://db.supabase.co/functions/v1/enrich');
  await fetch(u);
  await fetch(`https://api.x.com/${id}`);
  await fetch('/api/local');
  await fetch('https://api.stripe.com/v1/charges', { method: 'POST' });
  await client.fetch('https://member.call/x');
  return id;
}
EOF

node "$EXTRACT_MJS" "$FIXTURE" > "$WORK/extracted.jsonl" 2>"$WORK/extract-err" || {
  echo "FAIL: extract.mjs nonzero"; cat "$WORK/extract-err" >&2; exit 1; }
jq -s '.' "$WORK/extracted.jsonl" > "$WORK/records.json"
FC="$(jq -c '.[] | select(.rel_path=="src/calls.ts") | .fetch_calls' "$WORK/records.json")"

echo "Part 1 — AST scan:"
# A1 — exactly 7 real fetch calls (the comment + the member x.fetch() are excluded).
eq "A1 seven real fetch_calls (comment + member ignored)" "$(echo "$FC" | jq 'length')" "7"
# A2 — two dynamic (the bare identifier u + the template-with-substitution).
eq "A2 two dynamic fetch urls flagged" "$(echo "$FC" | jq '[.[]|select(.dynamic==true)]|length')" "2"
# A3 — the POST method extracted from the options object.
eq "A3 stripe POST method extracted" \
   "$(echo "$FC" | jq -r '[.[]|select(.url=="https://api.stripe.com/v1/charges")|.method][0]')" "POST"
# A4 — a method-less external call defaults to GET.
eq "A4 openai call defaults to GET" \
   "$(echo "$FC" | jq -r '[.[]|select(.url=="https://api.openai.com/v1/chat/completions")|.method][0]')" "GET"
# A5 — the member call's URL never appears (x.fetch() not matched).
eq "A5 member x.fetch() url absent" \
   "$(echo "$FC" | jq '[.[]|select(.url=="https://member.call/x")]|length')" "0"
# A6 — the relative url captured as a literal (dynamic:false) — classification happens in the transform.
eq "A6 relative '/api/local' captured static (not dynamic)" \
   "$(echo "$FC" | jq '[.[]|select(.url=="/api/local")|select(.dynamic==false)]|length')" "1"
# A7/A8 — a backtick (template_string) method literal is a real write verb, not a silent GET->reads_from.
# (code-council 2026-06-06 IMPORTANT: methodFromOpts must read a no-substitution template_string method.)
mkdir -p "$SCRATCH/mrepo/src"
cat > "$SCRATCH/mrepo/src/m.ts" <<'EOF'
export async function m() {
  await fetch('https://db.supabase.co/rest/v1/deals', { method: `DELETE` });
}
EOF
node "$EXTRACT_MJS" "$SCRATCH/mrepo" > "$WORK/m.jsonl" 2>/dev/null
jq -s '.' "$WORK/m.jsonl" > "$WORK/m.json"
eq "A7 backtick method literal extracted as DELETE" \
   "$(jq -r '.[]|select(.rel_path=="src/m.ts")|.fetch_calls[0].method' "$WORK/m.json")" "DELETE"
MOUT="$(jq -n --slurpfile records "$WORK/m.json" --arg now "$NOW" --arg src_commit c \
        --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$SUBIDS" --arg supabase_coverage covered -f "$TRANSFORM_JQ")"
eq "A8 backtick DELETE -> writes_to edge to public.deals (not reads_from)" \
   "$(echo "$MOUT" | jq '[.edges[]|select(.target=="public.deals" and .type=="writes_to")]|length')" "1"

# ===== Part 1b — parse skip-gate safety (follow-up #3) ========================
# The skip-gate only skips the SECOND (cross-system) tree-sitter parse for files that contain neither a
# Supabase client import NOR a bare `fetch(` token. The token test `\bfetch\s*\(` is whitespace/newline-
# tolerant — these assertions prove there is NO false-NEGATIVE (a real fetch with space/newline before the
# paren is STILL detected) and that a genuinely call-free file is correctly empty (the skip path == the
# parse path for such files).
echo "Part 1b — skip-gate safety:"
mkdir -p "$SCRATCH/sgrepo/src"
cat > "$SCRATCH/sgrepo/src/sg.ts" <<'EOF'
export async function sg(u: string) {
  await fetch ('https://api.spaced.com/x');
  await fetch
    ('https://api.newline.com/y');
}
export function noCalls() { return 41 + 1; }
EOF
node "$EXTRACT_MJS" "$SCRATCH/sgrepo" > "$WORK/sg.jsonl" 2>/dev/null
jq -s '.' "$WORK/sg.jsonl" > "$WORK/sg.json"
SGFC="$(jq -c '.[]|select(.rel_path=="src/sg.ts")|.fetch_calls' "$WORK/sg.json")"
# SG1 — whitespace-before-paren AND newline-before-paren fetches BOTH detected (no false-negative skip).
eq "SG1 two whitespace/newline fetch() still detected (gate keeps them)" "$(echo "$SGFC" | jq 'length')" "2"
eq "SG1b spaced host captured" "$(echo "$SGFC" | jq '[.[]|select(.url=="https://api.spaced.com/x")]|length')" "1"
eq "SG1c newline host captured" "$(echo "$SGFC" | jq '[.[]|select(.url=="https://api.newline.com/y")]|length')" "1"
# SG1d — CRITICAL regression lock (code-council 2026-06-06): an ISOLATED file whose ONLY call is the
# optional-call `fetch?.(...)` — and which imports NO Supabase client — must STILL be detected. The AST
# DOES catch `fetch?.(`, but the old `\bfetch\s*\(` gate skipped this file (no plain `fetch(` to match) ->
# a real silent edge drop. The `\bfetch\b` word-gate keeps it. This assertion FAILS if the gate regresses.
mkdir -p "$SCRATCH/optrepo/src"
cat > "$SCRATCH/optrepo/src/o.ts" <<'EOF'
export async function o() {
  await fetch?.('https://api.optional.com/z');
}
EOF
node "$EXTRACT_MJS" "$SCRATCH/optrepo" > "$WORK/o.jsonl" 2>/dev/null
jq -s '.' "$WORK/o.jsonl" > "$WORK/o.json"
eq "SG1d optional-call-only file (no supabase import) STILL detected (word-gate, no silent skip)" \
   "$(jq '[.[]|select(.rel_path=="src/o.ts")|.fetch_calls[]|select(.url=="https://api.optional.com/z")]|length' "$WORK/o.json")" "1"
# SG2 — a genuinely call-free file (no supabase import, no fetch) yields zero cross-system calls. (This
# holds on any code path; the load-bearing skip-gate guard is SG1/SG1d's tolerance. SG2 + SG2b just
# confirm a call-free file is still fully analysed and produces no spurious cross-system calls.)
mkdir -p "$SCRATCH/nrepo/src"
cat > "$SCRATCH/nrepo/src/none.ts" <<'EOF'
import { useState } from "react";
export function useThing() { const [n] = useState(0); return n + 1; }
EOF
node "$EXTRACT_MJS" "$SCRATCH/nrepo" > "$WORK/n.jsonl" 2>/dev/null
jq -s '.' "$WORK/n.jsonl" > "$WORK/n.json"
eq "SG2 call-free file: zero fetch_calls + zero supabase_calls (skipped, empty)" \
   "$(jq -c '.[]|select(.rel_path=="src/none.ts")|[(.fetch_calls|length),(.supabase_calls|length)]|@csv' "$WORK/n.json")" '"0,0"'
eq "SG2b call-free file STILL analysed (import counted — main analysis untouched by the gate)" \
   "$(jq '[.[]|select(.rel_path=="src/none.ts")|.analysis.imports|length]|add' "$WORK/n.json")" "1"

# ===== Part 2 — transform routing (honesty boundaries) ========================
echo "Part 2 — transform routing:"
fxs() {  # fxs <substrate_ids-json> <coverage> -> combined.json on stdout
  jq -n --slurpfile records "$WORK/records.json" --arg now "$NOW" --arg src_commit "fix123" \
    --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$1" --arg supabase_coverage "$2" \
    -f "$TRANSFORM_JQ"
}
COV="$(fxs "$SUBIDS" covered)"
# B1 — declared-high fetch edges = 2 external (openai+stripe) + 1 resolved supabase-fn (enrich) = 3.
eq "B1 three declared-high fetch edges (2 external + 1 resolved supabase-fn)" \
   "$(echo "$COV" | jq '.diagnostics.fetch_edges_declared_high')" "3"
eq "B2 fetch_external_endpoints == 2" \
   "$(echo "$COV" | jq '.diagnostics.fetch_external_endpoints')" "2"
# B3 — the openai external_endpoint node exists with classification external-api + host.
eq "B3 openai external_endpoint node (external-api, host)" \
   "$(echo "$COV" | jq -r '[.nodes[]|select(.id=="ext:external-api:api.openai.com/v1/chat/completions")|.attributes.classification][0]')" "external-api"
eq "B3b openai node host captured" \
   "$(echo "$COV" | jq -r '[.nodes[]|select(.id=="ext:external-api:api.openai.com/v1/chat/completions")|.attributes.url_host][0]')" "api.openai.com"
eq "B3c openai node emitter dependency_cruiser (joint-attribution)" \
   "$(echo "$COV" | jq -r '[.nodes[]|select(.id=="ext:external-api:api.openai.com/v1/chat/completions")|.emitter][0]')" "dependency_cruiser"
# B4 — supabase REST url resolved to public.deals (reads_from, declared-medium).
eq "B4 fetch supabase-rest resolved to public.deals reads_from declared-medium" \
   "$(echo "$COV" | jq '[.edges[]|select(.target=="public.deals" and .type=="reads_from" and .attributes.confidence=="declared-medium")]|length')" "1"
# B5 — supabase fn url resolved to the enrich edge fn (invokes, declared-high).
eq "B5 fetch supabase-fn resolved to enrich invokes declared-high" \
   "$(echo "$COV" | jq '[.edges[]|select(.target=="repo:supabase/functions/enrich" and .type=="invokes" and .attributes.confidence=="declared-high")]|length')" "1"
# B6 — POST stripe edge carries [POST] in derivation + external-api node has method POST.
eq "B6 stripe external node method POST" \
   "$(echo "$COV" | jq -r '[.nodes[]|select(.id=="ext:external-api:api.stripe.com/v1/charges")|.attributes.method][0]')" "POST"
# B7 — dynamic urls -> per-site blind-spots (the identifier + the template-with-sub = 2).
eq "B7 two dynamic fetch blind-spots" \
   "$(echo "$COV" | jq '[.nodes[]|select(.kind=="external_endpoint" and .attributes.classification=="blind-spot" and (.attributes.url_path_template=="fetch(<dynamic>)"))]|length')" "2"
# B8 — unparseable '/api/local' -> blind-spot (never green, never dropped).
eq "B8 unparseable '/api/local' -> a blind-spot edge" \
   "$(echo "$COV" | jq '[.edges[]|select(.attributes.confidence=="blind-spot")|select(.attributes.derivation|test("/api/local"))]|length')" "1"
# B9 — ACCOUNTING: every fetch call accounted (edge|blind-spot|drop) — no silent vanish.
eq "B9 fetch accounting: total == hi+med+blind+drops" \
   "$(echo "$COV" | jq '.diagnostics as $d | ($d.fetch_calls_total) == ($d.fetch_edges_declared_high + $d.fetch_edges_declared_medium + $d.fetch_blind_spots + $d.fetch_counted_drops)')" "true"
# B10 — covered: NO unresolved supabase literal here (deals+enrich resolve), so zero fetch drops.
eq "B10 covered: zero fetch counted drops (both supabase targets resolve)" \
   "$(echo "$COV" | jq '.diagnostics.fetch_counted_drops')" "0"

# Part 2b — credential / query-secret stripping (code-council 2026-06-06 IMPORTANT). A hardcoded userinfo
# URL must NOT leak credentials into the node id, url_host, or the edge derivation; a query secret must not
# survive into the derivation.
mkdir -p "$SCRATCH/crepo/src"
cat > "$SCRATCH/crepo/src/cred.ts" <<'EOF'
export async function c() {
  await fetch('https://apikey:s3cr3t@api.vendor.com/v1/data?token=ALSO_SECRET');
}
EOF
node "$EXTRACT_MJS" "$SCRATCH/crepo" > "$WORK/c.jsonl" 2>/dev/null
jq -s '.' "$WORK/c.jsonl" > "$WORK/c.json"
COUT="$(jq -n --slurpfile records "$WORK/c.json" --arg now "$NOW" --arg src_commit c \
        --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$SUBIDS" --arg supabase_coverage covered -f "$TRANSFORM_JQ")"
eq "B16 node id carries no credential" \
   "$(echo "$COUT" | jq '[.nodes[]|select(.kind=="external_endpoint")|select(.id|test("s3cr3t"))]|length')" "0"
eq "B17 url_host is the clean host (userinfo stripped)" \
   "$(echo "$COUT" | jq -r '[.nodes[]|select(.id=="ext:external-api:api.vendor.com/v1/data")|.attributes.url_host][0]')" "api.vendor.com"
eq "B18 derivation has no credential AND no query secret" \
   "$(echo "$COUT" | jq '[.edges[]|select(.attributes.derivation|test("s3cr3t|ALSO_SECRET"))]|length')" "0"

# Coverage routing fail-safe for UNRESOLVED supabase targets — ISOLATED fixture (only the ghosts, so the
# count is unambiguous; calls.ts's own blind-spots must not bleed in). Both a REST table + a FUNCTION ghost:
# the function case is the worst false-green (resolved-fn confidence is declared-HIGH).
mkdir -p "$SCRATCH/grepo/src"
cat > "$SCRATCH/grepo/src/ghost.ts" <<'EOF'
export async function g() {
  await fetch('https://db.supabase.co/rest/v1/ghost_table');
  await fetch('https://db.supabase.co/functions/v1/ghostfn');
}
EOF
node "$EXTRACT_MJS" "$SCRATCH/grepo" > "$WORK/extracted2.jsonl" 2>/dev/null
jq -s '.' "$WORK/extracted2.jsonl" > "$WORK/records2.json"
gfxs() {
  jq -n --slurpfile records "$WORK/records2.json" --arg now "$NOW" --arg src_commit "fix123" \
    --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$SUBIDS" --arg supabase_coverage "$1" \
    -f "$TRANSFORM_JQ"
}
GCOV="$(gfxs covered)"; GMISS="$(gfxs declared-missing)"; GABS="$(gfxs "")"; GABS2="$(gfxs absent)"
# B11 — covered + 2 unresolved ghosts -> 2 COUNTED DROPS (genuine dangling refs).
eq "B11 covered: 2 ghosts -> 2 counted drops" \
   "$(echo "$GCOV" | jq '.diagnostics.fetch_counted_drops')" "2"
# B12 — declared-missing -> 2 blind-spots, ZERO drops (fail-safe).
eq "B12 declared-missing: 2 ghosts -> blind-spots, zero drops" \
   "$(echo "$GMISS" | jq '[.diagnostics.fetch_blind_spots, .diagnostics.fetch_counted_drops]|@csv')" '"2,0"'
# B13 — coverage ABSENT (empty string) -> blind-spots, ZERO drops (the no-silent-drop fail-safe).
eq "B13 coverage-absent (empty): 2 ghosts -> blind-spots, zero drops" \
   "$(echo "$GABS" | jq '[.diagnostics.fetch_blind_spots, .diagnostics.fetch_counted_drops]|@csv')" '"2,0"'
# B13b — coverage 'absent' (the named enum value, not empty) routes identically (no special-casing).
eq "B13b coverage 'absent' enum: 2 ghosts -> blind-spots, zero drops" \
   "$(echo "$GABS2" | jq '[.diagnostics.fetch_blind_spots, .diagnostics.fetch_counted_drops]|@csv')" '"2,0"'
# B14 — CRITICAL regression (code-council 2026-06-06): EVERY edge to an unresolved-supabase blind-spot
# target carries confidence "blind-spot" — never the resolved-target confidence (the false-green the 4c
# pass originally shipped). Checks the EDGE confidence, not just the diagnostics counter.
eq "B14 CRITICAL: every unresolved-supabase edge is blind-spot confidence (never green)" \
   "$(echo "$GMISS" | jq -r '[.edges[]|select(.target|startswith("ext:blind-spot:"))|.attributes.confidence]|unique|join(",")')" "blind-spot"
# B15 — the worst case specifically: an unresolved supabase FUNCTION edge (resolved-conf would be
# declared-HIGH) must render blind-spot, not declared-high.
eq "B15 CRITICAL: unresolved supabase-FUNC edge is blind-spot (not declared-high)" \
   "$(echo "$GMISS" | jq -r '[.edges[]|select(.target=="ext:blind-spot:repo:supabase/functions/ghostfn")|.attributes.confidence][0]')" "blind-spot"

# ===== Part 3 — PARITY DRIFT-LOCK (fetch path vs n8n external-api path) ========
# The same URL must classify IDENTICALLY through classify_fetch_url (code emitter) and classify_url
# (external-api emitter). Pins the supabase-rest / supabase-func / external host-capture regexes against
# silent drift between the two siblings. Compared by the OBSERVABLE: (target id, confidence).
echo "Part 3 — classify parity drift-lock:"
mkdir -p "$SCRATCH/p/src"
cat > "$SCRATCH/p/src/p.ts" <<'EOF'
export async function p() {
  await fetch('https://api.openai.com/v1/chat/completions');
  await fetch('https://db.supabase.co/rest/v1/deals');
  await fetch('https://db.supabase.co/functions/v1/enrich');
}
EOF
node "$EXTRACT_MJS" "$SCRATCH/p" > "$WORK/p.jsonl" 2>/dev/null
jq -s '.' "$WORK/p.jsonl" > "$WORK/p.json"
PF="$(jq -n --slurpfile records "$WORK/p.json" --arg now "$NOW" --arg src_commit c \
       --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$SUBIDS" --arg supabase_coverage covered \
       -f "$TRANSFORM_JQ")"
# n8n path: one httpRequest node per URL (GET), same substrate ids + coverage.
cat > "$WORK/wfs.json" <<'EOF'
[ { "id": "wfp", "nodes": [
    { "id": "n1", "name": "openai", "type": "n8n-nodes-base.httpRequest",
      "parameters": { "url": "https://api.openai.com/v1/chat/completions", "method": "GET" } },
    { "id": "n2", "name": "deals", "type": "n8n-nodes-base.httpRequest",
      "parameters": { "url": "https://db.supabase.co/rest/v1/deals", "method": "GET" } },
    { "id": "n3", "name": "enrich", "type": "n8n-nodes-base.httpRequest",
      "parameters": { "url": "https://db.supabase.co/functions/v1/enrich", "method": "GET" } } ] } ]
EOF
NF="$(jq -n --slurpfile workflows "$WORK/wfs.json" --arg now "$NOW" --arg src_commit c \
       --argjson substrate_ids "$SUBIDS" --arg supabase_coverage covered -f "$EXT_TRANSFORM_JQ")"

# helper: confidence on the edge to target T, from a combined.json
conf_to() { echo "$1" | jq -r --arg t "$2" '[.edges[]|select(.target==$t)|.attributes.confidence]|first // "MISSING"'; }
for pair in \
  "ext:external-api:api.openai.com/v1/chat/completions|declared-high" \
  "public.deals|declared-medium" \
  "repo:supabase/functions/enrich|declared-high"; do
  T="${pair%%|*}"; WANT="${pair##*|}"
  FCONF="$(conf_to "$PF" "$T")"; NCONF="$(conf_to "$NF" "$T")"
  eq "P parity fetch[$T]==$WANT" "$FCONF" "$WANT"
  eq "P parity n8n[$T]==fetch[$T]" "$NCONF" "$FCONF"
done

# ===== Part 4 — end-to-end emit + READ-ONLY (R8) ==============================
echo "Part 4 — end-to-end + byte-untouched:"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
bash "$SUBSTRATE_SH" init "fixture-entity" >/dev/null 2>&1
bash "$SUBSTRATE_SH" bulk-write \
  '[{"id":"public.deals","kind":"table","source_file":"m.sql","source_commit":"c","timestamp":"'"$NOW"'","source_line":1,"emitter":"pg_depend","attributes":{}},
    {"id":"repo:supabase/functions/enrich","kind":"edge_function","source_file":"supabase/functions/enrich/index.ts","source_commit":"c","timestamp":"'"$NOW"'","source_line":1,"emitter":"dependency_cruiser","attributes":{}}]' '[]' >/dev/null 2>&1
bash "$SUBSTRATE_SH" mark-emitter-ran supabase-live covered >/dev/null 2>&1

HASH_BEFORE="$(shasum -a 256 "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
LIVE_IDS="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[].id]' 2>/dev/null)"
LIVE_COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters["supabase-live"].coverage' 2>/dev/null | tr -d '"')"
HASH_AFTER="$(shasum -a 256 "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
eq "D1 R8 substrate byte-untouched by resolution read" "$HASH_BEFORE" "$HASH_AFTER"

# Emit the Part-1 calls.ts graph (external + supabase-resolved + blind-spots) into the substrate.
FULL="$(fxs "$LIVE_IDS" "$LIVE_COV")"
echo "$FULL" | jq '.nodes' > "$WORK/nodes.json"
echo "$FULL" | jq '.edges' > "$WORK/edges.json"
EMIT_OUT="$(bash "$SCRIPT_DIR/../scripts/emit.sh" "$WORK/nodes.json" "$WORK/edges.json" "fixture-entity" 2>&1)"
EMIT_RC=$?
eq "D2 full pipeline emit.sh rc==0" "$EMIT_RC" "0"
# The external_endpoint nodes + cross-system edges landed, and the substrate still validates.
LANDED_EXT="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[]|select(.kind=="external_endpoint" and .attributes.classification=="external-api")]|length' 2>/dev/null)"
eq "D3 external-api endpoints landed in substrate (>=2)" "$( [ "${LANDED_EXT:-0}" -ge 2 ] && echo yes || echo no )" "yes"
VAL="$(bash "$SUBSTRATE_SH" validate-schema 2>&1 | tail -1)"
eq "D4 substrate validate-schema PASS after fetch write" "$VAL" "PASS"

# ===== summary ===============================================================
echo "-------------------------------------------"
echo "fetch-external.sh: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
