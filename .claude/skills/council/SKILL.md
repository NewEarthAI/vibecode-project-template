---
name: council
description: |
  Multi-perspective deliberation engine that gathers 3-6 council agents to evaluate proposals
  from opposing philosophical lenses. Default mode uses 5 agents (Optimist Strategist,
  Devil's Advocate, Neutral Analyst, Capability Scout, Reliability Engineer). Extended mode adds 3 more (Pragmatist, Edge Case Finder,
  The Reframer) for deeper analysis on high-stakes decisions. The Reframer runs FIRST (Phase 0)
  with expanded business context to validate the proposal's framing before the council deliberates.
  Supports 3 modes: standard (parallel evaluation), debate (agents challenge each other),
  premortem (assume failure, work backward). Supports --extended flag for 6-agent deliberation.
  Use when: "council", "gather agents", "deliberate", "get multiple perspectives",
  "stress test this idea", "should we do X", or before major strategic decisions about
  ventures, architecture, or resource allocation.
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash, AskUserQuestion
user-invocable: true
version: 4.0
classification: capability-uplift
created: 2026-03-06
updated: 2026-03-17
parameters:
  - name: proposal
    type: string
    description: The idea, plan, or decision to evaluate
  - name: mode
    type: enum
    values: [standard, debate, premortem]
    default: standard
    description: Deliberation mode
  - name: extended
    type: boolean
    default: false
    description: Use 6-agent extended council (adds Pragmatist + Edge Case Finder + Reframer with Phase 0)
  - name: save
    type: boolean
    default: true
    description: Whether to persist session to council/sessions/
validated_on:
  - different_proposal_domain
  - different_project_without_council_history
  - premortem_on_unfamiliar_venture
---

# AI Council — Multi-Perspective Deliberation Engine

> **Philosophy:** Better decisions come from structured disagreement, not false consensus. Three to six lenses, one synthesis. In extended mode, the Reframer validates the frame before the council begins.

---

## When to Use This vs. Other Tools

| Need | Use |
|------|-----|
| Test one specific belief against evidence | `/challenge` |
| Research a topic from multiple sources | `/agentresearch` |
| Evaluate a proposal from multiple perspectives | **`/council`** |
| Build something with parallel agents | `/build-with-agent-team` |

---

## Modes

### Mode Detection

Parse `$ARGUMENTS` to detect mode and flags:
- Starts with `debate` → **Debate Mode**
- Starts with `premortem` → **Pre-Mortem Mode**
- Contains `--no-save` → Skip session persistence
- Contains `--extended` or `extended` → **Extended Council** (8 agents, Phase 0 Reframer first)
- Everything else → **Standard Mode** (5 agents)

Extract the proposal/topic from the remaining argument text after mode keyword and flags.

**Extended mode** can combine with any deliberation mode: `/council --extended "proposal"`, `/council debate --extended "topic"`, `/council premortem --extended "project"`.

---

## Mode 1: Standard Invocation (Default)

**Trigger**: `/council "Should we build X before Y?"` or `/council "Evaluate this proposal: ..."`

### Step 1 — Parse Input

Extract from `$ARGUMENTS`:
- **Proposal**: The idea, plan, or decision to evaluate
- **Context**: Any background, constraints, or goals mentioned
- **Questions**: Specific angles the user wants explored

If no argument provided, AUTO-DETECT — the user's most recent message/context above the `/council` invocation IS the proposal. Look at:
1. The message immediately preceding `/council` — this is almost always the subject
2. An active plan file (from plan mode) if present
3. ONLY if genuinely nothing is discernible, ask: "What should the council evaluate?"

Never ask when the answer is obvious from conversation context. If a council quality mandate memory exists in the project, it is automatically applied — the user is implicitly asking "verify this is the best possible approach."

**Auto-suggest extended mode**: If `--extended` was NOT specified but the proposal involves any of the following, suggest it before proceeding:
- Implementation work that will be built immediately after deliberation
- Budget commitments above $500 or engineering time above 2 weeks
- Architecture decisions affecting multiple systems or repos
- Irreversible platform changes (new database schemas, deployed services)

