---
name: master-continuation-prompt
description: |
  Generate enterprise-grade continuation prompts that carry full session context,
  strategic alignment, and verified state into a new Claude Code session. Analyzes
  current work, memory, architecture, and roadmap to produce a standalone handoff
  document enabling laser-precision planning and implementation. Applies prompt-forge
  principles: classification block, inference audit, compression pass, machine-checkable
  verification, decision criteria, novelty flags, and sub-agent context injection.
  Output is minimum-sufficient — never duplicates CLAUDE.md content.
version: 2.1
classification: encoded-preference
created: 2026-02-22
updated: 2026-05-16
validated_on:
  - Multi-layer feature continuation (12 sections, 584 lines, frontend+backend+DB)
  - Phase-tracked architecture continuation (8 sessions, incremental progress)
  - Deep debugger continuation (10-phase verification chain)
parameters:
  - name: work_scope
    type: string
    description: "The feature/workstream this continuation covers"
  - name: continuation_type
    type: enum
    default: master
    values: [master, phase_tracker, bug_fix, planning_only]
    description: "Type of continuation prompt to generate"
  - name: output_dir
    type: path
    default: continuations/
    description: "Directory for the output file"
  - name: include_research_agents
    type: boolean
    default: true
    description: "Whether to suggest research agents for the new session"
  - name: execution_scale
    type: enum
    values: [auto-detect, single, sub-agents, agent-team, plan-then-execute]
    default: auto-detect
    description: "Target execution pattern for the new session"
---

!`date "+%Y-%m-%d %H:%M %Z"`
!`git log --oneline -10 2>/dev/null`
!`git diff --stat 2>/dev/null`
!`git status --short 2>/dev/null | head -20`
!`git branch --show-current 2>/dev/null`

# Master Continuation Prompt Generator

Produces a **self-contained continuation prompt** that gives a fresh Claude Code session
everything it needs to plan and execute the next phase of work at the highest standards.

Invoked by `/Master-Continuation-Prompt` command.

---

## Philosophy

A continuation prompt is NOT a todo list. It is a **minimum-sufficient operational briefing** that:

1. **Classifies** the work (scope, pattern, complexity, execution scale) — activates the right mental models
2. Explains **WHY** this work matters (client value, strategic alignment)
3. Documents **WHAT** exists (verified state, not assumptions)
4. Provides **DECISION CRITERIA** for ambiguous choices the new session will face
5. Flags **WHERE THE HARD PART IS** vs what's standard (novelty flags)
6. Warns about **LANDMINES** (gotchas, constraints, do-not-undo items)
7. Ends with **MACHINE-CHECKABLE VERIFICATION** (commands the new session can run, not descriptions)

### The Minimum Sufficiency Principle

The new session will read CLAUDE.md automatically. **Never repeat CLAUDE.md content in the continuation prompt.** Every line must pass: "Would removing this cause the new session to make a mistake?" If no, cut it. Context window is finite — every token of context competes with reasoning capacity.

### The Three Authority Layers

