---
name: apply-insights
description: |
  Systematic post-/insights friction eradication engine. Run AFTER /insights to turn
  friction data into shipped, verified fixes. Audits infrastructure for free wins (dead
  hooks, orphaned rules), classifies each friction event against existing coverage, scores
  candidates by (Frequency x Severity / Effort), implements in enforcement-layer order,
  and pushes generic fixes to template. Use when: "apply insights", "eradicate friction",
  "fix insights issues", "turn insights into action", or after running /insights.
version: 1.0
classification: encoded-preference
created: 2026-03-06
validated_on:
  - "Hub repo: 104-session insights report with 22 wrong-approach, 4 tooling, 2 context-loss events"
  - "Works for any project with .claude/ infrastructure (hookify rules, shell hooks, rules files)"
  - "Template-portable via /push-to-template for cross-repo propagation"
parameters:
  - name: score_threshold
    type: number
    default: 3
    description: "Minimum impact score to implement (below this = skip)"
  - name: template_multiplier
    type: number
    default: 1.5
    description: "Score boost for template-pushable fixes (benefits all repos)"
  - name: max_implementations
    type: number
    default: 5
    description: "Cap on implementations per session (prevent scope creep)"
  - name: auto_push_template
    type: boolean
    default: false
    description: "If true, auto-run /push-to-template after implementation. If false, prompt user."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent, EnterPlanMode, ExitPlanMode, TodoWrite
---

# Apply Insights — Friction Eradication Engine

Turn `/insights` friction data into shipped fixes. 4-step orchestration:

```
AUDIT → ANALYZE → IMPLEMENT → PROPAGATE
```

Invoked by `/apply-insights` command. Run in the SAME session as `/insights` (insights data is in conversation context).

---

## Philosophy

The insights report identifies WHAT hurts. This skill determines HOW to fix it with minimum wasted motion.

Four principles:
1. **Scope first** — insights spans ALL repos; only apply fixes relevant to THIS repo
2. **Free wins first** — dead code and misconfiguration fixes cost zero design effort
3. **Score, don't guess** — quantitative ranking prevents "top 3 by vibes"
4. **Ship to template** — a fix that propagates to all repos is 1.5x more valuable than a local fix

---

## Step 1: AUDIT — Infrastructure Free Wins

Before touching insights data, audit for problems the insights report CAN'T detect. These are zero-effort, zero-design fixes.

### 1A: Shell Hook Registration Audit

```
Read .claude/settings.local.json → extract hooks{} section
Glob .claude/hooks/*.sh → list all hook scripts on disk
```

Cross-reference and classify:

| Finding | Classification | Action |
|---------|---------------|--------|
| Script exists, NOT in settings.local.json | **Dead code** | Register it immediately |
| Registered in settings.local.json, script MISSING | **Broken reference** | Remove registration or create script |
| Registered with wrong matcher/event | **Misconfigured** | Fix the matcher |
| Everything aligned | **Healthy** | No action |

### 1B: Hookify Rule Health Check

```
Glob .claude/hookify.*.local.md → all rule files
Read each → extract YAML frontmatter (enabled, event, action)
Read .claude/hookify.auto-rules.local.md → reference table
```

Cross-reference:

| Finding | Classification | Action |
|---------|---------------|--------|
| File exists, not in reference table | **Orphaned** | Add to reference table |
| In reference table, no file exists | **Phantom** | Remove from reference table |
| `enabled: false` | **Deliberately disabled** | Note but don't fix |
| File has invalid frontmatter | **Broken** | Fix YAML syntax |

### 1C: Prerequisite Check

```bash
for cmd in gh brew playwright node npx; do
  which "$cmd" 2>/dev/null && echo "$cmd: installed" || echo "$cmd: MISSING"
done
```

**Critical rule**: Do NOT attempt installation. Log missing tools as user action items and move on. This prevents wasting turns on blocked installs (Homebrew not present, permissions issues, etc.).

### 1D: Free Wins Report

```
FREE WINS AUDIT
━━━━━━━━━━━━━━━
Dead hooks:          {list or "none — all registered"}
Broken references:   {list or "none"}
Orphaned rules:      {list or "none"}
Phantom entries:     {list or "none"}
Missing prereqs:     {list or "none — all installed"}
━━━━━━━━━━━━━━━
Free wins to fix:    {count}
```

