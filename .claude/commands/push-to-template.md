# /push-to-template

Copy TEMPLATE-MANAGED files from this project to the template repo, generalise project-specific values with laser precision, commit, rebase on remote, and push to GitHub. One invocation handles the FULL sync — no manual `git push` follow-up.

**Failure mode this command prevents**: the 2026-05-12 sync where the operator had to (a) manually run `git add -A && git commit && git push`, (b) hit a fetch-first rejection, (c) manually `git pull --rebase`, (d) resolve a CHANGELOG conflict by hand. Every one of those steps now runs automatically with conflict resolution baked in.

---

## Steps

### 1. Read template source config

- Read `.claude/template-source.md` to get `local_path` (where the template repo lives on disk) and `repo` (the GitHub URL — e.g., `https://github.com/NewEarthAI/claude-code-project-template`).
- **Resolve `local_path` per-machine.** `local_path` is stored `~`-relative (e.g. `~/Documents/GitHub/claude-code-project-template`) so it resolves on any operator's Mac — Justin's, Cassandra's, or a future adopter's. Expand the leading `~` to `$HOME` before use; never pass the raw `~`-string into a quoted context (quotes suppress `~` expansion):
  ```bash
  RAW_PATH="<local_path from template-source.md frontmatter>"
  TEMPLATE_PATH="${RAW_PATH/#\~/$HOME}"          # expand leading ~ to $HOME (per-machine)
  [ -d "$TEMPLATE_PATH/.git" ] || { echo "Template repo not cloned at $TEMPLATE_PATH — clone it: git clone <repo> \"$TEMPLATE_PATH\""; exit 1; }
  ```
  Use the expanded `$TEMPLATE_PATH` everywhere `{local_path}` appears in the steps below.
- Read `CHANGELOG.md` in the template repo to see the last entry date and format.
- Verify the template repo is in a clean state (no in-progress rebase / merge / cherry-pick): `cd {local_path} && git status --porcelain && [ ! -d .git/rebase-merge ] && [ ! -d .git/rebase-apply ] && [ ! -f .git/MERGE_HEAD ]`. If unclean, HALT and surface the state — never push on top of a half-finished sibling operation.

### 2. Identify files to copy

- Read the TEMPLATE-MANAGED files table from `.claude/template-source.md`.
- For each file, read both the project version and the template version (if it exists).
- Build a manifest of files that differ.

### 3. Show diff summary

For each TEMPLATE-MANAGED file that differs:
```
[FILE] .claude/hooks/sql-guardian.sh
Project version: 2026-02-19 (64 lines)
Template version: 2026-02-15 (40 lines)
Changes: +24 lines (added DROP FUNCTION and DROP VIEW blocks)
Copy? (y/skip/view-diff)
```

### 4. Laser-precision placeholder stripping (mandatory — before write)

Before writing ANY file to the template repo, run the full generalisation pass. The strip list is canonical — extend it here when new project-specific tokens are discovered.

**Tool-name generalisation** (regex-replace):
| Project-specific | Template-generic |
|---|---|
| `mcp__supabase-buyboxai__*` / `mcp__supabase-newearthai__*` / `mcp__supabase-nirvana__*` | `mcp__supabase-{{project}}__*` |
| `mcp__n8n-mcp-honeybird__*` / `mcp__n8n-mcp-newearthai__*` | `mcp__n8n-mcp-{{instance}}__*` |
| `mcp__followupboss-mcp__*` | `mcp__{{crm}}-mcp__*` (kept generic — FollowUpBoss is widely useful; only strip if context demands) |
| `mcp__wassenger__*` | `mcp__{{whatsapp}}__*` |
| `mcp__airtable-mcp-newearthai__*` | `mcp__airtable-mcp-{{instance}}__*` |
| `mcp__redis-nirvana__*` | `mcp__redis-{{instance}}__*` |

**Project-identity generalisation** (regex-replace):
| Project-specific | Template-generic |
|---|---|
| `BuyBox-AI` / `BuyBox` / `buybox-ai.com` | `{{project_name}}` (preserve casing) |
| `Honeybird` / `HomePros` / `Killer Bee` / `iSpeed2Lead` / `Trevor` / `Yuri` / `Chris` / `Justin` / `Mike Penez` | `{{partner_name}}` (entity-aware — preserve role context if needed for a precedent example) |
| Supabase project refs (`rkjbdjxihppklvlbfywp`, `cqjkroyfbqaynxihfowq`, etc. — 20-char alphanumeric) | `{{supabase_project_ref}}` |
| Vercel team slug `teamnewearthaias-projects` | `{{vercel_team_slug}}` |
| Repo paths starting with `/Users/justin/` | `{{user_home}}/code/{{repo_stem}}/` for project-rooted; `~/.claude/` for global |
| Specific git SHAs cited in prose (e.g., `03f8cc7e`, `b2012ff9`) | `{{commit_sha}}` IF they're cited as illustrative; PRESERVE if the SHA is being cited as a verifiable precedent ("PR #173 SHA 12abc34 caught X"). Decision rule: keep when the SHA is forensic evidence; strip when it's just a recency marker. |

