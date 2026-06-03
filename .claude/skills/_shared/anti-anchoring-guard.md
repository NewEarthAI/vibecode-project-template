---
name: _shared/anti-anchoring-guard
description: Shared procedural library used by all diagnostic-class workshop skills. Encodes the four-component anti-anchoring pattern from .claude/rules/diagnostic-skill-anti-anchoring.md as a single source of truth so /diagnose-bottleneck, /map-feedback-loops, /decide-under-uncertainty, and future diagnostic skills cite identical logic instead of drifting. Not user-invocable. Cited by SKILL.md procedure sections.
---

# Shared Library — Anti-Anchoring Guard Procedure

**Status**: v1.0 (2026-05-12)
**Authority**: `.claude/rules/diagnostic-skill-anti-anchoring.md` (post-Phase-3.5 patch with `hypothesis_provenance` field)
**Purpose**: One source of truth for the four anti-anchoring components. Three diagnostic skills cite this library rather than re-implementing the procedure. Future diagnostic skills MUST cite this library too.
**Not user-invocable**. This is a procedural module for skill authors; not a Claude Code slash command.

---

## When A Skill Cites This Library

A diagnostic skill cites this library in its SKILL.md `## Procedure` section whenever it must:

- Validate an operator-supplied hypothesis (the most common case)
- Validate input arriving from another diagnostic skill (chain handoff)
- Validate hypothesis that Claude itself proposed earlier in the same session
- Produce the mandatory counterfactual statement (Component 3)
- Produce the falsifier on any HIGH-confidence output (Component 4)

The citation form is:

> "Apply Component {N} of `.claude/skills/_shared/anti-anchoring-guard.md`."

The citing SKILL.md is responsible for supplying the doctrine-specific independent-location procedure (TOC 5 Focusing Steps; CLD construction + archetype check; Decision-Quality Application Checklist Steps 3-9). This library tells the skill HOW to wrap that procedure; the skill tells the library WHAT procedure to wrap.

---

## Component 1 — Minimum Viable Input (MVI) Procedure

### Step 1.1 — Define MVI threshold in the citing SKILL

Every diagnostic skill SKILL.md MUST list its MVI fields explicitly in an `## MVI` section before invoking any other component. The MVI threshold is doctrine-specific; this library does not name the fields.

### Step 1.2 — Check before any further processing

Before invoking Component 2, Component 3, or any output procedure:

1. Read all MVI fields from the operator's input
2. For each MVI field, check the field's validation predicate (the skill's MVI section names the predicate for each field)
3. If any predicate fails → emit structured insufficient-input error per Step 1.3 and HALT. Do not proceed to Component 2.

### Step 1.3 — Structured insufficient-input error template

When MVI fails, the skill emits:

```yaml
error: insufficient_input
skill: <skill_name>
missing_fields:
  - field: <name>
    reason: <one-sentence why this field is required>
example_input: |
  <a complete, copy-pastable example input from the skill spec's MVI section>
recommended_action: |
  <one-sentence pointer: "supply the missing fields and re-invoke">
```

NEVER hallucinate a recommendation from below-MVI input. This is the most-violated rule in diagnostic-skill authoring; the citing SKILL is responsible for refusing.

---

## Component 2 — Anti-Anchoring Guard (Mandatory Independent Location + Provenance Branch)

This is the structural protection against the skill becoming a hypothesis-confirmation machine. The procedure has three branches by `hypothesis_provenance`.

### Step 2.1 — Hypothesis provenance check (MANDATORY MVI element)

The MVI gate (Component 1) MUST include `hypothesis_provenance` as a required field. Allowed values:

| Value | Meaning |
|-------|---------|
| `operator` | Hypothesis came from the operator's own intuition or analysis |
| `prior_skill` | Hypothesis is the output of another diagnostic skill in this chain (e.g., `/diagnose-bottleneck` output flowed into `/decide-under-uncertainty` input) |
| `session_history` | Hypothesis was proposed by Claude earlier in the same session, NOT by the operator |
| `generative_primitive` | Input is the output of a *generative* workshop skill (e.g. the destination-authoring skill produced a destination now being audited by a diagnostic skill). The output IS the operator's expressed intent in computationally-structured form — not a competing diagnostic hypothesis. Added 2026-05-18. |

