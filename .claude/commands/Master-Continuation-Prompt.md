---
description: Generate a master continuation prompt for a new session to carry forward all context, state, and strategic alignment from the current session's work.
---

# /Master-Continuation-Prompt

Generate an enterprise-grade continuation prompt that enables a new Claude Code session
to seamlessly continue this session's work at the highest standards.

**Invokes**: `master-continuation-prompt` skill

---

## What Happens

1. **Analyze** current session — what was done, what remains, what was discovered
2. **Research** all related system artifacts (architecture, DB, workflows, frontend, backend)
3. **Synthesize** a self-contained continuation prompt document
4. **Validate** against quality checklist (no stale data, no missing sections)
5. **Output** to `continuations/` directory with standardized naming

---

## Instructions

You are now generating a **master continuation prompt**. Follow the `master-continuation-prompt` skill at `.claude/skills/master-continuation-prompt/SKILL.md` precisely.

### Phase 1: Determine Scope

Ask yourself (do NOT ask the user — infer from conversation):

1. **What was the primary work this session?** — Scan the conversation for the main task/feature
2. **What layers were touched?** — Database, workflows, frontend, backend, agents, edge functions
3. **What type of continuation?** — master | phase_tracker | bug_fix | planning_only
4. **What ROADMAP items does this align with?** — Check `ROADMAP.md`

If the scope is ambiguous or multiple workstreams were touched, ask the user which
workstream to generate the continuation for.

### Phase 2: Deep Research

For EACH layer in the blast radius, gather verified current state:

**Database** (if involved):
- Query relevant tables for row counts, recent data, schema details
- Verify RPC signatures and parameters (don't rely on memory)
- Check for relevant views, materialized views, pg_cron jobs

**Frontend** (if involved):
- Glob for related component files
- Read main page/component structure
- Map the component tree and route

**Backend/Edge Functions** (if involved):
- Read edge function source code
- Verify deployed function capabilities
- Check auth patterns

**Workflows** (if involved):
- Query workflow structure (minimal mode first)
- Map relevant workflow IDs and connections
- Check execution history for recent issues

**Memory & Strategic Context**:
- Read `ROADMAP.md` for strategic alignment
- Read `memory/MEMORY.md` for cross-session knowledge
- Check recent `continuations/` for overlap (avoid duplication)
- Read recent daily plans if they exist

### Phase 3: Generate the Continuation

Use the **12-Section Master Template** from the skill file. Key requirements:

1. **Section 1 (Strategic Context)** — MUST explain WHY in business/client terms
2. **Section 2 (Current State)** — MUST include a DO NOT UNDO subsection
3. **Section 3 (Gap Analysis)** — MUST be prioritized by IMPACT/EFFORT ratio
4. **Section 9 (Constraints)** — MUST include schema gotchas and anti-patterns
5. **Section 10 (Phase Plan)** — MUST include research/team agent recommendations if warranted
6. **Section 12 (Verification)** — MUST have testable, specific verification steps

### Phase 4: Quality Validation

Before saving, verify:

```
HARD REQUIREMENTS:
[ ] WHY section exists with client/business rationale
[ ] Every item has unambiguous status (DONE / NOT STARTED / IN PROGRESS)
[ ] Artifacts embedded (SQL, file paths, component trees)
[ ] DO NOT UNDO section present
[ ] Schema gotchas documented
[ ] Verification queries included
[ ] ROADMAP item referenced
[ ] File paths verified (not assumed)
[ ] RPC signatures verified (from database, not memory)
[ ] Numbers are current (freshly queried)
```

### Phase 5: Present & Suggest Next Actions

After generating:

1. Show the file path and a summary (type, sections, length, layers covered)
2. Suggest: "Start a new session and paste this prompt" or "Run `/daily-plan` tomorrow"
3. Offer to update `ROADMAP.md` if the continuation represents a milestone
4. Offer to run `/clientprojectupdate` if client-visible work was completed
5. Offer to update `memory/MEMORY.md` if significant discoveries were made

---

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `[scope]` | Override the work scope (e.g., "reports", "fuel pipeline") | Auto-detected from conversation |
| `--type` | Continuation type: `master`, `phase`, `bug`, `planning` | `master` |
| `--minimal` | Generate a shorter continuation (skip sections 4-8) | `false` |

---

## Usage Examples

```
/Master-Continuation-Prompt
```
Auto-detects scope and type from conversation context.

```
/Master-Continuation-Prompt reports-analytics --type master
```
Explicitly sets scope to "reports-analytics" with master type.

```
/Master-Continuation-Prompt idle-nudge --type phase
```
Phase tracker for idle nudge system work.

```
/Master-Continuation-Prompt --minimal
```
Short continuation with just strategic context, state, gaps, and phase plan.

---

## Output

**File**: `continuations/{{SCOPE}}-MASTER-CONTINUATION-{{YYYY-MM-DD}}.md`

**Naming examples**:
- `continuations/REPORTS-ANALYTICS-UI-MASTER-CONTINUATION-2026-02-22.md`
- `continuations/IDLE-NUDGE-PHASE-3-CONTINUATION-2026-02-22.md`
- `continuations/BUG-IC-TIMEOUT-FIX-CONTINUATION-2026-02-22.md`

---

## The New Session's Mandate

The continuation prompt instructs the new session to:

1. Read `CLAUDE.md` for full system architecture
2. Read the continuation prompt completely — it IS the context
3. Analyze and plan at the **highest standards of the niche** — enterprise-exceeding quality
4. Consider all directly AND indirectly related aspects of prior work
5. Plan for the **highest and best use** of available inputs
6. Produce a **master-level implementation plan** with laser precision
7. Suggest **research agents** if deep investigation is needed before implementation
8. Suggest **team of agents** if parallel implementation would be effective
9. Create its OWN continuation prompt for the NEXT session after it completes

---

## Session Lifecycle Position

```
SESSION START
  └─ /prime or /daily-plan (reads continuations as input)

SESSION WORK
  └─ Implementation, debugging, research

SESSION END
  └─ /Master-Continuation-Prompt  ← YOU ARE HERE
  └─ /reflect (captures learnings)
  └─ /clientprojectupdate (updates client board)
```

---

## Related Commands

| Command | Relationship |
|---------|-------------|
| `/daily-plan` | Consumes continuation files as planning input |
| `/prime` | Lighter context loading at session start |
| `/reflect` | Captures session learnings (complementary to this) |
| `/clientprojectupdate` | Updates client-facing status board |
| `/compress-roadmap` | Archives completed ROADMAP items |

---

*Skill: `master-continuation-prompt` v1.0 | Command created: 2026-02-22*
