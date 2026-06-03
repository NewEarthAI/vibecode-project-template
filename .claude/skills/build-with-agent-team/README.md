# Build with Agent Team

A Claude Code skill for building projects using Agent Teams — multiple Claude instances working in parallel tmux panes, communicating directly, and coordinating via a shared contract-first build sequence. Enhanced with NSM alignment, ROADMAP context wrapping, post-implementation discipline, and full hook inheritance.

```bash
/build-with-agent-team [plan-path] [num-agents]
```

---

## Worktree Isolation (Recommended)

When spawning agents via the Task tool, use `isolation: "worktree"` to give each agent its own branch and working directory. This prevents file conflicts when multiple agents edit files simultaneously.

```javascript
Task({
  description: "Build feature X",
  subagent_type: "general-purpose",
  isolation: "worktree",  // Each agent gets its own git worktree
  prompt: "..."
})
```

**Why worktree isolation matters:**
- Each agent works on an isolated copy of the repo (separate branch + directory)
- No file conflicts between parallel agents editing the same files
- Changes are returned as a branch that can be merged back
- Worktree is auto-cleaned if the agent makes no changes

**When to use:** Multi-agent builds where agents touch overlapping files, long-running agents.
**When to skip:** Read-only research agents (Explore, Plan types), quick single-file edits.

---

## Prerequisites

### 1. Install tmux

Agent teams use tmux for split-pane visualization so you can see all agents working simultaneously.

**macOS:**
```bash
brew install tmux
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update && sudo apt install tmux
```

Verify: `tmux -V`

### 2. Enable Agent Teams

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

> **tmux env var note:** The `settings.json` approach is preferred — tmux sessions don't inherit shell exports, so `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` won't work unless added to your shell profile.

---

## Installation

```bash
# Project-level
cp -r build-with-agent-team .claude/skills/

# Global (works in any project)
cp -r build-with-agent-team ~/.claude/skills/
```

---

## Phase 0: Pre-flight

**Run before spawning ANY agent.** Five checks — do not skip.

### 1. Prerequisites
Verify `tmux -V` succeeds and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is in settings.json.

### 2. NSM / ROADMAP Alignment Gate
Read ROADMAP.md. Check if the plan's goal maps to a NOW or NEXT lane item.
- **NOW/NEXT**: proceed silently
- **LATER lane**: advisory warning: "⚠️ LATER lane item. Current NOW: {items}. Proceed? (y/n)" — never block

Rationale: spawning 4 agents on a LATER item while NOW items are blocked is the most expensive strategic mistake in an agentic workflow.

### 3. Planning-Protocol Gate
If plan came from plan mode (`.claude/plans/`): proceed.
If not: run inline blast radius check:
```
Q1: Which existing DB tables/RPCs does this touch? (check CLAUDE.md)
Q2: Which views/edge functions depend on those?
Q3: Does anything in this plan already exist in the codebase?
```

### 4. Memory / Conflict Check
Scan CLAUDE.md Key Tables + MEMORY.md for components the plan would create. Surface anything that already exists. Prevents building parallel implementations of the same thing.

### 5. Cost Estimate Gate
Surface before spawning:
```
📊 {N} agents × ~{M} turns ≈ significant token footprint
   Subagents (Task tool) are better for isolated single-component tasks.
   Proceed with agent team? (y/n)
```

---

## Create Your Plan

Write a markdown document covering all required sections (see checklist below). This works for:

- **Greenfield projects**: A new app, API, or system from scratch
- **Brownfield features**: A new feature in an existing codebase

### Plan Format Requirements Checklist

Before spawning agents, verify the plan has:
- [ ] Tech stack table
- [ ] Project structure tree
- [ ] Agent build order with explicit contract handoff points
- [ ] Cross-cutting concerns table (or "None — fully isolated to {layer}")
- [ ] Authoritative API contract (both backend and frontend MUST conform exactly)
- [ ] Per-agent runnable validation bash scripts with expected output
- [ ] Measurable acceptance criteria
- [ ] Known gotchas section (check MEMORY.md schema gotchas + CLAUDE.md)

