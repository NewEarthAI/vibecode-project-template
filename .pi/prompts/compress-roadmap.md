---
description: "Archive stale completed items from ROADMAP.md when it grows beyond 500 lines."
---

# /compress-roadmap — ROADMAP Compression

Compress ROADMAP.md by archiving old completed items. Run when ROADMAP.md exceeds 500 lines.

## What This Does

1. Reads ROADMAP.md and counts lines
2. Identifies items in `## Recently Completed` that are older than 30 days
3. Moves them to `ROADMAP-ARCHIVE-{YYYY}-Q{N}.md` (creates it if needed)
4. Trims the Recently Completed section in ROADMAP.md
5. Reports: lines before → lines after, items archived

## When to Run

- ROADMAP.md exceeds 500 lines (auto-detected by `/daily-plan`)
- `## Recently Completed` has more than 20 entries
- Quarterly cleanup (Q1: April, Q2: July, Q3: October, Q4: January)

## Execution Steps

### Step 1 — Measure

```bash
wc -l ROADMAP.md
# Count lines in ## Recently Completed section
```

Report: "ROADMAP.md is {N} lines. Recently Completed has {M} entries."

### Step 2 — Identify Archive Candidates

From `## Recently Completed`:
- Archive entries **older than 30 days** based on the "When" date column
- Keep the most recent 10 entries regardless of age (preserve recent context)
- Always keep any entry marked `(ongoing)` or `(active)`

### Step 3 — Determine Archive File

Use current quarter:
- Jan-Mar → `ROADMAP-ARCHIVE-{YEAR}-Q1.md`
- Apr-Jun → `ROADMAP-ARCHIVE-{YEAR}-Q2.md`
- Jul-Sep → `ROADMAP-ARCHIVE-{YEAR}-Q3.md`
- Oct-Dec → `ROADMAP-ARCHIVE-{YEAR}-Q4.md`

If archive file exists: append. If not: create with header.

### Step 4 — Execute

1. Write archive entries to `ROADMAP-ARCHIVE-{YYYY}-Q{N}.md`
2. Remove those entries from `## Recently Completed` in ROADMAP.md
3. Verify ROADMAP.md still has valid structure

### Step 5 — Report

```
Compressed ROADMAP.md:
- Before: {N} lines, {M} completed entries
- After: {N2} lines, {M2} completed entries
- Archived: {count} items → ROADMAP-ARCHIVE-{YYYY}-Q{N}.md
- Kept: {count} recent entries (last 30 days)
```

## Archive File Format

```markdown
# ROADMAP Archive — {YEAR} Q{N}
*Items moved from ROADMAP.md on {date}. These are completed — not actionable.*

## Archived Completed Items

| What | When | Details |
|------|------|---------|
| {row from Recently Completed} | ...
```

## Safety Rules

- **Never delete** items that are less than 30 days old
- **Never remove** active project sections, milestone tables, or items with Status NEXT/LATER
- **Never remove** the End State table, Dependency Map, Known Issues, or How This Document Works sections
- If ROADMAP.md would drop below 200 lines after compression → warn and ask before proceeding
- If unsure about an item's date → keep it

## Related Commands

- `/daily-plan` — invokes compress reminder when ROADMAP > 500 lines
- `/push-to-template` — propagates template-managed changes to template repo

---
*Template-managed | 2026-02-24*
