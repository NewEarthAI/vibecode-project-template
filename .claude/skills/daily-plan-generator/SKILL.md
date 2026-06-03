---
name: daily-plan-generator
description: |
  Generate a prioritized daily work plan for each Claude Code session.
  Reads ROADMAP System/Project/Milestone hierarchy, git history, yesterday's plan,
  continuation prompts, forged session prompts, and session state. Outputs
  NSM-impact-ranked steps with full hierarchy context and complexity tags
  ([TRIVIAL]/[MODERATE]/[COMPLEX]). Scans continuations/ for unexecuted prompts
  from prior sessions (forged prompts get scoring boost). Implements 3 design
  invariants: silent strategy review (10A), agent research context wrapper (10B),
  client update flag check (10C). Includes Vault Pulse section for Obsidian
  Second Brain health. Use when: "daily plan", "what should I work on",
  "plan my day", "session plan".
allowed-tools: Read, Write, Bash, Glob, Agent
user-invocable: true
version: 5.4
classification: encoded-preference
created: 2026-02-19
updated: 2026-04-27
template_managed: true
template_section: daily-planning
parameters:
  - name: project_root
    type: path
    default: "."
  - name: roadmap_file
    type: path
    default: "ROADMAP.md"
  - name: primary_nsm_label
    type: string
    default: "NSM"
    description: "Primary North Star Metric label (e.g. OVS, Automation Coverage, ARR)"
  - name: primary_nsm_current
    type: string
    default: "~X%"
    description: "Current Primary NSM value"
  - name: primary_nsm_target
    type: string
    default: "Y%"
    description: "Target Primary NSM value"
  - name: domain_nsms
    type: array
    description: |
      Domain-level NSMs — each is a causal input to the Primary NSM.
      Set via /setup Step 7.6.2. Leave empty for single-domain projects.
      Format per item: { label, metric, current, target }
    default: []
  - name: vault_pulse_enabled
    type: boolean
    default: true
    description: "Enable Vault Pulse section. Disable for projects without Obsidian integration."
  - name: vault_cadence_file
    type: path
    default: ".claude/vault-cadence.local.md"
    description: "Per-machine file tracking last-run dates for vault commands. Gitignored."
validated_on:
  - "Multi-project automation with 5 systems, 8 projects, 30+ milestones"
  - "Works for any project with ROADMAP.md + System/Project/Milestone structure"
  - "Single-domain projects: set domain_nsms: [] and use primary_nsm_* only"
  - "Projects with Obsidian Second Brain: vault_pulse_enabled=true surfaces overdue commands"
  - "Projects without Obsidian: vault_pulse_enabled=false skips Vault Pulse silently"
---

!`date "+%Y-%m-%d %A"`
!`git log --oneline -10 2>/dev/null`
!`git diff --stat 2>/dev/null`
!`git status --short 2>/dev/null | head -20`
!`ls continuations/*.md 2>/dev/null | tail -3`

# Daily Plan Generator

Generates a focused, prioritized daily work plan. Invoked by `/daily-plan` command.

**Setup**: Set `primary_nsm_label`, `primary_nsm_current`, `primary_nsm_target` (and optionally `domain_nsms`) via `/setup` Step 7.6.2. For single-domain projects, leave `domain_nsms` empty — the skill uses the primary NSM only.

**NSM Cascade rule**: Domain NSMs are *inputs* to the Primary NSM. Moving any Domain NSM moves the Primary NSM. If you can't draw a causal arrow from a domain item to the Primary NSM, the item doesn't belong in the roadmap.

---

## Phase 0 — Session Housekeeping (runs BEFORE plan generation)

Three automated checks that ensure the repo is in sync across all macs and the admin portal reflects reality. Runs every `/daily-plan` invocation — fast, idempotent, safe.

### 0A — Git Sync Checkpoint + Shipped Today Summary

Ensure previous sessions' work is committed/pushed AND build a full picture of what shipped today across ALL parallel sessions. This is the primary data source for plan refresh — not just the current branch.

```bash
# 1. Check for uncommitted changes
git status --short

# 2. Check for unpushed commits
git rev-list --count origin/main..HEAD

# 3. Check for open PRs from this repo that are approved but unmerged
gh pr list --state open --json number,title,reviewDecision,headRefName --jq '.[] | select(.reviewDecision == "APPROVED")' 2>/dev/null

# 4. CRITICAL: Scan all PRs merged today (across ALL branches/sessions)
git fetch origin 2>&1
gh pr list --state merged --json number,title,mergedAt,headRefName --jq '.[] | select(.mergedAt > "'$(date -u +%Y-%m-%d)'")' 2>/dev/null

# 5. Check for open PRs that may need attention (merge conflicts, stale)
gh pr list --state open --json number,title,mergeable,headRefName --jq '.[] | {number, title, mergeable, branch: .headRefName}' 2>/dev/null
```

**Shipped Today summary (ALWAYS shown when PRs merged today):**
```
## Shipped Today ({N} PRs merged)
| PR | Title | Branch |
|----|-------|--------|
| #{N} | {title} | {branch} |
...
```

This summary is the FIRST thing shown — before any plan steps. It ensures the user (and the plan) see the full picture of parallel session output.

**Decision tree:**

| Condition | Action |
|-----------|--------|
| Uncommitted changes exist | Show diff summary. Ask: "Previous session left uncommitted changes. Commit now? (y/skip)" → If yes, stage + commit with descriptive message |
| Unpushed commits on main | Show `git log --oneline origin/main..HEAD`. Ask: "Push N commits to origin/main? (y/skip)" |
| Unpushed commits on feature branch | Show branch name + commit count. Ask: "Push to origin/{branch}? Or merge to main first?" |
| Approved PR unmerged | Show PR #/title. Ask: "PR #{N} is approved — merge now? (y/skip)" |
| Open PR with merge conflicts | Flag: "PR #{N} has merge conflicts — rebase needed" |
| Open PR superseded by merged PR | Flag: "PR #{N} may be superseded by #{merged} — close?" |
| Everything clean | Print `✓ Git in sync — origin/main is up to date` and continue silently |

**Rules:**
- Never force-push or auto-merge without user confirmation
- If on a feature branch with unpushed work, offer to merge to main first (standard flow)
- If user skips all prompts, proceed to planning — this is advisory, not a gate
- **Always** run `git fetch origin` before any comparison — stale refs caused today's blind spot

### 0B — Roadmap Activity Sync

Update `bb_roadmap_activity` so the admin portal feed reflects work actually done. Reads recent git commits and maps them to roadmap items.

```bash
# Get commits since last activity sync (or last 7 days as fallback)
git log --oneline --since="7 days ago" --format="%H %s"
```

Then query the current roadmap activity to avoid duplicates:

```sql
SELECT item_id, action, created_at
FROM bb_roadmap_activity
WHERE created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC
LIMIT 50;
```

**Mapping logic:**
1. For each recent commit, check if its subject references a roadmap item (by ID, milestone name, or keyword match against `dd_roadmap_items.title`)
2. For each matched item, check if an activity entry already exists for this action+date
3. If no activity exists, INSERT into `bb_roadmap_activity`:
   ```sql
   INSERT INTO bb_roadmap_activity (item_id, action, note, created_at)
   VALUES ('{item_id}', '{completed|started|updated}', '{commit subject}', '{commit_date}');
   ```

**Action classification from commit prefix:**

| Commit prefix | Activity action |
|---------------|----------------|
| `feat:`, `fix:` | `completed` (if item status is DONE in ROADMAP) or `updated` |
| `docs:` | `note` |
| `refactor:` | `updated` |
| No match to any roadmap item | Skip — not every commit maps to a roadmap item |

**Rules:**
- Maximum 10 activity inserts per run (prevent flooding the feed)
- Never delete or modify existing activity entries
- If Supabase MCP unavailable, skip silently: `"⚠️ Supabase MCP not connected — skipping roadmap activity sync"`
- Show summary: `"Synced {N} activities to admin portal feed"` or `"✓ Activity feed up to date"`

