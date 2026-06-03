---
name: prompt-forge
description: |
  Transform raw user intent into structurally optimal prompts for new Claude Code sessions.
  Takes messy, incomplete, outcome-focused input and produces enterprise-grade prompts with
  classification, decomposition, decision criteria, verification conditions, and infrastructure
  inventory. Prevents the 8 non-obvious failure modes that cause first-attempt failures.
  Supports single-session, sub-agent, and agent-team execution scaling. Interviews user to
  surface hidden requirements before generating. Output is paste-ready for a new chat.
  Use when: "forge this prompt", "improve this prompt", "prompt forge", "optimize my prompt",
  "make this prompt better", "session prompt for", "new chat prompt", "rewrite this for a new session",
  or when user provides a rough idea and needs a production-grade prompt for a new Claude Code chat.
version: 1.0
classification: capability-uplift
created: 2026-03-26
updated: 2026-03-26
validated_on:
  - messy_one_paragraph_intent_to_structured_prompt
  - multi_agent_build_prompt_with_contracts
  - simple_bug_fix_produces_lean_prompt_not_bloated
  - sub_agent_prompt_with_explicit_context_injection
triggers:
  - "forge this prompt"
  - "improve this prompt"
  - "prompt forge"
  - "optimize my prompt"
  - "make this prompt better"
  - "new chat prompt"
  - "rewrite this for a new session"
parameters:
  - name: raw_intent
    type: string
    description: "The user's raw prompt, idea, or intent to transform"
  - name: mode
    type: enum
    values: [forge, audit, interview-first]
    default: interview-first
    description: "forge = transform immediately; audit = score existing prompt; interview-first = ask questions then forge"
  - name: execution_scale
    type: enum
    values: [auto-detect, single, sub-agents, agent-team]
    default: auto-detect
    description: "Target execution pattern for the new session"
  - name: project_context
    type: boolean
    default: true
    description: "Whether to scan CLAUDE.md and infrastructure for context bridging"
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion, Agent, Write]
user-invocable: true
---

# Prompt Forge

> **Philosophy:** The best prompt is the shortest one that prevents all incorrect inferences. Every token competes with reasoning capacity. The skill is the factory; the prompt is the product.

---

## When This Applies

**Activate when:**
- User has a raw idea/intent and needs a prompt for a new Claude Code session
- User wants to improve an existing prompt before pasting it into a new chat
- User says "forge", "improve", "optimize", "rewrite" regarding a prompt
- User is about to start a new session and wants to maximize first-attempt success
- User has a continuation/spec that needs to be converted into a session-kickoff prompt

**Do NOT activate when:**
- User wants a continuation prompt carrying forward session state (use `/master-continuation-prompt`)
- User is asking about prompt engineering theory (just answer directly)
- User wants to create a reusable skill (use `/skill-creator`)

---

## Core Principles (Encoded from Research)

| # | Principle | Implementation |
|---|-----------|----------------|
| 1 | **Minimum Sufficient Instruction** | Shortest prompt that prevents all incorrect inferences. Cut anything Claude would figure out from code. |
| 2 | **Verification as Exit Criteria** | Machine-checkable conditions are the #1 highest-leverage addition. Without them, every mistake is terminal. |
| 3 | **Layer-Appropriate Placement** | Enforcement rules belong in hooks, persistent context in CLAUDE.md, only task-specific work in the session prompt. |
| 4 | **Decision Criteria Over Instructions** | "When X, do Y" frameworks produce consistent results. Rigid instructions break on edge cases. |
| 5 | **Explicit Context for Isolated Agents** | Sub-agents inherit nothing — no CLAUDE.md, no skills, no parent context. Everything must be injected. |

---

## Protocol: 5-Phase Execution

### Phase 1: Intake & Interview (MANDATORY unless mode=forge)

**1.1 Receive raw intent.** Accept whatever the user provides — messy, incomplete, outcome-focused. Do not judge the quality; that is Phase 2's job.

