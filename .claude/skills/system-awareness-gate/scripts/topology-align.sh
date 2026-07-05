#!/usr/bin/env bash
# system-awareness-gate/scripts/topology-align.sh — the DEEP READ of the System-Awareness Alignment Gate.
#
# The plan-level alignment twin of the framing-audit gate. Where /topology reconcile catches the LIVE system
# drifting from the saved map, THIS surfaces whether a PLAN fits what the system actually IS, where it is
# headed, and what was committed — by composing the four anchors at plan-time and applying an honest-degradation
# matrix that NEVER launders absence / staleness / partiality / corruption / anomaly into a green light.
#
# Spec: specs/17_SYSTEM_AWARENESS_ALIGNMENT_GATE_PLAN.md  (council-amended v2, 2026-06-06).
# Rule: .claude/rules/system-awareness-mandate.md.  Invoked as `/topology align` (Claude auto-runs it; the
# operator never types it). READ-ONLY: composes the existing reads, never writes the substrate, never runs an
# emitter, never executes a drift action.
#
# COMPOSES (never rebuilds):
#   topology-health-check/scripts/health-check.sh --json   → .verdict + per-emitter .coverage + .node_total
#   topology-reconcile/scripts/reconcile.sh     --json   → .summary + .drift_count + .invariants[]  (ESTABLISHED only)
#   topology-substrate/scripts/substrate.sh     validate-schema  → corruption detail (CORRUPT path, via health-check)
#   .claude/skills/_shared/goals.sh list active   (surfaces the raw `list active` output; per-goal intended_end is not read)
#   ROADMAP.md NOW lane  +  DESTINATION.md Element 2
#
# THE ANTI-THEATRE CORE — R0–R7 governing-rule matrix (spec §3.3), first match wins, ONLY R7 licenses "aligned":
#   R1 health==UNINITIALISED            → NO_MAP        (FROM-SCRATCH; reconcile skipped)
#   R2 health==CORRUPT                  → MAP_CORRUPT   (rc-primary; reconcile skipped)
#   R3  health==ANOMALOUS & reconcile!=DRIFT → MAP_ANOMALOUS       (IN_SYNC SUPPRESSED — agreement not reliable)
#   R3b health==ANOMALOUS & reconcile==DRIFT  → MAP_ANOMALOUS_DRIFT (drift real but map unreliable; verify the affected emitter)
#   R4 reconcile degraded {UNINITIALISED,CORRUPT,no-invariants-registered,INCONCLUSIVE,UNVERIFIABLE,pending_verification,null}
#      (pending_verification is reserved — reconcile does not emit it yet; the clause is forward-compat)
#                                       → NO_CLAIM      (+ "double-degraded" when health is also STALE/PARTIAL)
#   R5 reconcile==DRIFT                 → DRIFT         (+ health staleness/partiality prefix)
#   R6 reconcile==PARTIAL, OR health∈{STALE,PARTIAL,STALE_AND_PARTIAL} & reconcile==IN_SYNC
#                                       → PARTIAL_IN_SYNC (with concrete coverage ratio — A4)
#   R7 health==FRESH & reconcile==IN_SYNC → ALIGNED     (the SOLE licensed state)
#   R0 anything else (unknown enum)     → UNEXPECTED    (never "aligned")
#
# DEPENDENCY-INJECTION SEAM (for evals — accept dependencies, don't create them):
#   TOPOLOGY_ALIGN_HEALTH_JSON     — if set, used as health-check --json output (skips the live call)
#   TOPOLOGY_ALIGN_RECONCILE_JSON  — if set, used as reconcile --json output (skips the live call)
#   TOPOLOGY_ALIGN_ROADMAP / TOPOLOGY_ALIGN_DESTINATION / TOPOLOGY_ALIGN_GOALS_JSON — optional text/JSON overrides
#
# Usage:  topology-align.sh            → plain-English operator/Claude surface
#         topology-align.sh --json     → machine-readable alignment verdict object
# Exit:   0 always in read mode (the verdict carries the signal — NO_MAP/DRIFT/… are honest REPORTS, not failures)
#         2 usage/bad-arg | 6 jq missing / internal failure
# Portability: macOS system bash 3.2 + jq 1.7. set -uo pipefail; all JSON/structure logic in jq; no assoc arrays.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HEALTH_SH="$SCRIPT_DIR/../../topology-health-check/scripts/health-check.sh"
RECONCILE_SH="$SCRIPT_DIR/../../topology-reconcile/scripts/reconcile.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "topology-align.sh: jq not found in PATH — required dependency (brew install jq)" >&2
  exit 6
