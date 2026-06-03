# Layer 3 — PR Fleet Recipe

How `/verify-shipped` walks the GitHub PR fleet (open + recently merged) and produces actionable findings.

This is a Claude-followed recipe (no dedicated bash script — the entire surface is `gh` CLI calls). Total wall-clock on Justin's typical PR fleet: ~3-5 seconds.

---

## Pre-flight

1. `gh auth status` — confirm authenticated. If NOT authenticated:
   ```
   [skip] Layer 3 — gh CLI not authenticated. Run `gh auth login` to enable PR fleet audit.
   ```
   Exit Layer 3 with 0 issues. Do NOT fail the skill.

2. Confirm the current repo has a GitHub remote:
   ```bash
   git remote get-url origin 2>/dev/null | grep -q github.com || echo "[skip] not a GitHub repo"
   ```

---

## Step 1 — Open PRs

```bash
gh pr list --author "@me" --state open --limit 50 \
  --json number,title,headRefName,isDraft,mergeStateStatus,statusCheckRollup,createdAt,updatedAt
```

For each PR, classify:

### CONFLICTS — has merge conflicts
- Trigger: `mergeStateStatus == "DIRTY"`
- Output: `[CONFLICTS] PR #<N> "<title>" — has merge conflicts`
- Fix: `git fetch origin main && git checkout <headRefName> && git rebase origin/main`

### FAILING_CI — required check failing
- Trigger: any `statusCheckRollup` entry with `state == "FAILURE"` or `conclusion == "FAILURE"`
- Filter for the *required* checks per a SaaS app doctrine: `typecheck`, `check`, `Vercel`, `Bundle-secrets + paid-API governance`. Playwright FAILURE/CANCELLED is the known-flaky pattern (see `operational-guardrails.md` a SaaS app CI § admin-merge heuristic) — render as `[INFO]` not `[FAILING_CI]`.
- Output: `[FAILING_CI] PR #<N> "<title>" — <check-name> = FAILURE`
- Fix: `gh pr checks <N> --watch && gh run rerun <run-id>` (or fix the underlying issue)

### STALE_OPEN_PR — open >7 days with no recent activity
- Trigger: `(now - updatedAt) > 7 days`
- Output: `[STALE_OPEN_PR] PR #<N> "<title>" — <age> old, no activity since <updated>`
- Fix: either ship it OR close it OR add a comment explaining the wait state

### DRAFT_AGED — draft PR open >14 days
- Trigger: `isDraft == true && (now - createdAt) > 14 days`
- Output: `[DRAFT_AGED] PR #<N> "<title>" — draft <age> old`
- Fix: convert to ready-for-review OR close

### MERGEABLE — clean + green + ready (informational)
- Trigger: `mergeStateStatus == "CLEAN"` AND no failing required checks AND not draft
- Output: `[INFO] PR #<N> "<title>" — ready to merge`
- NOT counted as an issue (informational only)

### Otherwise — clean (suppressed, counted in summary)

---

## Step 2 — Recently merged PRs (cleanup signal)

```bash
gh pr list --author "@me" --state merged --limit 20 \
  --json number,title,headRefName,mergedAt
```

For each merged PR, check whether the local branch + worktree still exist:

```bash
# branch still exists locally?
git rev-parse --verify "refs/heads/<headRefName>" 2>/dev/null

# worktree still exists?
git worktree list --porcelain | grep -A2 "branch refs/heads/<headRefName>" | grep -E '^worktree ' | head -1
```

If branch OR worktree present:
- Output: `[MERGED_NOT_CLEANED] PR #<N> "<title>" merged <age> ago — worktree at <path>, branch <name>`
- Fix command:
  ```
  git worktree remove <path> && git branch -D <branch-name> && git push origin --delete <branch-name>
  ```
  (omit `git push origin --delete` if the remote ref is already gone)

---

## Step 3 — Cross-reference with Layer 2 (handled in Phase 7 synthesis)