Suggestion format:
> "This proposal involves [implementation/budget/architecture]. Consider running with `--extended` to add Pragmatist, Edge Case Finder, and Reframer perspectives. Proceed with standard 3-agent council, or re-invoke with `--extended`?"

### Step 2 — Gather the Council (Parallel)

Launch all 5 council agents simultaneously using the Agent tool. Each agent receives the same proposal but evaluates from their unique lens.

**CRITICAL**: Launch all 5 in a SINGLE message with multiple Agent tool calls to maximize parallelism.

**Prompt template for each agent:**

```
COUNCIL DELIBERATION
━━━━━━━━━━━━━━━━━━━━

Proposal: {{proposal}}

Context: {{context}}

Questions to address: {{questions}}

QUALITY MANDATE (apply to your analysis):
STEP 0 — DEFINE SUCCESS in outcome-only terms before evaluating anything. What does the primary stakeholder observe? What does the system guarantee? What metrics move? What failures are eliminated? CONSTRAINT: If you can infer the technical approach from your success definition, it is invalid — restate in outcome-only language. Also: what does the stakeholder see when this FAILS? Wrong-but-plausible data on failure = CRITICAL risk.
STEP 1 — REVERSE-ENGINEER THE PATH from that perfect outcome using first principles. What must be true? What conditions, in order? Simplest path from here to there?
STEP 2 — EVALUATE THE PLAN against that path. Most reliable, practically valuable, bulletproof approach? If a better way exists — say so and propose it.
ROBUST SIMPLICITY: Start simple. Add complexity ONLY to close real gaps toward defined success. Every complexity earns its place.
STAKEHOLDER CHECK: Easier or harder for the primary stakeholder? What do they see when it fails? Wrong-but-plausible failure data = CRITICAL.

OUTPUT CONSTRAINT: End with exactly 1 CONCLUSION sentence and 1 CRITICAL QUESTION for the decision-maker. This is mandatory.

Provide your analysis following your standard output structure.
Include confidence levels (0-100%) for your key claims.
Note where you expect to agree or disagree with the other council members.
```

**Agent configurations (Standard — 5 agents):**

| Agent | subagent_type | Color | model |
|-------|---------------|-------|-------|
| Optimist Strategist | `council/optimist-strategist` | Green | sonnet |
| Devil's Advocate | `council/devils-advocate` | Red | sonnet |
| Neutral Analyst | `council/neutral-analyst` | Blue | sonnet |
| Capability Scout | `council/capability-scout` | Gray | sonnet |
| Reliability Engineer | `council/reliability-engineer` | Yellow | sonnet |

**Agent configurations (Extended — 8 agents, when `--extended` flag is set):**

See **Phase 0 — Reframer** section below. In extended mode, the Reframer runs FIRST, then the remaining 7 agents run in parallel.

| Agent | subagent_type | Color | model | Phase |
|-------|---------------|-------|-------|-------|
| The Reframer | `council/reframer` | Teal | sonnet | **Phase 0 (solo, first)** |
| Optimist Strategist | `council/optimist-strategist` | Green | sonnet | Phase 1 (parallel) |
| Devil's Advocate | `council/devils-advocate` | Red | sonnet | Phase 1 (parallel) |
| Neutral Analyst | `council/neutral-analyst` | Blue | sonnet | Phase 1 (parallel) |
| Capability Scout | `council/capability-scout` | Gray | sonnet | Phase 1 (parallel) |
| Reliability Engineer | `council/reliability-engineer` | Yellow | sonnet | Phase 1 (parallel) |
| Pragmatist | `council/pragmatist` | Orange | sonnet | Phase 1 (parallel) |
| Edge Case Finder | `council/edge-case-finder` | Purple | sonnet | Phase 1 (parallel) |

---

