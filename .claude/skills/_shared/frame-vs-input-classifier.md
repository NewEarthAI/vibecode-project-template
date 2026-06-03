---
name: _shared/frame-vs-input-classifier
description: Shared procedural library — Primitive 4 of the First-Principles + Systems-Thinking skill suite. Classifies operator pushback as frame-criticism (the operator is naming a problem with the question/comparison/framing itself) vs input-criticism (the operator is adjusting a value within the accepted frame) vs mixed. On frame-criticism, the default next action is a framing audit, not a frame-internal clarification. Cited by the Reframer council agent (analytical primitive 8), /code-council, and /code-forge. Not user-invocable — a procedural module, not a slash command.
---

# Shared Library — Frame-vs-Input Classifier

**Status**: v1.0 (2026-05-17, Session 8 of the Operational Intelligence Synthesis Programme — Primitive 4 of the First-Principles + Systems-Thinking skill suite)
**Authority**: `.claude/rules/diagnostic-skill-anti-anchoring.md` (classification is diagnostic-class); Agency-Main `2026-05-14-FIRST-PRINCIPLES-SYSTEMS-THINKING-DISCOVERIES-REPORT.md` failure mode 5 + Requirement 4
**Purpose**: One source of truth for classifying operator pushback. The Reframer agent, `/code-council`, and `/code-forge` cite this library instead of each re-deriving the classification logic.
**Not user-invocable**. This is a procedural module for skills and agents — not a Claude Code slash command. It has no `evals/evals.json`; its test surface is the worked Required Test Cases section below (the same shape as `.claude/skills/_shared/anti-anchoring-guard.md`).

---

## Why This Library Exists

The agency's Hermes evaluation (2026-05-14) locked a verdict on an apples-vs-pears comparison. The operator pushed back three times before the framing problem surfaced. Failure mode 5 of the discoveries report names it precisely:

> "When the operator pushes back on a verdict, the agent's instinct is to treat the pushback as a data point to weigh against existing analysis. The structural reading — *the operator may be naming a framing problem the protocol cannot see from inside* — happens only when the operator uses explicit framing-vocabulary like 'apples and pears'."

For a two-person operator + agent team, the operator is the only entity with empirical access to ground truth — they are the frame-validator-of-last-resort. Treating their pushback as edge correction forces them to escalate three or four times before the frame gets audited, wasting their scarcest resource: their attention. This library makes the frame-vs-input distinction a mechanical step so the audit fires on the *first* frame-criticism signal, not the third.

---

## When A Skill Or Agent Cites This Library

Cite this library whenever operator pushback arrives at a framing-relevant juncture:

- A council or `/code-council` is about to lock a verdict and the operator pushed back
- A `/code-forge` or `/code-council` reviewer meets operator pushback in a diff context
- The Reframer agent's analytical primitive 8 (frame-vs-input classification) runs
- Any multi-phase orchestration crosses a phase boundary and the operator commented
- Any decision-locking protocol receives an operator objection before the lock

The citation form is:

> "Classify the operator pushback per `.claude/skills/_shared/frame-vs-input-classifier.md`."

---

## The Three Classes

| Class | Definition | What the operator is doing | Default next action |
|-------|------------|----------------------------|---------------------|
| **frame-criticism** | The pushback questions the framing itself — the question being asked, the comparison being drawn, the problem as scoped, the goal as stated | Naming a problem the protocol cannot see from *inside* its own frame | **Framing audit** — route to the Reframer / `/reduce-to-first-principles`. Do NOT answer inside the current frame. |
| **input-criticism** | The pushback accepts the current frame and adjusts a value, weight, option, or omission *within* it | Correcting an input the frame already has a slot for | Handle inside the current frame — adjust the input, re-run, add the missing item |
| **mixed** | The pushback carries both — at least one clause is frame-criticism and at least one is input-criticism | Both at once | Split: run the framing audit for the frame-criticism clause(s) FIRST, then handle input-criticism inside the (possibly reframed) frame |

