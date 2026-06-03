---
name: reduce-to-first-principles
description: |
  First-principles reduction for claims, proposals, and protocol gates. Strips a stated
  question down to its irreducible form, stops at the decision-relevance floor (not philosophy),
  and produces a delta table naming what the framing added on top — added constraints,
  presuppositions, smuggled conclusions. Runs the mandatory anti-anchoring guard before
  accepting any operator-supplied reduction, and emits a counterfactual comparing the
  reduction to the operator's default framing.
  Use when: "reduce to first principles", "what is the real question here", "is this framing
  sound", "what is this proposal actually asking", "audit this gate", "are we asking the
  wrong question", "what did the framing smuggle in", "first-principles this", "what's the
  irreducible question", "strip the framing", "are we comparing apples to pears".
  Do NOT use for: dynamic / over-time behaviour (use /map-feedback-loops); option-choice
  under uncertainty once the framing is already sound (use /decide-under-uncertainty);
  locating a flow constraint (use /diagnose-bottleneck); pure factual yes/no questions with
  no decision framing attached.
classification: capability-uplift
version: 1.0
created: 2026-05-17
operationalises: none — net-new primitive (Synthesis Programme Session 6, framing-audit skill suite, Primitive 1 of 5)
spec: specs/06_REDUCE_TO_FIRST_PRINCIPLES_SKILL.md
shared_library: .claude/skills/_shared/anti-anchoring-guard.md
allowed-tools: Read, Glob, Grep, AskUserQuestion
user-invocable: true
parameters:
  - name: subject
    type: string
    required: true
    description: The claim, proposal, or protocol gate to reduce; free text. The subject must be stated — there is no "discover" mode.
  - name: input_type
    type: enum
    required: true
    description: One of proposal | claim | protocol_gate — selects which reduction sub-procedure runs in Step 4
  - name: proposed_reduction
    type: string
    required: false
    description: If the operator has their own candidate for the irreducible question; the skill challenges it via the anti-anchoring guard before accepting
  - name: hypothesis_provenance
    type: enum
    required: true_when_proposed_reduction_present
    description: One of operator | prior_skill | session_history | generative_primitive (per shared anti-anchoring library Component 2)
  - name: default_action
    type: string
    required: true
    description: What the operator would do without the skill's reduction (required for the counterfactual gate)
  - name: source_hypothesis
    type: object
    required: true_when_provenance_is_prior_skill_or_generative_primitive
    description: Upstream-skill handoff block per shared library Cross-Skill Composition section. When provenance reaches prior_skill via a Branch C re-route (upstream_skill claude_session), this block is synthesised from session context with upstream_invocation_id null — see Step 7 Branch C. When provenance is generative_primitive the block additionally carries generated_at (ISO date) and project_root — the bounds-check fields per shared library Step 2.2 Branch D.
---

# /reduce-to-first-principles — First-Principles Reduction of a Framing

**Status**: v1.0 (Session 6 of the Operational Intelligence Synthesis Programme — 2026-05-17)
**Primitive**: 1 of 5 in the framing-audit skill suite (continuation `SYNTHESIS-PROGRAMME-SKILL-SUITE-MASTER-CONTINUATION-2026-05-17.md`)
**Skill spec**: `specs/06_REDUCE_TO_FIRST_PRINCIPLES_SKILL.md`
**Cites shared library**: `.claude/skills/_shared/anti-anchoring-guard.md` (anti-anchoring guard, counterfactual gate, falsifier discipline)

---

## Purpose

This skill is the executable form of first-principles reduction. It is the formal, callable version of analytical primitive 5 in the upgraded Reframer agent (`.claude/agents/council/reframer.md`), which currently carries that logic inline as best-effort.

What the skill diagnoses is a **framing**. It takes a stated question — a proposal, a claim, or a protocol gate — and answers two questions:

1. **What is the irreducible question beneath the framing?** The deepest question whose answer still changes the action in front of the operator.
2. **What did the framing add on top of that irreducible question?** Every added constraint, presupposition, and smuggled conclusion, named in a delta table.