### 0C — Pull Latest from All Macs

Pull the latest work from origin/main so the plan incorporates changes made on other Macs/Cursor instances.

```bash
# Always fetch first — stale refs caused the 2026-04-12 blind spot
git fetch origin 2>&1

# Then pull if working tree is clean (0A should have resolved this)
git pull --ff-only origin main 2>&1
```

**Decision tree:**

| Condition | Action |
|-----------|--------|
| Fast-forward succeeds | Print `✓ Pulled {N} commits from origin/main` |
| Already up to date | Print `✓ Already up to date with origin/main` |
| Fast-forward fails (diverged) | **Auto-diagnose**: run `git log --oneline main --not origin/main` to identify local-only commits. These are almost always pre-squash versions of PRs that were already merged via GitHub. Show the diverged commits and ask: `"Local main has {N} commits not on origin (likely pre-squash PR versions). Reset to origin/main? (y/skip)"`. If yes → `git checkout -B main origin/main`. This is safe because PRs are the source of truth. |
| Not on main branch | Pull main into current branch only if user confirms: `"You're on {branch}. Pull latest main? (y/skip)"` |

**Rules:**
- **Always `git fetch origin` first** — every single invocation. Stale remote refs are the #1 cause of daily-plan blind spots.
- Always `--ff-only` — never create merge commits automatically
- If pull brings new commits, re-read ROADMAP.md in Step 1 (the existing Step 1 already does this)
- If pull fails due to divergence, **prefer origin/main** (PRs are source of truth). Never leave diverged state — it cascades into wrong plan data.
- If user skips divergence fix, proceed with planning but warn: plan may not reflect actual shipped work

---

## Phase 0.5 — Founder Identity & Cross-Repo PR Inbox

Personalize the plan to the founder running the session. Bridges the `.claude/team.json` identity registry to the daily plan output. Crucial for multi-founder collaboration where each founder has different lanes (build vs. operate) and different review queues across multiple repos. Skips silently for solo projects (no team.json present).

### 0.5A — Resolve Current Founder

Read `.claude/team.json` and resolve the active founder via the GitHub CLI:

```bash
ME=$(gh api user --jq .login 2>/dev/null)
TEAM_FILE=".claude/team.json"

if [ -f "$TEAM_FILE" ] && [ -n "$ME" ]; then
  FOUNDER_NAME=$(jq -r ".founders[\"$ME\"].name // empty" "$TEAM_FILE")
  FOUNDER_LANE=$(jq -r ".founders[\"$ME\"].eos_lane // empty" "$TEAM_FILE")
  FOUNDER_RESP=$(jq -r ".founders[\"$ME\"].responsibilities // [] | join(\", \")" "$TEAM_FILE")
fi
```

**Skip gracefully** if either condition fails:
- `gh` not authenticated → `ME=""` → skip personalization, continue with generic plan
- `team.json` missing or no entry for this user → note "No founder profile for $ME — generic plan" → continue
- Solo project (no team.json) → skip 0.5 entirely — the skill works for solo projects too

### 0.5B — Cross-Repo PR Inbox (Awaiting Your Action)

Surface PRs across all accessible repos that are waiting on the current user. GitHub's `@me` token resolves server-side per machine, so the same query returns each founder's own slice without per-user branching.

```bash
# What's awaiting MY review across all my accessible repos
gh search prs --review-requested=@me --state=open \
  --json repository,number,title,author,updatedAt --limit 20 2>/dev/null

# What I authored that's still open (across all my repos)
gh search prs --author=@me --state=open \
  --json repository,number,title,reviewDecision,updatedAt --limit 20 2>/dev/null

# Changes requested on my open PRs (need my response)
gh search prs --author=@me --state=open --review=changes-requested \
  --json repository,number,title --limit 10 2>/dev/null
```

**Why `gh search prs` not `gh pr list`**: `gh pr list` is repo-scoped. `gh search prs` is account-wide — surfaces work across BuyBox-AI + every side repo the founder has access to. Critical for the docs/COLLABORATING.md side-repo integration patterns.

**Group output by repo and surface to plan**:
```
🔴 Awaiting your review (N): grouped by repo
🟡 Your open PRs (N): grouped by repo, flag changes-requested in red
🟢 You shipped today: N PRs across R repos (from Phase 0A)
```

If both queries empty → `✓ Inbox clear — no PRs awaiting your action`.

**Priority escalation**: If "Awaiting your review" has any item >24h old, mark with 🚨 in both plan file and chat summary — review debt compounds fast on a 2-person team.

### 0.5C — Lane-Aware Focus

If `FOUNDER_LANE` was resolved in 0.5A, append a lane block to the plan file:

```markdown
## Today's Lane: {FOUNDER_NAME}
> {FOUNDER_LANE}
> Core: {FOUNDER_RESP}
```

**Optional drift detection** (runs only if both founders are present in team.json):

```bash
# Justin's expected lane (build) → src/, supabase/, .claude/
# Chris's expected lane (operate) → strategy/, ROADMAP.md, specs/*.md (proposals)

git log --author="$(git config user.email)" --since="7 days ago" \
  --name-only --pretty=format: 2>/dev/null \
  | sort -u | grep -cE '^(strategy/|ROADMAP\.md|specs/.*\.md)$' 2>/dev/null
```

If the count exceeds a soft threshold (>3 over 7 days for an out-of-lane founder), surface in Context Health:
```
⚠️ Lane drift signal — {N} commits in {other founder}'s lane this past week.
   Per team.json operating_principles: both founders are V/I hybrids — drift is
   a signal, not a violation. Worth a quick check on responsibilities.
```

Never blocks. Per `team.json.operating_principles.both_v_i_hybrids` — overlapping domains are expected; only **persistent drift** is the signal worth flagging.

### 0.5D — Cross-Repo Activity Snapshot (Other Founder's Output)

Awareness of what the other founder shipped while you weren't online — keeps both sides synced without requiring meetings.

```bash
OTHER_FOUNDER=$(jq -r ".founders | to_entries | map(select(.key != \"$ME\")) | .[0].key // empty" "$TEAM_FILE" 2>/dev/null)

if [ -n "$OTHER_FOUNDER" ]; then
  gh search prs --owner NewEarthAI --merged --author "$OTHER_FOUNDER" \
    --merged-at ">$(date -u -v-1d +%Y-%m-%d)" \
    --json repository,number,title,mergedAt --limit 10 2>/dev/null
fi
```

**Output only if other founder shipped something** (otherwise skip silently):
```
🌍 Across the org in last 24h:
  • {OTHER_FOUNDER} shipped {N} PRs:
    - {repo}#{number} — {title}
```

### Rules

- All cross-repo queries are **read-only** — never mutate via this phase
- Every `gh search` command degrades gracefully on rate-limit / network failure → skip section, proceed
- Solo project (no team.json) → skip Phase 0.5 entirely; existing skill behavior unchanged
- Cross-repo PR inbox is **informational** — does NOT auto-add review tasks to the scored plan steps. Founder picks what to tackle.
- "Across the org" snapshot uses `NewEarthAI` as the org owner; configurable via team.json future field if multi-org becomes a thing
- Phase 0.5 must complete in < 5 seconds total — if any single `gh search` exceeds 3s, kill and skip that subsection

---

## Phase 0.6 — Collab Inbox (Incoming /collab Items)

Surfaces collabs filed by the OTHER founder where the running founder is the recipient. Parallel to Phase 0.5B's PR inbox — but for `bb_collab_log` rows instead of GitHub PRs. Skips silently if `bb_collab_log` table doesn't exist (skill not yet installed) or Supabase MCP unavailable.

### 0.6A — Query open collabs awaiting current founder

Requires `$ME` resolved in Phase 0.5A. Skip if `$ME` is empty or `team.json` missing.

