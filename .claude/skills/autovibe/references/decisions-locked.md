# Locked Design Decisions — Snapshot

Mirrors `specs/autovibe-design-decisions-2026-04-19.md`. This file lives in the skill so that anyone reading the skill in isolation knows which choices it embodies.

## D1 — Form factor: Layered

`/autovibe` command + `.claude/skills/autovibe/` skill that composes existing skills/commands. Hookify rule (`auto-council-on-plan.local.md`) NOT installed. Compose-don't-rebuild enforced via Phase 5 negative checks.

**Why**: Preserves separation of concerns. /ship doesn't know about autovibe. Each composed skill is independently testable. Minimal new surface area.

## D2 — Plan-mode trigger list

**Mandatory plan** (encoded in `scripts/triage.sh` case blocks):
- Intent keywords: migration, edge function, n8n, hook, auth, refactor, redesign, src/integrations, batchdata, rentcast, v_seller_pipeline, dd_property_enriched
- Diff patterns:
  - `supabase/{migrations,functions}/**` or `*.sql`
  - `.claude/{hooks,skills,agents}/**` or `council/**`
  - `src/integrations/**`
  - Auth flow: `src/pages/Auth*`, `auth.tsx`, hooks matching `useAuth*`
  - n8n workflow JSON (file is `*.json` AND contains `"nodes":` key)
  - >2 files OR >200 lines changed

**Never plan** (encoded in `scripts/triage.sh`):
- Intent: typo, comment, console.log
- Diff: single .md file with ≤5 lines changed
- Intent: roadmap reorder + .md-only diff

**Judgment** (everything else): falls through to ambiguous → orchestrator escalates to planned mode for safety (fail-closed).

## D3 — Ship-mode mapping

| Triage outcome | Ship mode |
|---|---|
| `direct` | `/ship quick` |
| `plan` | `/ship pr` |
| `ambiguous` | `/ship pr` (fail-closed escalation) |
| **(any)** | **`/ship hotfix` NEVER auto-invoked** — exit 9 |

**Hotfix refusal rationale**: `/ship hotfix` performs auto-rollback WITHOUT confirmation on smoke failure. Safe when human typed `/ship hotfix` (explicit authorization). Unsafe when autovibe decided to escalate. Hotfix requires explicit human invocation.

## D4 — Forge gate

**REVISED 2026-04-19 (during Phase 3 build, formalized post-code-council)**:

Original spec (continuation §4.D4): `<20 words OR lacks verb/object pair` — produced forge-needed on almost every invocation during DRYRUN testing.

**Revised** (encoded in `scripts/orchestrate.sh:99-110`): forge needed when intent is:
- Less than **4 words** (severely brief), OR
- Less than **8 words AND** lacks a verb/object pair

Verb/object pair regex (also revised from spec — broadened):
`(add|fix|build|create|update|deploy|implement|wire|refactor|remove|enable|disable|tweak|change|rename|migrate).*(in|to|from|for|on|at)`

**Why revised**: original `<20 OR no verb` heuristic fired on virtually every short intent (most autovibe invocations are <20 words). The result was a constant "would invoke /prompt-forge" message that was both noisy and wasteful — most short intents are clear (e.g., "fix typo in README" — 4 words, but unambiguous).

**Caveat from code-council 2026-04-19**: regex requires verb+preposition pair, not strictly verb+object. Intents like "fix buyer dashboard" (verb + object, no preposition) currently classify as no-verb-object. This is acceptable because such intents are nearly always still long enough (≥8 words once spelled out) OR truly need forging for clarity. If false positives multiply, broaden the regex to detect verb+noun patterns.

**Update history**:
- 2026-04-19: original spec drafted in continuation
- 2026-04-19: revised during Phase 3 build (DRYRUN feedback)
- 2026-04-19: drift formalized post-code-council

## D5 — Crash recovery

State file: `.claude/autovibe-state.json`
Lock primitive: atomic `mkdir .claude/autovibe-state.lock/`
TTL: 30 minutes
Future-tolerance: 60 minutes
Trap: `state.sh release` on INT/TERM/EXIT

Resume points (see `modes/planned.md` §Crash-Resume):
- forge_needed → restart at forge step
- plan_in_progress → re-enter plan mode
- council_pending → restart at /council
- execute_pending → restart at /execute
- ship_pending → restart at /ship

## Hookify

`auto-council-on-plan.local.md` rule from template repo: **uninstalled**. /autovibe is the explicit trigger. Manual ExitPlanMode does NOT auto-fire council. One trigger, one path. Cleaner mental model.

## How to revise

1. Edit `specs/autovibe-design-decisions-2026-04-19.md` — change `APPROVED-DEFAULT` → `REVISED: <new value>`
2. If revising D2: edit `scripts/triage.sh` `case` blocks + re-run Phase 5 evals
3. If revising D5 schema: edit `scripts/state.sh` + write a state-file migration
4. Update this snapshot to match
