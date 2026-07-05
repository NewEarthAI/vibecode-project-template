# v2 Queued — Layer 4 (Vercel deploy lag)

v1.0 shipped Layers 1 + 5 + 6. v1.1 shipped Layers 2 + 3 (see `walk-branches.sh` + `pr-fleet.md`). Only Layer 4 (Vercel deploy lag) remains queued for v1.2.

This file's Layer 2 + Layer 3 sections are HISTORICAL — they document the original spec before implementation. The implementation may differ from the spec; refer to `walk-branches.sh` and `pr-fleet.md` for current canonical behaviour. Layer 4 below is the active queue item.

---

## Layer 2 — Branch fleet (queued v1.1)

**Catches**: branches with local commits not on origin (you said "I pushed" but pushed an old commit).

### Recipe

```bash
# After a fresh `git fetch --all --prune`:

# Local branches that have an upstream
git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/ \
  | while read -r local upstream; do
      [ -n "$upstream" ] || continue
      ahead=$(git rev-list --count "${upstream}..${local}")
      behind=$(git rev-list --count "${local}..${upstream}")
      if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
        echo "[$local ahead=$ahead behind=$behind] upstream=$upstream"
      fi
    done

# Local branches WITHOUT upstream (never pushed)
git for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/ \
  | awk '$2 == "" {print $1}'
```

### Output format
```
[AHEAD] feat/foo on origin/feat/foo, 3 commits ahead — fix: git push origin feat/foo
[BEHIND] feat/bar on origin/feat/bar, 2 commits behind — fix: git pull --ff-only OR rebase
[DIVERGED] feat/baz, 1 ahead + 2 behind — fix: rebase or pull (manual decision)
[NO_UPSTREAM] wip/quick-test — fix: git push -u origin wip/quick-test (or delete if abandoned)
```

### Exclusions
- `main`, `master` — privileged, expected to track origin via fetch
- Branches whose upstream is `origin/main` (rare, unusual)

### Edge cases (must handle in v1.1)
- Branch deleted on remote but local survives → flag as STALE_LOCAL
- Detached HEAD on a worktree (overlap with Layer 1, but reportable here too)
- Ref locks (concurrent git op in another worktree) → ERROR fall-through
- Worktree-pinned branches (currently checked out elsewhere) — already counted by Layer 1, don't double-flag

---

## Layer 3 — PR fleet (queued v1.1)

**Catches**: open PRs that should have closed, merged PRs whose worktree wasn't cleaned up, draft PRs older than N days.

### Recipe

```bash
# All open PRs the current user authored
gh pr list --author "@me" --state open --json number,title,headRefName,createdAt,mergeable,statusCheckRollup --limit 50

# Recently merged PRs (last 7 days) — for "did you clean up the worktree?" check
gh pr list --author "@me" --state merged --search "merged:>=$(date -v-7d '+%Y-%m-%d')" --json number,title,headRefName,mergedAt --limit 50
```

### Output format
```
[OPEN_PR] #471 "fix: foo bar" on feat/foo, 2 days old, CI failing
  fix: gh pr checks 471  &&  fix the failing check  &&  gh pr merge 471 --squash --admin
[OPEN_DRAFT] #469 "wip: experimental" on wip/exp, 9 days old (>7d threshold)
  fix: convert to ready (gh pr ready 469) OR close (gh pr close 469)
[MERGED_NOT_CLEANED] #468 merged on feat/bar 3 days ago — worktree still at /Users/justin/code/the app-bar
  fix: git worktree remove /Users/justin/code/the app-bar
       git branch -D feat/bar
       git push origin --delete feat/bar 2>/dev/null
```

### Composition
- Layer 3 cross-references Layer 1 to detect MERGED_NOT_CLEANED
- Layer 3 cross-references Layer 2 to detect AHEAD branches that DON'T have an open PR (a branch with unpushed commits + no PR is suspicious)

### Auth
- Requires `gh auth status` clean. Layer 3 degrades to "[skip] gh CLI not authenticated — run gh auth login" if missing.

---

## Layer 4 — Vercel deploy lag (queued v1.2)

**Catches**: main has commits newer than the last successful Vercel production deployment (rate-limit cooldown class — `operational-guardrails.md` Vercel = FAILURE recovery).

### Recipe

```bash
# Last successful production deploy (state=READY, target=production, in main project)
vercel ls --json --scope=teamyour-orgas-projects buy-box-ai \
  | jq '[.[] | select(.target == "production" and .state == "READY")] | first'
# Returns the most recent successful production deploy
# Extract: .createdAt (epoch ms — convert to seconds)

# Compare against last commit on origin/main
git log -1 --format=%ct origin/main
```

