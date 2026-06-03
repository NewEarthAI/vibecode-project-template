# Doctrine Verification Gate — Triple-Layered Quality Mechanism for Doctrine Docs

**Origin**: Codified 2026-05-11 in the Operational Intelligence Synthesis Programme (First Principles Systems Thinker workshop) after Session 1 proved the methodology works.

**Scope**: Any operational doctrine doc authored in `docs/operational-doctrine/*.md` (or equivalent doctrine surface in a client project — e.g., `docs/methodology/*.md`, `docs/playbooks/*.md`). Composes with `code-review-identity.md` (anti-sycophancy) and project-specific programme alignment contracts if present.

**What this rule replaces**: Standard code-review verdict mechanics, which over-rotate on syntax and under-rotate on operational leverage when applied to non-code artefacts (markdown doctrine).

---

## The Triple Gate

A doctrine doc earns PASS status only by clearing all three gates. ADVISORY-pending if any gate is partial. BLOCKING halts merge until revised.

### Gate 1 — Deletion-as-Re-Invention Test

**Question**: Would the content of this doctrine doc need to be re-invented by a downstream session that lacked access to it, in order to produce the same operational guidance?

**Mechanism**: Cite ≥2 specific future sessions, skills, or doctrines that would have to re-derive the content. Cite by name, not by category.

**Why it differs from grep-based deletion testing**: Grep-for-references fails on day-1 artefacts (no consumers exist yet). The re-invention test answers the same question — "would removing this cause complexity to reappear?" — by looking forward at content necessity rather than backward at existing references.

**Verdict thresholds**:
- PASS: ≥2 downstream consumers named, each with specific re-invention work the doctrine prevents
- ADVISORY: 1 consumer named, OR consumers named but re-invention work is marginal
- BLOCKING: no specific consumer can be named — the doctrine has no work to do that another artefact does not already cover

### Gate 2 — Code-Council with Doctrine-Specific Rubric

**Standard `/code-council` is insufficient for markdown doctrine.** Domain-routing has no `.md` doctrine rules; without an explicit rubric, code-council returns rubber-stamp PASS on any well-formatted markdown.

**The doctrine-specific rubric** (replaces standard code-council rubric on doctrine artefacts):

| Axis | What it tests | Weight |
|------|---------------|--------|
| Falsifiability of Claims | Are governing principles paired with conditions under which they produce wrong predictions? | 40 |
| Scope Boundary Completeness | Does the doctrine explicitly name what it does NOT do, with redirects to other doctrines/frameworks? | 15 |
| Anti-Pattern Coverage | Are ≥5 specific anti-patterns paired with detection signals an operator can apply in real time? | 15 |
| Application Checklist Actionability | Can a downstream skill implement the checklist mechanically without re-deriving the procedure? | 15 |
| Triple Gate Conformance | Does the doctrine accommodate the counterfactual requirement + redefined deletion test + scope boundary explicitly? | 15 |

**Scoring thresholds**:
- All axes ≥70: technical PASS (reviewer may still apply judgment to downgrade to ADVISORY if material gaps exist below technical threshold)
- Any axis 50-69: ADVISORY (ships with named gap)
- Any axis <50: BLOCKING (halt, revise, re-run)

**Anti-sycophancy guard**: Reviewer must apply `code-review-identity.md` rule. A doctrine with strong structure but no operational leverage is BLOCKING regardless of axis scores. A doctrine with one weak axis but strong leverage is ADVISORY, not BLOCKING.

### Gate 3 — Real-Decision Test with Counterfactual

**Question**: When applied to a named past decision, does the doctrine produce an intervention recommendation that DIFFERS from what was actually done?

