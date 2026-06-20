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

### Step 7.4: Platform & Credential Discovery (set up the MCPs / credentials / CLIs the project actually needs)

A new project may use Supabase, n8n, Make, WhatsApp, Redis, Playwright, GitHub, Telegram, a broker
API, or none. **You cannot know the project's platforms in advance — ask.** This step (1) discovers
which platforms the project uses, (2) sets up the MCP + credentials + CLI for every platform we
SUPPORT that the project uses, (3) FLAGS platforms the project uses that we have NO out-of-box
integration for, so the operator can build an equivalent, and (4) leaves platform-specific hooks
dormant for platforms not in use.

**7.4.1 — Ask which platforms the project uses** (AskUserQuestion, multiSelect):
- Database: Supabase / Postgres / Firebase / none
- Automation: n8n / Make.com / none
- Comms: Telegram / WhatsApp / email / none
- Browser automation: Playwright / Chrome DevTools / none
- Cache/KV: Redis / none
- Other (free text): e.g. a broker API / a payment processor

**7.4.2 — For each in-use platform we SUPPORT** (Supabase, n8n, Playwright, Chrome, Redis, GitHub, Context7):
- Collect the connection info and wire it to YOUR OWN instance:
  - Supabase: project ref + API URL + keys → write the `.mcp.json` Supabase server entry referencing
    keys via ENV VARS (NEVER commit a service-role key in plaintext). Note the `supabase` CLI for local dev.
  - n8n: instance URL + API key → `.mcp.json` n8n entry (key via env).
  - GitHub: confirm `gh auth status`; if not authed, guide `gh auth login`.
  - Redis / Playwright / Chrome: add the relevant `.mcp.json` entry; any API key via env.
- **Enable that platform's hooks + read-only `permissions.allow` patterns** (Step 7.6 — e.g. the
  Supabase select-star/row-limit hooks, the n8n executions-full/essentials hooks). Leave hooks for
  platforms NOT in use dormant.

**7.4.3 — For each in-use platform we do NOT support out of the box** (e.g. Telegram, a broker API):
- FLAG it plainly: "We ship no MCP/hook for {platform}. To get the same safety + token-efficiency we
  have for Supabase/n8n, an equivalent must be built (a wrapper script, an API client, or a custom hook)."
- Capture it as a NOW/NEXT item in `ROADMAP.md`.
- NEVER pretend coverage exists. A used platform with no integration AND no flag is a silent gap.

**7.4.4 — Secrets discipline.** Credentials are NEVER committed in plaintext. Use `.env` (gitignored),
the OS keychain, or `.mcp.json` env-var references. Confirm `.mcp.json` and any `.env` are gitignored.

**7.4.5 — Verify.** Run `/verify-hooks` Phase 1 (Environment Discovery): it reads `.mcp.json`, derives
the platform flags, and confirms each in-use platform has its hooks + deny coverage.

---

### Step 7.5: Hookify Architecture Configuration

The template ships 13 hookify rules. Most work immediately with wildcard matchers. This step customizes them for the specific project.

**7.5.1 Detect MCP Servers:**

Read `.mcp.json` or ask user for their configured MCP servers. Identify:
- Which Supabase project? (e.g., `supabase-myproject`)
- Which n8n instance? (e.g., `n8n-yourinstance`)
- Which other servers? (playwright, github, etc.)

**7.5.2 Tighten Wildcard Matchers (Optional but Recommended):**

Hooks ship with wildcards (`mcp__supabase-*__.*`). For precision, tighten to exact names:

| Hook | Default Matcher | Tightened Example |
|------|----------------|-------------------|
| `supabase-auto-load` | `mcp__supabase-*__.*` | `mcp__supabase-myproject__.*` |
| `supabase-smart-query` | `mcp__supabase-*__execute_sql` | `mcp__supabase-myproject__execute_sql` |
| `supabase-select-star` | `mcp__supabase-*__execute_sql` | `mcp__supabase-myproject__execute_sql` |
| `n8n-auto-load` | `mcp__n8n-mcp-*__.*` | `mcp__n8n-yourinstance__.*` |
| `n8n-fetch-blocker` | `mcp__n8n-mcp-*__n8n_get_workflow` | `mcp__n8n-yourinstance__n8n_get_workflow` |
| `n8n-update-safety` | `mcp__n8n-mcp-*__n8n_update_*` | Exact server names |
| `n8n-executions-full` | `mcp__n8n-mcp-*__n8n_executions` | Exact server name |

**7.5.3 Configure Server Guard:**

