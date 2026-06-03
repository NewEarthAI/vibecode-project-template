---
name: map-feedback-loops
description: |
  Systems-Thinking diagnostic with two modes. SYSTEM mode (default): diagnoses systems
  with dynamic behaviour over time (oscillation, overshoot, plateau,
  regression-after-improvement, exponential growth, unintended consequences) — builds a
  causal loop diagram, classifies archetype (Senge's 8) when one fits, ranks
  interventions on Meadows' 12-level leverage hierarchy. DECISION mode (input_mode:
  decision): the systems-thinking second-order audit — projects the second-order effects
  of a named decision, the system as it BECOMES after the decision lands rather than as
  it is now, emitting feedback loops introduced/strengthened/weakened, compounding
  effects, delayed consequences with horizons, and structural couplings — traced as an
  order-tagged cascade (effect-of-effect, second-and-higher-order) across three time
  bands (immediate / near-term / long-term). Both modes
  produce a counterfactual vs operator's default action, emit a falsifier on
  HIGH-confidence verdicts, and run the mandatory anti-anchoring guard before accepting
  an operator-named archetype, leverage point, or dominant second-order effect.
  Use SYSTEM mode when: "diagnose this dynamic", "why does X behave this way over time",
  "find the feedback loops in Y", "map the system", "identify the archetype", "MRR
  plateaued after growth", "unintended consequence", "things got worse after we fixed Y".
  Use DECISION mode when: "what are the second-order effects of decision X", "what does
  this decision do to the system over time", "what compounds or breaks downstream if we
  do X", "second-order audit", "knock-on effects of X".
  Do NOT use for: snapshot bottleneck location (use /diagnose-bottleneck); option-choice
  adjudication between mutually exclusive options (use /decide-under-uncertainty — then
  re-invoke DECISION mode per chosen option); pure diagram-drawing requests with no
  diagnostic question.
classification: capability-uplift
version: 1.2
created: 2026-05-12
updated: 2026-05-17
operationalises: docs/operational-doctrine/02_systems-thinking.md
spec: specs/04_MAP_FEEDBACK_LOOPS_SKILL.md
shared_library: .claude/skills/_shared/anti-anchoring-guard.md
allowed-tools: Read, Write, Glob, Grep, Bash, AskUserQuestion, Agent
user-invocable: true
parameters:
  - name: input_mode
    type: enum
    required: false
    description: One of system | decision. Default system. Governs which MVI field set applies — see the MVI sections.
  # --- SYSTEM mode fields (required when input_mode is system or unset) ---
  - name: system_description
    type: string
    required: true_when_input_mode_system
    description: Named system with explicit boundary (what's in, what's out)
  - name: behaviour_pattern
    type: string
    required: true_when_input_mode_system
    description: Observed behaviour with timescale (e.g., "MRR grew 15%/mo for 9mo then flat for 6mo")
  - name: observed_stocks_flows
    type: list
    required: true_when_input_mode_system
    description: At least 2 observable stocks or rates with measurement context
  # --- DECISION mode fields (required when input_mode is decision) ---
  - name: decision
    type: string
    required: true_when_input_mode_decision
    description: One named decision stated as a concrete action — NOT an option-set. E.g. "build a native FTS5 session-recall layer in W4"
  - name: target_system
    type: string
    required: true_when_input_mode_decision
    description: The system the decision acts on, with explicit boundary (what's in, what's out)
  - name: system_current_state
    type: list
    required: true_when_input_mode_decision
    description: At least 2 observable stocks or structural facts describing the system BEFORE the decision lands
  - name: projection_horizon
    type: string
    required: true_when_input_mode_decision
    description: Time window for the second-order projection (e.g. "6 months", "2 years")
  - name: decision_status
    type: enum
    required: true_when_input_mode_decision
    description: One of committed | candidate
  # --- shared fields (both modes) ---
  - name: operator_hypothesis
    type: string
    required: false
    description: SYSTEM mode — operator's named archetype, dominant loop, or leverage point. DECISION mode — operator's named dominant second-order effect.
  - name: hypothesis_provenance
    type: enum
    required: true_when_operator_hypothesis_present
    description: One of operator | prior_skill | session_history | generative_primitive (per shared anti-anchoring library Component 2)
  - name: source_hypothesis
    type: object
    required: true_when_provenance_is_prior_skill_or_generative_primitive
    description: Upstream-skill handoff block per shared library Cross-Skill Composition section. When provenance is generative_primitive the block additionally carries generated_at (ISO date) and project_root — the bounds-check fields per shared library Step 2.2 Branch D.
  - name: default_action
    type: string
    required: true
    description: What operator would do without skill input (required for counterfactual gate, both modes)
  - name: operator_authority_layers
    type: list
    required: true
    description: Which leverage-hierarchy layers the operator can act on (filter for recommendations and mitigations)
---

# /map-feedback-loops — Systems-Thinking Diagnostic

**Status**: v1.2 (Session 9 of Operational Intelligence Synthesis Programme — 2026-05-17; amends DECISION mode with depth-cascade tracing + three time bands. v1.1 = Session 8 added DECISION mode / Primitive 2 second-order audit. v1.0 = Session 4, 2026-05-12)
**Operationalises**: `docs/operational-doctrine/02_systems-thinking.md`
**Skill spec**: `specs/04_MAP_FEEDBACK_LOOPS_SKILL.md`
**Cites shared library**: `.claude/skills/_shared/anti-anchoring-guard.md`

---

## Purpose

This skill operates on systems whose interesting behaviour is dynamic — patterns that show up only over time (oscillation, overshoot, plateau, regression-after-improvement, exponential growth, unintended consequences). It is NOT a notation tool (CLD-drawing for its own sake); it is a diagnostic that produces interventions ranked by leverage on Meadows' 12-level hierarchy.

The skill answers: which feedback loops are driving the observed behaviour, which archetype (if any) names the structure, and which intervention has the highest leverage the operator can act on?

**Use this skill when**:
- A growth curve flattened despite continued investment
- A "fix" produced a worse outcome later (fixes-that-fail archetype)
- A shared resource shows decline despite each user's rational behaviour (tragedy-of-the-commons)
- A short-term workaround keeps coming back because the root cause was not addressed (shifting-the-burden)
- Any pattern where the time dimension is load-bearing

**Do NOT use this skill when**:
- The question is "where is the bottleneck right now?" (use `/diagnose-bottleneck`)
- The question is "which option should I pick?" (use `/decide-under-uncertainty`)
- The request is pure notation ("draw a CLD for X") without a diagnostic question

---

## Two Modes

This skill runs in one of two modes, set by the `input_mode` parameter.

| Mode | `input_mode` | Input | Question answered |
|------|--------------|-------|-------------------|
| **System** (default) | `system` or unset | A system already in dynamic motion + an observed behaviour pattern | Which feedback loops drive the *observed* behaviour, and which intervention has the highest feasible leverage? |
| **Decision** (Primitive 2) | `decision` | A single named decision + the system it acts on + that system's current state | What does this decision do to the system *over time* — which feedback loops, compounding effects, delayed consequences, and structural couplings does it create, traced as an order-tagged cascade (second-and-higher-order) across three time bands (immediate / near-term / long-term)? |

**Everything from here to the `## Decision Mode` section describes SYSTEM mode** — the default, unchanged from v1.0. DECISION mode is the self-contained `## Decision Mode (input_mode: decision)` section below; it has its own MVI, procedure, output schema, anti-patterns, and tests, and reuses the same anti-anchoring guard library, the same CLD construction discipline, the same Senge archetypes, and the same Meadows leverage hierarchy.

**Mode boundary** — DECISION mode projects the second-order effects of *one* decision. It does NOT adjudicate an option-set ("hire vs automate vs restructure") — that is `/decide-under-uncertainty`. `/decide-under-uncertainty` MAY chain into DECISION mode per chosen option (cross-skill Branch B). An option-set passed to DECISION mode triggers a scope refusal with redirect.