**The discriminating test** — for each clause of the pushback, ask:

> *If the agent fully satisfied this clause WITHOUT changing the question being asked, would the operator be satisfied?*

- **Yes** → input-criticism (the frame has a slot for it).
- **No — satisfying it requires re-examining the question itself** → frame-criticism.
- **Genuinely cannot tell** → frame-criticism (fail-safe — see the Classification Procedure Step 4).

---

## The Marker Vocabulary

Markers are **signals, not proof**. They raise or lower suspicion; they never decide the class on their own. The Hermes thread is the proof: the operator's frame-criticism signals "are you saying we're not using Hermes at all?" and "a peer practitioner runs Hermes on a Hetzner VPS in production" carried **no marker phrase** — only "apples and pears" did. A marker-only classifier misses marker-free frame-criticism. The semantic read (Step 3) is mandatory regardless of marker hits.

### Frame-criticism markers (raise suspicion of frame-criticism)

- "apples and pears" / "apples to oranges" / "comparing things that aren't comparable"
- "are we asking the wrong question" / "is this the right question"
- "are we answering the right thing" / "are we solving the right problem"
- "this feels off" / "something feels wrong here" / "this doesn't sit right"
- "wait — what?" / "wait, what?" / "hang on"
- "are we comparing comparable things"
- "step back" / "let's zoom out"
- "are we sure this is the actual goal"
- "I don't think that's what I asked"
- "this doesn't feel like the real issue"
- "why are we even doing X" / "should we be doing X at all"

### Input-criticism markers (raise suspicion of input-criticism)

- "tweak X" / "adjust X" / "change the value of X"
- "X is overweighted" / "X is weighted too high" / "X is weighted too low"
- "let's also consider Z" / "also add Z" / "you missed Z"
- "re-run with X instead" / "what if we used Y instead of X" (same frame, swapped value)
- "increase / decrease X"
- "the number for X looks off" (a value correction, NOT a method objection)

### The deceptive middle — markers that flip on semantics

Some phrasings sit on the boundary and the semantic read decides:

| Phrasing | input-criticism reading | frame-criticism reading |
|----------|-------------------------|--------------------------|
| "the estimate for X seems wrong" | "the *number* is off — correct it" | "*estimates* can't answer this question — we need experience" (a commensurability objection — Primitive 3 territory) |
| "what about Y?" | "add Y as another input" | "Y reveals the whole comparison is mis-framed" |
| "I'm not sure about this" | vague hedge — probe for which input | the operator senses a frame problem they can't yet name |

When a marker lands in the deceptive middle, the semantic read is the tiebreaker, and the fail-safe (Step 4) applies if it stays ambiguous.

---

## The Classification Procedure

### Step 1 — MVI gate

Two inputs are mandatory. Without both, classification hallucinates:

| Field | Why required |
|-------|--------------|
| `pushback_text` | The operator pushback to classify, verbatim |
| `current_frame` | The frame the pushback lands against — the question being asked, the comparison being drawn, the verdict about to lock. Without it, "criticism OF the frame" and "criticism WITHIN the frame" are indistinguishable. |

If either is missing → emit a structured insufficient-input error (per `.claude/skills/_shared/anti-anchoring-guard.md` Component 1 Step 1.3) and HALT. Never classify pushback without knowing the frame it pushes against.

### Step 2 — Marker scan

Scan `pushback_text` for frame-criticism and input-criticism markers. Record every hit and which class it suggests. Do NOT classify yet — markers only set the prior.

### Step 3 — Semantic read (MANDATORY — never skipped)

Break `pushback_text` into clauses (a clause is one distinct objection — operators often voice two in one sentence). **Discard any candidate clause that carries no objection** — filler, acknowledgements, greeting fragments ("hmm", "okay", "thanks") — before running the discriminating test; only genuine objection clauses are classified. If discarding leaves zero objection clauses, the verdict is `OUT_OF_SCOPE` (the message is not pushback), NOT `frame-criticism` — the Step 4 fail-safe applies only to genuine-but-ambiguous objections, never to filler.

