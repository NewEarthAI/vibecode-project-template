---
description: "Run dashboard health verification for {{PROJECT_NAME}}"
argument-hint: "[--full | --kpi | --visual | --perf | --audit | --sync | --fix | --brainstorm]"
---

# /dashboard-health — Dashboard Health Verification

Run comprehensive health checks on the dashboard, backend, and data pipelines.

## Project Context

**Project**: {{PROJECT_NAME}}
**Dashboard URL**: {{DASHBOARD_URL}}
**Dashboard Status**: {{DASHBOARD_STATUS}}
**Backend MCP**: {{BACKEND_MCP}}
**Workflow MCP**: {{WORKFLOW_MCP}}

## Command Arguments

Parse the argument `$ARGUMENTS` to determine which checks to run:

| Argument | Action |
|----------|--------|
| (none) or `--full` | Run all applicable specialists |
| `--kpi` | Data accuracy verification only |
| `--visual` | UX/visual quality check only |
| `--perf` | Performance metrics only |
| `--audit` | Backend database audit only |
| `--sync` | Pipeline sync check only (requires workflow MCP) |
| `--fix` | Auto-fix safe issues after checks |
| `--fix-all` | Auto-fix + generate prompts for manual fixes |
| `--brainstorm` | Dashboard design mode (for projects without dashboard) |
| `--status` | Show current health status without running checks |

## Execution

### If Dashboard Status = "NONE" or "BUILDING"

When no dashboard exists yet, activate the Research/Brainstorm Specialist:

```
Use the Task tool to spawn:
  subagent_type: "dashboard-specialists/research-brainstorm-specialist"
  prompt: |
    Help design a dashboard for {{PROJECT_NAME}}.

    Backend MCP: {{BACKEND_MCP}}
    Project Domain: {{PROJECT_DOMAIN}}

    Follow your workflow to:
    1. Discover available data
    2. Interview user for priorities
    3. Recommend KPIs
    4. Generate specs and Lovable prompts
```

### If Dashboard Status = "EXISTS"

Spawn the Dashboard Health Orchestrator:

```
Use the Task tool to spawn:
  subagent_type: "dashboard-specialists/dashboard-health-orchestrator"
  prompt: |
    Run dashboard health verification for {{PROJECT_NAME}}.

    Arguments: $ARGUMENTS
    Dashboard URL: {{DASHBOARD_URL}}
    Backend MCP: {{BACKEND_MCP}}
    Workflow MCP: {{WORKFLOW_MCP}}

    Execute your standard workflow based on the arguments provided.
```

## Quick Status Check

If `--status` argument provided, read and display the current checkpoint:

```
Read: .claude/dashboard-status.md
Display: Current health status summary
```

## Output

The orchestrator will:
1. Run requested health checks
2. Document findings in `.claude/dashboard-status.md`
3. Generate fix prompts if issues found (when `--fix` specified)
4. Return summary report

## Related Files

- `.claude/agents/dashboard-specialists/` — Agent definitions
- `.claude/dashboard-status.md` — Health checkpoint
- `.claude/dashboard-ground-truth-queries.sql` — KPI verification queries
- `lovable-prompts/` — Generated frontend fix prompts
- `migrations/` — Generated database migrations

---

*Dashboard Health Command — Verification at your fingertips*