The `mcp-server-guard` hook starts DISABLED. To enable:
1. Identify ALL MCP servers the user has configured (active AND non-project)
2. Build a `tool_matcher` regex listing non-project servers to block
3. Update the hook: set `enabled: true`, replace `PLACEHOLDER_REPLACE_WITH_BLOCKED_SERVERS` with the regex
4. Update `{{ACTIVE_MCP_SERVERS}}` and `{{BLOCKED_MCP_SERVERS}}` in auto-rules, task-context-injector

Example:
```yaml
tool_matcher: mcp__redis-other__.*|mcp__supabase-other__.*|mcp__make__.*
```

**7.5.4 Configure Project-Specific Content:**

In `n8n-auto-load` hook:
- Add project-specific workflow IDs to "Key Workflow IDs" section
- Add project-specific critical fields

In `n8n-update-safety` hook:
- Replace `{{CRITICAL_FIELDS}}` with actual field names

In `supabase-auto-load` hook:
- Add project-specific RPCs to P4 section
- Add project-specific large tables

**7.5.5 Verify:**
```bash
ls .claude/hookify.*.local.md  # Should show 13+ files
bash scripts/selfcheck-safe-bash.sh  # Should pass
```

---

### Step 7.6: Autonomous Workflow System Setup

This registers the shell hooks and configures the daily planning system.

**7.6.1 Register shell hooks + confident mode in settings.local.json:**

Read `.claude/settings.local.json` — it may not exist yet (create it if needed, preserving any
existing content). Build the full settings object with BOTH shell hooks AND confident-mode permissions.

**Step A — Detect connected MCP servers:**

Check `.mcp.json` for the project's MCP server names. For each server found, generate
wildcard allow patterns for read-only operations. Common patterns:

| Server Type | Allow Pattern Examples |
|-------------|----------------------|
| Supabase | `mcp__supabase-{name}__execute_sql`, `mcp__supabase-{name}__list_*`, `mcp__supabase-{name}__get_*`, `mcp__supabase-{name}__generate_typescript_types`, `mcp__supabase-{name}__apply_migration` |
| n8n | Read-only: `mcp__n8n-*__n8n_list_*`, `mcp__n8n-*__n8n_get_*` |
| GitHub | `mcp__github__*` (all ops — GitHub has its own auth) |
| Redis | `mcp__redis-*__*` (all ops — local cache) |
| Context7 | `mcp__Context7__*` (documentation only) |
| Wassenger | Read-only: `mcp__wassenger__get_*`, `mcp__wassenger__search_*`, `mcp__wassenger__analyze_*`, `mcp__wassenger__list_*` |
| Airtable | Read-only: `mcp__airtable-*__list_*`, `mcp__airtable-*__get_*`, `mcp__airtable-*__search_*` |
| Make | `mcp__make__*` (automation platform) |
| Playwright | `mcp__playwright__*`, `mcp__plugin_playwright_playwright__*` |
| Chrome DevTools | `mcp__chrome-devtools__*` |

**Step B — Write settings.local.json:**

```json
{
  "permissions": {
    "allow": [
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "Bash(git status*)",
      "Bash(git log*)",
      "Bash(git diff*)",
      "Bash(git branch*)",
      "Bash(git add*)",
      "Bash(git commit*)",
      "Bash(git stash*)",
      "Bash(git checkout*)",
      "Bash(ls*)",
      "Bash(wc*)",
      "Bash(mkdir*)",
      "Bash(cp*)",
      "Bash(npm*)",
      "Bash(npx*)",
      "Bash(bun*)",
      "Bash(node*)",
      "Bash(cat*)",
      "Bash(head*)",
      "Bash(tail*)",
      "Bash(curl*)",
      "Bash(python3*)",
      "Bash(find*)",
      "Bash(env*)",
      "Bash(chmod*)",
      "WebFetch(*)",
      "WebSearch(*)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force*)",
      "Bash(git reset --hard*)",
      "Bash(git clean -f*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [{ "type": "command", "command": "bash .claude/hooks/sql-guardian.sh" }]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{ "type": "command", "command": "bash .claude/hooks/session-summarizer.sh" }]
      }
    ]
  }
}
```

**Step C — Add MCP server allow patterns:**

For each MCP server discovered in `.mcp.json`, add its allow patterns to the `permissions.allow`
array using the mapping from Step A.

**Step D — Register NOT-allowed MCP patterns (stay as permission prompts):**

