# Dashboard Specialist Agent Swarm

> Automated dashboard verification, debugging, and remediation system.
> Generated during `/setup` — Customized for {{PROJECT_NAME}}.

## Overview

This swarm provides comprehensive dashboard health monitoring through specialized agents that verify data accuracy, visual quality, performance, and backend integrity.

**Command**: `/dashboard-health [options]`

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │   DASHBOARD HEALTH ORCHESTRATOR     │
                    │      /dashboard-health command      │
                    └───────────────┬─────────────────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
           ▼                        ▼                        ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│   DATA ACCURACY     │   │    UX/VISUAL        │   │    PERFORMANCE      │
│    SPECIALIST       │   │    SPECIALIST       │   │    SPECIALIST       │
│  (KPI Verification) │   │  (Visual Quality)   │   │  (Core Web Vitals)  │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
           │                                                  │
           ▼                                                  ▼
┌─────────────────────┐                              ┌─────────────────────┐
│   BACKEND AUDITOR   │                              │   PIPELINE MONITOR  │
│  (Database Health)  │                              │  (Workflow → DB)    │
└─────────────────────┘                              └─────────────────────┘
                                    │
                                    ▼
                    ┌─────────────────────────────────────┐
                    │      REMEDIATION ORCHESTRATOR       │
                    │     (Auto-fix + Prompt Generation)  │
                    └─────────────────────────────────────┘
```

## Project Configuration

| Setting | Value |
|---------|-------|
| **Project** | {{PROJECT_NAME}} |
| **Dashboard URL** | {{DASHBOARD_URL}} |
| **Dashboard Status** | {{DASHBOARD_STATUS}} |
| **Backend MCP** | {{BACKEND_MCP}} |
| **Workflow MCP** | {{WORKFLOW_MCP}} |
| **Framework** | {{DASHBOARD_FRAMEWORK}} |

## Agents

### Tier 1: Orchestration

| Agent | Purpose | Model |
|-------|---------|-------|
| `dashboard-health-orchestrator` | Entry point, coordination, checkpointing | Sonnet |

### Tier 2: Verification Specialists

| Agent | Purpose | Model | Active |
|-------|---------|-------|--------|
| `data-accuracy-specialist` | KPI vs ground truth verification | Sonnet | {{DASH_DATA_ACTIVE}} |
| `ux-visual-specialist` | Visual quality, accessibility, design | Opus | {{DASH_UX_ACTIVE}} |
| `performance-specialist` | Core Web Vitals, API latency | Sonnet | {{DASH_PERF_ACTIVE}} |

### Tier 3: Deep Inspection

| Agent | Purpose | Model | Active |
|-------|---------|-------|--------|
| `backend-auditor-supabase` | Supabase-specific database health | Sonnet | {{DASH_AUDIT_SUPA_ACTIVE}} |
| `backend-auditor-generic` | Generic database/API health | Sonnet | {{DASH_AUDIT_GEN_ACTIVE}} |
| `pipeline-monitor` | Workflow → database sync | Sonnet | {{DASH_PIPE_ACTIVE}} |
| `remediation-orchestrator` | Auto-fix execution | Sonnet | Always |
| `research-brainstorm-specialist` | Pre-build planning | Opus | {{DASH_RESEARCH_ACTIVE}} |

## Usage

### Full Health Check
```
/dashboard-health
```
Runs all applicable specialists and generates comprehensive report.

### Targeted Checks
```
/dashboard-health --kpi       # Data accuracy only
/dashboard-health --visual    # UX/visual only
/dashboard-health --perf      # Performance only
/dashboard-health --audit     # Backend audit only
/dashboard-health --sync      # Pipeline sync only (if workflow MCP)
```

### Remediation
```
/dashboard-health --fix       # Auto-fix safe issues
/dashboard-health --fix-all   # Auto-fix + generate prompts for manual fixes
```

### Pre-Build Planning
```
/dashboard-health --brainstorm  # Design dashboard (if none exists)
```

## Key Files

| File | Purpose |
|------|---------|
| `.claude/dashboard-status.md` | Current health checkpoint |
| `.claude/dashboard-ground-truth-queries.sql` | KPI verification queries |
| `lovable-prompts/` | Generated frontend fix prompts |
| `migrations/` | Generated database migrations |
| `debugging/reports/` | Historical health reports |

## Issue Tracking

Issues are tracked with prefixed IDs:

| Prefix | Category | Example |
|--------|----------|---------|
| `DASH-` | Dashboard display issues | DASH-1: Stale KPI |
| `AUDIT-` | Database/backend issues | AUDIT-3: RPC mismatch |
| `SYNC-` | Pipeline/workflow issues | SYNC-2: Stuck processing |
| `PERF-` | Performance issues | PERF-1: Slow LCP |
| `UX-` | Visual/accessibility issues | UX-5: Missing alt text |

## Token Efficiency

All agents follow mandatory token optimization:

| Rule | Forbidden | Required |
|------|-----------|----------|
| SQL queries | `SELECT *` | Named columns + LIMIT |
| Playwright | `fullPage: true` | Viewport or element |
| MCP tools | `mode="full"` | `mode="minimal"` or `mode="structure"` |

See: `.claude/skills/mcp-token-optimizer/SKILL.md`

## Conditional Activation

Agents activate based on detected MCP servers:

| MCP Pattern | Activates |
|-------------|-----------|
| `mcp__supabase-*__*` | backend-auditor-supabase |
| `mcp__n8n-mcp-*__*` | pipeline-monitor |
| `mcp__make__*` | pipeline-monitor |
| `mcp__*playwright*__*` | ux-visual-specialist |
| None of above | backend-auditor-generic |

## Ground Truth Queries

KPIs are verified against SQL ground truth:

{{KPI_QUERY_TABLE}}

See: `.claude/dashboard-ground-truth-queries.sql`

---

*Dashboard Specialist Agent Swarm v1.0*
*Generated during /setup on {{SETUP_TIMESTAMP}}*
