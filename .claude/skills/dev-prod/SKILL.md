---
name: dev-prod
description: |
  Environment-routing, promotion, and rollback discipline for a project's dev/prod
  separation. Use when promoting a change to production, deciding whether something is
  safe to ship to prod, routing work to a staging/dev environment first, running a
  rollback drill, or wiring an autonomous run so it cannot reach production directly.
  NOTE: the /autovibe staging-first gate is wired in autovibe SKILL.md §Phase 5.5, but it
  is procedure-level (honoured by the orchestrator), not a hard PreToolUse block — treat
  accordingly until a hardening hook lands.
  Do NOT use for: Vercel deploy mechanics (use deploy-vercel), VPS disk/container ops
  (use n8nspace / digitalocean-infra), or generic git shipping (use /ship).
version: 1.1
classification: encoded-preference
created: 2026-06-02
updated: 2026-06-24
validated_on:
  - "Promote a Supabase schema change through staging before production"
  - "Block an autonomous /autovibe run from reaching production without a logged override"
  - "Make a drifted migration history rebuildable from code via a single trustworthy baseline (proven on a real prod baseline, 2026-06-24)"
  - "Refuse to baseline while migrations are actively shipping (stale-on-arrival guard)"
allowed-tools: Read, Bash, Grep, Glob, mcp__supabase-{{project}}__execute_sql
---

# dev-prod — Environment Routing, Promotion & Rollback

> Codifies a project's dev/prod separation pattern. This skill is the invocable
> **procedure + registry**; it does NOT re-implement the project's policy or runbook — it
> points at them. Before relying on it, the project's entities must be wired in
> `references/entity-routing.md` (a fresh template ships with stub rows only).

> ## ENFORCEMENT STATUS — honour vs hard-enforce
>
> The separation LAYERS (e.g. Supabase prod-vs-staging, n8n prod-vs-dev) are standing
> infrastructure that must be set up + proven per project. The **/autovibe staging-first
> gate** is wired in `autovibe/SKILL.md` §Phase 5.5 — but it lives in the orchestrator
> procedure (instruction the orchestrator follows), NOT in a PreToolUse hook that physically
> blocks `/ship`. The gate is as strong as the orchestrator's adherence to its own procedure
> — strong for a compliant run, not tamper-proof against a broken one. A future hardening
> step could add such a hook.

## What this skill is

Three jobs:

1. **Route + promote + rollback** — given a change for an entity, route it to that entity's
   staging surface first, validate, then promote to production via the project's proven
   recipe, with a rollback path that meets the project's rollback-time target.
2. **Gate autonomy** — the **hard staging-first gate** that `/autovibe` runs through before
   `/ship` (autovibe SKILL.md §Phase 5.5), so an autonomous run cannot reach production
   directly. Production-direct requires an explicit, externally-attributed, verified logged
   override. This is the structural precondition for autonomous (agent-driven) operation.
3. **Make a safe baseline** — turn a drifted, untrustworthy migration history into ONE clean
   baseline that rebuilds from code, so a throwaway copy can be stood up to prove changes
   against (the precondition for staging / Branching). System-agnostic PATTERN +
   per-DB-system adapters. See `references/make-safe-baseline.md`. This is a one-time-per-DB
   op with two non-negotiable safeguards (freeze-during-baseline; rescan-path-readers-before-archive).

## The pattern (per-entity, typically two layers)

A separated entity isolates at least its data layer and its automation layer:

| Layer | Production | Staging / Dev | Isolation proof to capture |
|---|---|---|---|
| **Supabase** | project `{{prod_ref}}` | project `{{staging_ref}}` (separate project, keys, compute) | row written to staging is absent from prod; schemas byte-identical |
| **n8n** (if used) | prod container/instance | separate dev container/instance (own DB, volume, key) | a dev workflow is absent from prod; prod uptime unchanged |

Resolve the live values per entity in `references/entity-routing.md` (stub rows on a fresh
template — fill them in as each entity is separated and proven).

## When invoked — the decision flow

```
1. Identify the entity from context.
2. Look up the entity's STATUS token in references/entity-routing.md.
   - STATUS: wired   → proceed.
   - STATUS: stub    → STOP. Tell the operator this entity is not yet wired; do not
                       invent a staging target.
3. Classify the request:
   - "route / where should this run"  → answer with the staging target, never prod first.
   - "promote to production"          → run the PROMOTION procedure below.
   - "rollback" / "rollback drill"    → run the ROLLBACK procedure below.
   - "is this safe to ship to prod"   → run the PRE-PROMOTION CHECKLIST below.
   - "make a baseline" / "squash migration history" / "make the DB rebuildable from code"
                                       → run the MAKE-SAFE-BASELINE recipe (references/make-safe-baseline.md).
                                         First resolve the DB system's adapter — STATUS must be `wired`.
4. Production write of any kind → confirm explicitly (destructive-action discipline).
```