If `hypothesis_provenance` is missing from input: treat as Component 1 MVI failure. Do not assume `operator`.

### Step 2.2 — Branch logic by provenance

Each branch invokes a different procedure. Mixing branches produces silent failures.

#### Branch A — provenance is `operator` → STANDARD guard

1. **Independent location**: invoke the citing skill's doctrine-specific identification procedure WITHOUT referencing the operator's named hypothesis. Apply the procedure mechanically.
2. **Compare**: independent location result vs operator's named hypothesis.
3. **Verdict in three classes** (write to output struct):

   | Verdict | Trigger | Skill behaviour |
   |---------|---------|-----------------|
   | `AGREED` | Independent location matches operator's hypothesis | Proceed with full analysis. Log "anti-anchoring verified" — the agreement is meaningful because it survived independent verification, not because the skill accepted the framing |
   | `DISAGREED` | Independent location identifies a different target | Present BOTH the operator's claim AND the independent location. Do NOT pick one silently. Ask the operator to choose OR run both analyses in parallel. |
   | `INCONCLUSIVE` | Observed data does not discriminate between hypotheses | Flag as insufficient-input even if MVI was met (numbers exist but lack discriminating power). Request additional data or finer-grained signals. |

#### Branch B — provenance is `prior_skill` → VALIDATE-UPSTREAM mode

This branch closes the silent-chain-break failure mode identified by Edge Case Finder 2026-05-12. NEVER apply standard compare when provenance is `prior_skill` — that produces false-agreement (both sides AI-generated) or false-disagreement (skill disagreeing with itself across layers).

1. **Identify upstream skill** from `source_hypothesis.upstream_skill` field in input.
2. **Rerun upstream skill with different parameters** — at least one of:
   - Alternative scope frame (different system boundary)
   - Different time window (if temporal)
   - Different operator-stated bias check
   - Different stakeholder framing
3. **Check stability of upstream output** across the rerun(s):

   | Verdict | Trigger | Skill behaviour |
   |---------|---------|-----------------|
   | `validate_upstream_stable` | Upstream output substantively unchanged across re-runs (specific stage/loop/option same; minor metric variation acceptable) | Treat the stabilised upstream output as the hypothesis; proceed to Branch A's steps 2-3 |
   | `validate_upstream_unstable` | Upstream output varies materially across re-runs (different stage / different loop / different option emerges) | BLOCK with: "Upstream skill output unstable; cannot validate downstream against unstable hypothesis. Re-run upstream with consolidated parameters before proceeding." Halt this skill's invocation; do NOT produce a downstream verdict. |

#### Branch C — provenance is `session_history` → OPERATOR CONFIRMATION question

The most-common error here is silent: Claude proposes a hypothesis earlier in the session; the operator parrots it back; the skill treats it as `operator` provenance and runs standard guard against an AI-generated anchor. The shield:

1. Emit one clarifying question to operator: "Is this hypothesis yours, or did Claude propose it earlier in this conversation? Hypothesis source affects how the anti-anchoring guard operates."
2. On operator response:
   - "Mine" → re-route to Branch A (`operator`)
   - "Claude proposed it" → re-route to Branch B (`prior_skill` with `upstream_skill: claude_session`)
   - Ambiguous response → re-ask; do not default

#### Branch D — provenance is `generative_primitive` → BOUNDED-TAG STANDARD guard

Added 2026-05-18. This branch handles input produced by a *generative* workshop skill — most commonly a destination authored by the destination-authoring skill and now passed to a diagnostic skill for audit. A generative skill's output is non-deterministic by design, so the validate-upstream rerun of Branch B would ALWAYS report `unstable` and BLOCK — wrongly. Branch D treats the input as operator-authored intent (the destination IS the operator's expressed intent in structured form), but only after a bounds check that closes the laundering hole (an operator must not be able to launder an anchored hypothesis past the guard by dressing it as a "destination").

