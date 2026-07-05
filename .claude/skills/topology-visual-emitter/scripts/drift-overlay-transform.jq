# topology-visual-emitter/scripts/drift-overlay-transform.jq
# Transform the FROZEN reconcile --json output + the substrate into the render-target-agnostic
# drift-overlay.json. Output contract: references/drift-overlay-shape.md. READ-ONLY.
#
# Intent-Actual-Gap Mechanism Build Programme, visual layer Wave 1. The genuine delta over the
# competitor's 2-state git diff: a 5-state coverage-and-drift overlay, drift-first, honesty-guarded.
#
# INVOCATION (reconcile --json on stdin; substrate via --slurpfile):
#   bash .../topology-reconcile/scripts/reconcile.sh --json \
#     | jq --arg now "$NOW" \
#          --slurpfile sub <(bash .../topology-substrate/scripts/substrate.sh read-topology '.') \
#          -f .claude/skills/topology-visual-emitter/scripts/drift-overlay-transform.jq
#
#   .          the reconcile --json envelope ({summary, drift_count, invariants[], ...})
#   $sub[0]    the substrate (for the depended_on_by / parent_map blast-radius walk + the entity)
#   $now       ISO 8601 UTC of this run — drift-overlay.json generatedAt
# OUTPUT: the drift-overlay.json envelope.

# ===== helpers (defensive coercion — degrade, never abort) =====
def as_arr: if type == "array" then . else [] end;

# Walk depended_on_by (substrate parent_map) outward from a seed set — depth-limited + cycle-safe
# (mirrors the reconcile impact_rank walk; default depth 20, visited-set terminates cycles).
def walk_up($seeds; $pmap; $maxdepth):
  { visited: ($seeds | unique), frontier: ($seeds | unique), depth: 0 }
  | until(.frontier == [] or .depth >= $maxdepth;
      ([ .frontier[] | (($pmap[.] // []) | as_arr)[] ] | unique) as $next
      | ($next - .visited) as $new
      | { visited: (.visited + $new | unique), frontier: $new, depth: (.depth + 1) })
  | .visited;

. as $rec
| (($sub[0]) // {}) as $substrate
| (($substrate.parent_map) // {}) as $pmap
| ($rec.invariants | as_arr) as $invs

# ----- the raw node sets, per verdict (design §4.1) -----
| ([ $invs[] | select(.verdict == "drift")                 | (.affected_nodes | as_arr)[] ] | unique) as $drift
| ([ $invs[] | select(.verdict == "unverifiable_dimension") | (.affected_nodes | as_arr)[] ] | unique) as $blind0
| ([ $invs[] | select(.verdict == "unverifiable_spot" or .verdict == "inconclusive") | (.affected_nodes | as_arr)[] ] | unique) as $unv0

# blast radius = depended_on_by walk from the drift nodes (the impact_rank node list reconcile only counts)
| ((walk_up($drift; $pmap; 20)) - $drift | unique) as $blast0

# blastRadiusPartial: true if ANY contributing drift node's rank is partial (honesty guard §4.5)
| ([ $invs[] | select(.verdict == "drift") | (.impact_rank.rank_completeness // "complete") ] | index("partial") != null) as $blastPartial

# ----- precedence: red > orange > amber > grey (each node in exactly one set) -----
| ($blast0 - $drift)                  as $blast
| ($blind0 - $drift - $blast)         as $blind
| ($unv0   - $drift - $blast - $blind) as $unv

# ----- the per-drift-node actions ("decide the next move") -----
| (reduce ($invs[] | select(.verdict == "drift")) as $iv ({};
     reduce (($iv.affected_nodes | as_arr)[]) as $nid (.;
       .[$nid] = {
         named_action:        $iv.named_action,
         impact_rank:         ($iv.impact_rank.rank // 0),
         rank_completeness:   ($iv.impact_rank.rank_completeness // "partial"),
         reason:              ($iv.drift_detail.reason_class // null),
         provenance:          (($iv.source_file // "") + "@" + ($iv.source_commit // "")),
         source_of_truth_ref: ($iv.source_of_truth_ref // null)
       }))) as $actions

# ----- the envelope; summary carried VERBATIM (the §8.4 vacuous-green-light defence) -----
| { version:             "drift-overlay-v1",
    generatedAt:         ($now // ""),
    entity:              ($substrate.entity // "unknown"),
    summary:             ($rec.summary // "INCONCLUSIVE"),
    driftCount:          ($rec.drift_count // ($drift | length)),
    driftNodeIds:        $drift,
    blastRadiusNodeIds:  $blast,
    blastRadiusPartial:  $blastPartial,
    blindSpotNodeIds:    $blind,
    unverifiableNodeIds: $unv,
    actions:             $actions }