**Mandatory mechanism (per Devil's Advocate / Edge Case Finder convergence on real-decision test self-grading hole)**:

1. **Decision is named BEFORE the doctrine is applied** — ideally nominated by a second party (council agent, peer, prior session). Self-selection by the doctrine author is a sycophancy hole.
2. **Actual outcome is written down BEFORE running the doctrine** — what decision was actually made, what was the result. Lock this in writing.
3. **Doctrine is applied to the decision context** — full procedure run, recommendation produced.
4. **Counterfactual comparison**: does the doctrine's recommendation DIFFER from the actual decision? AND would the doctrine's recommendation have produced a better outcome?

**Verdict thresholds**:
- PASS: doctrine recommendation differs substantively AND credible argument exists that it would have been better (referencing specific cost/capacity/failure-mode evidence, not vague "more systematic thinking")
- STRONG-PASS: same as PASS but with the test case nominated by an independent second party (not the doctrine author)
- ADVISORY-pending: recommendation matches actual decision OR difference is marginal. Doctrine has earned zero leverage for this case. Nominate a second test case before claiming PASS.
- FAIL: recommendation differs but is demonstrably worse than the actual decision — doctrine is not just unhelpful, it is actively misleading.

**Non-trivial insight is defined as**: the doctrine changed what action would have been taken AND the change is justified by specific evidence. Self-grading on "illumination" alone is theatre.

---

## When This Rule Fires

- Any session writing a new doctrine doc in `docs/operational-doctrine/` (or project-equivalent path)
- Any session revising a doctrine doc with material changes to governing principles or application checklist
- Any propagation event involving a doctrine doc (Gate 1 must re-run on the receiving project's context to confirm propagation-worthiness)

---

## What This Rule Is NOT

- **Not for code review** — standard `/code-council` rubric applies to TypeScript / SQL / shell. This rubric is for markdown doctrine artefacts only.
- **Not a one-time gate** — doctrine docs are re-verified at every material revision and at every cross-doctrine consistency check (e.g., when a sibling doctrine is added that overlaps in scope).
- **Not a substitute for cross-doctrine consistency checks** — when two or more doctrines exist, an additional consistency check (do their principles contradict on overlapping cases?) is required before any propagation. This rule covers per-doctrine quality; cross-doctrine consistency is separate.

---

## Failure Modes This Rule Prevents

1. **Sycophantic PASS on well-structured but operationally hollow doctrine** — Gate 2's anti-sycophancy guard requires reviewer to downgrade structural-quality-only doctrines.
2. **Self-grading sycophancy on real-decision test** — Gate 3 mandates pre-written actual-outcome AND ideally second-party case nomination.
3. **Trivial-pass on day-1 deletion test** — Gate 1's re-invention test sidesteps the grep-evidence timing bias.
4. **Doctrine drift into skill spec** — Gate 2 Application Checklist axis catches under-specified checklists that would force skill spec to re-define gates the doctrine should carry.
5. **Industry-standard claims without primary-source citation** — Gate 2 Falsifiability axis catches "we say always do X" claims without falsification conditions OR primary-source backing.

---

## When Line-Count Targets Are Not Yet Hit

A doctrine doc that falls short of the ≥600-line verification baseline has two recovery paths:

1. **Narrative padding** (anti-pattern): expand existing prose to fill space. Produces a longer doc that operators skim and skip. Gate 2 axes do NOT improve from this approach; Anti-Pattern Coverage and Application Checklist Actionability scores often DECREASE because the operational density is diluted.

2. **Operational appendix** (preferred): add an Appendix A with worked examples instantiating the doctrine's frameworks. Each example follows a stable template (system / behaviour pattern / structural diagnosis / default intervention / doctrine-recommended intervention). Line count hits target AND Gate 2 Anti-Pattern Coverage axis improves (each example provides 3-5 detection signals an operator can apply in real time).

The principle: when the gap between current state and target is editorial, prefer addition of operational depth over expansion of existing narrative. The future skill author and the future operator both benefit from worked examples; neither benefits from longer paragraphs.

**Failure precedent (2026-05-11)**: a doctrine ran 544 lines at first complete draft. 56-line gap to the ≥600 baseline closed by adding Appendix A with 8 worked examples. Doctrine landed at 616 lines with operational density increased, not diluted.

---

## Composition with Existing Rules

| Rule | How it composes |
|------|----------------|
| `code-review-identity.md` | Anti-sycophancy directive applies to Gate 2 reviewer; no softening for author effort |
| Project-specific programme alignment contract (if present) | The contract's verification gate clause references this rule |
| `agentic-loop-guards.md` | Pre-exit verification checklist must confirm all 3 gates have a verdict before declaring doctrine "shipped" |
| `pre-completion-pocock-check.md` | Plan-class Question 2 (Pocock-grill applied?) is independent of this gate; both apply on doctrine work |
| `output-chunking.md` | Doctrine docs are always over the inline cap; manifest-first pattern is mandatory |

---

## References

- Origin programme: First Principles Systems Thinker workshop, Operational Intelligence Synthesis Programme Session 1 (2026-05-10)
- Companion rule: `multi-session-programme-contract-template.md` — programme alignment contracts reference this gate
- Companion rule: `diagnostic-skill-anti-anchoring.md` — diagnostic skills operationalising a doctrine inherit this gate's quality bar
