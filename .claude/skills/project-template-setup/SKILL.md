# Project Template Setup

Bootstrap new client projects using Claude Code project template. Implements PSB (Plan → Setup → Build) methodology with Grade 1-5 agentic maturity model.

## When This Applies

- Starting new client engagement
- Migrating existing system to Claude Code workflow
- Setting up debug/documentation engagement
- Onboarding project to agentic development

## Prerequisites

- GitHub CLI authenticated (`gh auth status`)
- Template repo: `NewEarthAI/vibecode-project-template`

## Flow (4 Steps)

```
1. [Clone] Clone template to {{project_path}}
   └─ Input: project name, path
   └─ Output: Project directory with scaffolding

2. [Interview] Run CONTEXT_QUESTIONS.md
   └─ Uses: AskUserQuestion tool
   └─ Output: Answers for CLAUDE.md population

3. [Discover] Query MCP servers for project context
   └─ Uses: Supabase list_tables, n8n list_workflows
   └─ Output: Schema/workflow inventory

4. [Populate] Generate CLAUDE.md from template
   └─ Uses: Interview answers + discovery
   └─ Output: Customized project memory
```

## Grade Selection

| Grade | When to Use | Components |
|-------|-------------|------------|
| **1** | Quick fixes, debugging | CLAUDE.md + `/prime` |
| **2** | Feature work | + specs/ + ai_docs/ + agents/ |
| **3** | Full development | + skills/ + .mcp.json + `/build` |
| **4** | Production systems | + app_reviews/ + test loops |

**Default**: Grade 2 for new clients, Grade 3 for active development

## Commands

### Clone Template
```bash
gh repo clone NewEarthAI/vibecode-project-template {{project_path}}
cd {{project_path}}
rm -rf .git && git init  # Fresh git history
```

### Run Interview
```
1. Read CONTEXT_QUESTIONS.md
2. Ask each question using AskUserQuestion tool
3. Store answers for template population
```

### MCP Discovery
```
# If Supabase connected
list_tables(schemas=["public"])

# If n8n connected
n8n_list_workflows()
```

### Populate CLAUDE.md
```
1. Copy CLAUDE.md.template → CLAUDE.md
2. Replace {{PLACEHOLDERS}} with interview answers
3. Add discovered tables/workflows to reference sections
4. Set grade level based on project needs
```

## Template Placeholders

| Placeholder | Source | Example |
|-------------|--------|---------|
| `{{PROJECT_NAME}}` | Interview Q1 | "a logistics app" |
| `{{PROJECT_TYPE}}` | Interview Q2 | "Logistics SaaS" |
| `{{STACK}}` | Interview Q3 | "Supabase, n8n, React" |
| `{{MCP_SERVERS}}` | Discovery | "supabase-yourproject, n8n-mcp" |
| `{{KEY_TABLES}}` | Discovery | "shipments, carriers, routes" |
| `{{KEY_WORKFLOWS}}` | Discovery | "order-intake, dispatch-notify" |

## Post-Setup Checklist

```
□ CLAUDE.md populated with project context
□ .mcp.json configured (copy from .mcp.json.sample)
□ Grade level set in README
□ Hookify architecture verified:
  □ 13 hookify rules present in .claude/
  □ Wildcard matchers tightened to exact server names
  □ mcp-server-guard configured and enabled
  □ safe-bash selfcheck passes: bash scripts/selfcheck-safe-bash.sh
□ /prime command tested
□ First /plan command executed for initial task
□ Client-specific skill created (if patterns emerge)
```

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Skip interview | CLAUDE.md lacks context | Run full CONTEXT_QUESTIONS |
| Hardcode secrets in .mcp.json | Security risk | Use environment variables |
| Start at Grade 5 | Over-engineering | Start Grade 2, evolve up |
| Copy  skills directly | Project-specific | Use template's generic skills |
| Skip /prime after setup | Claude lacks project understanding | Always run /prime first |

## Creating Client-Specific Skills

After 3+ repeated patterns, create `{{client}}-workflows` skill:

```markdown
---
name: {{client}}-workflows
description: |
  {{Client}} workflow IDs and patterns. Use when debugging {{client}}
  pipelines or checking workflow status.
---

# {{Client}} Workflows

## Quick Reference
| Workflow | ID | Purpose |
|----------|-----|--------|
| {{workflow_1}} | `{{id}}` | {{purpose}} |

## Debug Guide
| Symptom | Check | ID |
|---------|-------|-----|
| {{symptom}} | {{workflow}} | `{{id}}` |
```

## Integration with Other Skills

- **safe-bash**: Privileged workflow enforcement (n8n API, git commits, audit logging)
- **skill-creator**: Use to create client-specific skills after patterns emerge
- **agent-research**: Coordinated multi-agent research for complex investigations

## Hookify Architecture (13 Rules)

The template ships a complete hookify architecture:

| Type | Count | Purpose |
|------|-------|---------|
| SessionStart addContext | 1 | 5 universal rules + hook reference |
| PreToolUse addContext | 3 | Lazy-load Supabase/n8n/Task patterns |
| PreToolUse warn | 7 | Token-efficiency and safety checks |
| PreToolUse block | 2 | Server guard + safe-bash enforcer |

Hooks use wildcard matchers out-of-box (`mcp__supabase-*__.*`). `/setup` Step 7.5 tightens them to exact server names and configures the server guard.

**Token efficiency patterns are embedded in hooks** — no separate skills needed. The `supabase-auto-load` and `n8n-auto-load` hooks inject patterns on-demand when relevant tools are called.

---

*Skill v3.0 — Project template setup with 13-hook architecture*
