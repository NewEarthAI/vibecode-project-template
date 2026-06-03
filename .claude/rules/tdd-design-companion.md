# TDD Design Companion (Pocock distinctives, captured as a rule, not a skill)

**Origin**: 2026-05-02 council (Cap Scout A5 + Edge Case Finder #8 amendments). Plan v3 of `specs/22_MATTPOCOCK_SKILLS_ADOPTION.md` rejected dual-install of `pocock-tdd` because it overlaps `superpowers:test-driven-development` at the use-case-trigger level (~80% trigger overlap). The substantive distinctives — anti-horizontal-slicing, deep modules, interface-design-for-testability — are captured here as a discoverable rule.

**Source**: github.com/mattpocock/skills commit b843cb5 — Copyright Matt Pocock 2026, MIT License.

**Composition**: applies WHEN `superpowers:test-driven-development` is invoked OR when implementing any feature/bugfix that requires writing tests.

---

## 1. Anti-horizontal-slicing rule

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" — treating RED as "write all tests" and GREEN as "write all code."

This produces crap tests:
- Tests written in bulk test *imagined* behaviour, not *actual* behaviour
- You end up testing the *shape* of things (data structures, function signatures) rather than user-facing behaviour
- Tests become insensitive to real changes — they pass when behaviour breaks, fail when behaviour is fine
- You outrun your headlights, committing to test structure before understanding the implementation

**Correct approach**: Vertical slices via tracer bullets. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
```

**Composes with**: `superpowers:test-driven-development` Iron Law (no production code without failing test first). Anti-horizontal-slicing is the discipline ABOVE the Iron Law — it tells you not just to write the test first but to write *only one* test before the next implementation.

---

## 2. Deep modules

From Ousterhout's *A Philosophy of Software Design*:

**Deep module** = small interface + lots of implementation.
**Shallow module** = large interface + little implementation (avoid).

When designing the interface for the code you're about to TDD:
- Can I reduce the number of methods?
- Can I simplify the parameters?
- Can I hide more complexity inside?

**Why this matters during TDD**: a deep module is testable through a small surface. A shallow module spreads behaviour across many entry points; tests proliferate to match. Deep modules → fewer, more meaningful tests.

**Deletion test**: imagine deleting the module. If complexity vanishes (no behaviour was hidden inside), it was a pass-through — shallow. If complexity reappears across N callers (real behaviour was hidden), it was earning its keep — deep.

---

## 3. Interface design for testability

Three rules:

### 3.1 Accept dependencies, don't create them

```typescript
// Testable
function processOrder(order, paymentGateway) {}

// Hard to test
function processOrder(order) {
  const gateway = new StripeGateway();
}
```

Dependency injection makes the seam visible. Without it, you have to mock-patch the import system to swap the dependency in tests — fragile and slow.

### 3.2 Return results, don't produce side effects

```typescript
// Testable
function calculateDiscount(cart): Discount {}

// Hard to test
function applyDiscount(cart): void {
  cart.total -= discount;
}
```

Pure functions are testable through one assertion. Side-effecting functions require setup, action, and inspection — three places for the test to drift from the real behaviour.

### 3.3 Small surface area

- Fewer methods = fewer tests needed
- Fewer parameters = simpler test setup
- One way to do one thing = no decision-tree of "did the test cover the right path"

---

## 4. When to consult this rule

- BEFORE invoking `superpowers:test-driven-development` for a new feature: read this rule. The Iron Law tells you to write the test first. This rule tells you what shape that test (and its target module) should be.
- AFTER `pocock-diagnose` Phase 6 surfaces "no good test seam exists": this rule names what a deep, testable module looks like. Hand off to `pocock-improve-codebase-architecture` if a redesign is needed.
- BEFORE writing all-tests-first because "I want to plan the suite": this rule says STOP. One test, one implementation, learn, next test.

---

## 5. Anti-pattern catch-list

- Wrote 5 tests, all passing immediately on first run → tests are testing imagined behaviour. Delete and redo with anti-horizontal-slicing.
- Module has 12 methods + 8 inner classes → likely shallow. Apply deletion test.
- Function uses `new Foo()` inside its body → not injectable. Refactor to accept a Foo as parameter.
- Function returns `void` and mutates an argument → side-effecting, hard to test. Refactor to return a result.
- Test setup is 50 lines, action is 1 line → setup is doing the testing's work. Extract helpers OR simplify the interface.

---

## References

- Pocock skill (rejected for dual-install, kept as source): `/tmp/mattpocock-skills-audit/skills/engineering/tdd/` (deep-modules.md, interface-design.md, mocking.md, tests.md, refactoring.md)
- Anthropic plugin skill: `superpowers:test-driven-development` (Iron Law, RED-GREEN-REFACTOR, anti-rationalization)
- Council adoption: `council/sessions/2026-05-02-pocock-skills-adoption-extended-council.md` amendment A5 + A7 + Edge Case Finder #8
- Ousterhout, *A Philosophy of Software Design* (2018) — deep modules + interface design source material
