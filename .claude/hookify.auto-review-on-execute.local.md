---
name: auto-review-on-execute
enabled: true
event: Stop
action: addContext
---

## Smart Dispatch Review — Post-Implementation

If you made code changes this session (plan execution, feature work, or bug fix), run a targeted review before completing.

### Step 1: Detect Changes
Run `git diff --stat` to identify changed file types.

### Step 2: Dispatch Reviewers (minimum 2, maximum 6)

**ALWAYS run:**
- `newearthai-code-reviewer` (master code review)
- `silent-failure-hunter` (silent failure detection)

**ADD based on file types:**
- `.sql` / `migrations/` → `postgresql-code-review`
- `auth/` / `security/` / `credential` / `.env` → `newearth-security`
- `.tsx` / `.css` / `.html` / `components/` → `design-review`
- Creating a PR → `pr-review-toolkit:review-pr` (full 6-agent sweep)

### Step 3: Report
Synthesize findings into a single report grouped by severity (CRITICAL → SIGNIFICANT → MINOR).

**Skip if**: No code changes this session, or session was read-only research/planning.