---

## When to Invoke

### Explicit triggers
- "why does X keep cycling?", "the system oscillates", "we keep solving and re-solving this"
- "MRR plateaued / churn climbed / engagement dropped" with operator stating they tried more of the same with no effect
- "unintended consequence", "made things worse"
- Operator names an archetype ("I think this is limits-to-growth") and wants validation

### Anti-triggers (refuse jurisdiction)
- Static question, no temporal pattern → defer to `/diagnose-bottleneck`
- Option-choice question → defer to `/decide-under-uncertainty`
- Pure diagram request → respond with pointer to notation tools (out of scope)

---

## Minimum Viable Input (MVI) — Component 1

Per `.claude/skills/_shared/anti-anchoring-guard.md` Component 1.

### Required MVI fields

| Field | Validation predicate |
|-------|----------------------|
| `system_description` | Named target with explicit boundary (in / out / at-boundary) |
| `behaviour_pattern` | Pattern + timescale (e.g., "monthly active users grew 15%/mo for 9 months, then flat for 6 months despite 30% increase in marketing spend") |
| `observed_stocks_flows` | ≥2 observable stocks or rates with measurement context |
| `dynamic_question_confirmed` | Operator confirms question is about behaviour-over-time, not current-snapshot |
| `default_action` | One sentence; what operator would do without skill |
| `hypothesis_provenance` | Required when `operator_hypothesis` is non-null |
| `operator_authority_layers` | Which leverage-hierarchy layers (1-12) the operator can act on |

### Below-MVI handling

Per shared library Component 1 Step 1.3 — structured insufficient-input error with example template. NEVER hallucinate a CLD from below-MVI input.

---

## Procedure

### Step 1 — Scope boundary check (Systems Thinking doctrine §3)

If observed pattern is static-snapshot OR operator names a decision rather than a dynamic, halt with scope refusal + redirect to `/diagnose-bottleneck` or `/decide-under-uncertainty` as appropriate. The doctrine §3 boundary diagnostic determines applicability.

### Step 2 — MVI gate (shared library Component 1 Step 1.2)

Halt with insufficient-input error if any predicate fails.

### Step 3 — Anti-anchoring guard (shared library Component 2)

Branch by `hypothesis_provenance`:
- `operator` → Branch A (standard)
- `prior_skill` → Branch B (validate-upstream)
- `session_history` → Branch C (operator confirmation question)
- `generative_primitive` → Branch D (bounded-tag standard guard — the hypothesis arrived from a generative workshop skill, e.g. a `DESTINATION.md` being audited): verify the `source_hypothesis` bounds fields (`project_root` matches the current project AND `generated_at` within the staleness window, default 21 calendar days) per shared library Step 2.2 Branch D. Both bounds pass → run Branch A (standard); `project_root` mismatch OR `generated_at` stale → downgrade to `operator` and run Branch A, recording the downgrade reason in `reasoning_chain`; missing bounds fields → Component 1 input-validation failure. Validate-upstream (Branch B) is NEVER run for `generative_primitive`.

If `operator_hypothesis` is null, skip the compare; perform independent location only and set `anti_anchoring.verdict: not_applicable` and `anti_anchoring.hypothesis_provenance: not_applicable` (per `.claude/skills/_shared/anti-anchoring-guard.md` Component 2 Step 2.3 — `not_applicable` is valid only in the no-hypothesis case).

### Step 4 — Independent location

WITHOUT referencing operator's named hypothesis:

#### Step 4.1 — Causal loop diagram (CLD) construction

Per doctrine §6.1 + §6.2:
1. List stocks (≥2, ≤7 per doctrine §11.2)
2. List flows that change each stock
3. List information links influencing each flow
4. Verify every loop closes
5. Label each loop R (reinforcing) or B (balancing) with one-sentence behaviour description

#### Step 4.2 — Time-delay surfacing

For each information link, estimate delay magnitude. Classify per doctrine §6.5: material / information / decision. Flag any delay >20% of feedback-cycle time as load-bearing.

#### Step 4.3 — Archetype check

Compare CLD to each of Senge's 8 archetypes (doctrine §6.4). For each, score structural match 0.0-1.0 based on R+B+constraint-binding presence.