**NSM-label generalisation**:
| Project-specific | Template-generic |
|---|---|
| `OVS (~62% → 90%)` / any concrete metric current/target | `{{nsm_label}} ({{nsm_current}} → {{nsm_target}})` |
| Domain-specific NSM tables (e.g., "Property Pipeline Volume", "Buyer Match Rate") | `{{domain_nsm_label}}` |

**Timezone + date markers**:
| Project-specific | Template-generic |
|---|---|
| Specific dates in doctrine examples ("2026-04-20 drawer incident") | KEEP — these are historical precedents that anchor the rule's credibility. NEVER strip dates from failure-precedent sections. |
| Calendar markers like "next L10 meeting", "EOD Friday Pretoria time" | Strip — these are project-local scheduling refs |
| Specific webinar / event dates ("2026-05-14 Killer Bee webinar") | Strip — these are project-local |

**Strict-exclusion list (NEVER push, even if listed as template-managed)**:
- `ROADMAP.md` — project-specific lane content
- `MEMORY.md` — project-specific memory index
- `.claude/projects/**/memory/**` — project-specific memory files
- `continuations/**` — session-specific handoffs
- `council/sessions/**` — project-specific deliberations
- `council/audits/**` — project-specific research
- `specs/**` — project-specific work plans
- `strategy/**` — project-specific positioning + competitive intel
- `docs/` content describing this project's architecture (vs generic doctrine)
- ANY file under `src/`, `supabase/`, `tests/` — these are project code, never doctrine

**Verification gate (mandatory before write)**:
After running all substitutions, grep the generalised file for any remaining project-specific tokens. If ANY hit, HALT and report which token survived. Example check:
```bash
grep -nE '(BuyBox-AI|Honeybird|HomePros|Killer Bee|iSpeed2Lead|Trevor|Yuri|Justin|rkjbdjxihppklvlbfywp|teamnewearthaias)' <generalised-file>
```
Empty result = pass. Any hit = surface, ask user to disambiguate (keep as historical precedent vs strip).

### 5. Copy approved files to template repo