## Phase 0 — Reframer (Extended Mode Only)

**When**: Always runs FIRST in extended mode, BEFORE any other council agents.

**Why**: The Reframer's value is highest before deliberation, not after. If the proposal is asking the wrong question, 5 agents analyzing it in depth wastes effort and creates momentum toward the wrong framing.

### Step 0.1 — Load Context Bundle

Before invoking the Reframer agent, the orchestrator (main Claude) gathers expanded context:

1. **Detect entity context**: From the proposal text or current working directory, identify which entity/client/venture is relevant.
2. **Load PROFILE.yaml**: Read the relevant entity's `PROFILE.yaml` (check `clients/{slug}/PROFILE.yaml` or root `PROFILE.yaml`).
3. **Load ROADMAP.md**: Read `ROADMAP.md` from the repo root for strategic direction.
4. **Load client CLAUDE.md** (if applicable): Read `clients/{slug}/CLAUDE.md` for project-specific context.
5. **Scan recent council sessions**: Glob `council/sessions/*.md`, read the 2-3 most recent to avoid re-litigating settled decisions.

**CRITICAL**: This context loading happens in the MAIN orchestrator, not inside the Reframer agent. The orchestrator reads these files and includes the relevant excerpts in the Reframer's prompt.

### Step 0.1.5 — Reframer-Agent-Missing Fallback (added 2026-05-03)

If the `council/reframer` `subagent_type` is not registered in the active agent
registry (verifiable by the Agent tool returning "Agent type not found"), the
orchestrator (main Claude) MUST perform Phase 0 INLINE rather than aborting or
proceeding to Phase 1 with a missing frame check.

**Inline Phase 0 protocol**:
1. Apply the same Step 0.1 context bundle the agent would have received.
2. Apply the full Reframer analytical framework to the proposal: upstream
   audit, success metric validation, scope diagnosis, reversibility
   classification, Rumelt strategy lens (Diagnosis / Guiding Policies /
   Actions / Standard Kit Test), recent-precedent check.
3. Produce a verdict: PROCEED AS STATED / REFRAME SUGGESTED / SKIP-PHASE-1
   PRECEDENT (when doctrine is already locked and direct execution beats
   ceremony — e.g., 2026-04-17 sp1-polish-reframer-skip session).
4. Cite the orchestrator-substitution explicitly in the synthesis: "Phase 0
   performed inline by orchestrator — Reframer subagent_type unavailable in
   this environment."
5. Continue to Step 0.3 (evaluate verdict) as if the Reframer agent had
   returned the same content.

**Why this is acceptable**: the Reframer's value is the framework itself, not
the agent boundary. The orchestrator has identical access to PROFILE.yaml,
ROADMAP.md, recent council sessions, and project memory. On doctrine-extending
proposals, the inline path is faster, cheaper, and produces verdicts
indistinguishable from a registered Reframer.

**Failure precedents proving this works**:
- 2026-04-17 sp1-polish-reframer-skip — Reframer recommended SKIP Phase 1; PR #107 shipped same session.
- 2026-05-03 grade-tooltip — Reframer agent NOT registered; orchestrator-substituted Phase 0 produced skip-phase-1 verdict; PR #418 shipped + merged same session, zero rework.

**When NOT to substitute**: if the proposal is genuinely novel (no doctrine
precedent, brand-new strategic territory), the orchestrator should escalate
to the user with: "Reframer agent unavailable AND this proposal lacks
precedent — recommend pausing for human framing review or invoking standard
5-agent council without Phase 0."

### Step 0.2 — Invoke Reframer

Launch a SINGLE Reframer agent with this prompt:

```
PHASE 0 — FRAME VALIDATION
━━━━━━━━━━━━━━━━━━━━━━━━━━

You are running BEFORE the council convenes. Your job: validate whether this proposal is asking the right question.

PROPOSAL: {{proposal}}

CONTEXT: {{context}}

STRATEGIC CONTEXT (from PROFILE.yaml + ROADMAP.md):
{{profile_yaml_excerpt — roadmap, pain_points, active_sprint, relationships}}

ROADMAP PRIORITIES:
{{roadmap_excerpt — current focus areas, NSM, active milestones}}

PROJECT CONTEXT (from client CLAUDE.md):
{{client_claude_excerpt — if applicable, otherwise "N/A — agency-level proposal"}}

RECENT COUNCIL DECISIONS:
{{recent_sessions_summary — topic + verdict from last 2-3 sessions, or "No recent sessions"}}

Apply your full analytical framework (upstream audit, success metric validation, scope diagnosis, reversibility classification, entity context check, strategic alignment).

Additionally, apply the Rumelt Strategy Lens to the proposal:
- **Diagnosis**: Does the proposal clearly identify the core challenge it's solving? Or is it jumping to a solution without naming the problem?
- **Guiding Policies**: Are there decision principles that would constrain future choices? Or will every downstream decision require a new debate?
- **Actions**: Does the proposal specify concrete next steps, or is it all diagnosis with no action?
- **Standard Kit Test**: Is this proposal introducing new tools/technologies when existing infrastructure would suffice? Boring strategies that use the standard kit often outperform novel approaches that add complexity.

If the proposal fails the Rumelt lens (no clear diagnosis, no guiding policies, or unnecessary tool proliferation), flag this alongside your frame assessment.

If you determine the frame is valid: say so and the council will proceed on the original proposal.
If you determine a reframe is warranted: propose the alternative framing with clear reasoning. The decision-maker will be asked to approve before the council proceeds.
```

### Step 0.3 — Evaluate Reframer Output

Parse the Reframer's response:

**If "PROCEED AS STATED":**
- Continue to Phase 1 (launch 7 remaining agents in parallel on the original proposal)
- Include a brief note in each agent's prompt: "Frame validated by Reframer — proceeding as stated."

**If "REFRAME SUGGESTED":**
- **PAUSE** — Present the reframe to the user using AskUserQuestion:

```
REFRAMER INTERVENTION
━━━━━━━━━━━━━━━━━━━━

The Reframer suggests this proposal may be asking the wrong question.

Original: "{{original_proposal}}"
Suggested reframe: "{{reframed_proposal}}"

Reasoning: {{reframer_reasoning}}

Options:
(A) Accept reframe — council deliberates on the new framing
(B) Reject reframe — council deliberates on the original proposal
(C) Modify — provide your own adjusted framing
```

- If user picks **(A)**: Launch 5 agents with the reframed proposal. Note original framing for transparency.
- If user picks **(B)**: Launch 5 agents with the original proposal. Note the Reframer's concern in the synthesis.
- If user picks **(C)**: Launch 5 agents with the user's modified framing.

### Step 0.4 — Proceed to Phase 1

After Reframer resolution, launch ALL 7 remaining agents in a SINGLE message (parallel).

Each agent receives the (potentially reframed) proposal plus:
```
FRAME STATUS: {{Validated as stated | Reframed from "X" to "Y" (user-approved) | Original retained despite reframe suggestion}}
```

---

### Step 3 — Synthesize

After all agents return, the main Claude instance produces the synthesis.

**Standard (5-agent) synthesis:**