**Fix ALL free wins now.** No design decisions needed — just registration, cleanup, or frontmatter fixes.

---

## Step 2: ANALYZE — Classify Friction & Filter Suggestions

### 2-PRE: Scope Filter (Critical)

The `/insights` report aggregates friction across ALL repos and projects. This repo is only ONE of them. Before classifying anything, determine scope.

**Identify repo type:**
```
Read CLAUDE.md → determine if this is:
  - HUB repo (markdown/JSON/SQL hub, parent of client repos)
  - APP repo (TypeScript/React application)
  - CLIENT repo (client-specific automation + dashboard)
```

**Scope rules by repo type:**

| Repo Type | Accept These Friction Events | Skip These |
|-----------|------------------------------|------------|
| **Hub** | Cross-cutting (tooling, template sync, workflow patterns, operational guardrails) | App-specific UI bugs, calculator logic, frontend rendering issues |
| **App** | Bugs/friction in THIS app's domain (e.g., UI bugs, rendering issues specific to this app) | Friction from other apps, n8n workflow issues (unless this app triggers them) |
| **Client** | Client-specific automation friction, database issues for THIS client's Supabase instance | Friction from other clients, venture-specific issues |

**For EACH friction event from insights, ask:**
1. Does the event description reference THIS repo's domain, tech stack, or MCP servers?
2. Could a fix in THIS repo actually prevent this friction from recurring?
3. Is this a GENERIC pattern (wrong directory, wrong column names) that benefits everyone? → Keep regardless of repo type

**Classification:**
- **In scope** — friction happened in or is fixable from this repo
- **Generic** — friction is repo-agnostic (operational patterns, verification gaps) → always in scope
- **Out of scope** — friction is about another repo/project → skip entirely

```
SCOPE FILTER
━━━━━━━━━━━━
Repo type:       {hub / app / client}
Friction events:  {N total from insights}
  In scope:       {N} (domain match)
  Generic:        {N} (repo-agnostic patterns)
  Out of scope:   {N} (other repos — skipped)
━━━━━━━━━━━━
Proceeding with: {in_scope + generic} events
```

**Only proceed with in-scope + generic events for the rest of Step 2.**

### 2A: Friction Classification Matrix

Parse insights `friction_analysis.categories[]`. For EACH **in-scope** friction event:

1. **Assign root cause**:
   - **tooling** — missing CLI, auth failure, MCP unavailable
   - **knowledge** — wrong format, wrong columns, wrong directory
   - **verification** — claimed work not verified, silent failure
   - **approach** — started wrong, course-corrected mid-stream

2. **Check existing coverage** (search in this order — stop at first match):
   ```
   settings.local.json deny patterns → covers it?
   .claude/hooks/*.sh scripts → covers it?
   .claude/hookify.*.local.md rules → covers it?
   .claude/rules/*.md files → covers it?
   CLAUDE.md → covers it?
   ```

3. **Classify the gap**:
   - **none** = nothing addresses this friction
   - **partial** = something exists but doesn't fully cover the case
   - **broken** = coverage exists but isn't working (dead hooks, wrong matcher)

Output matrix:

| # | Friction Event | Root Cause | Freq | Existing Coverage | Gap |
|---|---------------|-----------|------|-------------------|-----|
| 1 | {from insights} | {category} | {N} | {what covers it, or "none"} | {none/partial/broken} |

### 2B: Suggestion Filtering

For each `suggestions.claude_md_additions[]`:

**Scope filter** — reject instantly if:
- Suggestion is about a DIFFERENT repo's domain (e.g., "use {{other_project}} for queries" in this repo) → **SKIP**
- References TypeScript/npm/build and repo has no `package.json` → **SKIP**
- References MCP server not in `.mcp.json` → **SKIP**
- Content already in CLAUDE.md or `.claude/rules/` → **SKIP (covered)**

**Placement decision** (if not skipped):
- Ambient context every session → `.claude/rules/` file
- Hard constraint ("never do X") → hookify rule or shell hook
- One-liner → CLAUDE.md (check 80-100 line ceiling first)

For each `suggestions.features_to_try[]`:

**Already-using filter**:
```
Count: hookify rules, shell hooks, skills, commands, agents
```
If suggesting a feature category already heavily used → **SKIP (already using)**

**Friction-driven filter**: Does it address a specific friction event from 2A?
- Yes → keep as candidate
- No → **SKIP (nice-to-have, not friction-driven)**

For each `suggestions.on_the_horizon.opportunities[]`:

Apply two gates:
1. **Autonomy gate**: Does user prefer manual control over this? → **SKIP**
2. **Complexity gate**: Can it ship in ONE session? No → **DEFER**

### 2C: Analysis Summary

```
ANALYSIS SUMMARY
━━━━━━━━━━━━━━━━
Friction events classified:    {N}
  With no coverage:            {N} ← these become implementation candidates
  With partial coverage:       {N} ← these become upgrade candidates
  With broken coverage:        {N} ← already fixed in Step 1 (free wins)
  Already covered:             {N} ← no action needed

Suggestions evaluated:         {N}
  Accepted as candidates:      {N}
  Skipped (already covered):   {N}
  Skipped (wrong stack):       {N}
  Skipped (not friction-driven): {N}
  Deferred (too complex):      {N}
```

---

## Step 3: IMPLEMENT — Score, Approve, Build

### 3A: Impact Scoring

For each candidate from Step 2 (gaps with no/partial coverage + accepted suggestions):

| Candidate | Freq | Sev | Effort | Template? | Score |
|-----------|------|-----|--------|-----------|-------|
| {name} | {N} | {1-3} | {1-3} | {y/n} | {calc} |

**Formula**: `Score = (Frequency × Severity) ÷ Effort × (Template ? {{template_multiplier}} : 1.0)`

- **Frequency**: raw event count from insights
- **Severity**: 3 = >10min waste per occurrence, 2 = 2-10min, 1 = <2min
- **Effort**: 1 = config/registration, 2 = new file, 3 = multi-file + testing
- **Template multiplier**: `{{template_multiplier}}` (default 1.5)

Sort descending. Apply `{{score_threshold}}` cutoff. Cap at `{{max_implementations}}`.

### 3B: Present for Approval

```
IMPLEMENTATION PLAN (ranked by impact)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#1 [{score}] {name}
   Fixes: {friction events addressed}
   Layer: {settings.json / shell hook / hookify rule / rules file}
   Effort: {trivial/moderate/complex}
   Template: {yes/no}

#2 [{score}] {name} ...

BELOW THRESHOLD (score < {{score_threshold}}):
- {name}: {score} — {reason}

USER ACTION ITEMS (cannot automate):
- {prerequisite installs, auth config, etc.}

DEFERRED (too complex for one session):
- {name}: {reason}
```

**Enter plan mode.** Get user approval before implementing.

### 3C: Enforcement Layer Decision Tree

For each approved implementation, select the cheapest effective layer:

```
Is this a HARD BLOCK (must never happen)?
├── YES: Can it be caught by command pattern matching?
│   ├── YES → Layer 1: settings.local.json deny pattern (0 tokens)
│   └── NO: Does it need input inspection (JSON/SQL parsing)?
│       ├── YES → Layer 2: Shell hook with exit 2 (0 tokens on pass)
│       └── NO → Layer 3: Hookify rule with action: block
└── NO: Is this behavioral guidance?
    ├── Needs checklist before proceeding → Layer 3: Hookify warn/addContext
    └── Ambient knowledge every session → Layer 4: Rules file (.claude/rules/)
```

**Rule**: If a hard block can be done at Layer 1 or 2, NEVER use Layer 3 or 4.

### 3D: Build Each Implementation

For each, in score order:

1. Create or modify the file
2. **If shell hook**: register in `settings.local.json` hooks section
3. **If hookify rule**: add row to `hookify.auto-rules.local.md` reference table
4. **If rules file**: check CLAUDE.md isn't duplicating — deduplicate if needed
5. **Verify** (see verification protocol below)
6. **Commit** this single implementation (granular rollback)

### 3E: Verification Protocol

| Layer | Verification Method |
|-------|-------------------|
| settings.local.json deny | Attempt the denied command — should be auto-blocked |
| Shell hook | Pipe test JSON to stdin: `echo '{"tool_input":{"command":"test"}}' \| bash .claude/hooks/{{hook}}.sh` — check exit code |
| Hookify rule | Verify: file exists, YAML frontmatter parses, event/action fields valid |
| Rules file | File exists, no YAML syntax errors, content loads without truncation |

