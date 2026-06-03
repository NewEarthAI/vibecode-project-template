---
title: 30-Day Sustain Log Schema
purpose: Make the Intent-Actual-Gap Mechanism's 30-day sustain (DESTINATION Test C) machine-verifiable
maintained_by: Workshop (First Principles Systems Thinker)
authored: 2026-06-02 (M5 Phase 1 — Path B+, council session 2026-06-02-m5-intent-layer-sequencing)
format: Approach A (markdown table per-entity), mirrors propagation-telemetry.md
closes: Reliability Engineer NON-SHIPPABLE #3 (no defined verification procedure for the sustain)
---

# 30-Day Sustain Log Schema

## Why this exists

DESTINATION Test C requires: "at least one /autovibe consumption per week per entity ... for the
30 consecutive days preceding the claim ... verifiable via the entity's session logs." Without a
defined log location + schema + format, the 30-day window cannot be closed — the operator cannot
prove the criterion was met and a third-party verifier cannot confirm it. This schema is that
verification artefact. It composes with `propagation-telemetry.md` (same Approach-A register) and is
the durable sink for the per-consumption verdicts emitted by `sustain-staleness-gate.sh` (the M5
freshness gate) + `/topology reconcile --json`.

## The "consecutive 30 days" rule (OPERATOR DECISION, 2026-06-02)

**Rolling window — NOT a strict calendar streak.** Success = there exists a trailing 30-day window in
which EVERY propagated entity received ≥1 fresh-substrate consumption in EACH of the window's weekly
slots. A single missed weekly slot on one entity does NOT reset the count to zero — it extends the
finish line (the trailing window slides forward until all slots are filled again). This is the
realistic rule for a solo operator running the sustain across 3 entities; a strict consecutive-streak
rule would make the milestone effectively impossible to close. (Resolves Edge Case Finder #5; council
2026-06-02 + operator confirmation.)

A "weekly slot" = a 7-day bucket. The window is satisfied when, for each of the 3 entities, every
7-day bucket inside the trailing 30 days contains ≥1 row with `staleness_verdict: fresh_substrate`
AND `gamed: no`.

## Log location

One log file per entity, at the entity repo's `.understand-anything/sustain-log.md` (the same gitignored
ephemeral folder the substrate lives in — the sustain log is per-entity ephemeral operational state, not
a workshop artefact). The workshop keeps NO central sustain log; the proof lives where the mechanism runs.

A consumption event appends ONE row. The append is the only write; rows are never edited (an
append-only ledger, like `action_outcome` in Doctrine 06).

## Schema — one row per consumption event

