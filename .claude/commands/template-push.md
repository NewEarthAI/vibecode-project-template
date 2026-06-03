# /template-push

Push skills, commands, hooks, and agents to the Claude Code project template repo.
Generalizes project-specific content, commits, and pushes to GitHub — fully autonomous.

**Invokes**: `template-push` skill

---

## What it does

1. Reads `.claude/template-source.md` for config + TEMPLATE-MANAGED file list
2. Diffs each managed file (project vs template) — shows what changed
3. Auto-detects NEW generic files not yet in the managed list
4. Smart direction detection: skips files where template is already ahead
5. Generalizes project-specific content (MCP names, NSM values, project IDs)
6. Writes generalized files to the template repo local clone
7. Updates CHANGELOG.md in the template repo
8. **Commits and pushes to GitHub** — no manual git commands needed
9. Updates `template-source.md` with new sync date

---

## Usage

```
/template-push
```

No arguments. The command reads the template repo location from `.claude/template-source.md`.
Falls back to auto-detection of common clone paths if configured.

---

## Approval Flow

You'll see a change summary before anything is pushed:

```
Changes detected:

  [NEW]     .claude/skills/template-push/SKILL.md
  [UPDATED] .claude/skills/daily-plan-generator/SKILL.md (+33 lines)
  [SAME]    .claude/hooks/sql-guardian.sh (skipping)
  [SKIP]    .claude/commands/daily-plan.md (template is ahead)

Push N files to template? (y / review each / abort)
```

Say `y` → it generalizes, copies, commits, pushes. Done.

---

## What Gets Generalized

| Project-specific | Becomes |
|-----------------|---------|
| `mcp__supabase-{project}__` | `mcp__supabase-.*__` |
| `mcp__n8n-mcp-{project}__` | `mcp__n8n-mcp-.*__` |
| NSM label (near NSM context) | `{{nsm_label}}` |
| NSM current value | `{{nsm_current}}` |
| NSM target value | `{{nsm_target}}` |
| Supabase project IDs | removed |
| Project-specific URLs/emails | removed |
| Timezone abbreviations | removed |

Files containing project domain terms are flagged as potentially project-specific before pushing.

---

## Safety

- **NEVER pushes**: ROADMAP.md, MEMORY.md, memory/, continuations/, domain-specific skills
- Only pushes files in the TEMPLATE-MANAGED table (or newly approved generic files)
- Always shows diff summary before pushing
- Regular `git push` only — never force push
- Template repo must be clean (no uncommitted changes) before pushing

---

## After Push

Other projects can pull the changes immediately:

```
/update-latest
```

New projects get the changes automatically when cloned from the template.

---

## Related

- `/update-latest` — pull template updates INTO this project (reverse direction)
- `/adopt-autonomous-workflow` — install the autonomous workflow system from template
- `.claude/template-source.md` — template config and managed file list

---

*Skill: `template-push` v1.0 | Command created: 2026-02-20*
