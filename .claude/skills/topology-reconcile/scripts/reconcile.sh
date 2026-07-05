#!/usr/bin/env bash
# topology-reconcile — the reconciliation comparator (M4, Doctrine 06).
#
# Reads the FROZEN topology substrate (read-only), loads registered invariants, and for each computes a
# verdict ∈ {in_sync, drift, inconclusive, unverifiable_spot, unverifiable_dimension,
# no-invariants-registered, pending_verification} with a named action on every drift — re-derived from the
# substrate's two source provenances, NEVER from a wired-in fixture. NEVER writes the substrate; NEVER runs
# an emitter inside compute() (the P2 boundary — Doctrine 06 §3.2/§6.3, Test D operational limb).
#
# Council-hardened (council/sessions/2026-06-02-m4-reconciliation-proof-plan.md):
#   C1 provenance-aware freshness (live:/+dirty → incomparable-provenance, never drift/in_sync).
#   C2 join key = attributes.n8n_id.
#   C3 unverifiable_dimension via jq -e on the coverage ENUM (never echo|grep -q → SIGPIPE; never node-count).
#   C4 decision-list = ONE jq expression returning a {verdict, named_action} discriminated union.
#   S1 NO persistent records file in v1 (stdout/--json is the audit trail; action_outcome always []).
#   S2 oscillation guard is v2-gated (asserted never to fire in v1).
#   S3 per-class authority rule (repo authoritative for the deployed config → reconcile).
#   S4 depth-limited depended_on_by walk (no hang on a cycle) + // [] coalescing.
#   M2 liveness count via find|wc -l (never grep -c double-echo).
# bash 3.2 + jq 1.7 target (macOS): all structure work is in jq; never GNU `date -d`.
#
# Usage:  reconcile.sh [--json] [--invariant <id>]
# Exit:   0 ran (verdict carries the signal — including UNINITIALISED/CORRUPT). 2 usage. 6 script failure.

set -u
# NB: intentionally NOT `set -e` — verdict computation must complete and report, not abort mid-run.
set -o pipefail

# ---- resolve paths (the skill dir, the frozen substrate helper) ------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# INVARIANT_DIR is env-overridable (additive testability seam — default unchanged, so all production +
# M4-eval behaviour is byte-identical; only an eval that sets the override sees a scratch registry).
INVARIANT_DIR="${TOPOLOGY_RECONCILE_INVARIANT_DIR:-$SKILL_DIR/references/invariants}"
SUB="$SKILL_DIR/../topology-substrate/scripts/substrate.sh"
# M6 (conservation class): the intent store + its computed-layer paths (resolved the SAME way intent-store.sh
# resolves them, so a conservation invariant with left_source:intent reads the same ledger). Read-only here.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

MODE="text"
ONLY_INVARIANT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) MODE="json"; shift ;;
    --invariant)
      # bash 3.2: `shift 2` with only 1 positional left is a SILENT no-op → infinite loop. Guard first.
      [ "$#" -ge 2 ] || { echo "reconcile.sh: --invariant requires an <id>" >&2; exit 2; }
      ONLY_INVARIANT="$2"; shift 2 ;;
    *) echo "reconcile.sh: unknown argument '$1' (usage: reconcile.sh [--json] [--invariant <id>])" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "reconcile.sh: jq not found" >&2; exit 6; }
[ -f "$SUB" ] || { echo "reconcile.sh: substrate helper not found at $SUB" >&2; exit 6; }

# ---- max-staleness window (hours) for the freshness precondition (configurable) --------------------------
STALE_WINDOW_H="${TOPOLOGY_RECONCILE_STALE_H:-168}"   # 7d default; beyond → stale-input-broken
# digits-only normalise (a malformed override falls back to default, never crashes a [ comparison)
STALE_WINDOW_H="$(printf '%s' "$STALE_WINDOW_H" | tr -dc '0-9' | head -c 6)"; STALE_WINDOW_H="${STALE_WINDOW_H:-168}"
# IMPACT_THRESHOLD — reserved for the v2 §11-step-3 threshold-gated escalate (a high-impact_rank drift →
# escalate instead of reconcile). NOT used in v1: every structural drift routes to reconcile per the S3
# per-class authority rule. Kept here as the documented v2 hook; do not wire into the selector until v2.
IMPACT_THRESHOLD="${TOPOLOGY_RECONCILE_IMPACT_THRESHOLD:-10}"  # v2-reserved
WALK_MAX_DEPTH="${TOPOLOGY_RECONCILE_WALK_DEPTH:-20}"
WALK_MAX_DEPTH="$(printf '%s' "$WALK_MAX_DEPTH" | tr -dc '0-9' | head -c 4)"; WALK_MAX_DEPTH="${WALK_MAX_DEPTH:-20}"

NOW_EPOCH="$(date -u +%s)"   # macOS-safe; jq does ALL ISO-8601 parsing via fromdateiso8601 (never date -d).

# ===========================================================================================================
# STEP 1 — read the substrate (map rc 4 → UNINITIALISED, rc 6/empty → CORRUPT). Mirrors the health-check.
# ===========================================================================================================
SUBSTRATE_JSON=""
READ_RC=0
SUBSTRATE_JSON="$(bash "$SUB" read-topology '.' 2>/dev/null)"; READ_RC=$?

emit_early() {  # $1=verdict $2=detail
  local v="$1" d="$2"
  if [ "$MODE" = "json" ]; then
    jq -n --arg v "$v" --arg d "$d" \
      '{verdict:$v, detail:$d, invariants:[], live_invariant_count:0, registry_health:{live_invariant_count:0, no_op_invariant_count:0}}'
  else
    echo "$v — $d"
  fi
}

