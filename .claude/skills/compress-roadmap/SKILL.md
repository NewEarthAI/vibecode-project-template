---
name: compress-roadmap
description: |
  Archive stale completed items from ROADMAP.md when it grows beyond 500 lines.
  Moves old "Recently Completed" entries to quarterly archive files.
  Keeps last 10 entries. Reports compression stats.
version: 1.0
created: 2026-02-24
template_managed: true
template_section: roadmap-management
parameters:
  - name: roadmap_file
    type: path
    default: "ROADMAP.md"
  - name: archive_dir
    type: path
    default: "."
  - name: max_lines_threshold
    type: number
    default: 500
  - name: archive_age_days
    type: number
    default: 30
  - name: keep_recent_count
    type: number
    default: 10
validated_on:
  - "Multi-project automation ROADMAP — 696 line compression to 386 lines"
  - "Would work for any project with ROADMAP.md + Recently Completed section"
---

!`wc -l ROADMAP.md 2>/dev/null`
!`grep -c "^>" ROADMAP.md 2>/dev/null | xargs -I{} echo "Blockquote sections: {}"`

# Compress Roadmap

Archives stale completed items from ROADMAP.md. Invoked by `/compress-roadmap` command.

---

## When to Run

- ROADMAP.md exceeds {{max_lines_threshold}} lines (auto-detected by `/daily-plan` and session-summarizer)
- `## Recently Completed` has more than 20 entries
- Quarterly cleanup (Q1: April, Q2: July, Q3: October, Q4: January)
- When explicitly invoked by user

---

## Step 1 — Measure Current State

```
Read ROADMAP.md
Count total lines
Identify "## Recently Completed" section
Count entries in that section (table rows or list items)
```

Report:
```
ROADMAP.md is {N} lines. Recently Completed has {M} entries.
{threshold check: above/below {{max_lines_threshold}} lines}
```

If below threshold and fewer than 20 entries: report "No compression needed" and stop.

---

## Step 2 — Identify Archive Candidates

From `## Recently Completed` section:

1. Parse each entry's date (from "When" column or inline date pattern `YYYY-MM-DD` / `(YYYY-MM-DD)`)
2. Calculate age in days from today
3. **Archive** entries older than {{archive_age_days}} days
4. **Keep** the {{keep_recent_count}} most recent entries regardless of age
5. **Always keep** entries marked `(ongoing)`, `(active)`, or with no parseable date

**Date parsing rules:**
- Table format: `| What | When | Details |` → "When" column contains the date
- List format: `- Item description (2026-02-15)` → parenthetical date
- Bare format: `2026-02-15` anywhere in the entry
- If no date found → keep (don't archive uncertain items)

---

## Step 3 — Determine Archive File

Use current quarter to name the archive:
- Jan-Mar → `ROADMAP-ARCHIVE-{YEAR}-Q1.md`
- Apr-Jun → `ROADMAP-ARCHIVE-{YEAR}-Q2.md`
- Jul-Sep → `ROADMAP-ARCHIVE-{YEAR}-Q3.md`
- Oct-Dec → `ROADMAP-ARCHIVE-{YEAR}-Q4.md`

Archive file location: `{{archive_dir}}/ROADMAP-ARCHIVE-{YYYY}-Q{N}.md`

If archive file exists: **append** entries (don't overwrite).
If archive file doesn't exist: **create** with header:

```markdown
# ROADMAP Archive — {YEAR} Q{N}

*Items archived from ROADMAP.md. These are completed — not actionable.*
*Source: {{roadmap_file}}*

---

## Archived Completed Items

| What | When | Details |
|------|------|---------|
```

---

## Step 4 — Also Compress Active Sections

Beyond Recently Completed, also clean up:

1. **Struck-through items** (`~~text~~`) in active project sections → collapse to single-line reference if they have verbose detail blocks underneath
2. **Completed milestones** (100% progress or DONE status) in milestone tables → keep the row but remove any detail blocks below the table
3. **Resolved Known Issues** → move to archive if older than {{archive_age_days}} days

**Do NOT compress:**
- Active project sections or milestone tables with Status NEXT/LATER
- The Dependency Map section
- The End State / North Star section
- Cross-cutting concern sections (even if items within them are complete)
- Any section header itself (only content under completed headers)

---

## Step 5 — Execute Changes

1. Write archive entries to the quarterly archive file
2. Remove archived entries from ROADMAP.md
3. Clean up struck-through verbose blocks
4. Verify ROADMAP.md structural integrity:
   - All `##` section headers still present
   - No orphaned markdown (unclosed code blocks, broken tables)
   - File starts with `#` title
   - File ends cleanly (no trailing garbage)

**Safety gate**: If ROADMAP.md would drop below 200 lines → warn and confirm before proceeding.

---

## Step 6 — Report

```
Compressed ROADMAP.md:
  Before: {N} lines, {M} completed entries
  After:  {N2} lines, {M2} completed entries
  Archived: {count} items → ROADMAP-ARCHIVE-{YYYY}-Q{N}.md
  Cleaned: {count} struck-through detail blocks collapsed
  Kept: {count} recent entries (last {{archive_age_days}} days)
  Reduction: {percent}%
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Delete items without archiving | Loses audit trail of what was accomplished | Always archive to quarterly file first |
| Archive items less than {{archive_age_days}} days old | Removes recent context needed for daily planning | Only archive items older than threshold |
| Remove section headers during cleanup | Breaks ROADMAP structure for future sessions | Only remove content under completed sections |
| Archive without checking date parsability | Could archive active items with no date | Keep items with no parseable date |
| Hardcode project-specific section names | Breaks when used on different projects | Use generic patterns (Recently Completed, struck-through text) |

---

## Integration Points

| Component | How It References This Skill |
|-----------|------------------------------|
| `session-summarizer.sh` | Warns when ROADMAP > 500 lines: "Run /compress-roadmap" |
| `daily-plan-generator` | Shows in Context Health section when threshold exceeded |
| `hookify.auto-rules.local.md` | SessionStart injects ROADMAP size warning |
| `/daily-plan` command | Related command listed in help text |

---

*Skill version: 1.0 | Template-managed | 2026-02-24*