fi

MODE="text"
case "${1:-}" in
  --json) MODE="json";;
  ''|--text) MODE="text";;
  -h|--help) grep -E '^#( |$)' "$0" | sed -E 's/^# ?//' | sed -n '1,40p'; exit 0;;
  *) echo "topology-align.sh: unknown arg '${1:-}' (use --json or no arg)" >&2; exit 2;;
esac

# tiered, format-tolerant ROADMAP-NOW extractor — entities format ROADMAP differently:
#   tier 1: a "## NOW" lane (explicit "## NOW"-lane style)  →  tier 2: NEXT-status item rows  →  tier 3: "## System:" headings.
roadmap_now() {  # $1=file  $2=indent
  local f="$1" ind="$2" out=""
  if [ ! -f "$f" ]; then printf '%sNo ROADMAP.md found — cannot check the plan against a roadmap.\n' "$ind"; return; fi
  out="$(sed -n '/^## NOW/,/^## [^#]/p' "$f" 2>/dev/null | grep -E '^(> \*\*|\| [^-])' | head -n 6)"
  [ -n "$out" ] || out="$(grep -E '^(\||>|### |- )' "$f" 2>/dev/null | grep -E '\bNEXT\b' | head -n 6)"
  [ -n "$out" ] || out="$(grep -E '^## System:' "$f" 2>/dev/null | head -n 6)"
  [ -n "$out" ] || out="(no NOW lane / NEXT items / System sections found in ROADMAP)"
  printf '%s\n' "$out" | sed -E "s/^/${ind}/"
}

# bound a command to N seconds — timeout/gtimeout (GNU) OR perl alarm (macOS ships perl, not coreutils).
_bounded() { local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'alarm shift; exec @ARGV' "$s" "$@"
  else "$@"; fi
}

# ── 1. health JSON (env seam → else live call) ────────────────────────────────
HEALTH_JSON="${TOPOLOGY_ALIGN_HEALTH_JSON:-}"
if [ -z "$HEALTH_JSON" ]; then
  if [ ! -f "$HEALTH_SH" ]; then
    echo "topology-align.sh: health-check helper not found at $HEALTH_SH" >&2; exit 6
  fi
  HEALTH_JSON="$(_bounded 8 bash "$HEALTH_SH" --json 2>/dev/null)"
fi
# Validate the health JSON parses + has a .verdict; else honest-degrade (NEVER a false-green).
HV="$(printf '%s' "$HEALTH_JSON" | jq -r '.verdict // empty' 2>/dev/null)"
if [ -z "$HV" ]; then
  HEALTH_JSON='{"verdict":"UNREADABLE","emitters":{},"node_total":0}'
  HV="UNREADABLE"
fi

# ── 2. reconcile JSON — ESTABLISHED modes only (skip for UNINITIALISED/CORRUPT/UNREADABLE) ──
RECON_JSON="null"
case "$HV" in
  UNINITIALISED|CORRUPT|UNREADABLE) RECON_JSON="null";;   # reconcile skipped — nothing coherent to compare
  *)
    if [ -n "${TOPOLOGY_ALIGN_RECONCILE_JSON:-}" ]; then
      RECON_JSON="$TOPOLOGY_ALIGN_RECONCILE_JSON"
    elif [ -f "$RECONCILE_SH" ]; then
      RECON_JSON="$(_bounded 30 bash "$RECONCILE_SH" --json 2>/dev/null)"
      [ -n "$RECON_JSON" ] || RECON_JSON="null"
    fi
    # guard: if the reconcile output does not parse, treat as null → R4 NO_CLAIM (never a false-green)
    printf '%s' "$RECON_JSON" | jq -e . >/dev/null 2>&1 || RECON_JSON="null"
    ;;