### Output format
```
[VERCEL_LAG] origin/main last commit at <main_iso>, last successful production deploy at <deploy_iso>, lag=<duration>
  fix (if rate-limited): git commit --allow-empty -m "ci: retrigger Vercel"  &&  git push origin main
  fix (if otherwise): inspect Vercel dashboard for failed deploy reason
```

### Edge cases
- Deploy IN PROGRESS (state=BUILDING) → flag as PENDING_DEPLOY, do NOT recommend retrigger (would compound)
- Multiple FAILED deploys in a row → escalate, do NOT auto-recommend retrigger (rate limit will block)
- `vercel` CLI not authenticated → degrade

### Auth (AUTH_DECISION proof-out 2026-05-07 — v1.1 capability-scout)

**Decision: CLI-only path. No env-var fallback.**

Findings on the operator's primary Mac (2026-05-07):
- ✅ `vercel` CLI installed at `/opt/homebrew/bin/vercel` (v50.39.0)
- ✅ `vercel whoami` returns `your-org` (the team scope a SaaS app lives under)
- ❌ `VERCEL_TOKEN` env var NOT set
- ✅ `/ship` skill uses `vercel whoami` as its auth-precheck (CLI is the canonical pattern in this repo)

**Implementation rule for v1.2**:
1. Pre-check: `vercel whoami` — must return non-empty
2. If CLI not authenticated: emit `[skip] Layer 4 — vercel CLI not authenticated. Run vercel login --scope=your-org to enable.` and exit Layer 4 with 0 issues
3. Do NOT fall back to `VERCEL_TOKEN` REST scrape — it adds a second auth surface to maintain without delivering parallel value

**Why no fallback**:
- The /ship precedent already standardises on CLI
- Env-var path duplicates auth state (CLI session + token) → drift class
- Headless CI environments aren't in the calling pattern today (autovibe + daily-plan are interactive)
- If the headless case becomes real, add VERCEL_TOKEN fallback in v1.3 alongside actual headless callers

**Vercel-as-StatusContext gotcha** (cross-reference: `operational-guardrails.md` Vercel = FAILURE recovery):
- Vercel deploy status surfaces on PRs as a GitHub `StatusContext`, NOT a `CheckRun`
- `gh run rerun` does NOT work to re-trigger Vercel — it only operates on GitHub Actions runs
- The way to re-trigger is an empty commit (`git commit --allow-empty`)
- Layer 4's recommended fix command for VERCEL_LAG should suggest the empty-commit path, NOT `gh run rerun`

**No blockers identified** — Layer 4 is ready for v1.2 implementation.

---

## Acceptance criteria

v1.1 (✅ shipped 2026-05-07):
- [x] `scripts/walk-branches.sh` exists, executable, returns the spec formats
- [x] `references/pr-fleet.md` exists with full recipe + edge cases
- [x] SKILL.md Phase 2 + Phase 3 promoted from `[V2_QUEUED]` to live invocations
- [x] AUTH_DECISION captured in this file's Layer 4 section
- [x] autovibe Phase 4.5 hook + Session Learning Gate fleet-drift trigger row
- [x] daily-plan Phase 1.5 fleet-status snippet + NSM-rank integration
- [x] `read-state.sh` primitive + parallel-session lock + suppress-file mechanism

v1.2 (queued):
- [ ] `references/vercel-drift.md` exists with full recipe (auth path uses CLI per AUTH_DECISION above)
- [ ] SKILL.md Phase 4 promoted from `[V1.2_QUEUED]` to live
- [ ] `verify-shipped deep` tier exclusively invokes Layer 4 (its complexity belongs in deep tier only)
- [ ] Layer 4 graceful skip when `vercel whoami` returns empty (CLI not authenticated)

---

## Why these were queued (history)

The Foundation-First Shipping rule (autovibe SKILL.md) — when council finds heavy MUST-HAVE count + 3+ session estimate, ship the foundation in one session and queue the implementation. v1.0 (Layers 1+5+6) shipped first as the silent-killer surface. v1.1 (Layers 2+3 + composition + lock + suppress) followed once foundation was proven on origin. v1.2 (Layer 4) waits because Vercel auth surface needed explicit proof-out (now captured in AUTH_DECISION above).

By splitting at silent-killer surface (Layer 1+5+6) → composition + branch/PR fleet (v1.1) → Vercel deploy lag (v1.2), each session shipped a coherent unit with verifiable wall-clock + zero overlapping concerns.
