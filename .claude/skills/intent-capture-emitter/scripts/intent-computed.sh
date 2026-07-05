#!/usr/bin/env bash
# intent-capture-emitter/scripts/intent-computed.sh — the COMPUTED LAYER generator (council A11 / G6 /
# Doctrine 04 §6.6). Emits the per-field change-commit map to a SEPARATE intent-computed.json.
#
# WHY THIS EXISTS: reconcile's conservation freshness precondition (Doctrine 06 §6.7) must know WHEN each
# intent FIELD it reads (wired_to, conditions) last changed, so a wording-only intent edit gates ONLY the
# invariants reading the changed field — NOT every invariant (the M4 deferral's binding "do NOT silently
# inherit record-level" demand). Field-level freshness lives here, NOT in the authored record.
#
# THE P2 BOUNDARY IS STRUCTURAL (Doctrine 04 P2 / §6.6): the per-field map is a DERIVED value. It is
# emitted to a SEPARATE FILE (intent-computed.json), emitter-stamped, keyed by intent record id — so it
# CANNOT be accidentally merged into the authored §6.1 record. The authored record stays authored-only.
#
# THE SOURCE OF GIT HISTORY IS THE CARRIER, NOT THE LEDGER: the intent ledger lives under the gitignored
# .understand-anything/ (it is a regenerable INDEX). The durable, committed source of truth for each
# record is its CARRIER file (DESTINATION.md / an ADR / a roadmap doc — git-tracked). Per-field freshness
# is therefore computed from the carrier git history: re-run extract+transform on each carrier commit and
# diff the derived field values. This mirrors topology freshness deriving from committed source, not from
# its own ephemeral substrate.
#
# SINGLE-PASS (A11): ONE git-show + extract + transform PER CARRIER COMMIT (never one subprocess per
# field). The per-field last-change is then computed in ONE jq pass over the cached per-commit records.
#
# COMMITTED-STATE-ONLY (A11): a dirty OR untracked carrier => that record freshness is
# `inconclusive: uncommitted-changes` (or carrier-untracked / carrier-missing) — NEVER a computed (false)
# freshness over an uncommitted edit. This is the anti-false-`in_sync` guard reconcile relies on.
#
# CONTRACT: writes ONLY intent-computed.json (atomic mktemp->mv). READS the ledger + carrier git history.
# NEVER writes the ledger. NEVER writes the §6.1 record. NEVER runs a topology emitter.
#
# Usage:  intent-computed.sh [--json]      (--json echoes the written map to stdout)
# Paths:  ledger  = $INTENT_SUBSTRATE_PATH   (default .understand-anything/intent-ledger.json)
#         output  = $INTENT_COMPUTED_PATH    (default <ledger-dir>/intent-computed.json)
#
# bash 3.2 + jq 1.7 + node portable. macOS-safe. No apostrophes inside inline single-quoted jq.
# Exit: 0 written · 4 uninitialised (no ledger) · 6 corrupt/jq-missing/node-missing · 2 usage.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
EXTRACT="$SCRIPT_DIR/extract.mjs"
TRANSFORM="$SCRIPT_DIR/transform.jq"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER_PATH="${INTENT_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/intent-ledger.json}"
LEDGER_DIR="$(dirname "$LEDGER_PATH")"
COMPUTED_PATH="${INTENT_COMPUTED_PATH:-$LEDGER_DIR/intent-computed.json}"
COMPUTED_DIR="$(dirname "$COMPUTED_PATH")"

# fields whose per-field freshness we track (the payload — NOT the provenance envelope, which changes every
# emit). reconcile reads wired_to + conditions; we track the full payload for completeness.
TRACK_FIELDS='["title","status","superseded_by","conditions","binary_test","falsifier","wired_to","owner","acceptance_cadence"]'

MODE="text"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) MODE="json"; shift ;;
    *) echo "intent-computed.sh: unknown argument '$1' (usage: intent-computed.sh [--json])" >&2; exit 2 ;;
  esac
done