```
COUNCIL SYNTHESIS
━━━━━━━━━━━━━━━━━

Proposal: "{{proposal}}"
Date: {{YYYY-MM-DD}}
Mode: Standard

━━━ CONSENSUS (All 5 agree) ━━━
- {{point where all 5 agents agree}}
- ...

━━━ DIVERGENCE (Key disagreements) ━━━
- {{topic}}: Optimist says {{X}}, Skeptic says {{Y}}, Analyst says {{Z}}
- ...

━━━ STACK REALITY (Capability Scout) ━━━
- Inventory matches: {{existing skills/MCPs/commands that cover part of the proposal}}
- Reuse-before-build: {{extend existing thing, or confirm genuine new-build}}
- Estimate translation: {{stack-adjusted effort vs generic estimate}}

━━━ OPERATE-COST AUDIT (Reliability Engineer) ━━━
- Failure visibility: {{loud/medium/quiet per new surface}}
- MTTR: {{minutes/hours/days per surface}}
- Non-shippable flags: {{any monitoring gaps that must be filled before go-live}}

━━━ CONFIDENCE SPREAD ━━━
| Claim | Optimist | Skeptic | Analyst | Cap. Scout | Rel. Eng. | Spread |
|-------|----------|---------|---------|------------|-----------|--------|
| {{claim}} | {{%}} | {{%}} | {{%}} | {{%}} | {{%}} | {{spread}} |

Spread interpretation:
- >30% = High uncertainty, investigate further
- 15-30% = Moderate disagreement, weigh carefully
- <15% = Near consensus, higher confidence

━━━ RECOMMENDATION ━━━
{{Integrated recommendation drawing from all 5 perspectives}}

━━━ NEXT STEPS ━━━
- {{actionable next step}}
- ...

━━━ 72-HOUR ACTION BRIEF ━━━
1. First action: {{specific task}} | Owner: {{who}} | By: {{date}}
2. Decision needed: {{what must be decided before proceeding}}
3. Success signal: {{how to know it's working}}
```

**Extended (8-agent) synthesis** — adds four additional sections:

```
━━━ FRAME CHECK (Reframer — Phase 0) ━━━
- Frame: {{proceed as stated | reframed from X to Y | reframe rejected}}
- Upstream assumptions: {{presupposed decisions not examined}}
- Strategic alignment: {{how this serves or deviates from ROADMAP priorities}}

━━━ EXECUTION REALITY (Pragmatist) ━━━
- Feasibility: {{honest assessment of what can be built with current resources}}
- Minimum viable path: {{simplest version that delivers core value}}
- Maintenance cost: {{ongoing operational burden}}

━━━ CRITICAL EDGE CASES (Edge Case Finder) ━━━
- {{specific scenario}} → {{consequence}} → {{defense}}
- ...

━━━ CONFIDENCE SPREAD ━━━
| Claim | Optimist | Skeptic | Analyst | Cap. Scout | Rel. Eng. | Pragmatist | Edge Cases | Reframer | Spread |
|-------|----------|---------|---------|------------|-----------|------------|------------|----------|--------|
| {{claim}} | {{%}} | {{%}} | {{%}} | {{%}} | {{%}} | {{%}} | {{%}} | {{%}} | {{spread}} |
```

The extended spread includes 8 columns. A wider spread across 8 agents indicates even higher uncertainty. Consensus across all 8 is a very strong signal.

### Step 4 — Persist Session

**Default behavior**: Write the full session to `council/sessions/YYYY-MM-DD-{{slug}}.md` where `{{slug}}` is a 3-5 word kebab-case summary of the proposal topic.

**Session file structure:**
```markdown
# Council Session: {{topic}}
**Date**: {{YYYY-MM-DD}}
**Mode**: Standard | Extended
**Agents**: 5 | 8
**Proposal**: {{full proposal text}}
**Frame Status**: {{Validated | Reframed | Reframe rejected}} (Extended only)

---

## Phase 0 — Reframer (Extended only)
{{full reframer report — omit this section in standard mode}}
{{user's frame decision if reframe was suggested}}

## Optimist Strategist
{{full optimist report}}

## Devil's Advocate
{{full devils advocate report}}

## Neutral Analyst
{{full neutral analyst report}}

## Capability Scout
{{full capability scout report — inventory matches, estimate translation, anchor-bias flags}}

## Reliability Engineer
{{full reliability engineer report — failure visibility, MTTR, non-shippable flags}}

## Pragmatist (Extended only)
{{full pragmatist report — omit this section in standard mode}}

## Edge Case Finder (Extended only)
{{full edge case finder report — omit this section in standard mode}}

## Synthesis
{{synthesis output from Step 3}}
```