## Procedure — route to staging first

The default answer to "where does this change run?" is **staging, always**.

- **Supabase work**: target the staging project ref, not the production ref. If staging
  auto-pauses (free/lightweight tier), wake it before use (see `references/staging-wake.md`).
- **n8n work**: target the dev container/instance. Never edit production workflows directly.

Reaching production directly is not the default and is friction-positive by design (see the
gate section).

## Procedure — promote to production

Run after the change is validated in staging. Per-layer steps live in the project's
staging-promotion runbook — this skill names the sequence, the runbook carries specifics.

```
[ ] Change implemented + validated in STAGING (smoke test the affected surface)
[ ] Schema-drift check: staging vs prod column lists match (no drift to promote into)
[ ] Rollback rehearsed OR rollback path written down (must meet the rollback-time target)
[ ] Credential check: staging creds are not leaking into the production config
[ ] Promote: apply to production
[ ] Monitor the affected surface
[ ] Record the promotion (what, when, rollback command) in the project's audit trail
```

## Procedure — rollback (proven recipe shape)

A proven Supabase shape: `ADD COLUMN` → `UPDATE` → `DROP COLUMN` inverse, **on staging only**
during a drill; on production only as a real rollback with explicit confirmation.
Date-qualify any ephemeral object name so residue is obvious. Log start/finish timestamps —
the rollback-time target is verified against wall-clock, not estimated.

## Pre-promotion checklist — "is this safe to ship to prod?"

Answer with evidence, not vibes:

- **Staging is awake first.** Confirm staging status is healthy before validation. A
  connection timeout or paused status is **not** a passing smoke test — it is inconclusive
  and fails the gate until staging is woken and the test runs to completion. **Timeout ≠ pass.**
- Did it run in staging and pass a smoke test? (yes/no + what was tested)
- Is there schema drift between staging and prod? Run the column-list comparison — AND note
  that matching column lists alone does NOT prove zero drift. A full check also compares RLS
  policies, triggers, views, and function definitions.
- Is there a rehearsed rollback under the target time? (yes/no + drill log)
- **Hardcoded-prod-ref audit (exhaustive, not sampled).** A column comparison CANNOT catch an
  edge function that holds a hardcoded production ref and writes to prod during a staging run.
  Grep every function + config:
  ```bash
  grep -rn "{{prod_ref}}" supabase/functions/ supabase/config* 2>/dev/null   # hardcoded prod ref
  grep -rn "service_role" supabase/functions/ 2>/dev/null                     # project-level service key use
  ```
  Enumerate every hit. ANY hardcoded prod ref reachable during the staging run = gate **FAIL**
  until parameterised. Sampling one PR is a classic false-pass.

- **Shadow-backtest for live-RPC replacements.** If the change includes a `CREATE OR REPLACE
  FUNCTION` on a LIVE function, run the test-copy before/after backtest on real data FIRST —
  zero risk to the live engine — per `.claude/rules/rpc-replacement-safety.md` (Shadow-Backtest
  on Real Data). A behaviour-changing RPC replacement with no clean shadow-backtest diff = gate **FAIL**.

Any "no" → not safe yet. Name the gap.

## Procedure — make a safe baseline (the prove-before-touch precondition)

A database whose migration history is drifted and partly hand-applied cannot be rebuilt cleanly
from code — so you cannot stand up a throwaway copy to prove a change against. This procedure makes
the history trustworthy: capture the live structure as one baseline, make it replay-safe, reconcile
the bookkeeping, prove a throwaway copy rebuilds healthy. Then every later change is provable.

The recipe is a **system-agnostic PATTERN** (`references/make-safe-baseline.md`) with **per-DB-system
adapters** (`references/db-adapters/<system>.md`). Resolve the adapter first:

```
1. Identify the DB system (Postgres/Supabase, MySQL, Mongo, …).
2. Read references/db-adapters/<system>.md — the STATUS: token.
   - STATUS: wired → proceed with that adapter's concrete tooling.
   - STATUS: stub  → STOP. Tell the operator the system is not wired; do NOT invent a recipe.
                     (A guessed recipe risks a real client DB.)
3. Run the 7-step recipe (references/make-safe-baseline.md). For Postgres/Supabase the brittle
   edits + the freeze-check + the path-rescan are automated:
       scripts/make-safe-baseline-postgres.sh {harden|path-rescan|freeze-check|--self-test}
4. Honour the two hard safeguards (they are STEPS, not advice):
   - Step 0 FREEZE: refuse to baseline while migrations are shipping (stale-on-arrival).
   - Step 5 RESCAN: re-point code/tests that read migration files by path BEFORE archiving.
5. The credentialed snapshot (step 1) and the ledger reconcile (step 6) are production writes →
   explicit operator nod at the moment (plan approval is NOT a blanket prod nod).
6. Completion gate = a throwaway copy rebuilt from the baseline reads HEALTHY (step 7).
```

### Topology-map tie-in (drift signal / gate trigger)

Step 0b reads the DB system's shape from the topology map (the `topology-substrate` family) as the
drift signal that SHOULD trigger this safety gate before a baseline or a prod ship. The agency-repo
topology map is out of a client repo's tree, so this is a **documented integration point with honest
degradation**: if no map is reachable, say so plainly and proceed with the gap stated — NEVER launder
an absent map into an "aligned" green light (per the system-awareness honest-degradation matrix).

## The /autovibe hard staging-first gate

`/autovibe` passes this gate before `/ship` (autovibe SKILL.md §Phase 5.5). This skill owns the
contract; the wiring lives in `references/autovibe-gate-wiring.md`. Summary:

- **Default**: an autonomous run targets the entity's staging surface for execute +
  validation; `/ship` targets staging, not production.
- **Gate pass**: the pre-promotion checklist above is satisfied for the entity.
- **Production-direct override**: requires BOTH an explicit truthy flag
  (`AUTOVIBE_PROD_DIRECT` = `1/true/yes/enabled`; absent or `0/false/no/off/disabled` =
  staging-first) AND an externally-attributed, write-then-read-back-verified logged record.
- **Stub / unresolved entity**: the gate hard-stops (fail-closed). No staging target = no ship.

## Anti-patterns

| Wrong | Why | Right |
|---|---|---|
| Routing a change straight at the production ref because "it's small" | Defeats the separation; staging-first is the *default* | Always staging first; production-direct is the logged exception |
| Inventing a staging target for a stub entity | A guessed target may write to prod | Stop at the stub row; tell the operator it's not wired |
| Advisory-only gate ("warn but proceed") | An autonomous agent on the path of least resistance reaches prod | Hard gate: no prod-direct without flag + verified record |
| Sampling one PR to declare separation proven | The hardcoded-edge-function false-pass | Grep exhaustively for hardcoded prod refs before trusting a pass |
| Estimating rollback time | "Under target" must be observed | Drill it; log wall-clock start/finish |
| Reading stub-vs-wired off prose | A careless edit flips meaning silently | Read the machine `STATUS:` token; anything but `wired` = stub |
| Baselining while a parallel session ships migrations | Stale-on-arrival — bakes drift into the baseline; throwaway copies rebuild a not-quite-prod DB | Step-0 freeze: refuse until the ledger is stable across the window |
| Archiving old migration files, then running the test suite | Path-reading tests break red after the fact | Step-5 rescan + re-point path-readers BEFORE archiving |
| Building a multi-DB adapter abstraction before a client runs on that system | Ships untested, operate-negative steps under a "bulletproof" label | Stub the adapter; wire it when a real client lands on the system |
| Declaring the baseline done after the reconcile | The reconcile is bookkeeping, not proof | Step-7: prove a throwaway copy rebuilds HEALTHY |

## References

- `references/entity-routing.md` — the per-entity registry (stub rows on a fresh template)
- `references/autovibe-gate-wiring.md` — the gate contract + autovibe wiring
- `references/staging-wake.md` — waking an auto-paused Supabase staging project
- `references/make-safe-baseline.md` — the system-agnostic baseline PATTERN (7 steps + the two hard lessons)
- `references/db-adapters/_PATTERN.md` — the adapter contract (what every `<system>.md` must answer)
- `references/db-adapters/postgres-supabase.md` — WIRED Postgres/Supabase recipe + live-fact gotchas
- `references/db-adapters/{mysql,mongo}.md` — STUB adapters (not yet wired; no client on those systems)
- `scripts/make-safe-baseline-postgres.sh` — automates the brittle Postgres edits + step-0/3/5 guards (`--self-test`)
- `autovibe/SKILL.md` §Phase 5.5 — the orchestrator this gate slots into
- the project's dev/prod DESTINATION / policy / staging-promotion runbook (project-specific)
