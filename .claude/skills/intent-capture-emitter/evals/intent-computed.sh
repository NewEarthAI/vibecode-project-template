#!/usr/bin/env bash
# evals/intent-computed.sh — the computed-layer (per-field change-commit map) eval.
#
# Builds an ISOLATED temp git repo (NOT the workshop repo; no push) with a destination carrier committed
# twice — v2 changes only the Element-2 (binary_test) section. Asserts:
#  - intent-computed.json is a SEPARATE file, keyed by record id, emitter-stamped (derived).
#  - genuine per-field attribution: the CHANGED field (binary_test) -> v2 commit; an UNCHANGED field
#    (title/conditions/status) -> v1 commit (NOT record-level inheritance — the A11 demand).
#  - committed-state-only: a dirty carrier -> freshness_status "inconclusive: uncommitted-changes".
#  - P2 structural boundary: the per-field map is ABSENT from the ledger (§6.1) record.
#
# Portable: bash 3.2, fresh mktemp scratch, git in an isolated temp repo (safe).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GEN="$SCRIPT_DIR/../scripts/intent-computed.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

REPO="$(mktemp -d /tmp/intent-computed-eval.XXXXXX)"
CARRIER="$REPO/DESTINATION.md"
git -C "$REPO" init -q
git -C "$REPO" config user.email "eval@workshop.local"
git -C "$REPO" config user.name  "eval"

# v1
cat > "$CARRIER" <<'EOF'
---
status: confirmed
owner: workshop
---

# My Destination

## Element 1 — End state
conditions text version one

## Element 2 — Binary success
binary test text VERSION ONE
EOF
git -C "$REPO" add DESTINATION.md
git -C "$REPO" commit -q -m "v1"
SHA1="$(git -C "$REPO" rev-parse HEAD)"

# v2 — change ONLY Element 2 (binary_test). title/conditions/status unchanged.
cat > "$CARRIER" <<'EOF'
---
status: confirmed
owner: workshop
---

# My Destination

## Element 1 — End state
conditions text version one

## Element 2 — Binary success
binary test text VERSION TWO CHANGED
EOF
git -C "$REPO" add DESTINATION.md
git -C "$REPO" commit -q -m "v2"
SHA2="$(git -C "$REPO" rev-parse HEAD)"

# scratch ledger with one record pointing at the temp carrier
SCRATCH="$(mktemp -d /tmp/intent-computed-led.XXXXXX)"
LEDGER="$SCRATCH/intent-ledger.json"
COMPUTED="$SCRATCH/intent-computed.json"
RID="intent:destination:destination-md"
jq -nc --arg id "$RID" --arg sf "$CARRIER" \
  '{schema_version:"1",entity:"test",records:[{id:$id,kind:"destination",source_file:$sf,status:"accepted",wired_to:"pending",falsifier:null}],emitters:{}}' > "$LEDGER"

export INTENT_SUBSTRATE_PATH="$LEDGER"
export INTENT_COMPUTED_PATH="$COMPUTED"

OUT="$(bash "$GEN" --json 2>/dev/null)"; rc=$?
[ "$rc" = "0" ] && ok || bad "generator exit 0 (got $rc)"
[ -f "$COMPUTED" ] && ok || bad "intent-computed.json written as a separate file"
# separate file: it is NOT the ledger
[ "$COMPUTED" != "$LEDGER" ] && ok || bad "computed path differs from ledger path"
# keyed by record id
keyed="$(printf '%s' "$OUT" | jq -r --arg id "$RID" '.records | has($id)')"
[ "$keyed" = "true" ] && ok || bad "computed map keyed by record id"
# emitter-stamped / derived provenance
prov="$(printf '%s' "$OUT" | jq -r '.emitter')"
[ "$prov" = "intent_computed_generator" ] && ok || bad "emitter-stamped (derived) — got '$prov'"
# freshness committed
fs="$(printf '%s' "$OUT" | jq -r --arg id "$RID" '.records[$id].freshness_status')"
[ "$fs" = "committed" ] && ok || bad "freshness_status committed — got '$fs'"
# per-field attribution: binary_test changed at v2
bt="$(printf '%s' "$OUT" | jq -r --arg id "$RID" '.records[$id].fields.binary_test.last_changed_commit')"
[ "$bt" = "$SHA2" ] && ok || bad "binary_test last_changed == v2 ($SHA2) — got $bt"
# per-field attribution: title UNCHANGED -> v1 (NOT record-level inheritance to v2)
ti="$(printf '%s' "$OUT" | jq -r --arg id "$RID" '.records[$id].fields.title.last_changed_commit')"
[ "$ti" = "$SHA1" ] && ok || bad "title last_changed == v1 ($SHA1) — got $ti (record-level inheritance bug if == v2)"
# conditions UNCHANGED -> v1
co="$(printf '%s' "$OUT" | jq -r --arg id "$RID" '.records[$id].fields.conditions.last_changed_commit')"
[ "$co" = "$SHA1" ] && ok || bad "conditions last_changed == v1 ($SHA1) — got $co"
# status UNCHANGED -> v1
st="$(printf '%s' "$OUT" | jq -r --arg id "$RID" '.records[$id].fields.status.last_changed_commit')"
[ "$st" = "$SHA1" ] && ok || bad "status last_changed == v1 ($SHA1) — got $st"
# P2: the per-field map is ABSENT from the ledger record
ledger_has="$(jq -r '.records[0] | (has("fields") or has("last_changed_commit"))' "$LEDGER")"
[ "$ledger_has" = "false" ] && ok || bad "per-field map absent from the §6.1 ledger record (P2)"

# committed-state-only: dirty carrier -> inconclusive
printf '\n<!-- uncommitted edit -->\n' >> "$CARRIER"
OUT2="$(bash "$GEN" --json 2>/dev/null)"
fs2="$(printf '%s' "$OUT2" | jq -r --arg id "$RID" '.records[$id].freshness_status')"
case "$fs2" in inconclusive:*) ok ;; *) bad "dirty carrier -> inconclusive — got '$fs2'" ;; esac
# and its fields map is empty under inconclusive (no false computed freshness)
nf="$(printf '%s' "$OUT2" | jq -r --arg id "$RID" '.records[$id].fields | length')"
[ "$nf" = "0" ] && ok || bad "inconclusive record carries no computed fields — got $nf"

# untracked carrier -> inconclusive (a record whose carrier is not in git)
jq -nc --arg sf "/tmp/nonexistent-carrier-$$.md" \
  '{schema_version:"1",records:[{id:"intent:destination:ghost",kind:"destination",source_file:$sf,status:"accepted"}],emitters:{}}' > "$LEDGER"
OUT3="$(bash "$GEN" --json 2>/dev/null)"
fs3="$(printf '%s' "$OUT3" | jq -r '.records["intent:destination:ghost"].freshness_status')"
case "$fs3" in inconclusive:*) ok ;; *) bad "missing carrier -> inconclusive — got '$fs3'" ;; esac

echo "== INTENT-COMPUTED RESULT: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
