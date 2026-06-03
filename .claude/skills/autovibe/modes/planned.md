---
name: autovibe-mode-planned
description: Planned mode for /autovibe. Triage returned `plan` or `ambiguous` (fail-safe). Full council + amend + execute + code-council + /ship pr.
---

# Autovibe — Planned Mode

**When this mode runs:** triage classified the work as substantive (migration, edge function, n8n, auth, hook/skill change, multi-file diff, refactor) OR ambiguous. Ambiguous escalates here for safety — judgment fails closed toward the heavier ceremony.

## Composition Sequence

The calling Claude session (after `orchestrate.sh` returns 0) executes:

```
1. Read /tmp/autovibe-prime-<pid>.md  ← context briefing
2. (If state.current_step == "forge_needed") Skill prompt-forge → reforged intent
2a. Framing audit — CHECKPOINT 1 (mandatory; `.claude/rules/framing-audit-mandate.md`).
    Audit the INTENT/GOAL before any plan is drafted. Planned mode is load-bearing
    multi-phase work by construction — this checkpoint ALWAYS runs; it is NOT skippable
    here (trivia routes to direct mode, which skips the whole audit).
    - If step 2 ran prompt-forge, the framing audit already ran inside it (prompt-forge
      step 1.1a) — inherit that verdict; do NOT re-run the primitive. Run the primitive
      directly at 2a ONLY when step 2 did not run prompt-forge.
    - Primitive: Skill reduce-to-first-principles (default — intent is a proposal/claim/
      gate), Skill check-commensurability (a comparison underpins the intent), or
      Skill map-feedback-loops (DECISION mode — consequences play out over time).
    - Record the verdict in the autovibe session log (the step-13 pre-completion gate
      confirms it is present).
    - Flagged frame (SMUGGLES_CONCLUSIONS, a rung-1/2 comparison firing the Hands-On
      Calibration Gate, or a frame-criticism classification) → HALT, surface the reframe
      to the user, do NOT proceed to step 3 until the intent is reframed. If the operator
      reviews the reframe and declines it, log the disagreement + their reason and proceed
      under their frame (a stated, recorded gap is allowed; only a silent skip is forbidden).
    - No usable verdict (INSUFFICIENT_INPUT, SCOPE_REFUSAL, errored, or primitive not
      registered) → the audit did NOT run; treat as HALT, not pass — escalate to the
      operator. Never log a clean verdict for an audit that did not complete.
    - Cite the primitive; never copy its procedure. This is the FIRST of autovibe's two
      framing checkpoints — it audits the goal; step 5's Reframer audits the plan.
3. EnterPlanMode (system tool)
3a. (Pocock-grill auto-trigger) IF intent contains laser-precision signals
    OR no CONTEXT.md exists for touched domain OR multi-bounded-context diff:
    Skill pocock-grill-with-docs → grilling sharpens domain language inline,
    optional ADR. NSF-1 review-gate REQUIRED on any CONTEXT.md/docs/adr write
    (user must say "yes write CONTEXT.md" — never auto-write).
    Trigger keywords: "laser precision", "elite", "mission-critical",
    "no regression", "enterprise", "premium", "production-grade".
4. Skill superpowers:writing-plans  → produce plan in ~/.claude/plans/<slug>.md
   IF step 3a ran: plan inherits the grilled domain language verbatim.
5. /council --extended  → writes council/sessions/<date>-<slug>.md
   - Phase 0 reframer first — this IS framing audit CHECKPOINT 2 per
     `.claude/rules/framing-audit-mandate.md`: the Reframer audits the DRAFTED
     PLAN's framing (step 2a audited the goal; the Reframer audits the plan
     built from it). Two checkpoints, not one — step 2a runs before a plan
     exists; the Reframer runs after.
   - 7-agent parallel deliberation
   - Synthesis with Strategic Alignment footer
6. /amend-plan  → applies council verdicts to the plan file
7. ExitPlanMode (system tool — auto-accept the amended plan)
8. /execute  → implements per amended plan
   8a. (improve-arch auto-trigger) IF plan classification == "refactor"
       OR diff-size > 5 files in same module:
       Skill pocock-improve-codebase-architecture → propose deepening
       opportunities BEFORE finalising. User picks one → /execute applies.
   8b. (TDD design companion) IF /execute writes any *.test.* file:
       sub-agent prompt MUST include pointer to
       ~/.claude/rules/tdd-design-companion.md (anti-horizontal-slicing,
       deep modules, interface design for testability) composing with
       superpowers:test-driven-development.
   8c. (pocock-diagnose auto-trigger) IF /execute encounters test failure,
       runtime error, silent failure, or perf regression:
       Skill pocock-diagnose → 6-phase loop (build feedback loop FIRST,
       3-5 ranked falsifiable hypotheses, tagged debug logs [DEBUG-a4f2],
       regression test). NOT a blind retry — explicit dispatch.
9. /code-council  → multi-lens review of diff before push
   - If verdict == BLOCKING → halt, surface, exit 3
   - If verdict == ADVISORY → continue with surfaced advisories
   - If verdict == PASS → continue
10. Skill ship (mode=pr) → composes /verify-pipeline, /e2e-quick, /ship pr
    - --format=json --caller=autovibe
    - On exit 0 → continue
    - On exit 1–6 → halt, surface remediation, exit with same code
    - On exit 9 (UNVERIFIABLE) → halt, surface, exit 9
11. Read .claude/ship-state.json — capture pr_number, merged_sha, completed_at
12. Run post-push doc step (see SKILL.md §Post-Push)
13. state.sh write phase "complete"
14. state.sh write exit_code "0"
15. state.sh release (also fires via trap)
```

