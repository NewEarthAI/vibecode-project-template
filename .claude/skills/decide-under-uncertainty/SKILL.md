---
name: decide-under-uncertainty
description: |
  Decision-Quality diagnostic. Operator supplies a named decision with ≥2 candidate options;
  skill returns a single verdict (PROCEED / DEFER / REFRAME) plus recommended option, with
  mandatory anti-anchoring guard, counterfactual statement vs operator's default, falsifiability
  marker on HIGH-confidence output, P5 AI-confidence-asymmetry check, P3 regret-minimisation
  framing when probabilities are operator-assigned or model-default, and detection of workshop
  top-3 biases (planning fallacy, base-rate neglect, overconfidence). Supports cross-skill chain
  handoff from /diagnose-bottleneck and /map-feedback-loops via validate-upstream mode.
  Use when: "should we do A or B", "help me decide", "this decision under uncertainty", "we
  have two options", "which path forward", "stress-test my decision", "I'm about to commit
  to X — sanity check", "the council was split — adjudicate".
  Do NOT use for: snapshot bottleneck (use /diagnose-bottleneck); dynamic feedback diagnosis
  (use /map-feedback-loops); pure values / aesthetics where no evidence could update belief;
  decisions where operator has no authority at the recommended layer; single-option non-
  decisions; multi-agent strategic game theory (Nash equilibria — out of MVP).
classification: capability-uplift
version: 1.0
created: 2026-05-12
operationalises: docs/operational-doctrine/03_decision-quality.md
spec: specs/05_DECIDE_UNDER_UNCERTAINTY_SKILL.md
shared_library: .claude/skills/_shared/anti-anchoring-guard.md
allowed-tools: Read, Write, Glob, Grep, Bash, AskUserQuestion, Agent
user-invocable: true
parameters:
  - name: decision_name
    type: string
    required: true
    description: Specific named decision (not "what should I do?")
  - name: candidate_options
    type: list
    required: true
    description: ≥2 options, each with description + ≥1 discriminating_observable
  - name: asymmetric_payoff_confirmation
    type: boolean
    required: true
    description: Operator confirms ≥1 option's worst case differs materially from others
  - name: probability_source
    type: enum
    required: true
    description: One of data-derived | operator-assigned | model-default; auto-ADVISORY when model-default
  - name: operator_decision_authority
    type: enum
    required: true
    description: One of sole | shared | advisory | none | unknown; unknown→one clarifying question; none→out-of-scope redirect
  - name: hypothesis_provenance
    type: enum
    required: true
    description: One of operator | prior_skill | session_history | generative_primitive (per shared anti-anchoring library Component 2)
  - name: operator_hypothesis
    type: string
    required: true
    description: Operator's preferred option (the one they'd act on without skill input)
  - name: default_action
    type: string
    required: true
    description: What operator would do without skill input (required for counterfactual gate)
  - name: source_hypothesis
    type: object
    required: when_hypothesis_provenance_is_prior_skill_or_generative_primitive
    description: Upstream skill identifier + invocation_id + verbatim hypothesis text. When provenance is generative_primitive the block additionally carries generated_at (ISO date) and project_root — the bounds-check fields per shared library Step 2.2 Branch D.
---

# /decide-under-uncertainty — Decision-Quality Diagnostic

**Status**: v1.0 (Session 4 of Operational Intelligence Synthesis Programme — 2026-05-12)
**Operationalises**: `docs/operational-doctrine/03_decision-quality.md`
**Skill spec**: `specs/05_DECIDE_UNDER_UNCERTAINTY_SKILL.md`
**Cites shared library**: `.claude/skills/_shared/anti-anchoring-guard.md` (post-Phase-3.5 patch)
**First skill** to support cross-skill chain validate-upstream mode (test 8 is novel)

---

## Purpose

This skill runs the Decision-Quality doctrine's 9-step application checklist mechanically and returns ONE verdict (PROCEED / DEFER / REFRAME) plus a recommended option. It is a single-diagnostic-verdict skill — it does NOT combine four schools of decision theory into one output. It runs the doctrine's procedure and emits one structured verdict.

The skill exists because operators bring biased framings ("I'm leaning toward X — confirm?"), AI sessions propose options that get treated as operator hypotheses (`session_history` provenance), and upstream diagnostic skills produce option-class outputs that get re-anchored downstream (`prior_skill` provenance). The skill structurally protects against all three.