**1.1a Run the Framing Audit (mandatory — `.claude/rules/framing-audit-mandate.md`).** Before the Inference Audit — and before any processing of the intent — ask the prior question: "is the intent the *right question* at all?" A forged prompt carries its frame into every downstream session, so a wrong frame must be caught before the prompt is shaped. Mandatory for load-bearing intent; skip ONLY for trivia (typo fixes, single-line edits, factual lookups).

- Pick the matching primitive: `/reduce-to-first-principles` (default — the intent is a proposal/claim/gate), `/check-commensurability` (a comparison underpins it), or `/map-feedback-loops` DECISION mode (consequences play out over time).
- Run it on the raw intent. Record the structured verdict — it MUST be carried into the Phase 5 delivery check (Quality Test question 6).
- A clean verdict (`SOUND`, or `ADDS_CONSTRAINTS` with the additions noted) → proceed to 1.2.
- A flagged frame (`SMUGGLES_CONCLUSIONS`, a rung-1/2 comparison firing the Hands-On Calibration Gate, or a `frame-criticism` classification) → do NOT forge yet. Surface the reframe to the user; forge the *reframed* intent. If the user reviews the reframe and declines it, record the disagreement and their stated reason in the verdict, then forge under their frame — a stated, recorded gap is allowed; only a silent skip is forbidden.
- If the primitive returns no usable verdict (`INSUFFICIENT_INPUT`, `SCOPE_REFUSAL`, an error, or it is not registered), the audit did NOT run — treat that as a HALT, not a pass. Surface the unmet input and restate the intent, or escalate to the user. Never record a clean verdict for an audit that did not complete.
- Cite the primitive; never copy its procedure. See `.claude/rules/framing-audit-mandate.md` for the full trigger table and the five primitives.

**1.2 Run the Inference Audit.** Before asking questions, silently analyze:

```
INFERENCE AUDIT — What would Claude get wrong if given ONLY this intent?
─────────────────────────────────────────────────────────────────────────
□ What KIND of work is this? (Would Claude default to the wrong pattern?)
□ What existing infrastructure would Claude rebuild from scratch?
□ What scope boundaries would Claude assume incorrectly?
□ What error handling strategy would Claude pick by default?
□ What output format/location would Claude choose?
□ What verification would Claude skip?
□ Would Claude mix exploration with implementation?
□ Are there decisions with multiple valid approaches that need criteria?
```

Each "yes" in this audit becomes either a question for the user OR a component in the final prompt.

**1.3 Ask Strategic Questions.** Ask 3-7 questions that surface hidden requirements. Rules:
- Do NOT ask about things you can determine from the project (read CLAUDE.md, scan infrastructure)
- Do NOT ask obvious questions ("what language?")
- DO ask about trade-offs, decision points, and scope boundaries
- DO ask about verification criteria ("how will you know this worked?")
- DO ask about execution scale if ambiguous

**Question template:**

```
I've analyzed your intent. Before I forge this, I need to understand:

1. [CLASSIFICATION] — Is this {X} or {Y}? (affects how Claude approaches it)
2. [SCOPE] — Should this include {Z} or stop at {W}?
3. [DECISION POINT] — When {scenario}, should Claude {option A} or {option B}?
4. [INFRASTRUCTURE] — I see you have {existing_tool}. Should the new session compose with it or build fresh?
5. [VERIFICATION] — What specific check would confirm this is done correctly?
```

**1.4 Classify the work.**

| Dimension | Options | Why It Matters |
|-----------|---------|----------------|
| **Scope** | single-file, multi-file, cross-system, orchestration | Determines decomposition depth |
| **Pattern** | CRUD, pipeline, state-machine, audit, transformation, meta-tooling | Activates right mental models |
| **Complexity** | trivial (<50 LOC), moderate (50-200), substantial (200-500), architectural (500+) | Determines plan-mode need |
| **Domain** | data-layer, UI, automation, integration, infrastructure | Selects relevant conventions |
| **Execution** | single-session, sub-agents, agent-team, plan-then-execute | Shapes prompt structure |

---

