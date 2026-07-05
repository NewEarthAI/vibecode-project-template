#!/usr/bin/env bash
# intent-capture-emitter/scripts/nsf3-wired-integrity.sh — NSF-3 (council A12), the wired_to
# referential-integrity sieve + emitter-id-format-change batch heuristic.
#
# WHY THIS EXISTS (plan specs/18 line 138 / Doctrine 04 §6.3 + §9.5): runs after any topology emitter
# re-run; flags intent records whose authored `wired_to` no longer resolves to a live topology node, and
# distinguishes a SYSTEMIC cause (an emitter id-format change → ≥N same-(emitter,kind) failures in one
# run) from individual `wired_to_target_absent` failures. Feeds Gate 1 rename-detection: an absent target
# is the signal the operator investigates and resolves via supersession (M6 NEVER auto-repoints — P1).
#
# SCOPE BOUNDARY (deliberate, documented). NSF-3 is the cheap sieve; it is NOT reconcile. The authoritative
# per-target, PER-EMITTER-PER-KIND coverage routing with ranked named actions (revert/reconcile/approve/
# escalate) lives in the conservation invariant in topology-reconcile (plan A3, specs/18 line 92). NSF-3
# shares the Gate-2 coverage LESSON, not reconcile code: it labels an unresolved target by WHOLE-MAP
# coverage — on a FULL map an unresolved target is a confident `wired_to_target_absent`; on a PARTIAL map
# it is the honest `wired_to_target_unverifiable` (its owning emitter may simply not have run — the
# theatre-of-trust false-drift NSF-3 must NOT commit). The batch heuristic still fires on the unresolved
# set regardless of FULL/PARTIAL, because a systemic same-(emitter,kind) cluster is suspicious either way.
#
# CONTRACT: READ-ONLY. Reads the intent ledger + the topology substrate via jq. NEVER writes either.
# NEVER mutates a record (Doctrine 04 P2 — the "% resolved" derived value belongs in the computed layer,
# not the authored record). Emits a verdict + a machine-readable --json line.
#
# CHECKED records: status in {accepted, fulfilled} (both assert a live wiring claim — §9.5 orphan, §8.5
# fulfilled-unresolved). `draft` (work-in-progress wiring) and `superseded` (terminal) are skipped.
# `wired_to == "pending"` is the legitimate aspirational marker (§6.3) — never a violation.
#
# Batch threshold: 5 (council A12). Override via INTENT_BATCH_THRESHOLD.
#
# bash 3.2 + jq 1.7 portable. No apostrophes inside inline single-quoted jq.
#
# Exit codes: 0 ok/unverifiable/topology-unavailable · 1 broken_pointers (BINDING) · 4 uninitialised ·
#             6 corrupt/jq-missing · 2 usage.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER_PATH="${INTENT_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/intent-ledger.json}"
TOPO_PATH="${TOPOLOGY_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/topology-graph.json}"

MODE="text"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) MODE="json"; shift ;;
    *) echo "nsf3-wired-integrity.sh: unknown argument '$1' (usage: nsf3-wired-integrity.sh [--json])" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "nsf3-wired-integrity.sh: jq not found" >&2; exit 6; }

BATCH_THRESHOLD="${INTENT_BATCH_THRESHOLD:-5}"
BATCH_THRESHOLD="$(printf '%s' "$BATCH_THRESHOLD" | tr -dc '0-9' | head -c 4)"; BATCH_THRESHOLD="${BATCH_THRESHOLD:-5}"

# ---- STEP 1 — read the intent ledger (missing → uninitialised; non-JSON / wrong shape → corrupt) --------
if [ ! -f "$LEDGER_PATH" ]; then
  if [ "$MODE" = "json" ]; then
    printf '{"verdict":"uninitialised","detail":"intent ledger not found at %s — run init + an emitter first"}\n' "$LEDGER_PATH"
  else
    echo "WIRED INTEGRITY: uninitialised — no intent ledger at $LEDGER_PATH. Run init + an emitter first."
  fi
  exit 4
fi
LEDGER_JSON="$(cat "$LEDGER_PATH" 2>/dev/null)"
if [ -z "$LEDGER_JSON" ] || ! printf '%s' "$LEDGER_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
  if [ "$MODE" = "json" ]; then printf '{"verdict":"corrupt","detail":"ledger empty or not a JSON object"}\n'
  else echo "WIRED INTEGRITY: corrupt — the ledger at $LEDGER_PATH is empty or not a JSON object."; fi
  exit 6
fi
RECORDS_TYPE="$(printf '%s' "$LEDGER_JSON" | jq -r '(.records // null) | type' 2>/dev/null)"
if [ "$RECORDS_TYPE" != "array" ] && [ "$RECORDS_TYPE" != "null" ]; then
  if [ "$MODE" = "json" ]; then printf '{"verdict":"corrupt","detail":"ledger .records is type %s, expected array"}\n' "$RECORDS_TYPE"
  else echo "WIRED INTEGRITY: corrupt — the ledger .records is a $RECORDS_TYPE, not an array."; fi
  exit 6