For each surviving clause, apply the discriminating test from The Three Classes against `current_frame`:

> *If the agent fully satisfied this clause WITHOUT changing the question being asked, would the operator be satisfied?*

Record per clause: the clause text, the test outcome, and the class. The semantic read runs even when Step 2 found a clear marker — a marker can be present and still be semantically the other class (e.g. "let's step back and bump the X estimate" reads input-criticism despite the "step back" marker).

### Step 4 — Fail-safe on ambiguity

If a clause is genuinely ambiguous after the semantic read — the discriminating test does not resolve — classify that clause as **frame-criticism**, and record `ambiguous: true` with the reason.

Rationale: the costs are asymmetric. Mis-routing input-criticism to a framing audit wastes a few minutes. Mis-routing frame-criticism to a frame-internal answer reproduces the Hermes failure — a locked verdict on the wrong question. Failure mode 5 is structurally a problem of *under*-detecting frame-criticism; the fail-safe corrects the asymmetry. This is not a licence to classify lazily — the semantic read must genuinely run first; the fail-safe is the tiebreaker, not the default.

### Step 5 — Aggregate

| Clause classes | Verdict |
|----------------|---------|
| All clauses input-criticism | `input-criticism` |
| All clauses frame-criticism | `frame-criticism` |
| At least one of each | `mixed` (with the per-clause breakdown retained) |

---

## The Default-Next-Action Rule

The classification is only useful if it changes what happens next:

| Verdict | Default next action |
|---------|---------------------|
| `frame-criticism` | **Framing audit.** Route to the Reframer agent and/or `/reduce-to-first-principles` on the current frame. Do NOT answer the pushback inside the current frame — answering inside it is the exact failure mode 5 behaviour. |
| `input-criticism` | Handle inside the current frame — adjust the named input, add the omission, re-run with the corrected value. No framing audit. |
| `mixed` | **Frame-criticism clauses first.** Run the framing audit for the frame-criticism clause(s) before touching the input-criticism clause(s) — a wrong frame contaminates any input adjustment made inside it. Once the frame is confirmed or corrected, handle the input-criticism clauses inside it. |

The citing skill/agent MAY override the default next action, but the override must be explicit and reasoned in its output — a silent override is an anti-pattern (see below).

---

## Anti-Anchoring Guard (carried — adapted to the classification domain)

