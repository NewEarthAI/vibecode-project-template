---
name: roadmap-multi-update
description: Auto-update all ROADMAP files (checkboxes, progress trackers, status text) when session work completes roadmap items
enabled: true
event: Stop
action: addContext
---

# Multi-ROADMAP Auto-Update — Stop Event

Before ending this session, update ALL relevant ROADMAPs to reflect completed work.

## Step 1: Quick Relevance Check

Review your session work. Did you complete anything that maps to a ROADMAP item?

1. Check the root `ROADMAP.md` for narrative status updates
2. Search for any `**/ROADMAP.md` files in subdirectories (e.g., `agency/*/ROADMAP.md`, `clients/*/ROADMAP.md`)
3. Match your session work to specific items in the relevant ROADMAP(s)

**If NONE match**: No ROADMAP update needed — skip entirely.

**If ANY match**: Proceed to Step 2 for EACH relevant ROADMAP.

## Step 2: Update Rules per ROADMAP Format

### Format A: Checkbox ROADMAPs (files with `- [ ]` items)

For each completed item:
1. **Re-read the ROADMAP file** before editing (never edit from memory)
2. Change `- [ ]` → `- [x]` on the specific line
3. Append completion annotation: ` — DONE {YYYY-MM-DD}`
4. If work is started but not complete: `- [ ]` → `- [~]` with ` — IN PROGRESS {YYYY-MM-DD} ({brief note})`
5. Add entry to **Recently Completed** table if one exists (newest first)

**False positive prevention**: Only tick items you ACTUALLY completed this session. Criteria:
- A file was created or modified → tick
- A deployment was made → tick
- A decision was documented → tick
- You only read about a topic → DO NOT tick
- You researched but didn't finish → use `[~]`

### Format B: Narrative ROADMAPs (status text, no checkboxes)

For completed work:
1. **Re-read the relevant section** before editing
2. Update inline status text (e.g., `**Status**: COMPLETE (YYYY-MM-DD)`)
3. Strikethrough completed headings: `### ~~Old heading~~ — COMPLETE (YYYY-MM-DD)`
4. Update `Depends on:` lines of newly unblocked items
5. Add entry to **Recently Completed** table if one exists (newest first)
6. Move NEXT → NOW if a blocker was cleared

### Format C: Cross-ROADMAP Sync

When you update a sub-directory ROADMAP, also update its summary block in the root `ROADMAP.md` if one exists.

## Step 3: Progress Tracker Auto-Calculation

After ANY checkbox change in a ROADMAP that has a Progress Tracker table, recalculate:

1. For each section: count checkboxes between section header and next `---` separator
2. `checked` = count of `[x]`, `unchecked` = count of `[ ]`, `partial` = count of `[~]`
3. `percentage = floor((checked + partial * 0.5) / (checked + unchecked + partial) * 100)`
4. Update the `%` column in the Progress Tracker table
5. Update the `Status` column:
   - 0% = `NOT STARTED`
   - 1-25% = `STARTED`
   - 26-75% = `IN PROGRESS`
   - 76-99% = `NEAR COMPLETE`
   - 100% = `COMPLETE`

## Step 4: Quick Contradiction Check

After updating any ROADMAP:
- Does ROADMAP contradict MEMORY.md? Fix if so — ROADMAP is source-of-truth for project status.
- Does root ROADMAP summary contradict sub-ROADMAP detail? Fix the root to match.
- Are Recently Completed entries newest-first? Reorder if not.

## Why This Matters

`/daily-plan` and `/clientprojectupdate` read ALL ROADMAPs to determine current state. Stale entries cause inaccurate plans, misleading client updates, and lost context across sessions.