```sql
-- Open + handoff collabs where current founder is recipient
SELECT
  collab_id,
  classified_type,
  mode,
  founder_name AS sender_name,
  raw_input,
  created_at,
  EXTRACT(EPOCH FROM (now() - created_at)) / 3600 AS age_hours
FROM bb_collab_log
WHERE recipient_github = '$ME'
  AND status IN ('open', 'in_progress')
ORDER BY
  mode = 'handoff' DESC,  -- handoffs first
  created_at ASC          -- oldest first within mode
LIMIT 20;
```

**Skip gracefully** if Supabase MCP unavailable OR `bb_collab_log` table doesn't exist (caught via PostgREST 404). Note: "Collab inbox skipped — bb_collab_log not yet installed (run /collab skill migration)."

### 0.6B — Group + escalate by age

| Age | Visual | Notes |
|---|---|---|
| <24h | normal `🆕` | Recent; surfaced informationally |
| 24-72h | bold `⚠️` | Aging; surface in chat summary |
| >72h | bold `🚨` | Stale; chat-summary header alert |

### 0.6C — Surface to plan file

Output section (after Phase 0.5D, before scored work):

```markdown
## Collab Inbox (from /collab — Phase 0.6)

🔴 Handoffs you owe action (M):
  • CL-CM40-0011 — Review Pace Morby PSA template diff (handoff, from Chris, 4h ago)

🔵 Awaiting your consideration (N):
  🚨 CL-OPS-0099 — Dashboard slow on his Mac (issue, from Chris, 4d ago)
  ⚠️ CL-CM38-0007 — Reverse dispo angle (feedback, from Chris, 1d ago)
  🆕 CL-PARTNER-0023 — Trever 0% down 50yr (idea, from Chris, 2h ago)

✅ Recently integrated by you (last 24h): K
   (run `/collab pull <id>` to integrate one; `/collab inbox` for full list)
```

**Empty state**: `✓ Collab inbox clear — no incoming collabs awaiting your action`

### 0.6D — Score boost for handoffs (feeds Step 3 scoring)

Handoff-mode collabs (`mode='handoff'`) where the recipient is the running founder enter the scored plan steps with **score = 88** (just below carry-forward at 85, above primary NSM improvement at 78).

**Why 88 not 85**: The other founder explicitly asked for action — that's a stronger commitment signal than yesterday's incomplete carry-forward (might be done, blocked, or deprioritized).

Outbound-mode collabs (`mode='outbound'`, types: idea / feedback / news / etc.) appear in the inbox section above but are **NOT auto-added** to scored work. The recipient picks what to integrate via `/collab pull <id>` per `.claude/skills/collab/SKILL.md` §pull-in.

### Rules

- Phase 0.6 is read-only — never mutates `bb_collab_log` or `bb_collab_relationships`
- Skip silently if Supabase MCP unavailable, OR `bb_collab_log` table missing (skill not installed yet), OR `team.json` missing
- Score 88 only applies to `mode='handoff'` rows; outbound collabs stay informational
- Maximum 10 inbox entries surfaced (older entries summarized as "+N more — run /collab inbox")
- Phase 0.6 must complete in <3 seconds — single SELECT, no joins needed

---

## Step 0 — Check for Existing Plan

Before generating anything, check if today's plan already exists:

```bash
Read .claude/daily-plans/PLAN-{today-YYYY-MM-DD}.md
```

**If plan EXISTS**:
1. Read the existing plan
2. Cross-reference against **merged PRs from Phase 0A** (primary source) AND recent git commits to identify what's been completed since the plan was written. The PR list is authoritative because parallel sessions work on feature branches — git log on the current branch misses everything done in other sessions.
3. Display a **refreshed summary** showing completed vs remaining steps, with merged PRs as evidence
4. Show the same approval gate ("go" / "go team") for the remaining work
5. Only regenerate the plan file if significant items have changed (new completions, new NEXT milestones)

**If plan DOES NOT exist**: proceed to Step 1 (generate from scratch).

This means `/daily-plan` is safe to run multiple times per day — first run generates, subsequent runs resume.

---

## Step 1 — Read Context (All In Parallel)

```bash
# 1. ROADMAP — extract System/Project/Milestone sections
Read ROADMAP.md  # extract all ## System: sections with ### Project headers

# 2. Recent work
git log --oneline --since="3 days ago"

# 3. Uncommitted changes from other sessions (cross-chat awareness)
git diff ROADMAP.md  # detect work done but not committed by another active chat

# 4. Yesterday's plan (skip silently if not found)
Read .claude/daily-plans/PLAN-{yesterday-YYYY-MM-DD}.md

# 5. Last session summary (most recent SESSION-*.md)
ls -t .claude/sessions/SESSION-*.md 2>/dev/null | head -1 → Read that file

# 6. Client update flag
Read .claude/sessions/session-state.env  # look for CLIENTUPDATE_PENDING=true

# 7. ROADMAP rot check
wc -l ROADMAP.md

# 8. ROADMAP staleness check (compare ROADMAP commit age vs overall repo activity)
git log -1 --format="%ci" -- ROADMAP.md   # last ROADMAP commit date
git log -1 --format="%ci"                  # last ANY commit date
```

**ROADMAP staleness rule**: If the most recent ROADMAP.md commit is older than the most recent non-ROADMAP commit by 3+ days, surface a warning in Context Health: `"⚠️ ROADMAP.md last updated {date}, but {N} commits since then don't touch ROADMAP. Plan may not reflect current work state. Consider updating ROADMAP or submitting a journal note."` This catches repos where an external task tracker (e.g., ClickUp) is SOT but ROADMAP is used for planning.

**Skip gracefully** if any file doesn't exist — all inputs are optional except ROADMAP.md.

**Cross-chat awareness**: If `git diff ROADMAP.md` shows uncommitted changes, incorporate them into planning. Another active session may have completed work that isn't committed yet. The diff reveals the true current state.

---

## Step 1A — Continuation & Prompt Audit

Scan `continuations/` for recent unexecuted prompts. These represent planned work from prior sessions that was forged but never run — high-value carry-forward.

```bash
# 1. Find recent continuations (last 3 days) for NEW discovery
ls -t continuations/*-2026-{MM}-{recent_days}*.md 2>/dev/null | head -20

# 2. Get git log subjects to cross-reference
git log --oneline --since="3 days ago" --format="%s"

# 3. Check uncommitted code changes (in-progress work from other sessions)
git status --short | grep -E '^\s?M\s+src/' | head -10
```

**Carry-forward bypass**: The 3-day window above is for DISCOVERING new continuations. Continuations linked from yesterday's plan carry-forward are verified in **Step 1C** regardless of file age — a continuation from 2 weeks ago that was carry-forwarded yesterday still gets checked.

**Cross-reference logic (two-tier — explicit status first, heuristic fallback):**

**Tier 1 — Explicit `impl_status` frontmatter (preferred):**
Check each continuation file for HTML comment frontmatter:
```
<!-- impl_status: pending | in_progress | ready-to-execute | completed | superseded | blocked -->
<!-- impl_session: YYYY-MM-DD or (none yet) -->
<!-- impl_completed_date: YYYY-MM-DD or empty -->
<!-- next_session_mandate: <one-line directive from prior session author> -->
```

If `impl_status` exists, trust it over git heuristics — it was set explicitly by the session that generated or executed the continuation.

**Tier 1+ — `next_session_mandate` is the highest-priority signal.** When a continuation has this frontmatter field, the prior session explicitly told the next session what to do. The mandate items become the FIRST entries in today's scored work, regardless of complexity. Score: 95.

**Mandatory body read for new continuations.** For every continuation file modified within the past 48 hours that is NOT marked `completed` or `superseded`, READ the first 80 lines (TOC, strategic context, "current state / open work" sections). Filename and frontmatter alone are insufficient — the prior session encoded action items in the body. If the file is >50KB, read first 80 + last 40 lines.