command -v jq   >/dev/null 2>&1 || { echo "intent-computed.sh: jq not found" >&2; exit 6; }
command -v node >/dev/null 2>&1 || { echo "intent-computed.sh: node not found" >&2; exit 6; }
command -v git  >/dev/null 2>&1 || { echo "intent-computed.sh: git not found" >&2; exit 6; }
[ -f "$EXTRACT" ] && [ -f "$TRANSFORM" ] || { echo "intent-computed.sh: extract/transform helpers missing" >&2; exit 6; }

[ -f "$LEDGER_PATH" ] || { echo "intent-computed.sh: ledger not found at $LEDGER_PATH (run init + an emitter first)" >&2; exit 4; }
LEDGER_JSON="$(cat "$LEDGER_PATH" 2>/dev/null)"
printf '%s' "$LEDGER_JSON" | jq -e 'type == "object" and (.records | type == "array")' >/dev/null 2>&1 \
  || { echo "intent-computed.sh: ledger at $LEDGER_PATH is corrupt (not an object with a .records array)" >&2; exit 6; }

# the (id, source_file, kind) tuples we must compute freshness for, one per line: id<TAB>source_file<TAB>kind
REC_TUPLES="$(printf '%s' "$LEDGER_JSON" | jq -r '.records[] | [(.id // ""), (.source_file // ""), (.kind // "")] | @tsv')"

# accumulate per-record computed entries as a newline stream of {id, entry} compact objects.
emit_record_entry() {
  # $1=id  $2=carrier  $3=kind  -> prints one compact {"id":..,"entry":..} line
  local rid="$1" carrier="$2" kind="$3"
  if [ -z "$carrier" ] || [ ! -f "$carrier" ]; then
    jq -nc --arg id "$rid" --arg sf "$carrier" '{id:$id, entry:{source_file:$sf, freshness_status:"inconclusive: carrier-missing", fields:{}}}'
    return
  fi
  local cdir cbase relpath
  cdir="$(cd "$(dirname "$carrier")" 2>/dev/null && pwd)" || cdir=""
  cbase="$(basename "$carrier")"
  if [ -z "$cdir" ] || ! git -C "$cdir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    jq -nc --arg id "$rid" --arg sf "$carrier" '{id:$id, entry:{source_file:$sf, freshness_status:"inconclusive: carrier-not-in-git", fields:{}}}'
    return
  fi
  relpath="$(git -C "$cdir" ls-files --full-name -- "$cbase" 2>/dev/null)"
  if [ -z "$relpath" ]; then
    jq -nc --arg id "$rid" --arg sf "$carrier" '{id:$id, entry:{source_file:$sf, freshness_status:"inconclusive: carrier-untracked", fields:{}}}'
    return
  fi
  # committed-state-only: a dirty (modified/staged) carrier -> inconclusive, NEVER a computed freshness.
  if [ -n "$(git -C "$cdir" status --porcelain -- "$cbase" 2>/dev/null)" ]; then
    jq -nc --arg id "$rid" --arg sf "$carrier" '{id:$id, entry:{source_file:$sf, freshness_status:"inconclusive: uncommitted-changes", fields:{}}}'
    return
  fi
  # build the versions array (newest-first): one {commit,date,rec} per carrier commit. ONE git-show +
  # extract + transform per COMMIT (single-pass; never per-field).
  local versions
  versions="$(
    git -C "$cdir" log --format='%H %cI' -- "$cbase" 2>/dev/null | while read -r sha cdate _rest; do
      [ -n "$sha" ] || continue
      local tmpf raw rec
      tmpf="$(mktemp "${TMPDIR:-/tmp}/intent-computed.XXXXXX")" || continue
      if ! git -C "$cdir" show "$sha:$relpath" > "$tmpf" 2>/dev/null; then rm -f "$tmpf"; continue; fi
      raw="$(node "$EXTRACT" "$kind" "$tmpf" 2>/dev/null)" || { rm -f "$tmpf"; continue; }
      rm -f "$tmpf"
      rec="$(printf '%s' "$raw" | jq -c -f "$TRANSFORM" --arg source_commit "$sha" --arg timestamp "$cdate" 2>/dev/null | jq -c '.record' 2>/dev/null)"
      [ -n "$rec" ] && [ "$rec" != "null" ] || continue
      jq -nc --arg c "$sha" --arg d "$cdate" --argjson r "$rec" '{commit:$c, date:$d, rec:$r}'
    done | jq -sc '.'
  )"
  if [ -z "$versions" ] || [ "$versions" = "[]" ] || [ "$versions" = "null" ]; then
    jq -nc --arg id "$rid" --arg sf "$carrier" '{id:$id, entry:{source_file:$sf, freshness_status:"inconclusive: no-committed-history", fields:{}}}'
    return
  fi
  # per-field last-change in ONE jq pass: newest-first; the OLDEST contiguous-from-top commit still equal
  # to the current value is the commit where the field BECAME current (its last change). Constant field =>
  # first-appearance (oldest) commit.
  printf '%s' "$versions" | jq -c \
    --arg id "$rid" --arg sf "$carrier" --argjson fields "$TRACK_FIELDS" '
    . as $v
    | ($v | length) as $n
    | { id:$id,
        entry: {
          source_file: $sf,
          freshness_status: "committed",
          commits_scanned: $n,
          fields: ( reduce $fields[] as $f ({};
            . + { ($f):
              ( ($v[0].rec[$f]) as $cur
                | ( [ range(0;$n) | . as $i
                      | select( [ range(0;$i+1) | $v[.].rec[$f] ] | all(. == $cur) ) ] | last ) as $k
                | { last_changed_commit: $v[$k].commit, last_changed_date: $v[$k].date } )
            } ) )
        } }'
}

