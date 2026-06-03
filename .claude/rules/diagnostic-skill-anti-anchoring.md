# Diagnostic Skill Anti-Anchoring — Pattern for Skills That Take User-Supplied Hypotheses

**Origin**: Codified 2026-05-11 from Session 1 of the Operational Intelligence Synthesis Programme. Embedded in `specs/03_DIAGNOSE_BOTTLENECK_SKILL.md` Section 6; generalised here for reuse across all diagnostic skills.

**Scope**: Any skill whose purpose includes diagnosis, classification, or identification where the user can supply a candidate hypothesis. Examples: `/diagnose-bottleneck` (user proposes a bottleneck), future `/identify-leverage-point` (user proposes a leverage point), future `/locate-feedback-loop` (user proposes a loop driver), future `/classify-decision-type` (user proposes a decision class).

**What this rule prevents**: The skill becoming a hypothesis-confirmation machine. Without explicit anti-anchoring guards, diagnostic skills that accept user-supplied hypotheses produce confident wrong answers — they pattern-match on the framing and produce analyses that validate the pre-selected hypothesis.

---

## The Failure Mode

Operators bring biased framings to diagnostic questions. The "obvious" bottleneck (or leverage point, or decision class) is the one that frustrates them most, which is not necessarily the binding/highest-leverage/correct one. A diagnostic skill that accepts the user's framing at face value:

1. Loses the leverage it was designed to provide — the operator already has the framing
2. Produces a structurally correct analysis that confirms the wrong target
3. Costs the operator the cost of intervening at the wrong stage (often expensive)
4. Erodes trust in the skill once the misdirection becomes apparent

This is the most common silent-failure class for diagnostic skills. The skill returns "PASS" / "diagnosis complete" / "constraint identified" while having been steered by the operator's anchor the entire time.

---

## The Required Pattern

Every diagnostic skill spec MUST include the following four components.

### Component 1 — Minimum Viable Input (MVI) Thresholds

The skill defines explicit MVI thresholds and refuses to proceed when not met. MVI is NOT operator preference — it is the threshold below which the skill produces hallucinated output.

**Required MVI elements**:
- Named target system / entity / scope (not "our process", but specifically "customer onboarding from form-submission through contract-signed")
- At least one observable, measurable signal per dimension being diagnosed (throughput / leverage estimate / loop driver / decision class)
- Confirmation that the input is in-scope for the skill (e.g., for TOC: internal flow-based constraint, not external market constraint)

**Below-MVI handling**: structured insufficient-input error with an example input template. NEVER proceed to a diagnosis on below-MVI input.

### Component 2 — Anti-Anchoring Guard (Mandatory Independent Location)

When the operator has named a candidate hypothesis, the skill MUST:

1. **Hypothesis provenance check first** (mandatory MVI element): record `hypothesis_provenance` with one of four values:
   - `operator` — hypothesis formed by the operator from their own intuition or analysis
   - `prior_skill` — hypothesis is the output of another diagnostic skill in this same chain (e.g., `/decide-under-uncertainty` invoked with `/diagnose-bottleneck` output as input)
   - `session_history` — hypothesis was discussed earlier in the same Claude Code session by Claude (not the operator)
   - `generative_primitive` — input is the output of a *generative* workshop skill (e.g. the destination-authoring skill produced a destination now being audited). The output IS the operator's expressed intent in structured form, not a competing diagnostic hypothesis. Added 2026-05-18.
2. **Branch logic by provenance** (this is what closes the silent-chain-break failure mode):
   - `operator` → standard guard: independent location + 3-class compare (steps 3-5 below)
   - `prior_skill` → **validate-upstream mode**: rerun the upstream diagnostic with different parameters (e.g., different MVI input, alternative scope frame) and check whether the upstream output is stable across re-runs. If stable → proceed to standard guard treating the stabilised output as the hypothesis. If unstable → BLOCK with "upstream skill output unstable; cannot validate downstream against unstable hypothesis." NEVER apply standard compare when provenance is `prior_skill` — that produces false-agreement (both sides AI-generated) or false-disagreement (skill disagreeing with itself across layers).
   - `session_history` → flag for one-question operator confirmation before applying standard guard: "Is this your hypothesis, or did Claude propose it earlier? Hypothesis source affects how the anti-anchoring guard operates."
   - `generative_primitive` → **bounded-tag standard guard** (Branch D): the input MUST carry `generated_at` (ISO date) and `project_root`; verify both — current project AND within the staleness window (default 21 days). If both pass → run the standard guard (independent location + 3-class compare; the input is NOT rubber-stamped — `Disagreed` is still reachable). If cross-project or stale → downgrade provenance to `operator` and run the standard guard, recording the downgrade reason. NEVER run validate-upstream for `generative_primitive` — a generative skill's non-determinism makes the stability check meaningless. Only the originating generative skill writes this tag; it must never be set manually.
