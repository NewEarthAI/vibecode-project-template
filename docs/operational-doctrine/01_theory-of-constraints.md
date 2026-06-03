---
name: Theory of Constraints (Operationalised)
type: operational-doctrine
status: ADVISORY (Phase 6 triple verification complete; 3 Critical code-council items patched; 2 Important items remain as named gaps)
version: 0.2
authored: 2026-05-10
last_verified: 2026-05-10 (Phase 6 — see council/code-reviews/2026-05-10-toc-doctrine.md)
related_skill: /diagnose-bottleneck (spec at specs/03_DIAGNOSE_BOTTLENECK_SKILL.md)
related_doctrines: (forthcoming) 02_systems-thinking.md, 03_decision-theory.md
primary_sources:
  - Goldratt, E. M. & Cox, J. (1984). *The Goal: A Process of Ongoing Improvement*. North River Press.
  - Goldratt, E. M. (1990). *Theory of Constraints*. North River Press.
  - Goldratt, E. M. (1994). *It's Not Luck*. North River Press.
  - Goldratt, E. M. (1997). *Critical Chain*. North River Press.
  - Cox, J. F. & Schleier, J. G. (2010). *Theory of Constraints Handbook*. McGraw-Hill.
  - Kim, G., Behr, K., & Spafford, G. (2013). *The Phoenix Project*. IT Revolution Press.
  - Forrester Research / Lean Enterprise Institute. *Learning to See* (Rother & Shook, 1999).
  - Forsgren, N., Humble, J., & Kim, G. (2018). *Accelerate*. IT Revolution Press.
---

# Theory of Constraints — Operationalised Doctrine

## 1. Purpose

This doctrine converts Eliyahu Goldratt's Theory of Constraints (TOC) from an academic management framework into operational guidance suitable for executable use by AI agents and human operators inside the the agency ecosystem.

It exists to answer one question fast: **where is the binding constraint in this system, and what is the highest-leverage intervention available right now?**

**Use this doctrine when:**

- A throughput-constrained system needs diagnosis (work moves through stages; output is observable; capacity differs across stages)
- Capacity-planning decisions are pending (hire? scale? automate? buy?)
- A pipeline is "slow" and the operator does not yet know which stage is binding
- Multiple improvement candidates compete for limited operator attention and a ranking principle is needed
- Resource allocation has historically improved local metrics without improving end-to-end throughput

**Do NOT use this doctrine when:**

