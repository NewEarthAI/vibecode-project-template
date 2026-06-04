---
name: template-push
description: |
  Push skills, commands, hooks, and agents from this project to the Claude Code
  project template repo. Generalizes project-specific content, commits, and pushes
  to GitHub — fully autonomous, zero user action after approval.
version: 1.0
created: 2026-02-20
parameters:
  - name: template_local_path
    type: path
    description: "Local clone of the template repo"
  - name: template_repo
    type: string
    description: "GitHub repo URL"
  - name: generalize
    type: boolean
    default: true
    description: "Strip project-specific identifiers before pushing"
---

# Template Push

Pushes TEMPLATE-MANAGED files from the current project to the upstream Claude Code project
template repo. Handles generalization, git commit, and GitHub push — end to end.

Invoked by `/template-push` command.

---

## Step 1 — Read Config

```
Read .claude/template-source.md
```

Extract:
- `repo` — GitHub URL
- `local_path` — local clone path
- `last_sync` — date of last push
- **TEMPLATE-MANAGED Files table** — the canonical list of what gets pushed

**Dual-repo**: `template-source.md` lists a `repos` array with TWO targets — the legacy
`claude-code-project-template` and the public `vibecode-project-template`. Run Steps 2–7
once per target; both receive identical white-labelled content AND an in-sync `.pi/`
parity layer (Step 4b). If only one repo is configured, fall back to single-target.

**If template-source.md doesn't exist** → error: "No template configured. Run `/adopt-autonomous-workflow` first."

**If local_path doesn't exist or isn't a git repo** → error: "Template repo not cloned at `{path}`. Clone it first: `git clone {repo} {path}`"

---

## Step 2 — Detect Changes

For each file in the TEMPLATE-MANAGED table:

1. Read the **project version** (this repo)
2. Read the **template version** (template repo local clone)
3. Compare content — if identical, skip

Build a change list:
```
Changes detected:

  [NEW]     .claude/skills/template-push/SKILL.md
            → Not in template yet

  [UPDATED] .claude/skills/daily-plan-generator/SKILL.md
            → Project: 290 lines | Template: 257 lines | +33 lines

  [SAME]    .claude/hooks/sql-guardian.sh
            → Identical, skipping

Push N files? (y / review each / abort)
```

**Auto-detect NEW files**: Also scan for files matching these patterns that are NOT yet in the
TEMPLATE-MANAGED table but SHOULD be (generic, not project-specific):

```
.claude/skills/*/SKILL.md          — any new skills
.claude/commands/*.md              — any new commands
.claude/hookify.*.local.md         — any new hookify rules
.claude/hooks/*.sh                 — any new shell hooks
.claude/agents/*.md                — any new agents (non-project-specific)
```

For each candidate, check if it contains project-specific domain terms. Only surface
template-worthy candidates. Add approved ones to the TEMPLATE-MANAGED table in
`template-source.md` before pushing.

**Smart direction detection**: Compare project vs template. If the template version is MORE
ADVANCED (longer, more generic, higher version number), skip that file — pushing would be
a regression. Only push files where the project has genuine improvements.

---

## Step 3 — Generalize Content

For each file being pushed, apply these transformations:

### 3a. MCP Server Names (regex replace)
```
mcp__supabase-{project}__     →  mcp__supabase-.*__
mcp__n8n-mcp-{project}__      →  mcp__n8n-mcp-.*__
```

### 3b. NSM Values
```
{nsm_label}                    →  {{nsm_label}}
{nsm_current}                  →  {{nsm_current}}
{nsm_target}  (when near NSM)  →  {{nsm_target}}
```

### 3c. Project-Specific Identifiers (remove entirely)
```
Supabase project IDs           →  (remove)
Project company name           →  (remove or replace with "your project")
Client names                   →  (remove or replace with "the client")
Project-specific emails        →  (remove)
Project-specific URLs          →  (remove or replace with "your instance")
```

### 3d. Timezone Markers
```
{timezone abbreviation}        →  (remove or replace with "local time")
```

### 3e. Domain Terms (flag, don't auto-replace)
If project-specific table names, service names, or domain concepts appear in a
supposedly-generic file, **flag it**:

"WARNING: `{file}` contains project-specific terms (`{terms}`). This file may be
project-specific, not template-worthy. Push anyway? (y/skip)"

### 3f. Preserve Parameterized Content
Do NOT generalize content already using `{{parameter}}` syntax — it's already template-ready.

---

## Step 4 — Write to Template Repo

For each approved file:

1. Ensure parent directory exists in template repo:
   ```bash
   mkdir -p {template_local_path}/{dirname}
   ```

2. Write the generalized content to the template repo path

3. If file is NEW (not in template yet), also add it to template repo's file index

---

## Step 4b — Regenerate the pi parity layer (MANDATORY)

The template runs under BOTH Claude Code and pi. After writing the `.claude/` files,
refresh the target repo's `.pi/` layer so pi stays at parity:

```bash
cd {template_local_path}
mkdir -p .pi/prompts
for f in .claude/commands/*.md; do
  b=$(basename "$f"); [ "$b" = "setup.md" ] && continue   # twin is hand-spliced — never overwrite
  cp "$f" ".pi/prompts/$b"
done
for f in .pi/prompts/*.md; do
  [ "$(basename "$f")" = "setup.md" ] && continue
  sed -i '' -e 's/^!`\([^`]*\)`/Run: \1/' -e 's/mcp__\([a-zA-Z0-9-]*\)__/\1_/g' "$f"
done
git add .pi/prompts .pi/extensions .pi/settings.json
```

- If `setup.md` changed: re-splice `.pi/prompts/setup.md` (keep its "pi Environment
  Wiring" section; refresh the interview/output halves from the new `setup.md`).
- New shell hook without a matching `.pi/extensions/*.ts` → FLAG for a TypeScript port
  (pi-migration Phase 4). Hookify rules need no port (`hookify-loader.ts` reads them live).
- New skills need no action — `pi-setup` links them into `.pi/skills/` at install.

---

## Step 5 — Update Template Metadata

### 5a. Update CHANGELOG.md in template repo

Read existing CHANGELOG.md. Prepend new entry:

```markdown
## {YYYY-MM-DD} — {auto-generated summary}

{For each file pushed:}
- **{NEW|UPDATED}** `{file_path}` — {1-line description of what changed}

Synced from: {project name} ({git hash})
```

### 5b. Update template-source.md in THIS project

```yaml
last_sync: {today's date}
version: {today's date}
```

Add any newly-registered files to the TEMPLATE-MANAGED table.

---

## Step 6 — Git Commit + Push (Fully Autonomous)

Execute in the template repo directory:

```bash
cd {template_local_path}
git add -A
git status
```

If there are changes:

```bash
git commit -m "$(cat <<'EOF'
Sync from {project}: {summary}

Files: {count} pushed ({new_count} new, {updated_count} updated)
Source: {project_name} @ {git_hash}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

git push origin main
```

If `git push` fails (auth, conflict, etc.):
- Show the error
- Suggest: "Try: `cd {path} && git push origin main` manually, or check your GitHub auth."
- Do NOT retry automatically

---

## Step 7 — Verify + Report

After successful push, verify by checking the remote:

```bash
cd {template_local_path} && git log --oneline -1
```

Then report:

```
Template push complete.

  Repo: {repo_url}
  Files pushed: {count} ({new_count} new, {updated_count} updated)
  Commit: {short_hash} — {commit message first line}
  CHANGELOG: updated with {date} entry

  Ready for other projects:
    /update-latest  — pulls these changes into any project using this template

  template-source.md updated: last_sync = {today}
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Push ROADMAP.md | Project-specific | Never push — it's in the exclusion list |
| Push MEMORY.md or memory/ | Project-specific | Never push |
| Push domain-specific skills | Project-only skills | Only push generic skills |
| Skip generalization | Template gets polluted with project specifics | Always generalize in Step 3 |
| Ask user to run git push | Defeats the purpose | Push autonomously in Step 6 |
| Push without showing changes | User can't review | Always show diff summary in Step 2 |
| Force-push | Dangerous | Regular push only; on conflict, ask user |
| Push when template is ahead | Regression | Compare versions; skip if template is more advanced |

---

## Edge Cases

### Template repo has uncommitted changes
```bash
cd {template_local_path} && git status --porcelain
```
If dirty: inspect first — do not halt blindly. Two sub-cases:

**Sub-case A — Prior-session work with prepared CHANGELOG entry**

Symptom: modified files + CHANGELOG.md has a recent entry documenting those modifications, but no commit yet. Source attribution ("Synced from: {prior project}") makes the prior author clear.

Action: do NOT halt. Complete the prior session's commit under their attribution (use a "Sync from {prior project}" commit message that references the CHANGELOG entry's date), THEN add your new files as a separate commit. This honours both sessions' work and avoids stash-based context loss.

Decision rule: if CHANGELOG entry exists AND modified files match the entry's named files → safe to commit on their behalf. If modifications exist without a matching CHANGELOG entry → halt and surface to operator (modifications may be in-progress work that shouldn't ship).

**Sub-case B — Genuine in-progress local work without CHANGELOG entry**

Symptom: modified files, no matching CHANGELOG entry, no clear prior author.

Action: halt with original message: "Template repo has uncommitted changes. Commit or stash them first, then re-run."

Failure precedent: 2026-05-11 sync found template repo with 3 modified files + matching CHANGELOG entry from a sibling project dated the same day, but no commit. Halting would have stalled both syncs; sub-case A path completed the prior commit cleanly under the sibling project's attribution then added the new commit as a separate one.

### Template repo is behind remote
```bash
cd {template_local_path} && git fetch origin && git status -uno
```
If behind: auto-pull before pushing: `git pull --rebase origin main`

### File exists in template but NOT in TEMPLATE-MANAGED table
Skip it — only push files explicitly listed in (or newly approved for) the TEMPLATE-MANAGED table.

### CLAUDE.md TEMPLATE-MANAGED sections
For CLAUDE.md, only push content within `<!-- TEMPLATE-MANAGED-START: {name} -->` and
`<!-- TEMPLATE-MANAGED-END: {name} -->` markers. Extract the section, generalize, and
write to the corresponding section in the template's CLAUDE.md.

---

*Skill version: 1.0 | Created: 2026-02-20*
