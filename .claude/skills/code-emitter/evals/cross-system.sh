#!/usr/bin/env bash
# code-emitter/evals/cross-system.sh — Phase 1a (visual-layer cross-system edges).
#
# Verifies the supabase-call AST scan (extract.mjs) + the cross-system edge pass (transform.jq)
# against the council resolutions (2026-06-05, council/sessions/2026-06-05-visual-layer-phases-0-2-build-gate.md):
#   R13 AST-not-regex: a commented-out call is NEVER scanned; a bare from() is never matched.
#   R4  provenance gate: a non-supabase-importing file's .from() yields ZERO calls (false-positive bait).
#   R3  dynamic arg -> blind-spot (never a silent drop).
#   R2  unresolved literal -> blind-spot UNLESS supabase-live coverage == "covered" (then a counted drop);
#       coverage absent/empty -> blind-spot (the fail-safe — the CRITICAL-2 silent-drop fix).
#   R9  id normalisation: from('public.deals') -> public.deals (not public.public.deals); from('app.x') -> app.x.
#   declared-high (invoke resolved) / declared-medium (from resolved) / blind-spot confidence classes.
#   R8  the substrate node-id resolution read is READ-ONLY (byte-untouched).
#   Part 4 (follow-up #2, 2026-06-07): DI (this.<conv> client) scanner — fixture-only, SPECULATIVE.
#       Convention-gated this.<conv>.from/invoke -> declared-medium cap + DI derivation marker; a
#       non-convention this.<other>.from() yields ZERO edges (false-POSITIVE guard); dynamic -> blind-spot.
#
# Portability: macOS bash 3.2 + jq 1.7. set -uo pipefail per shell-portability.md.
# Exit 0 = all assertions pass (or clean SKIP if UA absent); 1 = a FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRANSFORM_JQ="$SCRIPT_DIR/../scripts/transform.jq"
EXTRACT_MJS="$SCRIPT_DIR/../scripts/extract.mjs"
SUBSTRATE_SH="$SCRIPT_DIR/../../topology-substrate/scripts/substrate.sh"

for f in "$TRANSFORM_JQ" "$EXTRACT_MJS" "$SUBSTRATE_SH"; do
  [ -f "$f" ] || { echo "FAIL: missing $f" >&2; exit 1; }
done
command -v jq   >/dev/null 2>&1 || { echo "FAIL: jq not found" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "FAIL: node not found" >&2; exit 1; }

UA_DIST="${UA_PLUGIN_DIST:-/Users/justin/.claude/plugins/cache/understand-anything/understand-anything/2.7.4/packages/core/dist/index.js}"
if [ ! -f "$UA_DIST" ]; then
  echo "SKIP: Understand-Anything not installed at $UA_DIST — cross-system eval needs UA to parse fixtures" >&2
  exit 0
