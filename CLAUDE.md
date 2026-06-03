# NewEarth AI — Central Hub

> AI automation agency and parent company for AI-related businesses. This repo is the central command center with cross-project awareness.

## What This Is

**NewEarth AI** is an AI automation agency focused on **logistics and PropTech**, with the following ventures:
- **NewEarth AI Agency** — AI transformation partner for businesses (core)
- **BuyBox AI / DispoDaddy** — Real estate deal analysis SaaS
- **Property Business** — AI infrastructure for real estate operations

This repo serves as the **parent hub** — aware of all clients, projects, automations, and business operations across all ventures.

### Team
- 2-person core team (Justin + partner)
- Additional partners on BuyBox AI
- Budget-conscious (~$500/mo AI tooling) but investing strategically

---

## MCP Servers (All Access)

This repo has full access to all MCP servers as the parent company hub.

| Server | Purpose | Project Scope | Token Optimization |
|--------|---------|--------------|-------------------|
| `supabase-nirvana` | Database operations | Cross-project | hookify: select-star, row-limit |
| `supabase-dispodaddy` | BuyBox AI / DispoDaddy DB | BuyBox AI | hookify: select-star, row-limit |
| `supabase-midatlantic-home` | Property business DB | Property | hookify: select-star, row-limit |
| `supabase-newearthai` | **NewEarth AI dedicated DB** | **Agency Hub** | hookify: select-star, row-limit |
| `n8n-mcp-newearthai` | Agency n8n (all clients/projects) | **Primary** | hookify: executions-full, optimizer, essentials |
| `n8n-mcp-honeybird` | Partner's n8n (BuyBox AI automations) | BuyBox AI | hookify: executions-full, optimizer, essentials |
| `redis-nirvana` | Key-value storage | Cross-project | - |
| `airtable-mcp-newearthai` | Airtable (legacy, migrating to ClickUp) | Agency | - |
| `Context7` | Library documentation | Development | - |
| `make` | Make.com scenarios | Cross-project | - |
| `github` | GitHub operations (NewEarth AI account) | All repos | hookify: file-contents |
| `playwright` | Browser automation | Testing/scraping | hookify: full-page |
| `chrome-devtools` | Browser DevTools | Debugging | - |
| `wassenger` | WhatsApp automations | Client comms | - |
| `n8n-workflows_Docs` | n8n documentation/code search | Development | - |

---

## Core Architecture

### Pattern: AI-Augmented Data Pipeline
```
Ingest → Classify (AI) → Process → Correlate → Present/Report
```

- **Deterministic pipelines** with AI at key decision points (not everywhere)
- **n8n** is the central nervous system (all client automations, internal ops)
- **Supabase** is the data layer (storage, RPCs, edge functions)
- **OpenAI/LangChain** for classification, analysis, decision-making
- **Lovable.dev** for frontend dashboards and UIs
- **Claude Code** is the deployment tool (pushes to all platforms via MCP)

### Trigger Types
Webhooks, email, WhatsApp (Wassenger), cron, manual, Supabase triggers, edge function calls

### Output Types
Gmail reports, dashboards (Lovable), WhatsApp messages, frontend updates, Supabase data

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Database** | Supabase (3 instances) |
| **Automations** | n8n (2 instances), Make.com |
| **Frontend** | Lovable.dev, Next.js, Tailwind |
| **AI/ML** | OpenAI, LangChain, Mistral (OCR), Claude |
| **Comms** | Wassenger (WhatsApp), Gmail |
| **PM/Ops** | Airtable → ClickUp (migrating), Google Drive |
| **DevTools** | GitHub, Claude Code, Playwright |
| **Cache/KV** | Redis |

### Future Interests
- RAG implementations
- Temporal knowledge graphs
- Archon for managing MCP credentials
- AI maturity audits as a service offering

---

## Business Domain

### Core Entities
| Entity | Description | Status |
|--------|------------|--------|
| **NewEarth AI (Business)** | The agency itself — KPIs, financials, operations | Formalizing |
| **Clients** | Agency clients — contact, contracts, project status, AI maturity | 2 active + growing |
| **Projects** | Client deliverables — automations, dashboards, integrations | Multiple per client |
| **Automations/Workflows** | n8n workflows, Make scenarios, edge functions | 50+ active |
| **Revenue/Costs** | Financial tracking across all ventures | Needs consolidation |

### Client Lifecycle
```
Lead → Discovery → Scope/AI Audit → Build/Automate → Deliver → Monitor → Iterate
```
Currently informal (word-of-mouth), actively formalizing all stages.

### Agency Focus
- **Logistics** — supply chain and operations automation
- **PropTech** — real estate deal analysis, transaction coordination, investor matching
- **AI Transformation** — AI maturity audits → custom proposals → implementation

### Project States (Hybrid Kanban/Pipeline)
`Backlog → Scoping → In Progress → Testing → Live → Monitoring`

---

## Vault Context (Layer 0)