### Phase 2: Project Context Scan (if project_context=true)

**2.1 Read CLAUDE.md** — Extract: stack, conventions, safety rails, MCP servers, known issues, "don't do" list. These become the Context Bridge in the final prompt.

**2.2 Scan infrastructure** — Identify tools, scripts, skills, RPCs, views that the new session should compose with, not rebuild.

```
INFRASTRUCTURE INVENTORY
────────────────────────
Glob: .claude/skills/*/SKILL.md → existing skills
Glob: .claude/rules/*.md → active rules
Grep: relevant function/RPC names in supabase migrations
Read: .mcp.json → connected MCP servers
```

**2.3 Check for related existing work** — Continuations, specs, fix docs that provide context.

**Output:** A structured context brief (NOT included in the final prompt — used to INFORM what goes in the Context Bridge component).

---

### Phase 3: Structural Assembly

Assemble the 9 components. The key discipline: **include a component ONLY if its absence would cause an incorrect inference.**

#### Component 1: Classification Block
```markdown
## Classification
- **Scope**: {{scope}}
- **Pattern**: {{pattern}}
- **Complexity**: {{complexity}}
- **Execution**: {{execution_scale}}
```
**Include when:** Always. This is the single highest-leverage line — it activates the right mental models before Claude reads a single requirement.

#### Component 2: Decomposition
```markdown
## Phases
1. **{{Phase name}}** — {{what happens, what it produces}}
2. **{{Phase name}}** — {{what happens, consumes Phase 1 output}}
3. **{{Phase name}}** — {{what happens, final output}}
```
**Include when:** Work has 2+ distinct phases. Omit for single-step tasks.

**Rules:**
- If a phase has more than one verb, it is two phases
- 3-5 phases maximum (fewer = not decomposed enough; more = micromanaging)
- Name the artifact each phase produces

#### Component 3: Decision Criteria
```markdown
## Decision Criteria
- **When {{scenario}}**: {{action}} — because {{reason}}
- **When {{scenario}}**: {{action}} — because {{reason}}
```
**Include when:** There are ambiguous choice points where Claude's default would be wrong. Omit when all choices are obvious.

#### Component 4: Infrastructure Inventory
```markdown
## Existing Infrastructure (compose with, don't rebuild)
| Asset | Location | What It Does | How This Work Uses It |
|-------|----------|-------------|----------------------|
```
**Include when:** The project has relevant existing tools, scripts, RPCs, or skills. The "How This Work Uses It" column is mandatory — without it, Claude knows the asset exists but not where it fits.

#### Component 5: Novelty Flags
```markdown
## Where the Innovation Lives
**Novel** (concentrate design effort here): {{description}}
**Standard** (don't over-engineer): {{description}}
```
**Include when:** There is a mix of novel and standard work. Prevents Claude from gold-plating boilerplate while rushing innovation.

#### Component 6: Constraints
```markdown
## Constraints
- NEVER {{action}} — because {{reason}}
- ALWAYS {{action}} — because {{reason}}
```
**Include when:** Claude's default behavior would be wrong for this context. Constraints shape priors; instructions compete with them.

**Rules:**
- Constraints > Instructions (constraints shape defaults; instructions compete with them)
- Only add constraints where Claude's default is WRONG here
- Each constraint needs a "because" — naked constraints get deprioritized

#### Component 7: Verification Conditions (HIGHEST LEVERAGE — NEVER OMIT)
```markdown
## Verification
- [ ] {{machine-checkable condition — a command Claude can run}}
- [ ] {{assertion condition — a specific property Claude can verify}}
- [ ] {{negative condition — grep for X; if found, output is wrong}}
```
**Include when:** ALWAYS. This is non-negotiable. Anthropic calls it "the single highest-leverage thing you can do."

**Rules:**
- Every condition must be machine-checkable (a command, a grep, a file-exists check)
- Include at least one negative condition (catches specific failure modes)
- "It should be good" is NOT a verification condition

