# Operational Doctrine: Decision-Quality

> **Status**: v0.1 — ADVISORY with named gaps (Gate 2 + Gate 3 DEFERRED per programme pattern)
> **Authored**: 2026-05-12 (Operational Intelligence Synthesis Programme Session 3, post-extended-council calibration)
> **Predecessors**: Theory of Constraints (`01_theory-of-constraints.md`), Systems Thinking (`02_systems-thinking.md`)
> **Operationalised by**: `/decide-under-uncertainty` skill (spec at `specs/05_DECIDE_UNDER_UNCERTAINTY_SKILL.md`)
> **Composes with**: `council-protocol.md` (Agent-Disagreement layer), `diagnostic-skill-anti-anchoring.md` (anti-anchoring + provenance), `code-review-identity.md` (anti-sycophancy), `agentic-loop-guards.md` (verification layer), `pre-completion-pocock-check.md` (plan-class gate)

---

## 1. Purpose

This doctrine codifies what makes a decision good when the evidence is uncertain, ambiguous, or contested. It does NOT codify Decision Theory in the academic sense — the four-school taxonomy (Bayesian / expected-value / behavioural / falsificationist) is the source material, not the operational output. The operational output is a small set of governing principles, a single diagnostic procedure (operationalised by `/decide-under-uncertainty`), and a structural defence against the failure modes that look like good decisions in the moment but produce wrong outcomes at scale.

The doctrine answers four questions an operator faces under uncertainty:

1. **What evidence would change my mind?** (falsification gate)
2. **What does it cost if I'm wrong about which option is best?** (cost-of-being-wrong framing)
3. **Which biases are silently shaping this judgement?** (bias-as-detection-signal)
4. **When AI agents and I disagree, who wins and why?** (Agent-Disagreement Protocol)

Each question is answered with a procedure, not a principle alone. Principles without procedures become philosophy by week 3.

---

## 2. Why Decision-Quality Earned Its Slot in This Workshop

Three reasons this doctrine is in the MVP triad rather than deferred to Tier 2:

**It absorbs both predecessor doctrines' delegations.** Theory of Constraints §3.2 explicitly punts decision-under-uncertainty here; Systems Thinking §3.2 does the same, plus the multi-operator-disagreement delegation. Without this doctrine, every operator using the prior two hits an undefined boundary the moment uncertainty arrives.

**It is the highest-frequency framework in the operator's daily reality.** Bottlenecks and feedback loops appear; decisions under uncertainty appear constantly. Every architectural call, every build-vs-buy, every ship-now-vs-iterate is a decision under uncertainty. Frequency × leverage = the propagation case.

**It has the most contested boundaries of the MVP triad, so codifying it FIRST (before Tier 2 frameworks) protects the workshop's coherence.** Without explicit IN/OUT scope, every Tier 2 framework that touches decision-making (Lean's pull/push, JTBD's job hierarchy, Wardley's movement classification) would re-litigate what belongs where. Decision-Quality is the boundary anchor.

---

## 3. Scope Boundary — What This Doctrine Does NOT Do

Decision-Quality refuses jurisdiction over six adjacent territories. Each refusal is paired with a redirect.

### 3.1 Static-Snapshot Constraint Location (delegated to Theory of Constraints)

When the question is "where is the binding bottleneck right now and how do I increase throughput", the answer lives in TOC. Decision-Quality would produce a generic "consider asymmetric payoffs across candidate interventions" output that misses the specific structural answer.

### 3.2 Dynamic System Behaviour (delegated to Systems Thinking)

When the question is "why does this system behave like this over weeks/months/years", Systems Thinking has the stock-and-flow tooling. Decision-Quality assumes a static decision moment; it does not model time delays, feedback loops, or compounding effects.

### 3.3 Game-Theoretic Equilibrium Analysis (separate doctrine candidate)

When multiple decision-makers' choices are coupled (each side's payoff depends on the other's choice), Nash equilibrium analysis, Schelling points, and prisoners-dilemma frames are the right tools. This doctrine handles single-decision-maker uncertainty with multiple options, not multi-agent strategic interaction.

### 3.4 Pearl's Structural Causal Models (technical apparatus, separate doctrine candidate)

When the question is "given this causal graph, what is the effect of intervention X on outcome Y", Pearl's do-calculus is the formal tool. This doctrine handles informal Bayesian belief revision (prior → evidence → posterior) without the structural-equation apparatus.

### 3.5 Knightian Uncertainty / Ambiguity Aversion (Tier 2 doctrine candidate)

When the probability distribution itself is unknown (not just probabilities within a known distribution), Ellsberg-paradox-class problems require different machinery. This doctrine flags Knightian-uncertainty conditions explicitly and switches the operator to regret-minimisation framing rather than expected-value calculation — but does not codify the full ambiguity-aversion literature.

### 3.6 Paradigm-Level Rationality Reform

When the operator's underlying epistemic framework is itself the problem (e.g., systematic overconfidence calibration across all domains), this doctrine cannot intervene. Calibration training requires a logged-prediction corpus that this workshop does not yet have; full Brier-score implementation is deferred to a future doctrine.

**Boundary diagnostic** — before applying this doctrine, run a 30-second test:

1. Is the question "what to do given uncertain or conflicting evidence" rather than "where is the bottleneck" (TOC) or "why does this behave like this over time" (Systems Thinking)?
2. Is there ≥1 decision option that could be wrong in a way that matters (asymmetric payoff)?
3. Are competing hypotheses observable — can you gather evidence that distinguishes them?
4. Does the operator have authority to act on a recommendation at the decision layer (not at paradigm or organisational-incentive layer)?

If yes to ≥3: Decision-Quality is in scope. If 1 is no → redirect to TOC or Systems Thinking. If 4 is no → flag operator-authority gap before applying doctrine.

---

## 4. Governing Principles

Each principle is paired with its **falsification condition** — the specific evidence that would prove the principle wrong in a given case. Principles without falsification conditions are philosophy, not doctrine.

### P1 — Beliefs are revised by evidence; revision rate scales with evidence specificity

**Statement**: A decision-maker holds a belief with some implicit confidence (prior). New evidence updates that confidence (posterior). The update is proportional to how specifically the evidence distinguishes the held belief from competing beliefs. Vague evidence ("a smart person disagreed") produces a small update; specific evidence ("the test ran for 30 minutes and produced X output instead of expected Y") produces a large update.

**Mechanism**: prior × likelihood-ratio = posterior (informal Bayesian — no numerical computation required; the operator names "what would I expect to see if X were true vs Y were true" and notices which side the observed evidence supports).

**Falsification condition**: This principle is false in a case if specific, distinguishing evidence arrives AND the operator's confidence does NOT shift. If you can name a case where you saw the evidence and your belief did not move, the failure is either: (a) the evidence wasn't actually distinguishing, OR (b) you have a bias (most likely confirmation or sunk-cost) that blocked the update. The principle does NOT predict which.

**Why it matters here**: AI agents produce confident outputs that look like evidence. The principle says: AI confidence is NOT evidence; AI's reasoning IS evidence. Demand the reasoning chain before updating belief.

### P2 — Confidence requires a falsifiability condition

**Statement**: A HIGH-confidence claim requires a stated condition under which the claim would be wrong. Without that condition, the claim is unfalsifiable in Popper's sense — it cannot be tested, only believed.

**Mechanism**: For every HIGH-confidence verdict, the operator names ≥1 specific external observable (rate, count, date, threshold) + timeframe that would invalidate the claim. Example: "I'm confident this architecture will scale" + "Falsified by: p95 latency exceeding 800ms when concurrent users pass 1,000, within 30 days of production deploy." Without the falsifier, the claim downgrades to MEDIUM.

**Falsification condition**: P2 is itself false if the operator can name a high-stakes case where they were correctly HIGH-confidence AND no falsifiability condition could be stated. (This is rare. The more common case is the operator did not bother to state the condition — that is a failure of practice, not of P2.)

**Why it matters here**: Falsifiability is the gate between calibrated confidence and theatre. AI agents are systematically poor at producing falsifiability conditions on their own — they generate confident outputs without invariants. The operator must add the falsifier.

### P3 — When probabilities are unknown, switch from expected-value to regret-minimisation

**Statement**: Expected-value calculation requires probability estimates. When probabilities are guessed, the EV output has decimal-precision confidence built on fabrication — the most dangerous kind of theatre. In those cases, the operator switches to: "Which option do I regret least if it goes wrong?" + "What is the worst case for each option?" + "Is the worst case recoverable?"

**Mechanism**: cost-of-being-wrong framing. For each option, name (a) the worst-case outcome, (b) the cost of that outcome, (c) whether the cost is recoverable, (d) the cost of NOT pursuing the option if it would have worked. Pick the option with the most recoverable worst case at acceptable forgone-upside cost.

**Falsification condition**: P3 is false in a case if the operator HAS calibrated probabilities (e.g., from logged historical data) AND the EV calculation produces a different recommendation from regret-minimisation AND the EV path is empirically validated. If you have real probabilities, use them — P3 does NOT prohibit EV, it prohibits fabricated EV.

**Why it matters here**: Most operator decisions under AI assistance have NO calibrated probabilities. The temptation is to invent them to make the EV template work. P3 names this as a failure mode and routes to a framing that survives unknown probabilities.

### P4 — Biases are detection signals, not gotcha-categories

**Statement**: Naming a cognitive bias is operational only when paired with a real-time detection signal. "Watch for anchoring" is decoration; "if you find yourself defending the first number that came up, you are anchored" is operational. The doctrine codifies the operator-class top-3 biases as headline detection signals; the broader catalogue is in §6 for propagation to other operator classes.

**Workshop-operator-class top-3** (this workshop, this operator class):

- **Planning fallacy** — Detection signal: "Time estimate based on 'how long if everything goes right' without naming the failure modes." Counter-procedure: name ≥2 failure modes and add their probability-weighted time cost.
- **Base-rate neglect** — Detection signal: "Conclusion drawn from the current case without checking the historical adoption rate of similar moves." Counter-procedure: explicitly state the base rate and check whether the current case has evidence to depart from it.
- **Overconfidence on novel material** — Detection signal: "HIGH confidence on a question outside your historical accuracy domain." Counter-procedure: drop to MEDIUM and demand falsifier per P2.

**Falsification condition**: P4 is false if naming a bias with a detection signal does NOT change the operator's subsequent behaviour. Tested by: invoke the skill, name the bias, then check 30 days later whether the operator acted differently. Sessions 1-2 precedent: the only protection is invocation logging (programme spec §214-226 quiet-failure commitment).