**Use this skill when**:
- Two or more genuine options exist with at least one discriminating observable
- The decision matters enough to justify 5-15 min skill invocation
- The operator has authority to act on the recommended option
- The decision involves uncertainty — at least one option's outcome is not foregone

**Do NOT use this skill when**:
- Question is "where is the bottleneck right now?" → `/diagnose-bottleneck`
- Question is "why does this behave this way over time?" → `/map-feedback-loops`
- Pure values / aesthetic / ethical decisions where no evidence could update belief
- Operator has no authority at the recommended layer
- Single-option "decisions" where the second option is structurally null
- Multi-agent strategic game-theoretic problems (Nash equilibria — out of MVP)
- Knightian uncertainty (probability distribution itself unknown) — skill flags and switches to regret-minimisation framing per doctrine P3

---

## Scope Boundary Diagnostic

Operator runs before invocation; skill re-runs at MVI step:

1. Is this question Decision-Quality in scope per doctrine §3?
2. Are there ≥2 genuine options?
3. Is at least one option's outcome observable in a meaningful timeframe?
4. Does operator have authority to act on the recommended option?

If "no" on any → skill returns `verdict: SCOPE_REFUSAL` with redirect.

---

## Minimum Viable Input (MVI) — Component 1

Per `.claude/skills/_shared/anti-anchoring-guard.md` Component 1.

| Field | Type | Required | Validation predicate |
|-------|------|----------|----------------------|
| `decision_name` | string | YES | Non-empty; specific (not "what should I do?") |
| `candidate_options` | list[option] | YES | Length ≥ 2; each option has `description` + at least one `discriminating_observable` |
| `discriminating_observable` per option | string | YES | What evidence would distinguish this option's outcome from others |
| `asymmetric_payoff_confirmation` | boolean | YES | Operator confirms ≥1 option's worst case differs materially from others |
| `probability_source` | enum | YES | `data-derived` / `operator-assigned` / `model-default` — auto-ADVISORY downgrade on `model-default`; switch to regret-minimisation framing when `operator-assigned` or `model-default` |
| `operator_decision_authority` | enum | YES | `sole` / `shared` / `advisory` / `none` / `unknown` — `unknown` → ONE clarifying question; `none` → out-of-scope redirect |
| `hypothesis_provenance` | enum | YES | `operator` / `prior_skill` / `session_history` / `generative_primitive` per shared anti-anchoring library Component 2 |
| `operator_hypothesis` | string | YES | Operator's preferred option |
| `default_action` | string | YES | What operator would do without skill input |
| `source_hypothesis` | object | conditional | Required when `hypothesis_provenance: prior_skill` or `generative_primitive` (for `generative_primitive` it carries `generated_at` + `project_root`) |

### Below-MVI handling

Per shared library Component 1 Step 1.3 — structured insufficient-input error with example template. NEVER hallucinate a verdict from below-MVI input.

---

## Procedure

### Step 1 — Scope boundary check (Decision-Quality doctrine §3)

Run the 4-question boundary diagnostic above. If "no" on any, halt with scope refusal.

### Step 2 — MVI gate

Shared library Component 1 Step 1.2. Halt on any predicate failure.

### Step 3 — Authority unknown handler

If `operator_decision_authority: unknown`, emit ONE clarifying question to operator: "Who has the final call on this decision? You alone (`sole`), you with others (`shared`), you advise someone else (`advisory`), or someone else entirely (`none`)?" On response, re-enter the procedure at Step 1 with corrected authority value.

### Step 4 — Anti-anchoring guard (shared library Component 2)

Branch by `hypothesis_provenance`:

#### Branch A — `operator`

Apply Decision-Quality doctrine §11 Application Checklist Steps 3-9 WITHOUT referencing operator's named hypothesis. Produces independent recommended option. Then compare → AGREED / DISAGREED / INCONCLUSIVE.

#### Branch B — `prior_skill` (VALIDATE-UPSTREAM mode)

This is the novel work — first time the validate-upstream branch is exercised in code.

1. Read `source_hypothesis.upstream_skill` (typically `/diagnose-bottleneck` or `/map-feedback-loops`)
2. Re-run upstream skill with at least one alternative parameter (different scope frame, different time window, different operator-stated bias check)
3. Compare upstream output across runs:
   - Stable (same stage / loop / option emerges) → `validate_upstream_stable`; treat stabilised output as hypothesis; proceed to Branch A's remaining steps
   - Unstable (different output emerges) → `validate_upstream_unstable`; HALT with: "Upstream skill output unstable; cannot validate downstream against unstable hypothesis. Re-run upstream with consolidated parameters before proceeding." Do NOT produce a downstream verdict.

