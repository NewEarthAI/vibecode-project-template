# Project — Planning Protocol

> **MANDATORY**: Every plan mode session in this project MUST follow this protocol.
> This is not optional. This is not a suggestion. This is the standard.

---

## Why This Exists

This is the **central hub** for your project — potentially with multiple clients, ventures, and departments.
Every component connects across projects: Supabase instances, n8n servers, Lovable dashboards,
edge functions, Claude Code agents/skills, and cross-project MCP servers. A plan that ignores these
connections creates technical debt, breaks existing functionality, or duplicates work already done.

---

## Phase 0: Context Loading

Before writing a single line of plan, read and internalize:

| File | What You Learn | Required |
|------|---------------|----------|
| `ROADMAP.md` | What's done, what's next, what's blocked, dependency map | ALWAYS |
| `CLAUDE.md` | Architecture, MCP servers, tech stack, client registry, conventions | ALWAYS |
| `agency/BRIEFING.md` (if exists) | Current operational state across all clients and ventures (COO view) | When applicable |
| `agency/MASTER_PLAN.md` (if exists) | Approved architecture and strategic decisions | When touching agency structure |
| `clients/{slug}/CLAUDE.md` (if exists) | Per-client architecture, tables, workflows, integrations | When touching client projects |
| `departments/{dept}/CONTEXT.md` (if exists) | Department context | When touching department concerns |
| Relevant continuation/spec files | Full context for the specific workstream being planned | When applicable |

**Token efficiency**: Don't re-read files already loaded in the current session. Check your context first.
Use progressive disclosure for MCP queries. LIMIT all SQL queries. Start minimal, expand only when insufficient.

---

## Phase 1: Impact Analysis

Before proposing ANY change, map the blast radius across all layers:

### 1. Database Layer
- **Which Supabase instance?** (refer to CLAUDE.md for instance names)
- Which tables are read/written?
- Which RPCs call these tables?
- Which views depend on these tables?
- Which triggers fire on these tables?
- Does this create a new table? If so, does it duplicate an existing one?

### 2. Workflow/Pipeline Layer
- **Which n8n instance?** (refer to CLAUDE.md for instance names)
- Which workflows touch affected tables?
- Does this change data flow through existing pipeline stages?
- Are there data flow integrity concerns? (critical fields that must pass through)

### 3. API/Edge Function Layer
- Which deployed Supabase edge functions read/write affected data?
- Does this require a new deployment or update?
- Are there local-only changes that haven't been deployed yet?

### 4. Frontend/Dashboard Layer
- Which components consume this data?
- Does this change any KPI calculation or display?
- Are there existing dashboard views that need updating?

### 5. Agent/Skill/Command Layer
- Which Claude Code agents, skills, or commands reference affected systems?
- Does this create or modify any agent system prompts?
- Do any hookify rules need updating?

### 6. Cross-Workstream Impact
- Check ROADMAP dependency map — does this unblock or conflict with other workstreams?
- Does this affect any items in the NOW or NEXT lanes?
- **Cross-project**: Does this affect other repos?

---

## Phase 2: Interoperability Verification

Every plan MUST verify these invariants:

### Naming & Convention Compliance
- [ ] Tables: `snake_case`, UUID primary keys via `uuid_generate_v4()`
- [ ] Columns: `snake_case`, `created_at`/`updated_at` timestamps
- [ ] RPCs: `snake_case`, appropriate parameter prefix for your platform
- [ ] n8n nodes: Action-oriented names
- [ ] Platform-appropriate best practices per technology

### Data Integration
- [ ] New data integrates with canonical views/sources of truth
- [ ] Compatible with existing reporting systems
- [ ] Respects source-of-truth rules (verify in CLAUDE.md)
- [ ] No silent data changes — everything auditable

### No Duplication
- [ ] Checked existing RPCs before creating new ones
- [ ] Checked existing tables before creating new ones
- [ ] Checked existing n8n workflows before creating new ones
- [ ] Checked existing edge functions before creating new ones