If `--no-save` was in arguments, skip this step.

---

## Mode 2: Debate

**Trigger**: `/council debate "topic"` or `/council debate "contested claim"`

### Step 1 — Check for Prior Session

Search `council/sessions/` for a recent session on this topic. If found, use it as context. If not, run Standard Mode first to generate initial positions.

### Step 2 — Launch Confrontation (Parallel)

Re-launch all 5 agents with each other's positions included:

```
COUNCIL DEBATE
━━━━━━━━━━━━━━

Topic: {{topic}}

The council has delivered initial reports. Now engage in direct confrontation.

OPTIMIST'S POSITION: {{summary of optimist report}}
SKEPTIC'S POSITION: {{summary of skeptic report}}
ANALYST'S POSITION: {{summary of analyst report}}

YOUR TASK:
1. Identify the strongest claims from opposing agents
2. Challenge specific assertions — name the agent and claim you're disputing
3. Expose logical gaps in other agents' reasoning
4. Defend your position against likely criticisms
5. Acknowledge valid points from other agents
6. End with a REVISED confidence level for your key claims

Use format: "To [Agent] on '[specific claim]': [Your challenge]"
```

### Step 3 — Adjudicate

The Neutral Analyst's debate output serves as the adjudication. Main Claude adds:
- Which positions survived scrutiny
- Which were weakened
- What the debate revealed that wasn't visible in the initial analysis
- Updated recommendation

### Step 4 — Persist

Append debate results to the existing session file, or create a new one with `-debate` suffix.

---

## Mode 3: Pre-Mortem

**Trigger**: `/council premortem "project name"` or `/council premortem "decision"`

### Step 1 — Frame the Failure

```
PRE-MORTEM ANALYSIS
━━━━━━━━━━━━━━━━━━━

The Scenario: It's 18 months from now. {{project}} has failed completely.

YOUR TASK: Write a post-mortem explaining WHY it failed from your perspective.

- Optimist: What success conditions didn't materialize? What did we overestimate?
- Skeptic: Which risks materialized? What warnings did we ignore?
- Analyst: What trade-offs did we get wrong? What evidence did we misinterpret?

Be specific. Name concrete failure modes, not vague concerns.
End with: How likely is this failure scenario (0-100%)? What single action would most prevent it?
```

### Step 2 — Synthesize Failure Modes

Main Claude collects all 3 failure narratives and produces:

```
PRE-MORTEM SYNTHESIS
━━━━━━━━━━━━━━━━━━━━

Project: {{project}}
Date: {{YYYY-MM-DD}}

━━━ FAILURE MODES (by likelihood) ━━━
1. {{highest likelihood failure}} — {{%}} likely
   Raised by: {{agent(s)}}
   Prevention: {{specific action}}

2. ...

━━━ EARLY WARNING SIGNS ━━━
- {{signal to watch for}} → indicates {{failure mode}}
- ...

━━━ PREVENTION PRIORITIES ━━━
1. {{most impactful prevention action}}
2. ...

━━━ VERDICT ━━━
Overall failure risk: {{low/moderate/high}}
Most dangerous blind spot: {{the thing most likely to be ignored}}
```

### Step 3 — Persist