#### Branch C — `session_history`

Emit one clarifying question: "Is this hypothesis yours, or did Claude propose it earlier in this conversation? Hypothesis source affects how the anti-anchoring guard operates." On response, re-route to Branch A or Branch B with corrected provenance.

#### Branch D — `generative_primitive` (BOUNDED-TAG STANDARD guard)

The `operator_hypothesis` arrived from a generative workshop skill — most commonly an option named in a `DESTINATION.md` authored by the destination-authoring skill. A generative skill's output is non-deterministic, so Branch B's validate-upstream stability check would always report `unstable` and wrongly HALT. Branch D treats the input as operator-authored intent, but only after a bounds check per shared library Step 2.2 Branch D.

1. **Bounds check.** Verify `source_hypothesis.project_root` matches the current project AND `source_hypothesis.generated_at` is within the staleness window (default: 21 calendar days). A `generative_primitive` input arriving without both fields is a Component 1 input-validation failure.
2. **Branch by the bounds-check result:**
   - **Both pass** → treat the input as `operator` provenance and run Branch A — the independent application of §11 Steps 3-9 AND the three-class compare both run normally. A `generative_primitive` input is NOT rubber-stamped: `DISAGREED` remains reachable if the independent recommendation contradicts the operator's hypothesis.
   - **`project_root` mismatch OR `generated_at` stale** → DOWNGRADE: re-classify provenance as `operator`, run Branch A, and record in `reasoning_chain`: "input was `generative_primitive`-tagged but the tag is cross-project or beyond the staleness window — provenance downgraded to `operator`; full standard guard applied."
3. **Validate-upstream (Branch B) is NEVER run for `generative_primitive`.**

### Step 5 — Independent application of Decision-Quality §11 Steps 3-9

WITHOUT referencing operator's hypothesis:

1. **Step 3 — Estimate probabilities** (each option × each plausible outcome). If `probability_source: model-default`, mark all probability outputs as ESTIMATES not measurements
2. **Step 4 — Estimate payoffs** (each outcome × each option, in operator-relevant units)
3. **Step 5 — Compute Expected Value (EV)** when `probability_source: data-derived`; ELSE switch to regret-minimisation framing per P3 (`cost_of_being_wrong` per option)
4. **Step 6 — Apply bias detection** (workshop top-3): planning fallacy, base-rate neglect, overconfidence. For each, name detection signal observed + counter-procedure applied
5. **Step 7 — Apply operator-authority filter** — remove options operator cannot act on
6. **Step 8 — P5 AI-Confidence-Asymmetry check**: if any input came from an AI source (this skill, prior skill, council session), apply detection-signals. Pattern: "HIGH confidence + no reasoning chain" or "matches operator's stated preference exactly" or "100% accepted in chat" → operator must apply detection-signal check OR confidence auto-downgrades
7. **Step 9 — Single-verdict selection**: PROCEED (recommend option X with confidence Y) / DEFER (insufficient evidence; specify what would resolve) / REFRAME (decision is in wrong frame; redirect)

### Step 6 — Compare (Branch A only)

Per shared library Component 2 Branch A Step 3:
- AGREED → proceed with full output; "agreement is meaningful because it survived independent verification"
- DISAGREED → present BOTH operator's hypothesis and independent recommendation; do NOT pick silently
- INCONCLUSIVE → discriminating observables are weak; verdict insufficient-input even if MVI passed

### Step 7 — Counterfactual statement (shared library Component 3)

Emit four-field structure. If `difference: none` or `marginal`, flag ADVISORY-pending.

### Step 8 — Falsifier (shared library Component 4 when HIGH confidence)

Quality constraint per A7: specific observable + timeframe + operator response. Generic statements ("contrary evidence", "worse outcomes") are BLOCKING. If specific-observable cannot be stated → auto-downgrade confidence to MEDIUM.

---

## Output Schema (full — per spec §8)

