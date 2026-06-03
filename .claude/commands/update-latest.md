# /update-latest

Pull new skills, commands, hooks, and techniques from the upstream template repo into this project.
Works on any project — no local clone required. Fetches directly from GitHub.

## What it does
1. Connects to the template GitHub repo
2. Reads CHANGELOG.md to see what's been added since your last sync
3. Shows you a human-readable "what's new" summary
4. Offers to apply each new component with a diff view
5. Runs any required post-install setup (hook registration, permissions, etc.)

---

## Step 1: Find the template repo

Check `.claude/template-source.md`:
- If it exists → read `repo` URL from it (format: `https://github.com/owner/repo`)
- If it doesn't exist → use default: `https://github.com/cassandrasnyman/claude-code-project-template`
  Then ask: "Is this the right template repo URL? (y / paste different URL)"

Parse `owner` and `repo` from the URL for GitHub MCP calls.

---

## Step 2: Fetch and read CHANGELOG

Use `mcp__github__get_file_contents` to fetch `CHANGELOG.md` from the template repo:
```
owner: {parsed from URL}
repo:  {parsed from URL}
path:  CHANGELOG.md
```

Read `.claude/template-source.md` to get `last_sync` date (or `version`).
If no template-source.md → treat `last_sync` as "never" (apply all entries).

---

## Step 3: Show "What's New" summary

Parse CHANGELOG entries newer than `last_sync`. Display:

```
╔══════════════════════════════════════════════════════╗
║  Template Updates Available                          ║
║  Last sync: 2026-02-15  →  Template: 2026-02-19     ║
╚══════════════════════════════════════════════════════╝

New since your last sync:

## 2026-02-19 — Autonomous Workflow System
  NEW SKILL: daily-plan-generator
    → Prioritized daily plan from ROADMAP + git + session state
  NEW COMMANDS: /daily-plan, /compress-roadmap, /push-to-template
  NEW HOOKS: supabase-destructive-sql, migration-safety, filesystem-safety,
             n8n-workflow-delete-block, progress-logger (PostToolUse)
  NEW SHELL HOOKS: sql-guardian.sh (hard SQL block), session-summarizer.sh (StopHook)

Apply all? (y) or review one-by-one? (r)
```

---

## Step 4: Apply updates (one-by-one or all)

For each new file listed in new CHANGELOG entries, fetch from GitHub using
`mcp__github__get_file_contents` and show a comparison:

```
──────────────────────────────────────────────────────────
[1/9] .claude/skills/daily-plan-generator/SKILL.md
Status: NEW — this file doesn't exist in your project yet

Preview:
  Skill: daily-plan-generator
  Generates prioritized daily work plan from ROADMAP NOW/NEXT lanes,
  git history, session state, and NSM context.
  Invariants: strategy review, research context wrapper, client update flag.

[y] add to project  [s] skip  [d] show full content
──────────────────────────────────────────────────────────
[2/9] .claude/hookify.supabase-destructive-sql.local.md
Status: NEW — guards execute_sql calls with checklist

[y] add to project  [s] skip  [d] show full content
──────────────────────────────────────────────────────────
```

For files that ALREADY EXIST in the project (possible if previously partially applied):
```
[3/9] .claude/hooks/sql-guardian.sh
Status: EXISTS — your version differs from template

Template has: +8 lines (added DROP SCHEMA block)

[y] apply template version  [s] keep yours  [d] show diff
──────────────────────────────────────────────────────────
```

**For CLAUDE.md updates** (TEMPLATE-MANAGED sections only):
- Identify the section by `<!-- TEMPLATE-MANAGED-START: {name} -->` markers
- Replace ONLY that section, leave all other CLAUDE.md content untouched
- Always show the section diff before applying

---

## Step 5: Post-install setup

After applying files, run setup steps for newly installed components.

### Obsidian autopilot bootstrap (ALWAYS runs after every /update-latest)

**5-PRE. Run bootstrap-obsidian.sh:**

Whenever the SessionStart aggregator hook OR the obsidian example config is in
the applied set (or already present in the project), invoke the bootstrap
script. It is idempotent — running it on an already-configured repo is a no-op
beyond a heartbeat report. Running it on a fresh repo creates the per-machine
config with the auto-detected repo slug, verifies the Keychain entry, and
smoke-tests the SessionStart vault block.