| Layer | What Goes There | Persistence |
|-------|----------------|-------------|
| **CLAUDE.md / rules/** | Conventions, safety rails, schema gotchas that apply to ALL sessions | Permanent |
| **Memory** | Discoveries, decisions, context that apply to FUTURE sessions | Permanent |
| **Continuation prompt** | ONLY what's unique to THIS work — state, gaps, phases, verification | Ephemeral |

If you discover something during generation that should be persistent, **suggest adding it to CLAUDE.md or memory** rather than embedding it in the continuation.

---

## Continuation Type Taxonomy

| Type | When to Use | Typical Length | Key Sections |
|------|-------------|----------------|--------------|
| **master** | Multi-session feature work, strategic deliverables | 300-600 lines | All 14 sections |
| **phase_tracker** | Work split across numbered phases (Phase 1/2/3...) | 150-300 lines | State + Remaining + Verification |
| **bug_fix** | Specific bug investigation and fix continuation | 80-150 lines | Root Cause + Fix Applied + Remaining |
| **planning_only** | Research/design complete, needs implementation planning | 200-400 lines | Research Summary + Architecture + DO NOT IMPLEMENT note |

---

## Step 0 — Determine Scope & Type

Before generating anything, determine:

1. **What work was done this session?** — Scan conversation for completed actions
2. **What remains?** — Identify unfinished items, blocked work, next steps
3. **What type of continuation?** — Use taxonomy above
4. **What's the blast radius?** — Which system layers are involved?
5. **Is this part of a multi-session programme?** — See "Programme Detection" below

```
BLAST RADIUS CHECKLIST:
[ ] Database (tables, RPCs, views, migrations)
[ ] Workflows (n8n workflows, triggers, subworkflows)
[ ] Edge Functions (Supabase edge functions)
[ ] Frontend (pages, components, hooks, routes)
[ ] Backend/API (RPCs, edge functions, external APIs)
[ ] Agents/Skills (Claude Code configuration)
[ ] Cross-workstream (impacts other features/projects)
```

### Programme Detection (added 2026-05-11 — pairs with prompt-forge programme-launchpad mode)

If this continuation is one session within a multi-session programme (≥3 sequential sessions sharing a verification standard, framework set, or build sequence — examples: arc-level work like "Operational Intelligence Synthesis Sessions 1-12", "Client Migration Q3 Phases 1-N", "Multi-Stack Refactor Streams A/B/C"), then the continuation MUST cross-reference the programme's alignment contract so the next session inherits the verification gate.

**Detection signals**:
- The work is referenced in `MEMORY.md` "In-Flight Work" with a programme name + session/phase number
- A spec file exists at `specs/NN_<programme-name>.md` with a session forecast
- A rule file exists at `.claude/rules/<programme-name>-alignment.md` (the derived contract)
- The user's session prompt mentions a Stage / Phase / Wave / Session number tied to a named arc

**If detected**:
1. Set the `programme_name` + `programme_contract` fields in §5A Implementation Status Frontmatter (REQUIRED — these fields are gated by programme detection, optional otherwise)
2. In §11 Design Principles → "Must Follow", add a literal first bullet: `Read .claude/rules/<programme-name>-alignment.md BEFORE substantive work — it carries the 10-clause verification gate for every session in this programme.`
3. In §14 Verification → "State Verification", add a literal first command: `test -f .claude/rules/<programme-name>-alignment.md && head -5 $_ || echo "MISSING PROGRAMME CONTRACT — halt and ask user"`
4. In §0 Strategic Context, add a one-line "Programme position" stating which session (e.g., "Session 8 of the Operational Intelligence Synthesis Arc — sessions 1-7 complete; sessions 9-12 queued")

**If NOT detected**: skip programme-launchpad fields, generate standard 14-section continuation.

**Generic skeleton for new programmes**: 📄 `.claude/rules/multi-session-programme-contract-template.md` — the 10-clause template that prompt-forge's programme-launchpad mode uses when birthing a new programme. Master-continuation-prompt does NOT author new contracts (that's prompt-forge's job); it only points the next session at an existing one.

---

## Step 1 — Gather Context (Research Phase)

**This is the most critical step.** The continuation prompt must contain VERIFIED facts,
not assumptions. Research each layer that's in the blast radius.

### 1A. Session Work Analysis

Analyze the current conversation to extract:

- **Completed items** — What was actually done (with file paths, SQL applied, workflow changes)
- **Partial items** — What was started but not finished
- **Blocked items** — What couldn't proceed and why
- **Discoveries** — Things learned during the session that the next session needs
- **Decisions made** — Architecture choices, trade-offs selected, user preferences

### 1B. Memory & Strategic Context

Read and extract relevant context from:

```
CLAUDE.md                    → System architecture, RPCs, conventions
ROADMAP.md                   → Strategic alignment, priority ranking
memory/MEMORY.md             → Cross-session persistent knowledge
.claude/daily-plans/         → Recent daily plans (last 3 days)
continuations/               → Related existing continuations (avoid duplication)
```

**Key questions to answer:**
- Which ROADMAP item(s) does this work support?
- What's the client-visible impact?
- Are there dependencies on other workstreams?

### 1C. Architecture & File Discovery

For each layer in the blast radius, research:

| Layer | What to Discover | How |
|-------|-----------------|-----|
| **Frontend** | Components, pages, hooks, routes involved | Glob for related `.tsx`/`.ts` files, read component structure |
| **Backend RPCs** | Related RPCs, their parameters, return shapes | Query `{{db_tool}}` for function signatures |
| **Database** | Tables, views, columns, row counts, recent data | Query `{{db_tool}}` for schema + sample data |
| **Workflows** | Related workflow IDs, node names, connections | Query `{{workflow_tool}}` for structure |
| **Edge Functions** | Deployed functions, their capabilities | Read source files in `edge-functions/` or `supabase/functions/` |
| **External APIs** | Integrations involved, auth methods | Check `.mcp.json`, API docs |

### 1D. Gap Analysis

Compare **current state** against **desired outcome**:

```
For each feature/capability:
  CURRENT STATE: [what exists today — verified]
  DESIRED STATE: [what should exist — from roadmap/user request]
  GAP:           [what's missing — specific, actionable]
  EFFORT:        [Small / Medium / Large]
  IMPACT:        [Critical / High / Medium / Low]
```

Prioritize gaps by: `IMPACT / EFFORT` ratio (highest first).

---

## Step 1D.5 — Framing Audit (mandatory — `.claude/rules/framing-audit-mandate.md`)

Before the Inference Audit — and before locking the continuation's scope — audit the
*framing* of the work being handed off. A continuation that carries a wrong frame hands
that wrong frame to the next session, where it becomes load-bearing across every downstream
phase; auditing it here means the Inference Audit that follows runs inside an audited frame.
This is a named, non-skippable step for load-bearing handoffs; skip ONLY for trivia
(typo-fix continuations, single-line handoffs).

- Pick the matching primitive: `/reduce-to-first-principles` (default — the handed-off work
  is a proposal/claim/gate), `/check-commensurability` (a comparison underpins it), or
  `/map-feedback-loops` DECISION mode (consequences play out over time).
- Run it on the work's framing. Record the structured verdict in the continuation —
  Section 1 (Strategic Context) or Section 4 (Decision Criteria). Its presence is a Step 3
  Must-Pass requirement; a load-bearing continuation with no recorded verdict is incomplete.
- A flagged frame (`SMUGGLES_CONCLUSIONS`, a rung-1/2 comparison firing the Hands-On
  Calibration Gate, or a `frame-criticism` classification) → do NOT generate the continuation
  on that frame. Surface the reframe; the continuation must hand off the *reframed* work. If
  the operator reviews the reframe and declines it, record the disagreement and their stated
  reason in the verdict, then generate under their frame — a stated, recorded gap is allowed;
  only a silent skip is forbidden.
- If the primitive returns no usable verdict (`INSUFFICIENT_INPUT`, `SCOPE_REFUSAL`, an
  error, or it is not registered), the audit did NOT run — treat that as a HALT, not a pass.
  Surface the unmet input and restate the work's framing, or escalate to the operator. Never
  record a clean verdict for an audit that did not complete.
- Cite the primitive; never copy its procedure. See `.claude/rules/framing-audit-mandate.md`
  for the full trigger table and the five primitives.
- **Destination pointer (generative complement).** The framing audit above is *diagnostic*
  (is the frame sound?); this is its *generative* companion (does the arc have a written
  definition of done?). If a `DESTINATION.md` exists at the repo root, cite its end-state
  (Element 1) + binary success test (Element 2) **by pointer** in Section 1 — a one-line echo,
  NEVER a copy of the file. This carries the arc's success target into a cold-read / autofired
  session so it inherits what "done" means. If `DESTINATION.md` is ABSENT, degrade gracefully:
  state "Destination: none written for this arc" in Section 1 — never crash, never fabricate a
  target. Cite `.claude/rules/framing-audit-mandate.md` (generative-complement section); the
  destination is authored by `/define-destination`, not by this skill.

---

## Step 1E — Inference Audit (NEW — Prompt Forge Principle)

Before generating, ask: **"What would the new session get wrong if given only CLAUDE.md and no continuation?"**

```
INFERENCE AUDIT:
□ Would the new session know what KIND of work this is? → Add Classification block
□ Would the new session rebuild infrastructure that already exists? → Add Infrastructure Inventory
□ Would the new session make wrong assumptions about scope? → Add Constraints
□ Would the new session know where the HARD PART is? → Add Novelty Flags
□ Would the new session know how to handle ambiguous decisions? → Add Decision Criteria
□ Would the new session know what execution scale to use? → Add Execution Scale
□ Are there things in your draft that CLAUDE.md already covers? → CUT THEM
```

Each "yes" becomes a component in the output. Each "no" means that component can be omitted.

## Step 1F — Layer Placement Triage

For each discovery or rule from the session:

| If it applies to... | Put it in... | NOT in the continuation |
|---------------------|-------------|------------------------|
| ALL future sessions | CLAUDE.md or `.claude/rules/` | Flag as "Suggested CLAUDE.md addition" |
| FUTURE sessions on this topic | `memory/` file | Flag as "Suggested memory addition" |
| ONLY the next session | Continuation prompt | This is the right place |

**Run this before generating.** If you discover 3+ items that belong in CLAUDE.md, suggest updating it first.

---

## Step 1G — Cold-Read Safety Gate (MANDATORY — runs after authoring, before emit)

A continuation is executed by a session with **zero memory of how it was produced** — frequently an autofire-chained session that never saw the originating conversation. The Minimum Sufficiency Principle is necessary but not self-enforcing: an author with full conversational context routinely leaks a load-bearing fact into a place the cold reader cannot reach. This gate makes that failure class structurally impossible. It composes with Step 1D.5 (which audits the *framing*); this audits *cold-read completeness*.

Before emitting ANY continuation, run all four checks. Any failure → fix the continuation, do not emit.

1. **No session-scoped artefact paths.** Every referenced path is EITHER (a) a repo-committed path the cold session can open, OR (b) an explicit reproduce-from-scratch instruction (the exact command / API shape / query that regenerates it). BANNED: tool-result temp paths, `/Users/*/.claude/projects/*/tool-results/*`, "files on disk from this session", "the captured pool above", "as pulled earlier" — these resolve to nothing in a fresh session. Grep-style self-check: any path containing `tool-results`, `/.claude/projects/`, or the phrases "this session"/"earlier"/"above" adjacent to a file reference is a FAIL until rewritten as (a) or (b).
2. **No conversation-only load-bearing facts.** Every fact the next session must act on is IN the continuation or in a committed repo file it explicitly names. BANNED: "as discussed", "per our decision", "the verdict we reached", "you'll remember" — the cold reader remembers nothing. Locked verdicts must point to committed audit/council files by path.
3. **Automation/loop state stated in-file.** If the continuation will be autofire-chained: state the arm/persist/kill-switch state, chain-depth posture, and what "clean ship" triggers the next leg — explicitly, in the file. A future-loop assumption that lives only in chat silently breaks the chain (the 2026-05-19 single-fire gap).
4. **The zero-memory reader test.** Read the continuation as if you have only it + the repo, nothing else. Could you reach the correct first action with **zero questions back**? If a cold reader would have to ask "where is X?" / "what was decided about Y?" / "does the loop continue?" — it FAILS; supply the answer in-file.
5. **Strategic-Continuity refusal (anti-drift — autofire-chained continuations).** An autofire-chained session has no human in the loop to catch strategic drift, and autofire itself has NO ROADMAP-alignment gate (it chains whatever canonical continuation exists). So the continuation MUST itself carry the brake. The §13 Strategic Alignment block MUST name EITHER (a) a specific current `ROADMAP.md` NOW/NEXT item this work advances (by item ID / NOW-lane entry — not "aligns with X" hand-waving), OR (b) an explicitly-still-relevant outstanding continuation it is a verified leg of (named by path, with a one-line "still relevant because…"). If NEITHER can be stated truthfully, the continuation MUST replace its "next action" with a hard stop: `STOP — no live ROADMAP item or still-relevant predecessor. Do NOT auto-proceed. Surface to the operator for re-prioritisation.` A continuation whose next scope is "figure out the next best thing" with no ROADMAP anchor is the canonical drift failure — it is BANNED from emitting an auto-proceed instruction; it stops and asks instead. (Composes with the runaway depth cap, currently 2: the cap bounds how many hops; this bounds whether each hop is still the right work.)

Record the gate result in the continuation's §14 verification block as a checklist line: `- [ ] Cold-Read Safety Gate passed (Step 1G — no session-scoped paths, no conversation-only facts, loop-state in-file, zero-memory-reader test, strategic-continuity anchor named OR hard-stop substituted)`.

**Failure precedent (2026-05-19)**: a hand-off referenced three captured data pools as "on disk in the session tool-results" (a path only the authoring session had) AND omitted that the autonomous loop was single-fire (a fact only in chat). Both were caught by a `/reduce-to-first-principles` audit *after* authoring — this gate moves the catch to *before emit*, every time, with no audit required.

---

## Step 1H — Doctrine-Currency Check (MANDATORY — runs after 1G, before emit)

Continuation prompts routinely cite project rule files, doctrine docs, ROADMAP lines, or memory entries to justify a recommended next action ("per X.md, the Y trap still lives at file:line"). The author has full conversational context AND treats the doctrine file as the source of truth. **Both assumptions can be wrong**: the doctrine file may have shipped before the code was fixed, and the code is authoritative — not the rule file describing the code. This gate forces a verification pass on every doctrine reference the continuation contains BEFORE the prompt is emitted to a cold reader.

This is the executable form of `.claude/rules/doctrine-currency-check.md`, applied at continuation-authoring time. That rule is passive ("triple-cite before propagating"); this step is the named, non-skippable gate that runs it.

**When this gate fires** — for every doctrine reference in the continuation that supports a NEGATIVE decision (recommended action assumes a problem still exists / a trap is still live / a feature is still missing / a function still has signature X / a column is still named Y). Positive citations (recommending the use of a documented pattern that is genuinely current) get a lighter touch unless the author is uncertain.

**The three-cite check** (per `doctrine-currency-check.md`):

1. **Read the cited section of the rule file.** Identify the specific claim — e.g., "the cast at line N silences typechecking".
2. **Read the cited code at file:line.** Does the live code still match the doctrine's description? If the doctrine names a line number, open that exact line. If the doctrine names a function or symbol, grep for it.
3. **If they disagree** → the doctrine is stale. The continuation MUST EITHER:
   - Restate the recommended action against the current code reality (NOT the stale doctrine), AND flag the doctrine as needing a separate update PR, OR
   - HALT the continuation emit and surface the disagreement to the operator before authoring further.

Banned alternative: silently emitting the continuation with the stale claim intact "because the rule file says so".

**Self-check** before emit — for every paragraph in the continuation that references a `.claude/rules/*.md` file, a `MEMORY.md` line, an architecture-doc claim, or a ROADMAP entry as evidence for a NEGATIVE recommendation: did you actually open the cited code / file referenced BY the doctrine, or did you just trust the doctrine's description? If "just trusted" — re-do that check now.

**Record** the gate result in the continuation's §14 verification block: `- [ ] Doctrine-Currency Check passed (Step 1H — every NEGATIVE doctrine reference was triple-cited against current code; staleness flagged and routed to separate update where found)`.

**Failure precedent (2026-05-20)**: a continuation revision cited a drawer-invariants rule file as evidence that a `.update(updates as any)` cast still lived at a named hook file:line — and used that "still-live trap" as the load-bearing reason for an entire systemic-mandate sub-plan, including a hand-off citation that "~15 latent type errors will surface when the cast is removed". A parallel chat reading the actual hook found the cast had been removed nearly a month earlier in a prior PR; the current hook exposed a typed parameter from generated Supabase types, carried a doc comment stating the original bug class was closed, and shipped a runtime detector for the snap-back failure mode the doctrine had described. The revision's first commit shipped with the stale claim; a correction commit was needed within minutes once the parallel chat surfaced the gap; a doctrine update PR was needed to mark the rule's trap section HISTORICAL. **All three commits would have been avoided** if this gate had run before emit. The author had cited `doctrine-currency-check.md` in the continuation's doctrine list while not applying it — a passive rule with no executing step.

---

## Step 2 — Generate the Continuation Prompt

Use the **14-Section Master Template** below (upgraded from 12). For shorter continuation types,
use only the relevant sections (marked with type indicators).

### File Naming Convention

```
{{output_dir}}/{{SCOPE}}-MASTER-CONTINUATION-{{YYYY-MM-DD}}.md
```

Examples:
- `continuations/REPORTS-ANALYTICS-UI-MASTER-CONTINUATION-2026-02-22.md`
- `continuations/FUEL-RECONCILIATION-PHASE-2-CONTINUATION-2026-02-22.md`
- `continuations/BUG-IC-TIMEOUT-FIX-CONTINUATION-2026-02-22.md`

---

## 14-Section Master Template

```markdown
# {{Title}} — Master Continuation Prompt

**Created:** {{YYYY-MM-DD}}
**Priority:** {{priority_ranking}} — {{client_impact_summary}}
**Status:** {{current_status_one_line}}
**ROADMAP Item:** {{#N}} ({{roadmap_lane}})

## CLASSIFICATION
- **Scope**: {{single-file | multi-file | cross-system | orchestration}}
- **Pattern**: {{CRUD | pipeline | state-machine | audit | transformation | meta-tooling}}
- **Complexity**: {{trivial | moderate | substantial | architectural}}
- **Execution**: {{single-session | sub-agents | agent-team | plan-then-execute}}
- **Layers**: {{database, workflows, frontend, backend, agents — whichever apply}}

---

## HOW TO USE THIS PROMPT — COLD-OPEN SESSION START

You are opening a fresh chat with zero memory of the prior session. Follow these steps in order.

### Step 0 — Feature branch in the one folder  ← REQUIRED for branch-modifying work

Single-folder is the default: one canonical clone, every job a feature branch *inside it* — no new folder, no worktree (see `.claude/rules/worktree-discipline.md`). Open a terminal in 📁 `{{repo_root_path}}` (the one canonical clone) and run:

```bash
git fetch origin main
# If the working tree has unrelated WIP, stash it first so the switch starts clean:
#   git stash push -u -m "wip before {{branch_name}}"
git switch -c {{branch_name}} origin/main   # feature branch IN the one folder

# Confirm starting state — expected predecessor commits on origin/main:
git log --oneline -3
# Expect:
#   {{predecessor_commit_sha}} {{predecessor_commit_title}}
#   ...
```

A separate worktree is the rare, explicitly justified **exception** — genuine simultaneous parallel work only (e.g. `/build-with-agent-team`). It is never the per-job default; the enforcement hook blocks unsanctioned `git worktree add`.

NEVER use a cloud-synced directory (iCloud / OneDrive / Dropbox / Documents/GitHub) — sync corrupts `.git` metadata mid-write. NEVER use a temp directory (`/tmp/*`) — tmpfs triggers git auto-lock. Use a real, non-synced working directory (e.g. `~/code/`). (Source: the project's worktree-discipline rule, if present.)

### Step 1 — Read system architecture + this prompt

1. Read 📄 `CLAUDE.md` first — it has system architecture (DO NOT re-read things stated there)
2. Read this prompt completely — it IS the context
3. Read any predecessor continuations or arc charters named in §RELATED CONTINUATIONS for unchanged sections to inherit

### Step 2 — Run §14 State Verification BEFORE writing any code

The verification block at §14 carries machine-checkable commands that confirm the post-predecessor ship and tell you if anything drifted. Run them as your first action — they take seconds and prevent multi-hour misdirection.

### Step 3 — Enter plan mode and produce an implementation plan

Use `EnterPlanMode`. The continuation is enough context to plan against — do NOT re-research what's already documented here. Target ONE PR per phase; subsequent phases are subsequent operator-triggered sessions unless the continuation says otherwise.

### Step 4 — Execute phase-by-phase with verification at each step

One PR per phase. Live-smoke after every deploy. Run the project's code-review gate on the staged diff before opening the PR.

---

## TABLE OF CONTENTS

1. [Strategic Context — Why This Matters](#1-strategic-context)
2. [Current State — What Exists](#2-current-state)
3. [Gap Analysis — What's Missing](#3-gap-analysis)
4. [Decision Criteria — Ambiguous Choices](#4-decision-criteria) ← NEW
5. [Where the Hard Part Is](#5-novelty-flags) ← NEW
6. [Frontend Component Map](#6-frontend-component-map)
7. [Backend Infrastructure Map](#7-backend-infrastructure-map)
8. [Database Infrastructure Map](#8-database-infrastructure-map)
9. [Workflow Context](#9-workflow-context)
10. [Project Status Context](#10-project-status-context)
11. [Design Principles & Constraints](#11-design-principles)
12. [Proposed Phase Plan](#12-proposed-phase-plan)
13. [Key Files to Read](#13-key-files-to-read)
14. [Verification — Machine-Checkable](#14-verification)

---

## 1. STRATEGIC CONTEXT
[ALL TYPES]

### The Vision
{{Why this work exists. Client value. Business problem being solved.}}

### Destination (success target)
{{If a DESTINATION.md exists at the repo root, cite its end-state + binary success test BY
POINTER (one-line echo, never a copy) so this cold-read / autofired session inherits the arc's
definition of done. E.g.: "Destination (see `DESTINATION.md`): <end-state one-liner> — pass
test: <binary test one-liner>". If absent, write: "Destination: none written for this arc (no
DESTINATION.md) — consider `/define-destination`." Per Step 1D.5.}}

### Why This Is Priority
{{Urgency drivers. What happens if delayed. Who is affected.}}

### How This Connects to the Bigger Picture
{{Table mapping this work to other system components/projects.}}

---

## 2. CURRENT STATE — WHAT EXISTS
[ALL TYPES]

### What Was Accomplished
{{Verified list of completed work with file paths, SQL applied, etc.}}

### What's Deployed & Working
{{Infrastructure, functions, components that are live and tested.}}

### What's NOT Working / Broken
{{Known issues, disabled features, stale content.}}

### DO NOT UNDO
{{Critical: list of changes from prior sessions that MUST be preserved.
The new session must not accidentally regress these.}}

---

## 3. GAP ANALYSIS — WHAT'S MISSING
[ALL TYPES except bug_fix]

### Critical Gaps (Must Fix)
{{Table: #, Gap, Impact, Effort}}

### Enhancement Gaps (Should Do)
{{Table: #, Gap, Impact, Effort}}

### Future Gaps (Could Do Later)
{{Table: #, Gap, Impact, Effort}}

---

## 4. DECISION CRITERIA — AMBIGUOUS CHOICES
[ALL TYPES — include ONLY if the new session faces decisions with multiple valid approaches]

For each ambiguous choice point the new session will face:
- **When {{scenario}}**: {{recommended action}} — because {{reason}}
- **When {{scenario}}**: {{recommended action}} — because {{reason}}

Only include decisions where Claude's default would be WRONG. If the right approach is
obvious from CLAUDE.md conventions, don't repeat it here.

---

## 5. WHERE THE HARD PART IS (NOVELTY FLAGS)
[ALL TYPES — prevents the new session from gold-plating boilerplate while rushing innovation]

**Novel** (concentrate design effort here):
{{What's genuinely new, complex, or risky about this work}}

**Standard** (don't over-engineer):
{{What's routine and should be done quickly without overthinking}}

---

## 6. FRONTEND COMPONENT MAP
[MASTER, PHASE_TRACKER if frontend involved]

### Route
{{Page route, where defined}}

### Main Page Structure
{{Component tree showing layout}}

### Component Details
{{Table: File, Lines, Purpose, Status}}

---

## 7. BACKEND INFRASTRUCTURE MAP
[MASTER, PHASE_TRACKER]

### Related RPCs
{{Table: RPC, Purpose, Key Params — ONLY those relevant to this work}}

### Edge Functions
{{Table: Function, Purpose, URL, Status}}

### External API Integrations
{{Table: Service, Purpose, Auth Method}}

---

## 8. DATABASE INFRASTRUCTURE MAP
[MASTER, PHASE_TRACKER]

### Tables Involved
{{Table: Name, Purpose, Row Count, Key Fields}}

### Views
{{Table: View, Purpose}}

### Recent Data State
{{Verified query results showing current data state — embed actual numbers}}

---

## 9. WORKFLOW CONTEXT
[If n8n/automation workflows are involved]

### Related Workflows
{{Table: ID, Name, Purpose, Status}}

### Workflow Dependencies
{{How workflows connect to this work}}

---

## 10. PROJECT STATUS CONTEXT
[MASTER]

### Current Progress
{{Table: Project, Progress %, Notes}}

### How This Work Impacts Progress
{{Which project percentages move when this work is completed}}

---

## 11. DESIGN PRINCIPLES & CONSTRAINTS
[ALL TYPES]

### Must Follow
{{Numbered list of non-negotiable constraints}}

### Should Follow
{{Best practices and preferences}}

### Must NOT Do
{{Anti-patterns, forbidden approaches, safety rails}}

### Schema Gotchas
{{Column name surprises, type casting issues, known quirks}}

---

## 12. PROPOSED PHASE PLAN
[ALL TYPES]

### Phase 1: {{Name}} ({{Effort}}, {{Impact}})
**Goal:** {{One-line goal}}
{{Numbered steps}}
**Verify:** {{How to confirm this phase is complete}}

### Phase 2: {{Name}} ({{Effort}}, {{Impact}})
...

### Research Agents Recommended
{{If complex research is needed before implementation, suggest agents:}}
- Agent 1: {{Purpose}} — {{What it researches}}
- Agent 2: {{Purpose}} — {{What it researches}}

### Team of Agents Recommended
{{If parallel implementation would be effective, suggest team structure:}}
- Lead: {{Orchestrator role}}
- Agent A: {{Specialization}} — {{What it implements}}
- Agent B: {{Specialization}} — {{What it implements}}

---

## 13. KEY FILES TO READ
[ALL TYPES]

### Must Read (Before Planning)
{{Table: File, Why — files the new session MUST read before starting}}

### Should Read (During Implementation)
{{Table: File, Why — reference files for implementation details}}

### Reference (As Needed)
{{Table: File, Why — deep-dive references}}

---

## 14. VERIFICATION — MACHINE-CHECKABLE
[ALL TYPES — THIS IS THE HIGHEST LEVERAGE SECTION. NEVER OMIT.]

Every verification step MUST be a command or query the new session can run.
"It should work" is NOT verification. A bash command or SQL query IS.

### Cold-Read Safety (Step 1G — author self-certifies before emit; cold session sees this line)
- [ ] Cold-Read Safety Gate passed: no session-scoped artefact paths (no `tool-results`/`/.claude/projects/`/"this session"/"above" file refs); no conversation-only load-bearing facts (locked verdicts point to committed files by path); automation/loop state (autofire arm/persist/kill-switch/chain trigger) stated in-file if autofire-chained; zero-memory-reader test (fresh session, only this file + repo, correct first action, zero questions back); **strategic-continuity** — §13 names a live ROADMAP NOW/NEXT item OR an explicitly-still-relevant outstanding continuation, ELSE the next-action is replaced with a hard STOP-and-surface (no off-roadmap auto-proceed).

### Doctrine-Currency (Step 1H — author self-certifies before emit; cold session sees this line)
- [ ] Doctrine-Currency Check passed: every NEGATIVE doctrine reference in the continuation (rule file / memory entry / architecture doc / ROADMAP line cited as evidence a problem still exists / a trap is still live / a feature is still missing) was triple-cited against current code — the actual cited file:line was opened, not just the doctrine's description trusted. Any stale claim found was either restated against current code reality (with a separate doctrine-update PR queued) or surfaced to the operator as a halt. No "the rule file says so therefore it is so" propagation.

### State Verification (Run FIRST to confirm starting point)
- [ ] `{{SQL query or command that confirms current DB state}}`
- [ ] `{{File existence check: ls -la path/to/expected/file}}`
- [ ] `{{RPC call that confirms function exists and returns expected shape}}`

### Phase Verification (Run AFTER each phase)
- [ ] Phase 1: `{{command that confirms phase 1 output exists and is correct}}`
- [ ] Phase 2: `{{command that confirms phase 2 output exists and is correct}}`

### Completion Verification (Run LAST)
- [ ] `{{end-to-end test command or query that confirms the whole thing works}}`
- [ ] `{{negative check — grep for thing that should NOT exist: grep -r "{{anti_pattern}}" path/}}`
- [ ] {{Client-visible outcome: what the user/client should see when this is done}}

### Sub-Agent Context (if execution_scale includes agents)
When spawning sub-agents from this continuation, inject these context items
(sub-agents inherit NOTHING from parent — no CLAUDE.md, no skills, no conversation):
- Classification block from Section 0
- DO NOT UNDO list from Section 2
- Decision criteria from Section 4
- Relevant schema gotchas from Section 11

---

## EXECUTION NOTES

- **Start with Phase 1** — {{why this ordering}}
- **Use `EnterPlanMode`** before starting any phase to verify the approach
- **Run `/clientprojectupdate`** after completing each phase to log progress
- {{Project-specific execution guidance}}
- **Don't over-engineer** — ship iteratively, improve later

---

*Generated: {{YYYY-MM-DD}} | Context: {{work_scope}}*
*Generator: `/Master-Continuation-Prompt` skill v2.1*
```

---

## Step 3 — Quality Validation

Before presenting to the user, validate the continuation prompt against these criteria:

### Must Pass (Hard Requirements)

```
[ ] Section 0 exists: WHY in business/client terms before any technical detail
[ ] State is unambiguous: every item marked DONE, NOT STARTED, or IN PROGRESS
[ ] Embedded artifacts: SQL, file paths, component trees — not vague references
[ ] DO NOT UNDO section present (if prior session made changes)
[ ] Schema gotchas documented (if database involved)
[ ] Verification queries at the end (confirm DB state without re-researching)
[ ] ROADMAP item referenced (strategic alignment explicit)
[ ] File paths are real (verified via glob/read, not assumed)
[ ] RPC signatures verified (parameters confirmed via database, not from memory)
[ ] No stale data (all numbers come from current queries, not prior sessions)
[ ] Framing-audit verdict recorded (Step 1D.5) for load-bearing handoffs — in Section 1 or Section 4
[ ] Destination pointer recorded (Step 1D.5) — if `DESTINATION.md` exists at repo root, its end-state + binary test are cited BY POINTER in Section 1 (one-line echo, not a copy); if absent, Section 1 states "Destination: none written for this arc"
[ ] HOW TO USE block carries the Step 0 single-folder setup with CONCRETE commands (git fetch + git switch -c {branch} origin/main IN the one folder + optional stash-first note for dirty WIP + git log -3 sanity check). Generic "set up a branch" without commands FAILS this gate — the cold-open chat must reach §14 State Verification with zero questions back. The block MUST NOT instruct `git worktree add` (single-folder is the default per `worktree-discipline.md`; a worktree is the rare parallel-work exception only). Placeholders ({{branch_name}}, {{predecessor_commit_sha}}, {{predecessor_commit_title}}, {{repo_root_path}}) MUST be substituted with concrete values for the specific handoff. (Anti-pattern: emitting the template verbatim with placeholders unresolved, OR mandating a worktree.)
[ ] Paste-ready MICRO prompt printed in chat (Step 4.5) — fenced, copyable, carries the committed continuation file reference + the "stay in your own isolated checkout" instruction + the ORIGIN line (live `git branch --show-current` + `git rev-parse --show-toplevel` of the generating session, never guessed). Missing micro prompt OR an un-substituted ORIGIN placeholder FAILS this gate.
```

### Should Pass (Quality Markers)

```
[ ] Gap analysis prioritized by IMPACT/EFFORT ratio
[ ] Phase plan has clear verification criteria per phase
[ ] Key files table includes BOTH "must read" and "should read"
[ ] Research/team agent recommendations included where appropriate
[ ] Design constraints include anti-patterns (what NOT to do)
[ ] Continuation is self-contained (new session doesn't need to read other continuations)
[ ] Total length appropriate for type (master: 300-600, phase: 150-300, bug: 80-150)
```

### Template Portability Check (For Template Repo)

```
[ ] No hardcoded project IDs, URLs, or credentials
[ ] MCP tool references use {{db_tool}}, {{workflow_tool}} placeholders
[ ] Project-specific table names in examples only, not in core logic
[ ] Continuation types are domain-agnostic
[ ] Works for any tech stack (not just Supabase/n8n/React)
```

---

## Step 4 — Present & Confirm

Present to user:

```
Master Continuation Prompt generated:
  File: {{output_path}}
  Type: {{continuation_type}}
  Scope: {{work_scope}}
  Sections: {{N}}/14
  Length: ~{{lines}} lines

Layers covered: {{checked_layers}}
Phases proposed: {{N}}
Research agents suggested: {{yes/no}} ({{count}})
Team agents suggested: {{yes/no}} ({{count}})

The new session should:
1. Read CLAUDE.md
2. Read this continuation prompt
3. Enter plan mode
4. Execute phase-by-phase

Open the file to review?
```

---

## Step 4.5 — ALWAYS Emit a Paste-Ready Micro Prompt (MANDATORY)

Every `/Master-Continuation-Prompt` run MUST end by printing — **in the chat, in a fenced block the operator can copy in one action** — a short MICRO prompt to paste into a NEW chat. This is non-negotiable and runs on every invocation, regardless of continuation type. The full continuation file is the briefing; this micro prompt is the *trigger* that points a fresh chat at it without the operator hand-writing anything.

The micro prompt has exactly three load-bearing jobs:

1. **Carry the file reference** — the committed path to the continuation file (so the new chat reads the full context).
2. **Tell the new chat to stay in its OWN isolated checkout** — never share a working tree with the session that generated the prompt.
3. **Name the worktree/branch this prompt came from** — so the new chat knows what is held and does not collide with it.

### Capture the origin at generation time (REQUIRED — do this before printing the block)

Run these in the generating session's working directory and substitute the results verbatim into the template:

```bash
ORIGIN_BRANCH=$(git branch --show-current)
ORIGIN_PATH=$(git rev-parse --show-toplevel)
```

Never hard-code or guess these — they are the live identity of the session emitting the hand-off. If `ORIGIN_BRANCH` is empty (detached HEAD), substitute the short SHA from `git rev-parse --short HEAD` and say "(detached HEAD)".

### The micro-prompt template (print this, filled in)

```
[PASTE INTO A NEW CHAT]

Continue: {{Title}}. Read 📄 continuations/{{filename}} — it is the full context + plan; do not re-research what it already documents.

Work in your OWN isolated checkout — do NOT share a working tree with the session that generated this:
- If the one canonical folder ({{repo_root_path}}) is FREE → take a fresh feature branch in it: git switch -c {{suggested_branch}} origin/main
- If it is HELD by another session (see the origin line below, or any parallel chat) → use your OWN sanctioned worktree off origin/main:
    ALLOW_PARALLEL_WORKTREE=1 git worktree add ~/code/{{repo_stem}}-{{slug}} origin/main
  …and remove it when done (git worktree remove <path> && git worktree prune).

⚠️ ORIGIN: this prompt was generated from branch `{{ORIGIN_BRANCH}}` in {{ORIGIN_PATH}}. Do NOT switch onto that branch and do NOT touch that working tree — it belongs to the generating session. Pick a different branch name and a different folder/worktree.

First action: {{continuation_first_action}} (then run the continuation's §14 State Verification before any code).
```

### Rules for the micro prompt
- It is printed to chat for the operator to copy — it is NOT written to a file (the *continuation* is the file; this is the paste-trigger). If the continuation type ALSO warrants a committed micro file (multi-session programmes often do), that is a separate artefact under `continuations/…-MICRO-…md`; this step's job is the in-chat paste block, always.
- `{{slug}}` and `{{suggested_branch}}` derive from the scope (kebab-case); keep them distinct from `{{ORIGIN_BRANCH}}` so the new chat cannot accidentally reuse the origin's branch.
- Single-folder is still the default (see `.claude/rules/worktree-discipline.md`): the feature-branch-in-the-one-folder path is listed FIRST; the sanctioned worktree is the contended-folder exception. This step does NOT mandate a worktree for every chat — it tells the new chat to stay ISOLATED from the origin, by whichever of the two paths fits the folder's state.
- Keep it short — a screenful. The full detail lives in the continuation file; this block only needs the file reference + the isolation instruction + the origin line.

---

## Step 5 — Post-Generation Actions (MANDATORY)

After the continuation prompt is saved to disk:

### 5A. Implementation Status Frontmatter (REQUIRED)

Every continuation file MUST include YAML-style frontmatter at the top with an explicit `impl_status` field:

```markdown
<!-- impl_status: pending -->
<!-- impl_session: (none yet) -->
<!-- impl_completed_date: -->
```

Status values: `pending` → `in_progress` → `completed` | `superseded` | `blocked`

**When a session picks up a continuation**: Change `pending` → `in_progress` and set `impl_session` to the current date.
**When the work is done**: Change `in_progress` → `completed` and set `impl_completed_date`.
**When a newer continuation replaces this one**: Change to `superseded` and note which file supersedes it.

The daily-plan-generator reads these fields instead of heuristically guessing from git history.

**REQUIRED IF programme detection (Step 0 §5) fired** — two additional fields:

```markdown
<!-- programme_name: <programme-slug> -->
<!-- programme_contract: .claude/rules/<programme-slug>-alignment.md -->
<!-- programme_session: <session-id, e.g. "session-8b"> -->
```

The next session loading this continuation will see the contract pointer in frontmatter AND in §11 Must-Follow AND in §14 State Verification — three independent surfaces enforcing the gate. The daily-plan-generator + autovibe skills can read `programme_contract` to auto-load the alignment rule before substantive work begins. If the programme contract file is absent from disk at load time, §14's first verification command halts the session — better to halt than drift.

**OPTIONAL — goal-ledger stamp (Goal-Ledger Build Programme).** If this continuation
hands off a goal-ledger thread (the work was opened via `.claude/skills/_shared/goals.sh`,
or it descends from a prior continuation that carried a `goal_id`), stamp the goal_id of
the ledger entry this continuation is handing off:

```markdown
<!-- goal_id: <slug>-<8hex> -->
```

This single line is the durable cross-session link. It survives compaction (it lives in
the file, not in conversation context), so the next session's reaper (§5C) can close this
entry by reading the line off disk even when the goal_id is long gone from the live
transcript. If `.claude/goals/` does not exist or this work is not goal-ledger-managed,
omit the line — it is never fabricated.

### 5B. Auto-Publish to Origin (Branch-Protection Aware — REQUIRED)

After writing the continuation file, publish it via whichever path the repo's protection allows. **Never assume direct-push-to-main works** — bash hooks and GitHub branch protection commonly block it.

**Step 1 — Detect repo state (once, before committing):**

```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || echo "main")
CURRENT_BRANCH=$(git branch --show-current)
# Protection check: returns 0 if protected, non-zero if not
gh api "repos/:owner/:repo/branches/${DEFAULT_BRANCH}/protection" --silent 2>&1 | grep -qv "Branch not protected" && PROTECTED=yes || PROTECTED=no
```

**Step 2 — Pick the path:**

| Condition | Action |
|-----------|--------|
| `PROTECTED=no` AND `CURRENT_BRANCH == DEFAULT_BRANCH` | Direct commit + push to default — fastest path |
| `PROTECTED=yes` OR local bash hook blocks direct-push-to-main | Create `docs/continuation-{slug}` branch, commit, push, open PR |
| `CURRENT_BRANCH != DEFAULT_BRANCH` | Commit to current branch — it's already a feature branch, no extra ceremony |

**Step 3 — Narrow `git add <pathspec>` only** (protects user's unrelated dirty-tree work):

```bash
git add continuations/{{filename}}
git commit continuations/{{filename}} -m "docs: continuation — {{scope}} ({{type}}, impl_status: pending)"
```

**Step 4 — Publish:**

```bash
# Path A: unprotected + on default branch
git push origin "$DEFAULT_BRANCH"

# Path B: protected OR hook blocks push-to-main
SLUG=$(echo "{{scope}}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
git checkout -b "docs/continuation-${SLUG}"
git push -u origin "docs/continuation-${SLUG}"
gh pr create --title "docs: continuation — {{scope}}" \
  --body "Continuation prompt for {{scope}}. impl_status: pending. Next session picks this up from continuations/{{filename}}."
```

**Why this is mandatory**: Justin works across multiple Macs. A continuation that exists only on one Mac's working tree is invisible to sessions on other Macs and to the daily plan. Publishing to origin (via either direct push OR PR merge) guarantees:
- All Macs see the continuation after `git pull`
- The daily plan on ANY Mac can surface it
- Implementation status is tracked in version control
- Nothing gets left unfinished because it was "on the other laptop"

**If publish fails for ANY reason**: the commit stays local. Report the exact failure + remediation command to the user — do NOT silently drop the work.

**Never use `--admin` to bypass branch protection for continuation commits.** The admin-merge cascade is reserved for time-critical fixes against pre-existing red CI; continuations are by definition not time-critical.

### 5C. Cross-Reference + Supersede

- If this continuation supersedes an older one, update the old file's frontmatter to `<!-- impl_status: superseded -->` and commit that change too
- Note the supersession in the new file header

**Goal-ledger reaper handshake (Goal-Ledger Build Programme — runs when this continuation
supersedes a prior one AND `.claude/goals/` exists).** A goal-ledger thread is a chain of
entries linked by `parent_goal_id`; each entry must be closed when its continuation is
superseded, or phantom `status: active` entries accumulate and fire spurious collision
blocks downstream. Before writing the new ledger entry, run the handshake **in this order**:

1. **Find the prior goal_id (compaction-safe).** Read it from the *prior* continuation
   file's frontmatter on disk — `grep -oE 'goal_id: [a-z0-9-]+' <prior-file>` — NOT from
   conversation context (which may have compacted it away). No prior file, or no
   `goal_id:` line in it → there is no entry to reap: log "no prior ledger entry" and skip
   to step 4 (this is the first goal in the thread; never fail the handoff over it).
2. **Close the prior entry.** Default close is `abandon` (the safe default — never falsely
   stamp a half-done goal `achieved`):
   `bash .claude/skills/_shared/goals.sh reap <prior_goal_id>`
   ONLY if §5D roadmap-writeback verified the prior goal's milestone as actually met
   (a verified `[x]` with an evidence pointer, not artefact-existence) use instead:
   `bash .claude/skills/_shared/goals.sh achieve <prior_goal_id>` — note `achieve`
   hard-refuses (exit 3) without a `roadmap_ref`; on a non-zero exit OTHER than the
   idempotent no-op, fall back to `reap`. Both transitions are idempotent (a second call
   is a no-op), so re-running the handshake is safe. **Check the exit code** — if `reap`
   itself returns non-zero (5 = lock stuck after retry; 6 = salvage-write failed), do NOT
   proceed to step 3 silently: surface the failure in the handoff and stop (a phantom
   `active` entry is the exact failure this handshake exists to prevent).
3. **Open the new entry, linked to the prior one:**
   `NEW_ID=$(bash .claude/skills/_shared/goals.sh new "<slug>" "<intended_end>" "continuations/<this-file>" "<prior_goal_id-or-empty>" "<declared_touches_json-or-[]>")`
   - 4th arg = `parent_goal_id` (empty for a root thread) → the new entry inherits the
     prior chain's `constraints`.
   - 5th arg (optional) = a JSON array of the files this continuation expects to touch
     (`["src/a.ts","src/b.ts"]`); pass `[]` if unknown. This populates `declared_touches`,
     which the collision gate reads — an empty array there means the gate cannot
     see this thread, so pass real paths when known.
   - **Guard: `[ -n "$NEW_ID" ] || { surface "goals.sh new failed — ledger entry NOT
     created"; stop the handshake }`**. An empty `$NEW_ID` (a `new` that failed and
     returned non-zero) must NOT be stamped as `<!-- goal_id: -->` — that silently breaks
     the chain link and leaves the prior entry the last one standing.
   - On success, stamp `<!-- goal_id: $NEW_ID -->` into THIS file's §5A frontmatter (the
     §5A optional block).

If `.claude/goals/` does not exist (the goal-ledger is not provisioned in this repo), skip
the entire handshake — the continuation is still valid; the ledger is additive.

### 5D. Downstream Updates

1. **Roadmap write-back is part of authoring — NOT an optional later step.** For every roadmap item this continuation relates to, apply the canonical write-back contract (`@.claude/skills/_shared/roadmap-writeback-phase.md`): tick `[x]` ONLY with a verified-verdict evidence pointer atomically (W2/W3); anything done-but-unverifiable → `[~]` with a machine-readable reason tag (W4); anything still open stays `[ ]`. Never a bare `[x]`, and never a `[x]` on artefact-existence alone (an artefact that exists but carries no verdict is NOT proof). A continuation that touched roadmap-relevant work but left the roadmap untouched is an INCOMPLETE continuation.
2. **Emit the machine-readable `ROADMAP-REFS:` block** into the continuation file — one line per referenced item: `ROADMAP-REFS: <item-slug>=<0-100>` (completeness this continuation asserts). This is the authoritative input any continuation-completeness scorer consumes; prose inference is only a labelled low-confidence fallback (prevents adversarial-prose mis-scoring — e.g. completion vocabulary inside an anti-pattern example).
3. **Update memory/MEMORY.md** — If significant discoveries were made, persist them
4. **Suggest next actions:**
   - "Start a new session and paste this prompt"
   - "Or run `/daily-plan` tomorrow — it will pick up this continuation automatically"

---

## Anti-Patterns (What Makes a BAD Continuation Prompt)

| Anti-Pattern | Why It's Bad | What to Do Instead |
|--------------|-------------|-------------------|
| Missing Section 0 (WHY) | New session has no strategic context, makes wrong trade-offs | Always start with client value and business rationale |
| Ambiguous status ("IN PROGRESS") | Can't tell which sub-items are done vs remaining | Use checkboxes, status columns, explicit DONE/NOT STARTED markers |
| No embedded artifacts | Forces next session to re-research everything | Embed SQL results, component trees, RPC signatures directly |
| Missing DO NOT UNDO | Next session accidentally reverts prior work | List every change that must be preserved |
| No schema gotchas | Next session hits same column-name bugs you already debugged | Document every surprise (wrong column names, type mismatches) |
| Vague file references | "The component file" instead of exact path | Always use full relative paths |
| Stale numbers | Using counts/metrics from prior sessions instead of fresh queries | Always query current state during generation |
| No verification queries | Next session can't confirm starting state | Include SQL/commands to verify current state |
| Too long (>800 lines) | Context window waste, diminishing returns | Keep to type-appropriate length, use "Key Files to Read" for deep dives |
| Too short (<50 lines) | Missing critical context, new session will flounder | Better to over-document than under-document |
| Authored without roadmap write-back | Work captured in a continuation while the roadmap stays silently stale; the next session re-plans done work | Write-back is part of Step 5, not a remembered later step. Tick related items (verified-verdict evidence only) + emit the `ROADMAP-REFS:` block before the continuation is "done" |
| `[x]` ticked on a pointer that merely exists | An artefact can exist and carry no verdict (a blank template, an empty review file) — ticking it "done" is a false-completion that poisons downstream decisions | TYPE the evidence and extract a verdict (canonical W2). No verdict → `[~] (evidence-failed: <kind>)`, never `[x]` |

---

## Integration with Session Lifecycle

```
SESSION START
  └─ /prime or /daily-plan
       └─ Reads existing continuations/ as input
            └─ Prioritizes work based on continuation state

SESSION WORK
  └─ Implementation, debugging, research
       └─ Progress tracked via todo list

SESSION END
  └─ /Master-Continuation-Prompt  ← THIS SKILL
       └─ Generates continuation for next session
  └─ /reflect
       └─ Captures learnings as skills/expertise
  └─ /clientprojectupdate
       └─ Updates client-facing project status
```

---

## Adapting for Different Project Types

This skill is designed to be **project-agnostic**. When used in different projects:

| Project Element | This Project (Nirvana) | Generic Equivalent |
|----------------|----------------------|-------------------|
| Database tool | `mcp__supabase-nirvana__execute_sql` | `{{db_tool}}` — any database MCP or CLI |
| Workflow tool | `mcp__n8n-mcp-yourinstance__*` | `{{workflow_tool}}` — any automation platform |
| Frontend | Lovable.dev (React/Vite) | `{{frontend_framework}}` — any frontend |
| Backend | Supabase Edge Functions | `{{backend_platform}}` — any backend |
| Messaging | Wassenger (WhatsApp) | `{{messaging_platform}}` — any comms channel |
| Roadmap file | `ROADMAP.md` | `ROADMAP.md` (convention) |
| Project instructions | `CLAUDE.md` | `CLAUDE.md` (convention) |
| Memory | `memory/MEMORY.md` | `memory/MEMORY.md` (convention) |

The 14-section template works for ANY software project. Sections 6-9 adapt to whatever
layers the project uses. If a project has no workflows, skip Section 9. If no frontend,
skip Section 6.

---

*Skill Version: 2.1 | Updated 2026-05-16 — roadmap write-back is part of Step 5 authoring (canonical contract, verified-verdict evidence not pointer-existence, `ROADMAP-REFS:` block) + 2 anti-pattern rows. Composes with `.claude/skills/_shared/roadmap-writeback-phase.md`.*
*Skill Version: 2.0 — Master Continuation Prompt Generator (prompt-forge principles applied)*
