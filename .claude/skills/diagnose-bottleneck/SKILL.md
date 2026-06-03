---
name: diagnose-bottleneck
description: |
  Theory-of-Constraints bottleneck diagnosis for flow-based systems. Identifies the binding
  constraint, classifies it (physical / policy / market), runs mandatory anti-anchoring guard
  before accepting any operator-named bottleneck, tests for multi-bottleneck and hidden-coupling
  failure modes, produces ranked interventions (exploit → subordinate → elevate), and outputs
  a counterfactual statement comparing the recommendation to operator's default action.
  Use when: "diagnose bottleneck", "what's the constraint", "why is X slow", "where should we
  add capacity", "stress test this bottleneck claim", "pipeline diagnosis", "throughput analysis",
  "is engineering really the constraint", "find the rate-limiting step".
  Do NOT use for: dynamic / over-time behaviour (use /map-feedback-loops); option-choice under
  uncertainty (use /decide-under-uncertainty); political constraints (out of TOC jurisdiction);
  demand-constrained businesses (market constraint — out of jurisdiction).
classification: capability-uplift
version: 1.0
created: 2026-05-12
operationalises: docs/operational-doctrine/01_theory-of-constraints.md
spec: specs/03_DIAGNOSE_BOTTLENECK_SKILL.md
shared_library: .claude/skills/_shared/anti-anchoring-guard.md
allowed-tools: Read, Write, Glob, Grep, Bash, AskUserQuestion, Agent
user-invocable: true
parameters:
  - name: system_description
    type: string
    required: true
    description: Named flow with stages, OR "discover" to invoke flow-discovery sub-procedure
  - name: throughput_metrics
    type: object
    required: false
    description: Stage-keyed observable throughput numbers (units per time period)
  - name: proposed_bottleneck
    type: string
    required: false
    description: If operator has a hypothesis to test; skill challenges it before accepting
  - name: hypothesis_provenance
    type: enum
    required: true_when_proposed_bottleneck_present
    description: One of operator | prior_skill | session_history | generative_primitive (per shared anti-anchoring lib)
  - name: source_hypothesis
    type: object
    required: true_when_provenance_is_prior_skill_or_generative_primitive
    description: Upstream-skill handoff block per shared library Cross-Skill Composition section. When provenance is generative_primitive the block additionally carries generated_at (ISO date) and project_root — the bounds-check fields per shared library Step 2.2 Branch D.
  - name: default_action
    type: string
    required: true
    description: What the operator would do without skill input (required for counterfactual gate)
  - name: scope_check
    type: boolean
    default: true
    description: Run TOC boundary diagnostic first; skip only when operator confirms TOC applicability
---

# /diagnose-bottleneck — Theory-of-Constraints Bottleneck Diagnosis

**Status**: v1.0 (Session 4 of Operational Intelligence Synthesis Programme — 2026-05-12)
**Operationalises**: `docs/operational-doctrine/01_theory-of-constraints.md`
**Skill spec**: `specs/03_DIAGNOSE_BOTTLENECK_SKILL.md`
**Cites shared library**: `.claude/skills/_shared/anti-anchoring-guard.md` (anti-anchoring guard, counterfactual gate, falsifier discipline)

---

## Purpose

This skill is the executable form of the TOC doctrine. Operators (and AI agents on their behalf) invoke it when they need to locate the binding constraint in a flow-based system without manually walking the 640-line doctrine each time. The skill encodes the doctrine's Application Checklist as a callable procedure with mandatory anti-anchoring discipline.

**Use this skill when**:
- A pipeline / process / workflow with named stages is slow and the rate-limiting step needs to be located
- A capacity-investment decision (hire / scale / automate / outsource) requires knowing the actual constraint
- An existing bottleneck claim needs stress-testing ("our constraint is X — is that right?")
- A new system's throughput needs first-pass analysis