```bash
if [ -x .claude/scripts/bootstrap-obsidian.sh ]; then
  bash .claude/scripts/bootstrap-obsidian.sh
fi
```

The script handles every step a new repo needs for obsidian autopilot parity
with BuyBox / Agency-Main:
- Creates `.claude/obsidian-second-brain.local.md` if missing, with the three
  shared agency values pre-filled and the per-repo scope slug auto-detected
  from the folder name (e.g. `nirvana-freight` → `vault_scope_slug: "nirvana-freight"`).
- Adds `vault_scope_slug` to an existing config that doesn't have one (so
  upgrading from an older template version is one /update-latest away).
- Verifies the macOS Keychain entry exists (the one Justin's Macs use across
  the entire fleet). If absent, prints the exact command to provision it and
  exits non-zero so the operator sees it.
- Smoke-tests the SessionStart vault block and prints the first row, so the
  operator confirms with their own eyes that the vault loop is live.

After this runs cleanly, the repo is FULLY obsidian-connected on the read
side. The write side (Stop chain: session-summarizer → vault-capture →
auto-sync-artifacts) is wired in step 5b below if those hooks were applied.

### If any shell hooks were added (sql-guardian.sh, session-summarizer.sh):

**5a. Make executable:**
```bash
chmod +x .claude/hooks/*.sh
```

**5b. Register in settings.local.json:**

Read `.claude/settings.local.json` (it may not exist yet — create it if needed).
Check if hooks section already has these entries. If not, add them.

**IMPORTANT:** `.claude/settings.local.json` is gitignored (contains secrets). Read it first to
preserve ALL existing content. Only add/merge sections, never overwrite the whole file.

If the hooks section doesn't exist, add it:
```json
{
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

If the hooks section already exists, add the new entries to the array (don't overwrite).

### If confident-mode hook was added (hookify.confident-mode.local.md):

**5b2. Add confident-mode permissions to settings.local.json:**

Check if `permissions.allow` array exists in `settings.local.json`. If not, add the full
confident-mode permission set. Read `.mcp.json` to discover connected MCP servers and generate
appropriate allow patterns for each.

Add to `permissions.allow`:
```json
"Read(*)", "Write(*)", "Edit(*)", "Glob(*)", "Grep(*)",
"Bash(git status*)", "Bash(git log*)", "Bash(git diff*)",
"Bash(git branch*)", "Bash(git add*)", "Bash(git commit*)",
"Bash(git stash*)", "Bash(git checkout*)",
"Bash(ls*)", "Bash(wc*)", "Bash(mkdir*)", "Bash(cp*)",
"Bash(npm*)", "Bash(npx*)", "Bash(bun*)", "Bash(node*)",
"Bash(cat*)", "Bash(head*)", "Bash(tail*)", "Bash(curl*)",
"Bash(python3*)", "Bash(find*)", "Bash(env*)", "Bash(chmod*)",
"WebFetch(*)", "WebSearch(*)"
```

For each MCP server in `.mcp.json`, add read-only patterns:
- Supabase: `execute_sql`, `list_*`, `get_*`, `generate_typescript_types`, `apply_migration`, `list_edge_functions`, `get_edge_function`, `list_storage_buckets`, `list_branches`
- GitHub: `mcp__github__*` (all operations)
- Redis: `mcp__redis-*__*` (all operations)
- Context7: `mcp__Context7__*` (all operations)
- Wassenger: only `get_*`, `search_*`, `analyze_*`, `list_*` (NOT send/manage)
- Airtable: only `list_*`, `get_*`, `search_*`
- Playwright/Chrome DevTools: all operations
- Make: all operations

Add to `permissions.deny`:
```json
"Bash(rm -rf *)", "Bash(git push --force*)",
"Bash(git reset --hard*)", "Bash(git clean -f*)"
```

Do NOT add to allow (these require confirmation):
- `deploy_edge_function`, `create_branch`, `merge_branch`, `delete_branch`
- `send_whatsapp_message`, `manage_whatsapp_message_interactions`
- Any tool that modifies external/shared state irreversibly

TELL user: "Confident Mode permissions applied — safe operations auto-allowed, destructive operations still require confirmation."

### If daily-plan-generator skill was added:

**5c. Configure NSM parameters:**

Ask the user:
```
The daily-plan-generator skill needs your project's North Star Metric configured.