1. **Bounds check.** A `generative_primitive` input MUST carry, in its `source_hypothesis` block, two fields: `generated_at` (ISO date) and `project_root` (repo identifier). A `generative_primitive` provenance arriving WITHOUT both is a Component 1 input-validation failure. Verify BOTH:
   - `project_root` matches the current project, AND
   - `generated_at` is within the staleness window (the citing skill's MVI section names the window; default: 21 calendar days).
2. **Branch by the bounds-check result:**

   | Result | Skill behaviour |
   |--------|-----------------|
   | Both pass | Treat the input as `operator` provenance and run Branch A (standard guard) — the independent location AND the three-class compare both run normally. A `generative_primitive` input is NOT rubber-stamped: the diagnostic skill can and MUST still return `DISAGREED` if its independent location contradicts the destination. The only Branch B step suppressed is validate-upstream. |
   | `project_root` mismatch OR `generated_at` stale | DOWNGRADE — re-classify provenance as `operator`, run Branch A, and record in `reasoning_chain`: "input was `generative_primitive`-tagged but the tag is cross-project or beyond the staleness window — provenance downgraded to `operator`; full standard guard applied." |

3. **Validate-upstream (Branch B) is NEVER run for `generative_primitive`.** A generative skill's non-determinism makes the stability check structurally meaningless.
4. **Only the originating generative skill writes the `generative_primitive` tag** — into its output artefact's frontmatter. A session author or a diagnostic skill MUST NOT set `hypothesis_provenance: generative_primitive` manually.

### Step 2.3 — Output struct fields (MANDATORY in every diagnostic skill's output)

```yaml
anti_anchoring:
  hypothesis_provenance: <operator | prior_skill | session_history | generative_primitive | not_applicable>
  verdict: <AGREED | DISAGREED | INCONCLUSIVE | validate_upstream_stable | validate_upstream_unstable | not_applicable>
  independent_recommendation: <the skill's independent answer; null if Branch B unstable>
  reasoning_chain: <list of steps that led to the independent recommendation; required for operator-readable reasoning per Decision-Quality doctrine P5>
```

The verdict field is **mandatory** — emitting a skill output without it is a Gate 2 BLOCKING violation.

**`not_applicable` (added 2026-05-17).** When a skill is invoked with NO operator-supplied hypothesis (the skill's hypothesis parameter is null), there is no anchor to guard against — the anti-anchoring compare does not run. In that case both `hypothesis_provenance` and `verdict` take the value `not_applicable`. `not_applicable` is valid ONLY in the no-hypothesis case; a skill that emits `not_applicable` while a hypothesis WAS supplied has a bug. The independent location still runs and `independent_recommendation` is still populated — the skill's own analysis is never skipped, only the *compare* is.

**Field-name aliasing convention (added 2026-05-17).** A diagnostic skill MAY rename `independent_recommendation` to a domain-specific alias (e.g. `independent_reduction` in `/reduce-to-first-principles`, `independent_ladder_position` in `/check-commensurability`) when the domain name is clearer to operators. The alias is permitted ONLY if: (a) the skill's Output Schema documents inline that the field IS the `independent_recommendation` mandatory field under a domain alias, and (b) the alias still carries the same semantics (the skill's independent answer; null if Branch B unstable). A conformance audit treats a documented alias as satisfying the mandatory-field requirement. An *undocumented* rename is still a Gate 2 BLOCKING violation.

---

## Component 3 — Counterfactual Statement (MANDATORY in Output)

Every skill recommendation MUST include a counterfactual statement comparing the skill's recommendation to the operator's default action.

### Step 3.1 — Required fields in output struct

```yaml
counterfactual:
  default_action: <one sentence; what the operator would have done without invoking the skill>
  skill_recommendation: <one sentence; what the skill recommends>
  difference: <none | marginal | substantial | transformative>
  skill_leverage: <1-3 sentences justifying the difference value with specific evidence — cost, time, capacity, failure-mode-avoided>
```

The citing skill obtains `default_action` from operator input at MVI time (Component 1 requires it). The skill produces `skill_recommendation` from its independent location.

### Step 3.2 — Counterfactual gate

If `difference` is `none` or `marginal`:

- Skill self-flags ADVISORY-pending — the skill has earned zero leverage for this case
- The output struct's `advisory_pending_reasons` field includes: "counterfactual difference below substantial threshold"
- Operator nominates a different test case OR refines the input
- Verdict is NOT PASS

This gate exists because skills that produce the operator's default action are theatre; they consumed reasoning budget and returned what the operator already knew. The doctrine has not earned its keep for this case.

---

## Component 4 — Falsifiability Marker (MANDATORY on HIGH-Confidence Output)

For any output the skill marks as HIGH confidence, the output MUST include a falsifier.

### Step 4.1 — Required falsifier structure

```yaml
falsifier:
  specific_observable: <a named rate / count / date / threshold — NOT "contrary evidence" or "worse outcomes">
  timeframe: <a concrete period — "within 4 weeks", "by end of Q2", "after 50 invocations">
  operator_response_if_triggered: <what the operator does if the falsifier fires; one sentence>
```

### Step 4.2 — Quality constraint (per Session 3 amendment A7)

A falsifier that fails any of these is BLOCKING at Gate 2 code-council:

- Generic statements like "contrary evidence" or "worse outcomes" without a named observable
- Missing timeframe
- Missing operator response

### Step 4.3 — Confidence downgrade rule

If the citing skill cannot produce a specific-observable falsifier (e.g., the doctrine genuinely cannot point to one observable for this case):

- Auto-downgrade confidence to MEDIUM
- Output struct includes the downgrade reason
- MEDIUM output does not require falsifier marker but documents the absence reason

LOW confidence outputs do not require falsifier marker.

---

## Cross-Skill Composition — How Skills Chain

When skill A's output flows into skill B's input, three rules apply:

1. **Skill A's output struct includes `source_hypothesis`**:

   ```yaml
   source_hypothesis:
     provenance: operator
     upstream_skill: <skill_a_name>
     upstream_invocation_id: <skill_a's invocation_id from invocation_metadata>
     hypothesis_text: <verbatim string operator provided OR skill_a's recommendation>
   ```

2. **Skill B's input includes**:
   - `hypothesis_provenance: prior_skill`
   - `source_hypothesis.upstream_skill: <skill_a_name>`
   - The hypothesis text itself

3. **Skill B's anti-anchoring guard executes Branch B (validate-upstream)**, NOT Branch A.

If a session author manually sets `hypothesis_provenance: operator` while `source_hypothesis.upstream_skill` is non-null, the citing skill MUST reject the combination as input-validation failure. This catches the "hidden AI-anchor" failure mode.

**Generative-skill handoff (added 2026-05-18).** When the upstream is a *generative* workshop skill — not a diagnostic skill — e.g. the destination-authoring skill, skill A's `source_hypothesis.provenance` is `generative_primitive` and the block additionally carries `generated_at` (ISO date) and `project_root`. Skill B runs **Branch D** (bounded-tag standard guard), NOT Branch B — a generative skill's output is non-deterministic and would always fail the validate-upstream stability check. The `upstream_skill` field still names the generative skill.

---

## Required Test Cases (per skill citing this library)

Every diagnostic skill citing this library MUST ship with all of these test cases passing:

| # | Test name | Required behaviour |
|---|-----------|--------------------|
| 1 | Happy path | Well-formed MVI + Branch A operator hypothesis → full output struct with all four components populated |
| 2 | Adversarial anchored | Operator names a hypothesis that disagrees with observed data → `verdict: DISAGREED`; both options presented; no silent acceptance |
| 3 | Vague input | Description without MVI → structured insufficient-input error with example template |
| 4 | Empty input | Skill invoked with no scope → structured error; no hallucination |
| 5 | Out-of-scope | Input outside skill's jurisdiction → scope refusal with redirect |
| 6 | Same-as-default counterfactual | Skill recommendation matches operator's default → `counterfactual.difference: none\|marginal`; ADVISORY-pending; NOT PASS |
| 7 | Non-author-domain | Input from a domain different from where the skill was designed → analysis without domain-specific assumptions; generic vocabulary |

Additionally, for any skill that supports cross-skill chain handoff (Branch B), one more test:

| 8 | Cross-skill chain | `hypothesis_provenance: prior_skill` + valid `source_hypothesis` → Branch B fires; verdict is `validate_upstream_stable` OR `validate_upstream_unstable`; standard agree/disagree/inconclusive verdict is NEVER returned |

And for any skill that may receive the output of a generative workshop skill (Branch D):

| 9 | Generative-primitive input | `hypothesis_provenance: generative_primitive` + `source_hypothesis` carrying the current `project_root` and an in-window `generated_at` → Branch D fires; the bounds check passes; Branch A runs (independent location + three-class compare); validate-upstream is NOT run. A stale or cross-project tag → provenance downgrades to `operator` with the reason recorded in `reasoning_chain`. A `generative_primitive` input MISSING `generated_at`/`project_root` → Component 1 input-validation failure. |

---

## Anti-Patterns This Library Prevents

Each diagnostic skill author should self-check against these before committing:

| Anti-pattern | Detection signal | Fix |
|--------------|------------------|-----|
| Skill emits output without `anti_anchoring.verdict` | Output struct missing the field | Add the field per Component 2 Step 2.3 |
| Skill applies Branch A to `prior_skill` provenance | Output emits AGREED/DISAGREED/INCONCLUSIVE while `source_hypothesis.upstream_skill` is non-null | Re-route through Branch B (validate-upstream) |
| Skill emits HIGH confidence without falsifier | Output has `confidence: HIGH` and no `falsifier` field | Add specific-observable falsifier OR downgrade to MEDIUM |
| Skill omits counterfactual on PASS output | Output has verdict PASS but no `counterfactual` field | Add per Component 3 |
| Skill produces `counterfactual.difference: substantial` without naming the specific evidence | `skill_leverage` is generic ("better outcome", "more systematic") | Replace with named cost/time/capacity/failure-mode |
| Skill hallucinates from below-MVI input | Skill produces a recommendation when MVI gate should have failed | Component 1 Step 1.2 must HALT before Component 2 |
| Skill silently accepts `session_history` provenance as `operator` | No operator confirmation question emitted | Branch C must fire the question |

---

## What This Library Is NOT

- **Not a slash command** — `_shared/` libraries are not user-invocable; they are procedural modules cited by other skills
- **Not doctrine-specific** — this library knows nothing about TOC, Systems Thinking, or Decision-Quality; the citing skill supplies the doctrine procedure
- **Not a runtime check** — this is authoring discipline; the citing SKILL.md must encode the procedure correctly. The library names the pattern; it does not enforce at runtime.
- **Not retroactive** — applies to diagnostic skills authored 2026-05-12 onwards. Pre-existing diagnostic skills are not subject to this library until next material revision.

---

## Failure Mode History

The Edge Case Finder identified the silent-chain-break failure mode in `council/sessions/2026-05-12-session-3-calibration-council.md`:

> "Without explicit cross-skill provenance handling, the skill will pattern-match on the framing and produce an analysis that validates the pre-selected hypothesis. When the hypothesis came from another AI-generated upstream skill output, the downstream skill is validating against its own kind — false agreement is structurally probable."

The Phase 3.5 rule patch added `hypothesis_provenance: prior_skill` with the validate-upstream branch. This library is the implementation layer of that patch — three skills can cite one source instead of re-implementing the branch three times.

---

## Strategic Alignment

**ROADMAP item(s) this advances**:
- Methodology codification (shared library is reusable infrastructure across future diagnostic skills)
- Anti-sycophancy enforcement (anti-anchoring guard is one of three mechanisms per programme contract §8)
- Cross-skill chain pattern (the validate-upstream branch is first exercised in code via this library)

**ROADMAP item(s) this REJECTS**:
- Per-skill duplication of anti-anchoring logic (three drifting copies)
- Standalone slash-command for anti-anchoring (this is a procedural module, not a user-facing skill)

**If this library advances nothing on workshop NSM**: the three skills citing it would individually drift; their propagation (Session 5+) would propagate three subtly different anti-anchoring procedures into client projects. The library exists to prevent that drift.

---

## References

- Authority rule: `.claude/rules/diagnostic-skill-anti-anchoring.md`
- Doctrine verification gate: `.claude/rules/doctrine-verification-gate.md`
- Session 3 council session: `council/sessions/2026-05-12-session-3-calibration-council.md` (A5 patch origin)
- Citing skills: `.claude/skills/diagnose-bottleneck/SKILL.md`, `.claude/skills/map-feedback-loops/SKILL.md`, `.claude/skills/decide-under-uncertainty/SKILL.md`

---

*Shared library v1.0 authored 2026-05-12 in Session 4 of the Operational Intelligence Synthesis Programme. Source of truth for the four-component anti-anchoring pattern across all current and future workshop diagnostic skills.*
