---
description: "Build with Agent Teams — parallel Claude instances, contract-first, NSM-aligned, full pre-flight"
arguments:
  - name: plan-path
    description: "Path to your plan markdown file"
    required: true
  - name: num-agents
    description: "Number of agents (2-4). If omitted, auto-sized from plan component count."
    required: false
---

# Build with Agent Team

## Skill Location

- **Project**: `.claude/skills/build-with-agent-team/README.md`
- **Global**: `~/.claude/skills/build-with-agent-team/README.md`

Read the full skill doc before proceeding — it contains the complete protocol including Phase 0 pre-flight, auto-sizing heuristic, ROADMAP context wrapper, Phase 5 post-implementation, and hook inheritance notes.

---

## Phase 0: Pre-flight (MANDATORY — run before spawning ANY agent)

Work through all 5 checks in order. Do not skip.

### 1. Prerequisites
```bash
tmux -V          # must succeed
# Verify settings.json has CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"
```
If either fails: surface the fix and stop. Agent teams cannot run without both.

### 2. NSM / ROADMAP Alignment Gate
Read `ROADMAP.md`. Check if the plan's top-level goal maps to a NOW or NEXT lane item.

- **NOW or NEXT**: proceed silently.
- **LATER lane**: surface advisory warning:
  ```
  ⚠️  This plan targets a LATER lane item.
      Current NOW: {list NOW items}
      Proceed anyway? (y/n)
  ```
  Never block — user decides.

### 3. Planning-Protocol Gate
Did the plan come from a plan-mode session using the planning-protocol?

If **yes** (plan file is in `.claude/plans/` or was explicitly created via plan mode): proceed.

If **no**: run this 3-question inline blast radius check before spawning:
```
Q1: Which existing DB tables/RPCs does this plan touch? (check CLAUDE.md Key Tables)
Q2: Which existing views or edge functions depend on those tables?
Q3: Are there any existing implementations in the codebase that this overlaps with?
```
Surface findings. If conflicts found, raise them for user decision before proceeding.

### 4. Memory / Conflict Check
Scan CLAUDE.md Key Tables + MEMORY.md:
- Does any component in the plan already exist? (table, RPC, component name)
- Would any new table/RPC duplicate an existing one?

Surface any conflicts. Prevents building over or alongside existing work.

### 5. Cost Estimate Gate
Calculate and surface before spawning:
```
📊 Estimated footprint: {N} agents × ~{M} turns each
   Subagents (Task tool) are cheaper for isolated, single-component tasks.
   Agent teams add value when components must communicate and agree on contracts.
   Proceed with agent team? (y/n)
```

---

## Phase 1: Auto-Sizing (when num-agents omitted)

Count distinct component layers in the plan:

| Component count | Agents |
|---|---|
| 1-2 | 2 (lead + 1 specialist) |
| 3-4 | 3 (lead + 2 specialists) |
| 5+ | 4 max (lead + 3 specialists) |

Surface the sizing: "Auto-sized to {N} agents based on {M} component layers. Override? (y/number)"

---

## Phase 2: Spawn with ROADMAP Context Wrapper

Read the plan at `$ARGUMENTS.plan-path`. Determine agent roles from the plan's component layers.

**EVERY sub-agent's initial message MUST include this block** (before role-specific instructions):

```
ROADMAP CONTEXT:
- Building: {goal from plan, 1 line}
- Lane: {NOW / NEXT / LATER — from ROADMAP check above}
- NSM impact: {which NSM component this moves, estimated delta}
- Constraint: must not disturb {adjacent system from CLAUDE.md / conflict check}
- Existing at: {relevant file:line from CLAUDE.md — "greenfield" if none}
- Build to: minimum viable — no features beyond acceptance criteria in this plan
```

---

## Phase 3–4: Contract-First Build

Coordinate per the skill README:
- DB Agent → Backend Agent (with verified DB contract)
- Backend Agent → Frontend Agent (with verified API contract)
- Lead runs E2E validation after all agents complete

Ensure agents communicate and challenge each other's contracts before implementing.

---

## Phase 5: Post-Implementation Protocol (MANDATORY after E2E passes)

1. **Update CLAUDE.md** — add new tables/RPCs/components to Current Status / Key Tables
2. **Update ROADMAP.md** — mark item complete, move to COMPLETED section
3. **Write build log** to `.claude/sessions/agent-team-build-{YYYY-MM-DD}.md`:
   ```
   ## {HH:MM} — AGENT [database]: {what was built}
   ## {HH:MM} — AGENT [backend]: {what was built}
   ## {HH:MM} — AGENT [frontend]: {what was built}
   ## {HH:MM} — LEAD [e2e]: validation passed / issues found
   ```
4. **Set client flag** — if client-visible, append `CLIENTUPDATE_PENDING=true` to `.claude/sessions/session-state.env`
5. **Surface completion**:
   ```
   ✅ Build complete. E2E passed.
   📄 Docs updated: CLAUDE.md + ROADMAP.md
   📋 Run /clientprojectupdate? (y/skip)
   ```

---

## Examples

```bash
# Auto-size from plan complexity
/build-with-agent-team .claude/plans/my-feature-plan.md

# Specify agents explicitly
/build-with-agent-team .claude/plans/my-feature-plan.md 3

# Launched from /daily-plan agent team offer
/build-with-agent-team .claude/daily-plans/PLAN-2026-02-20.md auto
```

---

## Hook Inheritance

Project-level hooks fire automatically in all agent pane processes. Agent panes are separate Claude instances in the same project directory — they load all `.claude/` hookify files on startup. All safety and cost-optimization hooks are active in every pane with zero additional setup.