1. What do you call your NSM? (e.g., "OVS", "Conversion Rate", "NPS Score", "Availability")
2. What's the current value? (e.g., "~62%", "2.3%", "47 NPS")
3. What's the target? (e.g., "90%", "5%", "70 NPS")
```

Write the values into `.claude/skills/daily-plan-generator/SKILL.md` frontmatter:
```yaml
nsm_label: {user answer 1}
nsm_current: {user answer 2}
nsm_target: {user answer 3}
```

### If any new hookify rule (.claude/hookify.*.local.md) was added (NEW — added 2026-05-12):

**5c2. Auto-wire matchers for pulled hookify rules:**

The same logic that `/setup` Step 7.6.5 runs at first-install applies here when new hookify rules arrive via update. For each newly-pulled `hookify.*.local.md`:

**Step A** — Parse its frontmatter `event` + `tool_matcher` fields.

**Step B** — If the matcher is NOT `Bash` AND NOT `*` AND the matcher is NOT already registered in `.claude/settings.local.json` for that event, append a new entry pointing at `hookify-context-injector.sh`:

```python
import json
path = '.claude/settings.local.json'
with open(path) as f:
    s = json.load(f)
s.setdefault('hooks', {}).setdefault(event, [])
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
    print(f'Registered {matcher} matcher for {event}')
```

**Step C** — Simulate a tool dispatch through the chain to confirm the rule fires. Pattern matches `/setup` Step 7.6.5 Step D verification block.

**Step D** — Make sure all hook scripts remain executable:
```bash
chmod +x .claude/hooks/*.sh 2>/dev/null
```

Surface to user: "Auto-wired {{N}} new hookify rule matcher(s) in your settings: {{list of (event, matcher) pairs}}. The hookify-context-injector.sh script will now fire on those tool events."

If the matcher was already registered with the same script, do NOTHING and inform: "Matcher {{matcher}} for event {{event}} was already wired — no change."

### If this is the first time applying the template to this project:

**5d. Create template-source.md:**

Write `.claude/template-source.md` with:
```yaml
repo: {template repo URL}
local_path: {ask user for local path, or "not cloned"}
version: {latest CHANGELOG date}
last_sync: {today}
```

---

## Step 6: Report

```
╔══════════════════════════════════════════════════════╗
║  Update Complete                                     ║
╚══════════════════════════════════════════════════════╝

Applied:  9 files
Skipped:  0 files
Now at:   template version 2026-02-19

What was added:
  ✓ .claude/skills/daily-plan-generator/SKILL.md
  ✓ .claude/commands/daily-plan.md
  ✓ .claude/commands/compress-roadmap.md
  ✓ .claude/hookify.supabase-destructive-sql.local.md
  ✓ .claude/hookify.supabase-migration-safety.local.md
  ✓ .claude/hookify.n8n-workflow-delete-block.local.md
  ✓ .claude/hookify.filesystem-safety.local.md
  ✓ .claude/hookify.progress-logger.local.md
  ✓ .claude/hooks/sql-guardian.sh  (registered in settings.local.json)
  ✓ .claude/hooks/session-summarizer.sh  (registered in settings.local.json)

NSM configured: OVS — current ~62% → target 90%

Next:
  - Run /daily-plan to generate your first daily work plan
  - Run /compress-roadmap if ROADMAP.md > 500 lines
  - Commit the new .claude/ files: git add .claude/commands .claude/skills .claude/hooks .claude/hookify.*.local.md
```

---

## Conflict Detection

If a file exists in your project AND has been modified since the template version:
```
[!] .claude/hooks/sql-guardian.sh — LOCAL MODIFICATIONS DETECTED

Your version has 3 changes vs the last-synced template version:
  + Line 45: added custom block for your project's audit tables
  + Line 67: tweaked TRUNCATE error message

Template update adds:
  + Line 55: new DROP SCHEMA block

Options:
  [m] merge manually (shows both versions side by side)
  [t] take template version (lose your local changes)
  [k] keep yours (skip this file)
```

---

## Related
- `/push-to-template` — push improvements from this project back to the template
- `/setup` — full project setup wizard (for new projects)
- `/daily-plan` — generate a daily work plan
- `.claude/template-source.md` — template config file (auto-created by this command)