## Crash-Resume Semantics

If a crash interrupts execution mid-flow, the next `/autovibe` invocation:
1. `state.sh inspect` shows phase + current_step
2. If phase == "compose_planned_pending", resume from step where current_step left off
3. If state file missing or unparseable → halt with exit 6, surface diagnostic

Resume points:
- `current_step == "forge_needed"` → restart at step 2
- `current_step == "plan_in_progress"` → restart at step 3 (re-enter plan mode)
- `current_step == "council_pending"` → restart at step 5
- `current_step == "execute_pending"` → restart at step 8
- `current_step == "ship_pending"` → restart at step 10

Step 2a (framing audit, checkpoint 1) has no `current_step` value of its own — it is
idempotent and cheap to re-run. On ANY resume that lands at step 2 OR step 3, re-run step 2a
before proceeding. Re-running a framing audit is safe; silently skipping it on resume is a
contract violation per `.claude/rules/framing-audit-mandate.md`.

## Failure Modes

| Step | Symptom | Action |
|---|---|---|
| Council | Reframer suggests reframe | Surface to user; pause for approval before proceeding |
| Amend | No actionable amendments | Continue with original plan + advisory note |
| Execute | Compilation/test failure | Halt; let user decide retry vs abort; exit 3 |
| Code-Council | BLOCKING verdict | Halt; surface findings; exit 3 |
| Ship pr | CI fail (exit 2) | Halt; surface CI diagnostic; exit 4 |
| Ship pr | Smoke fail (exit 4) | /ship triggered auto-rollback automatically; surface; exit 4 |
| Ship pr | UNVERIFIABLE smoke (exit 9) | Do NOT rollback (no header confirmation); surface; exit 9 |

## What This Mode NEVER Does

- ❌ Invoke `/ship hotfix` — under any circumstance, autovibe never auto-invokes hotfix; if hotfix conditions detected mid-flow, halt with exit 9 and recommend human takeover
- ❌ Skip code-council on the grounds that "council already reviewed the plan" — council reviews the plan, code-council reviews the diff
- ❌ Auto-merge if branch protection fires for genuinely unrelated reasons unless `/ship` itself does so via the admin-merge heuristic

## Pocock skill composition — quick reference

| Phase | Skill / Rule | Auto-trigger | Skip-when | Composes with |
|---|---|---|---|---|
| 3a (pre-plan) | `pocock-grill-with-docs` | Laser-precision signal OR no CONTEXT.md OR multi-bounded-context | Single-file plan, well-defined domain (CONTEXT.md exists + recently updated), trivial-classification diff | `superpowers:writing-plans` consumes grilled output |
| 8a (mid-execute) | `pocock-improve-codebase-architecture` | Refactor classification OR ≥5-file same-module diff | Plan explicitly classifies as "feature" without architectural impact, OR Phase 3a grill already covered structure | Output feeds back into /execute step |
| 8b (test writing) | `tdd-design-companion` rule (NOT skill) | /execute writes any `*.test.*` file | Existing test file edited by ≤3 lines (regression test added to existing suite) | `superpowers:test-driven-development` |
| 8c (error recovery) | `pocock-diagnose` | Test fail / runtime err / perf regression on FIRST attempt | Same error pattern recurs from previous /execute pass (loop detection — escalate to user instead) | Replaces blind retry |
| Status output | `caveman` (passive) | `AUTOVIBE_FORMAT=json` already implies terseness | Destructive-keyword path active (Auto-Clarity Exception fires regardless) | Auto-Clarity destructive-keyword carve-out preserves safety |

**Composition rule**: Pocock skills do NOT replace any autovibe step. They run INSIDE the named step as sub-skill invocations. The autovibe state machine is unaffected. Crash-resume semantics inherit from the parent step.

**Anti-overfire discipline (per user instruction 2026-05-03)**: each phase's auto-trigger MUST be checked against its skip-when clause before invocation. If skip-when matches, log the consideration as a one-line note ("Phase 3a evaluated, skipped — well-defined domain") but do NOT invoke the skill. This prevents over-application of Pocock ceremony to trivial work while keeping audit visibility.

**Implicit-activation pairing**: the `.claude/hooks/pocock-implicit-activation.sh` UserPromptSubmit hook fires BEFORE autovibe state machine runs. If the hook surfaced a `[pocock-hint]` for the user's intent, autovibe's Phase 3a check inherits the signal — meaning the trigger threshold lowers (treat as if laser-precision signaled). This closes the gap between user-not-knowing-the-trigger and Pocock-not-firing.

**Pre-completion gate**: before `state.sh write phase "complete"` (step 13), run the `.claude/rules/pre-completion-pocock-check.md` checklist on the work just completed, AND confirm the step-2a framing-audit verdict (checkpoint 1) is recorded in the session log. If gaps surface — including a missing framing-audit verdict on a planned-mode run — surface them in the post-push doc step output (step 12) with ADVISORY classification.

## Reference

- Plan-writing: `superpowers:writing-plans` skill
- Plan-grilling (3a): `pocock-grill-with-docs` skill (Spec 22 adopted 2026-05-02)
- Council contract: `.claude/rules/council-protocol.md`
- Architecture lens (8a): `pocock-improve-codebase-architecture` skill
- TDD design companion (8b): `.claude/rules/tdd-design-companion.md`
- Diagnosis (8c): `pocock-diagnose` skill
- Code-council: `.claude/commands/code-council.md`
- Ship contract: `.claude/skills/ship/SKILL.md`
- Failure inventory: `.claude/skills/ship/references/failure-inventory.md`