See `example-plan/session-manager-plan.md` for a reference.

---

## Cross-Cutting Concerns Table

**Required in every plan.** This is where integration bugs live — not in individual components.

```markdown
| Concern | Owner | Coordinates With | Detail |
|---------|-------|-----------------|--------|
| {shared behavior} | {agent role} | {other agent role} | {exact spec} |
```

**Examples of cross-cutting concerns:**
- Text chunk accumulation strategy (backend ↔ frontend rendering)
- API URL trailing slash conventions (backend ↔ frontend fetch calls)
- Response envelope shape for nested objects (backend ↔ frontend destructuring)
- Shared enum values / status strings (DB ↔ backend ↔ frontend)
- Auth token format and refresh behavior (backend ↔ frontend)
- Error response shape (backend ↔ frontend error handling)

If no cross-cutting concerns exist: `"None — fully isolated to {layer}."`

---

## Auto-Sizing Heuristic

When `num-agents` is omitted, count distinct component layers in the plan:

| Component count | Team size |
|---|---|
| 1-2 layers | 2 agents (lead + 1 specialist) |
| 3-4 layers | 3 agents (lead + 2 specialists) |
| 5+ layers | 4 agents max (lead + 3 specialists) |

Count: unique DB table groups + unique API service domains + major UI component areas.

The lead surfaces the auto-sizing and accepts an override before spawning.

---

## ROADMAP Context Wrapper

**Every sub-agent's initial message MUST include this block** before their role-specific build instructions:

```
ROADMAP CONTEXT:
- Building: {goal from plan, 1 line}
- Lane: {NOW / NEXT / LATER}
- NSM impact: {which metric component this moves and estimated delta}
- Constraint: must not disturb {adjacent system from CLAUDE.md}
- Existing at: {relevant file:line from CLAUDE.md — "greenfield" if none}
- Build to: minimum viable — no features beyond acceptance criteria in this plan
```

**Without this context**: agents build to spec, potentially over-engineering or adding unrequested features that conflict with adjacent systems.
**With this context**: agents know product purpose, constraint boundaries, and that minimum viable is the target.

---

## Usage

```bash
/build-with-agent-team [plan-path] [num-agents]
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `plan-path` | Yes | Path to your plan markdown file |
| `num-agents` | No | 2-4 agents. If omitted, auto-sized from plan complexity. |

**Examples:**
```bash
# Auto-size from plan complexity
/build-with-agent-team .claude/plans/my-feature.md

# Specify 3 agents
/build-with-agent-team .claude/plans/my-feature.md 3

