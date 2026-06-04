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
INVARIANT_DIR="$SKILL_DIR/references/invariants"
SUB="$SKILL_DIR/../topology-substrate/scripts/substrate.sh"

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
  if [ -n "$reads_dim" ]; then
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

  # ---- VERSIONING / STRUCTURAL class (the Test B headline): join repo↔cloud by attributes.n8n_id (C2),
  #      structural count-conservation fires drift independent of commit-time (T1); the commit-time
  #      sub-assertion routes to incomparable-provenance when either side is live:/+dirty (C1).
  join_key="$(printf '%s' "$inv" | jq -r '.join_key // "attributes.n8n_id"')"

  # Compute the comparison + the §11 decision-list as ONE jq expression returning the discriminated union.
  # Then enrich with impact_rank via a second jq pass (the depended_on_by walk, S4 depth-limited).
  local base_record
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
LIVENESS_OK="no"
if [ "${HAS_VERSIONING:-0}" -ge 1 ] && [ "${HAS_DERIVATION:-0}" -ge 1 ]; then LIVENESS_OK="yes"; fi

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
