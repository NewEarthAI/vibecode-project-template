#!/usr/bin/env bash
# evals/parsers.sh — exercise ALL three carrier parsers (destination + adr + roadmap_item) through
# extract -> transform -> store bulk-write -> validate. The destination path was proven end-to-end on the
# real DESTINATION.md in S2b; this eval adds the ADR + roadmap_item fixtures (built but previously
# unexercised) AND re-verifies DESTINATION through the edited transform (the kind->emitter map fix).
#
# Portable: bash 3.2, fresh mktemp scratch.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SK="$SCRIPT_DIR/../scripts"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"   # workshop repo root
FIX="$SCRIPT_DIR/fixtures"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

SCRATCH="$(mktemp -d /tmp/parsers-eval.XXXXXX)"
export INTENT_SUBSTRATE_PATH="$SCRATCH/intent-ledger.json"
bash "$SK/intent-store.sh" init test >/dev/null 2>&1

# derive a record from a carrier (extract+transform) and echo the compact .record
derive() { # $1 kind  $2 carrier
  node "$SK/extract.mjs" "$1" "$2" 2>/dev/null \
    | jq -f "$SK/transform.jq" --arg source_commit "evaltest" --arg timestamp "2026-01-01T00:00:00Z" 2>/dev/null \
    | jq -c '.record' 2>/dev/null
}
field() { printf '%s' "$1" | jq -r "$2" 2>/dev/null; }

# --- destination — the repo's real DESTINATION.md when present (workshop real-carrier regression),
#     else a self-contained fixture so the eval is PORTABLE to any repo without a DESTINATION.md yet
#     (a fresh template clone or a freshly-set-up receiving entity). Both paths produce the same record. ---
DEST_CARRIER="$ROOT/DESTINATION.md"; [ -f "$DEST_CARRIER" ] || DEST_CARRIER="$FIX/sample-destination.md"
DREC="$(derive destination "$DEST_CARRIER")"
[ -n "$DREC" ] && [ "$DREC" != "null" ] && ok || bad "destination: derived a record"
[ "$(field "$DREC" '.kind')" = "destination" ] && ok || bad "destination: kind"
[ "$(field "$DREC" '.emitter')" = "destination_parser" ] && ok || bad "destination: emitter=destination_parser"
[ "$(field "$DREC" '.status')" = "accepted" ] && ok || bad "destination: status confirmed->accepted (got $(field "$DREC" '.status'))"
[ "$(field "$DREC" '.binary_test != null')" = "true" ] && ok || bad "destination: binary_test present"
[ "$(field "$DREC" '.wired_to')" = "pending" ] && ok || bad "destination: wired_to pending (never guessed)"

# --- adr fixture ---
AREC="$(derive adr "$FIX/sample-adr.md")"
[ -n "$AREC" ] && [ "$AREC" != "null" ] && ok || bad "adr: derived a record"
[ "$(field "$AREC" '.kind')" = "adr" ] && ok || bad "adr: kind"
[ "$(field "$AREC" '.emitter')" = "adr_parser" ] && ok || bad "adr: emitter=adr_parser (got $(field "$AREC" '.emitter'))"
[ "$(field "$AREC" '.status')" = "accepted" ] && ok || bad "adr: status accepted (got $(field "$AREC" '.status'))"
[ "$(field "$AREC" '.conditions != null')" = "true" ] && ok || bad "adr: conditions (Decision section) present"
[ "$(field "$AREC" '.binary_test != null')" = "true" ] && ok || bad "adr: binary_test (Consequences) present"
case "$(field "$AREC" '.id')" in intent:adr:*) ok ;; *) bad "adr: id format (got $(field "$AREC" '.id'))" ;; esac

# --- roadmap_item fixture — the emitter-map regression (roadmap_item -> roadmap_parser, NOT roadmap_item_parser) ---
RREC="$(derive roadmap_item "$FIX/sample-roadmap.md")"
[ -n "$RREC" ] && [ "$RREC" != "null" ] && ok || bad "roadmap: derived a record"
[ "$(field "$RREC" '.kind')" = "roadmap_item" ] && ok || bad "roadmap: kind"
[ "$(field "$RREC" '.emitter')" = "roadmap_parser" ] && ok || bad "roadmap: emitter=roadmap_parser NOT roadmap_item_parser (got $(field "$RREC" '.emitter'))"
[ "$(field "$RREC" '.status')" = "draft" ] && ok || bad "roadmap: status draft (got $(field "$RREC" '.status'))"
[ "$(field "$RREC" '.binary_test != null')" = "true" ] && ok || bad "roadmap: binary_test (Done when) present"
case "$(field "$RREC" '.id')" in intent:roadmap_item:*) ok ;; *) bad "roadmap: id format (got $(field "$RREC" '.id'))" ;; esac

# --- all three index cleanly into the store + the ledger validates (the emitter-map fix lets roadmap pass) ---
bash "$SK/intent-store.sh" bulk-write "[$DREC,$AREC,$RREC]" >/dev/null 2>&1 && ok || bad "bulk-write all three records"
vr="$(bash "$SK/intent-store.sh" validate-schema 2>&1)"
[ "$vr" = "PASS" ] && ok || bad "ledger validates after indexing all three kinds (got: $vr)"
n="$(bash "$SK/intent-store.sh" read-intent 2>/dev/null | jq -r '.records | length')"
[ "$n" = "3" ] && ok || bad "three records present in the ledger (got $n)"

echo "== PARSERS RESULT: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