**Tier 2 — Git heuristic fallback (for files without frontmatter):**
For files missing `impl_status`, fall back to the original cross-reference:
1. Extract the **title** (first `#` heading) and **date** from filename
2. Check if a git commit subject references this work (fuzzy match on keywords)
3. Check if the continuation contains a `## Verification` section with checkable conditions
4. If verification conditions exist, run 1-2 quick checks (SELECT counts, file existence) to determine completion status

**Classify each continuation:**

| Status | Condition | Action |
|--------|-----------|--------|
| **Mandate** | `next_session_mandate:` frontmatter present AND not completed | Surface mandate items as TOP scored steps (score: 95). The prior session explicitly directed today's work. |
| **Ready-to-Execute** | `impl_status: ready-to-execute` | Surface as "execute this next" (score: 92). Stronger signal than `pending` — author marked it ready. |
| **Completed** | `impl_status: completed` OR (Tier 2: commit references + verification pass) | Mark as done, skip |
| **In Progress** | `impl_status: in_progress` | Surface as "active work — check if session is still running or stalled" (score: 88) |
| **Blocked** | `impl_status: blocked` | Surface as "blocked work — investigate blocker" (score: 80) |
| **Superseded** | `impl_status: superseded` | Skip silently |
| **Not Started** | `impl_status: pending` OR (Tier 2: no match, file < 3 days old) | Surface as candidate work item (score: 82) |
| **Unverified** | Tier 2: commit references but verification fails/missing | Surface as "verify previous work" (score: 75) |
| **Stale** | `impl_status: pending` AND file > 5 days old, OR (Tier 2: no match, file > 5 days old) | Surface in Context Health as "⚠️ {N} stale continuations" |

**When picking up a continuation**: The session MUST update the file's `impl_status` from `pending` → `in_progress` and commit the change. This ensures other Macs see the status update after `git pull`.

**Scoring:**
- Not-started continuations get **82 points** (just below carry-forward's 85, because the user chose not to run them yet — they're candidates, not commitments)
- Unverified continuations get **75 points** (verification debt — should be resolved before new work)
- Forged prompts (`FORGED-*`) get **+3 bonus** (represent deliberate future-session planning via `/prompt-forge`)

**Output to plan:** Each surfaced continuation becomes a plan step with:
```markdown
### Step N — [{COMPLEXITY}] {Continuation title}
> Continuation: continuations/{filename}
> Status: Not started | Needs verification
> Created: {date from filename}
> Why: Planned work from prior session — {1-line from file's first paragraph}
> Action: Open new session with this continuation prompt | Run verification checks
```