```yaml
skill: decide-under-uncertainty
version: 1.0
decision_name: <string>
verdict: <PROCEED | DEFER | REFRAME>
recommended_option: <option from candidate_options or null when verdict != PROCEED>
confidence: <HIGH | MEDIUM | LOW>

mvi:
  probability_source: <data-derived | operator-assigned | model-default>
  operator_decision_authority: <sole | shared | advisory | none | unknown>
  asymmetric_payoff_confirmed: <bool>

anti_anchoring:
  hypothesis_provenance: <operator | prior_skill | session_history | generative_primitive>
  verdict: <AGREED | DISAGREED | INCONCLUSIVE | validate_upstream_stable | validate_upstream_unstable>
  independent_recommendation: <option | null>
  reasoning_chain: <list[step]>

counterfactual:
  default_action: <string>
  skill_recommendation: <string>
  difference: <none | marginal | substantial | transformative>
  skill_leverage: <string, 1-3 sentences with named evidence>

falsifier:  # required when confidence == HIGH
  specific_observable: <string>
  timeframe: <string>
  operator_response_if_triggered: <string>

source_hypothesis:
  provenance: <operator | prior_skill | session_history | generative_primitive>
  upstream_skill: <string | null>
  upstream_invocation_id: <string | null>
  hypothesis_text: <string>

bias_detection:  # workshop top-3
  - bias: planning_fallacy
    detected: <bool>
    detection_signal_observed: <string | null>
    counter_procedure_applied: <string | null>
  - bias: base_rate_neglect
    detected: <bool>
    detection_signal_observed: <string | null>
    counter_procedure_applied: <string | null>
  - bias: overconfidence
    detected: <bool>
    detection_signal_observed: <string | null>
    counter_procedure_applied: <string | null>

ai_confidence_check:  # P5
  applied: <bool>
  pattern_detected: <string | null>
  operator_response_required: <string | null>

cost_of_being_wrong:  # P3 regret-minimisation when probabilities not data-derived
  per_option:
    - option: <name>
      worst_case: <string>
      cost: <string>
      recoverability: <hours | days | weeks | months | never>
      forgone_upside_if_right: <string>

advisory_pending_reasons: <list[string]>

invocation_metadata:
  timestamp: <ISO 8601 UTC>
  skill_version: 1.0
  doctrine_version: <semver>
  invocation_id: <uuid>
```

---

## Anti-Patterns (per spec §10 — 7 detection signals operator can apply in real time)

| # | Anti-pattern | Detection signal | Defence |
|---|--------------|------------------|---------|
| **AP1** | "I'm just being thorough" — skill invoked on a decision below mattering threshold | `counterfactual.difference: none` AND decision impact is small | Skill returns ADVISORY-pending with "doctrine invocation cost may exceed decision value" note |
| **AP2** | "AI was confident, so I went with it" — operator accepts AI recommendation without P5 check | `ai_confidence_check.applied: false` while `source_hypothesis.provenance: session_history` | Skill BLOCKS until P5 check runs |
| **AP3** | "Three options: A/B/C — which one?" — operator framed as menu rather than directed call | Operator submits ≥3 options without preferring one (`operator_hypothesis` blank or "I don't know") | Skill redirects to brainstorming or `/council` (genuine deliberation tool), not this skill |
| **AP4** | "We averaged the council's view" — operator averaged disagreeing council agents into mid-range claim | Skill detects upstream council session with >30% spread + averaging in `default_action` | Skill applies doctrine §6.5 PAUSE rule; rejects averaged synthesis as input |
| **AP5** | "Falsifier is 'any contrary evidence'" — operator provides generic falsifier | `falsifier.specific_observable` is generic or empty | Skill auto-downgrades confidence to MEDIUM; flags falsifier-rot |
| **AP6** | "Probabilities are 0.6 and 0.4" — fabricated-probability theatre (doctrine FM2) | `probability_source ≠ data-derived` AND operator requests probability-weighted EV output | Skill auto-switches to regret-minimisation framing per P3 |
| **AP7** | "The skill agreed with me, so I'm right" — operator treats AGREED as confirmation | Operator does not apply falsifier check post-verdict | Skill's AGREED verdict explicitly states: "agreement is meaningful because it survived independent verification, not because the skill accepted your framing — you still need to state and watch the falsifier per Component 4" |

---

## Cross-Skill Chain (`prior_skill` provenance)

The composition with `/diagnose-bottleneck` and `/map-feedback-loops`:

```
operator question
       │
       ├── flow / capacity question ───────► /diagnose-bottleneck ──┐
       │                                                            │
       ├── dynamic / over-time question ──► /map-feedback-loops ────┤
       │                                                            │
       └── option / commitment question ──► /decide-under-uncertainty
                                                                    ▲
                                                                    │
                                  output of either upstream skill   │
                                  flows here for adjudication ──────┘
                                  with hypothesis_provenance: prior_skill
                                  triggering validate-upstream mode
```