**Why it matters here**: A doctrine that lists 12 biases without detection signals is a textbook. A doctrine that names 3 biases with detection signals is a tool.

### P5 — AI-Confidence-Asymmetry: AI confidence is calibrated differently from human confidence

**Statement** (NOVEL — the doctrine's load-bearing contribution to AI-vibe-coding workflows): Claude and similar AI systems express confidence in patterns that are systematically miscalibrated relative to ground truth in the operator's domain. Specifically:

- HIGH confidence on syntactically plausible wrong answers (the answer "looks right" because it matches training distribution, but is wrong in the operator's specific context)
- LOW confidence on correct answers in unfamiliar terrain (the answer is right but the AI hedges because the territory is out-of-distribution)
- Confidence does NOT track reasoning depth — short confident outputs and long reasoned outputs may have the same confidence claim but very different actual reliability

**Real-time detection signals**:

| AI output pattern | Operator's required response |
|-------------------|------------------------------|
| HIGH confidence + no explicit reasoning chain shown | Treat as MEDIUM. Ask "what's your reasoning chain?" before acting. |
| HIGH confidence + explicit step-by-step analysis citing observed artefacts (file content, query results, tool output) | Confidence at face value; still apply P2 falsifier check. |
| LOW/HEDGED confidence on a question in operator's domain expertise | Investigate why; the AI may have detected a real edge case OR may be miscalibrated downward. Don't dismiss the hedge as noise. |
| HIGH confidence on a recommendation that matches what operator already wanted to do | Apply confirmation-bias-detection check (P4). The match may be calibrated, OR the AI is mirroring the operator's framing. |

**Falsification condition**: P5 is false if AI confidence claims are observed to track ground-truth accuracy in the operator's domain over a logged sample. (No logged sample exists yet in this workshop — P5 is operationally true until invocation logging accumulates evidence.)

**Why it matters here**: This is the single most-applicable principle for daily AI-vibe-coding work. Every Claude Code response has a confidence pattern; the operator must read it correctly. Without P5, the operator either over-trusts confident wrong answers or dismisses hedged right answers.

### P6 — Calibration is a property of forecasts, not of confidence claims

**Statement** (concept only — full implementation deferred): A calibrated forecaster's stated probability tracks empirical frequency over many forecasts. Saying "70%" should mean 70% accuracy across many such claims. Calibration is measurable (Brier score, calibration curve) but requires a logged-prediction corpus.

**Mechanism**: deferred to a future Decision-Quality v0.2. Current workshop state: no logged corpus. The principle stays in doctrine as a flag — when operator starts logging predictions (manually or via skill output), this principle becomes operational.

**Falsification condition**: P6 is unfalsifiable in its current form until a logged corpus exists. Acknowledged. This is the only doctrine principle without an operational falsifier; it is included as a forward-pointer to future work, not as current operational guidance.

**Why it matters here**: Programme spec §214-226 names quiet-failure as the most dangerous class. Calibration is the eventual fix; until then, P5's detection signals are the field-replaceable proxy.

### P7 — Operator-authority filter: recommendations only at the layer the operator can act on

**Statement**: A decision recommendation is valuable only if the operator has authority to implement it. A recommendation that requires changing organisational incentives, policies, or external commitments — when the operator lacks that authority — produces frustration, not action. The doctrine and skill must filter recommendations to the operator's actual decision layer.

**Mechanism**: skill input includes `operator_decision_authority: {sole | shared | advisory | none | unknown}`. When `unknown`, the skill asks one clarifying question before proceeding. When `none`, the skill flags the recommendation as out-of-scope and redirects to a feasible layer.

**Falsification condition**: P7 is false in a case if the operator has authority they don't realise (false-negative on the filter). Detection: 30 days post-decision, check whether the filtered-out recommendation would have been actionable. If yes → operator authority assessment was wrong; doctrine flagged correctly given input but input was bad.

**Why it matters here**: Solo operators frequently underestimate their own authority. The filter is calibrated to the operator's self-report; the principle names the failure mode explicitly so the operator can re-check.

---

## 5. Assumptions

This doctrine assumes:

**A1** — The operator can name candidate options. If only one option exists (or only a sham second option like "don't proceed"), the doctrine cannot operate. Skill MVI gate catches this.

*Fails when*: operator has structurally committed to an action before invoking the doctrine. The doctrine then produces validation theatre.

**A2** — Some observable signal can distinguish between options. If no evidence can in principle update belief, the question is values-driven not evidence-driven, and Decision-Quality is the wrong frame.

*Fails when*: the decision is purely aesthetic, ethical, or based on incommensurable values. Redirect to a values-clarification frame, not this doctrine.

**A3** — The operator has authority to implement the recommended option at the recommended layer.

*Fails when*: P7 false-negative — operator has authority but doesn't report it. Doctrine outputs filtered recommendation; useful action is blocked.

**A4** — The decision matters enough to justify the doctrine's invocation cost. The doctrine adds ~5-15 minutes of structured reasoning. Decisions with payoff smaller than the cost should use intuition.

*Fails when*: doctrine is applied to trivial decisions (which file to edit first); operator burns out on the procedure and abandons it for high-stakes decisions where it matters.

**A5** — AI confidence signals are interpretable (P5). The operator must be able to observe HIGH/MEDIUM/LOW confidence patterns in AI output.

*Fails when*: AI outputs are filtered through a layer that strips confidence signals (e.g., automated pipelines that take only the recommendation, not the reasoning).

---

## 6. Mechanisms

### 6.1 Informal-Bayesian belief revision procedure

Five steps, executed in order:

1. **Name the belief**: "I currently believe X with HIGH/MEDIUM/LOW confidence."
2. **Name what evidence would distinguish X from competing beliefs**: "If X were true, I'd expect to see [E1]. If competing Y were true, I'd expect to see [E2]."
3. **Observe**: gather the evidence.
4. **Update**: "The evidence aligns more with X / Y / neither. My confidence in X moves to [new level]."
5. **Confirm via P2**: state the falsifier for the new confidence level.

This is informal — no numerical Bayes. The procedure forces the operator to make the prior, the discriminating evidence, and the update mechanism explicit. The skill `/decide-under-uncertainty` runs this as one of its sub-procedures.

### 6.2 Cost-of-being-wrong template (P3 operationalised)

Four cells per option:

| Cell | What it names |
|------|---------------|
| Worst-case outcome | The bad thing that happens if this option is wrong |
| Cost of worst case | Money, time, capacity, reputation, optionality |
| Recoverability | Hours / days / months / never |
| Cost of NOT pursuing if right | The forgone upside |

Pick the option with the most recoverable worst case at acceptable forgone-upside cost. When probabilities are calibrated (logged corpus exists), this combines with EV to produce a combined verdict; without calibration, regret-minimisation alone is the verdict.

### 6.3 Bias-as-detection-signal catalogue

**Workshop top-3** (skill targets):

| Bias | Detection signal | Counter-procedure |
|------|------------------|-------------------|
| Planning fallacy | "Estimate based on best case; failure modes unnamed" | Name ≥2 failure modes + probability-weight their time cost |
| Base-rate neglect | "Conclusion from current case; historical adoption rate unchecked" | State the base rate explicitly; check evidence for departing from it |
| Overconfidence on novel material | "HIGH confidence outside historical accuracy domain" | Drop to MEDIUM; demand P2 falsifier |

**Doctrine catalogue (broader — for propagation to other operator classes)**:

| Bias | Detection signal | Counter-procedure |
|------|------------------|-------------------|
| Anchoring | "Defending the first number or option that came up" | Generate the alternative independently from a different starting point |
| Confirmation bias | "Only the evidence supporting current belief is named" | Force-name ≥1 piece of disconfirming evidence |
| Sunk-cost | "Continuing because of prior investment, not future expected value" | Ask: "Would I start this if I had not already invested?" |
| Availability heuristic | "Recent vivid examples dominate the probability estimate" | Check base rate from a longer historical window |
| Framing effects | "The same outcome described differently produces different choices" | Re-describe the outcome in opposite framing; check if the choice changes |
| Hindsight bias | "Past outcome feels like it was obvious in advance" | Check prior-period notes; were you actually confident at the time? |
| Status-quo bias | "Defaulting to no-action because of inertia, not analysis" | Explicitly cost the no-action option same as the action option |

Operators in different classes (e.g., real-estate underwriting, freight scheduling, agency client management) pick the relevant top-3 from the broader catalogue based on their domain's actual failure pattern.

### 6.4 Falsification gate (P2 operationalised)

Three-question check before any HIGH-confidence output:

1. **What specific external observable would falsify this claim?** (a rate, count, date, threshold)
2. **In what timeframe?**
3. **What would the operator do differently if the falsifier triggered?**

If any of the three is unstateable → confidence downgrades to MEDIUM automatically. Code-council reviewer on the skill spec enforces this structurally per §10 AI-systems implications.

### 6.5 Agent-Disagreement Protocol (composes with council-protocol.md)

When two AI agents (within a council, or two skills feeding each other) produce conflicting recommendations, the doctrine defers to `council-protocol.md` for the structural deliberation layer (Devil's Advocate / Optimist / Neutral / etc.). The doctrine adds ONE rule on top:

**Decision-escalation rule**: when the council's Devil's Advocate and Optimist Strategist disagree materially (confidence spread >30%) on a load-bearing claim, the synthesis defaults to PAUSE not average. The operator (or `/decide-under-uncertainty` skill in operator mode) decides whether to:
- Run additional evidence-gathering before re-deliberating, OR
- Accept the higher-confidence side with explicit downgrade documentation, OR
- Defer the decision until the disagreement resolves with new evidence.

NEVER average conflicting confidence claims into a synthetic mid-range claim. Averaging hides the disagreement.

When the conflict is between two skills (one feeds the other), the patched `diagnostic-skill-anti-anchoring.md` rule's `hypothesis_provenance: prior_skill` branch handles it — validate-upstream mode rather than standard compare.

---

## 7. Leverage Points — Where Decision-Quality Pays Rent

Five places where this doctrine produces leverage the predecessor doctrines cannot:

1. **Multi-stakeholder disagreement adjudication** — the delegation Systems Thinking §3.2 hands here. When two parties (operator + Claude; operator + partner; two council agents) disagree on a load-bearing claim, this doctrine's escalation rule + falsification gate prevents premature compromise.

2. **Asymmetric-payoff decisions** — when one option has a recoverable downside and the other has an unrecoverable downside, P3's regret-minimisation framing catches this directly. EV calculation can miss it when probabilities are guessed close to 50/50.

3. **Evidence-conflict adjudication** — when new evidence disagrees with prior belief, P1's informal-Bayesian procedure forces the update to happen explicitly rather than be rationalised away.

4. **Unknown-unknown surfacing** — P2's falsification gate + the cost-of-being-wrong template force the operator to name failure modes they hadn't considered.

5. **AI-output calibration in real time** — P5 is the single most-applicable leverage point for the daily AI-vibe-coding workflow. Every Claude response is a P5 instance.

---

## 8. Failure Modes — Where This Doctrine Produces Wrong Results

Five failure modes, each with detection signals and defences:

**FM1 — Overconfident Bayesian update**: operator names evidence as "specific" when it is actually weak; posterior moves more than the evidence warrants.
- Detection: operator's confidence shift > 30% from a single piece of evidence.
- Defence: P1 falsification condition — name what evidence would NOT have moved the belief; check whether the actual evidence cleared that bar.

**FM2 — Expected-value theatre with fabricated probabilities**: operator invents probabilities to fill the template; EV calculation produces decimal-precision recommendation built on fabrication.
- Detection: probability source is `intuition` or `unknown` (per skill `probability_source` field).
- Defence: auto-switch to regret-minimisation framing (P3); skill output downgrades to ADVISORY on `model-default`.

**FM3 — Bias catalogue used as gotcha-tool against team or self**: naming biases becomes a way to dismiss disagreement rather than improve decisions.
- Detection: same bias named >3 times in one decision; bias-naming without counter-procedure.
- Defence: P4 requires detection signal + counter-procedure pairing; without both, bias-naming is decoration.

**FM4 — Falsification as nihilism / marker rot**: every claim demands "what would falsify this?" → operator burns out → markers degrade to "any contrary evidence."
- Detection: falsification markers across last 5 outputs are textually similar; specific external observable + timeframe absent.
- Defence: code-council reviewer prompt enforces specific-observable + timeframe constraint structurally per §10.

**FM5 — Calibration training without feedback loop**: operator starts logging predictions, never reviews them, calibration claim becomes worse not better.
- Detection: prediction log exists; no review cadence; no Brier score computed.
- Defence: P6 is concept-only until logging + review cadence both exist. Programme spec §214-226 quiet-failure-class commitment names this gap explicitly.

---

## 9. Anti-Patterns

Five anti-patterns the operator should recognise in real time:

**AP1 — "I'm just being thorough"**: Decision-Quality applied to a decision below A4's mattering threshold. Doctrine procedure adds 10 minutes; payoff is 5 seconds. Burnout precursor. Use intuition.

**AP2 — "The AI was confident, so I went with it"**: P5 false-positive — operator treats AI confidence as evidence. Detection: no falsifier was named (P2 violation).

**AP3 — "Three options: A, B, C — which one?"**: doctrine invoked to defer a decision the operator already has enough information for. Decide-don't-menu (per `layman-mode.md`) is the relevant rule; doctrine is not needed.

**AP4 — "We averaged the council's view"**: violates §6.5 — averaging conflicting confidence claims hides the disagreement. Synthesis MUST PAUSE on >30% spread.

**AP5 — "I logged it, that's enough"**: prediction logging without review cadence (FM5). Logs are necessary not sufficient.

---

## 10. AI-Systems Implications

This is the doctrine's highest-leverage novel application section — operators of AI-vibe-coding workflows hit these patterns weekly.

### 10.1 Calibration for LLM confidence claims

Per P5, LLM confidence is systematically miscalibrated relative to ground truth in the operator's domain. Concrete patterns:

- HIGH-confidence syntactically plausible wrong answers (the answer matches training distribution but is wrong in operator's specific codebase)
- LOW-confidence hedged right answers (the answer is correct but the model hedges on out-of-distribution terrain)
- Confidence does NOT track reasoning depth

Operator practice: every AI output gets P5 detection-signal check (§4 P5 table). The skill `/decide-under-uncertainty` runs this check structurally.

### 10.2 Bias injection in AI training data

LLM training data carries the biases of its source corpora. Detection: when the AI's recommendation closely matches the operator's stated framing without independent reasoning, the AI may be mirroring rather than reasoning. Counter: ask for the AI's reasoning chain explicitly; check whether it cites observed artefacts (file content, query results) versus generic patterns.

### 10.3 Asymmetric-payoff routing for AI-mediated decisions

When an AI agent recommends a decision with asymmetric payoffs, the doctrine's P3 cost-of-being-wrong framing must run BEFORE the recommendation is accepted. Specifically: AI agents do not natively distinguish recoverable from unrecoverable consequences. The operator must apply that filter.

Worked pattern: AI proposes "refactor approach A vs B." Operator runs cost-of-being-wrong: A's worst case (works but ugly code; recoverable in hours); B's worst case (subtle data corruption; recoverable in days with potential data loss). Verdict: A despite AI's preference for B, because the recoverability asymmetry dominates.

### 10.4 Falsification before deploying autonomous agents

Per P2, any HIGH-confidence claim about an autonomous agent's correctness requires a falsifier. Detection: deploying an agent (n8n workflow, agent-team session, scheduled job) without a stated "this is broken if X is observed" condition is FM4 + P2 violation simultaneously.

Operator practice: every autonomous-agent deployment includes one of: (a) a loud monitoring signal that fires on a specific observable, (b) a manual review cadence ≤7 days, (c) explicit acceptance that the agent will fail silently and that is acceptable. Without one of the three, deployment violates this doctrine.

### 10.5 Cross-skill chain validation

When the operator chains diagnostic skills (`/diagnose-bottleneck` → `/decide-under-uncertainty`), the downstream skill MUST recognise that the upstream output is the input hypothesis. The patched `diagnostic-skill-anti-anchoring.md` rule's `hypothesis_provenance: prior_skill` branch fires here — validate-upstream mode replaces standard compare. Without this, the chain produces internally consistent output where the hidden anchor is two layers deep and invisible.

---

## 11. Application Checklist — the procedure `/decide-under-uncertainty` operationalises

Run this checklist when a decision under uncertainty arrives. The skill mechanises it; the operator can run it manually for high-stakes calls.

**Step 1 — Scope gate**
- [ ] Is this question Decision-Quality in scope (per §3 boundary diagnostic)?
- [ ] Are there ≥2 genuine options (not "do X" vs "don't do X" where "don't do X" is structurally null)?
- [ ] Is at least one option's outcome observable in a timeframe that matters?
- [ ] Does the operator have authority to act on the recommended option?

If any "no" → halt and redirect, OR clarify input.

**Step 2 — Provenance check** (per patched anti-anchoring rule)
- [ ] What is the provenance of the operator's hypothesis? (`operator | prior_skill | session_history`)
- [ ] If `prior_skill` → switch to validate-upstream mode (rerun upstream skill with different parameters; check stability)
- [ ] If `session_history` → one-question clarification: "Is this your hypothesis or Claude's?"

**Step 3 — Probability source check** (P3)
- [ ] What is the source of any probability estimates? (`data-derived | operator-assigned | model-default`)
- [ ] If `operator-assigned` or `model-default` → switch from EV to regret-minimisation framing

**Step 4 — Bias detection** (P4)
- [ ] Run top-3 workshop biases (planning fallacy / base-rate neglect / overconfidence) with detection signals
- [ ] If any fire → apply counter-procedure before continuing

**Step 5 — AI-confidence check** (P5)
- [ ] If any input comes from an AI source, apply P5 detection signals (§4 P5 table)
- [ ] HIGH-confidence + no reasoning chain → demand the reasoning chain before proceeding

**Step 6 — Cost-of-being-wrong template** (P3)
- [ ] Fill the four cells (worst case, cost, recoverability, forgone-upside-cost) for each option
- [ ] Pick the option with most recoverable worst case at acceptable forgone-upside

**Step 7 — Falsification gate** (P2)
- [ ] State the falsifier for the chosen option: specific external observable + timeframe + operator's intended response if it fires
- [ ] If falsifier cannot be stated → downgrade confidence to MEDIUM

**Step 8 — Counterfactual statement**
- [ ] What would the operator have done without the doctrine? (default action)
- [ ] What does the doctrine recommend?
- [ ] Difference verdict: `none | marginal | substantial | transformative`
- [ ] If `none` or `marginal` → ADVISORY-pending; doctrine earned zero leverage for this case

**Step 9 — Agent-disagreement check** (if council ran upstream)
- [ ] Was there a council session on this decision with >30% spread between agents?
- [ ] If yes → apply §6.5 PAUSE rule; do NOT average

---

## 12. Real-Decision Test Appendix (Gate 3 — DEFERRED)

Gate 3 of `doctrine-verification-gate.md` requires applying this doctrine to one named past decision with actual-outcome ground-truth captured BEFORE doctrine application. The case must be nominated by a SECOND PARTY (operator OR Reframer-from-prior-council), not self-selected by the doctrine author.

**Status**: DEFERRED at Session 3 ship.

**Reason**: anti-sycophancy criterion (per programme spec §214-226 + plan v2 amendment A8). Sessions 1-2 deferred Gate 3 on the same constraint.

**Resolution pathway**: operator supplies a past decision-under-uncertainty case at any point post-ship. Recommended elicitation:

> "Name one past decision where you had ≥2 plausible options and committed without being certain you were choosing for the right reasons. Write down: (a) what you actually did, (b) what the actual outcome was, (c) what it cost in money/time/capacity/reputation/optionality, BEFORE consulting this doctrine. Then apply the Step 1-9 checklist to that case. If the doctrine's recommendation differs from your actual action AND a credible argument exists that the difference would have produced a better outcome, this Gate 3 returns PASS or STRONG-PASS."

A single cross-cutting case can validate Decision-Quality + TOC + Systems Thinking simultaneously if it spans all three.

**Verdict on file**: ADVISORY-pending Gate 3 second-party-nominated case.

---

## 13. Deletion Test Appendix (Gate 1)

Gate 1 of `doctrine-verification-gate.md` requires naming ≥2 downstream consumers that would have to re-invent this doctrine's content if it were deleted. The test answers: would removal cause complexity to reappear?

**Named consumers**:

1. **Session 4 skill code authoring** (`/diagnose-bottleneck` + `/map-feedback-loops` skill code; Session 3 plan v2 A10 mandate) — Session 4 will hit decision-under-uncertainty patterns when authoring the skills (when to fail loud vs quiet; when to return ADVISORY vs PASS; how to handle conflicting inputs from operator vs context). Without this doctrine, those calls get made ad-hoc, inconsistently across the two skills.

2. **Future propagation event (Session 5+)** — propagating skills to BuyBox AI / Nirvana Freight / MidAtlantic requires each entity's operators to make decisions about which skills to invoke when. Without Decision-Quality, each entity reinvents the AI-Confidence-Asymmetry detection patterns (P5) — same content, three places.

3. **Cross-doctrine synthesis layer** (deferred from Session 4 to Session 5+ per A10) — synthesis cannot run without three doctrines; without Decision-Quality, synthesis would be limited to TOC + Systems Thinking which produces a static-vs-dynamic comparison but no procedure for choosing between them under uncertainty.

4. **Future Decision-Quality skills** (calibration training when logged corpus exists; bias-specific detection skills; expected-value skill when probabilities are calibrated) — all reference this doctrine's principles + mechanisms.

5. **`council-protocol.md`** — §6.5 Agent-Disagreement Protocol composes with council-protocol's deliberation layer. The decision-escalation rule (PAUSE on >30% spread; never average) is Decision-Quality's net-new contribution; without this doctrine, council synthesis would default to averaging, which hides disagreement.

**Verdict**: Gate 1 PASS — five named consumers, four with specific re-invention work that this doctrine prevents, one composition partner (council-protocol) that the doctrine extends rather than replicates.

---

## 14. References

**Primary sources** (cited where doctrine principles draw on specific work):

- Bayes, T. — informal Bayesian belief revision (P1, §6.1). Modernised in Jaynes, *Probability Theory: The Logic of Science* (2003).
- Popper, K. — falsification as quality criterion for hypotheses (P2). *Logic of Scientific Discovery* (1959); *Conjectures and Refutations* (1963).
- Tetlock, P. — calibration concept (P6, deferred). *Superforecasting* (2015); *Expert Political Judgment* (2005). Brier-score implementation deferred to v0.2.
- Kahneman, D. — bias-as-detection-signal source material (P4). *Thinking, Fast and Slow* (2011). Workshop-class top-3 selected; broader catalogue in §6.3.
- Savage, L. J. — expected-value framework when probabilities are subjective (P3 context). *Foundations of Statistics* (1954).
- von Neumann, J. & Morgenstern, O. — expected-utility axioms (P3 context). *Theory of Games and Economic Behavior* (1944).

**Workshop sources**:

- `council/sessions/2026-05-12-session-3-calibration-council.md` — extended council that produced the 10 amendments shaping this doctrine
- `.claude/rules/diagnostic-skill-anti-anchoring.md` (post-Phase-3.5 patch) — anti-anchoring + hypothesis-provenance rule that the `/decide-under-uncertainty` skill imports
- `.claude/rules/doctrine-verification-gate.md` — triple gate mechanism this doctrine is verified against
- `docs/operational-doctrine/01_theory-of-constraints.md` §3.2 — delegation of decision-under-uncertainty to this doctrine
- `docs/operational-doctrine/02_systems-thinking.md` §3.2 — delegation of decision-under-uncertainty + multi-operator disagreement to this doctrine
- `.claude/rules/council-protocol.md` — composition layer for §6.5 Agent-Disagreement Protocol

**Out-of-scope frameworks cited for boundary clarity**:

- Pearl, J. — *Causality* (2009). Pearl SCM is §3.4 OUT.
- Knight, F. — *Risk, Uncertainty and Profit* (1921). Knightian uncertainty is §3.5 OUT; Ellsberg's 1961 paradox extension also OUT.
- Schelling, T. — *The Strategy of Conflict* (1960). Game-theoretic equilibrium is §3.3 OUT.

---

## Appendix A — Worked Examples

### Example 1 — Non-software domain (Nirvana fleet dispatch under uncertain driver availability)

**Decision context**: Nirvana Freight dispatcher at 06:00 — three drivers reported sick overnight; four trips scheduled for the day; one of the trips is a 14-hour interstate haul that requires specific driver certification (only 2 of remaining 5 drivers hold it).

**Option A**: Cancel the 14-hour haul; serve the other 3 trips fully staffed.
**Option B**: Run the 14-hour haul; serve 2 of the other 3 trips; defer the third to tomorrow.
**Option C**: Subcontract the 14-hour haul to a partner carrier; serve all 4 trips internally.

**Doctrine application (Steps 1-9)**:

- Step 1 scope: yes to all 4 (decision-under-uncertainty, ≥2 options, observable outcomes, dispatcher has authority).
- Step 2 provenance: `operator` (dispatcher's framing).
- Step 3 probability source: `operator-assigned` — dispatcher estimates 70% chance the sick drivers return tomorrow. Source = intuition. Switch to regret-minimisation.
- Step 4 bias check: base-rate neglect risk — what's the historical rate of next-day driver recovery? Dispatcher checks: 80% over past 30 days. Confidence in 70% estimate calibrated upward to 80%.
- Step 5 AI-confidence: no AI input.
- Step 6 cost-of-being-wrong:

| Option | Worst case | Cost | Recoverability | Forgone-upside if right |
|--------|-----------|------|----------------|------------------------|
| A | Lose 14-hour client | Long-term contract loss + reputation | Months | Today's haul revenue |
| B | Drop 3rd trip; weak service | Customer churn for that route | Weeks | Tomorrow's catch-up cost |
| C | Subcontractor delivers late | Margin loss + partial reputation hit | Days | Internal driver hours wasted |

- Step 7 falsification: dispatcher's chosen option = C. Falsifier: "If subcontractor late-delivery rate this month exceeds 15%, this was the wrong call." Timeframe: 30 days. Operator response if triggered: switch to Option B framework next time.
- Step 8 counterfactual: dispatcher's default would have been Option B (familiar pattern). Doctrine recommends C. Difference: `substantial` (recoverability dominates; B's customer-churn risk is week-class while C's margin-loss is day-class).
- Step 9 agent-disagreement: not applicable (no council ran).

**Result**: C with HIGH confidence + stated falsifier. Decision counterfactual is substantial; doctrine earned leverage in this case. This example is hypothetical for illustration; actual Nirvana dispatch decisions would need real ground-truth.

### Example 2 — Workshop-operator-specific (Worktree-Branch-Choice)

**Note for propagation**: this example is workshop-operator-specific. Operators in other contexts (real-estate, freight, agency operations) substitute their domain's equivalent parallel-work decision.

**Decision context**: Operator has a feature branch with 3 commits pending PR review. Claude proposes a refactor that touches 8 files overlapping the pending branch. Three options:

**Option A**: Apply refactor on current branch; bundle with PR (increases PR scope).
**Option B**: Spawn new worktree on `origin/main`; apply refactor there; rebase pending branch onto refactored main.
**Option C**: Defer refactor until pending PR merges; apply afterward.

**Doctrine application (Steps 1-9 highlights)**:

- Step 4 bias check: sunk-cost risk — operator has invested in the 3 pending commits; tempted to bundle (Option A) to avoid context-switch. Counter: would the operator start the refactor on the current branch if there were zero pending commits? If no, sunk-cost is firing.
- Step 5 AI-confidence: Claude proposed refactor with HIGH confidence + explicit reasoning chain citing the 8 files. Per P5 detection-signal table, this is confidence-at-face-value (not the MEDIUM-downgrade case).
- Step 6 cost-of-being-wrong:

| Option | Worst case | Recoverability |
|--------|-----------|----------------|
| A | PR scope creep delays review by days | Days (smaller PR can be re-extracted) |
| B | Rebase conflicts compound; cleanup eats half-day | Hours |
| C | Pending PR merges; refactor wisdom is lost or context shifts | Permanent (memory decay) |

- Step 7 falsifier: chosen option = B. Falsifier: "If rebase conflicts exceed 30 minutes to resolve, this was the wrong call; Option A would have been faster." Timeframe: this session.
- Step 8 counterfactual: operator's default = A (bundling pattern). Doctrine recommends B. Difference: `marginal` (B is slightly better but A would survive). ADVISORY-pending.

**Result**: B with MEDIUM confidence + stated falsifier; counterfactual `marginal` means the operator could go either way without doctrinal violation. Demonstrates that not every doctrine invocation must produce a `transformative` verdict — `marginal` is honest.

**Agent-Disagreement note**: if Claude and operator had disagreed on the chosen option (Claude pushing A, operator preferring B), §6.5 PAUSE rule would fire. Operator gathers additional evidence (e.g., check whether the 8 files have outstanding changes from other worktrees) before re-deliberating.

---

## Status Footer

| Dimension | Status |
|-----------|--------|
| **Gate 1 (deletion-as-re-invention)** | PASS — 5 named consumers (§13) |
| **Gate 2 (code-council with doctrine-specific rubric)** | DEFERRED to fresh-context ceremony (Sessions 1-2 precedent); recommended sequence: run code-council on all three MVP doctrines together post-Session-3 to surface cross-doctrine consistency issues |
| **Gate 3 (real-decision test with counterfactual)** | DEFERRED — second-party-nominated case required per A8; anti-sycophancy criterion blocks self-nomination |
| **Composite verdict** | **ADVISORY** with two named gaps (Gate 2 + Gate 3 deferrals); structural gates passed; no BLOCKING findings |
| **First invocation expected by** | 2026-06-11 (30 days post-ship per A9; zero-invocation past this date triggers retire-or-use signal) |
| **Propagation readiness** | NOT YET — Gate 2 + Gate 3 must close before any /push-to-template event; Session 5 dependency |
| **Composes with** | council-protocol (§6.5); diagnostic-skill-anti-anchoring (patched, §10.5 + Step 2); doctrine-verification-gate (Gates); code-review-identity (P2 enforcement); agentic-loop-guards (P7 verification layer); pre-completion-pocock-check (P5 + P2 alignment with plan-class gates) |
| **Operator self-check per programme spec §214-226** | Before invoking `/decide-under-uncertainty`, write down what you would do without it (one sentence). After receiving the skill's recommendation, write down whether it differs (yes/no/marginally). If the recommendation matches your default, the doctrine earned zero leverage for this case — flag as ADVISORY-pending; nominate a different real-decision test case |

---

*Doctrine v0.1 authored 2026-05-12 post-extended-council calibration. Council session: `council/sessions/2026-05-12-session-3-calibration-council.md`. Plan: `specs/02_PLAN_V2_SESSION_3.md` v2 with 10 integrated amendments.*