Write to `council/sessions/YYYY-MM-DD-premortem-{{slug}}.md`.

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No arguments provided | Ask for proposal via conversation |
| Agent fails to return | Report which agent failed, synthesize from remaining agents, note reduced confidence |
| Session directory missing | Create `council/sessions/` automatically |
| Prior session not found (debate mode) | Run standard mode first, then debate |
| Reframer fails (extended mode) | Log the failure, proceed with 5 agents on original proposal, note in synthesis |
| Reframer agent NOT registered (subagent_type lookup fails) | Orchestrator (main Claude) performs Phase 0 inline using the same prompt template + context bundle. Cite the substitution explicitly in the synthesis. Cheaper, fast, proven on doctrine-extending proposals — see precedent rows below. |
| Context files not found (Phase 0) | Proceed with available context, note gaps in Reframer prompt |

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Launching agents sequentially | Later agents see earlier outputs, destroying independent reasoning | Always launch all agents in ONE parallel message |
| Running Reframer in parallel with others | Defeats its purpose — if it says "wrong question," 5 agents already analyzed the wrong thing | Reframer runs FIRST (Phase 0), then others run in parallel (Phase 1) |
| Using council for factual research | Council evaluates proposals, not gathers data | Use `/agentresearch` for information gathering |
| Using council for single-belief testing | Council is multi-lens; single beliefs need evidence search | Use `/challenge` for single-belief pressure-testing |
| Skipping synthesis and just showing reports | Raw reports without synthesis leave the user to reconcile views alone | Always produce CONSENSUS + DIVERGENCE + CONFIDENCE SPREAD |
| Running debate mode without prior standard session | Agents can't challenge positions that don't exist yet | Run standard first, then debate |
| Putting council protocol in CLAUDE.md | Violates 80-100 line ceiling; rules file is the correct home | Protocol lives in `.claude/rules/council-protocol.md` |
| Skipping Phase 0 context loading | Reframer without PROFILE.yaml/ROADMAP is just doing word games | Always load the context bundle before invoking Reframer |

---

## Deliberation Quality Standards (v2.2)

Every council deliberation — standard or extended — applies this quality mandate automatically:

1. **Outcome-only success definition** (Step 0): Before evaluating, define what SUCCESS looks like in terms the primary stakeholder can observe. If you can infer the technical approach from the definition alone, it is invalid. Also define what failure looks like — wrong-but-plausible output is a CRITICAL risk.
2. **Reverse-engineer the path** (Step 1): From the perfect outcome, work backwards using first principles. What must be true? Simplest path from here to there.
3. **Evaluate against the path** (Step 2): Does the plan follow the reverse-engineered path? Is it the most reliable, bulletproof approach? If a better way exists, say so.
4. **Robust simplicity**: Start with the simplest approach. Add complexity ONLY to close real gaps toward defined success. Council agrees on achievability before including complexity.
5. **Stakeholder visibility check**: Would this make the primary stakeholder's decisions easier or harder? What do they see when it fails? Wrong-but-plausible failure data = CRITICAL.

**Output structure** (mandatory for plan reviews):
- 0. SUCCESS DEFINITION — outcome-only, stakeholder-observable, with failure visibility
- 1. RECOMMENDATIONS (CRITICAL / SIGNIFICANT / MINOR)
- 2. CONSIDERED AND DISMISSED (with reason)
- 3. AMBIGUOUS TRADE-OFFS (2+ agents dissent → escalate to user)

**Tiebreaker**: 2+ agents dissent from majority → routes to AMBIGUOUS. Pragmatist/Edge Case Finder dissent on execution questions carries extra weight. Reframer dissent on framing/strategic alignment carries extra weight.

**Override**: Projects can layer project-specific mandate customization via a memory file (e.g., naming a specific client persona). The universal standards above always apply as the baseline.

---

## Design Principles

- **Two-phase execution (extended)**: Reframer runs solo first (Phase 0), then 5 agents run in parallel (Phase 1)
- **Single-phase execution (standard)**: All 5 agents launch in parallel in one message
- **Fresh context**: Each agent gets a clean context window (subagent architecture handles this naturally)
- **Expanded context for Reframer**: Phase 0 loads PROFILE.yaml, ROADMAP.md, client CLAUDE.md, and recent sessions
- **Human-in-the-loop on reframes**: Reframer suggestions pause for user approval before council proceeds
- **No CLAUDE.md dependencies**: This skill is self-contained; protocol lives in `.claude/rules/council-protocol.md`
- **Template-safe**: No hardcoded project refs, venture names, or credentials
- **Complementary**: Designed to work alongside `/challenge` (single-belief) and `/agentresearch` (information gathering)