fi

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL - $1" >&2; }
eq()   { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got '$2' want '$3'"; fi; }

SCRATCH="$(mktemp -d -t code-emit-xs-XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
FIXTURE="$SCRATCH/repo"; WORK="$SCRATCH/work"
mkdir -p "$FIXTURE/src" "$WORK"
NOW="2026-06-05T00:00:00Z"

# ===== Part 1 — the AST scan (extract.mjs) =====================================
# A supabase-importing file exercising every scan branch; a non-importing bait file.
cat > "$FIXTURE/src/data.ts" <<'EOF'
import { supabase } from "@/integrations/supabase/client";
export async function load() {
  // supabase.from('commented_out') — must be IGNORED (R13 AST comment-skip)
  const a = await supabase.from('deals').select();
  await supabase.from('public.leads').insert({ x: 1 });
  await supabase.from('app.audit').update({ y: 2 });
  const t = 'runtime'; await supabase.from(t).select();
  await supabase.functions.invoke('enrich');
  await supabase.from('ghost_table').select();
  await supabase.from('').select();
  return a;
}
EOF
# Bait: NO supabase import; an RxJS-style bare from() + a non-supabase obj.from() — R4 gate 1.
cat > "$FIXTURE/src/bait.ts" <<'EOF'
import { from } from "rxjs";
import { db } from "@/lib/drizzle";
export function noise() {
  const s = from([1, 2, 3]);
  const r = db.from('orders').where('id', 1);
  return [s, r];
}
EOF

node "$EXTRACT_MJS" "$FIXTURE" > "$WORK/extracted.jsonl" 2>"$WORK/extract-err" || {
  echo "FAIL: extract.mjs nonzero"; cat "$WORK/extract-err" >&2; exit 1; }
jq -s '.' "$WORK/extracted.jsonl" > "$WORK/records.json"

DATA_CALLS="$(jq -c '.[] | select(.rel_path=="src/data.ts") | .supabase_calls' "$WORK/records.json")"
BAIT_CALLS="$(jq -c '.[] | select(.rel_path=="src/bait.ts") | .supabase_calls' "$WORK/records.json")"

echo "Part 1 — AST scan:"
# A1 — false-positive bait: a non-supabase-importing file yields ZERO calls (R4 gate 1).
eq "A1 bait file zero supabase_calls" "$(echo "$BAIT_CALLS" | jq 'length')" "0"
# A2 — commented-out call NOT scanned: only the 7 real calls, not the comment (R13).
eq "A2 data.ts has exactly 7 real calls (comment ignored)" "$(echo "$DATA_CALLS" | jq 'length')" "7"
# A3 — dynamic args flagged dynamic:true (the from(t) identifier + the empty from('') — fix 5).
eq "A3 dynamic from(t) + empty from('') flagged dynamic (2)" \
   "$(echo "$DATA_CALLS" | jq -c '[.[]|select(.dynamic==true)]|length')" "2"
# A4 — write-method chain detected (.insert / .update -> op:write).
eq "A4 two write ops detected (insert+update)" \
   "$(echo "$DATA_CALLS" | jq '[.[]|select(.op=="write")]|length')" "2"
# A5 — invoke literal captured.
eq "A5 invoke('enrich') captured" \
   "$(echo "$DATA_CALLS" | jq -r '[.[]|select(.call=="invoke")|.literal][0]')" "enrich"
# A6 — schema-qualified literal preserved verbatim by the scan (normalisation happens in transform).
eq "A6 schema-qualified literal 'app.audit' captured raw" \
   "$(echo "$DATA_CALLS" | jq -r '[.[]|select(.literal=="app.audit")]|length')" "1"

# ===== Part 2 — transform routing (R2 / R9 / confidence classes) ==============
echo "Part 2 — transform routing:"
xs() {  # xs <substrate_ids-json> <coverage> -> combined.json on stdout
  jq -n --slurpfile records "$WORK/records.json" --arg now "$NOW" --arg src_commit "fix123" \
    --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$1" --arg supabase_coverage "$2" \
    -f "$TRANSFORM_JQ"
}
# Substrate has public.deals + public.leads + the enrich edge fn; NOT app.audit, NOT ghost_table.
SUBIDS='["public.deals","public.leads","repo:supabase/functions/enrich"]'

# Covered: ghost_table + app.audit unresolved -> counted DROPS (genuine dangling refs).
COV="$(xs "$SUBIDS" covered)"
eq "B1 declared-high invoke edge (covered)" \
   "$(echo "$COV" | jq '.diagnostics.cross_system_edges_declared_high')" "1"
eq "B2 declared-medium from edges (deals read + leads write)" \
   "$(echo "$COV" | jq '.diagnostics.cross_system_edges_declared_medium')" "2"
eq "B3 covered: dynamic blind-spots (from(t) + empty from('') = 2)" \
   "$(echo "$COV" | jq '.diagnostics.cross_system_blind_spots')" "2"
eq "B4 covered: app.audit + ghost_table are COUNTED DROPS (2)" \
   "$(echo "$COV" | jq '.diagnostics.cross_system_counted_drops')" "2"
# R9: deals resolved as public.deals (NOT public.public.deals) — a real edge, not a blind-spot.
eq "B5 R9 from('deals') resolved to public.deals" \
   "$(echo "$COV" | jq '[.edges[]|select(.target=="public.deals")]|length')" "1"
eq "B6 R9 no double-prefix node public.public.leads exists" \
   "$(echo "$COV" | jq '[.edges[]|select(.target=="public.public.leads")]|length')" "0"

# Declared-missing: unresolved literals become BLIND-SPOTS, zero drops (R2).
MISS="$(xs "$SUBIDS" declared-missing)"
eq "B7 declared-missing: 4 blind-spots (dynamic + empty + app.audit + ghost_table)" \
   "$(echo "$MISS" | jq '.diagnostics.cross_system_blind_spots')" "4"
eq "B8 declared-missing: ZERO counted drops (fail-safe)" \
   "$(echo "$MISS" | jq '.diagnostics.cross_system_counted_drops')" "0"
# the shared unresolved-literal blind-spot id, and the per-site dynamic id.
eq "B9 unresolved-literal blind-spot id ext:blind-spot:public.ghost_table present" \
   "$(echo "$MISS" | jq '[.nodes[]|select(.id=="ext:blind-spot:public.ghost_table")]|length')" "1"
eq "B10 blind-spot node classification == blind-spot" \
   "$(echo "$MISS" | jq -r '[.nodes[]|select(.kind=="external_endpoint")|.attributes.classification]|unique|join(",")')" "blind-spot"
eq "B11 blind-spot EDGE confidence == blind-spot" \
   "$(echo "$MISS" | jq -r '[.edges[]|select(.attributes.confidence=="blind-spot")]|length>0')" "true"

# Coverage ABSENT (empty) — the CRITICAL-2 fix: still blind-spots, never a silent drop.
ABSENT="$(xs "$SUBIDS" "")"
eq "B12 coverage-absent: ZERO counted drops (no silent drop)" \
   "$(echo "$ABSENT" | jq '.diagnostics.cross_system_counted_drops')" "0"
eq "B13 coverage-absent: unresolved -> blind-spots (>=3)" \
   "$(echo "$ABSENT" | jq '.diagnostics.cross_system_blind_spots>=3')" "true"

# ===== Part 3 — end-to-end + READ-ONLY (R8) ===================================
echo "Part 3 — end-to-end + byte-untouched:"
export TOPOLOGY_SUBSTRATE_PATH="$SCRATCH/topology-graph.json"
bash "$SUBSTRATE_SH" init "fixture-entity" >/dev/null 2>&1
# Seed the resolution targets (simulate supabase-live covered) so cross-system edges can WRITE.
bash "$SUBSTRATE_SH" bulk-write \
  '[{"id":"public.deals","kind":"table","source_file":"m.sql","source_commit":"c","timestamp":"'"$NOW"'","source_line":1,"emitter":"pg_depend","attributes":{}},
    {"id":"public.leads","kind":"table","source_file":"m.sql","source_commit":"c","timestamp":"'"$NOW"'","source_line":1,"emitter":"pg_depend","attributes":{}},
    {"id":"repo:supabase/functions/enrich","kind":"edge_function","source_file":"supabase/functions/enrich/index.ts","source_commit":"c","timestamp":"'"$NOW"'","source_line":1,"emitter":"dependency_cruiser","attributes":{}}]' '[]' >/dev/null 2>&1
