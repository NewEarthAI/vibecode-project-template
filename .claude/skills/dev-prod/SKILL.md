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
version: 1.0
classification: encoded-preference
created: 2026-06-02
updated: 2026-06-02
validated_on:
  - "Promote a Supabase schema change through staging before production"
  - "Block an autonomous /autovibe run from reaching production without a logged override"
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

Two jobs:

1. **Route + promote + rollback** — given a change for an entity, route it to that entity's
   staging surface first, validate, then promote to production via the project's proven
   recipe, with a rollback path that meets the project's rollback-time target.
2. **Gate autonomy** — the **hard staging-first gate** that `/autovibe` runs through before
   `/ship` (autovibe SKILL.md §Phase 5.5), so an autonomous run cannot reach production
   directly. Production-direct requires an explicit, externally-attributed, verified logged
   override. This is the structural precondition for autonomous (agent-driven) operation.

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

Any "no" → not safe yet. Name the gap.

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

## References

- `references/entity-routing.md` — the per-entity registry (stub rows on a fresh template)
- `references/autovibe-gate-wiring.md` — the gate contract + autovibe wiring
- `references/staging-wake.md` — waking an auto-paused Supabase staging project
- `autovibe/SKILL.md` §Phase 5.5 — the orchestrator this gate slots into
- the project's dev/prod DESTINATION / policy / staging-promotion runbook (project-specific)
