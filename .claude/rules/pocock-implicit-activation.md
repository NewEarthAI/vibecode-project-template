# Pocock Skill Implicit-Activation Rule

**Origin**: 2026-05-02 Spec 22 Pocock skill adoption + 2026-05-03 implicit-activation extension.
**Pairs with**: `.claude/hooks/pocock-implicit-activation.sh` (UserPromptSubmit hook that injects "candidate" hints).
**Pairs with**: `.claude/rules/pre-completion-pocock-check.md` (verification gate before claiming completion).

---

## The principle

**Owning a Pocock skill is not the same as using it when applicable.** Justin should never have to use the exact trigger phrase from a skill's `description` field for the right skill to fire. If the work class matches, the skill should be considered — not waited for.

The `pocock-implicit-activation.sh` hook surfaces a one-line `[pocock-hint] consider: X` message in context when patterns match. This rule defines what to do with that hint.

---

## When this rule fires

Every time a `[pocock-hint] ...` line appears in the conversation context (injected by the UserPromptSubmit hook), or whenever the work class is detected even WITHOUT the hint firing (the regex isn't perfect — judgment supplements it).

---

## The four-step check

When a work-class signal is detected (hint or otherwise):

### 1. Classify the work — what is the user actually trying to do?

| Signal class | Examples | Pocock skill to consider |
|---|---|---|
| **Bug / failure** | "throwing 500", "broken", "why is this failing", "timeout", "perf regression" | `pocock-diagnose` |
| **Plan stress-test** | "stress test", "grill", "challenge this design", "fuzzy", "domain language" | `pocock-grill-with-docs` |
| **Refactor / architecture** | "refactor", "tangled", "extract", "ball of mud", "deepen", "shallow module" | `pocock-improve-codebase-architecture` |
| **Unfamiliar code** | "explain this code", "I don't know this area", "how does this fit" | `pocock-zoom-out` |
| **Test writing** | "write tests", "TDD", "red-green-refactor", "regression test" | `superpowers:test-driven-development` + `tdd-design-companion` rule |
| **Token budget** | "be brief", "less tokens", "compact", "tldr" | `caveman` |

### 2. Decide: invoke, soft-mention, or skip

- **Invoke** — when the work is non-trivial AND the skill clearly applies AND the user hasn't explicitly opted out. Run the skill.
- **Soft-mention** — when the work is small or the skill might be overkill: "I'll keep this simple, but `pocock-diagnose`'s 6-phase loop is available if it gets harder than I expect." Continue with the lightweight path.
- **Skip** — when the user explicitly rules out skills ("just do it"), the work is genuinely trivial (typo fix, comment edit), or applying the skill would obscure the answer (a simple factual question).

### 3. Compose with existing skills, don't replace

Pocock skills live alongside our existing toolkit. Composition order:

| Existing skill | Pocock skill | How they compose |
|---|---|---|
| `superpowers:test-driven-development` | `tdd-design-companion` rule | Discipline (Iron Law) + design (anti-horizontal-slicing, deep modules) |
| `superpowers:systematic-debugging` | `pocock-diagnose` | Both run; superpowers covers principles, Pocock adds 10-technique feedback-loop construction |
| `code-council` / `code-forge` | `pocock-improve-codebase-architecture` | Pocock proposes deepening; council reviews the resulting plan |
| `/challenge` | `pocock-grill-with-docs` | `/challenge` tests one belief; Pocock walks the whole decision tree + writes CONTEXT.md |
| `superpowers:brainstorming` | `pocock-grill-with-docs` | Brainstorm explores; Pocock-grill commits the resolved decisions to docs |

### 4. Note the consideration in the response

When you decide (invoke OR skip), say so plainly so the user can intervene:
- **Invoke**: "This is a bug-class problem — running `pocock-diagnose` Phase 1 to build a feedback loop first."
- **Skip with reason**: "Single-line typo fix — skipping `pocock-diagnose`. Patching directly."

This makes the decision auditable instead of silent.

---

## What this rule is NOT

- **Not auto-invocation**: the hook surfaces hints; this rule says "consider" — Claude still judges.
- **Not a gate**: nothing blocks if Pocock isn't used. The pre-completion check (separate rule) catches missed applicability AFTER the fact.
- **Not for trivia**: typos, single-token rename, comment edits, settings tweaks → no Pocock consideration needed.

---

## Failure precedent (would-have-applied this rule)

- 2026-04-25 — 27-second list-page timeout debugged ad-hoc. Would have been faster + better-documented if `pocock-diagnose` Phase 1 (build the feedback loop FIRST) had been the entry point. The fix was correct but the path to it was undisciplined.
- 2026-04-13 — Spec 14 V1.1 amendments captured 12 fixes via 8-agent council. Could have been front-loaded with `pocock-grill-with-docs` to catch some of the Reframer-class issues earlier — would have shipped a better V1.0.

These are prospective, not retroactive blame — the skills landed 2026-05-02. Going forward, this rule keeps the value flowing.

---

## Composition with token-savers

When `caveman` (or future `jCodeMunch` / `CodeBurn`) is active:
- `[pocock-hint]` line itself is concise — caveman compresses fine
- Pocock skill internal mechanism still runs verbatim — only chat-summary register gets compressed
- Auto-Clarity Exception still fires on destructive-keyword paths

See `.claude/rules/token-savers-composition.md` for the full precedence order.

---

## References

- Hook: `.claude/hooks/pocock-implicit-activation.sh`
- Pre-completion check: `.claude/rules/pre-completion-pocock-check.md`
- Council awareness: `.claude/rules/council-protocol.md` § Tool catalog
- Token-saver composition: `.claude/rules/token-savers-composition.md`
- Spec 22: `specs/22_MATTPOCOCK_SKILLS_ADOPTION.md`
- Council session: `council/sessions/2026-05-02-pocock-skills-adoption-extended-council.md`