bash "$SUBSTRATE_SH" mark-emitter-ran supabase-live covered >/dev/null 2>&1

# R8 — the resolution read is READ-ONLY: hash before, read node-ids, hash after.
HASH_BEFORE="$(shasum -a 256 "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
LIVE_IDS="$(bash "$SUBSTRATE_SH" read-topology '[.nodes[].id]' 2>/dev/null)"
LIVE_COV="$(bash "$SUBSTRATE_SH" read-topology '.emitters["supabase-live"].coverage' 2>/dev/null | tr -d '"')"
HASH_AFTER="$(shasum -a 256 "$TOPOLOGY_SUBSTRATE_PATH" | awk '{print $1}')"
eq "C1 R8 substrate byte-untouched by resolution read" "$HASH_BEFORE" "$HASH_AFTER"
eq "C2 live coverage read == covered" "$LIVE_COV" "covered"

# Run the transform against the LIVE substrate ids + coverage, then emit.
FULL="$(xs "$LIVE_IDS" "$LIVE_COV")"
echo "$FULL" | jq '.nodes' > "$WORK/nodes.json"
echo "$FULL" | jq '.edges' > "$WORK/edges.json"
EMIT_OUT="$(bash "$SCRIPT_DIR/../scripts/emit.sh" "$WORK/nodes.json" "$WORK/edges.json" "fixture-entity" 2>&1)"
EMIT_RC=$?
eq "C3 full pipeline emit.sh rc==0" "$EMIT_RC" "0"
# The cross-system edges landed + the substrate still validates.
LANDED="$(bash "$SUBSTRATE_SH" read-topology '[.edges[]|select(.attributes.confidence=="declared-high" or .attributes.confidence=="declared-medium")]|length' 2>/dev/null)"
eq "C4 cross-system edges (hi+med) landed in substrate" "$LANDED" "3"
VAL="$(bash "$SUBSTRATE_SH" validate-schema 2>&1 | tail -1)"
eq "C5 substrate validate-schema PASS after cross-system write" "$VAL" "PASS"