#### Component 8: Output Specification
```markdown
## Outputs
| File | Purpose | Format |
|------|---------|--------|
```
**Include when:** The work produces files. Omit for pure investigation/research tasks.

#### Component 9: Context Bridge
```markdown
## Context This Session Needs
- {{Convention not in CLAUDE.md that matters here}}
- {{Decision from prior work that constrains this task}}
- {{Terminology specific to this ecosystem}}
```
**Include when:** The new session needs knowledge from prior sessions, undocumented conventions, or relationships between systems not obvious from code.

**Rules:**
- Only bridge what Claude CANNOT determine from reading code/CLAUDE.md
- If it's in CLAUDE.md, don't repeat it — Claude will read CLAUDE.md automatically
- Bridge the non-obvious connections, not the documentation

#### Component 10: Cold-Open Session Start (REQUIRED when execution_scale touches a git repo)
```markdown
## How To Use This Prompt — Cold-Open Session Start

You are opening a fresh chat with zero memory. Follow these steps in order.

### Step 0 — Feature branch in the one folder  ← REQUIRED for branch-modifying work

Single-folder is the default: one canonical clone, every job a feature branch *inside it* — no new folder, no worktree (see `.claude/rules/worktree-discipline.md`). Open a terminal in 📁 `{{repo_root_path}}` (the one canonical clone) and run:

```bash
git fetch origin main
# If the working tree has unrelated WIP, stash it first so the switch starts clean:
#   git stash push -u -m "wip before {{branch_name}}"
git switch -c {{branch_name}} origin/main   # feature branch IN the one folder