esac

# ── 3. THE MATRIX — one jq pass produces the discriminated alignment verdict ──
VERDICT_OBJ="$(jq -n \
  --argjson h "$HEALTH_JSON" \
  --argjson r "$RECON_JSON" '
  ($h.verdict // "UNREADABLE") as $hv |
  ($r // null) as $rec |
  ($rec.summary // null) as $rs |
  ($rec.drift_count // 0) as $dc |
  ($h.emitters // {}) as $em |
  ([ $em | to_entries[] | select(.value.coverage == "covered") | .key ]) as $covered |
  ([ $em | to_entries[] | select(.value.coverage != "covered") | .key ]) as $uncovered |
  ($covered | length) as $ncov |
  (($em | length)) as $mtot |
  ($h.node_total // 0) as $nodes |
  # degraded-reconcile set: any summary that means "no alignment claim is possible"
  def degraded($s):
    ($s == null) or ($s == "UNINITIALISED") or ($s == "CORRUPT")
    or ($s == "INCONCLUSIVE") or ($s == "UNVERIFIABLE")
    or ($s == "no-invariants-registered") or ($s == "pending_verification") ;
  (if ($hv == "STALE" or $hv == "PARTIAL" or $hv == "STALE_AND_PARTIAL") then true else false end) as $health_degraded |
  # ── the ordered rules (first match wins) ──
  ( if $hv == "UNINITIALISED" then
      {rule:"R1", av:"NO_MAP", aligned:false,
       headline:"NO system map exists yet (topology UNINITIALISED). This plan has NOT been checked against system structure — only against the written intent (ROADMAP / DESTINATION / goals) below. Run /topology to build the map.",
       offer_build:true}
    elif $hv == "CORRUPT" then
      {rule:"R2", av:"MAP_CORRUPT", aligned:false,
       headline:"System map is CORRUPT (validate-schema: \($h.integrity_detail // "see /topology validate")). Alignment CANNOT be checked — re-emit (/topology) to repair before relying on any structural claim.",
       offer_build:true}
    elif $hv == "UNREADABLE" then
      {rule:"R0", av:"UNEXPECTED", aligned:false,
       headline:"System map is UNREADABLE (health-check produced no parseable verdict). Cannot assess alignment. NOT aligned — investigate the topology substrate before relying on a structural claim.",
       offer_build:true}
    elif $hv == "ANOMALOUS" then
      ( if $rs == "DRIFT" then
          {rule:"R3", av:"MAP_ANOMALOUS_DRIFT", aligned:false,
           headline:"System map ANOMALY \($h.conditions // []) AND \($dc) drift(s) — the drift is real but sits on an anomalous map; verify the affected emitter before acting. Affected emitter UNRELIABLE; re-emit to repair.",
           offer_build:true}
        else
          {rule:"R3", av:"MAP_ANOMALOUS", aligned:false,
           headline:"System map ANOMALY (an emitter coverage-metadata is inconsistent — e.g. owned_but_uncovered / covered_but_empty / future_dated). Any reconcile result over it is NOT reliable (both sides may be compromised); treat as INCONCLUSIVE. Re-emit to repair.",
           offer_build:true} end )
    elif ($hv == "STALE" or $hv == "PARTIAL" or $hv == "STALE_AND_PARTIAL" or $hv == "FRESH") then
      ( if degraded($rs) then
          {rule:"R4", av:"NO_CLAIM", aligned:false,
           headline:( "NO alignment claim possible — reconcile " + ($rs // "produced no summary (drift has NEVER been assessed)") + "."
                      + (if $health_degraded then " DOUBLE-degraded: the map is also \($hv) — neither layer supports an alignment claim. Surface BOTH; do not let one mask the other." else "" end) ),
           offer_build:$health_degraded}
        elif $rs == "DRIFT" then
          {rule:"R5", av:"DRIFT", aligned:false,
           headline:( (if $health_degraded then "Map is also \($hv) — both apply. " else "" end)
                      + "\($dc) drift(s) detected between the saved map and the live system: act on the per-invariant named actions below before building on the affected nodes." ),
           offer_build:$health_degraded}
        elif $rs == "PARTIAL" then
          {rule:"R6", av:"PARTIAL_IN_SYNC", aligned:false,
           headline:"IN_SYNC within PARTIAL coverage only — reconcile reached \($ncov) of \($mtot) emitters (covered: \($covered)); the un-covered layers (\($uncovered)) were NOT checked. Treat as PARTIAL, not aligned.",
           offer_build:true}
        elif $rs == "IN_SYNC" then
          ( if $hv == "FRESH" then
              {rule:"R7", av:"ALIGNED", aligned:true,
               headline:"Map FRESH (\($ncov) of \($mtot) emitters covered: \($covered); \($nodes) nodes) and reconcile IN_SYNC across the registered invariants. This is the fully alignment-checkable state — the plan can be checked against current structure. (Name which invariant classes were checkable; the conservation class is deferred where no intent producer exists.)"}
            else
              {rule:"R6", av:"PARTIAL_IN_SYNC", aligned:false,
               headline:"Reconcile IN_SYNC but the map is \($hv) — checked \($ncov) of \($mtot) emitters (covered: \($covered)); the un-covered/stale layers (\($uncovered)) were NOT checked. IN_SYNC within that partial coverage only; treat as PARTIAL.",
               offer_build:true} end )
        else
          {rule:"R0", av:"UNEXPECTED", aligned:false,
           headline:"Map \($hv) but reconcile returned an unexpected summary (\($rs // "null")) — cannot assess alignment. NOT aligned.",
           offer_build:false} end )
    else
      {rule:"R0", av:"UNEXPECTED", aligned:false,
       headline:"Unexpected map state (health verdict: \($hv)) — cannot assess alignment. NOT aligned. Investigate the topology substrate.",
       offer_build:false} end )
  | . + {
      health_verdict:$hv,
      reconcile_summary:($rs // null),
      drift_count:$dc,
      covered_emitters:$covered,
      uncovered_emitters:$uncovered,
      coverage_ratio:{covered:$ncov, total:$mtot},
      node_total:$nodes,
      offer_build:(.offer_build // false)
    }
' 2>/dev/null)"

if [ -z "$VERDICT_OBJ" ]; then
  echo "topology-align.sh: failed to compute alignment verdict (jq produced no output)" >&2
  exit 6
fi

# Self-check invariant: aligned==true ONLY for rule R7 (defence-in-depth against a future edit
# accidentally licensing "aligned" elsewhere — the single most dangerous regression for this gate).
BAD="$(printf '%s' "$VERDICT_OBJ" | jq -r 'if ((.aligned == true and .rule != "R7") or (.rule == "R7" and .aligned != true)) then "BREACH" else "" end' 2>/dev/null)"
if [ "$BAD" = "BREACH" ]; then
  echo "topology-align.sh: INTERNAL INVARIANT BREACH — aligned=true on a non-R7 rule. Refusing to emit a false-green." >&2
  exit 6
fi

# ── JSON mode ─────────────────────────────────────────────────────────────────
if [ "$MODE" = "json" ]; then
  printf '%s\n' "$VERDICT_OBJ" | jq '{rule, alignment_verdict:.av, licensed_aligned:.aligned, headline,
    health_verdict, reconcile_summary, drift_count, covered_emitters, uncovered_emitters, coverage_ratio,
    node_total, offer_build}'
  exit 0
fi

# ── TEXT mode — the operator/Claude surface ───────────────────────────────────
printf '%s' "$VERDICT_OBJ" | jq -r '.headline'
echo ""

# Map health relay (the verbatim health-check verdict line + per-emitter coverage)
echo "── System map (topology health) ──"
printf '%s' "$HEALTH_JSON" | jq -r '
  "verdict: \(.verdict)   |   nodes: \(.node_total // 0)   |   last updated: \(.last_updated // "(never)")",
  ( (.emitters // {}) | to_entries[] | "  - \(.key): \(.value.coverage)\( if .value.stale == true then ", STALE" else "" end)" )' 2>/dev/null

# Open drift (ESTABLISHED only — when reconcile ran)
if [ "$RECON_JSON" != "null" ]; then
  echo ""
  echo "── Open drift (topology reconcile) ──"
  printf '%s' "$RECON_JSON" | jq -r '
    "summary: \(.summary)   |   drift_count: \(.drift_count // 0)",
    ( (.invariants // []) | .[] | select(.verdict == "drift")
      | "  - [\(.id // "?")] \(.verdict) → \(.named_action // "no action") (affected: \((.affected_nodes // []) | join(", ")))" )' 2>/dev/null
fi

# ROADMAP NOW lane (bounded read; env override for tests/propagation)
echo ""
echo "── Where we are headed (ROADMAP NOW) ──"
ROADMAP_FILE="${TOPOLOGY_ALIGN_ROADMAP:-$REPO_ROOT/ROADMAP.md}"
roadmap_now "$ROADMAP_FILE" "  "

# DESTINATION (Element 2 — the binary success test; may not exist)
echo ""
echo "── What was committed (DESTINATION) ──"
DEST_FILE="${TOPOLOGY_ALIGN_DESTINATION:-$REPO_ROOT/DESTINATION.md}"
if [ -f "$DEST_FILE" ]; then
  sed -n '/[Bb]inary success test/,/^## /p' "$DEST_FILE" 2>/dev/null | head -n 20 | sed -E 's/^/  /'
else
  echo "  No DESTINATION.md — plan cannot be checked against a committed destination; consider /define-destination."
fi

# Open goals + intended ends (honest empty handling)
echo ""
echo "── Open goals ──"
GOALS_SH="$REPO_ROOT/.claude/skills/_shared/goals.sh"
GOALS_RAW="${TOPOLOGY_ALIGN_GOALS_JSON:-}"
if [ -z "$GOALS_RAW" ] && [ -f "$GOALS_SH" ]; then
  GOALS_RAW="$(_bounded 5 bash "$GOALS_SH" list active 2>/dev/null)"
  GRC=$?
  if [ "$GRC" -ne 0 ]; then
    echo "  (goal ledger unavailable — exit $GRC; treat as no goals confirmed)"
    GOALS_RAW="__SKIP__"
  fi
fi
if [ "$GOALS_RAW" = "__SKIP__" ]; then
  :
elif [ -z "$(printf '%s' "$GOALS_RAW" | tr -d '[:space:]')" ] || [ "$GOALS_RAW" = "[]" ]; then
  echo "  No active goals registered."
else
  printf '%s\n' "$GOALS_RAW" | head -n 10 | sed -E 's/^/  /'
fi

# Build-the-map offer — FROM-SCRATCH OR incomplete coverage (PARTIAL/STALE_AND_PARTIAL/ANOMALOUS) — council S3
if [ "$(printf '%s' "$VERDICT_OBJ" | jq -r '.offer_build')" = "true" ]; then
  echo ""
  echo "── Next move ──"
  echo "  The system map is absent or incomplete. Run the topology emitters (/topology) to build/complete it,"
  echo "  then re-run /topology align for a structure-aware alignment read. (Inside /setup this is an inline offer.)"
fi

echo ""
echo "(advisory only — this gate never blocks; only FRESH map + IN_SYNC reconcile licenses \"aligned\")"
exit 0