# Launched from /daily-plan agent team offer
/build-with-agent-team .claude/daily-plans/PLAN-2026-02-20.md auto
```

The skill will:
1. Run Phase 0 pre-flight (ROADMAP alignment, protocol gate, memory check, cost estimate)
2. Read your plan and determine agent roles
3. Auto-size the team or use your specified count
4. Spawn agents in tmux split panes with ROADMAP context wrappers
5. Coordinate contract-first collaboration
6. Run E2E validation and Phase 5 post-implementation protocol

---

## Agent Build Order & Communication

When building with an agent team, agents MUST follow this contract-first sequence:

### Phase 1: Database Agent
1. Build schema, CRUD functions, Pydantic models (or TypeScript types)
2. **Send function signatures and model definitions to lead**
3. Lead verifies and forwards to backend agent

### Phase 2: Backend Agent (after receiving DB contract)
1. Build API routes, business logic, SDK/service integration
2. **Send complete API contract to lead** — must include:
   - Exact endpoint URLs with trailing slash conventions noted
   - Exact request/response JSON shapes
   - Status codes for success and error cases
   - SSE event format and all event types (if applicable)
3. Lead verifies and forwards to frontend agent

### Phase 3: Frontend Agent (after receiving API contract)
1. Build UI conforming **exactly** to the verified API contract
2. Do NOT guess endpoint URLs or response shapes — use what was provided

### Phase 4: Lead Validation
1. Contract diff — compare backend's actual endpoints vs frontend's fetch calls
2. Start all servers
3. Run E2E validation per the plan's acceptance criteria

---

## Phase 5: Post-Implementation Protocol

**MANDATORY after E2E passes.** The lead agent completes all 5 steps before reporting done.

1. **Update CLAUDE.md** — add new tables, RPCs, components to Current Status / Key Tables
2. **Update ROADMAP.md** — mark the item complete, move to COMPLETED section
3. **Write build log** to `.claude/sessions/agent-team-build-{YYYY-MM-DD}.md`:
   ```
   ## {HH:MM} — AGENT [database]: {what was built, 1 line}
   ## {HH:MM} — AGENT [backend]: {what was built, 1 line}
   ## {HH:MM} — AGENT [frontend]: {what was built, 1 line}
   ## {HH:MM} — LEAD [e2e]: validation passed / {issue if any}
   ```
4. **Set client flag** — if client-visible, append `CLIENTUPDATE_PENDING=true` to `.claude/sessions/session-state.env`
5. **Surface completion**:
   ```
   ✅ Build complete. E2E passed.
   📄 CLAUDE.md + ROADMAP.md updated.
   📋 Run /clientprojectupdate? (y/skip)
   ```

**Why Phase 5 matters**: agent teams produce working software but create documentation debt if this step is skipped. The next session starts without knowing the feature exists, degrading every subsequent planning and routing decision.

---

## Lead Agent Progress Log

The `progress-logger` hook fires per-pane (inside each agent's session), not in the parent session. The lead agent's build log (Phase 5, Step 3) is the unified parent-session audit trail.

Format: one entry per agent's domain completion, timestamped.
File: `.claude/sessions/agent-team-build-{YYYY-MM-DD}.md`

---

## Hook Inheritance

**Project-level hooks fire automatically in all agent pane processes — no configuration needed.**

Agent panes are separate Claude instances running in the same project directory. They load all `.claude/` hookify files on startup. Every safety and cost-optimization hook applies in every pane:

| Hook | Fires in agent panes? |
|------|----------------------|
| `supabase-smart-query` (LIMIT enforcement) | ✅ Yes |
| `supabase-destructive-sql` (DELETE/TRUNCATE guard) | ✅ Yes |
| `supabase-migration-safety` (migration pre-flight) | ✅ Yes |
| `plan-mode-enforcer` (protocol enforcement) | ✅ Yes |
| `n8n-workflow-delete-block` (hard block on delete) | ✅ Yes |
| `safe-bash-enforcer` (catastrophic bash block) | ✅ Yes |
| `filesystem-safety` (destructive command warn) | ✅ Yes |
| `progress-logger` (mutation logging) | ✅ Yes (per-pane log) |

The main session's `progress-logger` output won't capture child agent mutations (different process = different log file). The lead agent's unified build log covers this gap.

---

## Agent Teams vs Subagents

| | Subagents | Agent Teams |
|---|-----------|-------------|
| **Context** | Runs within main session | Each agent has its own session |
| **Communication** | Reports back to main agent only | Agents message each other directly |
| **Coordination** | Main agent manages all work | Shared task list, self-coordination |
| **Visibility** | Results summarized to main context | Each agent visible in tmux pane |
| **Token cost** | Lower (results summarized) | Higher (each agent is a separate instance) |
| **Best for** | Quick, focused tasks | Complex builds requiring contract negotiation |

**Use subagents when**: task is quick, isolated, cost-sensitive, or only the result matters.
**Use agent teams when**: multiple components must integrate, agents need to agree on shared contracts, or you want real-time parallel progress visibility.