# ===== Part 4 — DI (dependency-injection) scanner (follow-up #2) ==============
# SPECULATIVE / FIXTURE-ONLY (operator override of a recorded deferral 2026-06-07): NO live target uses the
# DI pattern, so this validates the this.<conv>.from/invoke matcher, the declared-medium cap (DI invoke must
# NEVER be declared-high), the dynamic-arg -> blind-spot guard, and — load-bearing — the false-POSITIVE guard
# (a non-convention this.<other>.from() yields ZERO edges). Its OWN isolated fixture + records keep Parts 1-3
# aggregate counts byte-identical (the imported-singleton assertions are unchanged).
echo "Part 4 — DI scanner (fixture-only):"
FIXTURE2="$SCRATCH/repo-di"; WORK2="$SCRATCH/work-di"
mkdir -p "$FIXTURE2/src" "$WORK2"
cat > "$FIXTURE2/src/repo.ts" <<'EOF'
import { SupabaseClient } from "@supabase/supabase-js";
export class DealRepo {
  constructor(private supabase: SupabaseClient, private notSupabase: SupabaseClient) {}
  read()         { return this.supabase.from('di_deals').select('*'); }
  write()        { return this.supabase.from('di_audit').insert({ x: 1 }); }
  dyn(t: string) { return this.supabase.from(t).select(); }
  call()         { return this.supabase.functions.invoke('di_enrich'); }
  bait()         { return this.notSupabase.from('should_not_emit').select(); }
}
EOF
node "$EXTRACT_MJS" "$FIXTURE2" > "$WORK2/extracted.jsonl" 2>"$WORK2/extract-err" || {
  echo "FAIL: extract.mjs (DI) nonzero"; cat "$WORK2/extract-err" >&2; exit 1; }
jq -s '.' "$WORK2/extracted.jsonl" > "$WORK2/records.json"
DI_CALLS="$(jq -c '.[] | select(.rel_path=="src/repo.ts") | .supabase_calls' "$WORK2/records.json")"

# D1 — exactly 4 DI calls scanned (read+write+dyn+invoke); the notSupabase bait is NOT one of them.
eq "D1 repo.ts has exactly 4 supabase_calls (bait excluded)" \
   "$(echo "$DI_CALLS" | jq 'length')" "4"
# D2 — false-POSITIVE guard at AST level: the non-convention this.notSupabase.from() emitted ZERO calls.
eq "D2 this.notSupabase.from('should_not_emit') yields ZERO calls" \
   "$(echo "$DI_CALLS" | jq '[.[]|select(.literal=="should_not_emit")]|length')" "0"
# D3 — all 4 scanned calls are tagged di:true (convention-inferred binding marker).
eq "D3 all 4 DI calls tagged di==true" \
   "$(echo "$DI_CALLS" | jq '[.[]|select(.di==true)]|length')" "4"
