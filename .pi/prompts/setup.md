---
description: Guided project setup for pi — the identical twin of Claude Code's /setup, wired for pi
argument-hint: "[quick|full]"
---

> **This is the pi twin of `/setup`.** The interview, the destination, the
> roadmap, and every output file are identical to the Claude Code version — those
> files are shared, and pi reads `CLAUDE.md` via the `load-claude-md` extension.
> The ONE structural difference is the environment wiring in Step 7.5: pi uses its
> pre-installed `.pi/extensions/` guard layer instead of Claude Code's
> `settings.local.json` hooks. Wherever a step below names a Claude Code specific
> (the hookify plugin, `settings.local.json`, `/prime`), pi's equivalent is
> already in place — the `hookify-loader` extension, `.pi/` config, and the ported
> `prime` prompt — so follow the step as written and substitute accordingly.

# Setup

Guided project setup that systematically builds Claude's deep understanding across 7 dimensions + MCP optimization.

## Overview

This command walks you through a structured interview to populate CLAUDE.md, configure MCP token optimization, and create a fully context-aware development environment.

**Time**: 15-45 minutes depending on depth
**Output**: Populated CLAUDE.md, specs/, docs/, configured hookify rules

## Arguments

- `$ARGUMENTS` — Optional: "quick" for 5-minute setup, "full" for comprehensive

## Workflow

### Step 0: Determine Depth & Setup Prerequisites

**0.0 Offer the welcome deck (fresh projects):**
If CLAUDE.md is still the unconfigured placeholder, tell the user they can open
📊 `docs/welcome-deck.html` in any browser for a 12-slide tour of what they're
about to set up (and why), then ask if they'd like to view it before continuing.
Don't block — proceed as soon as they're ready.

**0.1 Check for hookify plugin:**
```bash
# Check if hookify plugin exists
ls ~/.claude/plugins/cache/claude-code-plugins/hookify/ 2>/dev/null
```

IF hookify NOT found:
  - INFORM user: "The hookify plugin is recommended for MCP token optimization (auto-warns on inefficient calls). It's part of claude-code-plugins."
  - ASK: "Would you like me to guide you through installing it? (Y/n)"
  - IF yes: Guide user to run `/install-plugins` or add to settings

**0.2 Determine depth:**
IF arguments contain "quick":
  - RUN Quick Context flow (5 questions)
  - SKIP to Step 8

IF arguments contain "full" OR no arguments:
  - RUN Full Setup flow (all 7 phases)

---

### Step 1: Vision & Strategy

ASK user with AskUserQuestion tool:

**Question 1.1**: "In one sentence, what problem does this project solve and for whom?"

**Question 1.2**: "What does success look like in 3-6 months? (Be specific — metrics, outcomes)"

**Question 1.3**: "What are we explicitly NOT building, even if it seems related?"

**Question 1.4**: "What constraints should I know about? (Budget, timeline, tech requirements, regulatory)"

STORE answers for CLAUDE.md population.

---

### Step 1.5: Project Type Gate — Strategic Intelligence Eligibility

This step decides whether to activate the Strategic Intelligence (SI) layer — competitor analysis, positioning doc, SWOT tooling, decisions-log. Not every project needs it. Most client automation/internal-tooling work does NOT; SaaS ventures, agencies, and marketing-focused client work DO.

ASK user (AskUserQuestion tool):

**Question 1.5.1**: "What kind of project is this? This determines whether we set up Strategic Intelligence infrastructure (competitor analysis, positioning, SWOT tooling) or skip it."

Options:
- (a) **SaaS / product venture** — your own product we're building and selling
- (b) **Agency** — your own service business (needs CI to position vs alternatives)
- (c) **Client project — marketing / positioning / competitive work** — the client needs market positioning and we're helping them find their edge
- (d) **Client project — automation, process, or internal tooling** — we're automating the client's ops, no CI needed
- (e) **Internal tool** — for your own team/ops only, no CI needed
- (f) **Not sure / hybrid** — explain and we'll decide together

STORE answer as `project_type`.

Set flag `SI_ENABLED`:
- (a), (b), (c) → `SI_ENABLED=true`
- (d), (e) → `SI_ENABLED=false`
- (f) → ask clarifying follow-up, then set based on response

IF `SI_ENABLED=true`:
  STORE `si_subject` based on project_type:
  - (a) or (b): `si_subject=our_own` — positioning + our-profile describe US
  - (c): `si_subject=client` — positioning + our-profile describe THE CLIENT we're helping

  Ask follow-up **Question 1.5.2**: "Who are 1-3 known competitors for this market, if any? (Leave blank to discover later.)" — store for Step 7.8 stub pre-seeding.