The `MERGED_NOT_CLEANED` output for a branch should suppress any matching Layer 2 `STALE_LOCAL` for the same branch name. The MERGED_NOT_CLEANED finding is more specific (PR # + age + worktree path) and includes the same fix commands plus the worktree-removal step.

This dedup happens in SKILL.md Phase 7, NOT in Layer 3 itself. Layer 3 emits raw findings; orchestration layer reconciles.

---

## Edge cases

- **Author filter**: `@me` resolves to the authenticated `gh` user. If the authenticated user is bot-like or different from the human (e.g., GitHub Actions token), Layer 3 will under-report. Surface this in the [skip] message if `gh api user --jq .login` returns a non-Justin/non-Chris user.
- **Rate limit**: `gh pr list` consumes ~3 GitHub API calls per invocation. Free-tier rate limit is 5,000/hr — easily survives this audit.
- **Fork repos**: `gh pr list` runs against the local repo's GitHub remote. If the worktree is on a fork, results will be PRs on the fork, not upstream. Acceptable for v1.1.
- **Closed-not-merged PRs**: deliberately ignored. If a user closed without merging, that's a deliberate signal; this skill doesn't lecture about it.
- **PR <-> branch name mismatch**: rare but possible (e.g., PR was renamed via `gh pr edit`). Match by `headRefName` from the JSON, not by attempting to parse the PR title.
- **Old gh CLI versions**: `mergeStateStatus` appeared in `gh` 2.0+. Older CLIs return null and we'd miss CONFLICTS classification. Consider this a doctrine-level requirement: `gh >= 2.0`.

---

## Sample output

```
LAYER 3 (PRs): 3 issues
  [FAILING_CI] PR #471 "feat: drawer design Wave H" — typecheck = FAILURE
    fix: gh pr checks 471 --watch  (or fix the type error locally)
  [MERGED_NOT_CLEANED] PR #481 "Track 1: match_score truthiness fix" merged 4 days ago — worktree at /Users/justin/code/the app-track1, branch feat/track1
    fix: git worktree remove /Users/justin/code/the app-track1 && git branch -D feat/track1 && git push origin --delete feat/track1
  [STALE_OPEN_PR] PR #463 "WIP: telegram dedup" — 12 days old, no activity since 2026-04-25
    fix: ship, close, or comment explaining the wait state
  [INFO] PR #492 "feat(verify-shipped): v1.0 foundation" — ready to merge (informational)
```

---

## Why this is a recipe (markdown), not a script (bash)

Per master-continuation Section 5 NOVELTY guidance, Layer 3 is "standard, do NOT over-engineer." The complexity is in interpreting `gh pr list` JSON output + classification logic — Claude-following-a-recipe handles that fluently. A dedicated bash script would have to:
- Parse JSON in shell (jq) — adds dependency + complexity
- Hard-code classification thresholds — less flexible than recipe-driven logic
- Reproduce orchestration logic that already lives in SKILL.md

The recipe-as-markdown approach matches the v1.0 pattern (`edge-fn-drift.md`, `migration-drift.md`).

---

## Performance

- `gh auth status`: ~50ms
- `gh pr list --state open --limit 50`: ~1-2s
- `gh pr list --state merged --limit 20`: ~1-2s
- Per-PR branch+worktree check: ~10ms × 20 = 200ms
- Total: ~3-5s on Justin's typical PR fleet

Well under the `quick` tier wall-clock budget.

---

## References

- `operational-guardrails.md` a SaaS app CI § — admin-merge heuristic explains why Playwright FAILURE/CANCELLED is the known-flaky pattern (rendered as `[INFO]`, not `[FAILING_CI]`)
- `loading-state-invariants.md` Invariant 7 — partner-facing data-fidelity merge gate (the doctrinal witness for why merged-not-deployed matters)
- `pipeline-philosophy.md` Principle 3a — one state, one primary surface (the dedup discipline that justifies Layer 2/3 cross-reference)
- `walk-branches.sh` — Layer 2 implementation (Layer 3 dedups against STALE_LOCAL outputs from this script)