Durable second-brain markdown lives in the parent NewEarth AI monorepo at `Agency-Main/agency/vault/01 - Projects/{project-slug}/`. When you clone this template for a new project, replace `{project-slug}` with your project's lowercase-kebab name (e.g., `buybox-ai`, `nirvana-freight`, `goodbuy-properties`). **Always check `Agency-Main/agency/memory/` for cross-project strategy notes; read its MEMORY.md first.** For human-curated thinking (atomic notes, daily logs, MOCs, decisions), see `Agency-Main/agency/vault/README.md` for the rule table on `shared/` vs `personal/{user}/` vs `daily/{user}/`. Wikilinks ARE part of the agent retrieval path via `vault-sync.sh` → `knowledge_items` → `/trace` `/drift` `/emerge` `/graduate` `/challenge` `/vault-sync` `/vault-review` skills. Community graph plugins (Graphify-the-plugin, Excalibrain, Juggl) are SKIP for the agent stack — vault graph view is human-only.

---

## Documentation Structure

| Path | Contents |
|------|----------|
| `docs/` | Architecture, branding, API docs |
| `specs/` | Implementation specs (vision, domain model, calculations) |
| `ai_docs/` | Technology documentation cache |
| `.claude/skills/` | Reusable knowledge (6 skills) |
| `.claude/commands/` | Slash commands (5 commands) |
| `.claude/agents/` | Sub-agent definitions (13 agents) |

---

## Mandatory Skills

**ALWAYS invoke before relevant MCP operations:**

| Skill | When to Use |
|-------|-------------|
| `mcp-token-optimizer` | Before ANY MCP call — 80-95% token savings |
| `progressive-disclosure` | Exploring data/codebases — 3-tier loading |
| `n8n-data-flow-integrity` | Modifying n8n workflows — prevents silent breakage |

---

## Hookify Rules (Active)

All rules in `.claude/hookify.*.local.md`:

| Rule | Trigger | Savings |
|------|---------|---------|
| `supabase-select-star` | `SELECT *` in execute_sql | 60-80% |
| `supabase-row-limit` | Missing LIMIT on queries | 40-60% |
| `n8n-executions-full` | `mode: 'full'` in n8n_executions | 80-90% |
| `n8n-mcp-optimizer` | Inefficient n8n MCP patterns | 60-80% |
| `n8n-use-essentials` | Using full node info vs essentials | 70-85% |
| `github-file-contents` | Fetching whole files via MCP | 70-90% |
| `playwright-full-page` | `fullPage: true` screenshots | 50-80% |

---

## Critical Debug References

| Symptom | First Check | Hookify Rule |
|---------|-------------|--------------|
| Supabase response huge | Using `SELECT *`? | `supabase-select-star` |
| n8n execution bloated | Mode is `full`? | `n8n-executions-full` |
| GitHub fetch slow | Fetching whole file? | `github-file-contents` |
| Screenshot massive | Using `fullPage: true`? | `playwright-full-page` |

**Resolution pattern**: Use minimal mode first → escalate only if needed

---

## Available Commands

| Command | Purpose |
|---------|---------|
| `/setup` | Guided project setup |
| `/prime` | Test Claude's understanding of the project |
| `/plan "task"` | Create implementation spec in `specs/` |
| `/agentresearch` | Spawn coordinated research agent teams |
| `/dashboard-health` | Run dashboard health verification |

---

## Conventions

- **Database**: snake_case (Supabase standard)
- **Code**: Platform-appropriate best practices
- **Priority**: Strategic alignment with business goals and client needs over rigid conventions
- **Approach**: Effective, minimalistic, best-practice-driven per platform

---

## Deployment

All changes deployed via Claude Code → MCP:
- **Supabase**: MCP `execute_sql`, `apply_migration`, edge function deployment
- **n8n**: MCP or API, saved and published with hookify skills
- **Lovable**: Push to GitHub → Lovable auto-deploys (manual "Update" click)
- **General**: Direct platform changes via Claude Code using appropriate MCP tools

---

## Current Pain Points (Active)

1. **No central visibility** — Can't see status across all clients/projects in one place
2. **Manual processes** — Too many things still require manual intervention
3. **Data scattered** — Info spread across Airtable, Supabase, Google Drive, n8n
4. **No formalized client lifecycle** — Onboarding, scoping, delivery not standardized
5. **No dedicated NewEarth AI database** — Need a Supabase project for agency-level data

---

## Don't Do

- **Never** use `SELECT *` — always specify columns
- **Never** use `mode: 'full'` for n8n executions without trying minimal modes first
- **Never** fetch entire files when tree API or targeted reads suffice
- **Never** take full-page screenshots when viewport/element screenshots work
- **Never** assume a single Supabase instance — check which project context you're in

---

## Cross-Project Repos

This parent repo should be aware of and can reference:
- Client project repos (each has their own CLAUDE.md)
- BuyBox AI / DispoDaddy repo
- Property business repos

Use GitHub MCP to inspect other repos when cross-project context is needed.