IF `SI_ENABLED=false`:
  INFORM: "No Strategic Intelligence scaffolding will be created. The `competitive-intelligence` skill stays installed but dormant — you can scaffold later by typing 'set up strategic intelligence' when relevant."

---

### Step 2: Domain Model

ASK user:

**Question 2.1**: "What are the 3-5 most important entities this system manages? (e.g., Users, Orders, Products)"

For each entity mentioned, ASK:
- "What are the key properties of {{entity}}?"
- "What states can {{entity}} be in?"

**Question 2.2**: "How do these entities relate to each other?"

**Question 2.3**: "Walk me through the most important user journey or data flow."

STORE answers.

---

### Step 3: Technical Stack

ASK user:

**Question 3.1**: "What's your tech stack?"

Provide options:
- Database: Supabase / Postgres / Firebase / MongoDB / Other
- Backend: Node / Python / Edge Functions / Go / Other
- Frontend: React / Vue / Next.js / None / Other
- Workflows: n8n / Zapier / Temporal / None / Other

**Question 3.2**: "Do you have MCP servers configured for any services?"

IF user has MCP servers:
  - RUN discovery commands (list_tables, list_workflows)
  - STORE discovered schema/workflows

**Question 3.3**: "What's the repo structure? Main directories?"

---

### Step 4: Architecture

ASK user:

**Question 4.1**: "At a high level, what are the main components and how do they interact?"

**Question 4.2**: "How do components communicate? (REST, GraphQL, webhooks, queues)"

**Question 4.3**: "For a typical request, trace the data from entry to storage and back."

STORE answers.

---

### Step 5: Data Pipelines

ASK user:

**Question 5.1**: "What are all the sources of data entering your system?"

**Question 5.2**: "What transformations or enrichments happen to the data?"

**Question 5.3**: "What are the 5-10 most important database tables?"

**Question 5.4**: "What automated workflows are critical to operations?"

IF MCP servers available:
  - SUPPLEMENT with discovered tables/workflows
  - ASK user to confirm/annotate

---

### Step 6: Conventions

ASK user:

**Question 6.1**: "What naming conventions do you use? (database, code, files)"

Provide defaults:
- Database: snake_case
- Variables: camelCase
- Components: PascalCase
- Files: kebab-case

**Question 6.2**: "What's your git workflow? (branch naming, commit format)"

---

### Step 7: Operational Context

ASK user:

**Question 7.1**: "How do you deploy changes?"

**Question 7.2**: "How do you monitor for issues and debug problems?"

**Question 7.3**: "What are the current known issues or technical debt?"

---

### Step 7.5: pi Environment Wiring (the pi equivalent of Claude Code's hook + permission setup)

> **This is the ONLY part that differs from Claude Code's `/setup`.** Claude Code
> registers hooks in `settings.local.json`; pi ships its guard layer as
> pre-installed **extensions** in `.pi/extensions/`. Everything else in this
> wizard — the interview, the destination, the roadmap, the output files — is
> identical, because those files (`CLAUDE.md`, `DESTINATION.md`, `ROADMAP.md`,
> `specs/`) are shared and pi reads `CLAUDE.md` via the `load-claude-md` extension.

**7.5.1 Verify the pi scaffolding (shipped with the template):**

```bash
ls .pi/extensions/*.ts | wc -l   # expect ~25 — the ported guard layer
ls .pi/settings.json             # skills + prompts + extensions config
cat .pi/mcp.json                 # valid JSON (MCP servers wired in 7.5.2)
```

IF `.pi/` is missing or extensions < 20: the template pull was incomplete —
run `/update-latest`, or run the `pi-migration` skill for a full port.

**7.5.2 Wire MCP servers into `.pi/mcp.json`:**

pi reads MCP config from `.pi/mcp.json` (project-local) or `~/.pi/agent/mcp.json`
(global). If the user already configured MCP for Claude Code:

```bash
cat .claude/settings.local.json 2>/dev/null | jq '.mcpServers // empty'
```

IF servers exist: copy them into `.pi/mcp.json` in the same `{ "mcpServers": { ... } }`
shape. IF not: leave `.pi/mcp.json` as `{ "mcpServers": {} }` and tell the user to
run `bootstrap.sh` (it writes `~/.mcp.json`, which they can mirror into
`.pi/mcp.json`) or configure manually. NEVER write a real token into a tracked file.

**7.5.3 Verify the extensions load:**

```bash
pi -e .pi/extensions/tool-guards.ts -e .pi/extensions/hookify-loader.ts -p "What extensions did you load?" 2>&1
```