Verdict:
- Top archetype >0.7 AND second <0.5 → classify as that archetype
- Both >0.5 → classify as ambiguous; present both
- All <0.5 → "no archetype fits" (do NOT force a match — that's doctrine anti-pattern §9.5)

#### Step 4.4 — Leverage-point ranking

For each candidate intervention, score on Meadows' 12-level hierarchy (doctrine §6.3). Lower number = higher leverage (1 = paradigm; 12 = parameter).

#### Step 4.5 — Operator-authority filter

Remove candidates the operator cannot feasibly act on. Use `operator_authority_layers` input.

### Step 5 — Compare (when operator hypothesis present)

Per shared library Component 2 Branch A Step 3. Verdict in three classes: AGREED / DISAGREED / INCONCLUSIVE.

### Step 6 — Counterfactual statement (shared library Component 3)

Emit four-field structure. If `difference` is `none` or `marginal`, flag ADVISORY-pending.

### Step 7 — Falsifier (shared library Component 4 when HIGH confidence)

Name specific observable + timeframe + operator response. Generic statements are BLOCKING.

### Step 8 — Re-evaluation trigger

Systems with dynamic behaviour shift after intervention. Emit re-evaluation trigger: typically after N feedback cycles or M weeks, whichever is doctrine-relevant for the named system.

---

## Output Schema

```yaml
skill: map-feedback-loops
version: 1.2
input_mode: system
verdict: <PASS | ADVISORY_PENDING | SCOPE_REFUSAL | INSUFFICIENT_INPUT>
confidence: <HIGH | MEDIUM | LOW>

input:
  system: <string>
  boundary: { in: [...], out: [...], at_boundary: [...] }
  behaviour_pattern: <string + timescale>
  observed_stocks_flows: [...]
  operator_hypothesis: <string | null>

mvi_check:
  passed: <bool>
  missing: <list[string]>

scope:
  in_jurisdiction: <bool>
  redirect: <skill_or_doctrine | null>

anti_anchoring:
  hypothesis_provenance: <operator | prior_skill | session_history | generative_primitive | not_applicable>
  operator_hypothesis: <string | null>
  independent_location: <string>   # domain alias for the anti-anchoring-guard.md mandatory field `independent_recommendation` (SYSTEM mode: the located archetype/loop/leverage point; DECISION mode: the independently-projected dominant second-order effect)
  verdict: <AGREED | DISAGREED | INCONCLUSIVE | validate_upstream_stable | validate_upstream_unstable | not_applicable>
  reasoning_chain: <list[step]>

cld:
  stocks: [...]
  flows: [...]
  loops:
    - id: R1
      type: reinforcing
      description: <string>
    - id: B1
      type: balancing
      description: <string>

delays:
  - link: <string>
    estimated_duration: <value + unit>
    classification: <material | information | decision>
    load_bearing: <bool>

archetypes:
  - name: <one of Senge's 8>
    structural_match: <0.0-1.0>
    canonical_intervention: <string>
top_archetype: <archetype_name | ambiguous | none_fit>

leverage_points:
  - candidate: <string>
    level: <1-12>
    feasible_for_operator: <bool>

recommended_intervention:
  candidate: <string>
  level: <1-12>

counterfactual:
  default_action: <string>
  skill_recommendation: <string>
  difference: <none | marginal | substantial | transformative>
  skill_leverage: <string 1-3 sentences>

falsifier:  # required when confidence == HIGH
  specific_observable: <string>
  timeframe: <string>
  operator_response_if_triggered: <string>

source_hypothesis:
  provenance: <operator | prior_skill | session_history | generative_primitive>
  upstream_skill: <string | null>
  upstream_invocation_id: <string | null>
  hypothesis_text: <string>

re_evaluation_trigger:
  cadence: <string e.g. "after 2 feedback cycles (~8 weeks)">
  why: <string>

advisory_pending_reasons: <list[string]>

invocation_metadata:
  timestamp: <ISO 8601 UTC>
  skill_version: 1.2
  doctrine_version: <semver>
  invocation_id: <uuid>
```

---

## Decision Mode (`input_mode: decision`) — Second-Order Projection

**This is Primitive 2 of the First-Principles + Systems-Thinking skill suite** — the systems-thinking second-order audit. It exists because the agency's Hermes evaluation (2026-05-14) locked a verdict on a decision's *first-order* outcome — "native FTS5 capability ships" — without projecting what that decision did to the *system* over time. DECISION mode makes second-order projection a callable, mechanical step.

**"Second-order" is shorthand for second-AND-higher-order.** The audit traces effect → effect-of-effect → … as an order-tagged cascade (order 2, 3, 4, …), not a flat list that stops at order 2; and it sweeps three explicit time bands so an effect that lands in hours is not lost behind one that lands in years. The name "second-order audit" is kept as the established suite term (continuation §6, the Reframer); the `order` and `time_band` fields on every effect are what make the depth and the speed explicit.

SYSTEM mode reads a system already in motion. DECISION mode runs *before* the motion exists: it takes a named decision and projects the system **as it becomes after the decision lands** — not as it is now. The first-order outcome ("the thing the decision directly produces") is assumed; DECISION mode's entire job is everything downstream of that.

### When DECISION mode fires

`input_mode: decision` is set explicitly, AND the input is **one named decision** (committed or candidate) for which the operator wants the second-order consequences. Triggers: "what are the second-order effects of X", "what does this decision do to the system over time", "what compounds or breaks downstream if we do X", "second-order audit of decision X", "knock-on effects".

### Decision-Mode MVI (Component 1)

Per `.claude/skills/_shared/anti-anchoring-guard.md` Component 1. The skill refuses to proceed without ALL of:

| Field | Validation predicate |
|-------|----------------------|
| `decision` | A single decision stated as a concrete action with enough specificity to identify what changes structurally. "Build a native FTS5 session-recall layer in W4" passes; "improve search" fails. NOT an option-set. |
| `target_system` | Named system the decision acts on, WITH an explicit boundary — at least one `in` entity and at least one `out` entity. A system named without a boundary FAILS this predicate (a boundary-less target invites a hallucinated CLD). Same boundary discipline as SYSTEM mode. |
| `system_current_state` | ≥2 observable stocks or structural facts describing the system BEFORE the decision lands — the baseline the projection departs from |
| `projection_horizon` | A concrete time window (e.g. "6 months", "2 years"). Second-order effects without a horizon are unfalsifiable |
| `decision_status` | `committed` (already decided) or `candidate` (under consideration) — both project; status only frames the recommendation register |
| `default_action` | One sentence — what the operator would do without the skill (counterfactual gate, Component 3) |
| `hypothesis_provenance` | Required when `operator_hypothesis` is non-null |
| `operator_authority_layers` | Which leverage-hierarchy layers the operator can act on (filters mitigations/amplifiers) |

`operator_hypothesis` in DECISION mode is the operator's named **dominant second-order effect** (e.g. "I think the main knock-on is re-evaluation tax every time a competitor ships an FTS5 feature").

**Below-MVI handling**: structured insufficient-input error per shared library Component 1 Step 1.3. The most common DECISION-mode failure is a `decision` with no `target_system` — projecting onto an unnamed system hallucinates. NEVER project from below-MVI input.

### Decision-Mode scope refusals

| Input signal | Verdict | Redirect |
|--------------|---------|----------|
| Input is an option-set (≥2 mutually exclusive options) | `SCOPE_REFUSAL` | `/decide-under-uncertainty` — "DECISION mode projects ONE decision's second-order effects; adjudicate the option-set first, then re-invoke DECISION mode per chosen option" |
| Input is a system already in observed motion with a behaviour pattern, no decision named | `SCOPE_REFUSAL` | re-invoke with `input_mode: system` |
| `input_mode: decision` but the input is a static-snapshot bottleneck question | `SCOPE_REFUSAL` | `/diagnose-bottleneck` |

### Decision-Mode Procedure

#### Step D1 — Scope check

Confirm the input is a single decision + a target system, not an option-set and not a system-already-in-motion. Refuse + redirect per the table above if not.

**Discriminating test for the embedded-option-set case** — a `decision` phrased as one sentence can hide a fork (e.g. "build a native layer, falling back to integrating Hermes if W4 slips"). Apply: *can the `decision` be satisfied by exactly one structural intervention?*
- One intervention (a contingency or a sequence is still one decision) → single decision; proceed.
- Two or more interventions the operator must still choose between → option-set; `SCOPE_REFUSAL`, redirect `/decide-under-uncertainty` (DAP4).
- Genuinely ambiguous → do NOT proceed. Ask the operator to confirm it is one decision before projecting. The fail-safe direction is REFUSE — a wrongly-projected option-set is a confident wrong output; a wrongly-refused single decision costs one clarifying question.

#### Step D2 — MVI gate

Halt with structured insufficient-input error if any Decision-Mode MVI predicate fails. Predicate checks are on field *adequacy*, not just presence — specifically, `target_system` must carry an explicit boundary with at least one `in` and one `out` entity. A `target_system` string that names a system but supplies no boundary FAILS MVI here — do NOT proceed to Step D4.1 and build a CLD on it (a hallucinated boundary would otherwise slip past AP2, which fires only at draft time).

#### Step D3 — Anti-anchoring guard (shared library Component 2)

Branch by `hypothesis_provenance`. The operator's hypothesis here is a named dominant second-order effect. If `operator_hypothesis` is null, skip the compare; perform independent projection only and set `anti_anchoring.verdict: not_applicable`.

#### Step D4 — Second-order projection (independent)

WITHOUT referencing the operator's named hypothesis:

##### Step D4.1 — Baseline CLD

Build the causal loop diagram of `target_system` in its `system_current_state` — the system as-is, before the decision. Apply the same construction discipline as SYSTEM mode Step 4.1 (stocks ≥2 ≤7, flows, information links, every loop closes, every loop R/B-labelled with a one-sentence behaviour description).

##### Step D4.2 — Decision delta

Identify precisely what the decision changes in the baseline CLD: which stocks, flows, and information links it **adds**, **removes**, or **re-weights**. The decision is a structural intervention; name the intervention exactly. A decision that changes nothing structural is a parameter tweak — say so and downgrade confidence.

##### Step D4.3 — Projected CLD

Build the CLD of the system **as it becomes** after the decision lands: baseline CLD + decision delta, including any *new loops the decision closes* (a new flow plus a new information link can close a loop that did not exist before). Every new loop is R/B-labelled and closed, same discipline.

##### Step D4.4 — Second-order cascade extraction

DECISION mode traces an **order-tagged cascade**, not a flat list. From the projected CLD, extract effects in five sub-steps (D4.4.a–D4.4.e). Each effect MUST name the CLD element(s) that produce it — an effect not traceable to a loop, flow, or coupling in the projected CLD is speculation (see DAP2).

Each effect carries three independent attributes: its **type-class** (one of the four below), its **`order`** (its depth in the cascade), and its **`time_band`** (the speed at which it lands). Type, order, and time band are orthogonal — a third-order effect can be immediate; a second-order effect can be long-term.

**The four type-classes:**

- **Feedback loops** introduced / strengthened / weakened / polarity-flipped vs the baseline CLD
- **Compounding effects** — reinforcing loops the decision feeds; state the growth behaviour (doubling time, accumulation rate)
- **Delayed consequences** — a *discrete downstream consequence that is NOT itself a feedback loop, a compounding effect, or a structural coupling* — a one-off effect separated from its cause by a load-bearing time delay, each with an estimated horizon. The defining property is *discrete + non-structural*; the delay is its qualifying condition (an *immediate* discrete consequence is first-order-obvious and below the surfacing bar — so a `delayed_consequences` entry's `time_band` is always `near-term` or `long-term`, never `immediate`). Effects whose horizon exceeds `projection_horizon` are reported as `in_projection_horizon: false` — flagged, NOT dropped
- **Structural couplings** — new dependencies the decision creates between previously-independent parts of the system or the wider stack; each with a reversibility classification

###### Step D4.4.a — Order-2 extraction

From the decision delta, extract the **direct second-order effects** — the effects the decision sets off. Each is one of the four type-classes, names the producing CLD element(s), and gets `order: 2`, `produced_by: decision_delta`, and a unique `effect_id` (`SO1`, `SO2`, …). Order 1 is the assumed `first_order_outcome` — it is not in the cascade.

###### Step D4.4.b — Time-band tagging + immediate-first sweep

Tag every effect with a `time_band` — `immediate` (hours–days), `near-term` (weeks–months), or `long-term` (quarters–years). Sweep the bands **immediate first**, then near-term, then long-term. Immediate-first is deliberate: it counters the long-term bias that lets the first-hour ripple be skipped. The sweep is an ordering of attention applied while extracting — not a separate pass over a different CLD.

###### Step D4.4.c — Depth tracing

For each order-N effect, ask: *what does this effect itself set off?* Trace each order-(N+1) effect and give it the **full set of universal fields**: a unique `effect_id` (continuing the `SO1`, `SO2`, … sequence), `produced_by: <parent effect_id>`, a type-class, a `time_band`, `order: N+1`, and — by applying D4.4.d to it — a `terminal` value (plus `stop_reason` + `stop_detail` when `terminal: true`). Apply the same immediate-first ordering of attention (D4.4.b) at each depth level: consider immediate-band candidates before near-term before long-term. Continue order 3, order 4, … per branch. There is **no hardcoded depth limit** — "stop at exactly 3" is as arbitrary as stopping at 2. The per-branch stop rule (D4.4.d) is the limit.

###### Step D4.4.d — Per-branch stop rule

Stop tracing a branch when the candidate next-order effect meets any of:

- **(a) below materiality** — it touches no *load-bearing* element of the projected CLD. **Load-bearing is a binary structural test**: an element (stock / flow / loop / coupling) is load-bearing if and only if removing it from the projected CLD would break ≥1 closed loop OR eliminate ≥1 stock. An element appearing only in an information link with no loop closure is NOT load-bearing. A candidate effect that changes only non-load-bearing elements is below materiality. This fixed binary rule is named verbatim in the block-level `materiality_threshold` field. Parent effect: `terminal: true`, `stop_reason: below_materiality`.
- **(b) untriggerable** — it cannot be given a concrete `trigger_condition`. This is the DAP2 boundary (see the Decision-Mode Anti-Patterns table) promoted to a stop rule: an untriggerable next-order effect is **neither emitted nor traced past** — it is not speculation dressed as a finding. Parent effect: `terminal: true`, `stop_reason: untriggerable_next_order`.
- **(c) horizon exceeded** — its estimated landing time is beyond `projection_horizon`. Unlike (a), (b), and (d), the effect itself **IS emitted** (a delayed consequence carries `in_projection_horizon: false`; any class carries `stop_reason: horizon_exceeded`), but its own children are not traced. That effect: `terminal: true`, `stop_reason: horizon_exceeded`.
- **(d) cascade cycle** — the candidate next-order effect re-enters an element or effect already on this branch's `produced_by` ancestor chain (the cascade has looped back into a reinforcing or balancing loop already traced). That loop is already captured once — as a `feedback_loops` or `compounding_effects` entry with its `behaviour_over_time` / `growth_behaviour`; do NOT re-trace its iterations as deeper orders. Parent effect: `terminal: true`, `stop_reason: cascade_cycle`.

Every terminal effect also carries a one-line `stop_detail` naming the specific candidate that hit the stop and why (e.g. "the candidate 'minor UI copy churn' touches no load-bearing CLD element"). An effect with ≥1 traced child is `terminal: false` and carries neither `stop_reason` nor `stop_detail`.

###### Step D4.4.e — Band coverage check

Confirm every time band that falls within `projection_horizon` has either ≥1 effect (at any order) OR an explicit `empty_justification`. The `immediate` band is within every horizon, so it always needs effects-or-justification — an empty immediate band must be justified ("this decision has no hours-to-days ripple because X"), never silently absent. A band outside `projection_horizon` is recorded `in_horizon: false` and is not a coverage gap. Record the result in the `band_coverage` block.

##### Step D4.5 — Archetype check on the projected system

Compare the projected CLD to each of Senge's 8 archetypes (doctrine §6.4). The question is specifically: **did the decision move the system into an archetype it did not match before?** A decision that adds a symptomatic quick-fix loop can shift a healthy system into fixes-that-fail or shifting-the-burden. Score structural match 0.0-1.0; "no archetype fits" is a valid result (do not force a match).

##### Step D4.6 — Leverage-ranked responses

For each adverse projected second-order effect, produce a **mitigation** ranked on Meadows' 12-level hierarchy. For each beneficial effect, produce an **amplifier**. Apply the operator-authority filter (`operator_authority_layers`) — remove responses the operator cannot act on; if the highest-leverage response is outside the operator's authority, downgrade to the highest feasible level and flag the authority gap (same discipline as SYSTEM-mode AP6).

#### Step D5 — Compare (when operator hypothesis present)

Per shared library Component 2 Branch A Step 3: independent projection vs the operator's named dominant second-order effect. Three-class verdict — `AGREED` / `DISAGREED` / `INCONCLUSIVE`. On `DISAGREED`, present BOTH; never pick silently.

#### Step D6 — Counterfactual (Component 3)

Emit the four-field counterfactual. `default_action` is what the operator would do without the second-order audit (usually: act on the first-order outcome alone). If `difference` is `none` or `marginal`, flag `ADVISORY_PENDING` — the audit surfaced nothing the operator did not already see.

#### Step D7 — Falsifier (Component 4 when HIGH confidence)

A projected second-order effect at HIGH confidence MUST carry a falsifier: a specific observable + a timeframe **within `projection_horizon`** + the operator response if it fires. "What observation, by when, would show this projection wrong?" Generic falsifiers ("worse outcomes") are BLOCKING; downgrade to MEDIUM if no specific observable exists.

#### Step D8 — Re-evaluation trigger

A projection is a forecast; it must be checked against reality. Emit a re-evaluation trigger: re-run DECISION mode (or SYSTEM mode, once the system is in observed motion) after the decision lands + N feedback cycles, to compare the projection to what actually happened.

### Decision-Mode Output Schema

DECISION mode emits the shared blocks (`mvi_check`, `scope`, `anti_anchoring`, `counterfactual`, `falsifier`, `re_evaluation_trigger`, `advisory_pending_reasons`, `source_hypothesis`, `invocation_metadata`) plus:

```yaml
skill: map-feedback-loops
version: 1.2
input_mode: decision
verdict: <PASS | ADVISORY_PENDING | SCOPE_REFUSAL | INSUFFICIENT_INPUT>
confidence: <HIGH | MEDIUM | LOW>

decision:
  statement: <string>
  status: <committed | candidate>
target_system: <string>
boundary: { in: [...], out: [...], at_boundary: [...] }
projection_horizon: <string>
first_order_outcome: <string — the decision's direct intended result; assumed, not analysed>

baseline_cld:
  stocks: [...]
  flows: [...]
  loops: [ { id: R1, type: reinforcing, description: <string> }, ... ]

decision_delta:
  stocks_added: [...]
  flows_added: [...]
  links_added: [...]
  links_reweighted: [...]
  elements_removed: [...]

projected_cld:
  stocks: [...]
  flows: [...]
  loops: [ { id: R2, type: reinforcing, description: <string> }, ... ]

second_order:
  # --- block-level cascade metadata ---
  materiality_threshold: <string — the fixed binary structural rule D4.4.d(a) applied: an element is load-bearing iff removing it breaks >=1 closed loop OR eliminates >=1 stock>
  max_order_reached: <int — highest order any effect reached; >= 2>
  band_coverage:
    - { time_band: immediate,  in_horizon: <bool — true for any projection_horizon of days or longer>, effect_count: <int>, empty_justification: <string|null> }
    - { time_band: near-term,  in_horizon: <bool>, effect_count: <int>, empty_justification: <string|null> }
    - { time_band: long-term,  in_horizon: <bool>, effect_count: <int>, empty_justification: <string|null> }
  # --- EVERY effect entry below (all four classes) ALSO carries these 7 universal fields: ---
  #   effect_id:    <SO1, SO2, … — unique cascade id, distinct from CLD loop ids>
  #   order:        <int >= 2 — depth in the cascade>
  #   time_band:    <immediate | near-term | long-term>
  #   produced_by:  <decision_delta (order 2) | parent effect_id (order >= 3)>
  #   terminal:     <bool — true = no children traced from this effect>
  #   stop_reason:  <below_materiality | untriggerable_next_order | horizon_exceeded | cascade_cycle — present iff terminal: true>
  #   stop_detail:  <string — one line naming the specific candidate that hit the stop and why; present iff terminal: true>
  feedback_loops:
    - id: <loop id in projected_cld>
      change: <new | strengthened | weakened | polarity_flip>
      description: <string>
      behaviour_over_time: <string>
      trigger_condition: <string — what activates this loop; required, never null>
      # + the 7 universal fields
  compounding_effects:
    - effect: <string>
      driving_loop: <loop id>
      growth_behaviour: <string — doubling time / accumulation rate>
      # + the 7 universal fields
  delayed_consequences:
    - consequence: <string>
      estimated_horizon: <value + unit>
      in_projection_horizon: <bool>
      load_bearing_delay: <bool>
      # + the 7 universal fields (time_band constrained to near-term | long-term — never immediate)
  structural_couplings:
    - coupling: <string — what becomes dependent on what>
      previously_independent: <bool>
      reversibility: <reversible | costly_to_reverse | locked_in>
      # + the 7 universal fields

projected_archetype: <archetype name | ambiguous | none_fit>
archetype_shift: <string — did the decision move the system into a new archetype vs the baseline? MUST be the literal "none" when projected_archetype is none_fit AND the baseline CLD matched no archetype — a prose shift claim with no archetype on either end is forcing a match (AP5 class)>

recommended_response:
  for_adverse_effects:
    - mitigation: <string>
      level: <1-12>
      feasible_for_operator: <bool>
  for_beneficial_effects:
    - amplifier: <string>
      level: <1-12>
      feasible_for_operator: <bool>
```

### Decision-Mode Anti-Patterns the Skill Must Refuse

| Anti-pattern | Detection signal | Defence |
|--------------|------------------|---------|
| **DAP1 — First-order-only projection** | Output names the decision's direct intended outcome but `second_order` is empty or all four classes are absent | Return error; second-order content is the entire purpose of DECISION mode |
| **DAP2 — Speculative loop without trigger** | A projected feedback loop has `trigger_condition: null` or no named activating condition | Return error; mirrors the Reframer anti-pattern "second-order effects that are speculative without naming the conditions that make them real". Its boundary is also the D4.4.d depth stop rule (b) — an untriggerable *next-order* candidate is neither emitted nor traced past (`stop_reason: untriggerable_next_order`) |
| **DAP3 — Horizon-free delayed consequence** | A delayed consequence has no `estimated_horizon` | Return error; an unfalsifiable consequence is decoration |
| **DAP4 — Option-set smuggled as a decision** | The `decision` field contains ≥2 mutually exclusive options | `SCOPE_REFUSAL`; redirect to `/decide-under-uncertainty` |
| **DAP5 — Baseline skipped** | `projected_cld` is built without a `baseline_cld` — no delta is measurable | Return error; the projection is meaningless without the as-is baseline to measure the delta against |
| **DAP6 — Flat-list projection** | `second_order` is populated but flat or structurally inconsistent: ≥1 effect lacks `effect_id` / `order` / `produced_by` / `terminal`; OR a `terminal: true` effect lacks `stop_reason` or `stop_detail`; OR a `terminal: false` effect carries a `stop_reason` (contradiction); OR a `stop_reason` value is outside the declared enum; OR `band_coverage` is absent | Return error; the cascade tree (via `produced_by`) and the stop-rule application must be visible and internally consistent. Distinct from DAP1 (DAP1 = `second_order` *empty*; DAP6 = populated but with no depth structure). A genuinely shallow cascade — every effect `order: 2`, each `terminal: true` with a valid `stop_reason` + `stop_detail` — is NOT DAP6: that is the stop rule firing early, correctly recorded |

The SYSTEM-mode anti-patterns AP1-AP7 still apply to every CLD-construction sub-step (D4.1, D4.3) — map-without-bound, unlabelled-loop theatre, archetype-spotting without verification, paradigm-level rec without authority all carry over.

### Decision-Mode Tests — Required Before v1.2 Ships

Per `.claude/skills/_shared/anti-anchoring-guard.md` Required Test Cases. All 11 (DT1-DT11) plus the two scope-refusal variants DT5b/DT5c must return correct behaviour. These are ADDITIONAL to the 7 SYSTEM-mode tests in `## Tests` — the SYSTEM-mode tests must all still pass unchanged (backward compatibility). DT9 + DT10 were added in v1.2 (Session 9) to cover the depth cascade and the three-band time sweep.

**Anti-pattern coverage map**: DAP2 (speculative loop without trigger) is caught by DT1's verification gate ("every projected loop has a non-null `trigger_condition`"); DAP4 (option-set smuggled) by DT5; DAP6 (flat-list projection) by DT9's verification gate and the Depth-cascade verification gate. DAP1 (first-order-only projection), DAP3 (horizon-free delayed consequence), and DAP5 (baseline skipped) are caught by the Decision-Mode Verification Gates below — those gates run on EVERY output, so a draft tripping DAP1/DAP3/DAP5 fails the gate and returns `ADVISORY_PENDING` regardless of which test input produced it.

#### Decision Test DT1 — Happy path

**Input**: `input_mode: decision`; decision = "build a native FTS5 session-recall memory layer in W4 rather than integrate Hermes"; `target_system` = the agency's skill + cross-session-memory stack (boundary in: skills, the memory substrate, operator build-time; out: client-facing products); `system_current_state` = 4 facts (no native recall layer, ~80 installed skills, operator is sole builder, Hermes is the reference implementation); `projection_horizon` = "9 months"; `decision_status` = committed; operator hypothesis = "the dominant second-order effect is native-build expertise compounding"; `hypothesis_provenance: operator`.

**Expected**: full output; baseline CLD + decision delta + projected CLD; `second_order` populated across all four classes (e.g. compounding loop: native-build expertise; delayed consequence: re-evaluation tax each time a competitor ships an FTS5 feature; structural coupling: future skills depend on the native layer's API) and traced as an order-tagged cascade — ≥1 order-3 effect (e.g. native-build-expertise compounding [order 2] → future skills depend on the native API [order 3] → a competitor's FTS5 feature now triggers re-evaluation of the whole skill stack, not one layer [order 4]); archetype check on the projected system; counterfactual; falsifier if HIGH confidence.

**Verification**: `verdict == PASS` (or `ADVISORY_PENDING` if counterfactual marginal); every `second_order` schema field populated; every effect carries `effect_id` / `order` / `time_band` / `produced_by` / `terminal`; every projected loop has a non-null `trigger_condition`; `band_coverage` present with all three bands; `max_order_reached >= 3`.

#### Decision Test DT2 — Adversarial anchored

**Input**: operator names "native-build expertise compounding" as the dominant second-order effect with `hypothesis_provenance: operator`; the independent projection finds the dominant effect is integration-debt with Hermes-as-reference-implementation (a costly-to-reverse structural coupling).

**Expected**: `anti_anchoring.verdict == DISAGREED`; both the operator's named effect AND the independent dominant effect presented with reasoning; no silent acceptance.

#### Decision Test DT3 — Vague input

**Input**: `input_mode: decision`; decision = "we should modernise our search" with no `target_system`, no `system_current_state`, no `projection_horizon`.

**Expected**: `verdict == INSUFFICIENT_INPUT`; `mvi_check.missing` lists the absent fields; example input template returned.

#### Decision Test DT4 — Empty input

**Input**: `input_mode: decision` with `{}`.

**Expected**: structured insufficient-input error; no projection hallucinated.

#### Decision Test DT5 — Out-of-scope (option-set)

**Input**: `input_mode: decision`; decision = "should we hire two engineers, automate the legal step, or restructure to skip legal?"

**Expected**: `verdict == SCOPE_REFUSAL`; `scope.redirect == "/decide-under-uncertainty"`; message notes DECISION mode projects ONE decision — adjudicate first, then re-invoke per chosen option (DAP4 catch).

#### Decision Test DT5b — Out-of-scope (system already in motion)

**Input**: `input_mode: decision`; the input describes a system already in observed motion with a behaviour pattern ("our MRR plateaued after 9 months of growth despite more spend") and names no decision.

**Expected**: `verdict == SCOPE_REFUSAL`; the message redirects to re-invoke with `input_mode: system` — a system already in motion is SYSTEM mode's jurisdiction; DECISION mode projects a decision not yet visible in behaviour.

#### Decision Test DT5c — Out-of-scope (static-snapshot bottleneck)

**Input**: `input_mode: decision`; the input is a static-snapshot bottleneck question ("where is the bottleneck in our pipeline right now?").

**Expected**: `verdict == SCOPE_REFUSAL`; `scope.redirect == "/diagnose-bottleneck"`.

#### Decision Test DT6 — Same-as-default counterfactual

**Input**: the projected dominant response matches the operator's `default_action`.

**Expected**: `counterfactual.difference == none` or `marginal`; `verdict == ADVISORY_PENDING`; `advisory_pending_reasons` includes "counterfactual difference below substantial threshold".

#### Decision Test DT7 — Non-author-domain

**Input**: a freight-operations decision (NOT software): decision = "add a second depot 200km north"; `target_system` = a regional freight network (boundary in: trucks, depots, routes, drivers; out: client contracts); `system_current_state` = 3 facts (one depot, ~40 trucks, average route 380km); `projection_horizon` = "18 months".

**Expected**: projection produced without software-domain vocabulary; archetypes and the leverage hierarchy apply unmodified; second-order effects named in freight terms (e.g. compounding: depot draws drivers from the original depot's pool; delayed consequence: maintenance-capacity split; structural coupling: route planning now depends on two-depot balancing).

#### Decision Test DT8 — Cross-skill chain

**Input**: `input_mode: decision`; the decision arrives as the chosen option from `/decide-under-uncertainty`; `hypothesis_provenance: prior_skill`; `source_hypothesis.upstream_skill: decide-under-uncertainty`.

**Expected**: Branch B (validate-upstream) fires; `anti_anchoring.verdict` is `validate_upstream_stable` or `validate_upstream_unstable`; the standard `AGREED`/`DISAGREED`/`INCONCLUSIVE` verdict is NEVER returned for `prior_skill` provenance.

#### Decision Test DT9 — Depth cascade

**Input**: `input_mode: decision`; decision = "make the data team's nightly ETL job a hard dependency of the customer-facing analytics dashboard" (the dashboard currently reads a cached snapshot; the ETL job is best-effort); `target_system` = the analytics delivery stack (boundary in: ETL job, snapshot cache, dashboard, data-team on-call; out: the upstream source databases); `system_current_state` = 3 facts (ETL succeeds ~96% of nights, the dashboard currently never blocks on ETL, the data team has no formal on-call); `projection_horizon` = "6 months"; `decision_status` = candidate. No operator hypothesis.

**Expected**: a cascade with a clear 2→3→4 chain — order-2: a failed ETL night now blocks the dashboard (`produced_by: decision_delta`); order-3: blocked dashboards drive support tickets AND force the data team into reactive firefighting (each `produced_by` the order-2 `effect_id`); order-4: reactive firefighting crowds out ETL-hardening work — a reinforcing loop (`produced_by` an order-3 `effect_id`). At least one branch reaches a recorded stop via `below_materiality` or `untriggerable_next_order`, each carrying a `stop_detail`. The order-4 reinforcing loop, traced one step further, re-enters the order-2 "failed ETL night" effect — that branch therefore stops with `stop_reason: cascade_cycle` (the loop is captured once as a `feedback_loops` entry; its iterations are not re-traced as deeper orders). At least one traced effect has an estimated horizon beyond the 6-month `projection_horizon` (e.g. "un-hardened ETL eventually degrades all analytics permanently — horizon ~18 months"): it is emitted with `in_projection_horizon: false`, `terminal: true`, `stop_reason: horizon_exceeded`, and its children are NOT traced.

**Verification**: `max_order_reached >= 4`; every effect carries `effect_id` / `order` / `produced_by` / `terminal`; every `produced_by` resolves to `decision_delta` or an existing `effect_id`; every `terminal: true` effect has a `stop_reason` in {`below_materiality`, `untriggerable_next_order`, `horizon_exceeded`, `cascade_cycle`} plus a non-empty `stop_detail`; no `terminal: false` effect carries a `stop_reason`; ≥1 effect has `stop_reason: horizon_exceeded` with `in_projection_horizon: false` and no traced children; `band_coverage` is present; `materiality_threshold` is a non-empty string.

#### Decision Test DT10 — Time-band coverage

**Input**: `input_mode: decision`; decision = "switch the whole sales team to a new CRM next Monday with no parallel-run period"; `target_system` = the sales operation (boundary in: reps, the CRM, the pipeline data, sales managers; out: marketing, finance); `system_current_state` = 3 facts (12 reps, ~400 active opportunities, the current CRM holds 3 years of history); `projection_horizon` = "2 years"; `decision_status` = candidate. No operator hypothesis.

**Expected**: effects populated across all three bands — `immediate` (hours–days): reps lose access to working notes mid-deal, data entry stalls; `near-term` (weeks–months): pipeline-forecast accuracy drops while reps re-learn the tool; `long-term` (quarters–years): the cleaner data model compounds into better forecasting OR three years of un-migrated history becomes a permanent blind spot. The `immediate` band is swept and reported first.

**Verification**: `band_coverage` shows a non-zero `effect_count` for `immediate` AND `near-term` AND `long-term` (or an explicit non-null `empty_justification` for any genuinely empty in-horizon band); the `immediate` band entry is present in `band_coverage` and never silently absent (the observable proof that the immediate-first sweep ran); every effect carries a `time_band`; no `delayed_consequences` entry carries `time_band: immediate`.

#### Decision Test DT11 — Branch D (`generative_primitive` provenance)

**Input**: `input_mode: decision`; the decision arrives as the end-state of a `DESTINATION.md` authored by the destination-authoring skill, now being audited for its second-order effects; `hypothesis_provenance: generative_primitive`; `source_hypothesis` carrying `upstream_skill` (the destination-authoring skill), `generated_at` (an in-window ISO date), and `project_root` (the current project); operator hypothesis = a named dominant second-order effect.

**Expected**: Step D3 routes to Branch D; the bounds check passes (`project_root` matches, `generated_at` in window); the input is treated as `operator` provenance and the standard guard runs — the independent projection (Step D4) AND the three-class compare (Step D5) both run normally; validate-upstream is NEVER run. A stale or cross-project tag → provenance downgrades to `operator` with the reason recorded in `reasoning_chain`. A `generative_primitive` input MISSING `generated_at` / `project_root` → Component 1 input-validation failure.

**Verification**: `anti_anchoring.hypothesis_provenance == generative_primitive` (or `operator` with a downgrade reason in `reasoning_chain` for the stale/cross-project sub-case); `anti_anchoring.verdict` is one of `AGREED` / `DISAGREED` / `INCONCLUSIVE` — and is NEVER `validate_upstream_stable` / `validate_upstream_unstable` for `generative_primitive` provenance; the independent projection ran (`anti_anchoring.independent_location` populated); a `generative_primitive` input missing the bounds fields → `verdict == INSUFFICIENT_INPUT`.

### Decision-Mode Verification Gates (self-check before PASS)

| Gate | Pass condition |
|------|----------------|
| MVI | All Decision-Mode MVI predicates passed |
| Scope | Single decision + single target system confirmed; not an option-set |
| Anti-anchoring | Guard ran; `anti_anchoring.verdict` populated (`not_applicable` valid only if no operator hypothesis) |
| Baseline CLD | Built before the projected CLD; loops R/B-labelled and closed (DAP5) |
| Decision delta | The decision's structural change named exactly against the baseline CLD |
| Second-order content | All four effect classes considered; every projected loop has a `trigger_condition` (DAP1, DAP2) |
| Depth cascade | Every effect carries `effect_id` / `order` / `produced_by` / `terminal`; every `terminal: true` effect carries a `stop_reason` (in the declared enum) + a non-empty `stop_detail`; no `terminal: false` effect carries a `stop_reason`; every `produced_by` resolves to `decision_delta` or an existing `effect_id` (the cascade tree is connected) (DAP6) |
| Time-band coverage | Every band within `projection_horizon` has ≥1 effect OR a non-null `empty_justification`; the `immediate` band always has effects-or-justification; `band_coverage` block present |
| Horizons | Every delayed consequence has an `estimated_horizon`; out-of-horizon effects flagged not dropped (DAP3) |
| Counterfactual | Statement present; `difference` is one of the four values |
| Falsifier | Present when `confidence: HIGH` — specific observable + timeframe within `projection_horizon` + operator response |

If any gate fails, return `ADVISORY_PENDING` with reasons.

---

## Anti-Patterns the Skill Must Refuse (SYSTEM mode)

Per doctrine §9 — the skill MUST refuse to produce output if any of these are present in its draft analysis. DECISION mode adds DAP1-DAP6 in the `## Decision Mode` section; AP1-AP7 below still apply to DECISION mode's CLD-construction sub-steps (D4.1, D4.3).

| Anti-pattern | Detection signal | Defence |
|--------------|------------------|---------|
| **AP1 — Default-to-parameter** | Recommendation is level 11-12 with no documented infeasibility argument for higher levels | Skill returns ADVISORY-pending; requests operator to supply infeasibility argument OR accept lower-leverage recommendation |
| **AP2 — Map-without-bound** | CLD lacks any "boundary out" entities | Returns error requesting explicit boundary |
| **AP3 — Unlabelled-loop theatre** | Any loop in CLD lacks R/B label OR behaviour description | Returns error; loops without labels are diagrams, not models |
| **AP4 — Delay-blindness** | Recommendation involves a decision rule AND any load-bearing delay is unaddressed | Flags ADVISORY; intervention must reference delay handling |
| **AP5 — Archetype-spotting without verification** | Archetype claim has structural_match <0.5 | Skill classifies as "no archetype fits" rather than forcing a match |
| **AP6 — Paradigm-level rec to operator without authority** | Recommendation is level 1-3 AND operator-authority filter shows operator cannot influence | Downgrades to highest feasible level + flags the authority gap |
| **AP7 — Static analysis of dynamic problem** | Problem statement is time-dependent AND draft recommendation is snapshot-class | Returns error noting framework mismatch |

---

## Escalation Rules — When to Defer

| Signal | Defer to | Reason |
|--------|----------|--------|
| Problem is static-snapshot, not dynamic | `/diagnose-bottleneck` | Wrong framework class |
| Problem is option-choice under uncertainty (≥2 mutually exclusive options) | `/decide-under-uncertainty` | Wrong framework class — adjudication, not projection |
| Question is "what does this single DECISION do to the system over time" | DECISION mode of this skill (`input_mode: decision`) | Not a defer — switch modes within this skill |
| Multi-stakeholder model disagreement | Future skill or council | Outside this skill's mental-models layer |
| Pure CLD-drawing request without diagnostic question | Notation tools outside this skill | Out of jurisdiction |

---

## Tests — Required Before Skill Ships (SYSTEM mode)

Per spec §10 + shared library Required Test Cases. These are the **SYSTEM-mode** acceptance tests — all 7 must pass. **DECISION mode** adds 10 tests (DT1-DT10, plus the scope-refusal variants DT5b/DT5c) in the `## Decision Mode` section. Both sets must pass before v1.2 ships; the 7 SYSTEM-mode tests are unchanged from v1.0 — they are the backward-compatibility floor.

### Test 1 — Happy path

**Input**: A SaaS pipeline with stated boundary (marketing → trial → paid sub; excluding referrals + post-paid retention) + behaviour pattern ("MRR grew 15%/mo for 9 months, flat for 6 despite 30% more marketing spend") + 4 observed stocks/flows (monthly_enquiries, monthly_trials, trial_to_paid_conversion_rate, monthly_marketing_spend) + operator hypothesis ("limits to growth on segment exhaustion").

**Expected behaviour**: full output, all four anti-anchoring components populated, archetype classified, leverage point ranked, counterfactual stated, falsifier present if HIGH confidence.

**Verification**: `verdict == PASS` (or `ADVISORY_PENDING` if counterfactual marginal); all output schema fields populated.

### Test 2 — Adversarial anchored

**Input**: Operator names "tragedy of the commons" archetype with `hypothesis_provenance: operator`; observed data better fits "fixes that fail" (short-term workaround caused downstream regression).

**Expected behaviour**: `anti_anchoring.verdict == DISAGREED`; both archetypes presented; no silent acceptance.

**Verification**: Output contains BOTH archetype names with structural-match scores; operator asked to choose OR skill runs both.

### Test 3 — Vague input

**Input**: "Our growth has stalled — what's the system thinking on this?"

**Expected behaviour**: MVI insufficient-input; missing fields listed; example template returned.

**Verification**: `verdict == INSUFFICIENT_INPUT`; `mvi_check.missing` populated.

### Test 4 — Empty input

**Input**: Skill invoked with `{}`.

**Expected behaviour**: Structured insufficient-input error; no hallucination.

**Verification**: Same as Test 3 with broader missing list.

### Test 5a — Out-of-scope (static question)

**Input**: "Where is the bottleneck in our pipeline right now?"

**Expected behaviour**: Skill refuses jurisdiction; redirects to `/diagnose-bottleneck`.

**Verification**: `verdict == SCOPE_REFUSAL`; `scope.redirect == "/diagnose-bottleneck"`.

### Test 5b — Out-of-scope (pure notation)

**Input**: "Draw a CLD for our customer-acquisition system" with no diagnostic question.

**Expected behaviour**: Skill refuses jurisdiction; notes that pure-notation tools exist outside this skill.

**Verification**: `verdict == SCOPE_REFUSAL`; `scope.redirect` indicates "notation tools (out of scope)".

### Test 6 — Same-as-default counterfactual

**Input**: Skill's recommendation matches operator's `default_action`.

**Expected behaviour**: `counterfactual.difference == none` or `marginal`; ADVISORY-pending; NOT PASS.

**Verification**: `verdict == ADVISORY_PENDING`; `advisory_pending_reasons` includes "counterfactual difference below substantial threshold."

### Test 7 — Non-author-domain test

**Input**: A hospital triage system (NOT a SaaS / software context): patient inflow → triage assessment → bed allocation → discharge; observed: ED wait times climbed for 8 weeks while bed-utilisation rate also climbed and discharge rate stayed flat.

**Expected behaviour**: Skill produces analysis without software-domain assumptions; archetypes apply without modification.

**Verification**: Output vocabulary stays generic; no SaaS-specific framing; appropriate archetype (likely limits-to-growth or capacity-binding) classified correctly.

---

## Verification Gates (Self-Check Before PASS — SYSTEM mode)

DECISION mode has its own gate table in the `## Decision Mode` section.

| Gate | Pass condition |
|------|----------------|
| MVI | All MVI predicates passed |
| Scope | Boundary check ran; in_jurisdiction true |
| Anti-anchoring | Guard ran; `anti_anchoring.verdict` populated |
| CLD | Loops all R/B labelled with behaviour description |
| Delays | Load-bearing delays flagged where applicable |
| Archetype | Either classified, ambiguous-with-both-presented, or "no archetype fits" |
| Operator-authority filter | Recommended intervention is feasible for operator's authority layers |
| Counterfactual | Statement present; `difference` is one of four values |
| Falsifier | Present when `confidence: HIGH` with specific observable + timeframe + operator response |

If any gate fails, return `ADVISORY_PENDING` with reasons.

---

## Composition with Other Skills

| Skill | Composition |
|-------|-------------|
| `/diagnose-bottleneck` | Sibling diagnostic. The two NEVER run on the same problem simultaneously — boundary diagnostic determines which fires. |
| `/decide-under-uncertainty` | Two-way cross-skill chain. (1) This skill's recommended intervention may flow into `/decide-under-uncertainty` as `source_hypothesis` (`provenance: prior_skill`) when multiple feasible interventions need adjudication. (2) `/decide-under-uncertainty`'s chosen option may flow back into this skill's **DECISION mode** to project that option's second-order effects (`provenance: prior_skill`, Branch B — see Decision Test DT8). |
| `reframer` council agent | The Reframer's analytical primitive 6 (systems-thinking second-order audit) is the best-effort *inline* version of DECISION mode. Per the skill-suite plan, the Reframer is patched at Session 10 to cite DECISION mode instead of carrying the logic inline. |
| `/check-commensurability` | Sibling framing-audit primitive (Primitive 3). A comparison-based decision goes through `/check-commensurability` for ladder position; the chosen path's second-order effects go through this skill's DECISION mode. |
| `.claude/skills/_shared/anti-anchoring-guard.md` | Cites Components 1-4 (both modes) |
| `.claude/skills/_shared/frame-vs-input-classifier.md` | Sibling framing-audit primitive (Primitive 4). Independent of this skill; both compose inside the Reframer. |

---

## Strategic Alignment

**ROADMAP item(s) this advances**:
- `/map-feedback-loops` skill (spec → code; first runnable Systems Thinking tool)
- Methodology codification (Systems Thinking doctrine now operational)
- Cross-skill chain pattern (validate-upstream mode tested via chain handoff to `/decide-under-uncertainty`)
- **v1.1 — Primitive 2 of the First-Principles + Systems-Thinking skill suite** (DECISION mode / second-order audit; Operational Intelligence Synthesis Programme Session 8) — gives the upgraded Reframer's analytical primitive 6 a callable backing
- **v1.2 — depth + time-domain amendment** (Operational Intelligence Synthesis Programme Session 9 Phase A) — the second-order audit now compels an order-tagged cascade (effect-of-effect to arbitrary depth, with a per-branch stop rule) across three explicit time bands, not a flat single-horizon list
- The Session 10 Hermes re-run gains a mechanical second-order-projection step

**ROADMAP item(s) this REJECTS**:
- Map-without-bound CLD authoring (AP2 catch)
- Default-to-parameter recommendations (AP1 catch)
- Archetype-forcing on low-match data (AP5 catch)
- Standalone CLD-notation tool (out of scope; not a notation skill)
- First-order-only verdicts on decisions (v1.1 DAP1 catch — the Hermes failure class)
- Flat-list second-order projections with no effect-of-effect tracing and no multi-speed sweep (v1.2 DAP6 catch)

**If this skill advances nothing**: Systems Thinking doctrine remains theory; operators apply CLD-thinking ad-hoc with no anti-anchoring discipline; the leverage hierarchy gets ignored in favour of default-to-parameter; decisions lock on first-order outcomes with second-order effects unprojected (the Hermes failure recurs).

---

## References

- Doctrine: `docs/operational-doctrine/02_systems-thinking.md`
- Skill spec: `specs/04_MAP_FEEDBACK_LOOPS_SKILL.md`
- Shared library: `.claude/skills/_shared/anti-anchoring-guard.md`
- Rule: `.claude/rules/diagnostic-skill-anti-anchoring.md`
- Verification gate: `.claude/rules/doctrine-verification-gate.md`
- Sibling skills: `.claude/skills/diagnose-bottleneck/SKILL.md`, `.claude/skills/decide-under-uncertainty/SKILL.md`

---

*Skill v1.0 authored 2026-05-12 in Session 4 of the Operational Intelligence Synthesis Programme. Operationalises Systems Thinking doctrine. Cites shared anti-anchoring guard library. Triple verification: Gate 1 deletion test PASS (named consumers: future dynamic-system diagnoses across the agency entities; cross-skill chain with `/decide-under-uncertainty`); Gate 2 code-council DEFERRED to fresh-context ceremony; Gate 3 real-decision test DEFERRED (anti-sycophancy second-party constraint).*

*v1.1 authored 2026-05-17 in Session 8. Adds DECISION mode — Primitive 2 of the First-Principles + Systems-Thinking skill suite (systems-thinking second-order audit). DECISION mode is fully additive: SYSTEM mode and its 7 acceptance tests are unchanged. Decision-mode design source: continuation §6 + Agency-Main discoveries report Requirement 2. Gate 2 code-council ran in Session 8; Gate 3 real-decision test is the Session 10 Hermes re-run (projecting the W4 native-FTS5 decision's second-order effects).*

*v1.2 authored 2026-05-17 in Session 9 (Phase A). Amends DECISION mode with depth-cascade tracing and three time bands, per the operator's 2026-05-17 catch that the shipped second-order audit permitted but did not compel a deep, multi-speed analysis. Step D4.4 is restructured into D4.4.a-e (order-2 extraction → time-band tagging + immediate-first sweep → depth tracing → per-branch stop rule → band coverage check); every effect carries `order` / `time_band` / `produced_by` / `terminal`; anti-pattern DAP6 (flat-list projection) and two verification gates (depth cascade, time-band coverage) are added; DT9 + DT10 are added. SYSTEM mode and its 7 acceptance tests are unchanged. The four effect classes are kept; `delayed_consequences` is redefined as the discrete-non-structural-consequence type (the keep-not-fold decision was made in plan-mode after a `/reduce-to-first-principles` self-audit returned framing verdict `ADDS_CONSTRAINTS`). Gate 2 code-council on the v1.2 diff; Gate 3 real-decision test remains the Session 10 Hermes re-run.*