**Rules:**
- Maximum 3 continuations surfaced in the plan (don't overwhelm)
- Prefer not-started forged prompts > not-started master continuations > unverified
- If >5 stale continuations exist, add a housekeeping task: "Review and archive stale continuations"
- Never auto-delete continuations — they're the user's planned work

---

## Step 1B — Vault Pulse (Obsidian Second Brain Health Check)

**Skip entirely** if `vault_pulse_enabled` is `false` or if `.claude/obsidian-second-brain.local.md` does not exist.

This step checks the health of the Obsidian Second Brain and surfaces actionable reminders. It runs alongside Step 1 context reads.

### 1B.1 — Read Cadence Tracking File

```bash
Read .claude/vault-cadence.local.md
```

This file (gitignored, per-machine) tracks when vault commands were last run:

```yaml
---
last_drift: "2026-03-01"
last_emerge: "2026-02-15"
last_vault_sync: "2026-03-07"
last_vault_review: "2026-03-01"
---
```

If the file doesn't exist, create it with all dates set to `"never"`.

### 1B.2 — Check Pending Vault Deposits

Query Supabase for pending `vault_deposit` actions (requires Supabase MCP):

```sql
SELECT COUNT(*) as pending_count
FROM knowledge_actions
WHERE action_type = 'vault_deposit'
  AND status = 'proposed'
  AND entity_slug = '{current_project_slug}';
```

**Project filter**: Always filter by the current project's slug to avoid showing deposits from other projects. The `entity_slug` comes from the PROFILE.yaml identity section or the project's CLAUDE.md slug field. Without this filter, running `/daily-plan` in one project shows deposits from all projects — creating false urgency.

**If MCP unavailable**: skip this check silently (note "Supabase MCP not connected — vault-sync check skipped").

**If pending_count > 0**: flag for the Vault Pulse output section.

### 1B.3 — Calculate Cadence Overdue Status

Using the dates from the cadence file, check:

| Command | Cadence | Overdue when |
|---------|---------|-------------|
| `/drift` | Every 14 days | last_drift + 14 < today |
| `/emerge` | Every 30 days | last_emerge + 30 < today |
| `/vault-sync` | Every session (if deposits exist) | pending_count > 0 |
| `/vault-review` | Every 14 days | last_vault_review + 14 < today |

### 1B.4 — Count Vault Notes (Quick Health)

```bash
find {vault_path} -name "*.md" -not -path "*/.obsidian/*" | wc -l
find {vault_path}/daily -name "*.md" 2>/dev/null | wc -l
```

Capture total note count and daily note count for the Vault Pulse display.

### 1B.5 — Vault Pulse Output Section

Include in the plan file (after Context Health section):

```markdown
## Vault Pulse
- Vault: {vault_path} ({N} notes, {D} daily)
- Pending deposits: {count} {→ run /vault-sync | ✓ none}
- /drift: last {date} {✓ on schedule | ⚠️ overdue by N days — run /drift}
- /emerge: last {date} {✓ on schedule | ⚠️ overdue by N days — run /emerge}
- /vault-review: last {date} {✓ on schedule | ⚠️ overdue — run /vault-review}
{⚠️ Vault has < 10 daily notes — write more before /drift produces meaningful results}
```

**Chat summary addition**: If ANY vault item is actionable (deposits pending OR command overdue), append to the chat summary:

```
🧠 Vault: {N pending deposits | /drift overdue | /emerge overdue} — see Vault Pulse section
```

**Important**: Vault Pulse is informational only. It never blocks the plan or changes task scoring. It's a gentle nudge, not a gate.

---

## Step 1C — Carry-Forward Verification Gate (MANDATORY)

Before scoring, EVERY carry-forward item from yesterday's plan MUST be re-verified against current reality. Never trust yesterday's status assessment — things ship in parallel sessions, PRs merge overnight, and continuations get executed in other chats.

**This step exists because carry-forward items are the #1 source of daily plan inaccuracy.** Without it, the plan blindly inherits yesterday's (now stale) status, causing completed work to resurface as "NOT STARTED" — wasting the user's time and eroding trust in the plan.

### 1C.1 — Collect carry-forward candidates

From yesterday's plan (read in Step 1), extract all steps that were NOT marked as complete. For each, note:
- Task name
- Linked continuation path (if any)
- Number of consecutive days this item has been carried forward (check plans from N-2, N-3 if they exist)

### 1C.2 — Three-check verification

For each carry-forward candidate, run these checks IN ORDER. If ANY check proves completion, mark as DONE and exclude from today's plan.

**Check 1 — Continuation `impl_status` (if linked)**

Read the linked continuation file's frontmatter. This check applies **regardless of file age** — carry-forward items bypass the Step 1A 3-day scan window:
```bash
head -5 continuations/{linked_file} 2>/dev/null | grep "impl_status"
```
- `impl_status: completed` → **DONE. Stop checking.**
- `impl_status: superseded` → **DONE. Stop checking.**
- `impl_status: in_progress` → Check if the session that claimed it is still active or stalled. If stalled (no commits in 24h), treat as incomplete.
- `impl_status: pending` or missing → Continue to Check 2.

**Check 2 — Merged PRs (7-day window)**

Scan PRs merged in the last 7 days (broader than Phase 0A's today-only scan):
```bash
gh pr list --state merged --json number,title,mergedAt,headRefName \
  --jq '[.[] | select(.mergedAt > "YYYY-MM-DD")] | sort_by(.mergedAt) | reverse' 2>/dev/null
```
Where `YYYY-MM-DD` = 7 days ago.

Match PR titles against the carry-forward task name using keyword overlap (e.g., "Guided Tour" in task matches "Phase 2 guided tours" in PR title). Also check if the PR's branch name matches the continuation's branch reference.

If a merged PR clearly addresses the carry-forward item → **DONE. Stop checking.**

**Check 3 — Codebase spot-check (for items carried forward 2+ days)**

If the item has appeared in 2+ consecutive daily plans as incomplete, run a targeted verification based on the item's domain:

| Domain | Spot-check |
|--------|-----------|
| Frontend feature | `ls` or `grep` for expected component/file |
| Test coverage | `find tests/ -name "*keyword*"` + count |
| Database/migration | Query `information_schema` or check migration files |
| n8n workflow | Check recent execution status via MCP |
| Bug fix | `grep` for the fix pattern in the relevant file |
| Design/docs | Check if the output file exists |

If the spot-check confirms the work is done → **DONE.**

### 1C.3 — Update carry-forward list

After verification, produce a verified carry-forward summary. Items that passed any check are struck through with evidence. Only genuinely incomplete items enter the scoring pipeline (Step 3).

**Output format** (included in the plan file's carry-forward section):
```markdown
## Carry-forward from {yesterday's date}

| Yesterday's Step | Verdict | Evidence |
|-----------------|---------|----------|
| {Task A} | ✅ Complete | PR #{N} merged {date} |
| {Task B} | ✅ Complete | impl_status: completed |
| {Task C} | ⚠️ Still incomplete | No PR, no impl_status, no codebase match |
| {Task D} | ⚠️ Carried 3+ days | Investigate why this isn't shipping |
```

### Rules

- **NEVER skip this step** — even if "everything looks the same as yesterday"
- Read continuation `impl_status` **regardless of file age** — carry-forwards bypass the 3-day window
- PR scan uses **7-day window** for carry-forward verification (separate from Phase 0A's today-only scan)
- Items carried forward **3+ consecutive days** get a mandatory ⚠️ flag: `"Carried 3+ sessions — investigate: is this blocked, deprioritized, or done but unrecognized?"`
- If all carry-forward items verify as complete, say so explicitly: `"All carry-forward items verified complete — clean slate today"`
- Verification evidence must be specific (PR number, commit hash, file path) — not vague ("probably done")

---

## Step 1D — Fleet Audit (Phase 1.5 from /verify-shipped composition, added 2026-05-07 v1.1)

Read fleet shipping state via `/verify-shipped`. Surfaces drift across 6 layers (worktree, branch, PR, edge function deploy, migration apply, Vercel deploy lag) BEFORE the NSM-rank pass so fleet items compete fairly with feature work.

### 1D.1 — Read cached state OR refresh

```bash
bash .claude/skills/verify-shipped/scripts/read-state.sh
rc=$?
```

Decision tree on `rc`:
- `0`: parse the JSON returned on stdout — proceed to 1D.2
- `1` (missing/stale/interrupted): invoke `Skill verify-shipped quick` synchronously (~10s); re-read state via `read-state.sh`
- `2` (malformed): log `[INFO] fleet state file malformed — skipping fleet section`; skip to Step 2

### 1D.2 — Render Shipping Integrity header

After Step 1C output (Carry-Forward summary), append:

If clean (`exit_code == 0`):
```markdown
🚢 Shipping integrity: 10/10 ✓ (last verified {relative time})
```

If drift (`exit_code == 1`):
```markdown
🚢 Shipping integrity: {fleet_integrity_score}/10 ({total_issues} issues — {layer1_count} worktree, {layer2_count} branch, {layer3_count} PR, {layer5_count} deploy drift, {layer6_count} migration; last verified {relative time})
```

Suppressed entries (per `.claude/verify-shipped-suppress.json`) appear in the header but NOT as work items:
```markdown
🚢 Shipping integrity: 8/10 (2 issues — 1 PR, 1 deploy; 3 suppressed)
```

### 1D.3 — Surface fleet findings as candidate work items

Each non-suppressed finding produced by `/verify-shipped` becomes a candidate work item, fed into the Step 3 scoring pipeline alongside ROADMAP NEXT items + verified-incomplete carry-forwards. For each finding:

| Finding | Verb-first label | Effort tag | Action |
|---|---|---|---|
| `[DIRTY] <path> <N>` | Commit or stash {N} uncommitted changes in {worktree-name} | [TRIVIAL] | `cd <path> && git status` (then commit or stash) |
| `[STALE] <path> on <branch>` | Push {N} unpushed commits on {branch} | [TRIVIAL] | `cd <path> && git push` |
| `[AHEAD] <branch> <N>` | Push {N} unpushed commits on {branch} | [TRIVIAL] | `git push origin <branch>` |
| `[DIVERGED] <branch> <a>/<b>` | Reconcile diverged branch {branch} ({a} ahead, {b} behind) | [MODERATE] | `git fetch && git checkout <branch> && git pull --rebase` |
| `[NO_UPSTREAM] <branch>` | Decide on untracked branch {branch} | [TRIVIAL] | push -u OR delete |
| `[STALE_LOCAL] <branch>` | Clean up branch {branch} (upstream gone) | [TRIVIAL] | `git branch -D <branch>` |
| `[FAILING_CI] PR #N` | Fix failing CI on PR #{N} | [MODERATE] | `gh pr checks <N>` |
| `[STALE_OPEN_PR] PR #N` | Decide on stale PR #{N} ({age} no activity) | [MODERATE] | ship/close/comment |
| `[MERGED_NOT_CLEANED] PR #N` | Clean up merged-not-deleted worktree from PR #{N} | [TRIVIAL] | `git worktree remove ... && git branch -D ...` |
| `[DRIFT] <fn-name>` | Deploy edge function {fn-name} to production | [MODERATE] | `supabase functions deploy <fn> --project-ref ...` |
| `[PENDING_APPLY] <migration>` | Apply pending migration {name} to production | [MODERATE] | `mcp__supabase-.*__apply_migration` |

### 1D.4 — Score severity for Step 3 ranking

Map fleet findings into the existing scoring rubric:

| Severity class | Findings | Score input |
|---|---|---|
| Production drift (silent-killer class — Cedar Hurst doctrine) | DRIFT (Layer 5), PENDING_APPLY (Layer 6) | Score = 78 (Primary NSM impact >10%) |
| Work-in-progress unblock | AHEAD, STALE_OPEN_PR, FAILING_CI, DIVERGED | Score = 65 (unblocks LATER milestone) |
| Housekeeping | DIRTY, MERGED_NOT_CLEANED, NO_UPSTREAM, STALE_LOCAL | Score = 50 (maintenance / debt) |

Tie-break by `severity × age_hours / urgency_decay` — older findings rank higher within the same class.

### Rules

- **NEVER block** — fleet audit failure is graceful-degrade, not halt-plan
- **Suppressed findings** ARE NOT surfaced as work items, but DO appear in the header count
- **Cached state preferred** — only invoke `Skill verify-shipped quick` when read-state.sh returns exit 1
- Fleet section is **inline in the plan**, not a separate document — one source of truth for the day's work
- If `gh` CLI not authenticated, Layer 3 emits `[skip]` and is invisible to this step (correct behaviour — degrade quietly)

---

## Step 2 — Invariant 10A: Silent Strategy Review

Before scoring any work items, silently run these 3 alignment tests on the top 3 active tasks (milestones with Status=NEXT):

**First: resolve each item's NSM target.** For each item, check which Domain NSM it most directly affects (if `domain_nsms` is populated). If no domain match, check against the Primary NSM directly.

| Test | Question | Fail condition |
|------|----------|---------------|
| A | Does this task's Project connect to a {{primary_nsm_label}} component? | Project has no NSM Component in End State table |
| B | Is there a carry-forward blocker making this premature? | Predecessor step incomplete from yesterday |
| C | Is there a higher-leverage task in a near-complete project (>80%)? | Finishing a nearly-done project would be higher impact |

**Rules:**
- If ALL tests pass → **proceed silently** (no strategy note shown)
- If ANY test fails → surface **ONE concern max** (highest-impact failure first)
- **Never block** — strategy review is advisory only
- **Never surface a concern if ROADMAP.md hasn't changed** since the last session date in SESSION-*.md
- Surface at most 1 concern per /daily-plan invocation

**Concern output format** (only when warranted):
```
⚠️ Strategy note: {item} may be premature because {1-line reason}.
   Consider: {alternative}. Proceed with original order? (y/change)
```

---

## Step 2.5 — Destination Glance (read DESTINATION.md, compute staleness)

Surfaces the project's destination — what success looks like — *before* the task
list, so decisions are made *with* it, not checked against it afterward. Reads
the `DESTINATION.md` written by the `/define-destination` skill. This step
prepares the data; Step 4's plan file renders the `## Destination` section.

**2.5.1 — Read the file (loud on absence — never a silent skip):**

```bash
# DESTINATION.md lives at the project root — one fixed path, every repo.
# `malformed` covers BOTH frontmatter corruption AND body corruption — a file
# that is present but unparseable must route to the loud prompt, not render blank.
if [ ! -f DESTINATION.md ]; then
  DEST_STATE="absent"
elif ! grep -q '^reviewed:' DESTINATION.md \
  || ! grep -q '^## End-state' DESTINATION.md \
  || ! grep -q '^## Could the test lie' DESTINATION.md; then
  DEST_STATE="malformed"          # missing reviewed: line OR missing a body element heading
else
  REVIEWED=$(grep '^reviewed:' DESTINATION.md | awk '{print $2}')
  if printf '%s' "$REVIEWED" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    DEST_STATE="present"
  else
    DEST_STATE="malformed"        # reviewed: present but not a valid ISO date
  fi
fi
```

- `absent` (every new repo's first run) OR `malformed` → the `## Destination`
  section shows ONE loud line — "⚠️ No destination set — run `/define-destination`
  to author one" — and the plan **CONTINUES with the task list**. Never a crash,
  never a silent skip. `DESTINATION.md` is a genuine dependency of this flow; its
  absence OR corruption is a loud condition. The malformed check inspects the
  frontmatter (`reviewed:`), the body element headings, AND the `reviewed` value's
  ISO-date validity — a file that is present-but-unparseable in any of those ways
  never reaches the staleness computation or the glance render.
- `present` → `REVIEWED` is now a validated ISO date; continue to 2.5.2.

**2.5.2 — Stateless staleness signal (git is the state — no counter file):**

Staleness is computed from real project activity, so it fires correctly even for
an operator who ships via `/autovibe` and rarely runs `/daily-plan`.

```bash
# REVIEWED was validated as a real ISO date in 2.5.1 (DEST_STATE=present requires it).
# --max-count=16 caps the walk: the threshold is 15, so 16 is enough to decide
# "stale" — git early-exits instead of walking the full DAG on a deep-history or
# iCloud-synced repo. The displayed count saturates at 16 (rendered "16+").
COMMITS_SINCE=$(git log --oneline --max-count=16 --since="$REVIEWED" -- . 2>/dev/null | wc -l | tr -d ' ')
COMMITS_SINCE=${COMMITS_SINCE:-0}
# calendar days since the reviewed date (macOS BSD date — REVIEWED is a valid ISO date here)
DAYS_SINCE=$(( ( $(date +%s) - $(date -j -f "%Y-%m-%d" "$REVIEWED" +%s) ) / 86400 ))
```

Thresholds (defaults): **15 commits** OR **21 calendar days** since `reviewed`.
If EITHER is exceeded → the glance carries a loud review prompt: "⚠️ Destination
last reviewed {DAYS_SINCE}d / {COMMITS_SINCE} commits ago — review it
(`/define-destination` review mode)." No counter state file is written; the
`reviewed` date in `DESTINATION.md` frontmatter plus git history IS the state.

**2.5.3 — Build the 3-line glance** (readable in under ~30 seconds):

1. The end-state (Element 1 of `DESTINATION.md`), length-capped to one line.
2. The could-the-test-lie clause (Element 4) — the one most worth re-checking.
3. At most 3 review-trigger yes/no prompts drawn from the destination's binary
   test and still-true-later clause (e.g. "Has the binary success test changed?").

**2.5.4 — Review-trigger answers have consequences:** a "yes" to any embedded
trigger prompts the operator to run `/define-destination` review mode now. If the
operator defers, the deferral is noted in `DESTINATION.md` (a one-line entry in
its Review log) and the `reviewed` date is **NOT advanced** — a deferred trigger
does not count as a review. Only `/define-destination` review mode advances
`reviewed`.

**2.5.5 — Drift decision rule** (auto-resolved per the plan-v1 review council;
the operator may reverse it by editing this step): when the glance shows the
destination and today's top-ranked session goal (Step 3 output) in conflict, that
mismatch is a **routing signal, not an error**. The `## Destination` section
names three paths and the operator chooses — the glance never chooses for them:

- **(a) Proceed (default)** — today's goal is a legitimate step toward the
  destination that the destination text does not yet name. No action; continue.
- **(b) Update** — today's goal reveals the destination itself was wrong or has
  moved. The operator may update `DESTINATION.md` via `/define-destination`
  review mode, but only with an explicit one-line justification recorded in the
  file. The friction is deliberate — it stops the destination silently becoming
  a mirror of whatever the operator did that day.
- **(c) Pause** — the mismatch reveals today's goal itself has drifted. The
  operator drops or reframes the goal.

Path (a) requires nothing. This step never blocks the plan.

---

## Step 3 — Score and Rank Work Items

Score ALL active tasks found across ROADMAP milestones (Status=NEXT) and **verified-incomplete** carry-forward items from yesterday's plan (Step 1C output):

**Prerequisite**: Step 1C MUST complete before scoring. Only items that FAILED all three verification checks enter the scoring pipeline as carry-forwards. Items verified as complete are excluded entirely — they do not appear in the plan.

| Condition | Score |
|-----------|-------|
| Handoff from other founder (Phase 0.6, mode='handoff') | 88 |
| Carry-forward from yesterday (verified incomplete via Step 1C) | 85 |
| Primary {{primary_nsm_label}} improvement > 10% | 78 |
| Domain NSM improvement > 10% (targeted) | 74 |
| Primary {{primary_nsm_label}} improvement 5-10% | 68 |
| Domain NSM improvement 5-10% (targeted) | 64 |
| Unblocks a LATER milestone | 65 |
| Maintenance / debt | 50 |
| LATER milestone (no blocker) | 40 |
| Research / exploration | 30 |

**Project completion bonus**: Tasks advancing projects at >80% completion get **+10** — finishing a nearly-done project is higher-leverage than starting a new one.

**Domain NSM note**: Score domain items 4 points below their primary-equivalent — domain improvements are valuable but only via their causal contribution to the Primary NSM.

**Complexity tags** (replace time estimates):
- `[TRIVIAL]` = 1-2 tool calls, verification only
- `[MODERATE]` = design + implement in one pass
- `[COMPLEX]` = multi-file, needs exploration or agent team

**Grouping**: Bundle multiple `[TRIVIAL]` tasks for the same project into a single step.

**Tie-breaking** (applied in order):
1. User action required items rank lower (can't complete autonomously)
2. When scores are within 5 points, prefer the task in the project with higher current completion percentage (consistent with the >80% completion bonus — finishing nearly-done work is higher leverage)

**Target**: 5-10 steps in the plan. We run at AI speed (5-10x human), so sessions accomplish more than traditional planning assumes.

---

## Step 4 — Write Plan File

Write to `.claude/daily-plans/PLAN-{YYYY-MM-DD}.md`:

```markdown
# Daily Plan — {DATE}
> {Project Name} | {{primary_nsm_label}}: {{primary_nsm_current}} → {{primary_nsm_target}}
> Active systems today: {list 2-3 systems with NEXT milestones}

[STRATEGY NOTE — only include if Invariant 10A found a concern]:
⚠️ Strategy note: {concern}. Proceed anyway? (y/change)

## Destination (from DESTINATION.md — Phase 2.5)

[IF DEST_STATE is absent or malformed — show ONLY this line, then continue to Prioritized Work:]
⚠️ No destination set — run `/define-destination` to author one.

[IF DEST_STATE is present — the 3-line glance:]
> End-state: {Element 1, one line}
> Could the test lie? {Element 4, one line}
> Review triggers: {≤3 yes/no prompts}

[IF stale (15+ commits OR 21+ days since `reviewed`):]
⚠️ Destination last reviewed {DAYS_SINCE}d / {COMMITS_SINCE} commits ago — review it (`/define-destination` review mode).

[IF today's top-ranked goal conflicts with the destination — the drift routing note:]
↗️ Drift: today's top goal and the destination differ. This is a routing signal, not an error —
   (a) Proceed (default — a legitimate step the destination doesn't yet name) ·
   (b) Update DESTINATION.md (via `/define-destination` review mode, with a one-line justification) ·
   (c) Pause (today's goal has drifted — drop or reframe it).

## Prioritized Work (ranked by {{primary_nsm_label}} impact × urgency)

### Step 1 — [{COMPLEXITY}] {Task name}
> System: {system name}
> Project: {project name} [{progress%}] | Milestone: {milestone name} [{progress%}]
> North Star: {project's one-line "done when" from End State table}
> Why: {1-line rationale — which {{primary_nsm_label}} component, what delta}
> Action: {specific first thing to do — not vague}
> Continuation: {path/to/continuation.md if exists}
> Success: {measurable, verifiable criteria}

### Step 2 — [{COMPLEXITY}] ...

### Step 3 — ...

(target 5-10 steps; group [TRIVIAL] tasks for the same project)

## Carry-forward from {yesterday's date}
{List incomplete steps from yesterday's plan — or "None" if clean}

## Cross-Repo PR Inbox (from Phase 0.5B — include only if team.json present)
🔴 Awaiting your review: {N grouped by repo, 🚨 if any >24h}
🟡 Your open PRs: {N grouped by repo, flag changes-requested}
🟢 Shipped today: {N PRs across R repos}

## Today's Lane: {FOUNDER_NAME} (from Phase 0.5C — include only if team.json present)
> {FOUNDER_LANE}
> Core: {FOUNDER_RESP}
{⚠️ lane drift if detected}

## Across the Org (from Phase 0.5D — include only if other founder shipped in last 24h)
🌍 {OTHER_FOUNDER} shipped {N} PRs: {list}

## Collab Inbox (from Phase 0.6 — include only if bb_collab_log exists)
🔴 Handoffs you owe action: {M with age flags}
🔵 Awaiting your consideration: {N with 🚨/⚠️/🆕 age flags}
✅ Recently integrated by you (24h): {K}

## Context Health
- ROADMAP.md: {N} lines {✓ / ⚠️ run /compress-roadmap}
- Last session: {date from SESSION-*.md} — {top 2 bullet points from Work Completed}
- Uncommitted ROADMAP changes: {yes/no from git diff}
{[📋 /clientprojectupdate pending — see Invariant 10C below]}

## Vault Pulse
{Include ONLY if vault_pulse_enabled and vault config exists — skip entirely otherwise}
- Vault: {vault_path} ({N} notes, {D} daily)
- Pending deposits: {count} {→ run /vault-sync | ✓ none}
- /drift: last {date} {✓ on schedule | ⚠️ overdue by N days — run /drift}
- /emerge: last {date} {✓ on schedule | ⚠️ overdue by N days — run /emerge}
- /vault-review: last {date} {✓ on schedule | ⚠️ overdue — run /vault-review}
{⚠️ Vault has < 10 daily notes — write more before /drift produces meaningful results}
```

---

## Step 5 — Display Chat Summary + Approval Gate

Show this in chat after writing the file:

```
Plan ready: .claude/daily-plans/PLAN-{date}.md
{👤 {FOUNDER_NAME} — {FOUNDER_LANE} | only if team.json present}
{🚨 N reviews awaiting >24h | only if any review-debt)}
{🔴 N awaiting your review | 🟡 M your open PRs | 🟢 K shipped today across R repos | only if team.json present}
{📥 P collabs awaiting your action | only if bb_collab_log present and rows exist}
Steps: {N} tasks ({trivial count} trivial, {moderate count} moderate, {complex count} complex)
Highest impact: {Step 1 name} ({project} [{progress%}])
{⚠️ strategy note if any}
{⚠️ lane drift if detected}
{📋 client update if pending}
{🧠 Vault: {N pending deposits | /drift overdue | /emerge overdue} — see Vault Pulse section}

Type 'go' to start Step 1, or edit the plan file first.
Want to use an agent team to work on multiple steps in parallel? Say 'go team'.
```

**WAIT** for user to type "go" (or equivalent: "yes", "start", "proceed").
Do NOT begin executing work until explicitly approved.

---

## Step 6 — Agent Team Offer (When User Says "go team")

If the user responds with "go team", "team", "use a team", "agents", or similar:

1. **Assess parallelizability**: Check which plan steps are independent (no dependency between them) and which must be sequential
2. **Propose team structure**: Suggest a team with named agents based on the plan steps
3. **Use TeamCreate**: Create the team and spawn teammates using the Task tool, setting `subagent_type` based on step type and `team_name` to `daily-plan-{date}`
4. **Assign work**: Each independent step gets its own agent working in parallel

**Example team proposal** (adapt to actual plan):
```
Team plan for today's 4 steps:

  Step 1 (API Refactor) — needs user action, will run as lead task
  Step 2 (Dashboard Verification) — independent, can run in parallel → agent "dashboard-verifier"
  Step 3 (Schema Check) — independent, quick check → agent "schema-checker"
  Step 4 (Client Update) — depends on Steps 1-3 completing → run last

Spawn 2 parallel agents + lead works Step 1? (y/adjust)
```

**Rules**:
- Only suggest agents for steps that are truly independent
- Research/read-only steps are ideal for parallel agents
- Steps requiring user interaction should stay with the lead
- Steps with write operations to the same systems should NOT be parallelized
- Always confirm the team structure before spawning

If the user says just "go" (without "team"), proceed normally — work through steps sequentially as a single agent. The team offer is optional, never forced.

---

## Invariant 10B — Agent Research Context Wrapper

When this skill generates a research sub-task that will invoke `/agent-research` or a Task agent:

**ALWAYS** prepend this block to the research prompt:

```
ROADMAP CONTEXT:
- System: {system name}
- Project: {project name} [{progress%}]
- Milestone: {milestone name} [{progress%}]
- {{primary_nsm_label}} impact: {component} +{delta}%
- Constraint: solution must not disturb {adjacent system}
- Existing approach: {what already exists in codebase at {file:line}}
- Success criterion: {from the plan step above}
```

**Without this context**: agent returns generic advice.
**With this context**: agent returns surgical, codebase-aware advice.

Anti-pattern (never do this):
```
❌ /agent-research "how to fix data normalization in the pipeline"
```
Correct pattern:
```
✅ /agent-research "ROADMAP CONTEXT: Data Integrity milestone is NEXT. NSM impact: +8%.
   Constraint: must not affect existing message routing logic. Existing: Router
   uses field extraction at normalization step. Fix: adjust extraction pattern.
   Verify: processing failure rate < 2%."
```

---

## Invariant 10C — Client Update Flag

**Read** `.claude/sessions/session-state.env` at the start of every `/daily-plan`.

If file contains `CLIENTUPDATE_PENDING=true`:
1. Surface at the bottom of the plan: `📋 Client status board update pending from last session.`
2. After user types "go" — confirm: "Run /clientprojectupdate first? (y/skip)"
3. If yes → invoke `/clientprojectupdate` as Step 0 before the ranked work steps
4. After it completes (or if skipped) → clear the flag: remove `CLIENTUPDATE_PENDING=true` from `session-state.env`

**Why two-hop**: The StopHook (session-summarizer.sh) cannot invoke Claude skills synchronously. It writes a flag. The next session's daily-plan picks it up. The flag file persists until explicitly cleared.

---

## Context Rot Warnings

Include in the plan's Context Health section:

```bash
# ROADMAP rot
if ROADMAP.md > 500 lines:
  "⚠️ ROADMAP.md is {N} lines. Run /compress-roadmap when convenient."

# Session file accumulation
if .claude/sessions/SESSION-*.md count > 14:
  "⚠️ {N} session files. Consider archiving older ones."
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| ROADMAP.md missing | HALT — cannot generate plan without it |
| `continuations/` dir missing | Skip Step 1A silently — project doesn't use continuations |
| Yesterday's plan missing | Skip carry-forward section — normal for first-ever run |
| Session summary missing | Proceed without — note "no prior session found" in Context Health |
| Git log returns empty | Proceed — new repo or no recent commits |
| Continuation file unreadable | Skip that file, note in Context Health |
| >20 recent continuations found | Process only the 20 most recent, note overflow count |
| MCP unavailable for Vault Pulse | Degrade gracefully — note "Supabase MCP not connected" |
| ROADMAP >500 lines | Surface rot warning but don't block |
| Concurrent sessions editing ROADMAP | Detect via `git diff`, incorporate uncommitted changes |

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| List all active tasks | Overwhelming, no prioritization | Score and pick top 5-10 only |
| Use time estimates | We run at AI speed (5-10x human) | Use complexity tags: [TRIVIAL]/[MODERATE]/[COMPLEX] |
| Steps without hierarchy context | Can't trace to project/milestone | Every step shows System → Project → Milestone chain |
| Start working without "go" | User hasn't approved the plan | Always wait for approval |
| Surface strategy concern every session | Trains user to ignore it | Only when ROADMAP changed AND test fails |
| Research without ROADMAP context (10B) | Generic unhelpful advice | Always prepend ROADMAP CONTEXT block |
| Forget to clear 10C flag | Surfaces update prompt forever | Clear flag after /clientprojectupdate |
| Vague success criteria | Can't verify done | Specific: "failure rate < 2%", "smoke test passes" |
| Ignore near-complete projects | Miss high-leverage finishing work | Projects >80% get +10 scoring bonus |
| Ignore continuations directory | 200+ planned prompts invisible to planning | Step 1A scans recent continuations + forged prompts |
| Surface all continuations | Overwhelms the plan with old work | Max 3, prefer recent forged > master > unverified |
| Auto-delete stale continuations | User's planned work, not ours to delete | Surface housekeeping task, never auto-delete |
| Blind carry-forward from yesterday | Yesterday's status is stale — work ships in parallel sessions | Run Step 1C verification gate on EVERY carry-forward item |
| Trust yesterday's "NOT STARTED" without checking | PRs merge overnight, continuations get executed in other chats | Check impl_status + merged PRs (7d) + codebase spot-check |
| Carry forward 3+ days without investigating | Item is likely done, blocked, or deprioritized — not "not started" | Flag with ⚠️, investigate root cause before re-adding to plan |
| Only scan today's merged PRs for carry-forward | Misses PRs merged 2-6 days ago that closed carry-forward items | Use 7-day PR window for carry-forward verification (Step 1C) |
| Block plan on Vault Pulse failures | Vault is advisory, not a gate | Vault Pulse is informational only — never blocks |
| Skip Vault Pulse when MCP down | Loses deposit awareness | Degrade gracefully — note "MCP not connected" |
| Hardcode vault path in skill | Different per Mac | Read from `.claude/obsidian-second-brain.local.md` |
| Run vault commands automatically | User must approve plan first | Surface overdue commands as suggestions, never auto-run |
| Use `gh pr list` for cross-repo inbox | repo-scoped — misses side repos | Use `gh search prs` (account-wide) per Phase 0.5B |
| Hardcode founder identity in skill | breaks on per-machine + Chris vs. Justin | Resolve via `gh api user --jq .login` + read team.json |
| Auto-add cross-repo review PRs as scored plan steps | Hijacks the user's plan with reactive work | Surface in PR Inbox section only — founder picks what to tackle |
| Block plan if `gh search` fails or rate-limits | Network blip should not break daily-plan | Phase 0.5 degrades gracefully — every subsection is independent |

---

## Held-Out Validation

This skill works for any project that has:
- A `ROADMAP.md` with `## System:` sections containing `### Project` headers and milestone tables
- A `.claude/sessions/` directory for session state
- A Primary NSM (parameterized as `{{primary_nsm_label}}`)
- A `.claude/daily-plans/` directory for plan output
- An "End State" table mapping projects to "done when" criteria
- Optionally: `domain_nsms` array for multi-domain projects (leave empty for single-domain)

**NSM cascade invariant**: Domain NSMs must be causal inputs to the Primary NSM. If moving a Domain NSM doesn't move the Primary NSM, the domain is mis-defined. The `/setup` Step 7.6.2 traceability check enforces this at project creation.

The hierarchy (System → Project → Milestone → Task) generalizes to any automation with client deliverables or any project with structured work breakdown.

---

*Skill version: 5.4 | Updated 2026-04-27 — Phase 0.6: Collab Inbox. Surfaces incoming `/collab` items from `bb_collab_log` where current founder is recipient. Handoff-mode collabs score 88 (just below carry-forward at 85, above primary NSM at 78) — other founder explicitly asked for action. Outbound-mode collabs (idea/feedback/news/etc) appear in inbox section but not auto-scored — recipient picks what to integrate via `/collab pull <id>`. Age escalation: <24h 🆕, 24-72h ⚠️, >72h 🚨 (chat summary header). Skips gracefully if `bb_collab_log` table missing (skill not yet installed) or Supabase MCP unavailable. <3s budget.*
*Skill version: 5.3 | Updated 2026-04-27 — Phase 0.5: Founder Identity & Cross-Repo PR Inbox. Reads `.claude/team.json` + resolves current founder via `gh api user`. Surfaces "awaiting your review" / "your open PRs" / "changes requested" across all accessible repos via `gh search prs` (account-wide, not repo-scoped). Lane-aware focus block + optional drift detection. "What other founder shipped" snapshot. Skips silently for solo projects. All cross-repo queries read-only + rate-limit-safe + 5s budget. Anti-patterns added for cross-repo and identity. Phase 0.5 outputs slot into Step 4 plan template + Step 5 chat summary.*
*Skill version: 5.2 | Updated 2026-04-13 — Step 1C: Carry-Forward Verification Gate (MANDATORY). Three-check verification (impl_status + 7-day merged PRs + codebase spot-check) on EVERY carry-forward item before scoring. Carry-forward continuations bypass 3-day scan window. Items carried 3+ days get mandatory investigation flag. Step 3 scoring now requires Step 1C as prerequisite. 4 new anti-patterns for blind carry-forward. Fixes bug where completed work resurfaced as "NOT STARTED" because yesterday's stale status was trusted without re-verification.*
*v5.1: 2026-04-12 — Phase 0A: merged PR scanning (primary data source for parallel sessions), open PR conflict/superseded detection. Phase 0C: auto-resolve divergence (prefer origin/main). Step 0: plan refresh uses PR data not just current-branch commits. Fixes blind spot where daily plan missed 11 merged PRs from parallel sessions.*
*v4.0: 2026-03-27 — Continuation & forged prompt scanning (Step 1A), error handling table, 3 new anti-patterns*
*v3.1: 2026-03-15 — ROADMAP staleness warning, Vault Pulse project filter, scoring tiebreaker (council-reviewed)*
*v3.0: 2026-03-12 — Vault Pulse integration, skill-creator compliance (allowed-tools, user-invocable, evals)*
*v2.0: 2026-02-24 — hierarchy context, complexity tags, AI speed, cross-chat awareness*
*v1.2: 2026-02-20 — Added Step 6 (agent team offer)*
*v1.0: 2026-02-19 — original with NOW/NEXT lanes*