3. **Independent location**: locate the target from observed data WITHOUT referencing the operator's named hypothesis. Apply the doctrine's identification procedure mechanically.
4. **Compare**: independent location result vs. operator's named hypothesis.
5. **Verdict in three classes**:
   - **Agreed**: hypothesis matches independent location → proceed with full analysis. Log "anti-anchoring verified" in output (the agreement is meaningful because it survived independent verification, not because the skill accepted the framing).
   - **Disagreed**: independent location identifies a different target → present BOTH the operator's claim and the independent location. Do NOT pick one silently. Ask the operator to choose OR run both analyses in parallel.
   - **Inconclusive**: observed data is uninformative — does not support either claim. Flag as insufficient-input even if MVI was met (numbers exist but lack discriminating power).

The guard is **mandatory**, not "best practice". Skill output structure must include:
- `anti_anchoring.hypothesis_provenance` field with one of the four provenance values
- `anti_anchoring.verdict` field with one of the three verdict values (or `validate_upstream_{stable | unstable}` when provenance is `prior_skill`; Branch D `generative_primitive` produces a standard three-class verdict)

### Component 3 — Counterfactual Statement (Mandatory in Output)

Every skill recommendation MUST include a counterfactual statement comparing the skill's recommendation to the operator's default action.

**Required structure**:
- `default_action`: what the operator would have done without invoking the skill (one sentence)
- `skill_recommendation`: what the skill recommends (one sentence summary)
- `difference`: one of `none` | `marginal` | `substantial` | `transformative`
- `skill_leverage`: 1-3 sentences justifying the difference value with specific evidence (cost, time, capacity, failure-mode-avoided)

**The counterfactual gate**: if `difference` is `none` or `marginal`, the skill self-flags ADVISORY-pending. The skill has earned zero leverage for this case. Operator nominates a different test case or refines the input.

### Component 4 — Falsifiability Marker on High-Confidence Output

For any HIGH-confidence verdict the skill returns, output MUST include a "what would falsify this?" field naming the specific evidence that would invalidate the recommendation. Examples:
- "Falsified by: any non-constraint stage running >90% utilisation after constraint exploitation"
- "Falsified by: target loop showing dampening behaviour within 4 weeks rather than amplification"

Skills that return HIGH confidence without a falsification marker are downgraded to MEDIUM until the marker is added.

---

## Required Test Cases (Before Any Diagnostic Skill Ships)

A diagnostic skill cannot enter `.claude/skills/` until these test cases all return correct behaviour:

| Test | Input | Required behaviour |
|------|-------|--------------------|
| Happy path | Well-formed input with named target + metrics | Skill produces full output with all four components populated |
| Adversarial anchored | Operator names a hypothesis that disagrees with observed data | Anti-anchoring guard fires; both options presented; no silent acceptance |
| Vague input | Description without named target | MVI insufficient-input error with example template |
| Empty input | Skill invoked with no scope | Structured error requesting input; no hallucination |
| Out-of-scope | Input describes a problem outside the skill's jurisdiction | Skill refuses jurisdiction; redirects to appropriate doctrine / framework |
| Same-as-default counterfactual | Skill recommendation matches operator's default action | Skill self-flags ADVISORY-pending; does NOT return PASS |
| Non-author-domain test | Input from a domain different from where the skill was designed | Skill produces analysis without domain-specific assumptions; vocabulary stays generic |
| Cross-skill chain test | Skill invoked with the output of another diagnostic skill (e.g., `/decide-under-uncertainty` with `/diagnose-bottleneck` output as input) | `hypothesis_provenance: prior_skill` branch fires; validate-upstream mode runs; verdict is `validate_upstream_{stable\|unstable}`, NOT standard agree/disagree/inconclusive. Closes the silent-chain-break failure surfaced by Edge Case Finder 2026-05-12. |

---

## Mechanical-Runnability Self-Check

A diagnostic skill's procedure is meant to be **mechanically runnable** — a downstream Claude follows it verbatim and reaches a defensible verdict with no re-derivation. Two specific authoring failures break that property even when the procedure looks complete. Run this self-check before a diagnostic skill ships; both checks are spec-time/authoring-time, not runtime.

### Check 1 — An example is not an algorithm