For each approved + generalised file, Write to the template repo path. For files that need surgical Edit rather than full overwrite (when the template version is ahead with content the project doesn't have — typical for `code-review-domain-routing.md` and `autovibe/SKILL.md`), use Edit with anchored `old_string`/`new_string` rather than overwriting.

### 6. Write CHANGELOG entry

Append to `CHANGELOG.md` in the template repo. Entry format:
```markdown
## {{YYYY-MM-DD}} — {brief description of what changed}

{2-3 sentence summary of the why — what failure mode does this prevent, what new capability does it enable}

- **UPDATED** `.claude/path/to/file` — what changed and why (one sentence per file)
- **UPDATED** `.claude/path/to/other-file` — what changed
- **ADDED** `.claude/path/to/new-file` — what it does

**Failure precedent prevented**: {{cite the incident this addresses, with date}}

Synced from: {{project_name}} @ {{commit_sha}}
```

### 7. Update template-source.md

Update `last_sync` field in `.claude/template-source.md` in BOTH the project AND the template repo. Value: `{{YYYY-MM-DD}}-{{slugified-description}}`. Example: `2026-05-12-code-review-identity-universal-enforcement`.

### 8. Auto-commit, auto-rebase, auto-push (NEW — replaces manual git steps)

**Step 8.1 — Stage all changes in the template repo**:
```bash
cd {local_path} && git add -A && git status --short
```
Show the staged files. If anything looks wrong, HALT and surface.

**Step 8.2 — Commit with structured message**:
```bash
cd {local_path} && git commit -m "Sync from {{project_name}}: {{brief-description}}

{{2-3 sentence body matching CHANGELOG entry}}

Synced from: {{project_name}} @ {{commit_sha}}

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

**Step 8.3 — Fetch latest from origin/main**:
```bash
cd {local_path} && git fetch origin main 2>&1
INCOMING=$(cd {local_path} && git log --oneline HEAD..origin/main | head -10)
```
If `INCOMING` is empty, skip to Step 8.5 (no rebase needed). If non-empty, log the incoming commits and proceed to Step 8.4.

**Step 8.4 — Rebase local commit on top of remote**:
```bash
cd {local_path} && git pull --rebase origin main 2>&1
```

**Conflict handling** (the 2026-05-12 precedent):
- If rebase reports CONFLICT in `CHANGELOG.md`: read both `<<<<<<< HEAD` and `>>>>>>>` sections. The remote's entry and ours BOTH belong — they're sibling syncs from different projects on the same day. Remove ONLY the conflict markers + ensure both entries are separated by `\n\n---\n\n`. Stage + `GIT_EDITOR=true git rebase --continue`.
- If rebase reports CONFLICT in `.claude/skills/*/SKILL.md` or another file: read the file, identify whether the sibling change is orthogonal (auto-merge usually wins) or overlapping (needs human). For orthogonal additions to the same section, keep both. For overlapping edits, HALT and surface the conflict for human resolution — DO NOT silently pick a side.
- After resolution: `cd {local_path} && git status` must show no conflict markers remaining, then `GIT_EDITOR=true git rebase --continue`.

**Step 8.5 — Push to GitHub**:
```bash
cd {local_path} && git push origin main 2>&1
```

If push succeeds, capture the SHA + remote URL. If push fails with another fetch-first (sibling pushed during our rebase window), loop back to Step 8.3. Cap the retry loop at 3 iterations — if we lose the race 3 times, HALT and ask the operator to investigate (something is auto-pushing every few seconds).

### 9. Report

```
╔══════════════════════════════════════════════════════╗
║  Template Sync Complete                              ║
╚══════════════════════════════════════════════════════╝

Pushed {N} files to template repo:
{list of files with one-line descriptions}

CHANGELOG entry: ## {{YYYY-MM-DD}} — {{description}}
last_sync bumped: {{old}} → {{new}}

Template repo:
  Branch: main
  Local commit: {{sha}}
  Remote: pushed to {{remote_url}}
  Conflicts: {{auto-resolved CHANGELOG / none}}

Auto-setup on receiving projects:
  When other projects run /update-latest + /setup, the following will be auto-wired:
  {{list any settings.local.json entries, hookify registrations, or post-install steps the new files require — derived from each file's auto-setup-needs frontmatter section, see Step 4 of /setup}}

Next: /update-latest from sibling projects pulls these changes.
```

---

## Auto-setup-needs declaration (NEW — for files that require receive-side wiring)

When a file pushed to template requires per-project setup to function (e.g., a new hookify rule needs a `settings.local.json` matcher entry), the file MUST declare its setup needs in its frontmatter OR the CHANGELOG entry MUST include a `## Auto-Setup Required` section.

Recognised setup-need types:

| Type | Action by `/setup` | Action by `/update-latest` |
|---|---|---|
| `hookify_matcher` | Adds the named matcher to `settings.local.json` PreToolUse / PostToolUse / Stop hooks chain with the hookify-context-injector script | Same, prompts user if matcher already exists with different content |
| `shell_hook` | Adds a direct shell-script hook registration | Same |
| `chmod_executable` | `chmod +x` the named file | Same |
| `mcp_permission_allow` | Adds the named MCP tool pattern to `permissions.allow` | Same |
| `mcp_permission_deny` | Adds the named MCP tool pattern to `permissions.deny` | Same |
| `env_var_required` | Prompts user to set the env var (in `.mcp.json` or `.env.local`) | Same |
| `cron_job` | Documents the cron entry for the user to add manually (cron is per-environment, not auto-installable) | Same |

The hookify rule shipped 2026-05-12 (`hookify.code-review-identity-load.local.md`) declares ONE setup need: `hookify_matcher: Agent / PreToolUse / hookify-context-injector.sh`. The `/setup` command (Step 7.6 update) auto-wires this.

---

## Safety Rules

- NEVER push project-specific files (the Strict-exclusion list above is non-negotiable)
- Only push files listed in the TEMPLATE-MANAGED table — never `git add -A` arbitrary content
- Always run the generalisation verification gate before write (Step 4 mandatory grep)
- Auto-push is permitted because the operation is to a non-production infrastructure repo and conflicts are recoverable via rebase. Hard-stop conditions: rebase produces non-CHANGELOG conflict in an overlapping file (HALT, surface to operator); 3 consecutive fetch-first rejections (HALT, surface — something is auto-pushing every few seconds, which is anomalous)
- NEVER `git push --force` to the template repo (would clobber sibling-project work)

---

## Related

- `/update-latest` — pull template updates into this project (reverse direction)
- `/setup` — full project setup wizard for new projects; consumes the auto-setup-needs declarations from template-pushed files
- `.claude/template-source.md` — template repo config + TEMPLATE-MANAGED file list