**Chain example**: operator uses `/diagnose-bottleneck` on a slow workflow; output identifies Stage 3 as constraint. Operator faces decision: "hire at Stage 3, automate Stage 3, or restructure to bypass Stage 3?" This skill is invoked with `hypothesis_provenance: prior_skill`, `source_hypothesis.upstream_skill: diagnose-bottleneck`, `operator_hypothesis: automate Stage 3`. Skill triggers validate-upstream mode (re-runs `/diagnose-bottleneck` with alternative scope frame to confirm Stage 3 is robust as constraint). If stable, applies standard guard to the three candidate options. If unstable, HALTS with "upstream skill output unstable" message.

**Anti-pattern in composition**: invoking this skill with operator's hypothesis directly when the hypothesis ORIGINATED from upstream skill — silently triggers `operator` branch with hidden AI-generated anchor. Detection: `source_hypothesis.upstream_skill` is set but `hypothesis_provenance: operator`. Defence: skill input validation rejects this combination; forces operator to declare `prior_skill` provenance.

---

## Tests — Required Before Skill Ships

Per spec §9 — 7 mandatory tests (per shared library Required Test Cases) + 1 novel cross-skill chain test (test 8, added by Phase 3.5 rule patch) + 1 Branch D `generative_primitive` test (test 9, added 2026-05-18 — Define-Destination Phase A part 2; mirrors shared library test case 9).

### Test 1 — Happy path

**Input**: Well-formed MVI on a real decision under uncertainty. Example — `decision_name: "Hire SDR vs invest in marketing automation for Q3 lead-gen ramp"`, two options each with discriminating observables (cost-per-MQL, ramp-time-to-productivity), `probability_source: operator-assigned`, `operator_decision_authority: sole`, `hypothesis_provenance: operator`, `operator_hypothesis: hire SDR`, `default_action: "hire SDR per existing plan"`.

**Expected behaviour**: full output struct with all components populated; verdict is one of three valid classes (PROCEED / DEFER / REFRAME); falsifier present if HIGH confidence; bias detection ran; `probability_source: operator-assigned` triggered regret-minimisation framing.

**Verification**: `verdict ∈ {PROCEED, DEFER, REFRAME}`; output schema fully populated; `anti_anchoring.verdict` is AGREED/DISAGREED/INCONCLUSIVE (NOT validate_upstream_*).

### Test 2 — Adversarial anchored

**Input**: Operator names hypothesis that disagrees with discriminating observables. Example — operator hypothesises "automate Stage 3" while observable evidence (cost-per-stage, error-rate, time-to-build) better supports "restructure to bypass Stage 3."

**Expected behaviour**: anti-anchoring guard fires; `verdict: DISAGREED`; both operator's hypothesis and independent recommendation presented; no silent acceptance.

**Verification**: `anti_anchoring.verdict == DISAGREED`; output contains both options with reasoning.

### Test 3 — Vague input

**Input**: Description without `decision_name` or with single option (`candidate_options.length < 2`).

**Expected behaviour**: MVI insufficient-input error; example template returned.

**Verification**: `verdict == INSUFFICIENT_INPUT`; `mvi.missing` lists decision_name or candidate_options.

### Test 4 — Empty input

**Input**: Skill invoked with no scope (empty arguments).

**Expected behaviour**: structured error requesting input; no hallucination.

**Verification**: same as Test 3 with broader missing list.

### Test 5 — Out-of-scope

**Input**: Input describes a bottleneck-location problem (TOC territory) OR a dynamic-feedback problem (Systems Thinking territory).

**Expected behaviour**: skill refuses jurisdiction; redirects to `/diagnose-bottleneck` or `/map-feedback-loops`.

**Verification**: `verdict == SCOPE_REFUSAL`; `redirect` field populated.

### Test 6 — Same-as-default counterfactual

**Input**: Skill's independent recommendation matches operator's `default_action`.

**Expected behaviour**: `counterfactual.difference: none` or `marginal`; `advisory_pending_reasons` includes "counterfactual difference below substantial threshold"; verdict NOT PASS.

**Verification**: `verdict == DEFER` OR ADVISORY-pending marker present; `advisory_pending_reasons` populated.

