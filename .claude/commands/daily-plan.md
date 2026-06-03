# /daily-plan

Your daily work plan — generates once, resumes on repeat calls. Optionally integrates journal/diary photos.

**Invokes**: `daily-plan-generator` skill (v5.0)

---

## What Happens

**Phase 0 — Session Housekeeping** (runs first, every time):
0A. Checks if previous sessions left uncommitted/unpushed work → offers to commit + push so all Macs stay in sync
0B. Syncs recent git commits to roadmap activity table → admin portal feed stays current (requires `roadmap_activity_table` parameter)
0C. Pulls latest from `origin/main` → picks up work done on other Macs before planning

**First call of the day** (no plan file exists):
1. **Journal Detection**: If you submitted photos or notes alongside the command, reads them (OCR for handwritten pages), extracts insights, classifies by project
2. **Journal Distribution** (Agency-Main only): Auto-pushes project-specific journal insights to relevant repos via GitHub MCP
3. Reads ROADMAP.md System/Project/Milestone hierarchy, git log + git diff, yesterday's plan, last session
4. Checks Obsidian Vault Pulse — pending deposits, overdue /drift, /emerge, /vault-review cadences
5. **Journal × Plan Arbitration**: Cross-references journal insights against AI plan. Each insight classified as NEW INTELLIGENCE, CONFIRMS PLAN, ALREADY HANDLED, SUPERSEDES PLAN, FUTURE SIGNAL, or NEEDS RESEARCH
6. Silently checks strategic alignment (10A — surface at most 1 concern if warranted)
7. Scores and ranks work items by NSM impact × urgency, including journal-sourced items
8. Writes `.claude/daily-plans/PLAN-{today}.md` with full hierarchy context per step + Journal × Plan Synthesis table
9. Displays summary and waits for your "go" or "go team"

**Subsequent calls** (plan already exists):
1. Runs Phase 0 housekeeping (always)
2. Reads existing plan + checks ROADMAP + recent git for completions
3. If new journal photos are submitted, processes them and re-arbitrates
4. Shows what's done, what's remaining
5. Refreshes the plan file if steps were completed since last generation
6. Waits for "go" or "go team" on remaining work

---

## Usage

### Standard (no journal)
```
/daily-plan
```

### With journal photos
Paste or drag diary/journal photos into the chat, then:
```
/daily-plan
```
The skill auto-detects images and processes them. No special syntax needed.

### With typed notes
```
/daily-plan

Also — I realized we need to revisit the deal scoring model. The geographic weighting
is off based on investor feedback yesterday. And for Nirvana: the driver app UX
needs attention, drivers are complaining about load times.
```

Any free-form text alongside the command is treated as journal input.

---

## Journal Integration

### How it works
1. You write in your physical diary/journal (meditation, thinking sessions, planning)
2. Take photos of the relevant pages
3. Paste them when you run `/daily-plan`
4. AI reads your handwriting, extracts each insight, classifies it
5. Each insight gets arbitrated against the AI-generated strategic plan
6. The result is a plan that's **strictly superior** to either source alone

### Arbitration Classifications

| Classification | What it means | What happens |
|---|---|---|
| **NEW INTELLIGENCE** | You identified a gap the AI missed | Inserted into plan with priority scoring |
| **CONFIRMS PLAN** | You independently validated an AI-planned step | Step annotated as "journal-confirmed" |
| **ALREADY HANDLED** | Plan already covers your concern | Noted — AI shows you it's covered |
| **SUPERSEDES PLAN** | Your insight makes a planned step obsolete | Plan step adjusted or removed |
| **FUTURE SIGNAL** | Valuable but not today | Deposited to Obsidian vault |
| **NEEDS RESEARCH** | You raised a question needing investigation | Research step added to plan |

### Multi-project journal entries
Your diary often covers multiple projects. When running in Agency-Main:
- Insights are auto-classified by project (buybox-ai, nirvana-freight, etc.)
- Project-specific insights are auto-pushed to those repos via GitHub
- When you later run `/daily-plan` in those repos, the journal insights are already there

### The key principle
Neither source is dominant. Your meditation insight can override AI strategy (when you have context the AI doesn't). AI strategy can show your concern is already handled (when you lack visibility into the plan). The superior signal always wins.

---

## After the plan appears

| You say | What happens |
|---------|-------------|
| `go` | Start Step 1, work through steps sequentially |
| `go team` | Spawn parallel agents for independent steps |
| Edit the plan file | Reorder/change priorities, then say `go` |

---

## Output

**Plan file**: `.claude/daily-plans/PLAN-{YYYY-MM-DD}.md`
**Journal file**: `.claude/journal/JOURNAL-{YYYY-MM-DD}.md` (only when journal input provided)

Each step shows full hierarchy context:
```
### Step N — [COMPLEXITY] Task Name
> System: Customer Operations
> Project: Order Tracking [75%] | Milestone: Real-time Status [65%]
> North Star: Every order visible without calling anyone
> Why: Order Visibility 78% → 90% — status updates close data gaps
> Action: Build StatusAccuracyCard.tsx
> Source: journal (NEW INTELLIGENCE) | ROADMAP
> Success: Hero card shows accuracy %, click opens details
```

When journal is processed, the plan also includes:
```
## Journal × Plan Synthesis
> Source: 5 journal insights (from diary photos)

| # | Journal Insight | Classification | Plan Impact |
|---|---|---|---|
| 1 | Deal scoring geographic weighting | NEW INTELLIGENCE | → Inserted as Step 2 |
| 2 | Driver app UX concern | ALREADY HANDLED | ✓ Covered by Step 4 |
| 3 | Explore Temporal.io | FUTURE SIGNAL | → Vault deposit |
```

---

## Setup

Configure your North Star Metric in `.claude/skills/daily-plan-generator/SKILL.md`.

For Agency-Main hub distribution, also set:
```yaml
journal_distribution_enabled: true
journal_distribution_targets:
  {{client-1-slug}}: "{{org}}/{{client-1-repo}}"
  {{client-2-slug}}: "{{org}}/{{client-2-repo}}"
```

---

## Related Commands

- `/compress-roadmap` — archive ROADMAP items when > 500 lines
- `/vault-review` — run overdue vault commands in one session
- `/prime` — session priming (lighter alternative for quick context)
- `/push-to-template` — propagate improvements back to the template repo

---

*Hub variant (template-managed + journal) | daily-plan-generator v5.0 | 2026-04-12*