STREAM="$(
  printf '%s\n' "$REC_TUPLES" | while IFS="$(printf '\t')" read -r rid sf kind; do
    [ -n "$rid" ] || continue
    emit_record_entry "$rid" "$sf" "$kind"
  done
)"

# assemble intent-computed.json: keyed by record id, emitter-stamped (derived).
COMPUTED_JSON="$(printf '%s\n' "$STREAM" | jq -s '
  { schema_version: "1",
    emitter: "intent_computed_generator",
    provenance: "derived (emitter-stamped) — Doctrine 04 §6.6 computed layer; NOT authored; keyed by intent record id",
    freshness_basis: "committed-state-only",
    records: ( map({ (.id): .entry }) | add // {} ) }')"
if [ -z "$COMPUTED_JSON" ] || ! printf '%s' "$COMPUTED_JSON" | jq -e . >/dev/null 2>&1; then
  echo "intent-computed.sh: failed to assemble the computed map" >&2; exit 6
fi

# atomic write (mktemp -> mv); never partial-write the computed file.
mkdir -p "$COMPUTED_DIR" 2>/dev/null || true
TMP_OUT="$(mktemp "${COMPUTED_DIR}/.intent-computed.XXXXXX" 2>/dev/null || mktemp "${TMPDIR:-/tmp}/.intent-computed.XXXXXX")" \
  || { echo "intent-computed.sh: mktemp failed" >&2; exit 6; }
printf '%s\n' "$COMPUTED_JSON" > "$TMP_OUT" || { rm -f "$TMP_OUT"; echo "intent-computed.sh: write failed" >&2; exit 6; }
mv "$TMP_OUT" "$COMPUTED_PATH" || { rm -f "$TMP_OUT"; echo "intent-computed.sh: mv failed" >&2; exit 6; }

N_REC="$(printf '%s' "$COMPUTED_JSON" | jq -r '.records | length')"
N_INC="$(printf '%s' "$COMPUTED_JSON" | jq -r '[ .records[] | select(.freshness_status | startswith("inconclusive")) ] | length')"
if [ "$MODE" = "json" ]; then
  printf '%s\n' "$COMPUTED_JSON"
else
  echo "intent-computed.sh: wrote $COMPUTED_PATH — $N_REC record(s), $N_INC inconclusive (uncommitted/untracked carrier). Per-field change-commit map is SEPARATE from the authored ledger (P2)."
fi