| Field | Type | Source | Description |
|---|---|---|---|
| `observed_at` | ISO-8601 UTC | the consuming session | When the consumption ran (stamped by the session, not the substrate). |
| `entity` | string | the substrate `.entity` | Which entity (`buybox-ai` / `nirvana` / `agency-main`). |
| `consumer` | enum | the session | `autovibe` / `daily-plan` / `manual-session` — what consumed the output. ≥1 `autovibe` per weekly slot is the Test C bar; the others are supplementary. |
| `staleness_verdict` | enum | `sustain-staleness-gate.sh --json` → `.verdict` | `fresh_substrate` / `stale_substrate` / `anomalous` / `uninitialised` / `corrupt`. **ONLY `fresh_substrate` rows count toward the sustain.** A `stale_substrate` row is logged honestly but does NOT fill its weekly slot — it records "the operator consumed against a stale map; re-scan needed." |
| `oldest_emitter` | string\|null | gate `--json` → `.oldest_emitter` | Which scanner is oldest (the staleness driver), for diagnosis. **Null when `staleness_verdict` is `uninitialised` or `corrupt`** — those paths exit before any emitter is age-analysed. |
| `oldest_age_hours` | int\|null | gate `--json` (`.oldest_age_seconds`/3600 floored) | Age of the oldest covered scanner. **Null when `staleness_verdict` is `uninitialised` or `corrupt`** (see above). |
| `reconcile_summary` | enum | `topology reconcile --json` → `.summary` | `DRIFT` / `IN_SYNC` / `PARTIAL` / `INCONCLUSIVE` / `UNVERIFIABLE` / `no-invariants-registered`. The drift-surface signal. |
| `drift_count` | int | reconcile `--json` → `.drift_count` | How many invariants surfaced drift this run. |
| `liveness_ok` | bool | reconcile `--json` → `.registry_health.liveness_ok` | Whether the registry carried ≥1 versioning + ≥1 derivation invariant (a `false` here means the reconcile run could not honestly report IN_SYNC — surfaced, not hidden). |
| `drift_surface_nonempty` | bool | derived | `true` if this run surfaced ANY actionable signal (drift OR a non-trivial inconclusive/unverifiable a human acted on). DESTINATION Condition 7 requires the drift-surface logs to be non-empty over the window — i.e. the mechanism caught real things, it isn't running over a frozen happy-path. |
| `gamed` | enum | operator attestation | `no` (the operator acted on the mechanism's output) / `suspected` (the operator hand-scraped in parallel — the theatre-of-trust failure). A `suspected` row does NOT count toward the sustain. This field is the honest guard the council named: a green log over parallel hand-scraping is a fake sustain. |
| `action_taken` | string\|null | the session | If drift surfaced, the named action applied (revert / reconcile / approve_as_intentional / escalate) — links the log to a real closure, not just detection. Null when `reconcile_summary` is `IN_SYNC`. |

## A row, by example (markdown table line in the entity's sustain log)

```markdown
| observed_at | entity | consumer | staleness_verdict | oldest_emitter | oldest_age_hours | reconcile_summary | drift_count | liveness_ok | drift_surface_nonempty | gamed | action_taken |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-06-09T14:03:11Z | buybox-ai | autovibe | fresh_substrate | code | 18 | DRIFT | 1 | true | true | no | reconcile |
| 2026-06-16T09:40:55Z | buybox-ai | autovibe | fresh_substrate | code | 22 | IN_SYNC | 0 | true | true | no | null |
| 2026-06-16T10:02:30Z | nirvana | autovibe | fresh_substrate | supabase-live | 30 | PARTIAL | 0 | true | true | no | null |
```

## How a consumption event writes its row (the mechanical recipe)

1. Run the freshness gate: `sustain-staleness-gate.sh --json` (in the health-check skill). Capture `.verdict`, `.oldest_emitter`, `.oldest_age_seconds`.
2. If `stale_substrate` → re-run the entity's emitters first (re-scan), then re-run the gate. Only proceed to consume on `fresh_substrate`. (A `stale_substrate` row MAY still be logged to record the miss honestly — it just doesn't fill the slot.)
3. Run `topology reconcile --json`. Capture `.summary`, `.drift_count`, `.registry_health.liveness_ok`.
4. If drift surfaced, apply + record the named action.
5. Append ONE row to the entity's sustain log with the operator's `gamed` attestation.

## Closing the window (the Test C claim)

The 30-day sustain is claimable when, for ALL 3 propagated entities, there exists a trailing 30-day
window where every 7-day slot has ≥1 row with `staleness_verdict: fresh_substrate` AND `gamed: no`,
AND the window's `drift_surface_nonempty` is `true` for at least one row per entity (real drift was
detected + closed, not a frozen happy-path). A counting helper over the three logs produces the
PASS/PENDING verdict; the claim cites the three log files + the window dates.

## What this schema is NOT

- NOT a workshop-central record — it is per-entity ephemeral, lives where the mechanism runs.
- NOT editable — append-only; a wrong row is corrected by a new row, never a mutation.
- NOT a substitute for `propagation-telemetry.md` — that records the propagation EVENT (artefact landed
  in entity); this records the ongoing CONSUMPTION (the mechanism stays in use). Propagation is the NSM
  count; sustain is the "did it stick?" proof on top.

## References

- `sustain-staleness-gate.sh` (`.claude/skills/topology-health-check/scripts/`) — emits `staleness_verdict`.
- `reconcile.sh --json` (`.claude/skills/topology-reconcile/scripts/`) — emits `reconcile_summary` + `drift_count` + `liveness_ok`.
- `propagation-telemetry.md` (`.claude/skills/_shared/`) — the sibling NSM-count manifest.
- Council: `council/sessions/2026-06-02-m5-intent-layer-sequencing.md` (Path B+, the rolling-window + theatre-of-trust guards).
- Plan: `specs/15_M5_PROPAGATION_SUSTAIN_PLAN.md` (Phase 1 day-one closures).
- DESTINATION Test C + Condition 6/7 (`DESTINATION.md`).