### Operational Safety
- [ ] Test strategy defined for any production-affecting changes
- [ ] Rollback plan exists for destructive or irreversible changes
- [ ] Workflow backups taken before modifications where applicable
- [ ] Correct instance targeted (don't cross-project without intention)

### Real-State Validation (heuristics / classifiers / decision trees)

If the plan introduces a heuristic, classifier, auto-detector, or any decision tree whose correctness depends on matching real-world inputs:

- [ ] Enumerate the ACTUAL current instances the heuristic will process (branches, workflows, rows, files) — not hypothetical test cases
- [ ] Dry-run the heuristic logic against each enumerated instance BEFORE first real use
- [ ] Document the expected classification per instance in the plan
- [ ] If any instance's expected classification is "ambiguous" or "edge case," that's the first real bug surface — address in the plan, not in the first production run

**Why**: idealized test cases (clean feature branch, single open PR) are usually NOT the common state in a multi-worktree / long-running project. Real state has edge combinations that didn't appear in the plan. Dry-run is a CHEAP plan gate — minutes of effort, catches a class of bug that no amount of idealized test-case design can prevent.

Real incident pattern: a shell classifier was written to the plan's idealized cases; dry-run against 5 active worktrees caught a shell-quoting bug (`grep -c PATTERN || echo 0` double-echoing `"0\n0"`) that would have silently misclassified every dirty tree. Without the dry-run gate, the bug ships to production and every first invocation misfires.

---

## Phase 3: Strategic Alignment

Validate the plan serves the project's actual goals:

### Client/Venture/Internal Value
- **Clients**: Does this directly address a client deliverable?
- **Ventures**: Does this improve venture capabilities?
- **Internal**: Does this improve operations (Finance, Marketing, IT/Ops)?
- If none of the above, is this foundational infrastructure that enables visible work?

### Architecture Quality
- Does this follow your project's data pipeline pattern?
- Is this the simplest solution that achieves the goal? (No over-engineering)
- Does this respect your platform's principles? (e.g., Claude Code everywhere)

### First Principles
- Think from the problem, not from the tools
- Prefer extending existing systems over building new ones
- Every new table/RPC/workflow has a maintenance cost — justify it
- The right amount of complexity is the minimum needed for the current task

---

## Phase 4: Plan Documentation Standard

Every plan MUST include these sections:

### Required Sections

1. **Context** (3-5 sentences): What problem does this solve? Why now?

2. **Files Created/Modified** table:
   | File | Action | Est. Lines |
   |------|--------|-----------|
   | path/to/file | CREATE/EDIT | ~N |

3. **Database Changes** (if any):
   | Change | Type | Instance | Details |
   |--------|------|----------|---------|
   | `table_name` | CREATE TABLE | `{{db_instance}}` | columns, indexes, RLS |
   | `rpc_name` | CREATE FUNCTION | `{{db_instance}}` | params, return type |

4. **Impact Assessment** (from Phase 1 — brief summary):
   - Database: X tables affected (which instance)
   - Workflows: Y workflows need updates (which n8n)
   - Frontend: Z components affected
   - Cross-workstream: interactions with roadmap items
   - Cross-project: other repos affected

5. **Risk Assessment**:
   | Risk | Likelihood | Impact | Mitigation |
   |------|-----------|--------|-----------|

6. **Verification Steps**: How to confirm the implementation works

7. **ROADMAP Update**: What changes when this ships

### Optional Sections (include when relevant)
- Migration strategy (for schema changes)
- Rollback plan (for risky changes)
- Performance considerations (for high-volume data paths)
- Token budget (for agent/skill changes)

---

## Phase 5: Post-Implementation Protocol

After completing a plan or significant milestones:

1. **Update ROADMAP.md** — move items, update statuses, clear blockers
2. **Update continuation/spec files** — mark phases complete, update data status
3. **Update CLAUDE.md** — only if new tables, RPCs, workflows, or commands were added
4. **Update agency/BRIEFING.md** — if client/venture status changed
5. **Notify stakeholders** — if the work is client/user-visible
6. **Update memory** — only if stable patterns were confirmed (not speculative)

ROADMAP updates should be **surgical**: change the status, update the numbers.
Don't rewrite sections that haven't changed.

---

## Anti-Patterns (Don't Do These)

| Anti-Pattern | Why It's Bad | Do This Instead |
|-------------|-------------|-----------------|
| Plan without reading ROADMAP + context | Misses blockers, duplicates work | Read both first, always |
| Create new table without checking existing | Table bloat, split data | Search CLAUDE.md + database |
| Plan in isolation from other workstreams | Breaks dependencies, conflicts | Check dependency map |
| Over-engineer for hypothetical future needs | Wasted effort, complexity debt | Build for the current requirement |
| Skip verification steps | Bugs ship to production | Always include how to test |
| Forget ROADMAP update | Roadmap goes stale | Plan the update as part of the plan |
| Re-fetch data already in context | Token waste | Check context before querying |
| Use wrong instance | Data in wrong project | Verify instance in CLAUDE.md |
| Use `SELECT *` in queries | Token waste, hookify blocks it | Specify columns explicitly |
| Use `mode="full"` for queries | Token waste, hookify blocks it | Start minimal, escalate as needed |
| Plan changes without value chain | Work that doesn't matter | Trace to client/venture/internal impact |

---

## Token Efficiency Standards

These apply to plan mode AND implementation:

1. **MCP queries**: Start minimal. Only escalate when genuinely insufficient.
2. **SQL queries**: Always LIMIT. `LIMIT 5` for spot checks, `LIMIT 25` for analysis. Never `SELECT *`.
3. **File reads**: Don't re-read files already in context.
4. **Parallel tool calls**: Make independent queries in parallel.
5. **Progressive disclosure**: Get the shape first, then drill into details.
6. **Existing documentation**: Reference existing docs rather than regenerating.
7. **Hookify enforcement**: Block rules will reject `SELECT *`, `mode=full`, `fullPage=true`, `list_tables`, `get_node_info`. Plan accordingly.

---

*Project Planning Protocol v1.0*
*Enforced by CLAUDE.md + hookify rules*