**After all implementations**: Run `/verify-hooks` for full-system validation.

---

## Step 4: PROPAGATE — Template Push & Impact Report

### 4A: Classify Each Implementation

| Implementation | Template-pushable? | Reason |
|---|---|---|
| {name} | Yes | Generic — works in any project |
| {name} | No | Contains project-specific content (MCP names, table names, etc.) |

### 4B: Generalize Template-Pushable Fixes

Before pushing, strip project-specific content:
- `mcp__supabase-{{project}}__*` → `mcp__supabase-.*__*`
- `mcp__n8n-mcp-{{instance}}__*` → `mcp__n8n-mcp-.*__*`
- Client slugs, API keys, workflow IDs → remove or `{{placeholder}}`
- Project-specific rules → omit from template version

### 4C: Update Template Infrastructure

- Add new files to `template-source.md` TEMPLATE-MANAGED table
- Add to `.github/propagation.json` `auto_safe` list (if auto-propagation exists)
- Update `/verify-hooks` expected minimum set (if new hooks added)

### 4D: Push

If `{{auto_push_template}}`: run `/push-to-template` automatically.
Otherwise: prompt user — "Push {N} template-pushable fixes to template? (y/n)"

### 4E: Projected Impact Report

```
PROJECTED IMPACT ON NEXT /insights
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Category                     Before   Expected   Mechanism
───────────────────────────  ───────  ─────────  ──────────
{friction category}          {N}      {est.}     {what we shipped}
{friction category}          {N}      {est.}     {what we shipped}

STILL OPEN (user action needed):
- [ ] {prereq install}
- [ ] {auth configuration}

TEMPLATE PROPAGATION:
- {N} fixes → template → auto-PRs in {downstream repos}
- Expected improvement in downstream repos: {categories}

VERIFICATION:
- /verify-hooks: {PASS/not run}
- Free wins fixed: {N}
- Implementations shipped: {N}
- Template files pushed: {N}
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Jump to implementing suggestions without auditing infrastructure first | Misses free wins (dead hooks cost 0 effort to activate) | Always run Step 1 AUDIT before touching insights data |
| Attempt to install missing prerequisites (brew, gh) | Wastes turns on blocked installs, permission issues | Log as user action item, skip, move on |
| Evaluate "On the Horizon" suggestions at length | These are multi-session projects that can't ship today | Apply autonomy gate + complexity gate → skip or defer in seconds |
| Implement all suggestions regardless of score | Low-impact fixes waste session budget | Apply score threshold; cap at `{{max_implementations}}` |
| Use hookify rules for things settings.json can block | Wastes 50-400 tokens per invocation when 0-token enforcement exists | Always choose cheapest effective enforcement layer |
| One big commit at the end | Can't rollback individual fixes if one causes issues | Commit after each implementation |
| Push project-specific content to template | Breaks downstream repos with wrong MCP names, table names | Generalize before pushing; when in doubt, keep local |
| Skip the projected impact report | No way to measure if the work actually improved things | Always produce before/after projections for accountability |
| Apply ALL insights friction in every repo | Insights spans all repos; app-specific bugs don't belong in other projects' fixes | Run scope filter (Step 2-PRE) to keep only in-scope + generic events |

---

## Defaults

| Parameter | Default | Adjust When |
|-----------|---------|-------------|
| `{{score_threshold}}` | 3 | Lower for repos with few friction events; raise for large backlogs |
| `{{template_multiplier}}` | 1.5 | Raise to 2.0 if managing 5+ downstream repos |
| `{{max_implementations}}` | 5 | Lower for short sessions; raise for dedicated friction-eradication sessions |
| `{{auto_push_template}}` | false | Set true after you trust the generalization step |

---

## Validation

This skill works for:
- Any project with `.claude/` infrastructure (hookify rules, shell hooks, rules files)
- Any `/insights` report output (parses standard friction_analysis, suggestions JSON structure)
- Single-repo projects (skip Step 4 template propagation)
- Multi-repo template systems (full Step 4 propagation)
- New projects with minimal infrastructure (Step 1 audit finds what exists)