# D4 — write-method chain on a DI receiver still detected (this.supabase.from('di_audit').insert).
eq "D4 DI write op detected (di_audit insert -> op:write)" \
   "$(echo "$DI_CALLS" | jq '[.[]|select(.op=="write")]|length')" "1"
# D5 — dynamic arg on a DI receiver flagged dynamic (this.supabase.from(t)).
eq "D5 DI dynamic from(t) flagged dynamic" \
   "$(echo "$DI_CALLS" | jq '[.[]|select(.dynamic==true)]|length')" "1"

xs2() {  # xs2 <substrate_ids-json> <coverage> -> combined.json over the DI fixture records
  jq -n --slurpfile records "$WORK2/records.json" --arg now "$NOW" --arg src_commit "fix123" \
    --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$1" --arg supabase_coverage "$2" \
    -f "$TRANSFORM_JQ"
}
# Resolve di_deals/di_audit/di_enrich so they become edges (not unresolved blind-spots); dyn stays blind-spot.
DISUB='["public.di_deals","public.di_audit","repo:supabase/functions/di_enrich"]'
DIOUT="$(xs2 "$DISUB" covered)"

# D6 (a) — DI from('di_deals') -> reads_from declared-medium WITH the DI derivation marker.
eq "D6 DI read -> reads_from declared-medium + DI marker" \
   "$(echo "$DIOUT" | jq '[.edges[]|select(.target=="public.di_deals" and .type=="reads_from" and .attributes.confidence=="declared-medium" and (.attributes.derivation|test("DI")))]|length')" "1"
# D7 (d) — DI invoke is capped at declared-medium, NEVER declared-high.
eq "D7 DI invoke -> declared-medium (NOT declared-high)" \
   "$(echo "$DIOUT" | jq -r '[.edges[]|select(.type=="invokes" and .target=="repo:supabase/functions/di_enrich")|.attributes.confidence][0]')" "declared-medium"
# D8 (b) — DI dynamic from -> blind-spot (never a silent drop, never declared-medium).
eq "D8 DI dynamic from -> blind-spot edge" \
   "$(echo "$DIOUT" | jq '[.edges[]|select(.attributes.confidence=="blind-spot" and (.attributes.derivation|test("DI")))]|length')" "1"
# D9 (c) — false-POSITIVE guard at transform level: NO edge targets the bait table.
eq "D9 no edge targets the bait table should_not_emit" \
   "$(echo "$DIOUT" | jq '[.edges[]|select(.target|test("should_not_emit"))]|length')" "0"
# D10 — the cap holds in aggregate: NO DI-marked edge is declared-high (the never-overstate-provenance lock).
eq "D10 zero DI edges are declared-high (cap holds in aggregate)" \
   "$(echo "$DIOUT" | jq '[.edges[]|select((.attributes.derivation|test("DI")) and .attributes.confidence=="declared-high")]|length')" "0"
# D11 — exactly 4 DI-marked edges total (read+write+invoke+dynamic blind-spot); bait contributes none.
eq "D11 exactly 4 DI-marked edges (bait excluded)" \
   "$(echo "$DIOUT" | jq '[.edges[]|select(.attributes.derivation|test("DI"))]|length')" "4"