The `hookify-loader.ts` extension reads every `.claude/hookify.*.local.md` rule
automatically — the token-saver and safety guards carry over with no extra wiring.

**7.5.4 Link the skills into `.pi/skills/`:**

pi discovers skills from `.pi/skills/` (per `.pi/settings.json`). Link them from
the shared `.claude/skills/` — symlink the plain ones, copy + tool-rename the ones
that call MCP tools (`server_tool` → `server_tool`):

```bash
mkdir -p .pi/skills
for d in .claude/skills/*/; do
  n=$(basename "$d"); t=".pi/skills/$n"; [ -e "$t" ] && continue
  if grep -q 'mcp__' "$d/SKILL.md" 2>/dev/null; then
    cp -r "$d" "$t"
    find "$t" -type f \( -name '*.md' -o -name '*.sh' \) -exec sed -i '' 's/mcp__\([a-zA-Z0-9-]*\)__/\1_/g' {} \;
  else
    ln -s "../../.claude/skills/$n" "$t"
  fi
done
ls .pi/skills | wc -l   # should match .claude/skills count
```

### Step 7.6: Daily-plan, sessions, and template tracking (shared with Claude Code)

These steps are identical to Claude Code's `/setup` — the same files, read by both tools.

**7.6.1 Configure the daily-plan North Star (same questions as Claude Code):**

ASK the user (5 steps), then write the answers into
`.claude/skills/daily-plan-generator/SKILL.md` frontmatter:

- **Primary NSM**: "What is the single most important metric for this project?" → its current value → its target.
- **Domains**: "Does this project span multiple domains? List them, or say 'single domain'." For each, "what one number measures success in this domain?"
- **Traceability**: for each domain NSM, confirm a causal arrow to the Primary NSM.

Write `nsm_label`, `nsm_current`, `nsm_target` into the skill frontmatter.

**7.6.2 Create session directories + template-source tracking:**

```bash
mkdir -p .claude/sessions .claude/daily-plans
```

Write `.claude/template-source.md` so `/update-latest` and `/push-to-template`
know where the upstream template lives (repo URL + last-sync date).

**7.6.3 (No hook registration step.)** Unlike Claude Code, pi needs no
`settings.local.json` hook wiring — the guard layer is the pre-installed
`.pi/extensions/`. This is the deliberate, only structural difference.

### Step 7.7: ROADMAP Creation Wizard

The ROADMAP is the engine that drives `/daily-plan`. This step creates a proper outcome-oriented
ROADMAP.md using the PR/FAQ approach — start with what "done" looks like, work backwards.

**7.7.0 Author the destination (DESTINATION.md) — runs first**

Before the PR/FAQ headline, invoke the `/define-destination` skill with
`invoked_by: setup_wizard` and `project_scope` built from the Step 1 answers. It
walks the validated six-part recipe (a three-way scope gate plus five content
elements) and writes `DESTINATION.md` at the project root — the single source of
truth for what success looks like.

- If the scope gate returns **no-forever** (open-ended exploration with no
  measurable end-state), `/define-destination` writes no file and redirects to
  the framing-audit skills; the ROADMAP's End State then carries the prose
  outcomes from 7.7.1 below, and the wizard continues.
- If it returns **yes** or **not-yet**, `DESTINATION.md` exists; 7.7.1 below
  draws the PR/FAQ headline and measurable outcomes FROM it rather than
  re-asking them loose.

`DESTINATION.md` is per-project content — never templatised, never copied
between repos. Only the `define-destination` skill propagates.

**7.7.1 PR/FAQ — What does success look like?**

ASK user (build on answers from Step 1; where `DESTINATION.md` was written in
7.7.0, draw the headline and measurable outcomes from it rather than re-asking):

**Question 7.7.1**: "Imagine it's 6 months from now and this system is working perfectly. Write the headline."

**Question 7.7.2**: "What are the 3-5 measurable outcomes that prove success?"

**Question 7.7.3**: "What's the single number that, if it went up, would prove the whole system is working?"

**7.7.2 Build the lanes:**

**Question 7.7.4**: "What are you working on RIGHT NOW (next 2-4 weeks)? List 2-3 items."

**Question 7.7.5**: "What's NEXT after that (next 1-3 months)? List 3-5 items."

**Question 7.7.6**: "What's the LATER horizon (3-6 months, directional not committed)? List 2-4 items."

**Question 7.7.7**: "What are big bets or future possibilities you're not ready to commit to yet?"