if [ "$READ_RC" -eq 4 ]; then
  emit_early "UNINITIALISED" "no topology substrate found — run: bash $SUB init <entity>  then the emitters."
  exit 0
fi
if [ "$READ_RC" -ne 0 ] || [ -z "$SUBSTRATE_JSON" ]; then
  DETAIL="$(bash "$SUB" validate-schema 2>&1 | tr '\n' ' ' | sed -E 's/  +/ /g')"
  [ -n "$DETAIL" ] || DETAIL="substrate unreadable (read-topology rc $READ_RC)"
  emit_early "CORRUPT" "$DETAIL"
  exit 0
fi

# ===========================================================================================================
# STEP 2 — load the registered invariants (the §6.8 liveness gate counts non-no-op ones). M2: find|wc -l.
# ===========================================================================================================
if [ ! -d "$INVARIANT_DIR" ]; then
  emit_early "no-invariants-registered" "no invariants directory at $INVARIANT_DIR"
  exit 0
fi
# Collect invariant files (newline-safe enough for our controlled filenames; no spaces by convention).
INV_FILES=""
INV_COUNT=0
for f in "$INVARIANT_DIR"/*.json; do
  [ -f "$f" ] || continue
  if [ -n "$ONLY_INVARIANT" ]; then
    fid="$(jq -r '.id // ""' "$f" 2>/dev/null)"
    [ "$fid" = "$ONLY_INVARIANT" ] || continue
  fi
  INV_FILES="$INV_FILES$f
"
  INV_COUNT=$((INV_COUNT + 1))
done
if [ "$INV_COUNT" -eq 0 ]; then
  emit_early "no-invariants-registered" "registry empty (or --invariant '$ONLY_INVARIANT' matched none)"
  exit 0
fi

# ===========================================================================================================
# compute_conservation <invariant-json> : the M6 CONSERVATION-class branch (additive — council A1/A2/A3/A11).
#   Prints the §6.1 record (placeholder impact_rank) to stdout; compute_one falls it through to the SHARED
#   impact_rank enrichment tail (reused, NOT re-copied). Touches NO versioning/derivation code path.
#
#   Reads a SECOND source (the intent store) as DATA when left_source==intent (jq over JSON — NEVER calls
#   the M6 emitter, NEVER authors intent: the Doctrine 06 P2 boundary + the duck-typed §6.2 view contract).
#   Ordered guard chain mirrors Doctrine 06 §11: 0b NO_MAP (emitter-level, A3) -> intent-source -> freshness
#   (A11, field-level) -> 0c empty-views -> the node-exists-AND-enabled assertion -> the four-action selector.
#   Adds NO new record field beyond Phase-0's left_source (reuses inconclusive_reason + drift_detail.specifics)
#   -> Test D untouched (the left_source Test-D row was logged at Phase 0; S3a adds no further field).
# ===========================================================================================================
compute_conservation() {
  local inv="$1"
  local c_left_source c_intent_path c_intent_json c_computed_path c_computed_json
  c_left_source="$(printf '%s' "$inv" | jq -r '.left_source // "topology"')"

  # Load the left_view SOURCE as DATA (P2 — never an emitter call). A conservation invariant REQUIRES
  # left_source:intent (its left_view IS intent's wired_to — Doctrine 06 §6.4.3); intent -> INTENT_SUBSTRATE_PATH
  # (A2/D7), init-guarded (absent/unreadable/corrupt -> $intent becomes JSON null -> the jq emits
  # intent-source-absent, NEVER a false in_sync/drift). A non-intent left_source is a MISCONFIGURATION — pass
  # null (NEVER alias the topology substrate, which lacks .records and would abort the jq -> the dangerous
  # versioning fallthrough); the $lsource gate in the jq emits conservation-requires-intent-source.
  if [ "$c_left_source" = "intent" ]; then
    c_intent_path="${INTENT_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/intent-ledger.json}"
    if [ -f "$c_intent_path" ] && c_intent_json="$(cat "$c_intent_path" 2>/dev/null)" \
         && printf '%s' "$c_intent_json" | jq -e 'type=="object" and (.records|type=="array")' >/dev/null 2>&1; then
      c_computed_path="${INTENT_COMPUTED_PATH:-$(dirname "$c_intent_path")/intent-computed.json}"
      c_computed_json="$(cat "$c_computed_path" 2>/dev/null)"
      # the computed file must be an object WHOSE .records is an object (keyed by record id). A malformed
      # .records (array/string) would otherwise throw on $computed.records[$rid] -> empty base_record -> the
      # versioning fallthrough (code-council CRITICAL 2026-06-08). Normalise to {} on any mismatch; the in-jq
      # $crecs guard below is the second layer (defence in depth).
      printf '%s' "$c_computed_json" | jq -e 'type=="object" and ((.records // {} | type)=="object")' >/dev/null 2>&1 || c_computed_json="{}"
    else
      c_intent_json="null"; c_computed_json="{}"
    fi
  else
    c_intent_json="null"; c_computed_json="{}"
  fi

  # The whole §11 ordered guard chain as ONE jq. topology via stdin ($root); intent + computed via args.
  printf '%s' "$SUBSTRATE_JSON" | jq -c \
    --argjson inv "$inv" --argjson intent "$c_intent_json" --argjson computed "$c_computed_json" \
    --arg now "$NOW_EPOCH" --arg lsource "$c_left_source" '
    . as $root
    | ($inv.reads_dimension // "") as $dim
    | ($inv.right_view_kind // "rls_policy") as $rvkind
    # base record skeleton (placeholder impact_rank — the shared enrichment tail overwrites it).
    | { id:$inv.id, kind:$inv.kind, source_file:$inv.source_file, source_commit:$inv.source_commit,
        timestamp:($now|tonumber), left_source:($inv.left_source // "topology"),
        left_view:$inv.left_view_filter, right_view:$inv.right_view_filter, assertion:$inv.assertion,
        impact_rank:{rank:0, rank_completeness:null, missing_dimensions:[]},
        action_outcome:[], cadence:$inv.cadence, source_of_truth_ref:$inv.source_of_truth_ref } as $base
    # ---- GATE 0b EMITTER-LEVEL NO_MAP (A3): the emitter for the target kind IS the reads_dimension. A
    #      declared-missing/absent emitter -> unverifiable_dimension (the honest theatre-of-trust defence —
    #      NEVER drift/in_sync/stale over a dark surface). Two distinct reason codes keep next-step actionable.
    | ( if $dim != "" then ($root.emitters[$dim].coverage // "declared-missing") else "covered" end ) as $cov
    # ---- GATE config: conservation REQUIRES left_source:intent (Doctrine 06 §6.4.3). A non-intent left_source
    #      is a misconfiguration -> inconclusive (NEVER aliased to topology, NEVER the versioning fallthrough).
    | if $lsource != "intent"
      then $base + {verdict:"inconclusive", drift_detail:null, inconclusive_reason:"conservation-requires-intent-source",
                    affected_nodes:[], named_action:null}
      elif ($cov == "declared-missing" or $cov == "absent")
      then $base + {verdict:"unverifiable_dimension", drift_detail:null,
                    inconclusive_reason:(if $cov=="absent" then "no_topology_source_at_entity" else "topology_emitter_not_run" end),
                    affected_nodes:[], named_action:null}
    # ---- GATE intent-source (A2/D7): the intent store is absent/unreadable/corrupt -> inconclusive.
      elif ($intent == null)
      then $base + {verdict:"inconclusive", drift_detail:null, inconclusive_reason:"intent-source-absent",
                    affected_nodes:[], named_action:null}
      else
        ([ $intent.records[] | select(.status=="accepted") ]) as $accepted
        | ([ $root.nodes[] | select(.kind==$rvkind) ]) as $rv
        | ( $rv | map({key:.id, value:.}) | from_entries ) as $rv_by_id
        # normalise wired_to -> a flat list of {rec,target} (string/list/pending all handled).
        | ( [ $accepted[] | . as $r
              | ( $r.wired_to | if type=="array" then . elif (. == "pending") then [] elif type=="string" then [.] else [] end )
                | map({rec:$r.id, target:.}) ] | add // [] ) as $targets
        # the computed-layer records map, normalised to an OBJECT (a malformed .records — array/string — would
        # otherwise throw on [$rid] indexing -> empty base_record -> the versioning fallthrough; the bash guard
        # is the first layer, this is the second). keyed by intent record id.
        | ( ($computed.records // {}) | if type=="object" then . else {} end ) as $crecs
        # ---- GATE freshness (A11, field-level, committed-state-only). Reads the computed layer (P2 — a
        #      SEPARATE file). dirty/untracked carrier (status starts inconclusive) -> uncommitted-changes.
        #      committed-but-stale: the topology right_view is OLDER than the last change to the fields THIS
        #      invariant reads (wired_to + conditions ONLY — a wording edit to title does NOT gate it). A
        #      missing computed entry or unparseable timestamp FAILS SAFE toward proceeding (never a false
        #      inconclusive); the dirty guard is the binding never-false-in_sync demand.
        | ( [ $accepted[] | .id as $rid | ($crecs[$rid]) as $ce
              | select($ce != null and ((($ce.freshness_status // "") | startswith("inconclusive")))) | $rid ] ) as $dirty
        | ( [ $accepted[] | .id as $rid | ($crecs[$rid]) as $ce
              | select($ce != null and (($ce.freshness_status // "") == "committed"))
              | ( [ ($ce.fields.wired_to.last_changed_date // null), ($ce.fields.conditions.last_changed_date // null) ]
                  | map(select(. != null)) | map(try fromdateiso8601 catch null) | map(select(. != null)) ) as $fe
              | select(($fe | length) > 0)
              | ( [ $rv[] | (try (.timestamp | fromdateiso8601) catch null) | select(. != null) ] ) as $rve
              | select(($rve | length) > 0)
              | select(($rve | min) < ($fe | max)) | $rid ] ) as $stale
        | if ($dirty | length) > 0
          then $base + {verdict:"inconclusive", drift_detail:null, inconclusive_reason:"uncommitted-changes",
                        affected_nodes:[], named_action:null}
          elif ($stale | length) > 0
          then $base + {verdict:"inconclusive", drift_detail:null, inconclusive_reason:"stale-input",
                        affected_nodes:[], named_action:null}
        # ---- GATE 0c empty left_view (no accepted records, or every wired_to is pending) -> inconclusive.
          elif ($targets | length) == 0
          then $base + {verdict:"inconclusive", drift_detail:null, inconclusive_reason:"left-view-empty-or-pending",
                        affected_nodes:[], named_action:null}
          else
            # ---- THE ASSERTION: each wired_to target must resolve to a present rls node with enabled==true.
            #      absent (target gone — Gate 1) and disabled (present-but-enabled:false — the A.6 silent
            #      failure) are BOTH drift; rls_policy is a security control => HIGH consequence => §11 step 3
            #      => named_action escalate. present-but-no-enabled-attribute -> inconclusive (cannot assert
            #      the control is active — fail-safe, never a false in_sync/drift; A4 assert-before-rely).
            #      NB: jq // treats `false` AS empty, so `enabled // null` would mis-read enabled:false as
            #      missing. Use has("enabled") to separate MISSING (inconclusive) from FALSE (drift/disabled).
            ( [ $targets[] | select(($rv_by_id[.target]) == null) | .target ] | unique ) as $absent
            | ( [ $targets[] | ($rv_by_id[.target]) as $n
                  | select($n != null and ((($n.attributes // {}) | has("enabled")) | not)) | .target ] | unique ) as $no_attr
            | ( [ $targets[] | ($rv_by_id[.target]) as $n
                  | select($n != null and (($n.attributes // {}) | has("enabled")) and ($n.attributes.enabled != true)) | .target ] | unique ) as $disabled
            | if ($absent | length) > 0
              then $base + {verdict:"drift",
                            drift_detail:{reason_class:"unilateral_drift", specifics:{reason:"wired_to_target_absent", absent_targets:$absent}},
                            inconclusive_reason:null, affected_nodes:$absent, named_action:"escalate"}
              elif ($no_attr | length) > 0
              then $base + {verdict:"inconclusive", drift_detail:null, inconclusive_reason:"wired_target_missing_enabled_attribute",
                            affected_nodes:$no_attr, named_action:null}
              elif ($disabled | length) > 0
              then $base + {verdict:"drift",
                            drift_detail:{reason_class:"unilateral_drift", specifics:{reason:"wired_target_disabled", disabled_targets:$disabled}},
                            inconclusive_reason:null, affected_nodes:$disabled, named_action:"escalate"}
              else $base + {verdict:"in_sync", drift_detail:null, inconclusive_reason:null, affected_nodes:[], named_action:null}
              end
          end
      end'
}

# ===========================================================================================================
# compute_one <invariant-file> : prints ONE invariant-record JSON object (the §6.1 record) to stdout.
#   The verdict + named_action are produced by a SINGLE jq expression (C4 discriminated union).
# ===========================================================================================================
compute_one() {
  local invf="$1"
  local inv kind reads_dim cov join_key
  inv="$(cat "$invf")"
  kind="$(printf '%s' "$inv" | jq -r '.kind // "versioning"')"
  reads_dim="$(printf '%s' "$inv" | jq -r '.reads_dimension // ""')"

  # ---- 0b UNVERIFIABLE_DIMENSION (C3): jq -e on the coverage ENUM, never echo|grep -q, never a node-count.
  #      EXCLUDES conservation (M6) — that class does its own EMITTER-LEVEL NO_MAP routing with the two
  #      distinct A3 reason codes (topology_emitter_not_run vs no_topology_source_at_entity) in
  #      compute_conservation(); a non-conservation kind is byte-unchanged (the guard is always-true for it).
  if [ -n "$reads_dim" ] && [ "$kind" != "conservation" ]; then
    # jq -e returns rc 0 when the boolean is true. read-topology validates before serving.
    if printf '%s' "$SUBSTRATE_JSON" | jq -e --arg d "$reads_dim" \
         '(.emitters[$d].coverage // "declared-missing") as $c | ($c == "declared-missing" or $c == "absent")' \
         >/dev/null 2>&1; then
      printf '%s' "$inv" | jq -c --arg now "$NOW_EPOCH" '
        {id, kind, source_file, source_commit, timestamp:($now|tonumber),
         left_view:.left_view_filter, right_view:.right_view_filter, assertion,
         verdict:"unverifiable_dimension",
         drift_detail:null,
         inconclusive_reason:null,
         impact_rank:{rank:0, rank_completeness:"partial", missing_dimensions:[.reads_dimension]},
         affected_nodes:[], named_action:null, action_outcome:[], cadence, source_of_truth_ref}'
      return 0
    fi
  fi

  # ---- DERIVATION class: every depends_on target must resolve to an existing node.
  # (Reached when kind==derivation AND — if the invariant reads a dimension — that dimension is COVERED;
  #  the declared-missing case is handled by the unverifiable_dimension block above and returns early.)
  if [ "$kind" = "derivation" ]; then
    printf '%s' "$SUBSTRATE_JSON" | jq -c --argjson inv "$inv" --arg now "$NOW_EPOCH" '
      . as $root
      | ([ $root.emitters | to_entries[] | select(.value.coverage=="declared-missing" or .value.coverage=="absent") | .key ]) as $missing
      | ([$root.nodes[].id] | unique) as $ids
      | ([ $root.nodes[] | .id as $src | (.depends_on // [])[] | select((. as $t | $ids | index($t)) | not)
           | $src ] | unique) as $dangling_sources
      | ($dangling_sources | length) as $n_dangling
      | (if $n_dangling == 0
         then {verdict:"in_sync", named_action:null, affected:[], reason_class:null}
         else {verdict:"drift", named_action:"escalate", affected:$dangling_sources, reason_class:"unilateral_drift"}
         end) as $r
      | {id:$inv.id, kind:$inv.kind, source_file:$inv.source_file, source_commit:$inv.source_commit,
         timestamp:($now|tonumber),
         left_view:$inv.left_view_filter, right_view:$inv.right_view_filter, assertion:$inv.assertion,
         verdict:$r.verdict,
         drift_detail:(if $r.reason_class==null then null
                       else {reason_class:$r.reason_class, specifics:{dangling_source_count:$n_dangling}} end),
         inconclusive_reason:null,
         impact_rank:{rank:($r.affected|length),
                      rank_completeness:(if ($missing|length) > 0 then "partial" else "complete" end),
                      missing_dimensions:$missing},
         affected_nodes:$r.affected, named_action:$r.named_action, action_outcome:[],
         cadence:$inv.cadence, source_of_truth_ref:$inv.source_of_truth_ref}'
    return 0
  fi

  # ---- CONSERVATION class (M6, additive — council A1/G5). The comparator is selected by KIND, NEVER by an
  #      empty captured string: a conservation invariant ALWAYS routes through compute_conservation (and, if
  #      that errors, an honest inconclusive: compute-failed) — it can NEVER silently fall into the versioning
  #      comparator (the code-council CRITICAL/IMPORTANT silent-misreport class, 2026-06-08). Falls through to
  #      the SAME impact_rank enrichment tail below (reused, NOT re-copied).
  local base_record=""
  if [ "$kind" = "conservation" ]; then
    base_record="$(compute_conservation "$inv")" || base_record=""
    if [ -z "$base_record" ]; then
      # compute_conservation errored (a malformed source / jq abort) — emit an HONEST conservation inconclusive,
      # NEVER fall to the versioning comparator. Mirrors the STEP-3 full-shape fallback.
      base_record="$(printf '%s' "$inv" | jq -c --arg now "$NOW_EPOCH" '
        {id, kind, source_file, source_commit, timestamp:($now|tonumber),
         left_source:(.left_source // "topology"), left_view:.left_view_filter, right_view:.right_view_filter,
         assertion, verdict:"inconclusive", drift_detail:null, inconclusive_reason:"compute-failed",
         impact_rank:{rank:0, rank_completeness:"partial", missing_dimensions:[]},
         affected_nodes:[], named_action:null, action_outcome:[], cadence, source_of_truth_ref}')"
    fi
  else
  # ---- VERSIONING / STRUCTURAL class (the Test B headline): join repo↔cloud by attributes.n8n_id (C2),
  #      structural count-conservation fires drift independent of commit-time (T1); the commit-time
  #      sub-assertion routes to incomparable-provenance when either side is live:/+dirty (C1).
  #      M4-PROVEN PATH — byte-unchanged INSIDE this else; reached for every NON-conservation kind (a
  #      conservation kind is handled entirely above and can never enter here).
  join_key="$(printf '%s' "$inv" | jq -r '.join_key // "attributes.n8n_id"')"

  # Compute the comparison + the §11 decision-list as ONE jq expression returning the discriminated union.
  # Then enrich with impact_rank via a second jq pass (the depended_on_by walk, S4 depth-limited).
  base_record="$(printf '%s' "$SUBSTRATE_JSON" | jq -c \
    --argjson inv "$inv" --arg now "$NOW_EPOCH" --argjson nowep "$NOW_EPOCH" \
    --argjson window "$STALE_WINDOW_H" '
    . as $root
    # provenance classifier: git | live | dirty (from a source_commit string).
    | def prov($sc): (if ($sc // "") | startswith("live:") then "live"
                      elif ($sc // "") | endswith("+dirty") then "dirty"
                      elif (($sc // "") | length) > 0 then "git"
                      else "unknown" end);
      # n8n_id resolver (C2): the repo emitter writes attributes.n8n_id; the cloud emitter writes the
      # n8n id AS the node id (cloud:<n8n_id>) with attributes.n8n_id == null. Resolve from BOTH so the
      # join works across the asymmetric emitter schemas. Returns null if neither source yields an id.
      def n8nid($n): ($n.attributes.n8n_id // (if (($n.id // "") | startswith("cloud:"))
                                               then (($n.id) | sub("^cloud:"; "")) else null end));
      # the two sides, joined by the resolved n8n_id.
      ([ $root.nodes[] | select(.kind=="workflow" and ((.id // "") | startswith("repo:"))) ]) as $repo
    | ([ $root.nodes[] | select(.kind=="workflow" and ((.id // "") | startswith("cloud:"))) ]) as $cloud
    # repo-side duplicate-n8n_id detector (the copy-rename case — many repo nodes share one n8n_id).
    | ( reduce $repo[] as $r ({}; (n8nid($r)) as $k | if $k==null then . else .[$k] = ((.[$k] // 0) + 1) end) ) as $repo_id_counts
    # build the join: for each repo node with a resolvable n8n_id, find the cloud node with the same id.
    | ([ $repo[]
         | . as $r
         | (n8nid($r)) as $nid
         | if $nid == null then {repo:$r, cloud:null, join:"null_key"}
           elif (($repo_id_counts[$nid] // 0) > 1) then {repo:$r, cloud:null, join:"ambiguous"}
           else ( [ $cloud[] | select(n8nid(.) == $nid) ] ) as $matches
                | if ($matches | length) == 0 then {repo:$r, cloud:null, join:"no_cloud"}
                  elif ($matches | length) > 1 then {repo:$r, cloud:$matches[0], join:"ambiguous"}
                  else {repo:$r, cloud:$matches[0], join:"matched"} end
           end ]) as $pairs
    # also: cloud nodes with no repo counterpart (unclaimed cloud surface).
    | ([ $cloud[] | . as $c | (n8nid($c)) as $cid
         | select($cid == null or ([ $repo[] | select(n8nid(.) == $cid) ] | length) == 0)
         | $c ]) as $orphan_cloud
      # epoch of a node .timestamp (ISO 8601), or null if unparseable (NEVER GNU date -d — fromdateiso8601).
    | def tsepoch($n): (try (($n.timestamp // "") | fromdateiso8601) catch null);
      # is this matched-pair right_view (cloud) node a manual source-orphan? → unverifiable_spot (P6).
      # is either side stale beyond the window? → stale-input-broken/transient (P4/§6.7).
      # both node_count present? (a both-null match must NOT report in_sync — §8.4 vacuous-green-light).
      # pick the FIRST decision-relevant pair. Priority (most-severe / most-honest first):
      #   manual-orphan (unverifiable_spot) > ambiguous > stale > count-drift > both-null (inconclusive)
      #   > no-right > orphan-cloud > in_sync.
      ( [ $pairs[] | select(.join=="matched" and ((.cloud.emitter // "") == "manual")) ] ) as $manual_spot
    | ( [ $pairs[] | select(.join=="ambiguous") ] ) as $amb
    | ( [ $pairs[] | select(.join=="matched")
          | . as $p | (tsepoch($p.cloud)) as $ce | (tsepoch($p.repo)) as $re
          | select(($ce != null and (($nowep - $ce) > ($window * 3600)))
                or ($re != null and (($nowep - $re) > ($window * 3600)))) ] ) as $stale_pairs
    | ( [ $pairs[] | select((.join=="matched")
          and ((.repo.attributes.node_count // null) != null) and ((.cloud.attributes.node_count // null) != null)
          and ((.repo.attributes.node_count) != (.cloud.attributes.node_count))) ] ) as $count_drifts
    | ( [ $pairs[] | select((.join=="matched")
          and (((.repo.attributes.node_count // null) == null) or ((.cloud.attributes.node_count // null) == null))) ] ) as $count_absent
    | ( [ $pairs[] | select(.join=="null_key" or .join=="no_cloud") ] ) as $no_right
    | ( [ $pairs[] | select((.join=="matched")
          and ((.repo.attributes.node_count // null) != null) and ((.cloud.attributes.node_count // null) != null)
          and ((.repo.attributes.node_count) == (.cloud.attributes.node_count))) ] ) as $in_syncs
    # --- the ordered decision-list (first match wins) → {verdict, named_action, affected, ic_reason, detail} ---
    #   ic_reason: an inconclusive REASON CODE (separate from drift_detail.reason_class — Type Analyzer fix).
    | (if ($pairs | length) == 0 and ($orphan_cloud | length) == 0
       then {verdict:"inconclusive", named_action:null, affected:[],
             ic_reason:"right-view-absent", detail:{note:"no repo or cloud workflow nodes to compare"}}
       elif ($manual_spot | length) > 0
       then {verdict:"unverifiable_spot", named_action:null, affected:[($manual_spot[0].cloud.id)],
             ic_reason:null,
             detail:{note:"right_view is a manual source-orphan node — no continuous generator; cannot assert drift (P6/§8.5)"}}
       elif ($amb | length) > 0
       then {verdict:"inconclusive", named_action:null, affected:[($amb[0].repo.id)],
             ic_reason:"classification_uncertain",
             detail:{note:"two repo workflows share one n8n_id — cannot establish a unique join",
                     n8n_id:($amb[0].repo.attributes.n8n_id)}}
       elif ($stale_pairs | length) > 0
       then ($stale_pairs[0]) as $sp
            | (tsepoch($sp.cloud)) as $ce | (tsepoch($sp.repo)) as $re
            | (((if $ce==null then 0 else ($nowep-$ce) end)) ) as $cage
            | {verdict:"inconclusive", named_action:null, affected:[$sp.repo.id, $sp.cloud.id],
               ic_reason:"stale-input-broken",
               detail:{note:"a side is staler than the max-staleness window — cannot honestly compare (P4/§6.7)",
                       window_hours:$window, cloud_age_seconds:$cage}}
       elif ($count_drifts | length) > 0
       then ($count_drifts[0]) as $d
            # structural drift fires (T1). commit-time sub-verdict: incomparable if either side live/dirty (C1).
            | (prov($d.repo.source_commit)) as $lp
            | (prov($d.cloud.source_commit)) as $rp
            | (($lp=="git") and ($rp=="git")) as $time_comparable
            # per-class authority (S3): repo authoritative → cloud diverged → reconcile (redeploy to match repo).
            | {verdict:"drift", named_action:"reconcile",
               affected:[$d.repo.id, $d.cloud.id],
               ic_reason:null, reason_class:"unilateral_drift",
               detail:{structural:{field:"node_count",
                                   repo:$d.repo.attributes.node_count,
                                   cloud:$d.cloud.attributes.node_count,
                                   n8n_id:(n8nid($d.repo))},
                       commit_time:(if $time_comparable then "comparable"
                                    else {sub_verdict:"inconclusive", reason:"incomparable_provenance",
                                          left_provenance:$lp, right_provenance:$rp} end)}}
       elif ($count_absent | length) > 0
       then {verdict:"inconclusive", named_action:null, affected:[($count_absent[0].repo.id)],
             ic_reason:"right-view-absent",
             detail:{note:"a joined pair is missing node_count on a side — cannot compare (NOT a false in_sync, §8.4)"}}
       elif ($orphan_cloud | length) > 0
       then {verdict:"drift", named_action:"escalate",
             affected:[($orphan_cloud[0].id)],
             ic_reason:null, reason_class:"unilateral_drift",
             detail:{note:"a cloud workflow has no repo counterpart — unclaimed/unauthored surface",
                     authorship:"ambiguous"}}
       elif ($no_right | length) > 0 and ($count_drifts|length)==0 and ($in_syncs|length)==0
       then {verdict:"inconclusive", named_action:null, affected:[($no_right[0].repo.id)],
             ic_reason:"right-view-absent",
             detail:{note:"repo workflow has no cloud counterpart (join key null or cloud dimension not populated)"}}
       elif ($in_syncs | length) > 0
       then {verdict:"in_sync", named_action:null, affected:[], ic_reason:null, detail:{note:"all joined workflows match on node_count"}}
       else {verdict:"inconclusive", named_action:null, affected:[], ic_reason:"right-view-absent",
             detail:{note:"no decisive comparison available"}}
       end) as $r
    | {id:$inv.id, kind:$inv.kind, source_file:$inv.source_file, source_commit:$inv.source_commit,
       timestamp:($now|tonumber),
       left_view:$inv.left_view_filter, right_view:$inv.right_view_filter, assertion:$inv.assertion,
       verdict:$r.verdict,
       # drift_detail is populated ONLY on drift (the §6.3 discriminated union — a non-drift carries null).
       drift_detail:(if $r.verdict=="drift" then {reason_class:$r.reason_class, specifics:$r.detail} else null end),
       # inconclusive_reason is the separate reason-code field for non-drift inconclusive verdicts (Type Analyzer fix).
       inconclusive_reason:($r.ic_reason // null),
       impact_rank:{rank:0, rank_completeness:null, missing_dimensions:[]},
       affected_nodes:$r.affected, named_action:$r.named_action, action_outcome:[],
       cadence:$inv.cadence, source_of_truth_ref:$inv.source_of_truth_ref}')"
  fi

  # ---- impact_rank: walk depended_on_by from the FIRST affected node (S4: depth-limited, // [], cycle-safe).
  #      partial whenever any emitter dimension is declared-missing (the current substrate IS partial, §8.7).
  printf '%s' "$SUBSTRATE_JSON" | jq -c \
    --argjson rec "$base_record" --argjson depth "$WALK_MAX_DEPTH" '
    . as $root
    | ($rec.affected_nodes[0] // null) as $seed
    | ([ $root.emitters | to_entries[] | select(.value.coverage=="declared-missing" or .value.coverage=="absent") | .key ]) as $missing
    | (if $seed == null then {rank:0, cycle:false}
       else
         # BFS over depended_on_by with a visited set, depth-limited (cycle-safe).
         { frontier:[$seed], visited:{($seed):true}, rank:0, cycle:false, depth:0 } as $init
         | reduce range(0; $depth) as $_ ($init;
             if (.frontier | length) == 0 then .
             else
               ( [ .frontier[] as $n
                   | ($root.nodes[] | select(.id==$n) | (.depended_on_by // []))[]
                   | select(. as $t | (($init.visited[$t]) // false) | not) ] | unique ) as $next_raw
               | . as $st
               | ( [ $next_raw[] | select((($st.visited[.]) // false) | not) ] ) as $fresh
               | (if ($next_raw | length) != ($fresh | length) then true else $st.cycle end) as $cyc
               | { frontier:$fresh,
                   visited:( reduce $fresh[] as $f ($st.visited; .[$f]=true) ),
                   rank:($st.rank + ($fresh|length)),
                   cycle:$cyc, depth:($st.depth+1) }
             end)
         | {rank:.rank, cycle:.cycle, truncated:((.frontier|length) > 0)}
       end) as $walk
    | $rec
    | .impact_rank = {
        rank:$walk.rank,
        rank_completeness:(if ($missing|length) > 0 or $walk.cycle or ($walk.truncated // false) then "partial" else "complete" end),
        missing_dimensions:$missing,
        cycle_detected:$walk.cycle,
        depth_truncated:($walk.truncated // false)
      }'
}

# ===========================================================================================================
# STEP 3 — compute each invariant; collect records.
# ===========================================================================================================
RECORDS="[]"
LIVE_COUNT=0
while IFS= read -r invf; do
  [ -n "$invf" ] || continue
  rec="$(compute_one "$invf")"
  if [ -z "$rec" ]; then
    # full-shape fallback (Type Analyzer fix): carry kind/source_file/etc. from the invariant file so the
    # liveness gate's .kind select still works + the record shape stays consistent. verdict is an honest
    # inconclusive (compute failed) — never a false in_sync/drift.
    rec="$(jq -nc --slurpfile invf "$invf" --arg now "$NOW_EPOCH" '($invf[0] // {}) as $i |
      {id:($i.id // "unknown"), kind:($i.kind // "unknown"),
       source_file:($i.source_file // $i.id // "unknown"), source_commit:($i.source_commit // "m4-v1"),
       timestamp:($now|tonumber), left_view:($i.left_view_filter // null), right_view:($i.right_view_filter // null),
       assertion:($i.assertion // null), verdict:"inconclusive", drift_detail:null,
       inconclusive_reason:"compute-failed",
       impact_rank:{rank:0, rank_completeness:"partial", missing_dimensions:[]},
       affected_nodes:[], named_action:null, action_outcome:[],
       cadence:($i.cadence // "on-demand"), source_of_truth_ref:($i.source_of_truth_ref // null)}')"
  fi
  # a registered invariant that produced any verdict other than no-op counts toward liveness.
  RECORDS="$(jq -nc --argjson acc "$RECORDS" --argjson r "$rec" '$acc + [$r]')"
  LIVE_COUNT=$((LIVE_COUNT + 1))
done <<EOF
$INV_FILES
EOF

# ===========================================================================================================
# STEP 4 — liveness gate (§6.8): the registry must carry ≥1 versioning + ≥1 derivation with non-empty views.
#   In v1 with 3 registered invariants this holds; the gate exists so an empty/no-op registry never reads in_sync.
# ===========================================================================================================
HAS_VERSIONING="$(printf '%s' "$RECORDS" | jq '[.[] | select(.kind=="versioning")] | length')"
HAS_DERIVATION="$(printf '%s' "$RECORDS" | jq '[.[] | select(.kind=="derivation")] | length')"
# M6 (council A1, conservation-aware): a conservation invariant is also a live check — its in_sync is a real
# two-view comparison, not a vacuous empty-registry green. So the registry is live with EITHER the M4 two-class
# set (≥1 versioning + ≥1 derivation, byte-unchanged) OR ≥1 conservation invariant (a conservation-only
# registry is a distinct valid case). This only ADDS a liveness path; it never makes a previously-live
# registry non-live, so the M4 gate (CASE M empty-registry, CASE H/J versioning+derivation) is unchanged.
HAS_CONSERVATION="$(printf '%s' "$RECORDS" | jq '[.[] | select(.kind=="conservation")] | length')"
LIVENESS_OK="no"
if { [ "${HAS_VERSIONING:-0}" -ge 1 ] && [ "${HAS_DERIVATION:-0}" -ge 1 ]; } || [ "${HAS_CONSERVATION:-0}" -ge 1 ]; then LIVENESS_OK="yes"; fi

# ===========================================================================================================
# STEP 5 — assemble + emit. Top-line summary: any drift? any unverifiable? else in_sync/inconclusive.
# ===========================================================================================================
DRIFT_COUNT="$(printf '%s' "$RECORDS" | jq '[.[] | select(.verdict=="drift")] | length')"
# Honest compound summary (council §8.4 vacuous-green-light defence): IN_SYNC is reported ONLY when EVERY
# invariant is in_sync. Any drift dominates the top line; otherwise the presence of inconclusive /
# unverifiable verdicts is surfaced — never hidden behind a single in_sync. The summary leads with the
# strongest signal but the chat body lists every per-invariant verdict.
SUMMARY="$(printf '%s' "$RECORDS" | jq -r '
  ([.[] | select(.verdict=="drift")] | length) as $d
  | ([.[] | select(.verdict=="unverifiable_dimension" or .verdict=="unverifiable_spot")] | length) as $u
  | ([.[] | select(.verdict=="inconclusive")] | length) as $i
  | ([.[] | select(.verdict=="in_sync")] | length) as $s
  | (length) as $total
  | if $d > 0 then "DRIFT"
    elif $s == $total then "IN_SYNC"
    elif $s > 0 and ($i > 0 or $u > 0) then "PARTIAL"
    elif $i > 0 and $u == 0 then "INCONCLUSIVE"
    elif $u > 0 and $i == 0 then "UNVERIFIABLE"
    else "INCONCLUSIVE" end')"
# Liveness gate ENFORCEMENT (§6.8 — Spec Validator fix): on a FULL run (no --invariant filter), the
# mechanism is PROHIBITED from reporting IN_SYNC unless the registry carries ≥1 versioning + ≥1 derivation.
# A single --invariant run is a deliberately-scoped run, not the liveness check — so the gate is skipped there.
if [ -z "$ONLY_INVARIANT" ] && [ "$LIVENESS_OK" = "no" ] && [ "$SUMMARY" = "IN_SYNC" ]; then
  SUMMARY="no-invariants-registered"
fi
# the conditions list (supplementary multi-signal — surfaces every non-in_sync class present)
CONDITIONS="$(printf '%s' "$RECORDS" | jq -c '
  [ (if ([.[]|select(.verdict=="drift")]|length)>0 then "drift" else empty end),
    (if ([.[]|select(.verdict=="inconclusive")]|length)>0 then "inconclusive" else empty end),
    (if ([.[]|select(.verdict=="unverifiable_dimension" or .verdict=="unverifiable_spot")]|length)>0 then "unverifiable" else empty end),
    (if ([.[]|select(.verdict=="in_sync")]|length)>0 then "in_sync" else empty end) ]')"

if [ "$MODE" = "json" ]; then
  jq -nc --argjson records "$RECORDS" --arg summary "$SUMMARY" --argjson conditions "$CONDITIONS" \
    --argjson live "$LIVE_COUNT" --arg liveness "$LIVENESS_OK" '
    {summary:$summary,
     conditions:$conditions,
     drift_count:([$records[] | select(.verdict=="drift")] | length),
     invariants:$records,
     registry_health:{live_invariant_count:$live, no_op_invariant_count:0, liveness_ok:($liveness=="yes")}}'
else
  echo "RECONCILE — $SUMMARY  (${DRIFT_COUNT} drift, ${LIVE_COUNT} invariant(s) registered; liveness=${LIVENESS_OK})"
  printf '%s' "$RECORDS" | jq -r '.[] |
    "  • [\(.kind)] \(.id): \(.verdict)" +
    (if .named_action != null then "  → action: \(.named_action)" else "" end) +
    (if .verdict=="drift" then "  (impact_rank \(.impact_rank.rank), \(.impact_rank.rank_completeness))" else "" end) +
    (if .drift_detail != null then "\n      reason: \(.drift_detail.reason_class)" +
       (if (.drift_detail.specifics.structural // null) != null
        then " — node_count repo=\(.drift_detail.specifics.structural.repo) vs cloud=\(.drift_detail.specifics.structural.cloud) (n8n_id \(.drift_detail.specifics.structural.n8n_id))" else "" end) +
       (if (.drift_detail.specifics.commit_time.reason // null) == "incomparable_provenance"
        then "\n      commit-time sub-verdict: inconclusive (incomparable-provenance: \(.drift_detail.specifics.commit_time.left_provenance) vs \(.drift_detail.specifics.commit_time.right_provenance))" else "" end)
     else "" end)'
fi
exit 0