# ===== Part 5 — DI regression locks (code-council 2026-06-07) =================
# Locks three paths that are CORRECT today but were UNasserted (a future refactor could break them silently):
#   (i)  mixed file — a VALUE-imported singleton client named `supabase` AND a this.supabase DI receiver in the
#        SAME file (same prop name): the highest-risk leak path. Singleton MUST stay declared-high + no di key;
#        DI MUST cap to declared-medium. Locks the `singleton ? null : diClientProp` precedence line.
#   (ii) no-import bait — a this.supabase DI receiver in a file importing NO supabase client (hasClient false)
#        -> ZERO calls. The DI twin of A1; guards against hoisting the DI matcher outside the hasClient gate.
#   (iii)dynamic DI invoke -> blind-spot (the dynamic guard on the invoke surface, not only from).
echo "Part 5 — DI regression locks:"
FIXTURE3="$SCRATCH/repo-di2"; WORK3="$SCRATCH/work-di2"
mkdir -p "$FIXTURE3/src" "$WORK3"
cat > "$FIXTURE3/src/mixed.ts" <<'EOF'
import { supabase } from "@/integrations/supabase/client";
export async function singletonLoad() {
  return supabase.functions.invoke('singleton_fn');
}
export class MixedRepo {
  constructor(private supabase: any) {}
  diCall()  { return this.supabase.functions.invoke('di_fn'); }
  diDyn(f)  { return this.supabase.functions.invoke(f); }
}
EOF
cat > "$FIXTURE3/src/noimport.ts" <<'EOF'
export class NoImportRepo {
  constructor(private supabase: any) {}
  read() { return this.supabase.from('no_import_table').select(); }
}
EOF
node "$EXTRACT_MJS" "$FIXTURE3" > "$WORK3/extracted.jsonl" 2>"$WORK3/extract-err" || {
  echo "FAIL: extract.mjs (DI locks) nonzero"; cat "$WORK3/extract-err" >&2; exit 1; }
jq -s '.' "$WORK3/extracted.jsonl" > "$WORK3/records.json"
MIX_CALLS="$(jq -c '.[] | select(.rel_path=="src/mixed.ts") | .supabase_calls' "$WORK3/records.json")"
NOIMP_CALLS="$(jq -c '.[] | select(.rel_path=="src/noimport.ts") | .supabase_calls' "$WORK3/records.json")"

# D12 — no-import DI receiver yields ZERO calls (hasClient gate; the DI twin of A1).
eq "D12 no-import this.supabase.from() yields ZERO calls" \
   "$(echo "$NOIMP_CALLS" | jq 'length')" "0"
# D13 — mixed file: the VALUE-imported singleton call carries NO di key (singleton path byte-identical).
eq "D13 singleton invoke (mixed file) has NO di key" \
   "$(echo "$MIX_CALLS" | jq '[.[]|select(.literal=="singleton_fn")][0]|has("di")')" "false"
# D14 — same file: the DI invoke carries di:true (precedence line picks DI only when singleton fails).
eq "D14 DI invoke (mixed file) tagged di==true" \
   "$(echo "$MIX_CALLS" | jq '[.[]|select(.literal=="di_fn")][0].di')" "true"

xs3() {  # xs3 <substrate_ids-json> <coverage> -> combined.json over the DI-locks fixture records
  jq -n --slurpfile records "$WORK3/records.json" --arg now "$NOW" --arg src_commit "fix123" \
    --argjson alias_map '{"@":"src"}' --argjson substrate_ids "$1" --arg supabase_coverage "$2" \
    -f "$TRANSFORM_JQ"
}
MIXSUB='["repo:supabase/functions/singleton_fn","repo:supabase/functions/di_fn"]'
MIXOUT="$(xs3 "$MIXSUB" covered)"
# D15 — collision cap: the singleton invoke stays declared-high even with a same-named DI receiver present.
eq "D15 singleton invoke -> declared-high (mixed file)" \
   "$(echo "$MIXOUT" | jq -r '[.edges[]|select(.target=="repo:supabase/functions/singleton_fn")|.attributes.confidence][0]')" "declared-high"
# D16 — collision cap: the DI invoke caps to declared-medium DESPITE sharing the prop name with the singleton.
eq "D16 DI invoke -> declared-medium despite same prop name (mixed file)" \
   "$(echo "$MIXOUT" | jq -r '[.edges[]|select(.target=="repo:supabase/functions/di_fn")|.attributes.confidence][0]')" "declared-medium"
# D17 — dynamic DI invoke -> blind-spot (the dynamic guard holds on the invoke surface, not only from).
eq "D17 dynamic DI invoke -> blind-spot edge" \
   "$(echo "$MIXOUT" | jq '[.edges[]|select(.attributes.confidence=="blind-spot" and (.attributes.derivation|test("invoke")) and (.attributes.derivation|test("DI")))]|length')" "1"

# ===== summary ===============================================================
echo "-------------------------------------------"
echo "cross-system.sh: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
