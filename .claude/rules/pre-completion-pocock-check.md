# Pre-Completion Pocock Check

**Origin**: 2026-05-03 — extends `.claude/rules/agentic-loop-guards.md` § Pre-Exit Verification Checklist with a Pocock-applicability gate.
**Pairs with**: `pocock-implicit-activation.md` (the hint surfacing layer), `pocock-implicit-activation.sh` (the hook).

---

## The principle

**Never claim work is "complete" / "fixed" / "done" without verifying that no Pocock-class skill could have produced a higher-standard outcome.** This is the symmetric pair of implicit-activation: the hook + rule make sure Pocock IS considered up-front; this rule makes sure missed applicability is caught at the exit gate.

The bar is high but bounded: applies ONLY to Pocock-class work (bug fixing, plan authoring, refactor, test writing, architecture review). Trivia is exempt.

---

## When to run this check

Before saying any of:
- "Fixed."
- "Bug resolved."
- "Couldn't reproduce / no fix needed."
- "Implementation complete."
- "Plan ready."
- "Refactor done."
- "Tests written."
- "Architecture decided."

OR before any of these completion-class actions:
- Marking a TodoWrite item as `completed`
- Committing with a "fix:" / "feat:" / "refactor:" prefix
- Closing a Spec section or sprint phase
- Writing a continuation file marked "shipped"

---

## The 6-question pre-completion checklist

Apply ONLY if work-class is Pocock-applicable. Skip for trivia.

### 1. Bug-class work — was `pocock-diagnose` applied?

If the work was a bug fix or perf regression:

- [ ] Did Phase 1 (build a feedback loop FIRST) actually happen, or did we skip to "edit the code"?
- [ ] Were 3-5 ranked falsifiable hypotheses generated before instrumenting?
- [ ] Were debug logs tagged `[DEBUG-XXXX]` for clean removal? (If logs were added.)
- [ ] Phase 5 — was a regression test written + watched fail before the fix? (Or absence of seam documented?)
- [ ] Phase 6 — original repro re-verified as no longer reproducing?

Failing any of these without a stated reason → completion claim is **ADVISORY** not **PASS**. State the gap before claiming "fixed."

### 2. Plan-class work — was `pocock-grill-with-docs` applied where applicable?

If the work produced a plan, spec, or PRD:

- [ ] Was domain language sharpened, or did the plan use fuzzy terms ("system", "service", "thing")?
- [ ] If a `CONTEXT.md` exists for the touched area, was it consulted?
- [ ] If a load-bearing trade-off was made, was an ADR offered (3-condition test: hard-to-reverse + surprising-without-context + real-trade-off)?
- [ ] NSF-1 review-gate — every CONTEXT.md / docs/adr write must have been preceded by an explicit "yes write CONTEXT.md" confirmation. NEVER auto-write.

Failing any of these → state the gap. The plan may still ship but the "ready" claim downgrades to "ready-with-gaps."

### 3. Refactor-class work — was `pocock-improve-codebase-architecture` applied?

If the work refactored or restructured code:

- [ ] Was the deletion test applied to anything labelled "shallow"? (If deleted, does complexity vanish or concentrate?)
- [ ] Was the deepening framed in the project's domain glossary (CONTEXT.md vocabulary)?
- [ ] One adapter = hypothetical seam, two adapters = real seam — was that distinction respected?

### 4. Test-writing — was `tdd-design-companion` rule consulted alongside `superpowers:test-driven-development`?

If `*.test.*` files were written:

- [ ] One test → one implementation → repeat (vertical slice), NOT all-tests-first then all-implementation?
- [ ] Module designed for testability (accept dependencies, return results not side effects, small surface)?
- [ ] Tests verify behaviour through public interface, not implementation details?

### 5. Token-budget contexts — was `caveman` Auto-Clarity Exception preserved?

If `caveman` was active during destructive-keyword work:

- [ ] Did the destructive-action confirmation (DELETE / DROP / deploy production / etc.) preserve full warning + rollback path + unambiguous confirmation phrase?
- [ ] Was caveman correctly resumed AFTER the destructive section?

### 6. Cross-cutting — did the council see the right tools?

If a `/council` or `/code-council` session ran during this work:

- [ ] Was the council prompt + protocol aware of the Pocock skills as available tools? (See `.claude/rules/council-protocol.md` § Tool catalog.)
- [ ] Did council agents recommend Pocock skill invocations where applicable? (If they did, was the recommendation acted on?)

---

## How to fail gracefully

When this checklist surfaces a gap, the response is NOT to retro-apply the skill before declaring done. Instead:

1. **Name the gap explicitly** in the completion message. Example: "Bug fix shipped, but `pocock-diagnose` Phase 5 regression test was skipped because no good seam exists in the current architecture. Hand-off note: when `pocock-improve-codebase-architecture` is next applied to this area, the seam should be revisited."
2. **Downgrade the claim** from PASS → ADVISORY. The work shipped; the standard wasn't fully met.
3. **Log to the relevant session/handoff file** so the next chat sees the gap.

This is symmetric with `agentic-loop-guards.md` — claim with evidence; if evidence is partial, claim with named partial.

---

## What this rule is NOT

- **Not a blocker** — work can ship with stated gaps; only silent gaps are forbidden.
- **Not for trivia** — typo fix, single-line ROADMAP edit, settings tweak → no checklist required.
- **Not retroactive** — does not require revisiting work shipped before this rule landed (2026-05-03).
- **Not exhaustive** — Pocock skills are tools, not the universe of quality. Other rules (`agentic-loop-guards`, `typecheck-and-review-gates`, `loading-state-invariants`) still apply with their own gates.

---

## Composition with `agentic-loop-guards.md`

`agentic-loop-guards.md` § Pre-Exit Verification Checklist already requires:
- Verification artifact (test output, query result, file diff)
- No silent failures
- Parallel-session drift check

This rule **adds** the Pocock-applicability dimension. Both checklists should pass before claiming completion. If `agentic-loop-guards` passes but Pocock-check surfaces gaps, surface the gaps; don't claim done.

---

## References

- `.claude/rules/agentic-loop-guards.md` — base verification protocol
- `.claude/rules/pocock-implicit-activation.md` — up-front activation discipline
- `.claude/hooks/pocock-implicit-activation.sh` — hint hook
- `specs/22_MATTPOCOCK_SKILLS_ADOPTION.md` — Pocock adoption rationale
- `council/sessions/2026-05-02-pocock-skills-adoption-extended-council.md` — 12 amendments
