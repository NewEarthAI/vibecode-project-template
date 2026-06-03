# /daily-plan

Your daily work plan — generates once, resumes on repeat calls.

**Invokes**: `daily-plan-generator` skill (v5.0)

---

## What Happens

**Phase 0 — Session Housekeeping** (runs first, every time):
0A. Checks if previous sessions left uncommitted/unpushed work → offers to commit + push so all Macs stay in sync
0B. Syncs recent git commits to roadmap activity table → admin portal feed stays current (requires `roadmap_activity_table` parameter)
0C. Pulls latest from `origin/main` → picks up work done on other Macs before planning

**First call of the day** (no plan file exists):
1. Reads ROADMAP.md System/Project/Milestone hierarchy, git log + git diff, yesterday's plan, last session
2. Silently checks strategic alignment (10A — surface at most 1 concern if warranted)
3. Scores and ranks work items by NSM impact × urgency (projects >80% get completion bonus)
4. Writes `.claude/daily-plans/PLAN-{today}.md` with full hierarchy context per step
5. Checks for pending `/clientprojectupdate` flag (10C)
6. Displays summary and waits for your "go" or "go team"

**Subsequent calls** (plan already exists):
1. Runs Phase 0 housekeeping (always)
2. Reads existing plan + checks ROADMAP + recent git for completions
3. Shows what's done, what's remaining
4. Refreshes the plan file if steps were completed since last generation
5. Waits for "go" or "go team" on remaining work

---

## Usage

```
/daily-plan
```

No arguments needed. After the plan appears:

| You say | What happens |
|---------|-------------|
| `go` | Start Step 1, work through steps sequentially |
| `go team` | Spawn parallel agents for independent steps (faster, uses more context) |
| Edit the plan file | Reorder/change priorities, then say `go` |

---

## Agent Team Mode

When you say "go team", Claude will:
1. Identify which plan steps can run in parallel (no shared dependencies)
2. Propose a team structure with named agents
3. Confirm with you before spawning
4. Coordinate parallel execution

Best for: plans with 3+ independent research/verification steps.
Not ideal for: plans where every step depends on the previous one.

---

## Output

**Plan file**: `.claude/daily-plans/PLAN-{YYYY-MM-DD}.md`

Each step shows full hierarchy context:
```
### Step N — [COMPLEXITY] Task Name
> System: Customer Operations
> Project: Order Tracking [75%] | Milestone: Real-time Status [65%]
> North Star: Every order visible without calling anyone
> Why: Order Visibility 78% → 90% — status updates close data gaps
> Action: Build StatusAccuracyCard.tsx
> Success: Hero card shows accuracy %, click opens details
```

**Complexity tags** (no time estimates — we run at AI speed):
- `[TRIVIAL]` = 1-2 tool calls, verification only
- `[MODERATE]` = design + implement in one pass
- `[COMPLEX]` = multi-file, needs exploration or agent team

---

## Setup

Before first use, configure your North Star Metric in `.claude/skills/daily-plan-generator/SKILL.md`:

```yaml
parameters:
  - name: primary_nsm_label
    default: "NSM"        # Your metric name (e.g. OVS, ARR, DAU, Uptime)
  - name: primary_nsm_current
    default: "~X%"        # Current baseline
  - name: primary_nsm_target
    default: "Y%"         # Target value
```

The scoring system ranks every ROADMAP milestone by how much it moves your metric.

---

## Related Commands

- `/compress-roadmap` — archive ROADMAP items when > 500 lines
- `/clientprojectupdate` — update client-facing project status board
- `/agent-research` — research sub-tasks (always wraps with ROADMAP context per 10B)
- `/prime` — session priming (lighter alternative if you just want quick context)
- `/push-to-template` — propagate improvements back to the template repo
- `/update-latest` — pull template updates into this project

---

*Template-managed | daily-plan-generator v2.0 | 2026-02-24*