These should NOT be added to the allow list — they require human confirmation:
- `mcp__*__deploy_edge_function` — production deployment
- `mcp__*__create_branch`, `mcp__*__merge_branch`, `mcp__*__delete_branch` — branch lifecycle
- `mcp__wassenger__send_whatsapp_message` — sends to real humans
- `mcp__wassenger__manage_whatsapp_message_interactions` — sends to real humans
- Any MCP tool that modifies external/shared state irreversibly

**Step E — Make hook scripts executable + verify:**

```bash
chmod +x .claude/hooks/sql-guardian.sh .claude/hooks/session-summarizer.sh
```

Note: `.claude/settings.local.json` is gitignored — it stays on your machine only.

**7.6.2 Configure daily-plan-generator NSM hierarchy:**

ASK user (AskUserQuestion) — 5 steps:

**Step 1 — Primary NSM:**
**Question 7.6.1**: "What is the single most important metric for this entire project?"

**Question 7.6.2**: "Current value of that metric? (e.g. '~62%', 'unknown — need baseline')"

**Question 7.6.3**: "Target value? (e.g. '90%', '5%', '70 NPS')"

**Step 2 — Domain Discovery:**
**Question 7.6.4**: "Does this project span multiple domains or departments? List them, or say 'single domain' to skip."

IF user lists domains (3-7):
  For each domain ASK:
  **Question 7.6.5**: "For [Domain X]: what is the single number that measures success in this domain?"

**Step 3 — Traceability Check (Claude validates, do not ask user):**
For each domain NSM provided, verify: "Can I draw a causal arrow from this Domain NSM to the Primary NSM?"

**Step 4 — Write NSM config into SKILL.md:**
Write answers into `.claude/skills/daily-plan-generator/SKILL.md` frontmatter.

**7.6.3 Create sessions directories:**
```bash
mkdir -p .claude/sessions .claude/daily-plans
```

**7.6.4 Create template-source.md:**
Write `.claude/template-source.md` so `/update-latest` and `/push-to-template` know where the upstream template lives.

**7.6.5 Auto-wire template-pushed hookify rules (NEW — added 2026-05-12):**

The template ships hookify rules (`.claude/hookify.*.local.md` files) that fire on specific tool events to inject doctrinal context. Most match on `Bash` (auto-wired via the wildcard PreToolUse Bash matcher in Step 7.6.1 above), but some match on OTHER tool names — these need their matchers explicitly registered in `settings.local.json` so the `hookify-context-injector.sh` runtime actually fires on those tool calls.

**Step A — Scan installed hookify rules for non-Bash matchers:**

```bash
for f in .claude/hookify.*.local.md; do
  matcher=$(awk '/^---$/{n++; if(n==2) exit; next} n==1' "$f" | grep -E '^tool_matcher:' | sed 's/^tool_matcher:[[:space:]]*//')
  event=$(awk '/^---$/{n++; if(n==2) exit; next} n==1' "$f" | grep -E '^event:' | sed 's/^event:[[:space:]]*//')
  if [[ "$matcher" != "" && "$matcher" != "Bash" && "$matcher" != "*" ]]; then
    echo "$f: event=$event matcher=$matcher"
  fi
done
```

**Step B — For each non-Bash matcher, register hookify-context-injector in settings.local.json:**

Read `.claude/settings.local.json`. For each unique (event, matcher) pair surfaced in Step A that is NOT already registered, append a new entry to the hooks object. Use Python+jq to preserve other entries:

```python
import json
path = '.claude/settings.local.json'
with open(path) as f:
    s = json.load(f)
s.setdefault('hooks', {}).setdefault(event, [])
# Check if matcher already has this script
already = any(
    e.get('matcher') == matcher
    and any('hookify-context-injector' in h['command'] for h in e.get('hooks', []))
    for e in s['hooks'][event]
)
if not already:
    s['hooks'][event].append({
        'matcher': matcher,
        'hooks': [{'type': 'command', 'command': 'bash $CLAUDE_PROJECT_DIR/.claude/hooks/hookify-context-injector.sh', 'timeout': 5}]
    })
    with open(path, 'w') as f:
        json.dump(s, f, indent=2)
```

**Step C — Known matchers that ship with the template** (as of 2026-05-12):

| Hookify rule | event | matcher | Why |
|---|---|---|---|
| `hookify.code-review-identity-load.local.md` | `PreToolUse` | `Agent` | Injects code-review-identity rule + Karpathy Razors on every Agent tool dispatch |
| `hookify.code-council-requires-artifact.local.md` | `Stop` | `Agent` | Catches PASS verdicts without verification artefacts on review-class subagents |
| (auto-extends as new template hookify rules ship) | | | |