Classification is diagnostic-class per `.claude/rules/diagnostic-skill-anti-anchoring.md`, so the four-component anti-anchoring pattern applies. It is carried here **adapted** to a classifier that takes pushback *text* as input rather than a *hypothesis about an answer*. The adaptation is marked `[P4-ADAPT]` so a reviewer can audit it (the same inline-marking discipline as the Reframer's `[GAP-3 FIX]`).

### Component 1 — MVI
Carried verbatim — Step 1 above (`pushback_text` + `current_frame`).

### Component 2 — Independent classification + provenance branch
`[P4-ADAPT]` The "independent location" of a classifier is the **independent classification**: run Steps 2-5 to a verdict BEFORE looking at any operator-supplied or agent-supplied candidate classification, and BEFORE considering which verdict is cheaper to act on. Two anchoring risks this closes:

1. **Convenience anchoring** — the agent has already invested in the current frame; `input-criticism` is the cheaper verdict (no framing audit). The classification MUST be reached without reference to which verdict is cheaper. If you notice the cost of the framing audit influencing the read, that is the anchor — discard it and re-read.
2. **Supplied-classification anchoring** — the operator, a prior skill, or Claude earlier in the session may assert a candidate classification ("this is just an input tweak"). Provenance branches apply, per `.claude/skills/_shared/anti-anchoring-guard.md` Component 2:
   - `operator` → classify independently, then compare to the operator's candidate. Verdict `AGREED` / `DISAGREED` / `INCONCLUSIVE`. On `DISAGREED`, present both — never silently accept the operator's candidate (note: even the operator can mislabel their own pushback).
   - `prior_skill` → validate-upstream (Branch B): the candidate classification came from another skill's output; re-derive independently and check stability.
   - `session_history` → fire the operator-confirmation question before classifying.
   - No candidate supplied → `hypothesis_provenance: not_applicable`; independent classification is the verdict.

### Component 3 — Counterfactual
`[P4-ADAPT]` The full four-field Component 3 struct is **carried in full** (`default_action`, `classifier_recommendation` — the domain alias for the mandatory `skill_recommendation` — `difference`, `skill_leverage`). The counterfactual default action is the failure-mode-5 instinct: **without the classifier, operator pushback is treated as input-criticism by default** (a data point weighed inside the frame). The classifier's leverage is the cases where it returns `frame-criticism` or `mixed` and thereby triggers a framing audit that would not otherwise have fired — `skill_leverage` names that triggered audit. If the classifier returns `input-criticism`, it has matched the default — `difference: none`, `skill_leverage: "none — matched the default, correctly"` — and earned no leverage for that case; that is correct and expected, not a failure (most pushback genuinely is input-criticism). **The ONE thing adapted is the GATE, not the field set**: in the standard pattern, `difference: none|marginal` flags ADVISORY-pending; here the counterfactual is reported, not gated — a classifier that returns `input-criticism` still PASSES (an input-criticism verdict is a correct result, not a low-leverage failure).

### Component 4 — Falsifier
`[P4-ADAPT]` The full three-field Component 4 struct is **carried in full** (`specific_observation` — the domain alias for the mandatory `specific_observable` — `timeframe`, `operator_response_if_triggered`). On a HIGH-confidence `frame-criticism` verdict, name the specific observation that would show the pushback was actually input-criticism — e.g. "falsified if, on framing audit, the operator confirms the question is correct and only the X value needed changing." On a HIGH-confidence `input-criticism` verdict, name what would show it was frame-criticism. **The ONE thing adapted is the `timeframe` semantics**: a classifier is synchronous, so `timeframe` is not a calendar window — it is "on completion of the routed next action" (the framing audit for `frame-criticism`, the frame-internal handling for `input-criticism`). The falsifier resolves the moment the routed action concludes. A missing `timeframe` is still BLOCKING per Component 4 Step 4.2; the synchronous value satisfies the requirement — it is never omitted. Generic falsifiers (no named observation) are downgraded to MEDIUM confidence.

---

## Output Struct

```yaml
classifier: frame-vs-input
version: 1.0
verdict: <frame-criticism | input-criticism | mixed | INSUFFICIENT_INPUT | OUT_OF_SCOPE>
confidence: <HIGH | MEDIUM | LOW>

input:
  pushback_text: <verbatim string>
  current_frame: <string — the question/comparison/verdict the pushback lands against>

marker_scan:
  frame_markers_hit: [<string>, ...]
  input_markers_hit: [<string>, ...]

clauses:
  - text: <clause verbatim>
    class: <frame-criticism | input-criticism>
    discriminating_test: <the satisfied-without-changing-the-question outcome>
    ambiguous: <bool>
    ambiguity_reason: <string | null>

anti_anchoring:
  hypothesis_provenance: <operator | prior_skill | session_history | not_applicable>
  supplied_candidate: <string | null>
  independent_classification: <frame-criticism | input-criticism | mixed>
  verdict: <AGREED | DISAGREED | INCONCLUSIVE | validate_upstream_stable | validate_upstream_unstable | not_applicable>

counterfactual:   # anti-anchoring-guard.md Component 3 — `classifier_recommendation` is the domain alias for the mandatory `skill_recommendation` field
  default_action: "treat the pushback as input-criticism — adjust inside the frame"
  classifier_recommendation: <the default next action for the verdict>
  difference: <none | marginal | substantial | transformative>
  skill_leverage: <1-3 sentences — for frame-criticism/mixed, the framing audit this verdict triggered that the default would have skipped; for input-criticism, the literal "none — matched the default, correctly">

falsifier:  # required when confidence == HIGH; anti-anchoring-guard.md Component 4 — `specific_observation` is the domain alias for the mandatory `specific_observable` field
  specific_observation: <what would show the verdict wrong>
  timeframe: <synchronous for a classifier — "on completion of the routed next action" (the framing audit, or the frame-internal handling); never omitted (see Component 4 [P4-ADAPT])>
  operator_response_if_triggered: <one sentence>

default_next_action: <framing-audit | handle-in-frame | split-frame-first>
override: <string | null>   # explicit + reasoned if the citing skill overrides the default

invocation_metadata:
  timestamp: <ISO 8601 UTC>
  classifier_version: 1.0
  invocation_id: <uuid>
```

---

## Required Test Cases

A skill or agent that cites this library MUST behave correctly on all of these. They are worked here (the library is not user-invocable, so it carries no `evals/evals.json` — these examples are the test surface, the same pattern as `anti-anchoring-guard.md`).

| # | Test | Input | Required behaviour |
|---|------|-------|--------------------|
| 1 | Happy path — frame-criticism | `pushback_text`: "wait — are we comparing apples and pears here?"; `current_frame`: "the council is locking BUILD NATIVE off an estimated-build-cost vs estimated-integration-cost comparison" | `verdict: frame-criticism`; `default_next_action: framing-audit`; marker hit recorded; semantic read confirms the comparison itself is what is questioned |
| 2 | Happy path — input-criticism | `pushback_text`: "I think the integration cost estimate is too low — bump it"; `current_frame`: same as Test 1 | `verdict: input-criticism`; `default_next_action: handle-in-frame`; the frame (estimate-vs-estimate) is accepted, a value inside it is corrected; counterfactual `difference: none` and that is a PASS, not a failure |
| 3 | Marker-free frame-criticism | `pushback_text`: "a peer practitioner runs Hermes on a Hetzner VPS in production"; `current_frame`: "the council is locking BUILD NATIVE — Hermes treated as not-yet-proven" | `verdict: frame-criticism` via the **semantic read**, not markers (no marker hits); the clause names real-world evidence that contradicts the frame's premise. This is the test that proves markers alone are insufficient. |
| 4 | Adversarial — operator mislabels their own pushback | `pushback_text`: "this is just a small thing — wait, are you saying we're not using Hermes at all?"; `supplied_candidate: input-criticism`, `hypothesis_provenance: operator` | independent classification returns `frame-criticism`; `anti_anchoring.verdict: DISAGREED`; both presented; the operator's "just a small thing" self-label is NOT silently accepted |
| 5 | Mixed | `pushback_text`: "the build estimate looks low, and anyway are we sure native-vs-integrate is even the right question?"; `current_frame`: same as Test 1 | `verdict: mixed`; clause 1 input-criticism, clause 2 frame-criticism; `default_next_action: split-frame-first` — framing audit before the estimate fix |
| 6 | Vague / below-MVI | `pushback_text`: "hmm, not sure"; `current_frame` absent | `verdict: INSUFFICIENT_INPUT`; missing-field error; `current_frame` required; no classification hallucinated |
| 7 | Out-of-scope | `pushback_text` is not pushback at all — a feature request ("can you also add a dark mode") or a greeting | `verdict: OUT_OF_SCOPE`; the library classifies pushback, not arbitrary operator messages; no forced frame/input verdict |
| 8 | Non-author-domain | `pushback_text`: "hang on — are we sure listing price is the right thing to be optimising?"; `current_frame`: a real-estate deal-analysis verdict locking on a price-optimisation metric | `verdict: frame-criticism`; classification works in a non-software domain with no software vocabulary; the discriminating test is domain-agnostic |
| 9 | Fail-safe on genuine ambiguity | `pushback_text`: "I'm not sure this is right"; `current_frame` present | semantic read cannot resolve → Step 4 fires → `verdict: frame-criticism`, `clauses[].ambiguous: true`, ambiguity reason recorded; confidence LOW or MEDIUM |
| 10 | Convenience anchoring | `pushback_text`: "are we sure this whole comparison even holds?" against a `current_frame` whose framing audit would be expensive to run (a near-locked verdict, much sunk work) | `verdict: frame-criticism` — the verdict does NOT drift to `input-criticism` to avoid the costly audit; the classification reasoning never references the cost of the next action (Component 2 `[P4-ADAPT]` convenience-anchoring guard) |

**Deliberate omission — `prior_skill` provenance has no worked case.** A classifier almost always receives `pushback_text` directly from the operator, not as a candidate classification handed down by an upstream skill — so the cross-skill-chain (Branch B / validate-upstream) category is not given its own worked row. If a `prior_skill` candidate classification does arrive, Component 2's `prior_skill` branch still applies in full — the path is wired (see the Anti-Anchoring Guard section), only the worked example is omitted. This omission is deliberate, not an oversight.

**Cross-invocation anti-pattern — a monitoring obligation, not a unit test.** The most dangerous anti-pattern — "treating all pushback as input-criticism" (the classifier never returns `frame-criticism` across many invocations) — cannot be caught by any single worked case. It is a monitoring obligation: audit the verdict distribution across invocations; a classifier that never returns `frame-criticism` is reproducing failure mode 5, and the semantic-read step (Step 3) must be re-examined.

---

## Anti-Patterns This Library Prevents

| Anti-pattern | Detection signal | Fix |
|--------------|------------------|-----|
| Marker-only classification | Verdict reached from Step 2 alone, Step 3 skipped | The semantic read is mandatory; markers set the prior, never the verdict |
| Convenience anchoring | The classifier returns `input-criticism` and the reasoning references the cost of a framing audit | Re-classify; the cost of the next action must not touch the classification |
| Silent acceptance of the operator's self-label | `supplied_candidate` present, no `anti_anchoring.verdict` | Run the provenance branch; classify independently first |
| Ambiguity resolved toward `input-criticism` | A clause marked ambiguous classified as input-criticism | Step 4 fail-safe: ambiguous → frame-criticism |
| Verdict with no next action | Output has a `verdict` but no `default_next_action` | The classification is only useful if it routes; emit the next action |
| Silent override | Citing skill ignores `default_next_action` with no `override` reason | Overrides must be explicit and reasoned in the citing skill's output |
| Treating all pushback as input-criticism | The classifier is cited but never returns `frame-criticism` across many invocations | Failure mode 5 recurring; audit the semantic-read step |

---

## Composition

| Consumer | How it cites this library |
|----------|---------------------------|
| **Reframer council agent** | The Reframer's analytical primitive 8 (frame-vs-input classifier) is the best-effort *inline* version of this library. **Session-10 patch (forward-reference)**: per the skill-suite plan, the Reframer is patched at Session 10 to cite this library instead of carrying the classification logic inline; the inline version is then deleted. Until then, both coexist — the inline version is the interim, this library is the canonical source. |
| **`/code-council`** | When a reviewer meets operator pushback in a diff-review context, the pushback is classified per this library; `frame-criticism` halts the review and routes to the Reframer rather than answering inside the review's frame. |
| **`/code-forge`** | Same as `/code-council` — operator pushback during a forge pass is classified before being acted on. |
| **`/reduce-to-first-principles`** (Primitive 1) | The default next action for `frame-criticism` routes here — the first-principles reduction IS the framing audit. |
| **`.claude/skills/_shared/anti-anchoring-guard.md`** | This library cites Components 1, 2, 3, 4 of the anti-anchoring guard, adapted (`[P4-ADAPT]`) to the classification domain. |

---

## What This Library Is NOT

- **Not a slash command** — `_shared/` libraries are not user-invocable; they are procedural modules cited by skills and agents.
- **Not a sentiment analyser** — it classifies pushback by its relationship to the *frame*, not by tone. Calm frame-criticism and angry input-criticism both classify by structure, not affect.
- **Not the framing audit itself** — it *routes to* the audit (the Reframer / `/reduce-to-first-principles`); it does not perform it.
- **Not a runtime guarantee** — this is authoring discipline. The citing skill/agent must encode the procedure; the library names the pattern, it does not enforce at runtime.
- **Not retroactive** — applies to skills/agents that cite it from 2026-05-17 onwards.

---

## Failure Mode History

This library implements the structural fix for **failure mode 5** of the Agency-Main discoveries report (`2026-05-14-FIRST-PRINCIPLES-SYSTEMS-THINKING-DISCOVERIES-REPORT.md`):

> "Operator pushback processed as input correction, not framing alarm. ... For a 2-person operator team where the operator has direct empirical access to the work and the agent has only analytical access, this ordering is backwards. Operator pushback should be primary signal at framing-relevant junctures, not edge correction."

The report's Requirement 4 asked for "a fourth primitive that takes operator pushback text and classifies it as frame-criticism versus input-criticism. When classified as frame-criticism, the agent's next action defaults to a framing audit." This library is that primitive.

The Hermes thread is also the source of Test 3 — the operator's marker-free frame-criticism (a factual statement that a peer practitioner runs Hermes on a VPS in production) that a marker-only classifier would have missed. (Test 3 is genericised — the source thread named a specific practitioner; the test value is the marker-free factual-evidence shape, which the generic form preserves fully.)

---

## Strategic Alignment

**ROADMAP item(s) this advances**: Operational Intelligence Synthesis Programme Session 8; the First-Principles + Systems-Thinking skill suite (Primitive 4 of 5); workshop methodology codification; the agency's framing-audit reflex — gives the upgraded Reframer's analytical primitive 8 a callable, single-source backing; the Session 10 Hermes re-run gains a mechanical pushback-classification step.

**ROADMAP item(s) this REJECTS**: marker-only classification (Test 3 catch); operator pushback treated as input-criticism by default (failure mode 5 — the failure this library exists to prevent); a standalone user-invocable slash command for classification (the consumers are agents, not the operator — this is a `_shared/` library, matching the `anti-anchoring-guard.md` precedent).

**If this library advances nothing**: the Reframer's frame-vs-input classification stays best-effort inline prose with no single source of truth; `/code-council` and `/code-forge` re-derive the logic or skip it; failure mode 5 keeps no structural defence and operator pushback keeps being mis-read as input correction until the operator escalates explicitly with a marker phrase.

---

## References

- Authority rule: `.claude/rules/diagnostic-skill-anti-anchoring.md`
- Sibling shared library: `.claude/skills/_shared/anti-anchoring-guard.md` (Components 1-4, cited adapted)
- Source brief: Agency-Main `continuations/2026-05-14-FIRST-PRINCIPLES-SYSTEMS-THINKING-DISCOVERIES-REPORT.md` (failure mode 5, Requirement 4)
- Skill-suite continuation: `continuations/SYNTHESIS-PROGRAMME-SKILL-SUITE-MASTER-CONTINUATION-2026-05-17.md` (§6 Primitive 4 design direction)
- Session 8 plan: `specs/02_PLAN_V2_SESSION_8.md`
- Consumer agent: `.claude/agents/council/reframer.md` (analytical primitive 8 — interim inline version, patched at Session 10)
- Sibling suite primitives: `/reduce-to-first-principles` (P1), `/map-feedback-loops` DECISION mode (P2), `/check-commensurability` (P3)

---

*Shared library v1.0 authored 2026-05-17 in Session 8 of the Operational Intelligence Synthesis Programme. Primitive 4 of the First-Principles + Systems-Thinking skill suite. Source of truth for frame-vs-input classification across the Reframer agent, `/code-council`, and `/code-forge`. Not user-invocable.*