### Test 7 — Non-author-domain

**Input**: A non-software decision (e.g., a real-estate JV-vs-direct-acquisition decision, or a hiring board-member decision, or a public-policy zoning-variance decision).

**Expected behaviour**: skill produces analysis without domain-specific assumptions; vocabulary stays generic; bias detection still applies workshop top-3 (operator may substitute domain-relevant biases manually).

**Verification**: output vocabulary not specific to software/SaaS; bias detection table populated.

### Test 8 — Cross-skill chain (NOVEL — first exercise of validate-upstream mode in code)

**Input**: Skill invoked with `hypothesis_provenance: prior_skill` and `source_hypothesis.upstream_skill: diagnose-bottleneck`. Example — operator ran `/diagnose-bottleneck` on a slow deal pipeline; output identified "legal contract negotiation" as constraint with confidence MEDIUM. Operator then asks this skill: "Should we hire another lawyer, automate contract templates, or restructure to bypass legal?" with `hypothesis_provenance: prior_skill`.

**Expected behaviour**:
1. Skill recognises chain handoff via `source_hypothesis.upstream_skill` non-null
2. Triggers Branch B (validate-upstream mode), NOT Branch A
3. Re-runs `/diagnose-bottleneck` with alternative scope frame (e.g., narrower time window OR different stakeholder framing)
4. Compares upstream output across runs
5. Emits `anti_anchoring.verdict: validate_upstream_stable` (if constraint still legal after re-run) OR `validate_upstream_unstable` (if different constraint emerges)
6. If stable → proceeds to standard guard treating stabilised output as hypothesis
7. If unstable → HALTS with block message

**Verification**: `anti_anchoring.verdict ∈ {validate_upstream_stable, validate_upstream_unstable}` — NOT AGREED/DISAGREED/INCONCLUSIVE. Skill demonstrably re-runs upstream skill (output schema includes `upstream_rerun_results` field documenting the alternative-parameter call). Chain-class invocation is detected, not silently treated as operator-named hypothesis.

This is the structural test that the Phase 3.5 rule patch is operational, not decorative. Code-council Gate 2 review must verify test 8 actually runs the upstream skill, not just claims to.

### Test 9 — Branch D (`generative_primitive` provenance)

**Input**: Skill invoked with `hypothesis_provenance: generative_primitive`. Example — the destination-authoring skill produced a `DESTINATION.md` whose backward chain names a choice between two intermediate routes; the operator invokes this skill to adjudicate, with `operator_hypothesis` = one of those routes; `source_hypothesis` carries `upstream_skill` (the destination-authoring skill), `generated_at` (an in-window ISO date), and `project_root` (the current project); `candidate_options` ≥ 2 each with discriminating observables.

**Expected behaviour**:
1. Step 4 routes to Branch D (NOT Branch B)
2. The bounds check passes (`project_root` matches the current project, `generated_at` within the staleness window)
3. The input is treated as `operator` provenance — the independent application of §11 Steps 3-9 (Step 5) AND the three-class compare (Step 6) both run normally; validate-upstream is NEVER run
4. A stale or cross-project tag → provenance downgrades to `operator` with the downgrade reason recorded in `reasoning_chain`
5. A `generative_primitive` input MISSING `generated_at` / `project_root` → Component 1 input-validation failure

**Verification**: `anti_anchoring.hypothesis_provenance == generative_primitive` (or `operator` with a downgrade reason in `reasoning_chain` for the stale/cross-project sub-case); `anti_anchoring.verdict ∈ {AGREED, DISAGREED, INCONCLUSIVE}` — and is NEVER `validate_upstream_stable` / `validate_upstream_unstable` for `generative_primitive` provenance; `anti_anchoring.independent_recommendation` populated (Step 5 ran); a `generative_primitive` input missing the bounds fields → `verdict == INSUFFICIENT_INPUT`.

---

## Verification Gates (Self-Check Before PASS)

| Gate | Pass condition |
|------|----------------|
| MVI | All MVI predicates passed |
| Scope | Boundary diagnostic ran; in_jurisdiction true |
| Authority | `operator_decision_authority ≠ unknown` after clarifying question |
| Anti-anchoring | Guard ran on hypothesis; verdict populated per the right branch |
| Bias detection | Workshop top-3 detection table populated |
| AI-confidence check | P5 applied when any AI input is present |
| Regret-minimisation framing | `cost_of_being_wrong` populated when `probability_source != data-derived` |
| Counterfactual | Statement present; `difference` is one of four values |
| Falsifier | Present when `confidence: HIGH` with specific observable + timeframe + operator response (quality constraint enforced) |
| Cross-skill chain handling | When `provenance: prior_skill`, verdict is `validate_upstream_{stable\|unstable}` |