If a hookify rule's frontmatter says `enabled: false`, do NOT register its matcher. The user can flip `enabled: true` and re-run `/setup --rewire-hookify` to activate.

**Step D — Verify the wiring**:

After Step B, simulate a tool dispatch through the chain to confirm the rule fires. For the Agent matcher:
```bash
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"silent-failure-hunter","description":"setup verification"}}' \
  | bash .claude/hooks/hookify-context-injector.sh PreToolUse 2>&1 \
  | grep -c "code-review-identity-load"
```
Expect output: `1` (the rule fired). If `0`, surface to user — the wiring is broken.

**7.6.6 Make all hook scripts executable:**

```bash
chmod +x .claude/hooks/*.sh 2>/dev/null
```

---

### Step 7.6.7: NewVibe Autonomous-Shipping Setup

NewVibe ships with the template in two layers. The **orchestration layer** —
the `/autovibe` skill (composes plan → council → execute → code-council → ship)
— works the moment the skill folder is present; nothing to wire. The
**autofire layer** is **opt-in**: after a clean ship, two hooks dispatch a fresh
Claude session that resumes the next phase of work, with no human pasting a
continuation. This step installs the orchestration layer (always) and offers to
wire autofire.

**7.6.7.1 — Confirm the orchestration layer (always installed):**

```bash
ls .claude/skills/autovibe/SKILL.md .claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh
```
If either is missing, the template pull was incomplete — re-run `/update-latest`.
`/autovibe` is now usable regardless of the autofire choice below.

**7.6.7.2 — Ask the autofire opt-in question:**

ASK user (AskUserQuestion tool):

**Question 7.6.7**: "`/autovibe` (the orchestrator) is installed and works now.
Do you also want **autofire** — after a clean ship, a fresh Claude session
launches itself to resume the next phase, no manual paste? Autofire needs an n8n
SSH-Execute dispatch substrate plus per-machine credentials."

Options:
- (a) **Enable autofire** — wires the two hooks in-repo now; then surfaces the
  operator-gated substrate + credential checklist.
- (b) **Orchestration only (recommended to start)** — `/autovibe` works fully;
  autofire skipped. Re-run `/setup` and choose (a) to enable it later.

IF (b): INFORM "Orchestration installed — `/autovibe` is ready. Autofire skipped."
→ skip to Step 7.7.

IF (a): proceed to 7.6.7.3.

**7.6.7.3 — Wire autofire in-repo (autonomous — Claude does this):**

1. **Register the two hooks** in `.claude/settings.local.json` — APPEND to the
   existing `hooks` object created in Step 7.6.1 (do NOT replace it):
   - `Stop` → `.claude/hooks/newvibe-autofire-stop.sh` (timeout 20)
   - `PreCompact` → `.claude/hooks/newvibe-precompact-handoff.sh` (timeout 20)

   Exact JSON shape: `.claude/skills/autovibe/references/newvibe-integration-guide.md` §3.

2. **Gitignore the four runtime-state files** — append to `.gitignore` if absent:
   ```
   .claude/.newvibe-autofire-armed
   .claude/phase47-log.jsonl
   .claude/ship-state.json
   .claude/autovibe-state.json
   ```
   The arm flag MUST stay ignored — committing it would arm a real autofire on
   every fresh checkout.

3. **Resolve the project slug**:
   ```bash
   bash -c 'source .claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh
            nv_resolve_paths
            echo "slug: $(nv_detect_slug "$NV_PROJECT_ROOT")"'
   ```
   - Non-empty + correct → done.
   - Empty/wrong → add a `case` arm to `nv_detect_slug` in
     `newvibe-dispatch-lib.sh` matching this repo's path, OR set
     `NEWVIBE_PROJECT_SLUG=<slug>` in the environment. The slug MUST equal the
     key used in the n8n REPO_MAP (Step 7.6.7.4). Guide §5.

4. **Verify the in-repo install** — all four harnesses must report `ALL PASS`:
   ```bash
   bash .claude/skills/autovibe/scripts/newvibe-chain-guard.sh  --self-test
   bash .claude/skills/autovibe/scripts/newvibe-dispatch-lib.sh --self-test
   bash .claude/skills/autovibe/scripts/verify-continuation.sh  --self-test
   bash .claude/skills/autovibe/scripts/newvibe-dryrun-matrix.sh
   ```

