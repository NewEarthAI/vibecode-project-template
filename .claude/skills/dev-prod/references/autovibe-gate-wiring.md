# /autovibe Hard Staging-First Gate — Contract

> The gate contract `/autovibe` Phase 5.5 follows. Hard gate (not advisory): an autonomous run
> cannot reach production directly without an explicit flag + a verified, externally-attributed
> logged record. Kernel-transition calls below apply only if the project's autovibe has the
> kernel-registration layer; otherwise record the gate decision in the project's audit trail.

## Where the gate sits

`/autovibe`: `plan → council → amend → execute → code-council → /ship`. The gate is **Phase 5.5**,
between code-council and the `/ship` phase (`/ship` is what reaches the live remote).

## Gate contract

```
Phase 5.5 — staging-first gate (dev-prod skill)

1. Resolve entity from profile_slug / branch context.
   - Fail-closed: no row / unknown / ambiguous → HARD STOP, halt to failed, write a
     continuation. Never default to any entity. Unresolved == not wired.
2. Read the STATUS token (not prose) in dev-prod/references/entity-routing.md.
   - Anything but exactly `wired` (or a missing staging ref) → HARD STOP, continuation.
3. Default ship target = staging. Execute + validation ran against staging; /ship targets
   staging, not production, unless the override below is satisfied.
4. Pre-promotion checklist (dev-prod SKILL.md) must pass — including the exhaustive
   hardcoded-prod-ref grep and the staging-healthy precondition (timeout ≠ pass).
```

## Production-direct override

BOTH required — flag alone is not enough:

1. **Explicit truthy flag**: `AUTOVIBE_PROD_DIRECT` = `1/true/yes/enabled` (case-insensitive).
   Absent, empty, or `0/false/no/off/disabled` = staging-first.
   **Fail-safe inversion**: this is the OPPOSITE default to the kill-switch convention (where
   unset = enabled). Here unset = staging-first (safe). Only an affirmatively-truthy value
   unlocks prod-direct.
2. **Externally-attributed `who`**: NOT self-asserted by the agent requesting the override.
   Resolve from `$GIT_AUTHOR_EMAIL`, the session identity, OR a human-typed confirmation —
   never the agent's own claim.
3. **Logged record, write-then-verify**: write the override record, then read it back and
   confirm it landed BEFORE `/ship`. **Order: write → read-back-verify → only then `/ship`.**
   This record write follows HALT discipline — a failed/timed-out write halts the run; it
   never resolves to "shipped anyway."

No flag → halt at the gate, write a continuation, never silently ship to prod. Truthy flag but
record unverifiable → gate failure.

## Kernel transitions (only if autovibe has kernel registration)

| Boundary | Call | Status |
|---|---|---|
| Gate entered | `autovibe_transition(run_id, 'phase5_5', 'staging_gate_entered', 'running', {entity, ship_target})` | running |
| Gate pass (staging) | `autovibe_transition(run_id, 'phase5_5', 'staging_gate_pass', 'running', {ship_target:'staging'})` | running |
| Prod-direct override | `autovibe_transition(run_id, 'phase5_5', 'prod_direct_override', 'running', {reason, who})`, then SELECT back to confirm | running |
| Gate halt (stub/unresolved/checklist fail/no flag) | `autovibe_transition(run_id, 'phase5_5', 'staging_gate_halt', 'failed', {reason, continuation_path})` | failed |

> **`failed`, not `waiting`**: an orphan watchdog auto-fails `registered/running/waiting` rows
> after a timeout; a gate-halt is not a resumable pause (resume = a NEW run after staging
> promotion), so `failed` + `{continuation_path}` avoids the watchdog racing the operator.

## Test before trusting the wiring

- Stub / unresolved entity → gate hard-stops (no /ship).
- Wired entity, checklist passes, no flag → ships to STAGING, not prod.
- Wired entity, truthy flag + verified record → ships to prod, override row present.
- Wired entity, flag set but record write fails → gate fails (no silent prod ship).