If any gate fails, return ADVISORY-pending with reasons.

---

## Verification Gate Pass Criteria (per doctrine-specific rubric)

Per `doctrine-verification-gate.md` Gate 2 doctrine-specific rubric applied to this skill code:

| Axis | Pass condition | Status |
|------|----------------|--------|
| Falsifiability of Claims | Each component documents what falsifies it | PASS — Component 2 names provenance-mismatch; Component 4 names specific-observable absence; Component 1 names below-MVI |
| Scope Boundary Completeness | Skill explicitly names what it does NOT do with redirects | PASS — Section "Do NOT use this skill" + scope boundary diagnostic |
| Anti-Pattern Coverage | ≥5 anti-patterns with detection signals | PASS — 7 anti-patterns each with detection + defence |
| Application Checklist Actionability | Mechanical execution possible without re-deriving doctrine | PASS — Output schema is fully mechanical |
| Triple Gate Conformance | Counterfactual + redefined deletion test + scope boundary explicit | PASS — Components 1-4 + cross-skill chain conformant |

---

## Composition with Other Skills

| Skill | Composition |
|-------|-------------|
| `/diagnose-bottleneck` | Cross-skill chain upstream — its output may flow here as `source_hypothesis` with `provenance: prior_skill` |
| `/map-feedback-loops` | Cross-skill chain upstream — same as above |
| `/council --extended` | When operator faces decision after council session, this skill is the adjudication layer; AP4 catches averaged-council inputs |
| `.claude/skills/_shared/anti-anchoring-guard.md` | Cites Components 1-4 |

---

## Strategic Alignment

**ROADMAP item(s) this advances**:
- `/decide-under-uncertainty` skill (spec → code; first Decision-Quality runnable tool)
- Methodology codification (Decision-Quality doctrine now operational)
- Cross-skill chain pattern (FIRST exercise of validate-upstream mode in code — closes Edge Case Finder's silent-chain-break failure mode)
- Falsifier quality constraint (FIRST skill to enforce specific-observable + timeframe + operator-response in code)
- 3 mandatory provenance fields (FIRST skill to ship all three: hypothesis_provenance, probability_source, source_hypothesis)

**ROADMAP item(s) this REJECTS**:
- Fabricated-probability theatre (AP6 catch)
- Averaged-council theatre (AP4 catch)
- Generic falsifier theatre (AP5 catch via quality constraint)
- Self-confirming AGREED verdicts (AP7 catch)

**If this skill advances nothing**: Decision-Quality doctrine remains theory; cross-skill chain pattern remains documented but not testable; operators continue to invoke /council on decisions where Decision-Quality is the right framework; the silent-chain-break failure mode operates undetected.

---

## References

- Doctrine: `docs/operational-doctrine/03_decision-quality.md`
- Skill spec: `specs/05_DECIDE_UNDER_UNCERTAINTY_SKILL.md`
- Shared library: `.claude/skills/_shared/anti-anchoring-guard.md`
- Rule: `.claude/rules/diagnostic-skill-anti-anchoring.md` (post-Phase-3.5 patch)
- Verification gate rule: `.claude/rules/doctrine-verification-gate.md`
- Sibling skills: `.claude/skills/diagnose-bottleneck/SKILL.md`, `.claude/skills/map-feedback-loops/SKILL.md`
- Session 3 council: `council/sessions/2026-05-12-session-3-calibration-council.md` (A5 + A6 + A7 origin)

---

*Skill v1.0 authored 2026-05-12 in Session 4 of the Operational Intelligence Synthesis Programme. Operationalises Decision-Quality doctrine. First skill to ship cross-skill chain validate-upstream mode (test 8 novel). Cites shared anti-anchoring guard library. Triple verification: Gate 1 deletion test PASS (named consumers: every option-class decision across the agency entities; council adjudication layer; cross-skill chain target); Gate 2 code-council DEFERRED to fresh-context ceremony with doctrine-specific rubric; Gate 3 real-decision test DEFERRED (anti-sycophancy second-party constraint). First live invocation expected by 2026-06-11 per Session 3 A9 (30-day retire-or-use signal).*