**7.6.7.4 — Surface the operator-gated checklist (autofire's environment half):**

A Claude session CANNOT self-provision this half. SURFACE it to the user — do
not attempt to automate it:

**(A) The n8n dispatch substrate + REPO_MAP**
- Autofire needs your own n8n SSH-Execute workflow that maps this repo's slug →
  `{ repo path on the target Mac, target user }`. This is DIY/advanced in v1;
  `newvibe-integration-guide.md` §7 documents the fixed dispatch contract.
  Skipping it leaves a fully working orchestration layer (autofire is an opt-in extra).

**(B) Per-machine credentials** — created on the target Mac that runs autofired
sessions; mode `600`; NEVER committed or templated:
- `~/.github_token` — a scoped GitHub token (`repo` + `workflow`)
- `~/.claude_oauth_token` — a Claude OAuth token (Keychain is unreachable from a
  non-interactive SSH session, so the token lives in a file)
- An `autossh` reverse tunnel + macOS Remote Login + a `ufw` rule for the tunnel
  port — full 6-layer walk-through in `newvibe-integration-guide.md` §7b.

INFORM the user: "Autofire wired in-repo. Until the n8n REPO_MAP entry and the
target-Mac credentials exist, autofire stays in the safe `would-dispatch`
dry-run state — correct, not broken. The first real fire is a supervised
dogfood: `touch .claude/.newvibe-autofire-armed` (single-fire), then run a small
task through `/ship pr`. Full runbook: `newvibe-integration-guide.md`."

---

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

## Setup Completion Gate (MANDATORY — run before the Report)

`/setup` is a long wizard; a run that follows the operator's ad-hoc sub-requests can jump past an
automated wiring step and still *look* finished. This gate is the backstop: it VERIFIES every
mandatory automated artefact exists before reporting done. **`/setup` is NOT complete until this gate
prints PASS.** It is idempotent. **No `eval`** — the `bash-guardian` / `sql-guardian` hooks this
wizard installs BLOCK `eval`; use the plain form below.

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fail=0
ok(){ echo "✓ $1"; }
no(){ echo "✗ $1  → $2"; fail=1; }

# --- Content artefacts ---
test -f CLAUDE.md  && ok "CLAUDE.md present"  || no "CLAUDE.md present"  "re-run Step 8 (generate CLAUDE.md)"
test -f ROADMAP.md && ok "ROADMAP.md present" || no "ROADMAP.md present" "re-run Step 7.7 (ROADMAP wizard)"
{ test -f DESTINATION.md || grep -rqi no_forever .claude/ 2>/dev/null; } \
  && ok "DESTINATION.md present (or scope=no_forever)" || no "DESTINATION.md" "re-run Step 7.7.0 (/define-destination)"

# --- Platform discovery (Step 7.4) ---
test -f .claude/template-source.md && ok "template-source.md present" || no "template-source.md" "re-run Step 7.6.4"
if [ -f .mcp.json ]; then
  ok ".mcp.json present (platform MCPs configured)"
else
  echo "• .mcp.json absent — OK ONLY if this project uses no Supabase/n8n/etc. If it does, re-run Step 7.4 (Platform & Credential Discovery)."
fi

# --- Hooks + session wiring (Step 7.6) ---
test -f .claude/settings.local.json && ok "settings.local.json present" || no "settings.local.json" "re-run Step 7.6 (hooks block at minimum)"
grep -q session-summarizer .claude/settings.local.json 2>/dev/null && ok "Stop hooks registered" || no "Stop hooks registered" "re-run Step 7.6"
{ test -d .claude/sessions && test -d .claude/daily-plans; } && ok "session dirs present" || no "session dirs" "mkdir -p .claude/sessions .claude/daily-plans"

echo "----"
if [ "$fail" -eq 0 ]; then
  echo "✓ SETUP COMPLETION GATE: PASS"
else
  echo "✗ SETUP COMPLETION GATE: INCOMPLETE — fix every ✗ above, then re-run. Do NOT write the Report until this prints PASS."
fi
```

After the gate prints PASS, run **`/verify-hooks`** — the 8-phase audit that confirms hook
*enforcement* coverage, token efficiency, escape-hatch absence, and platform-specific hook coverage
for the MCP servers this project actually uses. The gate checks the wiring EXISTS; `/verify-hooks`
checks it is CORRECT. Setup is fully done only when the gate prints PASS and `/verify-hooks` reports
no CRITICAL findings (or each is explicitly accepted).

---

## Report

Confirm:
- Number of files created
- Grade level recommendation
- Suggested next command (/plan or /prime)
