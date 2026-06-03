---
name: roadmap-freshness
enabled: true
event: Stop
action: addContext
---

# ROADMAP Freshness Check — Stop Event

Before ending this session, check whether completed work should be reflected in `ROADMAP.md`.

**Check**: Review the todo list or session work. Did you complete any of these?
- A feature, fix, or deployment that maps to a ROADMAP project or milestone
- Work that changes the status of any milestone (progress %, Status column)
- A new capability that should appear in "Recently Completed"

**If YES**: Update `ROADMAP.md` before the session ends:
1. Update the relevant milestone's progress % and Status in its project table
2. Update any Active Tasks descriptions that changed
3. Add an entry to the "Recently Completed" table (newest first, include date + 1-line summary)
4. If a LATER milestone is now unblocked, change its Status to NEXT

**If NO**: No action needed.

**Why this matters**: `/daily-plan` and `/clientprojectupdate` read ROADMAP.md to determine current state. Stale ROADMAP entries cause inaccurate plans and misleading client updates. ROADMAP.md and MEMORY.md must never contradict each other.