fi

# ---- STEP 2 — read the topology id-space + coverage (absent → referential checks become unverifiable) ---
# topology id-set = [.nodes[].id]; coverage from .emitters. FULL iff .emitters is non-empty AND no emitter
# is absent/declared-missing (covered + degenerate are fine). Absent/empty emitters info → PARTIAL (cannot
# confirm completeness → never confidently call a target broken).
TOPO_IDS="[]"; TOPO_COVERAGE="absent"
if [ -f "$TOPO_PATH" ]; then
  TOPO_JSON="$(cat "$TOPO_PATH" 2>/dev/null)"
  if [ -n "$TOPO_JSON" ] && printf '%s' "$TOPO_JSON" | jq -e 'type == "object"' >/dev/null 2>&1; then
    TOPO_IDS="$(printf '%s' "$TOPO_JSON" | jq -c '[ (.nodes // [])[] | .id ] | map(select(. != null))' 2>/dev/null || echo '[]')"
    TOPO_COVERAGE="$(printf '%s' "$TOPO_JSON" | jq -r '
      (.emitters // {}) as $em
      | if ($em | length) == 0 then "partial"
        elif ([ $em | to_entries[] | select(.value.coverage == "absent" or .value.coverage == "declared-missing") ] | length) > 0
          then "partial" else "full" end' 2>/dev/null || echo "partial")"
  fi
fi

# ---- STEP 3 — judge wired_to integrity in ONE jq pass ---------------------------------------------------
GATE_JSON="$(printf '%s' "$LEDGER_JSON" | jq -c \
  --argjson topo_ids "$TOPO_IDS" \
  --arg coverage "$TOPO_COVERAGE" \
  --argjson threshold "$BATCH_THRESHOLD" '
  ( $topo_ids | map({key:., value:true}) | from_entries ) as $idset
  | ( .records // [] ) as $recs
  | [ $recs[] | select(.status == "accepted" or .status == "fulfilled") ] as $checked
  # classify each checked record wired_to: pending | resolved | unresolved | orphan | malformed
  | [ $checked[]
      | { id, emitter: (.emitter // "unknown"), kind: (.kind // "unknown"),
          status, wt: .wired_to } as $r
      | (
          if ($r.wt == "pending") then { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"pending" }
          elif ($r.wt == null) then { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"orphan" }
          elif ($r.wt | type) == "array" then
            ( if ($r.wt | length) == 0 then { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"malformed", note:"empty wired_to array" }
              elif ([ $r.wt[] | select((type != "string") or (. == "")) ] | length) > 0
                then { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"malformed", note:"non-string or empty wired_to entry" }
              else
                ( [ $r.wt[] | select($idset[.] | not) ] ) as $unres
                | if ($unres | length) == 0 then { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"resolved" }
                  else { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"unresolved", unresolved_targets:$unres } end
              end )
          # a bare string that is not "pending" is a single target id -> resolve it
          elif ($r.wt | type) == "string" then
            ( if ($idset[$r.wt] | not) then { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"unresolved", unresolved_targets:[$r.wt] }
              else { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"resolved" } end )
          else { id:$r.id, emitter:$r.emitter, kind:$r.kind, cls:"malformed", note:"wired_to is neither string nor array" }
          end
        ) ] as $rows
  | [ $rows[] | select(.cls == "orphan" or .cls == "malformed") ] as $shape_bad
  | [ $rows[] | select(.cls == "unresolved") ] as $unresolved
  | [ $rows[] | select(.cls == "pending") ] as $pending
  | [ $rows[] | select(.cls == "resolved") ] as $resolved
  # batch heuristic: group the unresolved set by (emitter,kind); any group >= threshold = systemic.
  | ( $unresolved | group_by([.emitter, .kind])
      | map(select(length >= $threshold) | { emitter: .[0].emitter, kind: .[0].kind, count: length }) ) as $batch
  | {
      checked_count: ($checked | length),
      topology_coverage: $coverage,
      pending_count: ($pending | length),
      resolved_count: ($resolved | length),
      shape_violations: $shape_bad,
      unresolved: $unresolved,
      batch_flags: $batch,
      verdict:
        ( if ($shape_bad | length) > 0 then "broken_pointers"
          elif ($unresolved | length) == 0 then "referential_integrity_ok"
          elif $coverage == "absent" then "topology_unavailable"
          elif $coverage == "full" then "broken_pointers"
          else "referential_integrity_unverifiable" end ),
      # per-record reason label depends on coverage (honest): confident vs unverifiable.
      unresolved_label:
        ( if $coverage == "full" then "wired_to_target_absent" else "wired_to_target_unverifiable" end )
    }')"
if [ -z "$GATE_JSON" ]; then
  echo "nsf3-wired-integrity.sh: judgement jq produced no output — the ledger or topology has an unexpected shape" >&2
  exit 6
fi

VERDICT="$(printf '%s' "$GATE_JSON" | jq -r '.verdict')"
CHECKED="$(printf '%s' "$GATE_JSON" | jq -r '.checked_count')"
COVERAGE="$(printf '%s' "$GATE_JSON" | jq -r '.topology_coverage')"
N_SHAPE="$(printf '%s' "$GATE_JSON" | jq -r '.shape_violations | length')"
N_UNRES="$(printf '%s' "$GATE_JSON" | jq -r '.unresolved | length')"
N_BATCH="$(printf '%s' "$GATE_JSON" | jq -r '.batch_flags | length')"
SHAPE_STR="$(printf '%s' "$GATE_JSON" | jq -r '.shape_violations | map("\(.id):\(.cls)") | join("; ")')"
UNRES_STR="$(printf '%s' "$GATE_JSON" | jq -r '.unresolved | map("\(.id)→[\(.unresolved_targets | join(","))]") | join("; ")')"
BATCH_STR="$(printf '%s' "$GATE_JSON" | jq -r '.batch_flags | map("\(.emitter)/\(.kind):\(.count)") | join("; ")')"

# ---- STEP 4 — emit the verdict --------------------------------------------------------------------------
TS_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ "$MODE" = "json" ]; then
  JSON_OUT="$(printf '%s\n' "$GATE_JSON" | jq -c --arg now "$TS_NOW" --argjson threshold "$BATCH_THRESHOLD" \
    '. + {observed_at:$now, batch_threshold:$threshold}')" || { echo "nsf3-wired-integrity.sh: --json merge jq failed" >&2; exit 6; }
  [ -n "$JSON_OUT" ] || { echo "nsf3-wired-integrity.sh: --json merge produced empty output" >&2; exit 6; }
  printf '%s\n' "$JSON_OUT"
else
  BATCH_SUFFIX=""; [ "$N_BATCH" -gt 0 ] && BATCH_SUFFIX=" possible_emitter_id_format_change: $BATCH_STR (>= $BATCH_THRESHOLD same-(emitter,kind) failures — systemic, not individual drift)."
  case "$VERDICT" in
    referential_integrity_ok)
      echo "WIRED INTEGRITY: referential_integrity_ok — all $CHECKED checked record(s) have wired_to either pending or fully resolved against the topology map (coverage: $COVERAGE)." ;;
    broken_pointers)
      if [ "$N_SHAPE" -gt 0 ] && [ "$N_UNRES" -gt 0 ] && [ "$COVERAGE" = "full" ]; then
        echo "WIRED INTEGRITY: broken_pointers — $N_SHAPE shape violation(s) [$SHAPE_STR] AND $N_UNRES record(s) with absent wired_to targets [$UNRES_STR] on a FULL map (label: wired_to_target_absent → Gate-1 supersession, never auto-repoint).$BATCH_SUFFIX"
      elif [ "$N_SHAPE" -gt 0 ]; then
        echo "WIRED INTEGRITY: broken_pointers — $N_SHAPE shape violation(s): [$SHAPE_STR] (orphan = accepted/fulfilled with no wired_to and no pending marker, D04 §9.5; malformed = empty array / non-string entries)."
      else
        echo "WIRED INTEGRITY: broken_pointers — $N_UNRES record(s) with absent wired_to targets on a FULL map [$UNRES_STR] (label: wired_to_target_absent → Gate-1 supersession, never auto-repoint).$BATCH_SUFFIX"
      fi ;;
    referential_integrity_unverifiable)
      echo "WIRED INTEGRITY: referential_integrity_unverifiable — $N_UNRES record(s) have wired_to targets absent from a PARTIAL topology map [$UNRES_STR]; their owning emitter may simply not have run, so NSF-3 will not call them broken (label: wired_to_target_unverifiable). Reconcile conservation (emitter-level) is the authoritative adjudicator.$BATCH_SUFFIX" ;;
    topology_unavailable)
      echo "WIRED INTEGRITY: topology_unavailable — shape checks passed but no topology map at $TOPO_PATH, so wired_to referential integrity cannot be verified (not laundered to 'ok'). Run a topology emitter, then re-run NSF-3." ;;
    *) echo "WIRED INTEGRITY: $VERDICT" ;;
  esac
fi

case "$VERDICT" in
  referential_integrity_ok|referential_integrity_unverifiable|topology_unavailable) exit 0 ;;
  broken_pointers) exit 1 ;;
  *) exit 6 ;;
esac
