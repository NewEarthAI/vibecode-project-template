# The Catalogue — every tool, tiered

One page, three tiers. You do **not** need to learn 99 skills — Claude reaches
for the right one automatically. This page exists so you always know what's in
the box, what matters on day one, and what's safely ignorable until you grow
into it.

- **CORE** — the daily rhythm. You'll touch these (or they'll fire for you) in
  your first week. Installed and active by default.
- **RECOMMENDED** — wire these up when the situation applies (a database, a
  deploy, a team). `/setup` offers each at the right moment.
- **SPECIALIST** — deep tools for specific jobs. They wait quietly until asked.

> Safety hooks are **not listed as a tier — they are non-negotiable defaults.**
> Guardrails that block destructive commands are always on; the template's whole
> identity rests on them.

---

## CORE — the daily rhythm

> **Start here, day one:** `/setup` → `/prime` → `/daily-plan`, then just describe
> what you want to build in plain English. Everything else waits until you need it.

| Tool | One line |
|---|---|
| `/setup` | The run-once interview that builds your project's brain |
| `/prime` · `prime-lite` | Load project understanding (full or <2k-token brief) |
| `/daily-plan` | A ranked plan for every session |
| `/plan` → `/execute` | Spec first, build second |
| `/autovibe` · `/ship` | Autonomous shipping with guardrails |
| `/council` · `/code-council` | Structured disagreement — for decisions and for code |
| `/reduce-to-first-principles` + framing suite | "Is this the right question?" before big commitments |
| `/prompt-forge` · `/Master-Continuation-Prompt` | Hand context to a fresh session without loss |
| `caveman` + layman voice | Plain English, fewer tokens — always on |
| `/reflect` → `apply-insights` | The improvement loop: notice friction, fold in the fix |
| `/update-latest` | Pull template improvements, with a what's-new preview |

## RECOMMENDED — wire when relevant

| Situation | Tools |
|---|---|
| You use a database | `supabase-postgres-best-practices`, `postgresql-patterns`, `postgresql-code-review`, `supabase-database-hygiene`, `dev-prod` (staging-first discipline) |
| You deploy a frontend | `/deploy-vercel`, `landing-page-mvp`, `site-speed-boost`, `lovable-to-vercel-migration` |
| You build UI | `ui-design-system` (house design system), `/design-review`, `tailwind-shadcn-system`, `data-table-design`, `build-dashboard`, `kpi-dashboard-design` |
| You run parallel chats | worktree discipline, collision-detection hooks |
| You keep an Obsidian vault | `obsidian-second-brain`, `/vault-sync`, `/vault-review`, `/trace`, `/drift`, `/emerge`, `/graduate` (full recipe: `docs/OBSIDIAN-SETUP.md`) |
| You work with a team | `collab` skill, `/build-with-agent-team` |
| You ship to real users | `production-readiness-review`, `/verify-shipped`, `/e2e-test`, the security five (below) |
| Google Workspace | `gws-gmail`, `gws-calendar`, `gws-docs`, `gws-sheets`, `gws-drive`, `gws-tasks`, `gws-keep`, `gws-meet` |

## SPECIALIST — deep tools, on demand

| Theme | Tools |
|---|---|
| Security | `master-security-review`, `security-scan-agentshield`, `security-threat-model`, `saas-multi-tenant-auth`, `better-auth-security`, `safe-bash` |
| Research & analysis | `/agentresearch`, `deep-research`, `competitive-intelligence`, `/challenge`, `/decide-under-uncertainty`, `/diagnose-bottleneck`, `/define-destination` |
| Visuals & docs | `/diagram`, `/present`, `brand-visual-identity`, `guided-tour` |
| Knowledge pipeline | `ki-research`, `ki-profile`, `ki-insight`, `ki-evaluate`, `ki-apply`, `ki-vault`, `llm-wiki`, `cross-linker`, `tag-taxonomy`, `claude-history-ingest`, `skool-to-obsidian` |
| Infrastructure | `digitalocean`, `digitalocean-infra`, `ssh-claude-setup`, `grafana-dashboards`, `llm-monitoring-dashboard`, `cost-spike-diagnostic` |
| Meta / template-craft | `skill-creator`, `skill-auditor-merger`, `/push-to-template`, `pi-migration`, `refactor-claude-md`, `refactor-memory-md`, `master-code-reviewer`, `receiving-code-review` / `requesting-code-review` |

---

*Why tiers? Curation is the product. A flat list of 110 tools helps nobody;
a curated core plus honest "later" tiers is how the box stays approachable.*