**Do NOT use this skill when**:
- The system has no defined flow (TOC Assumption A1 fails)
- The constraint is political / organisational / market — out of TOC jurisdiction
- The question is dynamic-over-time (use `/map-feedback-loops`)
- The question is option-choice under uncertainty (use `/decide-under-uncertainty`)

---

## When to Invoke

### Explicit triggers
- "diagnose the bottleneck", "find the constraint", "where should we invest capacity"
- "is X really the bottleneck?", "stress test this constraint claim"
- A sister skill (`/plan`, `/council`) hits a throughput question and defers here

### Implicit triggers (consideration, not auto-invocation)
- Session discusses "scaling X" or "hiring more Y" — consider whether constraint analysis was done first
- ROI / cost analysis mentions throughput improvements — consider whether TOC framing applied

### Anti-triggers (skill MUST refuse jurisdiction)
- Operator describes feedback-loop-dominated problem (oscillations, time delays, runaway growth) → defer to `/map-feedback-loops`
- Operator describes ambiguous-evidence decision under uncertainty → defer to `/decide-under-uncertainty`
- Operator names single decision-maker or regulatory hold-up as constraint → refuse; redirect to stakeholder-mapping references
- Operator describes demand-constrained business → refuse; redirect to market-positioning doctrine

---

## Minimum Viable Input (MVI) — Component 1

Per `.claude/skills/_shared/anti-anchoring-guard.md` Component 1, the skill refuses to proceed below MVI.

### Required MVI fields

| Field | Validation predicate |
|-------|----------------------|
| `system_description` | Named flow with ≥3 stages with clear input/output boundaries |
| `throughput_metric` | At least one observable measure at one stage (units per time period) |
| `internal_constraint_confirmed` | Operator confirms constraint is internal, not "we don't have enough customers" |
| `default_action` | One sentence — what the operator would do without skill input (required for counterfactual) |
| `hypothesis_provenance` | One of `operator` / `prior_skill` / `session_history` / `generative_primitive` — required when `proposed_bottleneck` is non-null |

### Below-MVI handling

When MVI fails, emit structured insufficient-input error per shared library Component 1 Step 1.3. NEVER hallucinate a constraint from below-MVI input. Example error response shape lives in `specs/03_DIAGNOSE_BOTTLENECK_SKILL.md` §4.3.

---

## Procedure

The procedure runs in seven steps. Each step has a halt condition; the skill exits with a structured verdict at the first halt.

### Step 1 — Scope boundary check (TOC doctrine §3)

Apply the boundary diagnostic from the doctrine. If the system falls outside TOC's jurisdiction (political / market / no-flow / feedback-loop-dominated), emit structured scope refusal with redirect to the appropriate doctrine or skill. Do NOT proceed.

### Step 2 — MVI gate

Per shared library Component 1 Step 1.2. Halt with structured insufficient-input error if any MVI predicate fails.

### Step 3 — Anti-anchoring guard

Per shared library Component 2. Branch by `hypothesis_provenance`:
- `operator` → Branch A (standard): independent location via Step 4 BEFORE comparing to operator's named bottleneck
- `prior_skill` → Branch B (validate-upstream): rerun upstream skill with alternative scope frame; check stability
- `session_history` → Branch C (operator confirmation question first)
- `generative_primitive` → Branch D (bounded-tag standard guard): the proposed bottleneck arrived from a generative workshop skill. Run the bounds check per shared library Step 2.2 Branch D — verify the `source_hypothesis` bounds fields (`project_root` matches the current project AND `generated_at` within the staleness window, default 21 calendar days). Both bounds pass → run Branch A (standard); `project_root` mismatch OR `generated_at` stale → downgrade to `operator` and run Branch A, recording the downgrade reason in `reasoning_chain`; missing bounds fields → Component 1 input-validation failure. Validate-upstream (Branch B) is NEVER run for `generative_primitive`.

If `proposed_bottleneck` is null, skip the compare; proceed to Step 4 directly with no anchoring concern.

### Step 4 — Independent location (TOC 5 Focusing Steps Step 1: Identify)

WITHOUT referencing operator's named bottleneck:

1. For each stage in the named flow, compute observed throughput (units/time) and demanded throughput (units/time required to keep up with the system's upstream supply or downstream pull)
2. Locate the stage with the lowest observed-vs-demanded ratio — this is the constraint candidate
3. Classify the constraint type per doctrine §4: physical (resource), policy (rule), or market (external demand)
4. If type is market → halt with scope refusal (TOC's tools have no purchase on demand constraints)
5. Record `independent_constraint`, `observed_throughput`, `demanded_throughput`, `constraint_type`, `type_justification`

### Step 5 — Failure-mode checks (mandatory; never skip)

#### Step 5.1 — Multi-bottleneck check (TOC doctrine §8.1)

For each non-constraint stage, compute `non_constraint_throughput / constraint_throughput`. If any non-constraint is within 20% (ratio ≥ 0.8), flag multi-bottleneck. Apply decomposition (treat each as a sub-constraint) OR defer with explicit reasoning.

#### Step 5.2 — Hidden-coupling check (TOC doctrine §8.6)

For each non-constraint stage, check error rate. If a non-constraint has high error rate inflating constraint load (e.g., upstream defects forcing rework at constraint), flag hidden coupling. Amend recommendations to address the upstream stage first.

### Step 6 — Compare (when operator hypothesis present)

Per shared library Component 2 Branch A Step 3. Verdict in three classes:

| Verdict | Trigger | Behaviour |
|---------|---------|-----------|
| `AGREED` | Independent location matches operator's bottleneck | Proceed; log "anti-anchoring verified" |
| `DISAGREED` | Independent location differs | Present BOTH; do not silently pick; ask operator OR run both analyses |
| `INCONCLUSIVE` | Throughput data does not discriminate | Flag as insufficient-input even if MVI passed |

### Step 7 — Ranked interventions (TOC 5 Focusing Steps Steps 2-4)

Produce three lists in this order — NEVER reorder, NEVER skip Exploit:

1. **Exploit** (squeeze more from existing constraint without buying capacity) — idle-time elimination, quality-check relocation upstream, setup-time reduction, value-priority sequencing
2. **Subordinate** (cap non-constraints to match constraint rate) — reduce work-in-process, remove incentives that overproduce relative to constraint
3. **Elevate** (buy or build capacity) — hire, scale, automate; only after Exploit interventions are exhausted

Each intervention carries: description, expected throughput gain (range), cost (range or qualitative), confidence (low/medium/high), caveats.

### Step 8 — Counterfactual statement (Component 3)

Per shared library Component 3. Emit the four-field structure. If `difference` is `none` or `marginal`, the skill self-flags ADVISORY-pending — TOC has earned no leverage for this case.

### Step 9 — Falsifier (Component 4 when HIGH confidence)

Per shared library Component 4. Name specific observable (rate / count / threshold), timeframe, and operator response. Generic statements are BLOCKING at code-council review.

### Step 10 — Re-evaluation trigger

Constraints typically shift after Exploit interventions deploy. Emit a re-evaluation trigger date (typically 2-4 weeks after deployment) so the operator re-invokes the skill rather than acting on a stale diagnosis.

---

## Output Schema

```yaml
skill: diagnose-bottleneck
version: 1.0
verdict: <PASS | ADVISORY_PENDING | SCOPE_REFUSAL | INSUFFICIENT_INPUT>
confidence: <HIGH | MEDIUM | LOW>

mvi:
  passed: <bool>
  missing: <list[string]>

scope:
  in_jurisdiction: <bool>
  type_check: <internal-flow | political | market | no-flow | feedback-loop-dominated>
  redirect: <skill_or_doctrine_name | null>

constraint:
  stage: <string>
  observed_throughput: <string with units>
  demanded_throughput: <string with units>
  throughput_gap: <string>
  type: <physical | policy | market>
  type_justification: <string>

anti_anchoring:
  hypothesis_provenance: <operator | prior_skill | session_history | generative_primitive>
  operator_proposed_bottleneck: <string | null>
  independent_location: <string>
  verdict: <AGREED | DISAGREED | INCONCLUSIVE | validate_upstream_stable | validate_upstream_unstable>
  reasoning_chain: <list[step]>

failure_mode_checks:
  multi_bottleneck:
    flag: <bool>
    second_stage_throughput_ratio: <number>
    rationale: <string>
  hidden_coupling:
    flag: <bool>
    upstream_stage: <string | null>
    rationale: <string>

interventions:
  exploit:
    - description: <string>
      expected_throughput_gain: <range>
      cost: <range or qualitative>
      confidence: <high | medium | low>
      caveat: <string | null>
  subordinate: [<same shape>]
  elevate: [<same shape>]

counterfactual:
  default_action: <string>
  skill_recommendation: <string>
  difference: <none | marginal | substantial | transformative>
  skill_leverage: <string 1-3 sentences with named evidence>

falsifier:  # required when confidence == HIGH
  specific_observable: <string>
  timeframe: <string>
  operator_response_if_triggered: <string>

source_hypothesis:
  provenance: <operator | prior_skill | session_history | generative_primitive>
  upstream_skill: <string | null>
  upstream_invocation_id: <string | null>
  hypothesis_text: <string>

re_evaluation:
  trigger_date: <ISO date>
  why: <string>

advisory_pending_reasons: <list[string]>

invocation_metadata:
  timestamp: <ISO 8601 UTC>
  skill_version: 1.0
  doctrine_version: <semver of doctrine doc>
  invocation_id: <uuid>
```

---

## Anti-Patterns the Skill Must Refuse

| Anti-pattern | Detection signal | Defence |
|--------------|------------------|---------|
| **AP1 — Accept vague input** | `system_description` lacks named stages | Halt with structured insufficient-input error |
| **AP2 — Accept pre-named bottleneck without challenge** | `proposed_bottleneck` non-null; anti-anchoring guard not invoked | Step 3 is mandatory; output struct must contain `anti_anchoring.verdict` |
| **AP3 — Hallucinate throughput numbers** | Throughput metrics absent; skill produces concrete numbers anyway | Either request specific metrics OR flag estimates as ESTIMATE and downgrade confidence |
| **AP4 — Skip multi-bottleneck check** | Output struct lacks `failure_mode_checks.multi_bottleneck` | Step 5.1 is mandatory regardless of single-constraint claim |
| **AP5 — Skip hidden-coupling check** | Output struct lacks `failure_mode_checks.hidden_coupling` | Step 5.2 is mandatory |
| **AP6 — Jump to Elevate before Exploit** | `interventions.elevate` populated; `interventions.exploit` empty | Step 7 ordering is mandatory; never skip Exploit |
| **AP7 — Produce same recommendation as operator's default** | `counterfactual.difference: none` or `marginal` | Auto-flag ADVISORY-pending; verdict NOT PASS |
| **AP8 — Refuse to refuse jurisdiction** | Skill applies TOC to political / market / no-flow problem | Step 1 must halt with scope refusal |

---

## Escalation Rules — When to Defer to Other Skills

| Signal | Defer to | Reason |
|--------|----------|--------|
| Multiple binding constraints detected | Recursive self-call per sub-system | TOC's one-constraint claim fails |
| Constraint is political / organisational | Stakeholder-mapping reference | TOC tools have no purchase |
| Constraint is market (external demand) | Market-positioning doctrine | TOC exploit/elevate inapplicable |
| System dynamics dominant (feedback loops, time delays) | `/map-feedback-loops` | Wrong doctrine class |
| Decision under ambiguous evidence | `/decide-under-uncertainty` | Decision-Quality has tools for evidence-weighted choice |

---

## Hidden Risks the Skill Surfaces (Not Silent)

1. **Constraint moves silently after exploit** — re-evaluation trigger emitted in output (Step 10)
2. **Exploit interventions create new constraints** — flagged in `caveat` field per intervention
3. **Subordination is psychologically difficult** — flagged when intervention requires removing a visible metric or incentive
4. **Skill produces same recommendation as default** — flagged ADVISORY-pending (AP7)
5. **Diagnosis may be wrong** — `falsifier` field names the observable that would invalidate the diagnosis (Component 4)

---

## Tests — Required Before Skill Ships

Behavioural acceptance tests per spec §11. The skill cannot be considered shipped until all eight return correct behaviour. Test 8 is the Branch D `generative_primitive` case (added 2026-05-18 — Define-Destination Phase A part 2; mirrors shared library test case 9).

### Test 1 — Happy path (well-formed flow system)

**Input**: A pipeline with 5 named stages (intake, comp pull, MAO calculation, offer letter, follow-up) + throughput per stage (offer-letter stage at 60% of intake throughput).

**Expected behaviour**: skill identifies offer-letter stage as constraint, classifies type, runs anti-anchoring + multi-bottleneck + hidden-coupling checks, returns ranked interventions with counterfactual.

**Verification**: `verdict == PASS` (or `ADVISORY_PENDING` if counterfactual marginal); output schema fully populated; all four anti-anchoring components present.

### Test 2 — Adversarial input (pre-named bottleneck disagrees with throughput data)

**Input**: Operator names "engineering" as constraint with `hypothesis_provenance: operator`; throughput data shows legal review is slowest.

**Expected behaviour**: anti-anchoring guard fires; skill presents BOTH operator's claim and independent location; asks operator to choose or runs both.

**Verification**: `anti_anchoring.verdict == DISAGREED`; output includes both stages; skill does NOT silently pick one.

### Test 3 — Vague input (no named flow)

**Input**: "Our customer onboarding is slow."

**Expected behaviour**: MVI insufficient-input error; structured response with example template.

**Verification**: `verdict == INSUFFICIENT_INPUT`; `mvi.missing` includes `system_description.named_stages` and `throughput_metric`; no fabricated bottleneck.

### Test 4 — Empty input (no system specified)

**Input**: Skill invoked with `system_description: null`.

**Expected behaviour**: structured error requesting input; example input format provided.

**Verification**: skill returns example template; does not hallucinate a target system.

### Test 5 — Out-of-scope (political constraint refusal)

**Input**: System where named bottleneck is "CEO approval."

**Expected behaviour**: skill refuses jurisdiction; redirects to stakeholder mapping; does NOT apply TOC analysis.

**Verification**: `verdict == SCOPE_REFUSAL`; `scope.in_jurisdiction == false`; `scope.redirect` populated; no `interventions` produced.

### Test 6 — Same-as-default counterfactual

**Input**: System where skill's independent recommendation matches operator's stated `default_action`.

**Expected behaviour**: `counterfactual.difference == none` or `marginal`; skill flags ADVISORY-pending; verdict NOT PASS.

**Verification**: `verdict == ADVISORY_PENDING`; `advisory_pending_reasons` includes "counterfactual difference below substantial threshold."

### Test 7 — Non-author-domain test (per Reliability Engineer Assumption C)

**Input**: A freight-dispatch pipeline (load assignment → driver routing → fuel-stop scheduling → delivery), NOT a property-investment context.

**Expected behaviour**: skill produces a diagnosis that does not rely on real-estate-specific framing.

**Verification**: output vocabulary is generic (no MAO/ARV/comp-pull patterns); doctrine successfully applies in freight context; intervention list is freight-relevant.

### Test 8 — Branch D (`generative_primitive` provenance)

**Input**: a well-formed flow system as Test 1; `proposed_bottleneck` arriving from a generative workshop skill (the backward chain of a `DESTINATION.md` names a candidate flow constraint); `hypothesis_provenance: generative_primitive`; `source_hypothesis` carrying `upstream_skill` (the destination-authoring skill), `generated_at` (an in-window ISO date), and `project_root` (the current project); `default_action` supplied.

**Expected behaviour**: Step 3 routes to Branch D; the bounds check passes (`project_root` matches, `generated_at` in window); the input is treated as `operator` provenance and Branch A runs — independent location (Step 4) AND the three-class compare both run normally; validate-upstream is NEVER run. A stale or cross-project tag → provenance downgrades to `operator` with the reason recorded in `reasoning_chain`. A `generative_primitive` input MISSING `generated_at` / `project_root` → Component 1 input-validation failure.

**Verification**: `anti_anchoring.hypothesis_provenance == generative_primitive` (or `operator` with a downgrade reason in `reasoning_chain` for the stale/cross-project sub-case); `anti_anchoring.verdict` is one of `AGREED` / `DISAGREED` / `INCONCLUSIVE` — and is NEVER `validate_upstream_stable` / `validate_upstream_unstable` for `generative_primitive` provenance; `anti_anchoring.independent_location` populated (Step 4 ran); a `generative_primitive` input missing the bounds fields → `verdict == INSUFFICIENT_INPUT`.

---

## Verification Gates (Self-Check Before Returning PASS)

Before the skill emits `verdict: PASS`, it must self-check:

| Gate | Pass condition |
|------|----------------|
| MVI | All MVI predicates passed; `mvi.passed: true` |
| Scope | Boundary check ran; `scope.in_jurisdiction: true` |
| Anti-anchoring | Guard ran on any operator-proposed bottleneck; `anti_anchoring.verdict` populated |
| Multi-bottleneck | Check explicit; flag set true or false with reasoning |
| Hidden coupling | Check explicit; flag set true or false with reasoning |
| Exploit-before-elevate | `interventions.exploit` populated before any `interventions.elevate` |
| Counterfactual | Statement present; `counterfactual.difference` is one of four values |
| Falsifier | Present when `confidence: HIGH` with specific observable + timeframe + operator response |

If any gate fails self-check, skill returns `ADVISORY_PENDING` instead of `PASS` with `advisory_pending_reasons` populated.

---

## Composition with Other Skills

| Skill | Composition |
|-------|-------------|
| `/map-feedback-loops` | Sibling diagnostic. Skill defers when problem is dynamic-over-time. The two skills NEVER run on the same problem simultaneously. |
| `/decide-under-uncertainty` | Cross-skill chain: this skill's output may flow into `/decide-under-uncertainty` as `source_hypothesis` with `provenance: prior_skill`. |
| `.claude/skills/_shared/anti-anchoring-guard.md` | This skill cites Components 1-4. All anti-anchoring logic lives in shared library, not here. |

---

## Strategic Alignment

**ROADMAP item(s) this advances**:
- Decomposition skill (first runnable diagnostic skill in workshop)
- Methodology codification (TOC doctrine now operational, not theoretical)
- Propagation infrastructure: Session 5 first-propagation event unblocked

**ROADMAP item(s) this REJECTS**:
- Per-skill anti-anchoring duplication (cites shared library)
- Skill that accepts operator bottleneck claims without challenge (AP2)
- Premature elevate recommendations (AP6)

**If this skill advances nothing**: TOC doctrine remains theoretical; operators must walk 640 lines manually each invocation; propagation NSM untouched.

---

## References

- Doctrine: `docs/operational-doctrine/01_theory-of-constraints.md`
- Skill spec: `specs/03_DIAGNOSE_BOTTLENECK_SKILL.md`
- Shared library: `.claude/skills/_shared/anti-anchoring-guard.md`
- Rule: `.claude/rules/diagnostic-skill-anti-anchoring.md`
- Verification gate: `.claude/rules/doctrine-verification-gate.md`

---

*Skill v1.0 authored 2026-05-12 in Session 4 of the Operational Intelligence Synthesis Programme. Operationalises TOC doctrine. Cites shared anti-anchoring guard library. Triple verification: Gate 1 deletion test PASS (named consumers: future ROI / capacity / pipeline analyses across all NewEarth entities); Gate 2 code-council DEFERRED to fresh-context ceremony; Gate 3 real-decision test DEFERRED (anti-sycophancy second-party constraint).*
