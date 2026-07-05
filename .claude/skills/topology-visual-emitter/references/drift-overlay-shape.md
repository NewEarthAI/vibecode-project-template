# Drift-Overlay Shape — `drift-overlay.json` contract (the heart)

> **Authority**: this file is the output contract of `scripts/drift-overlay-transform.jq` (the
> `reconcile --json` + substrate → drift-overlay transform). Derived from `specs/16_VISUAL_LAYER_DESIGN.md`
> §4 + the FROZEN reconcile contract `.claude/skills/topology-reconcile/references/reconcile-shape.md`. It is
> a render-target-agnostic generalisation of Understand-Anything's `diff-overlay.json` (`{changedNodeIds,
> affectedNodeIds}`): it swaps "changed by a git diff" for "drifted per a reconcile verdict" and adds the two
> coverage states the competitor's 2-state diff lacks. READ-ONLY over reconcile output — it never executes an
> action (Doctrine 06: v1 proposes, never auto-executes).
>
> **Programme**: Intent-Actual-Gap Mechanism Build Programme, downstream application #1, Wave 1.

---

## Top-level envelope

```json
{
  "version":     "drift-overlay-v1",
  "generatedAt": "<ISO 8601 UTC>",
  "entity":      "<entity name>",
  "summary":     "<DRIFT | IN_SYNC | PARTIAL | INCONCLUSIVE | UNVERIFIABLE | no-invariants-registered>",
  "driftCount":  <int>,
  "driftNodeIds":        ["<node_id>"],
  "blastRadiusNodeIds":  ["<node_id>"],
  "blastRadiusPartial":  <bool>,
  "blindSpotNodeIds":    ["<node_id>"],
  "unverifiableNodeIds": ["<node_id>"],
  "actions": {
    "<node_id>": {
      "named_action":     "<reconcile|revert|approve_as_intentional|escalate>",
      "impact_rank":      <int>,
      "rank_completeness":"<complete|partial>",
      "reason":           "<drift_detail.reason_class>",
      "provenance":       "<source_file@source_commit>",
      "source_of_truth_ref": "<what defines 'intended' for this drift>"
    }
  }
}
```

## The 5 node-state sets → colour (design §4.1)

| set | colour | sourced from reconcile `--json` | operator reading |
|---|---|---|---|
| `driftNodeIds` | **red** | `invariants[] | select(.verdict=="drift") | .affected_nodes[]` | "diverged from intent — act" |
| `blastRadiusNodeIds` | **orange** | the cycle-safe `parent_map`/`depended_on_by` walk from each drift node (over the substrate) | "downstream of a drift — at risk" |
| `blindSpotNodeIds` | **amber** | `invariants[] | select(.verdict=="unverifiable_dimension") | .affected_nodes[]` (+ coverage `declared-missing`/`absent` margin chips, read from the substrate by the viewer) | "we can't see here — NOT a clean bill of health" |
| `unverifiableNodeIds` | **grey** | `invariants[] | select(.verdict=="unverifiable_spot" or .verdict=="inconclusive") | .affected_nodes[]` | "we looked but can't judge" |
| (in-sync) | faded | every node in none of the above | the de-emphasised majority |

## The node set-precedence rule (mandatory)

A node can be implicated by more than one invariant (e.g. a drifted node also appears in an
`inconclusive` invariant's `affected_nodes`). Precedence assigns each node to **exactly one** set:

```
red (drift)  >  orange (blast-radius)  >  amber (blind-spot)  >  grey (unverifiable)  >  faded (in-sync)
```

The transform applies this by subtraction in order: build `driftNodeIds` first, remove them from the
blast-radius candidates, remove both from blind-spot, remove all three from unverifiable. A drifted node is
NEVER also rendered grey/faded — preventing the "drift hidden behind a fade" failure. The local viewer must
honour the same precedence when colouring.

## The honesty guards (carried from the doctrines)

1. **`summary` is verbatim from reconcile.** The transform copies `reconcile.summary` unchanged. The map's
   headline can NEVER be greener than the verdict it renders (design §4.5; Doctrine 06 §8.4
   vacuous-green-light defence). A `drift-overlay.json` whose `summary` differs from its source reconcile
   `summary` is a contract violation.
2. **Blind-spot ≠ in-sync.** `unverifiable_dimension` / `declared-missing` coverage produces an **amber**
   node or a margin chip — never a green/faded node (Doctrine 05 P6).
3. **`unverifiable_spot` ≠ a clean verdict.** A `manual` source-orphan is **grey**, never rendered as
   in-sync (reconcile §6.7).
4. **`blastRadiusPartial`** is `true` when ANY contributing drift node's `impact_rank.rank_completeness ==
   "partial"` — so the viewer can label the blast radius "incomplete (some dimensions not introspected)"
   rather than imply it is the full radius. The current my-project substrate is partial (supabase + n8n
   declared-missing), so every real rank on it is partial.

## `actions{}` — the "decide the next move" payload

One entry per drift node (`verdict=="drift"`). Carries the reconcile `named_action`, the `impact_rank.rank`
(for ordering the side panel), `rank_completeness`, the `drift_detail.reason_class`, the provenance
(`source_file@source_commit`), and the `source_of_truth_ref`. The viewer's ranked side panel renders one row
per action, ordered by `impact_rank` descending. The action is **displayed, never executed** (reconcile v1
proposes only).

## What this contract is NOT

- **Not the graph** — node *structure* lives in `graph.json` (`references/graph-shape.md`); this file is
  *state only* (which nodes are in which drift set). The two are merged at render time.
- **Not an executor** — `named_action` is a proposal surfaced to the operator, never run by the viewer.
- **Not richer than the source** — every set + the summary trace to a reconcile verdict; the transform adds
  no judgement of its own (it only walks the substrate for the blast-radius node list, which reconcile's
  `impact_rank` counts but does not enumerate).