The skill exists because of a real failure. On 2026-05-14 the NewEarth agency ran a three-phase competitor evaluation that converged eight agents unanimously on a verdict — inside a flawed frame. A protocol gate named "reproducibility check" (irreducible purpose: *test whether the competitor's claim holds up when run in our environment*) had silently become a build-cost estimate. Nobody reduced the gate to its irreducible question and noticed the method no longer answered it. This skill is the callable tool that performs that reduction on demand, before a framing error compounds through a multi-phase chain.

**Use this skill when**:
- A proposal, claim, or protocol gate is about to drive a decision and its framing has not been audited
- A multi-phase orchestration crosses a gate boundary and the gate's method may have drifted from the gate's purpose
- An operator senses something is "off" about how a question is posed ("are we comparing apples to pears?")
- A council or review is about to deliberate inside an inherited frame

**Do NOT use this skill when**:
- The question is dynamic-over-time (use `/map-feedback-loops`)
- The framing is already sound and the operator just needs to pick an option (use `/decide-under-uncertainty`)
- The question is locating a flow constraint (use `/diagnose-bottleneck`)
- The question is a pure factual yes/no with no decision framing — there is no framing to reduce

---

## When to Invoke

### Explicit triggers
- "reduce this to first principles", "what is the real question here", "what is this actually asking"
- "is this framing sound?", "what did the framing smuggle in?", "audit this gate"
- "are we asking the wrong question?", "are we comparing apples to pears?"
- A sister skill or council agent hits an inherited framing and defers here before deliberating

### Implicit triggers (consideration, not auto-invocation)
- A multi-phase orchestration is about to cross a Phase N→N+1 boundary — consider reducing the upstream gate first
- A proposal arrives pre-shaped as a binary ("adopt X or build native?") — consider whether the binary itself is the smuggled conclusion

### Anti-triggers (skill MUST refuse jurisdiction)
- Operator asks a pure factual question with no decision attached ("did the migration apply?", "is the server up?") → refuse; there is no framing to reduce, the answer is empirical
- Operator describes a feedback-loop-dominated / over-time problem → defer to `/map-feedback-loops`
- Operator needs to pick between options and the framing of the choice is not in question → defer to `/decide-under-uncertainty`
- Operator needs to locate the rate-limiting step in a flow → defer to `/diagnose-bottleneck`

---

## Minimum Viable Input (MVI) — Component 1

Per `.claude/skills/_shared/anti-anchoring-guard.md` Component 1, the skill refuses to proceed below MVI.

### Required MVI fields

| Field | Validation predicate |
|-------|----------------------|
| `subject` | Contains an actual claim, proposal, or protocol gate phrased as a stateable question — NOT a bare topic noun ("Hermes", "performance") and NOT a noun phrase that merely implies a decision without stating one ("Hermes adoption", "the caching layer") |
| `input_type` | One of `proposal` / `claim` / `protocol_gate` |
| `default_action` | One sentence — what the operator would do without the skill's reduction (required for counterfactual) |
| `hypothesis_provenance` | One of `operator` / `prior_skill` / `session_history` / `generative_primitive` — required when `proposed_reduction` is non-null |
| `source_hypothesis` | Upstream handoff block — required when `hypothesis_provenance` is `prior_skill` or `generative_primitive` (for `generative_primitive` it carries `generated_at` + `project_root`) |

### Below-MVI handling

When MVI fails, emit the structured insufficient-input error per shared library Component 1 Step 1.3. NEVER fabricate an irreducible question from below-MVI input. Two below-MVI shapes are common for this skill:

- **(a) A bare topic noun** ("Hermes", "performance") — there is no framing to reduce.
- **(b) A noun phrase that implies a decision but states no question** ("Hermes adoption", "the caching layer") — there is still no stated question to extract verbatim in Step 4.1.

Both fail the `subject` predicate. The insufficient-input error MUST instruct the operator to restate `subject` as a complete question or proposal containing a verb — e.g. "Should we adopt Hermes?", not "Hermes adoption". A stated question can be reduced; a topic cannot.

---

## Procedure

The procedure runs in eleven steps (1 through 10, with Step 8.5). Each gating step has a halt condition; the skill exits with a structured verdict at the first halt.

### Step 1 — Scope boundary check

Determine whether the subject is a *decision framing* (a claim, proposal, or protocol gate that informs an action). If the subject is:

- A pure factual yes/no with no decision attached → halt with `SCOPE_REFUSAL`; redirect: "this is an empirical question — verify it directly; there is no framing to reduce."
- A dynamic / over-time behaviour question → halt with `SCOPE_REFUSAL`; redirect to `/map-feedback-loops`.
- A flow-constraint-location question → halt with `SCOPE_REFUSAL`; redirect to `/diagnose-bottleneck`.

A choice-proposal ("should we do A, B, or C?") is **in jurisdiction** — the skill reduces it; it does not refuse it. (Reducing a choice-proposal is the skill's central use case; the Hermes failure was exactly this shape.)

### Step 2 — MVI gate

Per shared library Component 1 Step 1.2. Halt with the structured insufficient-input error if any MVI predicate fails — including the `subject` noun-phrase case in the MVI section above.

### Step 3 — Anti-anchoring guard branch

Per shared library Component 2. If `proposed_reduction` is null, skip the compare and proceed to Step 4 directly with no anchoring concern. If `proposed_reduction` is non-null, branch by `hypothesis_provenance`:

- `operator` → Branch A (standard): run the independent reduction in Step 4 BEFORE comparing to the operator's proposed reduction in Step 7.
- `prior_skill` → Branch B (validate-upstream): rerun the upstream skill with an alternative scope frame; check stability per shared library Step 2.2 Branch B.
- `session_history` → Branch C: emit the operator-confirmation question first, then re-route (see Step 7 Branch C for the full procedure and terminal guard).
- `generative_primitive` → Branch D (bounded-tag standard guard): the proposed reduction arrived from a generative workshop skill (e.g. a `DESTINATION.md` being audited). Run the bounds check per shared library Step 2.2 Branch D — verify `source_hypothesis.project_root` matches the current project AND `source_hypothesis.generated_at` is within the staleness window (default: 21 calendar days); see Step 7 Branch D. Validate-upstream is NEVER run for `generative_primitive`.

The independent reduction in Step 4 runs in every branch — it is never skipped because an operator supplied a candidate.

### Step 4 — Independent reduction (the core)

Run WITHOUT referencing `proposed_reduction`.

**4.1 — Extract** the stated question verbatim. Record `stated_question`. If the subject cannot be extracted as a stated question verbatim — because it is a noun phrase, not a question or proposal — halt and route back to Step 2 as an MVI failure. NEVER paraphrase a question into existence; a fabricated `stated_question` poisons every downstream step.

**4.2 — Confirm `input_type`** and select the reduction question:

| `input_type` | Reduction question asked at each layer |
|--------------|----------------------------------------|
| `proposal` ("should we do X?") | "X is a means — to what end? What is X in service of?" |
| `claim` ("X is better than Y") | "Better at what, measured how, for what purpose? What end does the comparison serve?" |
| `protocol_gate` ("reproducibility check") | "What is this gate testing for, in plain terms? What is its first-principles purpose?" |

**4.3 — Iterative reduction.** Apply the reduction question. The answer becomes the next layer's question. Repeat. Record each layer as `{layer, question, means_or_end}`.

**4.4 — Means-vs-end test (under-reduction guard).** Before accepting any candidate as irreducible, test it: is this question a *means* (an action question — "should we do Y?") or an *end* (an outcome/value question — "what outcome do we want?")? If means → keep reducing. A means-question is never the floor. This is the AP4 guard.

**4.5 — Decision-relevance floor (over-reduction guard).** Stop at the deepest *end*-question whose answer still discriminates the action in front of the operator. The test: "if I reduce one layer deeper, does the answer to that deeper question change what the operator should do right now?" If no → the current layer is the floor. Going deeper produces philosophy, not leverage. Record `floor_layer` and `why_floor` — `why_floor` MUST name the specific deeper question that was tested and state why its answer does not discriminate the action. This is the AP3 guard.

**4.6 — Vocabulary strip.** Restate the irreducible question for a domain-outsider — strip project-specific vocabulary, acronyms, and inherited terms. Record `irreducible_question`.

Output of Step 4: `independent_reduction` (the irreducible question) + `reduction_chain` + `decision_relevance_floor`.

### Step 5 — Delta table

Compare the original framing to the irreducible question. For each element the framing carries that the irreducible question does NOT, add a delta-table row classified as:

| Classification | Definition | Materiality test |
|----------------|------------|------------------|
| `added_constraint` | The framing narrows the solution space (e.g., "adopt OR build" excludes wait / partial / nothing) | `material` if the excluded options are genuinely viable; `cosmetic` if not |
| `presupposition` | The framing assumes something true without establishing it (e.g., "we need capability X now") | `material` if the presupposition is load-bearing AND unverified; `cosmetic` if confirmed or non-load-bearing |
| `smuggled_conclusion` | The framing has partly pre-answered the question (e.g., "should we adopt Hermes" pre-selects Hermes as the axis and adoption as on the table) | `material` almost always — a smuggled conclusion is rarely cosmetic |

**For `protocol_gate` inputs only** — also run the method-vs-gate comparison. Record `method_vs_gate`: the gate's first-principles purpose (from Step 4), the method as actually executed, and the dropped content. Dropped content is recorded as a `smuggled_conclusion` row in the delta table. (This is the Hermes pattern: gate "reproducibility check" → method "build-cost estimate" → dropped "hands-on data on whether the tool works in our environment".)

### Step 6 — Framing verdict

Derive `framing_verdict` strictly from the delta table — it is never assigned by impression:

| Verdict | Trigger |
|---------|---------|
| `SOUND` | No material delta-table entries; the irreducible question ≈ the stated question modulo vocabulary. The framing is honest. |
| `ADDS_CONSTRAINTS` | Material `added_constraint` and/or `presupposition` entries, but no material `smuggled_conclusion`. The framing is defensible IF the operator confirms the additions are intended — surface them for confirmation. |
| `SMUGGLES_CONCLUSIONS` | At least one material `smuggled_conclusion`. The framing pre-answers the question; the proposal should not proceed inside this frame until reframed. |

### Step 7 — Compare (when `proposed_reduction` present)

Per shared library Component 2.

- **Branch A (`operator`)** — `independent_reduction` vs `proposed_reduction`:

  | Verdict | Trigger | Behaviour |
  |---------|---------|-----------|
  | `AGREED` | Independent reduction matches the operator's proposed reduction | Proceed; log "anti-anchoring verified" |
  | `DISAGREED` | They differ | Present BOTH; do not silently pick; ask the operator OR carry both forward |
  | `INCONCLUSIVE` | The subject is too thin to discriminate between the two | Flag as insufficient-input even if MVI passed |

- **Branch B (`prior_skill`)** — validate-upstream per shared library Step 2.2 Branch B. Verdict is `validate_upstream_stable` or `validate_upstream_unstable`. NEVER return a plain agree/disagree verdict for `prior_skill` provenance.
- **Branch C (`session_history`)** — emit the operator-confirmation question first (per shared library Step 2.2 Branch C), then re-route:
  - "Mine" → re-route to Branch A.
  - "Claude proposed it" → re-route to Branch B with a *synthesised* `source_hypothesis` block: `upstream_skill: claude_session`, `upstream_invocation_id: null`, `hypothesis_text` = the operator-parroted statement. This synthesised block satisfies the `prior_skill` requirement — the `true_when_provenance_is_prior_skill` predicate is met by the synthesised block, not by a real upstream invocation.
  - **Terminal guard**: if the operator does not resolve provenance after ONE re-ask (ambiguous response per shared library Step 2.2 Branch C), halt with `verdict: INSUFFICIENT_INPUT` and `mvi.missing: ["hypothesis_provenance — unresolved session_history ambiguity"]`. Branch C MUST NOT terminate in `anti_anchoring.verdict: not_applicable` — `not_applicable` is reserved exclusively for `proposed_reduction == null`.
- **Branch D (`generative_primitive`)** — bounded-tag standard guard per shared library Step 2.2 Branch D. The `proposed_reduction` arrived from a generative workshop skill (e.g. a `DESTINATION.md` authored by the destination-authoring skill, now being audited). Run the bounds check:
  - **Both bounds pass** (`source_hypothesis.project_root` matches the current project AND `source_hypothesis.generated_at` is within the staleness window) → treat the input as `operator` provenance and run Branch A: the independent reduction (Step 4) AND the three-class compare both run normally. A `generative_primitive` input is NOT rubber-stamped — `DISAGREED` remains reachable if the independent reduction contradicts the proposed reduction.
  - **`project_root` mismatch OR `generated_at` stale** → DOWNGRADE: re-classify provenance as `operator`, run Branch A, and record in `reasoning_chain`: "input was `generative_primitive`-tagged but the tag is cross-project or beyond the staleness window — provenance downgraded to `operator`; full standard guard applied."
  - A `generative_primitive` input arriving without both `source_hypothesis.generated_at` and `source_hypothesis.project_root` is a Component 1 input-validation failure — halt with `verdict: INSUFFICIENT_INPUT`.
  - Validate-upstream (Branch B) is NEVER run for `generative_primitive` — a generative skill's output is non-deterministic and would always fail the stability check.

**Below-floor check (over-reduction guard applied to operator input).** If the operator's `proposed_reduction` sits BELOW the decision-relevance floor (the operator over-reduced — e.g. "the real question is the company's purpose"), set `anti_anchoring.below_floor_flag: true` and name it explicitly in the reasoning chain: "proposed reduction sits below the decision-relevance floor — it no longer discriminates the action; the floor is [X]." The verdict is `DISAGREED` with the floor reason named.

### Step 8 — Counterfactual statement (Component 3)

Per shared library Component 3. `default_action` is what the operator would do without the skill (typically: "proceed inside the stated frame"). `skill_recommendation` is what the skill recommends (typically: "reframe to the irreducible question before deciding" — or "proceed; framing is sound"). Emit the four-field structure. If `framing_verdict` is `SOUND` and the reduction surfaced nothing material, `difference` is `none` or `marginal` → the skill self-flags `ADVISORY_PENDING` (the reduction earned no leverage for this case — the AP6 cosmetic-reduction guard).

### Step 8.5 — Confidence assignment

`confidence` is assigned explicitly — it is never a default. Assign it from the evidence basis of the delta-table materiality classifications:

- `HIGH` — the materiality classifications rest on observable evidence: a counted set of excluded viable options, a stated record, a named method-vs-gate substitution.
- `MEDIUM` — materiality rests on inference rather than observable evidence, OR Step 9 cannot produce a specific-observable falsifier (the shared library Component 4 Step 4.3 downgrade).
- `LOW` — the subject is too thin for an authoritative framing verdict.

A `SMUGGLES_CONCLUSIONS` verdict whose material delta rows rest on observable evidence MUST be `HIGH` — the skill may NOT self-assign `MEDIUM` to dodge the Step 9 falsifier requirement. When confidence is genuinely `MEDIUM` because no specific-observable falsifier exists, the output records the downgrade reason in `advisory_pending_reasons` or alongside the `falsifier` field.

### Step 9 — Falsifier (Component 4 when HIGH confidence)

Per shared library Component 4. Required when `confidence: HIGH` and `framing_verdict: SMUGGLES_CONCLUSIONS`. Name a specific observable that would show the framing was actually fine — not generic "contrary evidence". Example for a Hermes-shaped case: "Falsified by: a written record showing 'wait' and 'partial adoption' were explicitly considered and ruled out with stated reasons before the adopt-or-build framing was set — if that record exists, the two-options constraint was a deliberate scoping decision, not a smuggled conclusion." Include timeframe and operator response. If no specific-observable falsifier can be produced, the confidence is `MEDIUM` per Step 8.5 and the absence reason is recorded.

### Step 10 — Reframe recommendation

- If `SMUGGLES_CONCLUSIONS` or material `ADDS_CONSTRAINTS`: state the `reframed_question` (= the irreducible question, optionally re-expanded with the material constraints made explicit and re-labelled as deliberate choices the operator can accept or reject). State the `recommended_action`: re-run the decision inside the reframed question.
- If `SOUND`: `reframed_question: null`; `recommended_action`: "proceed — framing is honest. If the next step is an option-choice, hand off to `/decide-under-uncertainty`."

---

## Output Schema

```yaml
skill: reduce-to-first-principles
version: 1.0
verdict: <PASS | ADVISORY_PENDING | SCOPE_REFUSAL | INSUFFICIENT_INPUT>
  # PASS = framing audited, all Verification Gates pass.
  # ADVISORY_PENDING = SOUND framing with nothing material (AP6) OR a Verification Gate failed.
confidence: <HIGH | MEDIUM | LOW>   # assigned by Step 8.5 — never defaulted

mvi:
  passed: <bool>
  missing: <list[string]>

scope:
  in_jurisdiction: <bool>
  input_type: <proposal | claim | protocol_gate>
  redirect: <skill_name | null>

reduction:
  stated_question: <string verbatim>
  input_type: <proposal | claim | protocol_gate>
  reduction_chain:
    - layer: <int>
      question: <string>
      means_or_end: <means | end>
  irreducible_question: <string — vocabulary-stripped>
  decision_relevance_floor:
    floor_layer: <int>
    why_floor: <string — names the specific deeper question tested and why its answer does not discriminate the action>

delta_table:
  - framing_element: <string>
    classification: <added_constraint | presupposition | smuggled_conclusion>
    materiality: <material | cosmetic>
    explanation: <string>

method_vs_gate:            # only when input_type == protocol_gate
  gate_first_principles_purpose: <string>
  method_as_executed: <string>
  dropped_content: <string | null>

framing_verdict: <SOUND | ADDS_CONSTRAINTS | SMUGGLES_CONCLUSIONS>   # derived strictly from delta_table per Step 6

anti_anchoring:
  hypothesis_provenance: <operator | prior_skill | session_history | generative_primitive | not_applicable>
  operator_proposed_reduction: <string | null>
  independent_reduction: <string>   # domain alias for the shared library's mandatory `independent_recommendation` field (anti-anchoring-guard.md Step 2.3)
  verdict: <AGREED | DISAGREED | INCONCLUSIVE | validate_upstream_stable | validate_upstream_unstable | not_applicable>
    # not_applicable is valid ONLY when proposed_reduction == null
  below_floor_flag: <bool>
  reasoning_chain: <list[step]>

counterfactual:
  default_action: <string>
  skill_recommendation: <string>
  difference: <none | marginal | substantial | transformative>
  skill_leverage: <string 1-3 sentences with named evidence>

falsifier:                 # required when confidence == HIGH and framing_verdict == SMUGGLES_CONCLUSIONS
  specific_observable: <string>
  timeframe: <string>
  operator_response_if_triggered: <string>

reframe:
  reframed_question: <string | null>   # null when framing_verdict == SOUND
  recommended_action: <string>

source_hypothesis:         # OMIT ENTIRELY when not applicable — present ONLY when this skill's output feeds a downstream skill
  provenance: <operator | prior_skill | session_history | generative_primitive>
  upstream_skill: <string | null>
  upstream_invocation_id: <string | null>
  hypothesis_text: <string>

advisory_pending_reasons: <list[string]>

invocation_metadata:
  timestamp: <ISO 8601 UTC>
  skill_version: 1.0
  invocation_id: <uuid>
```

---

## Anti-Patterns the Skill Must Refuse

| Anti-pattern | Detection signal | Defence |
|--------------|------------------|---------|
| **AP1 — Accept vague input** | `subject` is a bare topic noun or a question-less noun phrase | Step 2 halts with structured insufficient-input error |
| **AP2 — Accept proposed reduction without challenge** | `proposed_reduction` non-null; independent reduction not run | Step 4 runs in every branch; output struct must carry `anti_anchoring.independent_reduction` |
| **AP3 — Over-reduce past the decision-relevance floor** | `irreducible_question` is a philosophy question whose answer does not discriminate the action | Step 4.5 floor test is mandatory; `why_floor` must name the deeper question tested |
| **AP4 — Under-reduce (means-question called irreducible)** | `irreducible_question` is still an action question ("should we do Y?") | Step 4.4 means-vs-end test is mandatory; a `means` candidate is never the floor |
| **AP5 — Manufacture a smuggled conclusion** | `framing_verdict: SMUGGLES_CONCLUSIONS` on a framing that is genuinely honest | `SOUND` is a valid, common verdict; never invent delta-table rows to justify the invocation |
| **AP6 — Cosmetic reduction on a tactical question** | Reduced form ≈ stated form; nothing material surfaced | Step 8 counterfactual gate; `difference: none\|marginal` → `ADVISORY_PENDING`, not `PASS` |
| **AP7 — Reduce a pure factual claim** | `subject` is an empirical yes/no with no decision framing | Step 1 halts with `SCOPE_REFUSAL` |
| **AP8 — Apply Branch A to `prior_skill` provenance** | Output emits AGREED/DISAGREED while `source_hypothesis.upstream_skill` is non-null | Step 3 routes `prior_skill` to Branch B (validate-upstream) |

---

## Escalation Rules — When to Defer to Other Skills

| Signal | Defer to | Reason |
|--------|----------|--------|
| Subject is dynamic / over-time behaviour | `/map-feedback-loops` | Wrong skill class — this skill reduces framings, not system dynamics |
| Framing verdict is `SOUND` and the next step is an option-choice | `/decide-under-uncertainty` | The framing is audited; the choice now needs evidence-weighted decision tooling |
| Subject is a flow-constraint-location question | `/diagnose-bottleneck` | Wrong skill class — that skill locates rate-limiting steps |
| Reduction surfaces second-order / compounding effects worth mapping | `/map-feedback-loops` (Primitive 2, when shipped) | Reduction names the irreducible question; loop-mapping projects its consequences |

---

## Hidden Risks the Skill Surfaces (Not Silent)

1. **The framing is sound and the skill found nothing** — surfaced as `ADVISORY_PENDING` with `difference: none|marginal`; the skill does not manufacture a finding.
2. **The reduction itself could be wrong** — `falsifier` field names the specific observable that would show the framing was actually fine.
3. **The operator over-reduced** — `anti_anchoring.below_floor_flag` surfaces it; the skill names the decision-relevance floor explicitly rather than silently accepting a philosophy-level reduction.
4. **A protocol gate's method has drifted from its purpose** — `method_vs_gate.dropped_content` names exactly what the method dropped relative to the gate's first-principles purpose.
5. **Reframing has a cost** — Step 10's `recommended_action` is a re-run of the decision; the skill states this is a real cost, not a free correction, so the operator weighs it.

---

## Tests — Required Before Skill Ships

Behavioural acceptance tests per spec §5. The skill cannot be considered shipped until all fifteen return correct behaviour. Tests 1-7 are the seven required cases (per `.claude/rules/diagnostic-skill-anti-anchoring.md`); Test 8 is the cross-skill chain case (required because this skill supports `prior_skill` provenance); Tests 9-14 are additional coverage added after the Session 6 Day 2 code-council surfaced gaps in input-type, branch, and confidence coverage; Test 15 is the Branch D `generative_primitive` case (added 2026-05-18 — Define-Destination Phase A part 2; mirrors shared library test case 9).

### Test 1 — Happy path (a proposal with a real smuggled conclusion)

**Input**: `subject` = "Should we adopt Hermes Agent or build a native equivalent?"; `input_type: proposal`; `default_action` = "run an 8-agent council on the adopt-vs-build question."

**Expected behaviour**: skill reduces to an irreducible question of the shape "what is the cheapest reliable path to the user-visible value we want?"; delta table names the `added_constraint` (exactly two options — adopt XOR build-native, excluding wait / partial / cherry-pick / adopt-on-VPS) as material, and the `presupposition` ("we need this capability now") as material; `framing_verdict: SMUGGLES_CONCLUSIONS`; reframe recommendation issued; falsifier present.

**Verification**: `verdict == PASS`; `framing_verdict == SMUGGLES_CONCLUSIONS`; delta table has ≥1 material row; `reframe.reframed_question` non-null; `falsifier` has all three sub-fields populated — `specific_observable` is a named record/count/date (NOT "contrary evidence"), plus `timeframe` and `operator_response_if_triggered`.

### Test 2 — Adversarial anchored (operator's proposed reduction disagrees)

**Input**: `subject` as Test 1; `proposed_reduction` = "the real question is just which option is cheaper to build"; `hypothesis_provenance: operator`; `default_action` supplied.

**Expected behaviour**: independent reduction runs first and produces the cheapest-reliable-path question; comparison finds the operator's proposed reduction still smuggles "build cost is the deciding axis"; `anti_anchoring.verdict == DISAGREED`; both reductions presented; no silent pick.

**Verification**: `anti_anchoring.verdict == DISAGREED`; output carries both `independent_reduction` and `operator_proposed_reduction`; skill does not silently adopt either.

### Test 3 — Vague input (bare topic, no stateable question)

**Input**: `subject` = "Hermes"; `input_type: proposal`.

**Expected behaviour**: MVI insufficient-input error; structured response with an example input template.

**Verification**: `verdict == INSUFFICIENT_INPUT`; `mvi.missing` includes `subject` (no stateable question) and `default_action`; no fabricated irreducible question.

### Test 4 — Empty input (no subject)

**Input**: skill invoked with `subject: null`.

**Expected behaviour**: structured error requesting input; example input format provided; no fabrication.

**Verification**: `verdict == INSUFFICIENT_INPUT`; `mvi.passed == false`; `mvi.missing` includes `subject`; output contains an `example_input` block.

### Test 5 — Out-of-scope (pure factual question)

**Input**: `subject` = "Did the schema migration apply successfully?"; `input_type: claim`.

**Expected behaviour**: skill refuses jurisdiction — this is an empirical yes/no with no decision framing; redirects to direct verification; does NOT produce a reduction.

**Verification**: `verdict == SCOPE_REFUSAL`; `scope.in_jurisdiction == false`; `scope.redirect` populated; no `reduction` block produced.

### Test 6 — Same-as-default counterfactual (question already at first principles)

**Input**: `subject` = "What is the cheapest reliable path to deliver the in-session-learning value we want?"; `input_type: proposal`; `default_action` = "answer this question directly."

**Expected behaviour**: independent reduction finds the stated question is already at the decision-relevance floor; delta table empty of material rows; `framing_verdict: SOUND`; `counterfactual.difference: none`; skill self-flags `ADVISORY_PENDING`.

**Verification**: `verdict == ADVISORY_PENDING`; `framing_verdict == SOUND`; `advisory_pending_reasons` includes both `"counterfactual difference below substantial threshold"` (the shared library's verbatim reason string) and `"framing verdict is SOUND — question already at first principles"` as two distinct list entries.

### Test 7 — Non-author-domain test

**Input**: `subject` = "Should the depot buy a third delivery truck or sub-contract the overflow loads?"; `input_type: proposal`; `default_action` supplied. (A freight-dispatch context — NOT a synthesis-programme or real-estate context.)

**Expected behaviour**: skill produces a reduction with generic vocabulary; irreducible question of the shape "what is the cheapest reliable way to clear the overflow loads we are committed to?"; delta table names the two-options `added_constraint` (buy-truck XOR sub-contract, excluding route-rescheduling, demand-shaping, refusing-the-overflow); no real-estate / no programme-specific assumptions.

**Verification**: output vocabulary is generic (no MAO/ARV/programme-codename patterns); reduction applies cleanly in the freight context; delta table is freight-relevant.

### Test 8 — Cross-skill chain (`prior_skill` provenance)

**Input**: `subject` as Test 1; `proposed_reduction` = output of an upstream `/diagnose-bottleneck` invocation; `hypothesis_provenance: prior_skill`; `source_hypothesis` populated with `upstream_skill` and `upstream_invocation_id`.

**Expected behaviour**: Branch B fires; the upstream skill's output is re-derived under an alternative scope frame; stability is checked; verdict is `validate_upstream_stable` OR `validate_upstream_unstable`.

**Verification**: `anti_anchoring.verdict` is one of `validate_upstream_stable` / `validate_upstream_unstable` — and is NEVER one of `AGREED` / `DISAGREED` / `INCONCLUSIVE` for `prior_skill` provenance (AP8); if unstable, the skill BLOCKS and does not emit a downstream framing verdict.

### Test 9 — `claim` input type

**Input**: `subject` = "Our new caching layer is better than the old one"; `input_type: claim`; `default_action` = "accept the claim and move on."

**Expected behaviour**: Step 4.2 `claim` sub-procedure runs — the reduction chain asks "better at what, measured how, for what purpose?"; the irreducible question surfaces the implicit metric and implicit end; the delta table flags the unstated metric as a `presupposition`.

**Verification**: `reduction.input_type == claim`; `reduction_chain` shows the "better at what / for what purpose" layers; delta table contains a `presupposition` row for the unstated comparison metric.

### Test 10 — `protocol_gate` happy path (method-vs-gate)

**Input**: `subject` = "the 'reproducibility check' gate of our competitor-evaluation protocol — its method was a build-cost-vs-integration-cost estimate"; `input_type: protocol_gate`; `default_action` = "treat the gate as satisfied by the estimate comparison."

**Expected behaviour**: Step 5 runs the method-vs-gate comparison; `method_vs_gate.gate_first_principles_purpose` ≈ "test whether the competitor's claim holds when run in our environment"; `method_as_executed` ≈ "build-cost estimate"; `dropped_content` ≈ "hands-on data on whether the tool works in our environment"; the dropped content appears as a material `smuggled_conclusion` row.

**Verification**: `reduction.input_type == protocol_gate`; `method_vs_gate` fully populated; `method_vs_gate.dropped_content` non-null; `framing_verdict == SMUGGLES_CONCLUSIONS`.

### Test 11 — `session_history` provenance (Branch C)

**Input**: `subject` as Test 1; `proposed_reduction` non-null; `hypothesis_provenance: session_history`.

**Expected behaviour**: the skill emits the operator-confirmation question BEFORE running the compare; "Mine" → re-routes to Branch A; "Claude proposed it" → re-routes to Branch B with a synthesised `source_hypothesis` (`upstream_skill: claude_session`); an ambiguous response that is still unresolved after one re-ask → halt.

**Verification**: the confirmation question fires before any compare; `anti_anchoring.verdict` is never silently `not_applicable`; unresolved ambiguity → `verdict == INSUFFICIENT_INPUT` with `mvi.missing` naming the unresolved provenance.

### Test 12 — Operator over-reduction (`below_floor_flag`)

**Input**: `subject` as Test 1; `proposed_reduction` = "the real question is what the company exists to do"; `hypothesis_provenance: operator`.

**Expected behaviour**: independent reduction stops at the decision-relevance floor; the operator's proposed reduction is recognised as sitting BELOW that floor (a philosophy question that does not discriminate the action); `anti_anchoring.below_floor_flag` is set true.

**Verification**: `anti_anchoring.below_floor_flag == true`; `anti_anchoring.verdict == DISAGREED`; the reasoning chain names the decision-relevance floor and states why the operator's proposed reduction sits below it.

### Test 13 — Honest multi-layer framing (AP5 guard)

**Input**: `subject` = "Should we add a database index on the property-search column?"; `input_type: proposal`; `default_action` = "add the index."

**Expected behaviour**: a genuine multi-layer reduction runs ("add index" is a means → "make the property search fast enough"); the framing is honest — the binary is not false (the index either helps or does not), nothing is presupposed or smuggled; the delta table has no material rows (cosmetic at most). The skill does NOT fabricate a `smuggled_conclusion` to justify the invocation.

**Verification**: `framing_verdict == SOUND`; delta table has zero `material` rows; no `smuggled_conclusion` row; `verdict == ADVISORY_PENDING` (counterfactual difference `none`/`marginal`).

### Test 14 — HIGH-confidence falsifier requirement / MEDIUM downgrade

**Input**: a proposal whose framing smuggles a conclusion but for which no specific-observable falsifier can be named (the case rests on inference, not an observable record/count).

**Expected behaviour**: Step 9 cannot produce a specific-observable falsifier; per Step 8.5 the confidence is `MEDIUM`, not `HIGH`; the absence of a falsifier is acceptable at `MEDIUM` and the downgrade reason is recorded. A `SMUGGLES_CONCLUSIONS` verdict at `HIGH` confidence without a falsifier is INVALID.

**Verification**: `confidence == MEDIUM`; `falsifier` absent is acceptable; the downgrade reason is recorded in `advisory_pending_reasons` or alongside the falsifier field; no `confidence: HIGH` + `SMUGGLES_CONCLUSIONS` + empty `falsifier` output is ever emitted.

### Test 15 — Branch D (`generative_primitive` provenance)

**Input**: `subject` as Test 1; `proposed_reduction` = the end-state of a `DESTINATION.md` authored by the destination-authoring skill; `hypothesis_provenance: generative_primitive`; `source_hypothesis` carrying `upstream_skill` (the destination-authoring skill), `generated_at` (an in-window ISO date), and `project_root` (the current project).

**Expected behaviour**: Step 3 routes to Branch D; the bounds check passes (`project_root` matches, `generated_at` in window); the input is treated as `operator` provenance and Branch A runs — the independent reduction (Step 4) AND the three-class compare both run normally; validate-upstream is NEVER run. A stale or cross-project tag → provenance downgrades to `operator` with the reason recorded in `reasoning_chain`. A `generative_primitive` input MISSING `generated_at` / `project_root` → Component 1 input-validation failure.

**Verification**: `anti_anchoring.hypothesis_provenance == generative_primitive` (or `operator` with a downgrade reason in `reasoning_chain` for the stale/cross-project sub-case); `anti_anchoring.verdict` is one of `AGREED` / `DISAGREED` / `INCONCLUSIVE` — and is NEVER `validate_upstream_stable` / `validate_upstream_unstable` for `generative_primitive` provenance; the independent reduction ran (`independent_reduction` populated); a `generative_primitive` input missing the bounds fields → `verdict == INSUFFICIENT_INPUT`.

---

## Verification Gates (Self-Check Before Returning PASS)

Before the skill emits `verdict: PASS`, it must self-check:

| Gate | Pass condition |
|------|----------------|
| MVI | All MVI predicates passed; `mvi.passed: true` |
| Scope | Boundary check ran; `scope.in_jurisdiction: true` |
| Means-vs-end | `reduction_chain` is non-empty AND its final entry has `means_or_end: end` AND `irreducible_question` is not phrased as an action question ("should we…", "do we…") |
| Decision-relevance floor | `decision_relevance_floor.why_floor` names the specific deeper question tested and why its answer does not discriminate the action — a `why_floor` that names no deeper question fails the gate |
| Delta table | Every framing element present in the stated question but absent from the irreducible question has a delta-table row |
| Framing verdict | `framing_verdict` populated AND consistent with the delta table: `SMUGGLES_CONCLUSIONS` iff ≥1 material `smuggled_conclusion` row; `ADDS_CONSTRAINTS` iff material `added_constraint`/`presupposition` rows and no material smuggled row; `SOUND` iff no material rows |
| Anti-anchoring | Independent reduction ran; if `proposed_reduction` present, `anti_anchoring.verdict` populated per the correct branch; `not_applicable` used ONLY when `proposed_reduction` is null |
| Counterfactual | Statement present; `counterfactual.difference` is one of four values |
| Confidence | `confidence` assigned per Step 8.5; `verdict: PASS` requires `confidence` ∈ {HIGH, MEDIUM} — a completed reduction at `confidence: LOW` emits `ADVISORY_PENDING` |
| Falsifier | Present when `confidence: HIGH` and `framing_verdict: SMUGGLES_CONCLUSIONS`, with specific observable + timeframe + operator response |

If any gate fails self-check, the skill returns `ADVISORY_PENDING` instead of `PASS` with `advisory_pending_reasons` populated.

---

## Composition with Other Skills

| Skill / agent | Composition |
|---------------|-------------|
| Reframer agent (`.claude/agents/council/reframer.md`) | This skill is the formal version of the Reframer's inline analytical primitive 5. Once all five primitives ship, the Reframer is patched to call this skill and the inline version is deleted (continuation §7). |
| `/diagnose-bottleneck`, `/map-feedback-loops`, `/decide-under-uncertainty` | Sibling diagnostics. This skill may run BEFORE any of them — reduce the framing first, then locate the constraint / map the loops / make the choice inside an audited frame. |
| `/decide-under-uncertainty` | Cross-skill chain: a `SOUND` framing verdict from this skill hands off to `/decide-under-uncertainty` for the option-choice. A reduction of this skill's output may also flow INTO a downstream skill as `source_hypothesis` with `provenance: prior_skill`. |
| `/code-council`, `/code-forge` | When a reviewer meets operator pushback in a diff context, this skill (with the future Primitive 4 frame-vs-input classifier) reduces the pushback's underlying question. |
| `.claude/skills/_shared/anti-anchoring-guard.md` | This skill cites Components 1-4. All anti-anchoring logic lives in the shared library, not here. |

---

## Strategic Alignment

**ROADMAP item(s) this advances**:
- Operational Intelligence Synthesis Programme — Session 6, Primitive 1 of the framing-audit skill suite
- Methodology codification (first-principles reduction is now a callable tool, not an inline best-effort step in one agent)
- The agency's NewClaw + NewMem builds (this suite is their upstream framing-audit dependency)

**ROADMAP item(s) this REJECTS**:
- First-principles reduction remaining trapped inline in the Reframer agent (un-callable, un-composable, un-propagatable)
- A reduction skill with no stop-criterion (would over-reduce into philosophy or under-reduce into means-questions — AP3/AP4)

**If this skill advances nothing**: the framing-audit suite stalls at one artefact (the Reframer agent); the Hermes failure mode stays a reflex-only defence with no callable tool behind it.

---

## References

- Skill spec: `specs/06_REDUCE_TO_FIRST_PRINCIPLES_SKILL.md`
- Shared library: `.claude/skills/_shared/anti-anchoring-guard.md`
- Authority rule: `.claude/rules/diagnostic-skill-anti-anchoring.md`
- Verification gate: `.claude/rules/doctrine-verification-gate.md`
- Shape template: `.claude/skills/diagnose-bottleneck/SKILL.md`
- Reframer agent (composes with): `.claude/agents/council/reframer.md`
- Continuation: `continuations/SYNTHESIS-PROGRAMME-SKILL-SUITE-MASTER-CONTINUATION-2026-05-17.md`

---

*Skill v1.0 authored 2026-05-17 in Session 6 of the Operational Intelligence Synthesis Programme. Primitive 1 of 5 in the framing-audit skill suite. Net-new — no doctrine doc; derived from the Agency-Main discoveries report (2026-05-14) and the Reframer's analytical primitive 5. Cites the shared anti-anchoring guard library. Hardened post-authoring by the Session 6 Day 2 code-council (framing-verdict gate, Branch C terminal, confidence-assignment step, six added test cases). Triple verification: Gate 1 deletion test PASS (named consumers — Primitives 2-5, the Reframer patch, /code-council pushback handling, the Hermes re-run test); Gate 2 code-council ADVISORY → findings fixed; Gate 3 real-decision test DEFERRED to the Session 10 Hermes re-run.*