**7.7.3 Generate ROADMAP.md** from the answers (4-lane + NSM header + lanes).
Where `DESTINATION.md` exists, the ROADMAP's End State / "Done When" cell for the
project is a pointer — `→ see DESTINATION.md` — not a duplicated prose end-state.
`DESTINATION.md` is the single source of truth; the ROADMAP End State is its index.

---

### Step 7.8: Strategic Intelligence Setup (conditional on `SI_ENABLED=true`)

**SKIP THIS STEP entirely if `SI_ENABLED=false` from Step 1.5.**

This step seeds the Strategic Intelligence skeleton — positioning, our-profile, competitor catalog — so the `competitive-intelligence` skill has a grounded reference point for its first research run. Without this seeding, the first competitor profile's "Differentiation Hypothesis" would cross-reference empty positioning and output generic, ungrounded analysis (the circular dependency documented in SI skeleton design §D5).

**7.8.1 Scaffold the SI skeleton:**

Invoke the `competitive-intelligence` skill's Phase 0.4 scaffold action. This copies the 7 bundled templates into:

```
strategy/
├── competitive-intel/
│   ├── _template-competitor-profile.md
│   ├── _rubric-definitions.md
│   ├── _research-runbook.md
│   ├── _swot-rollup-template.md
│   ├── README.md                      (catalog index)
│   ├── direct/ indirect/ adjacent/    (empty, populated as profiles are researched)
│   ├── swot-rollups/ tracking/ related/
├── our-profile.md                     (placeholder, filled by 7.8.3)
├── positioning/README.md              (placeholder, filled by 7.8.4)
└── decisions-log.md                   (empty append-only log)
```

Reference: `.claude/skills/competitive-intelligence/templates/SCAFFOLD-MANIFEST.md`.

**7.8.2 Decide the subject:**

`si_subject` was set in Step 1.5:
- `si_subject=our_own` (project types a, b): positioning + our-profile describe US
- `si_subject=client` (project type c): positioning + our-profile describe THE CLIENT

For `si_subject=client`, reframe Questions 7.8.3–7.8.4 to ask about the client, not about the user's own company.

**7.8.3 Seed `strategy/our-profile.md` — reuse existing setup answers:**

Draft `our-profile.md` by mapping answers already collected:

| Template field | Source |
|----------------|--------|
| `name` | Project name (from CLAUDE.md) |
| `type` (saas-venture / agency / client-marketing / other) | Derived from `project_type` |
| One-line identity | Q1.1 "what problem does this project solve and for whom" |
| Primary JTBD | Q1.1 + Q2.3 (user journey) |
| Target personas | Q2.1 entities (filter for user-facing) |
| Differentiators (Our Moat) | Q1.3 (what we're NOT building) inverse + Q4.1 (components) unique capabilities |
| Non-differentiators | Q1.3 (what we're explicitly NOT building) |
| Current traction signals | Q7.7.2 outcome metrics (if live) |
| GTM motion | ASK follow-up **Question 7.8.3.1**: "How do customers find and buy this? (self-serve signup / sales-led / product-led growth / partnership-led / influencer-driven)" |
| Tech signals | Q3.1 tech stack |
| What we are NOT | Q1.3 answers (explicit non-goals reframed as positioning rejections) |
| Success definition | Q1.2 + Q7.7.2 |

WRITE `strategy/our-profile.md` from these mappings. Show the user a preview. Ask:

**Question 7.8.3.2**: "I drafted your profile from your setup answers. Does this capture who you are? (Edit inline, accept, or rewrite)"

**7.8.4 Seed `strategy/positioning/README.md` v0.1 — verbatim capture:**

Positioning is the user's voice, not a structured interview. ASK:

**Question 7.8.4.1**: "In your own words (bullets are fine, full sentences are fine — don't polish), describe your positioning thesis. Cover as many as feel relevant:
- Core thesis (what you ARE)
- Two-mode GTM (if applicable)
- Full-cycle scope (what parts of the journey you serve)
- Differentiators (your moat)
- Non-differentiators (not your battle)
- Customer promise (observable outcome)

If you already have this written down anywhere — memo, pitch deck, Twitter bio, founder tweet — just paste it."

WRITE the user's words verbatim to `strategy/positioning/README.md` under a `## v0.1 — {{YYYY-MM-DD}} (raw capture)` header. Do NOT polish or restructure. Raw voice is the asset.

If user declines or says "skip", write `v0.0 — empty placeholder` header and inform: "Seed this before running the first competitor analysis, or the CI skill will HARD-WARN you."

**7.8.5 Pre-seed competitor stubs from Question 1.5.2:**

IF user named 1-3 competitors in Question 1.5.2, create stub profiles for each:

```
strategy/competitive-intel/direct/{{competitor-slug}}.md
```

Each stub contains YAML frontmatter only (no body content yet), matching `_template-competitor-profile.md`. The stubs appear in the catalog index at `strategy/competitive-intel/README.md`.

**7.8.6 Seed `strategy/decisions-log.md`:**

Append the first entry:

```
## {{YYYY-MM-DD}} — Strategic Intelligence layer activated via /setup
**Trigger**: Project scaffolding — project_type={{project_type}}, si_subject={{si_subject}}
**Decision**: Activate SI skeleton with {{positioning version}} + {{count}} pre-seeded competitor stubs
**Alternatives considered**: SI_ENABLED=false (skipped) — rejected because {{reason from project_type}}
**Source**: /setup wizard Question 1.5
**Revisit by**: First completed competitor profile — reassess whether rubric dimensions need customization
```

**7.8.7 Update CLAUDE.md to reference `strategy/`:**

Add one line under `## Project Structure`:

```
strategy/                     # Strategic Intelligence — positioning, competitors, decisions
```

**7.8.8 Inform user of next steps:**

```
Strategic Intelligence scaffolded:
  ✓ strategy/our-profile.md — who you are (reference point for every competitor profile)
  ✓ strategy/positioning/README.md — positioning {{v0.0 | v0.1}}
  ✓ strategy/competitive-intel/ — catalog + 4 methodology templates
  ✓ strategy/decisions-log.md — strategic log (entry 1 written)
  {{IF stubs pre-seeded:}} ✓ {{count}} competitor stubs pre-seeded: {{list}}

You can now run competitive analysis at any time:
  → "Analyze {{competitor}}" — produces a full hybrid JTBD profile
  → "Generate a SWOT rollup" — runs once ≥3 profiles are complete
  → "Track competitor changes" — delta reports for ongoing monitoring
```

---

### Step 8: Generate Outputs

Based on collected answers:

1. **WRITE** `CLAUDE.md` from template with all answers populated
2. **WRITE** `specs/00_VISION.md` with strategy
3. **WRITE** `specs/01_DOMAIN_MODEL.md` with entities
4. **WRITE** `docs/00_ARCHITECTURE.md` with system design
5. IF significant pipelines exist, **WRITE** `docs/01_DATA_PIPELINES.md`
6. **WRITE** `ROADMAP.md` from Step 7.7 answers
7. `DESTINATION.md` was already written by `/define-destination` in Step 7.7.0 (unless the scope gate returned no-forever) — do NOT re-author it here

---

### Step 9: Validation

RUN `/prime` to test Claude's understanding.

ASK user: "Did I capture the project accurately? Anything to correct or add?"

IF corrections needed:
  - UPDATE relevant files
  - RE-RUN `/prime`

---

### Step 10: Next Steps

REPORT to user:

```
Setup Complete!

Files created:
- CLAUDE.md (project memory)
- ROADMAP.md (4-lane: NOW/NEXT/LATER/HORIZON + NSM header)
- DESTINATION.md (the six-part destination — what success looks like; skipped if the project is open-ended exploration)
- specs/00_VISION.md (strategy + outcomes)
- specs/01_DOMAIN_MODEL.md (entities + relationships)
- docs/00_ARCHITECTURE.md (system design)
- .claude/template-source.md (template sync tracking)

Autonomous Workflow System:
- /autovibe — autonomous end-to-end shipping (plan→council→execute→code-council→ship); autofire opt-in
- /daily-plan — run every session start
- /compress-roadmap — run when ROADMAP.md > 500 lines
- /push-to-template — contribute improvements back
- /update-latest — pull new template features
- Confident Mode — smart permissions in settings.local.json

Recommended next steps:
1. Review CLAUDE.md and ROADMAP.md for accuracy
2. Configure .mcp.json with your credentials
3. Run /prime to test Claude's understanding
4. Run /daily-plan to generate your first session plan
5. Start building!
6. Open docs/welcome-deck.html — the closing slides recap what you just built
```

After the report, point the user to 📊 `docs/welcome-deck.html` once more: the
final slides ("Here's what you've got", "Your next three steps") are a clean
recap they can revisit or share.

---

## Quick Context Flow

For `/setup quick`:

ASK these 5 questions only:

1. "In one sentence, what does this project do?"
2. "What's the tech stack? (Database, backend, frontend)"
3. "What are the 3-5 main entities?"
4. "Walk me through the main user flow."
5. "What are the current pain points or known issues?"

WRITE minimal CLAUDE.md with answers.
SKIP specs/ and docs/ generation.

---

## Report

Confirm:
- Number of files created
- Grade level recommendation
- Suggested next command (/plan or /prime)
