# /adopt-autonomous-workflow

Bring the autonomous workflow system into any existing project in one command.
Works with zero prerequisites — no template clone, no template-source.md, no setup required.

**Use this when**: You have an existing project with its own CLAUDE.md and ROADMAP.md, and
you want to adopt the new autonomous workflow components (daily-plan, guardrails, progress
logging, session summarizer, compress-roadmap) without disturbing what you've already built.

**Time**: 5-10 minutes.

---

## What this installs

| Component | Type | What it does |
|-----------|------|-------------|
| `daily-plan-generator` | Skill | Generates ranked daily plan from ROADMAP + git + NSM |
| `/daily-plan` | Command | Invokes the skill, writes plan, waits for "go" |
| `/compress-roadmap` | Command | Archives stale ROADMAP completed items to quarterly file |
| `/push-to-template` | Command | Contribute improvements back to the template repo |
| `/update-latest` | Command | Pull future template updates into this project |
| `supabase-destructive-sql` | Hookify rule | Pre-flight checklist before every SQL execution |
| `supabase-migration-safety` | Hookify rule | Migration checklist (irreversible ops, rollback plan) |
| `n8n-workflow-delete-block` | Hookify rule | Hard block on n8n workflow delete operations |
| `filesystem-safety` | Hookify rule | Warns on risky Bash patterns (rm -rf, force push, etc.) |
| `progress-logger` | Hookify rule | PostToolUse: logs mutations to claude-progress-{date}.md |
| `sql-guardian.sh` | Shell hook | Hard block (exit 2) for DELETE/TRUNCATE/DROP without WHERE |
| `session-summarizer.sh` | Shell hook | StopHook: writes SESSION-*.md + client update flag |

**Does NOT touch**: CLAUDE.md (project-specific), ROADMAP.md (project-specific), any existing
skills, existing hookify rules, or any project code.

---

## Step 1: Confirm installation scope

Show the user the table above and ask:

```
Ready to install the autonomous workflow system into this project.

This will ADD new files to your .claude/ directory and register 2 shell hooks
in your local settings.local.json. Nothing will be deleted or overwritten.

Your CLAUDE.md and ROADMAP.md will NOT be changed.

Proceed? (y/n)
```

---

## Step 2: Fetch files from GitHub

Use `mcp__github__get_file_contents` to fetch each file from the template repo.
Default template repo: `https://github.com/NewEarthAI/vibecode-project-template`

Parse owner/repo from URL: owner=`NewEarthAI`, repo=`vibecode-project-template`

Fetch these files in parallel (all from branch `main`):
1. `.claude/skills/daily-plan-generator/SKILL.md`
2. `.claude/commands/daily-plan.md`
3. `.claude/commands/compress-roadmap.md`
4. `.claude/commands/push-to-template.md`
5. `.claude/commands/update-latest.md`
6. `.claude/hookify.supabase-destructive-sql.local.md`
7. `.claude/hookify.supabase-migration-safety.local.md`
8. `.claude/hookify.n8n-workflow-delete-block.local.md`
9. `.claude/hookify.filesystem-safety.local.md`
10. `.claude/hookify.progress-logger.local.md`
11. `.claude/hooks/sql-guardian.sh`
12. `.claude/hooks/session-summarizer.sh`

For any fetch that fails: note the failure, continue with the rest, report at the end.

---

## Step 3: Conflict check

Before writing, check each destination path:
- If file does NOT exist → mark as NEW, will be written directly
- If file DOES exist → mark as EXISTS, show diff and ask

For existing files:
```
[!] .claude/hookify.filesystem-safety.local.md — already exists

Your version: 40 lines
Template version: 38 lines

The template version is the canonical generic version. Your version may have
project-specific customizations.

[t] take template version
[k] keep yours (skip this file)
[d] show full diff first
```

Default recommendation: take template version for hookify rules (they use generic
wildcards and are designed to work without customization). Keep any existing shell
hooks that have been locally modified.

---

## Step 4: Write files