# Confirm starting state
git log --oneline -3
# Expect:
#   {{predecessor_commit_sha}} {{predecessor_commit_title}}
```

A separate worktree is the rare parallel-work exception only (e.g. `/build-with-agent-team`), never the per-job default; the enforcement hook blocks unsanctioned `git worktree add`. NEVER use a cloud-synced directory (iCloud / OneDrive / Dropbox) — sync corrupts `.git`. NEVER use a temp dir (`/tmp/*`) — tmpfs git auto-lock. Use a real non-synced working directory (e.g. `~/code/`).

### Step 1 — Read system architecture + this prompt + any predecessor handoffs named below

### Step 2 — Run any Verification block BEFORE writing code

### Step 3 — Enter plan mode + produce a plan + execute phase-by-phase, one PR per phase
```
**Include when:** The forged prompt's execution_scale is `single-session`, `sub-agents`, `agent-team`, or any path that involves committing code to a git repo. **Omit when:** execution is read-only research with no code output.

**Rules:**
- Concrete commands, not generic guidance — the cold-open chat must reach the verification step with zero questions back
- Substitute every `{{placeholder}}` with the actual repo slug + scope slug + branch name + expected predecessor commit SHA + commit title + repo root absolute path. Generic placeholders unresolved in the emitted prompt = FAIL.
- Banned paths: cloud-synced dirs (iCloud / OneDrive / Dropbox / Documents/GitHub) corrupt `.git`; temp dirs (`/tmp/*`) auto-lock. Use a real non-synced working directory.
- If the project doesn't use `node_modules`, drop the symlink line.

---

### Phase 4: Compression & Quality Gate

**4.1 Minimum Sufficiency Pass.** For every line in the assembled prompt, ask:

```
"Would removing this line cause Claude to make a mistake?"
   YES → Keep it
   NO  → Cut it
```

This is the most important step. Comprehensiveness is the enemy. Every token competes with reasoning capacity. CLAUDE.md content injected automatically does NOT need to be repeated.

**4.2 Failure Mode Scan.** Check the prompt against all 8 failure modes:

| # | Failure Mode | Check | Fix |
|---|-------------|-------|-----|
| 1 | No verification conditions | Is `## Verification` present with machine-checkable items? | Add verification section |
| 2 | Prompt too long | Is the prompt >800 words? | Cut ruthlessly — move persistent rules to CLAUDE.md suggestion |
| 3 | Silent inference | Are there unstated concerns Claude will misinterpret? | Add constraint or decision criteria |
| 4 | Sub-agent context starvation | If sub-agents will be spawned, does the prompt specify what context to inject? | Add explicit context injection instructions |
| 5 | Tool interface ambiguity | Does the prompt reference tools/skills that might be confused? | Add tool differentiation table |
| 6 | Ephemeral rules in long sessions | Are there rules that must survive context compression? | Flag as CLAUDE.md candidates, not prompt content |
| 7 | Mixing exploration and implementation | Does Phase 1 combine research and building? | Separate into explore-then-implement phases |
| 8 | Comprehensiveness bias | Are there "just in case" sections? | Apply the "would removing this cause a mistake?" test |

**4.3 Execution Scale Adaptation.**

If `execution_scale = single`:
- Prompt is complete as-is

If `execution_scale = sub-agents`:
- Add explicit context injection block: "When spawning sub-agents, inject: {{list}}"
- Add scope boundaries per agent: "Agent A handles X only, not Y"
- Add output contracts: "Each agent returns: {{format}}"

If `execution_scale = agent-team`:
- Add file ownership table (no two agents write same file)
- Add interface contracts (Agent A produces X.json, Agent B reads X.json)
- Add shared decisions section (naming, data structures decided upfront)
- Add integration verification step

If `execution_scale = plan-then-execute`:
- Wrap prompt in plan-mode instruction: "Enter plan mode. Read the following, then produce an implementation plan for my review before touching any code."
- Ensure decomposition is at plan-level (strategic), not implementation-level (tactical)

---

### Phase 5: Output & Scorecard

**5.1 Generate the final prompt.** Format as a single markdown block ready to paste.

**5.2 Generate the Quality Scorecard.**

```markdown
## Prompt Forge Scorecard
| Component | Present | Notes |
|-----------|---------|-------|
| Classification | YES/NO | {{note}} |
| Decomposition | YES/NO/NA | {{note}} |
| Decision Criteria | YES/NO/NA | {{note}} |
| Infrastructure Inventory | YES/NO/NA | {{note}} |
| Novelty Flags | YES/NO/NA | {{note}} |
| Constraints | YES/NO/NA | {{note}} |
| Verification Conditions | YES/FAIL | {{note}} — FAIL if missing |
| Output Specification | YES/NO/NA | {{note}} |
| Context Bridge | YES/NO/NA | {{note}} |
|---|---|---|
| Failure Mode Scan | PASS/FAIL | {{which modes triggered}} |
| Execution Scale | {{scale}} | {{adaptation applied}} |
| Token Efficiency | {{word count}} | Target: <800 words |
| Minimum Sufficiency | PASS/FAIL | {{lines cut}} |
```

Verification Conditions is the ONLY component that can FAIL the scorecard. All others may legitimately be NA for simple tasks.

**5.3 Suggest layer-appropriate placements.** If the prompt contains rules that should be persistent:

```
## Suggested CLAUDE.md Additions (Optional)
These rules from your prompt would benefit from persistence in CLAUDE.md or .claude/rules/:
- {{rule}} — because it applies beyond this single session
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Include everything "just in case" | Token competition — bloated prompts get rules ignored | Include ONLY what prevents incorrect inferences |
| Repeat CLAUDE.md content in the prompt | Claude reads CLAUDE.md automatically; duplication wastes tokens | Bridge only what's NOT in CLAUDE.md |
| Write instructions instead of constraints | Instructions compete with Claude's priors; constraints shape them | "NEVER do X because Y" > "Please do Z" |
| Skip verification conditions | Every mistake becomes terminal — you are the only feedback loop | ALWAYS include machine-checkable exit criteria |
| Forge without interviewing | Hidden requirements surface as failures during execution | Ask 3-7 strategic questions first |
| Over-decompose simple tasks | 8 phases for a 3-line bug fix wastes context and confuses priorities | Match decomposition depth to actual complexity |
| Specify HOW instead of WHAT + WHY | Micromanages Claude into a local optimum | Specify what and why; let Claude handle how |
| Assume sub-agents inherit context | Sub-agents get NOTHING from parent — no CLAUDE.md, no skills, no conversation | Explicitly inject all required context |
| Generate prompt without scanning project | Misses existing infrastructure, causes rebuilding | Always read CLAUDE.md and scan for relevant assets |
| Put enforcement rules in the prompt | Prompt rules are advisory and ephemeral; lost after compression | Enforcement → hooks; persistent → CLAUDE.md |

---

## Error Recovery

| Condition | Behavior |
|-----------|----------|
| User provides no raw intent | Ask: "What do you want the new session to accomplish?" |
| Raw intent is already well-structured | Run audit mode — score and suggest improvements only |
| Project has no CLAUDE.md | Proceed without context scan; note in scorecard |
| Verification conditions are impossible to define | Flag as HIGH RISK in scorecard; suggest investigation-first approach |
| Prompt exceeds 800 words after compression | Identify candidates for CLAUDE.md/rules migration |
| User disagrees with classification | Reclassify and re-run Phase 3 — classification drives everything |
| Interview surfaces scope much larger than expected | Suggest splitting into multiple sessions with a sequencing plan |

---

## Execution Scale Reference

| Scale | When to Use | Prompt Additions Required |
|-------|-------------|--------------------------|
| **Single** | Task completable in one session, no parallelism needed | None — standard prompt |
| **Sub-agents** | 2+ independent research/investigation tasks | Context injection block, scope boundaries, output contracts |
| **Agent-team** | 3+ independent implementation tasks with shared codebase | File ownership, interface contracts, shared decisions, integration verification |
| **Plan-then-execute** | Uncertainty about approach, multi-file changes, unfamiliar code | Plan-mode wrapper, strategic decomposition, review checkpoint |

**Auto-detection heuristic:**
- Trivial/moderate complexity → single
- Research-heavy with multiple angles → sub-agents
- Substantial/architectural with parallelizable implementation → agent-team
- Any task where the user says "I'm not sure how to approach this" → plan-then-execute
- Brief describes a multi-session programme (≥3 sequential sessions, shared verification standard, framework-set synthesis) → **programme-launchpad** (see below)

---

## Mode: programme-launchpad

**Trigger**: brief describes multi-session work spanning ≥3 named sessions with sequential dependencies and a shared verification standard. Examples: synthesising N frameworks across M sessions, building an N-stage product methodology, migrating an N-system stack. Also triggers when the user picks "programme launchpad" from the intake interview's scope-classification question.

**Why a special mode**: standard prompt-forge produces one paste-ready prompt for one session. A multi-session programme needs (a) session 1 to ship, (b) sessions 2-N to inherit the same verification standard, (c) every future session to know which session it's in and what's in scope. Without scaffolding, session N silently drifts from the programme's intent.

**Deliverable** (4 coordinated artefacts, not 1):

| # | Artefact | Purpose | Location |
|---|----------|---------|----------|
| 1 | Programme spec | Forged session 1 prompt + session forecast (sessions 1-N with status) + verification standard + MVP framework set + recently-completed log | `specs/NN_<programme-name>.md` |
| 2 | Alignment contract | 8-12 hard clauses any programme session must obey; auto-loads on programme-class work via path predicate | `.claude/rules/<programme-name>-alignment.md` |
| 3 | Memory index entry | Single-line pointer in "In-Flight Work" section referencing BOTH the spec AND the contract | `.claude/memory/MEMORY.md` |
| 4 | Project memory pointer | 2-3 line "In-Flight Programme" section in CLAUDE.md so every session loads the pointer automatically | `CLAUDE.md` |

**Token-efficiency exception**: programme spec may exceed the standard <800-word target (cap raised to <2,500 words). Decomposition + verification + 8-12-session forecast cannot compress further without losing the inference-prevention contract. Single-session forged prompts still target <800.

**Alignment contract must contain**:
1. Read programme spec FIRST before substantive work
2. Declare which session this is (halt if unclear)
3. Compose with existing tools — never rebuild
4. Pass the programme's verification gate before merging any artefact
5. Strategic Alignment footer on every council / spec / continuation
6. Manifest update before ending the session
7. Layman voice in chat; technical register in artefacts
8. Anti-sycophancy enforcement — name the existing tools that fire it
9. Plan-then-execute on every non-trivial session
10. Output chunking — manifest-first for any deliverable >3,000 tokens

The 10 clauses are template; programme-specific predicates (which file paths trigger the contract, which framework set is in MVP scope, which verification standard applies) fill in the specifics. Reference: `.claude/rules/multi-session-programme-contract-template.md` for the generic skeleton.

**Scorecard adaptation for programme-launchpad**:
- Token efficiency: <2,500 words for the spec; <800 for the forged session-1 prompt embedded inside
- Verification additions:
  - Alignment contract must specify a predicate for which sessions are in-scope (path globs, file types, or topic keywords)
  - Spec must contain a session forecast (sessions 1-N with status: NEXT / LATER / HORIZON)
  - MEMORY.md In-Flight entry must reference BOTH the spec AND the contract (single-pointer drift = single-point-of-failure)
  - CLAUDE.md must contain the In-Flight Programme pointer

**Failure modes prevented by this mode**:
- Forecast 1: session 2 silently borrows session 1's conclusions because they're load-bearing → produces a contaminated artefact. Prevented by alignment contract clause 2 (declared scope).
- Forecast 2: session 5 ships an artefact that hasn't passed the programme's verification gate → propagates fragility. Prevented by clause 4.
- Forecast 3: session 8 drifts into a side-quest that produces no NSM-aligned artefact → invisible drift. Prevented by clause 5 (Strategic Alignment footer).
- Forecast 4: session 11 produces a long inline deliverable that truncates at output-token limit → unrecoverable. Prevented by clause 10 (manifest-first).

**Failure precedent (programme-launchpad's birthday, 2026-05-10)**: User submitted a 6,000-word brief on synthesising 40+ business / systems / decision-theory frameworks into reusable operational doctrine + Claude Code skills + enforcement hooks. Standard prompt-forge mode would have produced one forged prompt for "do everything", which is unexecutable. Programme-launchpad mode produced the synthesis programme spec (with session 1 forged prompt inline + 12-session forecast) + alignment contract + memory index entry + CLAUDE.md pointer. Session 1 can now run with drift-prevention scaffolding already in place.

---

## The Quality Test (Pre-Delivery Check)

Before delivering ANY forged prompt, verify these 6 questions:

1. **Senior Engineer Test** — If a senior engineer who's never seen this codebase received this prompt, could they execute it without asking a question?
2. **Decision Point Test** — When Claude hits an ambiguous choice, does the prompt tell it how to decide?
3. **Verification Test** — Can Claude grep/run/check something specific to verify correctness?
4. **Novelty Test** — Does the prompt signal where to concentrate effort vs. where to keep it standard?
5. **Infrastructure Test** — Does the prompt reference everything that exists and shouldn't be rebuilt?
6. **Framing Test** — For load-bearing intent, was the framing audit run (step 1.1a) and its verdict recorded? A forged prompt whose intent's framing was never audited is not ready.

If any answer is NO, the prompt is not ready.

---

## Quick Reference

| User Says | Mode | Action |
|-----------|------|--------|
| "Forge this prompt" / provides raw idea | interview-first | Full 5-phase protocol |
| "Improve this prompt" / provides existing prompt | audit | Score + suggest improvements |
| "Quick forge, no questions" | forge | Skip interview, run Phase 2-5 |
| "Forge for agent team build" | interview-first | Force execution_scale=agent-team |
| "Forge for plan mode" | interview-first | Force execution_scale=plan-then-execute |
| Brief describes multi-session programme (≥3 sessions, shared verification) | interview-first | Force mode=programme-launchpad — produces 4-artefact deliverable |

---

*Skill Version: 1.1 — Capability Uplift — Encodes 5 principles, 9 components, 8 failure modes from primary research; v1.1 (2026-05-10) adds programme-launchpad mode for multi-session work*