A procedure step that says "the canonical case is X" has given an *illustration*, not a *procedure*. A downstream Claude meeting a non-canonical case has no rule to apply and falls back to default (impressionistic) behaviour — the exact failure the step was meant to prevent.

- **Fix**: name the **general test first** — the mechanically-checkable rule — THEN give the worked example as illustration of that rule, explicitly labelled "example, not the only case".
- **Detection signal at code-review**: a step whose only content is one worked scenario, with no stated general criterion. If a reviewer must infer the rule from the example, the step is under-specified.
- **Failure precedent (2026-05-18, Primitive 5 `/audit-artefact-grounding`)**: the composition-contradiction detection step was written as "the canonical case is axis-2 vs axis-4". Three independent code-council reviewers converged on it being an example, not an algorithm. Fixed by stating the general contradiction test (one primitive asserts property P; another asserts P's structural foundation is invalid) with the canonical pair demoted to an illustration.

### Check 2 — Every halt point needs a defined output envelope

A procedure with multiple halt/exit points must define the **full output envelope for every one of them** — not just the obvious early halts. Late halt points (after the main analysis has run) are the ones most often missed: the author writes the "what to emit when we stop early" discipline thinking of input-validation failures, and misses the halts that occur deep in the procedure.

- **Fix**: enumerate ALL halt points in one place (a table is good), each with its complete envelope — top-level verdict value, every mandatory field, and the disposition of any analysis result produced before the halt (preserved? discarded? where?).
- **Detection signal at code-review**: a "halt-path discipline" section that names only the pre-analysis halts. Trace every `halt` / `BLOCK` / `exit` in the procedure body and confirm each appears in the discipline section.
- **Failure precedent (2026-05-18, Primitive 5)**: the halt-path discipline covered only the two pre-rubric halts; the two post-rubric halts (a validate-upstream block, a provenance-ambiguity terminal guard) had no defined envelope — a real exit path could emit output missing its mandatory verdict field. Caught as 2 separate CRITICAL findings; fixed by rewriting the discipline as a 4-row table covering every halt.

---

## Composition with Other Rules

| Rule | How it composes |
|------|-----------------|
| `doctrine-verification-gate.md` | A diagnostic skill operationalises a doctrine; the doctrine's verification gates set quality bar; this rule sets the skill-design pattern that meets the bar |
| `code-review-identity.md` | Anti-sycophancy directive applies to anti-anchoring verdict — reviewer must call out skills that fail to disagree with operators |
| `skill-creator` (existing skill) | This rule extends skill-creator with the anti-anchoring pattern as a mandatory section for diagnostic-class skills |
| `pocock-grill-with-docs` | Apply at skill-spec authoring time; stress-tests whether the anti-anchoring guard is genuine or decorative |

---

## What This Rule Is NOT

- **Not for non-diagnostic skills** — generation skills, transformation skills, search skills don't typically take user hypotheses. The pattern is specifically for diagnose / identify / classify / locate skills.
- **Not a substitute for skill-creator conventions** — frontmatter, description quality, file structure conventions still apply. This rule is an additional section requirement for diagnostic-class skills.
- **Not gateable at runtime** — these are spec-time and authoring-time requirements. A skill that ships without these components is incomplete; a skill that ships with them but ignores them at runtime is broken.

---

## Failure Mode History

This pattern was extracted from the `/diagnose-bottleneck` skill spec authored in Session 1 of the Operational Intelligence Synthesis Programme. The Edge Case Finder agent in `council/sessions/2026-05-10-synthesis-programme-launchpad.md` Section "Edge Case Finder — Skill Spec Failure Inputs" identified the failure mode explicitly:

> "The skill, without explicit anti-adversarial guards, will pattern-match on the framing and produce a TOC analysis that validates the pre-selected bottleneck. This is not a failure in TOC — it's a failure in how the skill handles anchoring bias."

Without codification at the rule level, every future diagnostic skill author would re-derive this pattern (or skip it, becoming a hypothesis-confirmation machine). This rule prevents the recurrence.

---

## References

- Origin: `specs/03_DIAGNOSE_BOTTLENECK_SKILL.md` Section 6 (the per-skill instantiation that this rule generalises)
- Origin council: `council/sessions/2026-05-10-synthesis-programme-launchpad.md` Edge Case Finder findings
- Companion rule: `.claude/rules/doctrine-verification-gate.md` (the verification mechanism that this rule's pattern is designed to pass)
- Skill authoring skill: skill-creator (existing — extend with this rule's requirements for diagnostic-class skills)