Create any missing directories:
```bash
mkdir -p .claude/skills/daily-plan-generator
mkdir -p .claude/commands
mkdir -p .claude/hooks
mkdir -p .claude/sessions
mkdir -p .claude/daily-plans
```

Write each approved file to its destination.

Make shell hooks executable:
```bash
chmod +x .claude/hooks/sql-guardian.sh .claude/hooks/session-summarizer.sh
```

---

## Step 5: Configure daily-plan-generator NSM

ASK user:

```
The daily-plan-generator skill uses your North Star Metric (NSM) to prioritize
daily work. It shows up in every daily plan and helps rank tasks by impact.

1. What's your project's most important metric?
   (e.g., "Operational Visibility Score", "Conversion Rate", "Uptime %")

2. What's the current value? (e.g., "~62%", "2.3%", "unknown")

3. What's the target? (e.g., "90%", "5%", "skip for now")
```

Write values to `.claude/skills/daily-plan-generator/SKILL.md` frontmatter:
```yaml
nsm_label: {answer 1}
nsm_current: {answer 2}
nsm_target: {answer 3}
```

If user says "skip for now" → leave defaults as `{{nsm_label}}`, `{{nsm_current}}`, `{{nsm_target}}`
and add a note: "Edit .claude/skills/daily-plan-generator/SKILL.md to set your NSM values."

---

## Step 6: Register shell hooks in settings.local.json

Read `.claude/settings.local.json` to see its current content.
If the file doesn't exist, create it as `{}`.

Check if `hooks.PreToolUse` and `hooks.Stop` already have sql-guardian and session-summarizer.
If not, add them — merging carefully with any existing hooks array entries:

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

**IMPORTANT**: `.claude/settings.local.json` may contain API keys, credentials, and other
sensitive settings. Read it first, preserve ALL existing keys, only add/extend the `hooks` section.
Never overwrite the entire file.

---

## Step 7: Create template-source.md

Write `.claude/template-source.md`:

```yaml
repo: https://github.com/NewEarthAI/vibecode-project-template
local_path: not cloned
version: 2026-02-19
last_sync: {today's date}
```

This enables `/update-latest` to pull future template improvements into this project.

---

## Step 8: Verify and report

Run a quick sanity check:
```bash
ls .claude/hookify.*.local.md | wc -l   # Should be ≥ 5 new files
ls .claude/hooks/*.sh                   # Should show sql-guardian.sh, session-summarizer.sh
ls .claude/commands/daily-plan.md       # Should exist
```

Show final report:
```
╔══════════════════════════════════════════════════════╗
║  Autonomous Workflow System — Installed              ║
╚══════════════════════════════════════════════════════╝

Files installed: {N}
Shell hooks registered: 2 (in .claude/settings.local.json)
NSM configured: {nsm_label} — {nsm_current} → {nsm_target}

New commands available:
  /daily-plan          — generate today's prioritized work plan
  /compress-roadmap    — archive old ROADMAP completed items
  /push-to-template    — contribute improvements back to the template
  /update-latest       — pull future template updates into this project

How it works:
  1. Start your session → run /daily-plan
  2. Review the plan → type "go" to begin
  3. Work normally — progress is auto-logged after every mutation
  4. Close Claude Code → session summary is auto-written to .claude/sessions/
  5. Next session → /daily-plan reads yesterday's session to build context

To try it now: run /daily-plan
```

---

## Troubleshooting

**GitHub fetch fails**: The template repo may require authentication.
Try: `git clone https://github.com/NewEarthAI/vibecode-project-template /tmp/template-clone`
Then ask user to re-run with the local path.

**settings.local.json is complex / has existing hooks**: Show the exact JSON to add and ask
the user to confirm before writing. The merge logic should extend arrays, not replace them.

**SQL guardian blocks legitimate queries**: The hard block only fires on `DELETE FROM` without
`WHERE`, `TRUNCATE`, and `DROP TABLE/FUNCTION/VIEW`. It does NOT block `UPDATE`, `INSERT`,
`SELECT`, or `DELETE FROM table WHERE id = $1`. If you get a false positive, run the query
via the database dashboard directly.