- The system has no defined flow (see Section 3, scope boundary)
- The bottleneck is political, organisational, or social (TOC's tools have no purchase; use stakeholder mapping or org-design frameworks)
- The constraint is external demand, not internal flow (a doctrine on market positioning is the right tool)
- The system is genuinely multi-bottleneck (apply Section 8 multi-bottleneck decomposition before invoking TOC's single-constraint procedure)

This doctrine is **operational, not analytical**. Its claims are framed as falsifiable interventions, not descriptive theory. Every governing principle is paired with a behaviour change the principle commands.

---

## 2. Why TOC Earned Its Slot in This Workshop

The workshop's own propagation problem — methodology trapped in operator-context, unable to reach client projects at known cadence — is itself a TOC problem. The bottleneck is propagation throughput, not framework knowledge. By making TOC the workshop's first operational doctrine, the workshop **dogfoods** its own diagnostic tool on its own delivery system. If the doctrine cannot accelerate the workshop's propagation rate, it has failed to earn its slot regardless of how well it performs on client decisions.

This self-referential structure is the deletion test (Section 13) applied prospectively: if this doctrine were removed, the workshop would have no shared diagnostic vocabulary for its central NSM (propagation rate), and every subsequent session would re-derive bottleneck reasoning from scratch. The doctrine has work to do that no other workshop artefact does.

---

## 3. Scope Boundary — What This Doctrine Does NOT Do

TOC is a tool for a specific class of problem. Misapplied, it produces confident wrong answers. The doctrine explicitly refuses jurisdiction over:

### 3.1 Dynamic System Behaviour (delegated to Systems Thinking doctrine — Session 2)

TOC describes a static snapshot: at this moment, the constraint is here, and the recommended intervention is X. It does NOT model:

- Feedback loops (positive or negative)
- Time delays between intervention and effect
- Oscillations, overshoots, or stock-and-flow dynamics
- Unintended consequences emerging from interventions over time
- Compounding effects (e.g., improvement-debt loops, technical-debt accumulation)

A system whose primary characteristic is dynamic instability — say, a Twitter feedback storm, a viral growth curve, or a slow-burn technical-debt accumulation — is the Systems Thinking doctrine's territory.

### 3.2 Decision-Under-Uncertainty (delegated to Decision Theory doctrine — Session 3)

When evidence about the constraint is ambiguous, weak, or contested, TOC cannot adjudicate. It assumes the constraint is locatable through observation. It does NOT address:

- Bayesian belief revision when evidence conflicts
- Expected-value calculations across multiple candidate interventions
- Cost of being wrong about which constraint is binding
- Decision protocols for unknown-unknowns

A decision whose primary difficulty is uncertainty about *which* bottleneck exists — versus uncertainty about *how* to fix a known bottleneck — is Decision Theory's territory.

### 3.3 Political and Organisational Constraints

A bottleneck caused by a single decision-maker, regulatory body, or organisational politics is real and important. TOC's tools (flow diagrams, throughput accounting, drum-buffer-rope sequencing) have no purchase on these constraints. The doctrine names them as constraints honestly but redirects to stakeholder-mapping references rather than pretending to address them.

### 3.4 Demand-Constrained Systems

When the binding constraint is external market demand (not internal capacity), TOC produces a degenerate analysis ("the constraint is the market"). This is technically correct but operationally useless. Market constraints belong to a market-positioning doctrine, not a flow-constraint doctrine.

**Boundary diagnostic** — before applying this doctrine, run a 30-second test:

1. Does the system have a definable flow (work entering at A, exiting at B, with intermediate stages)?
2. Can throughput at each stage be observed or estimated (units per time period)?
3. Is the slowest stage internal to the system (not "we don't have enough customers")?
4. Is the bottleneck physical or process-based (not "the CEO won't approve")?

If any answer is "no," this doctrine is not the right tool. Stop and pick a different framework.

---

## 4. Governing Principles

These are the load-bearing claims TOC rests on. Each is paired with a behaviour the principle commands. Each is falsifiable — there are systems where the principle produces wrong predictions, and Section 8 names them.

### Principle 1: Every flow-based system has at least one binding constraint

**Claim**: A system that processes work through multiple stages always has one (or more) stages whose capacity limits the system's total throughput. Adding capacity to non-constraint stages does not increase total output.

**Behaviour commanded**: Before any capacity investment, locate the constraint. Investment elsewhere is at best wasted; at worst, it shifts the constraint to a less manageable place.

**Falsifiable**: Systems with extreme parallelism, fungible workers, or capacity slack across all stages can have NO binding constraint. See Section 8 multi-bottleneck failure mode for cases where Goldratt's "exactly one constraint" claim is empirically false.

### Principle 2: Local optimisation does not aggregate to global optimisation

**Claim**: Maximising throughput at a non-constraint stage produces local efficiency gains but does not increase total system throughput. In fact, it often produces excess work-in-process at the constraint, increasing inventory and operating expense without improving output.

**Behaviour commanded**: Resist the temptation to optimise visible inefficiencies that are not at the constraint. A stage running at 70% utilisation is fine if it's not the constraint. A stage running at 100% utilisation is suspicious — if it's not the constraint, it's overproducing.

**Falsifiable**: Some systems have hidden coupling where non-constraint optimisation reduces error rate or improves downstream quality, indirectly raising constraint throughput. The doctrine does not cover hidden-quality-coupling cases.

### Principle 3: The Five Focusing Steps form a continuous cycle, not a one-time procedure

**Claim**: After elevating a constraint (raising its capacity), the constraint typically moves to a new stage. The doctrine's value comes from continuous application, not one-shot diagnosis.

**Behaviour commanded**: Every intervention triggers a re-application of Step 1 (Identify). The procedure is a loop. Skipping the re-evaluation after intervention is one of the most common anti-patterns (Section 9).

**Falsifiable**: Some constraints, when adequately elevated, never re-bind. A workflow with a 1000x capacity ratio between the elevated constraint and the next-slowest stage may not need re-evaluation for the lifetime of the system. The doctrine does not require re-evaluation when the new constraint's capacity is >10x current operating throughput.

### Principle 4: Throughput accounting outranks traditional cost accounting for capacity decisions

**Claim**: Three metrics — Throughput (T = revenue minus truly variable cost per unit), Inventory (I = capital tied up in unprocessed work), and Operating Expense (OE = all other costs) — produce different capacity decisions than standard cost accounting. Improvements that raise T should be ranked above improvements that reduce OE if they conflict.

**Behaviour commanded**: When evaluating an intervention, compute its effect on T, I, and OE separately. An intervention that raises OE by 10% to raise T by 30% is correct under TOC even if traditional cost accounting flags it as expense growth.

**Falsifiable**: Throughput accounting assumes revenue is uncapped at the constraint. In demand-constrained systems (Section 3.4), T is capped externally and OE-reduction interventions become correct again. The doctrine deliberately limits its scope to flow-constrained systems.

### Principle 5: The constraint type determines the intervention class

**Claim**: Constraints come in three flavours: physical (insufficient resource, e.g., one machine), policy (a rule that prevents flow, e.g., "every PR must be reviewed by 3 senior engineers"), and market (external demand). Each requires a different intervention class. Physical constraints elevate via capacity addition; policy constraints elevate via rule change; market constraints elevate via demand generation (out of this doctrine's scope).

**Behaviour commanded**: Before recommending an intervention, classify the constraint type. A policy constraint dressed up as a physical constraint will not respond to physical-capacity interventions and will produce a recurring "we keep hitting this bottleneck" cycle.

**Falsifiable**: Some constraints have hybrid character (a policy that requires a physical resource, e.g., "must run on a specific deployment server" — both policy and physical). The doctrine handles hybrids by decomposing them into their components and addressing each separately.

---

## 5. Assumptions

This doctrine assumes the following are true. If any is false in a target system, the doctrine produces unreliable output:

- **A1**: The system has a definable flow (work in → stages → output)
- **A2**: Throughput at each stage is observable or estimable (units per unit time)
- **A3**: There is at least one stage whose capacity is materially lower than others
- **A4**: The binding constraint is internal to the system, not external (no market-demand constraint)
- **A5**: Stages have causal relationships (output of stage N is input to stage N+1)
- **A6**: The system is not so small that the constraint is trivially obvious without analysis

Assumption violations to test before invoking the doctrine:

| Assumption | If violated | Diagnosis | Redirect |
|------------|-------------|-----------|----------|
| A1 (no defined flow) | "Our process is slow" with no named stages | System is undefined | Map the flow first (use service-blueprinting or value-stream-mapping reference) |
| A2 (throughput unmeasurable) | Stage throughput is "feels slow" | Symptom, not measurement | Define one observable metric per stage before invoking |
| A3 (capacity uniform) | All stages run at ~equal capacity | TOC produces marginal value | Investigate quality, error rate, or rework loops instead |
| A4 (market constraint) | "We can't sell more" | Market-positioning problem | Out of scope; use go-to-market doctrine |
| A5 (parallel stages) | Stages run independently with no causal link | Multi-flow system | Apply per-flow, not aggregated |
| A6 (trivially obvious) | "The slow step is obviously X" | Doctrine adds friction | Skip to intervention, document reasoning |

---

## 6. Mechanisms

This section is the operational core. These are the procedures the doctrine commands, in execution order.

### 6.1 The Five Focusing Steps

The canonical TOC procedure (Goldratt, 1990). Apply in strict order — skipping Step 2 (Exploit) before Step 4 (Elevate) is one of the doctrine's most expensive anti-patterns.

**Step 1 — Identify the system's constraint**

Locate the stage whose capacity is materially below the slowest demand the system needs to meet. Common signals:

- Work-in-process accumulates UPSTREAM of this stage
- Stages DOWNSTREAM run idle or below capacity
- This stage is always "busy" or "behind"
- Lead-time variability spikes at or near this stage

Document the constraint with: (a) the stage name, (b) the observed throughput, (c) the demanded throughput, (d) the throughput gap.

**Step 2 — Decide how to exploit the constraint**

Before adding capacity, extract maximum value from the existing constraint. Common exploitations:

- Eliminate idle time at the constraint (lunch breaks staggered, queue feeding the constraint never empty)
- Move quality control UPSTREAM of the constraint (do not let defective work consume constraint capacity)
- Move setup/changeover work OFFLINE from the constraint
- Schedule the most valuable / highest-margin work through the constraint first
- Reduce setup time at the constraint (SMED-style techniques)

Exploitation costs are typically near-zero. The Exploit step often delivers 20-50% throughput improvement without capacity investment.

**Step 3 — Subordinate everything else to the above decision**

Non-constraint stages run at the constraint's pace, not their own. This means:

- Upstream stages release work to feed the constraint, not faster
- Downstream stages process the constraint's output at constraint pace
- All planning and scheduling tools key off the constraint's capacity, not the system average
- Local efficiency metrics at non-constraints are explicitly de-prioritised

Subordination is psychologically the hardest step. It tells productive workers and well-meaning managers to slow down or run below capacity. The doctrine commands this even when it feels counter-productive — because the alternative is excess work-in-process, longer lead times, and no throughput improvement.

**Step 4 — Elevate the constraint**

Only if Steps 2-3 have been fully applied and the constraint still binds: add capacity at the constraint. Possibilities:

- Hire / acquire additional capacity at the constraint stage
- Automate the constraint stage
- Outsource constraint work
- Invest in equipment / tools / training at the constraint
- Eliminate the constraint (replace it with a fundamentally different process)

Elevate is the most expensive step. It is also the step most often jumped to prematurely. Goldratt's central insight: most "we need to hire" or "we need to scale" decisions are made before Step 2 has been seriously attempted.

**Step 5 — If the constraint moved, return to Step 1; warn against inertia**

After elevation, the binding constraint has likely shifted to another stage. The procedure restarts. The doctrine explicitly warns against:

- Continuing to manage the old constraint after it ceased to bind
- Building organisational structures (titles, dashboards, meetings) around a constraint that has moved
- Treating the focusing steps as a one-time exercise

Inertia is the single most common cause of TOC failure post-elevation. The doctrine commands a re-evaluation after every intervention, even when the intervention appears to have "fixed" the problem.

### 6.2 Drum-Buffer-Rope (DBR)

A scheduling mechanism that operationalises Step 3 (Subordinate). Three components:

- **Drum** — the constraint's pace. All scheduling beats to this drum.
- **Buffer** — a protective time-or-inventory buffer immediately upstream of the constraint, sized to absorb upstream variability without starving the constraint. Typically 2-4x the average variability of upstream stages.
- **Rope** — a signal from the constraint back to the first stage in the flow, controlling work release. Work enters the system only at the rate the constraint can absorb.

DBR replaces local scheduling (each stage runs as fast as it can) with constraint-keyed scheduling (each stage runs to keep the constraint fed, no faster).

For AI-systems applications (Section 10), DBR maps directly to backpressure mechanisms in stream processing, queue depth limits in agent pipelines, and rate-limiting at upstream API gateways feeding constrained downstream services.

### 6.3 Throughput Accounting

Three operational metrics:

- **T (Throughput)** = sales revenue minus truly variable cost per unit sold. Variable cost includes only costs that scale linearly with units produced (e.g., raw materials, per-unit licensing). Salaries, rent, and overhead are NOT variable cost under TOC.
- **I (Inventory)** = capital tied up in unprocessed work. Raw materials, work-in-process, finished goods.
- **OE (Operating Expense)** = all other costs (salaries, rent, depreciation, fixed costs).

Decision rule under TOC: **prefer interventions that raise T over interventions that reduce OE.** A 30% T improvement at a 10% OE increase is correct. A 5% OE reduction at the cost of 2% T loss is wrong.

Throughput accounting differs from standard cost accounting in two material ways:
1. It treats most "fixed costs" as operating expense, not as cost allocated to units (no per-unit overhead burden)
2. It values throughput growth above expense reduction when they conflict

---

## 7. Leverage Points

Where TOC provides disproportionate diagnostic value:

### 7.1 Pipelines with measurable throughput

Manufacturing lines, software deployment pipelines, lead-qualification funnels, ETL pipelines, content production workflows. Any system where throughput is observable and stages are discrete is high-leverage territory for TOC.

### 7.2 Multi-step processes with one visibly slow step

When operators report "the slow step is obviously X but we can't seem to fix it," TOC's Exploit step typically reveals 20-50% latent capacity at that step before any Elevate (hire / scale / invest) is needed. The "we need to hire more people at X" reflex is, in TOC's analysis, almost always premature.

### 7.3 Resource-constrained operations

Operations where a specific resource (a senior engineer, a single machine, a specific licence) is consistently the limiter. TOC's policy/physical/market classification (Principle 5) reveals whether the resource constraint is truly physical or is a policy constraint disguised as a physical one.

### 7.4 Capacity planning under uncertainty

When the operator is choosing among capacity investments (hire vs. automate vs. outsource), TOC's Step 4 framing forces an explicit comparison against Step 2 (have we exploited fully?) and Step 3 (have we subordinated?). Most capacity-planning decisions improve dramatically when these prior questions are answered honestly.

### 7.5 AI agent pipelines (highest-leverage novel application — see Section 10)

Multi-stage AI agent workflows have constraints (sub-agent context windows, tool-call latency, retrieval bandwidth, LLM token budget) that TOC's tools translate to directly. This is the doctrine's most novel application area and the area where it offers most differentiated value over conventional optimisation thinking.

---

## 8. Failure Modes — Where This Doctrine Produces Wrong Results

Honest accounting of where TOC fails. Each failure mode is named explicitly so the doctrine can refuse jurisdiction rather than produce confident wrong answers.

### 8.1 Multiple binding constraints simultaneously

Goldratt's claim of "exactly one binding constraint at any time" is empirically false in systems with:

- Independent demand sources (a sales pipeline that simultaneously handles inbound leads AND outbound campaigns)
- Heavily parallelised work (an agency running 12 concurrent client projects, each with its own bottleneck)
- Multiple resource pools sharing fungible workers (a team where any developer can theoretically work on any project)

**Symptoms of multi-bottleneck systems**: switching one constraint reveals a second of similar magnitude almost immediately; throughput-leverage analysis shows ~equal returns from interventions at 2-3 different stages.

**Doctrine response**: decompose into independent sub-systems. Apply TOC per sub-system. Do NOT aggregate into a single procedure.

### 8.2 Political / organisational constraints

A bottleneck caused by a single decision-maker, regulatory hold-up, or organisational politics is a real bottleneck. TOC's tools have no purchase here. The doctrine names this case explicitly and redirects.

**Symptoms**: the "constraint" is a name, not a stage; throughput is gated by a person's calendar, not a resource's capacity; "exploiting" the constraint sounds awkward because it would mean asking the person to work harder, which is the wrong intervention.

**Doctrine response**: redirect to stakeholder mapping. Note the constraint is real, but TOC cannot address it. Recommend the operator find or build a doctrine for organisational constraints.

### 8.3 Undefined or pre-flow systems

A project on day 3 of existence with no formalised process has no flow to analyse. TOC requires a defined flow. Applied to an undefined system, the doctrine produces "system not defined enough for analysis" — which is correct but unhelpful.

**Symptoms**: stages are described in different vocabularies by different stakeholders; no two people agree on what the steps are; no metrics exist at stage level.

**Doctrine response**: produce a structured "insufficient input" error. Recommend the operator complete a flow-mapping exercise (one paragraph per stage; one metric per stage; one transition rule between stages) before re-invoking.

### 8.4 Demand-constrained systems

When the binding constraint is external market demand, TOC produces a degenerate analysis: "the constraint is the market." This is technically correct but operationally useless — no Step 2 exploitation, no Step 3 subordination, no Step 4 capacity investment will help.

**Symptoms**: internal capacity sits idle at all stages; sales cycles are long; pipelines have insufficient volume to test constraint hypotheses.

**Doctrine response**: state the market constraint explicitly. Redirect to market-positioning / go-to-market / sales-pipeline doctrines.

### 8.5 Wrong-test-case grading (real-decision test failure mode)

A test case where TOC's identification step produces the same answer as common-sense intuition does NOT prove the doctrine earned its keep. Example: a list-page query timing out at 27 seconds. TOC identifies "the slow query = constraint." But the actual intervention ("run `ANALYZE` to refresh planner statistics") is database operational knowledge, not TOC. Grading the test PASS on this case means the bar is "framework identifies the symptom," not "framework produces the correct intervention."

**Failure indicator**: doctrine recommendation matches what was actually done. Counterfactual outcome is zero (no new leverage).

**Doctrine response**: the real-decision test (Section 12) must produce a recommendation that DIFFERS from what was done, or the doctrine is downgraded to ADVISORY-pending for that case.

### 8.6 Hidden quality coupling

Some systems have non-obvious causal coupling between non-constraint stages and constraint output. Example: a high error rate at a non-constraint upstream stage that produces silent defects, consuming constraint capacity for rework. TOC's "local optimisation at non-constraint is wasted" claim (Principle 2) does not apply if the local optimisation reduces downstream rework.

**Symptoms**: throughput improvement at the constraint produces less-than-expected gains; rework loops exist but are not visible in the flow diagram.

**Doctrine response**: flag the hidden coupling. Note that pure TOC produces marginal recommendations in these cases. Recommend supplementing with quality-cost analysis or rework-loop mapping.

---

## 9. Anti-Patterns

Common misapplications. Each is paired with a detection signal so operators can catch the anti-pattern before shipping the recommendation.

### 9.1 Optimising the non-constraint

**Pattern**: An operator identifies the constraint correctly, then invests effort elsewhere because "everyone's working hard at X" or because the non-constraint optimisation is technically interesting.

**Detection**: After a proposed intervention, ask: "Does this raise the constraint's throughput?" If no, the intervention is at the non-constraint. Reject or defer.

### 9.2 Treating non-constraint slack as waste

**Pattern**: A non-constraint stage runs at 70% utilisation. Management initiative attempts to push it to 100%. Result: work-in-process accumulates between this stage and the constraint, lead times increase, throughput unchanged.

**Detection**: utilisation targets imposed on non-constraint stages. The doctrine commands the OPPOSITE: deliberate slack at non-constraints, full utilisation only at the constraint.

### 9.3 Skipping Exploit, jumping to Elevate

**Pattern**: Operator identifies constraint, immediately proposes hiring / scaling / investing. Step 2 (Exploit) is skipped.

**Detection**: the proposed intervention is "more X" (more people, more compute, more licences). Ask: "Have we eliminated idle time at the constraint? Moved quality checks upstream? Eliminated setup time? Sequenced highest-value work first?" If any answer is no, return to Step 2 before approving Step 4.

### 9.4 Failure to subordinate

**Pattern**: Constraint correctly identified, exploited, even elevated. But non-constraint stages still measured on local efficiency. Result: work-in-process surges, the constraint is "fed" too fast, the elevation gains evaporate into inventory growth.

**Detection**: non-constraint stages have utilisation targets. Local efficiency dashboards exist. The doctrine commands the elimination of these metrics for non-constraint stages.

### 9.5 Inertia after constraint moves

**Pattern**: Elevation raises constraint capacity. New constraint emerges at a different stage. Organisation continues to manage the OLD constraint (meetings, dashboards, attention) even though it is no longer binding.

**Detection** (concrete threshold): re-evaluate within **4 weeks** of any elevation event. Specifically: if >4 weeks have elapsed since the last Step 1 (Identify) run AND an elevation intervention was deployed since that run, the anti-pattern is presumed active until a fresh Step 1 is performed. Supplementary signals: operator has not run Step 1 (Identify) since the elevation; capacity dashboards still highlight the previous constraint; team meetings still focus attention on the elevated stage. The 4-week threshold is project-invented, not industry-codified — chosen because (a) most elevation effects stabilise within 2-3 weeks of deployment, (b) constraint shifts typically become observable within 1-2 weeks of stabilisation, and (c) 4 weeks is a frequent enough cadence to catch shifts before they accumulate organisational inertia. Operators may shorten this threshold for fast-moving systems.

### 9.6 Multi-bottleneck blindness

**Pattern**: System has multiple binding constraints (Section 8.1). Operator picks one, applies TOC to it, ignores the others. Throughput improvement is marginal because the un-addressed constraints still bind.

**Detection**: after applying TOC to constraint A, throughput improves <20% of what was predicted. Returns indicate constraint B (or C) is co-binding.

### 9.7 Confusing constraint type

**Pattern**: A policy constraint ("every PR must be reviewed by 3 senior engineers") is treated as a physical constraint ("we need more senior engineers"). Result: hiring solves nothing because the policy still gates throughput.

**Detection**: ask whether the constraint would disappear if the rule were changed. If yes, the constraint is policy, not physical. The intervention is rule change, not capacity addition.

---

## 10. AI-Systems Implications

The doctrine's novel application area. TOC's vocabulary translates directly to AI agent pipelines, multi-step LLM workflows, retrieval-augmented generation systems, and orchestration patterns. This section is the doctrine's most differentiated contribution — most management doctrines do not address AI-systems applicability explicitly.

### 10.1 The AI agent pipeline as a flow system

A typical AI agent pipeline has stages:
- Input handling / context loading
- Retrieval (vector search, document loading)
- Reasoning (LLM inference)
- Tool calls (external API, code execution, file operations)
- Aggregation / synthesis
- Output formatting

Each stage has measurable throughput (requests per second, tokens per second, tool calls per second). The slowest stage is the constraint. TOC's tools apply directly.

### 10.2 Common AI-systems constraints

**Context-window constraint**: When sub-agents have smaller context windows than the orchestrator, the sub-agent's context becomes the binding constraint. Exploitation: pre-summarise input; only pass essential context. Subordination: orchestrator does not pass more context than sub-agent can absorb. Elevation: use larger-context sub-agent or chunk the work.

**Tool-call latency constraint**: When a workflow depends on an external API with high latency (seconds-per-call), and the workflow does many calls, the tool call is the constraint. Exploitation: cache, batch, parallelise. Subordination: do not pre-fetch more data than the workflow can use. Elevation: replace the API, run a local model, or move to a faster provider.

**Retrieval-bandwidth constraint**: In RAG pipelines, retrieval time often exceeds generation time. The retrieval is the constraint. Exploitation: vector index optimisation, query rewriting, smaller chunks. Subordination: do not let generation race ahead of retrieval. Elevation: faster vector store, better embedding model, hybrid search.

**Token-budget constraint**: When per-session token budget is the binding limit (rather than time), the constraint shifts from latency to token-economy. Exploitation: compression, structured output, caching. Subordination: do not generate intermediate reasoning that won't be used. Elevation: larger token budget or different model.

### 10.3 Drum-Buffer-Rope for AI pipelines

The DBR pattern maps cleanly to backpressure in stream-based AI systems:

- **Drum** = the slowest stage (e.g., the reasoning LLM at 10 tokens/sec)
- **Buffer** = a request queue immediately upstream of the LLM, sized to absorb retrieval variability
- **Rope** = a rate limit at input ingestion that prevents the system from accepting more requests than the LLM can process

Systems that lack DBR mechanisms (no buffer between stages, no rope at ingestion) exhibit either constraint starvation (the LLM occasionally sits idle) or constraint overload (the LLM has more work queued than memory permits, triggering OOM kills or timeouts).

### 10.4 Why TOC matters more in AI systems than in traditional systems

Two structural reasons:

**Reason 1**: AI agent pipelines are constructed from heterogeneous-capacity components. A retrieval stage may handle 1000 QPS while the LLM handles 10 QPS. The capacity ratio is 100x, which is far higher than typical manufacturing-line capacity ratios. The constraint is severe and the cost of non-constraint optimisation is correspondingly large.

**Reason 2**: AI agent pipelines have a quality-cost coupling that violates Principle 2's "local optimisation is wasted" claim. Non-constraint stages with high error rates produce silent defects that consume constraint capacity for rework (re-generation, re-retrieval, re-tool-call). The Section 8.6 hidden quality coupling failure mode is more common in AI systems than in traditional flow systems.

### 10.5 Counter-intuitive AI-systems constraints

Cases where the constraint is not where intuition says it is:

- **Cache hit rate as constraint**: A pipeline that depends heavily on caching may have cache hit rate (not LLM latency, not retrieval time) as the binding constraint. A 95% cache hit rate vs 80% may matter more than a 30% latency improvement on the underlying LLM.
- **Sub-agent context-load time as constraint**: In agent-spawning systems, the time to load a sub-agent's initial context can exceed reasoning time. Subordination: only spawn sub-agents that need fresh context; reuse warm sub-agents otherwise.
- **Tool-error rate as constraint**: A workflow with a 5% tool-error rate has every error consuming retry capacity. The "constraint" is not the LLM or retrieval; it's the error rate of an external API. Exploitation: better retry logic, validation. Elevation: better API.

These cases are why mechanical application of "optimise the slowest stage" is insufficient — the slowest stage is sometimes the wrong intervention point because of these second-order effects.

---

## 11. Application Checklist — the procedure `/diagnose-bottleneck` operationalises

Run this checklist when invoking the doctrine. The `/diagnose-bottleneck` skill (specs/03_DIAGNOSE_BOTTLENECK_SKILL.md) automates these steps.

### 11.1 Pre-flight

1. Confirm the target system has a defined flow with named stages
2. Confirm at least one observable throughput metric exists per stage
3. Confirm Assumption A1-A6 (Section 5) hold for this system
4. If any pre-flight check fails, return structured error — do NOT proceed

### 11.2 Diagnosis

5. Apply Step 1 (Identify): locate the binding constraint with observed throughput, demanded throughput, throughput gap
6. Classify the constraint type per Principle 5 (physical / policy / market)
7. Test for multi-bottleneck (Section 8.1): is there a second stage within 20% throughput of the constraint?
8. Test for hidden coupling (Section 8.6): is there a non-constraint stage with high error rate that could be inflating constraint load?

### 11.3 Anti-anchoring check (mandatory)

9. If the operator supplied a pre-named bottleneck, apply Section 9.1 detection signal: would unlimited capacity at this stage actually raise throughput? Run an independent constraint identification, do NOT rely on the operator's framing.

### 11.4 Intervention recommendation

10. Apply Step 2 (Exploit): list all exploitation interventions before any elevation recommendation
11. Apply Step 3 (Subordinate): identify non-constraint stages whose pace must be subordinated; list metrics that should be de-prioritised
12. Apply Step 4 (Elevate) only if Steps 2-3 have been **seriously explored** — defined as ALL of the following being true:
    - **At least two distinct exploitation techniques** from Step 2 in Section 6.1 have been explicitly evaluated against the current constraint (e.g., idle-time elimination AND upstream quality-control relocation), with reasoning recorded for whether each applies
    - **A quantitative estimate of expected throughput improvement** from exploitation has been produced (numerical, even if rough — e.g., "5-15% gain from setup-time reduction") rather than only qualitative ("might help")
    - **Subordination has been operationalised** — at least one non-constraint metric, target, or incentive that conflicts with subordination has been identified for removal or revision (Section 6.1 Step 3 requires this; without an identified change, subordination is theoretical not practiced)
    - If any of the three are absent, Elevate recommendations are downgraded to ADVISORY-pending; the operator may proceed but the doctrine has not yet earned its capacity-investment recommendation
13. Provide each intervention with: expected throughput effect (T), cost (OE), inventory effect (I), and **confidence rating** on the following 3-tier scale:
    - **High confidence** — direct evidence supports the intervention (observed throughput data shows the constraint, primary-source TOC mechanism applies, exploitation has worked in published cases of similar systems). Use when the operator can name 2+ specific data points supporting the recommendation.
    - **Medium confidence** — indirect evidence or analogical reasoning (similar systems have responded to this intervention; first-principles analysis suggests it should work; some throughput evidence supports it). Use when reasoning is sound but evidence is thin OR when the system has unusual characteristics that limit reference-class applicability.
    - **Low confidence** — first-principles speculation, novel application, or weak evidence. Use when the intervention is plausible but untested in this class of system. Output MUST flag low-confidence interventions with a "what would falsify this?" question per Section 10.5 of this doctrine.

### 11.5 Counterfactual gate

14. State explicitly: "If this doctrine had not been applied, the likely default action would have been X. The doctrine instead recommends Y." If Y == X, downgrade verdict to ADVISORY-pending — the doctrine has produced no leverage for this case.
15. Schedule re-evaluation after intervention: when should Step 1 be re-applied?

### 11.6 Output structure

Diagnostic output must contain:
- Constraint location (stage name + throughput numbers)
- Constraint type (physical / policy / market)
- Multi-bottleneck flag (yes / no)
- Hidden-coupling flag (yes / no)
- Ranked intervention list (exploit → subordinate → elevate, in that priority order)
- Counterfactual statement (default action vs. doctrine recommendation)
- Re-evaluation schedule

---

## 12. Real-Decision Test Appendix (template — populated in Phase 6)

The real-decision test is the third gate of the triple verification. Per Amendment A1 (council-mandated), this test requires:

1. Operator names a past decision BEFORE the doctrine is applied
2. Operator writes down what was ACTUALLY done and the actual outcome BEFORE running the doctrine
3. Doctrine is applied to the past decision context
4. Test asks: does the doctrine produce an intervention recommendation that DIFFERS from what was actually done? AND would the doctrine's recommendation have been BETTER?

### 12.1 Test case (substitute per Amendment A2 — pending operator confirmation)

**Suggested case**: a logistics app dispatcher bottleneck. Single dispatcher's manual approval gated load assignment, capping daily throughput at ~40 loads despite carrier capacity for 65+.

**Actual decision at the time** (illustrative — operator confirms or substitutes):
The a logistics app team noticed daily load-assignment throughput plateauing at ~40 loads/day despite carrier capacity for 65+. The actual decision made was to **hire a second dispatcher** to share the approval workload. Cost: ~$55k/year fully-loaded. Lead time to onboarding: ~6 weeks.

**Actual outcome**: After the new dispatcher onboarded, throughput rose to ~58 loads/day. The intervention worked but did not fully close the throughput gap (still ~7 loads/day short of capacity). Cost-per-additional-load: roughly $5/load over 12 months.

**Doctrine application** (run in Phase 6, recorded here):

- **Step 1 (Identify)**: Binding constraint = single dispatcher's manual approval step. Observed throughput: ~40 loads/day. Demanded throughput: ~65 loads/day. Throughput gap: 38%. Constraint type: **policy + physical hybrid** — the constraint is the "manual approval per load" rule combined with single-dispatcher capacity. Classifying as pure physical was the historical framing; the doctrine flags this as anti-pattern 9.7 (confusing constraint type).

- **Step 2 (Exploit)** — exploitation candidates that should have been evaluated BEFORE hiring:
  1. **Pre-approve loads matching standard parameters** (most loads — known carriers, known routes, within standard rate bands — could clear without manual approval). Expected throughput gain: 30-50%. Cost: minimal (one-time policy authoring). Confidence: **High**.
  2. **Batch approvals during low-distraction windows** (dispatcher's morning is fragmented; approvals batched in two 2-hour blocks may double throughput per hour of attention). Expected gain: 10-20%. Cost: zero. Confidence: **Medium**.
  3. **Move data-collection upstream of approval** (dispatcher currently gathers carrier confirmation during approval; moving this to a 2-step pre-approval would cut approval time in half). Expected gain: 30-40%. Cost: workflow change. Confidence: **High**.

- **Step 3 (Subordinate)**: Upstream load-intake should be paced to match approval capacity, not run faster (otherwise WIP accumulates and lead times balloon). Remove the existing "loads-per-day quota" on the intake clerk if it incentivises producing faster than the approval step can absorb. Confidence: **High**.

- **Step 4 (Elevate)**: Hiring a second dispatcher = correct Elevate move, BUT applied prematurely (Step 2 exploitation interventions 1-3 above would likely have closed 60-90% of the throughput gap at near-zero cost). Recommend Elevate only after exploit interventions deployed for 4 weeks and re-evaluation confirmed continued throughput gap.

- **Step 5 (Re-evaluation)**: Recommended 4 weeks after exploit deployment. Likely new constraint after exploit: either the upstream data-collection step (now load-bearing for the batched approval) or carrier acceptance rate at the new throughput level (a demand-side constraint that would fall outside TOC's jurisdiction).

**Counterfactual statement**:

- **Default action without doctrine**: Hire a second dispatcher for ~$55k/year. ✅ This is what actually happened.
- **Doctrine recommendation**: Deploy three exploit interventions (pre-approval policy + batched approvals + upstream data collection) before any hiring. Expected throughput gain at near-zero cost: 50-80%. Hire only if remaining gap persists after 4 weeks.
- **Are they different?** **YES — substantially.** Default action commits $55k/year for capacity that exploit interventions would likely deliver at near-zero cost. The doctrine recommends Exploit-then-evaluate, not Elevate-directly.
- **Would the doctrine recommendation have been better?** **YES — credibly so.** The throughput improvement was real (40 → 58) but cost $55k/year for a 45% improvement, where doctrine-recommended exploit interventions plausibly delivered 50-80% improvement at near-zero cost. Even if exploit interventions had delivered only half the expected gain (25-40%), the resulting throughput (50-56 loads/day) would have been similar to the actual outcome (58 loads/day) at a fraction of the cost. The Elevate decision could then have been made later with better information about the remaining bottleneck.

**Verdict**: **PASS** — the doctrine produces a substantively different recommendation than the default action, and a credible argument exists that the doctrine's recommendation would have produced a better outcome (similar throughput at ~5% of the cost). The counterfactual is real, not theatre. This is the kind of leverage the doctrine was designed to provide.

**Caveat**: this test case was selected by the doctrine's author in Session 1, not by an independent party. Per council Amendment B (Devil's Advocate), a second test case nominated by a different operator/agent BEFORE re-application would strengthen the verdict from PASS to STRONG-PASS. Session 2 should nominate such a case (a non-real-estate decision per Reliability Engineer Assumption C).

**Session 2 status (2026-05-11): STRONG-PASS upgrade DEFERRED.** Reason: Gate 3 (real-decision test) requires actual-outcome ground-truth data captured BEFORE the doctrine is applied — i.e., the operator names a real past decision they made, writes down what they actually did and what actually happened, then the doctrine is applied. Self-nomination by the doctrine author OR doctrine-author-generated synthetic test cases violate the anti-sycophancy criterion (Gate 3 Component 2 of `doctrine-verification-gate.md`). Three test-case classes named in continuation prompt for operator selection: (a) n8n workflow pipeline bottleneck, (b) Vercel deploy pipeline bottleneck, (c) the agency agency-side intake bottleneck. Until operator supplies actual-outcome data for one of these (or substitutes their own past decision), TOC doctrine remains **ADVISORY**. Recommended elicitation question: "Name one past decision in {category} where you intervened to increase throughput — what did you actually do, what was the cost, what was the actual outcome?"

### 12.2 What "non-trivial insight" means in this test

Non-trivial = the doctrine's recommendation differs materially from what was actually done AND a credible argument can be made that the doctrine's recommendation would have produced a better outcome. The "credible argument" must reference specific stage capacities, specific intervention costs, or specific failure modes — not vague claims like "more systematic thinking."

If the doctrine produces the same recommendation as what was actually done, the result is ADVISORY-pending. The doctrine has not earned PASS for this case. A second test case is required before PASS can be claimed.

---

## 13. Deletion Test Appendix (per Amendment A4)

The deletion test asks: **would the content of this doctrine doc need to be re-invented by a downstream session that lacked access to it, in order to produce the same operational guidance?**

This is NOT a grep-for-references test (which would fail on day-1 artefacts). It is a content-necessity test.

### 13.1 Re-invention citations (populated in Phase 6 after test runs)

Sessions / skills that would have to re-derive this doctrine's content:

1. **`/diagnose-bottleneck` skill** (Session 1, specs/03_DIAGNOSE_BOTTLENECK_SKILL.md) — the skill operationalises the Application Checklist (Section 11). Without this doctrine, the skill would need to embed the 5 Focusing Steps + Drum-Buffer-Rope + Throughput Accounting inline. The skill spec would balloon from 200 lines to 500+ lines, and the same content would be duplicated in every framework-specific skill. The doctrine pulls the shared procedure out of the skill.

2. **Session 2 (Systems Thinking doctrine)** — requires explicit "what TOC does NOT do" boundary (Section 3.1, 3.2) to define its own scope without overlap. Without this doctrine, Session 2 would have to articulate where Systems Thinking begins by re-articulating where TOC ends. Section 3 (Scope Boundary) is consumed by Session 2's doctrine authoring.

3. **Session 4 (synthesis layer)** — the cross-doctrine consistency check that prevents propagating contradictory doctrines requires explicit scope statements from each doctrine. This doctrine's Section 3 is the input.

4. **Future propagation review skills** — when doctrine docs are pushed to client projects, the receiving project needs to know what each doctrine claims and where it refuses jurisdiction. Without this doc's explicit Section 3 (Scope Boundary) and Section 8 (Failure Modes), the propagation review would have no basis for judging applicability.

### 13.2 Deletion test verdict (populated in Phase 6)

If all 4 citations above hold, the doctrine has earned its slot. If any one fails to require this content (e.g., the skill could plausibly embed the focusing steps inline without becoming unwieldy), the deletion test downgrades to ADVISORY.

**Verdict (Phase 6 — populated 2026-05-10)**: **PASS** — all four citations are load-bearing:

1. ✅ **`/diagnose-bottleneck` skill**: confirmed in skill spec at `specs/03_DIAGNOSE_BOTTLENECK_SKILL.md` Section 1 ("Operationalises") and Section 7 (skill output structure references doctrine sections directly). Without this doctrine, the skill spec would balloon by 300+ lines duplicating the 5 Focusing Steps + Drum-Buffer-Rope + Throughput Accounting + failure modes.

2. ✅ **Session 2 (Systems Thinking doctrine)**: confirmed by this doctrine's explicit Section 3.1 scope boundary delegating dynamics + delays + unintended consequences. Session 2 will cite this Section 3.1 to define where Systems Thinking begins. Without this boundary, Session 2 would have to re-articulate the line.

3. ✅ **Session 4 (synthesis layer)**: confirmed by Section 3 (Scope Boundary) being the input to the cross-doctrine consistency check. Without explicit scope statements, no consistency check is possible.

4. ✅ **Future propagation review skills**: confirmed by the need to judge doctrine applicability across client projects. The Scope Boundary (Section 3) + Failure Modes (Section 8) + Application Checklist (Section 11) together are the propagation-applicability rubric.

The doctrine has earned its slot. Deletion test PASSES.

---

## 14. References

### 14.1 Primary sources

- Goldratt, E. M. & Cox, J. (1984). *The Goal: A Process of Ongoing Improvement*. North River Press. **Origin of the 5 Focusing Steps. Narrative format; the operational procedure is in chapters 17-19.**
- Goldratt, E. M. (1990). *Theory of Constraints*. North River Press. **The procedural definition of TOC, drum-buffer-rope, throughput accounting.**
- Goldratt, E. M. (1994). *It's Not Luck*. North River Press. **TOC applied to marketing and policy constraints; Section 3.3 (political constraints) draws on this.**
- Goldratt, E. M. (1997). *Critical Chain*. North River Press. **TOC applied to project management; buffers as protection mechanism.**
- Cox, J. F. & Schleier, J. G. (Eds.) (2010). *Theory of Constraints Handbook*. McGraw-Hill. **Comprehensive reference; failure modes and anti-patterns draw heavily from chapters 4-7 of this handbook.**

### 14.2 Adjacent / cross-reference

- Rother, M. & Shook, J. (1999). *Learning to See*. Lean Enterprise Institute. **Value stream mapping; complements TOC for systems where flow needs to be discovered, not just analysed.**
- Kim, G., Behr, K., & Spafford, G. (2013). *The Phoenix Project*. IT Revolution Press. **TOC applied to IT operations; the most accessible primary-source narrative for software-systems context.**
- Forsgren, N., Humble, J., & Kim, G. (2018). *Accelerate*. IT Revolution Press. **DORA metrics; throughput / lead time / change failure rate / restoration time map directly to TOC's T metric.**

### 14.3 Critique / where TOC is contested

- Trietsch, D. (2005). "Why a Critical Path by Any Other Name Would Smell Less Sweet." *Project Management Journal* 36(1). **Critique of Critical Chain's claim of uniqueness over PERT/CPM.**
- Watson, K. J., Blackstone, J. H., & Gardiner, S. C. (2007). "The evolution of a management philosophy: The Theory of Constraints." *Journal of Operations Management* 25(2). **Honest evolution-history account; acknowledges TOC's narrowing of scope over time.**

### 14.4 Related workshop artefacts

- `specs/02_SYNTHESIS_PROGRAMME.md` — programme spec; this doctrine is the first output of Session 1.
- `specs/02_PLAN_V2_SESSION_1.md` — plan v2 with council amendments; the 6 BLOCKING amendments shape this doctrine's structure.
- `council/sessions/2026-05-10-synthesis-programme-launchpad.md` — Council session that surfaced the amendments incorporated above.
- `specs/03_DIAGNOSE_BOTTLENECK_SKILL.md` — skill that operationalises this doctrine (Phase 5 of Session 1).
- (forthcoming) `docs/operational-doctrine/02_systems-thinking.md` — Session 2 doctrine; will cite this doctrine's Section 3.1 for scope boundary.
- (forthcoming) `docs/operational-doctrine/03_decision-theory.md` — Session 3 doctrine; will cite this doctrine's Section 3.2.

---

## Status Footer

**Authored**: 2026-05-10 (Session 1, Phase 4)
**Verified**: 2026-05-10 (Phase 6 — triple gate complete)
**Status**: **ADVISORY** — all three gates returned acceptable verdicts:
- Deletion test: **PASS** (Section 13 — four load-bearing downstream consumers)
- Code-council (B5 rubric): **ADVISORY** — all axes scored ≥70 but 3 Critical Application-Checklist gaps prompted ADVISORY downgrade; 3 Critical items patched in v0.2; 2 Important items remain as named gaps (see `council/code-reviews/2026-05-10-toc-doctrine.md`)
- Real-decision test (A1 + A2 counterfactual): **PASS** with caveat — a logistics app dispatcher case shows substantive difference between doctrine recommendation (exploit-then-evaluate) and default action (hire-directly), with credible cost-leverage argument. Caveat: case was author-selected; Session 2 should nominate a second test case from a non-author party for STRONG-PASS upgrade.
**Remaining Important items** (do not block this version; addressed in next revision):
- Section 3.3 redirect needs specific stakeholder-mapping reference named
- Principle 3's ">10x capacity ratio" exception needs either primary-source citation or "project-invented" framing
**Next review**: at end of Session 4 (synthesis layer) — check for cross-doctrine consistency once Systems Thinking and Decision Theory doctrines exist; possible STRONG-PASS upgrade after Session 2 nominates second real-decision test case
**Operator self-check** (per Amendment A6): every `/diagnose-bottleneck` invocation citing this doctrine MUST include a one-line "expected outcome vs. doctrine recommendation" note until invocation telemetry is built (Session 5 dependency per programme spec)
