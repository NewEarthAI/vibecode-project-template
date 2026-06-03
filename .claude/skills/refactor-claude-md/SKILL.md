---
name: refactor-claude-md
description: |
  Analyze and refactor CLAUDE.md to stay within Anthropic's recommended 80-100 line ceiling.
  Moves reference material to .claude/rules/ files with optional path-scoped frontmatter.
  Based on validated research: Anthropic officially warns that bloated CLAUDE.md files cause
  Claude to ignore critical instructions. This skill encodes the refactor process so every
  project gets the same surgical treatment without re-running research.
version: 1.0
created: 2026-02-25
template_managed: true
template_section: claude-md-optimization
---

!`wc -l CLAUDE.md 2>/dev/null`
!`ls .claude/rules/*.md 2>/dev/null | wc -l | xargs -I{} echo "Rules files: {}"`

# CLAUDE.md Refactor Skill

> **Research finding (validated Feb 2026, 30+ sources):** Anthropic states: "Keep it concise. For each line, ask: 'Would removing this cause Claude to make mistakes?' If not, cut it. **Bloated CLAUDE.md files cause Claude to ignore your actual instructions!**" The recommended ceiling is **80-100 lines**.

## When to Use
- CLAUDE.md exceeds ~100 lines
- After `/update-latest` brings new template features that should be documented
- When you notice Claude ignoring instructions that ARE in CLAUDE.md
- Part of project setup or periodic maintenance

---

## Step 1 — Measure Current State

```bash
wc -l CLAUDE.md
ls .claude/rules/*.md 2>/dev/null | wc -l
```

Report: "CLAUDE.md is {N} lines. Anthropic recommends 80-100. {Already has / Does not have} .claude/rules/ directory."

If already under 100 lines and has rules dir → "CLAUDE.md is healthy. No refactor needed." → STOP.

---

## Step 2 — Classify Every Section

Read CLAUDE.md and classify each section into one of these categories:

| Category | Stays in CLAUDE.md | Examples |
|----------|-------------------|----------|
| **IDENTITY** | YES | Brand name, stack, team size |
| **CRITICAL RULES** | YES | "NEVER do X", "ALWAYS do Y", naming conventions |
| **MCP SERVER TABLE** | YES (compact) | Server names + risk levels (NOT full tool lists) |
| **COMMANDS/SKILLS LIST** | YES (compact) | One-liner per command, not descriptions |
| **DEV COMMANDS** | YES | `npm run dev`, `npm run build`, etc. |
| **CURRENT STATUS** | YES | Working features, known issues, deferred items |
| **PLANNING PROTOCOL** | YES | Mandatory planning rules |
| **REFERENCE MATERIAL** | MOVE → `.claude/rules/` | Pipeline diagrams, workflow IDs, table lists, RPC lists, edge function descriptions, frontend component lists, data flow diagrams |
| **DUPLICATE OF DOCS** | DELETE | Anything already in `docs/` or `specs/` |

**Rule of thumb**: If a section is CONSULTED during specific tasks but not NEEDED every session, it's reference material → move it.

---

## Step 3 — Design Rules Files

Create `.claude/rules/` directory. For each block of reference material, create a focused rule file.

### Path-Scoped Frontmatter (Official Pattern)

Files that only matter for specific directories use YAML frontmatter:
```markdown
---
paths:
  - "supabase/**"
  - "src/integrations/**"
---

# Supabase Safety Rules
...
```

These rules ONLY load when Claude is working on files matching those paths. Saves tokens.

### Common Rules File Patterns

| Rule File | Content | Scope |
|-----------|---------|-------|
| `pipeline-reference.md` | Pipeline overview, workflow IDs, debug guide | Always (no paths) |
| `data-layer.md` | Tables, RPCs, edge functions, APIs | Always |
| `supabase-safety.md` | Column gotchas, verification protocol | `paths: ["supabase/**", "src/integrations/**"]` |
| `frontend.md` | Pages, components, hooks, patterns | `paths: ["src/**"]` |
| `n8n-patterns.md` | Execution modes, return patterns, sandbox limits | Always |
| `file-editing.md` | Pre-edit checks, post-mutation audit trail | Always |
| `tool-fallbacks.md` | MCP → CLI fallback table | Always |

**Adapt these to your project.** Not every project needs all of these. A frontend-only project might just need `frontend.md` and `tool-fallbacks.md`.

---

## Step 4 — Create Rules Files

For each identified reference block:
1. Create the rule file in `.claude/rules/`
2. Add path-scoped frontmatter if the content is directory-specific
3. Include the content AS-IS (no need to rewrite — just relocate)
4. Add any NEW guardrails that the research identified:
   - "Always re-read before editing" → `file-editing.md`
   - "MCP auth error → fall back to CLI" → `tool-fallbacks.md`
   - "Verify columns with information_schema" → `supabase-safety.md` or `file-editing.md`

---

## Step 5 — Slim Root CLAUDE.md

Rewrite CLAUDE.md keeping ONLY:
- **Brand + Stack** (~10 lines)
- **MCP Servers table** — compact: server names + risk levels (~15 lines)
- **Conventions** — naming + MCP tool rules (~15 lines)
- **Dev Commands** (~5 lines)
- **Skills & Commands** — one-liner list (~10 lines)
- **Rules listing** — reference to `.claude/rules/` files with descriptions (~10 lines)
- **GitHub/hosting links** (~5 lines)
- **Current Status + Known Issues** (~10 lines)
- **Planning Protocol** (~5 lines)

**Target: 80-100 lines.** Absolute max: 120 lines.

### @import Pattern (Optional)

For docs that should load on demand:
```markdown
## Architecture
@docs/00_MASTER_ARCHITECTURE.md
```

---

## Step 6 — Verify

```bash
wc -l CLAUDE.md                        # → < 120 lines
ls .claude/rules/*.md | wc -l          # → 3-7 files
```

Report the token savings:
- **Before**: {N} lines (~{N*5} tokens)
- **After**: {M} lines root + rules load conditionally (~{M*5} tokens base)
- **Savings**: ~{percentage}% context reduction on session start

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Move EVERYTHING to rules | Critical rules get ignored | Keep identity + conventions + status in root |
| One giant rules file | Same bloat problem, different location | Focused files by topic |
| Path-scope everything | Some rules matter everywhere | Only path-scope directory-specific content |
| Duplicate content | Rules AND root both have same info | Move completely — don't leave a copy |
| Skip the listing in root | Claude won't know rules exist | Root CLAUDE.md should list all rules files with 1-line descriptions |

---

## Research Backing

This skill encodes findings from 30+ sources (Feb 2026):
- **Anthropic Official**: CLAUDE.md should be 80-100 lines, bloated files cause instruction ignoring
- **`.claude/rules/` directory**: Officially supported (Jan 2026), auto-loaded, optional `paths:` frontmatter
- **`@import` syntax**: Official for composing external files into context
- **Path-scoped rules**: Only load when editing matching files — automatic token savings
- **BuyBox AI case study**: 405 → 92 lines (77% reduction), ~40-50% session start token savings

---

*Skill version: 1.0 | Template-managed | Created 2026-02-25*
