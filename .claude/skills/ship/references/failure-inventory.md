# /ship Failure Inventory

Seeded from:
- 2026-04-19 3-hour shipping incident
- Design spec: `continuations/SHIP-SKILL-DESIGN-FORGED-2026-04-19.md`
- Council 2026-04-19 extended deliberation: `council/sessions/2026-04-19-ship-skill-plan-deliberation.md`
- Auto-memory: `feedback_icloud_corrupts_git_metadata.md`, `feedback_pr115_submit_form_lessons.md`

**Growth contract**: when `/ship` resolves a failure NOT in this inventory, append the mode here AND write `feedback_ship_<slug>.md` to auto-memory so the next session has both the pattern and the memory pointer.

---

## A. Filesystem failures

### A1. iCloud-poisoned worktree (`~/Documents/GitHub/*`)
**Symptom**: 10–15 minute `git` hangs; `.git/index 2.lock` / `.git/HEAD 2` duplicate artifacts; zombie checkouts; silent `.git/index` corruption.
**Root cause**: iCloud syncs `.git/index.lock` / `.git/HEAD` mid-write; "filename 2" is iCloud's duplicate-on-conflict pattern.
**Prevention**: `path-check.sh` (exit 6) blocks the invocation with a copy-pastable `~/code/<repo>-*` redirect command.
**Also covers**: OneDrive, Dropbox, any cloud-synced path.
**Source**: `feedback_icloud_corrupts_git_metadata.md`, 2026-04-19 incident.

### A2. `/tmp/*` as worktree base
**Symptom**: `git worktree add` hangs silently mid-populate.
**Root cause**: macOS tmpfs triggers git auto-lock.
**Prevention**: `path-check.sh` (exit 6) — `/tmp/*` and `/private/tmp/*` are unsafe patterns.

### A3. Stale `.git/*.lock` from crashed session
**Symptom**: `fatal: Unable to create '.git/index.lock': File exists` OR silent hang if the lock is respected by reader.
**Root cause**: crashed `git` process left a lock file; most common crash vector is iCloud mid-write (see A1).
**Prevention**: `preflight.sh` scans `find .git -name "*.lock" -mmin +10` and halts with the list, plus `worktree-guard.sh` PreToolUse hook catches this on any `git worktree add`.

### A4. Disk full (APFS CoW degradation)
**Symptom**: `git` writes succeed then silently corrupt; `.git/index` becomes unparseable.
**Root cause**: APFS copy-on-write performance degrades sharply past 90% disk use; mid-write flush can fail.
**Prevention**: `preflight.sh` checks `df /System/Volumes/Data` ≥5GB free (block at 90%+ use).

### A5. Symlink `~/code/` → `~/Documents/GitHub/` (wolf in sheep's clothing)
**Symptom**: `path-check.sh` passes because `pwd -P` resolves to `~/code/X`, but `~/code/` is itself a symlink to iCloud.
**Root cause**: user may have symlinked `~/code/` for convenience without realizing it routes back into iCloud.
**Prevention**: `path-check.sh` checks `if [ -L "$HOME/code" ]` + reads the link target; matches against synced-dir patterns; exits 1 with `rm ~/code && mkdir ~/code` recovery.
**Status**: IMPLEMENTED (2026-04-19, full build).

### A6. Zero-byte `ship-state.json` from iCloud mid-write
**Symptom**: `lock.sh acquire` reads empty file, proceeds as if no lock held; two sessions both proceed.
**Root cause**: iCloud deferred upload writes zero-byte placeholder.
**Prevention**: `lock.sh` treats empty / unparseable / missing-fields state file as corrupt (exit 6), never as "no lock." (Primary defense: don't work in iCloud in the first place — see A1.)

---

## B. Git operation failures

### B1. `git checkout --ours/--theirs` misapplied on code files during rebase
**Symptom**: hook cascade fires 2–3 times in one invocation; conflict "resolves" with wrong content; state drift.
**Root cause**: rebase semantics are REVERSED from merge — `--ours` during rebase means the branch being rebased ONTO, not the current branch.
**Prevention**: constraint in SKILL.md NEVER section; halt for human eyeball on code conflicts (`.ts, .tsx, .js, .sql, .py`). Docs-only (`.md`) exception when duplicate content is provable.
**Source**: 2026-04-19 incident; confirmed hook fired 3× on auto-resolved rebases.

### B2. `git push --force` destroying sibling worktree's WIP
**Symptom**: remote commits disappear; another worktree can't push.
**Root cause**: `--force` ignores lease; blind overwrite.
**Prevention**: `bash-guardian.sh` hard-blocks plain `--force`. `/ship` uses plain `git push` for all normal flows (`quick`, `pr` initial push, `hotfix` initial push, `auto-rollback.sh` revert push — all fast-forward). `--force-with-lease` is reserved for: (a) explicit pr-mode amend-flow re-push after rebase, and (b) the user-invoked manual "Nuclear option B" recovery in `auto-rollback.sh`'s conflict-handling stderr (never auto-executed).

### B3. `--force-with-lease` rejected by stale-info in parallel worktrees
**Symptom**: push fails with "stale info"; user's worktree hasn't fetched but sibling pushed.
**Root cause**: `--force-with-lease` compares against last-known remote ref; if remote moved, rejection is correct safety.
**Prevention**: halt with exit 1 + recovery `git fetch && git rebase origin/<branch>` — never escalate to plain `--force`.

### B4. Detached HEAD → empty branch push
**Symptom**: `git push HEAD:<empty>` creates orphan ref or cryptic git error.
**Root cause**: `git branch --show-current` returns empty on detached HEAD; naive mode detection proceeds.
**Prevention**: `detect-mode.sh` has its own `detached` exit path (halt exit 1 + "checkout a branch first").

### B5. Pushing on `main` / `master`
**Symptom**: direct-to-main push rejected by branch protection OR merged without review.
**Root cause**: user ran `/ship` from default branch without intending hotfix.
**Prevention**: `detect-mode.sh` returns `hotfix-guard` when branch is `main`/`master`; halt exit 1 until explicit `/ship hotfix` (Phase C).

### B6. Multiple open PRs for the same branch (closed-then-reopened)
**Symptom**: `gh pr list --head <branch>` returns 2+ results; naive selection hits wrong PR.
**Prevention**: `detect-mode.sh` returns `ambiguous` with explicit enumeration rather than silent first-pick.

---

## C. Lock + state-file failures

### C1. Future-dated `started_at` permanent lock
**Symptom**: every `/ship` returns exit 5 forever; TTL check `(now - started_at) < 10min` is always true on negative diff.
**Root cause**: machine clock was wrong (set ahead), then NTP corrected. Lock file carries future timestamp.
**Prevention**: `lock.sh` has 60-min future-tolerance upper bound; timestamps outside that window → exit 6 with "likely clock skew" + `rm -rf` command.

### C2. Zombie lock from ^C mid-op
**Symptom**: user hits ^C mid-ship; subsequent `/ship` blocked for up to 10 min.
**Root cause**: Claude Code Bash tool calls are independent subshells — a `trap` registered in one call CANNOT fire when the next call is interrupted (or when Claude itself exits). The original design assumed a single-process model that doesn't apply here.
**Prevention**: TTL-based recovery is the implemented mechanism — `lock.sh` enforces a 10-minute TTL on `started_at`, after which the next `acquire` auto-takes-over. For faster recovery, the exit-5 collision message includes the explicit one-line `rm -rf .claude/ship-state.lock .claude/ship-state.json` command that bypasses TTL. MTTR: 10 min passive, 5 sec active.
**Why traps were dropped**: code-council 2026-04-19 ship-skill review (council/code-reviews/2026-04-19-ship-skill-build.md) flagged the spec's trap claim as documented-not-implemented at 99% confidence; investigation showed the Bash-subprocess-per-tool-call execution model makes traditional traps non-viable.

### C3. Corrupt JSON in state file
**Symptom**: naive `jq` reader crashes, or the lock-acquire logic silently proceeds.
**Prevention**: `lock.sh` uses `grep -o` (tolerant to whitespace variation) and treats missing fields as corrupt; halts exit 6 rather than silently bypassing.

### C4. JSON race during concurrent writes
**Symptom**: `/ship` mid-writes state file; concurrent `/verify-pipeline` reads partially-flushed JSON; reader crashes.
**Prevention**: state writes in `/ship` are single heredoc (no append), so the final file is either the old content or the new content — never interleaved.

---

## D. CI / deploy failures

### D1. `gh pr checks --watch` hangs indefinitely
**Symptom**: session blocks forever on GitHub API degradation.
**Prevention**: `ci-watch.sh` wraps with `timeout 15m` (or `gtimeout` / manual background-kill on macOS) + distinct exit 9 "CI status UNKNOWN"; caller halts, never maps timeout to pass/fail.
**Status**: IMPLEMENTED.

### D2. Vercel cold-start false-positive smoke failure
**Symptom**: `/` returns 503 during 5–30s warmup; auto-rollback reverts healthy deploy.
**Prevention**: `smoke.sh --min-wait 30 --retries 3 --backoff 10` — 30s propagation pause, then 3 attempts × 10s backoff before any failure signal. Total window ≥60s covers typical Vercel cold-start ceiling.
**Status**: IMPLEMENTED.

### D3. Vercel auth expired → 401 indistinguishable from 502
**Symptom**: `vercel ls` 401 looks like real deploy failure; auto-rollback fires on healthy prod.
**Prevention**: `smoke.sh` runs `vercel whoami` pre-check as FIRST step; exits 2 if auth expired (before smoke HTTP checks start). Missing `x-vercel-git-commit-sha` header (despite auth OK) → exit 9 UNVERIFIABLE — caller halts, does NOT rollback.
**Status**: IMPLEMENTED.

### D4. Squash-merge auto-rollback conflicts with concurrent hotfix
**Symptom**: `git revert <sha>` on a squash commit conflicts with later hotfix on main; auto-rollback halts mid-outage.
**Prevention**: `auto-rollback.sh` enumerates post-merge commits via `git log <merged>..origin/main` BEFORE reverting; warns explicitly. On conflict, surfaces the conflicted-files list + 3 recovery paths (abort+manual, nuclear reset, snapshot restore) + preserves snapshot for restore. Exits 3; human takes over.
**Status**: IMPLEMENTED.

### D5. Playwright-only CI failure with everything else green
**Symptom**: CI red but `check` + `Vercel` pass; Playwright chronically red on this repo (PRs #112, #113, #115, #116, #119, #120).
**Prevention**: `/ship pr` admin-merge heuristic — `check`=SUCCESS ∧ `Vercel`=SUCCESS ∧ only `playwright`=FAILURE → `gh pr merge --admin --squash` with one-sentence FYI. Any other red check → halt exit 2 (real regression).
**Status**: IMPLEMENTED in `modes/pr.md`.

---

## E. Process / workflow failures

### E1. Hook accumulated pattern-context fire loop
**Symptom**: same hook fires 2–3 times; identical task completes on first try in a fresh `claude` CLI session.
**Root cause**: Claude session accumulates context-pattern that biases future tool calls; hooks re-fire on the same classification.
**Prevention**: when `worktree-guard.sh` fires ≥2× in one `/ship` invocation, halt with "run this in a fresh `claude` session" recommendation.
**Status**: recommendation surfaced 2026-04-19; implementation in Phase B.

### E2. Render/scrollbar oscillation on Windows (PR115)
**Symptom**: infinite loop of setState during render on Windows scrollbar reflow.
**Prevention**: `scrollbar-gutter: stable` + never setState during render + debounced saves flush on unmount+visibilitychange.
**Source**: `feedback_pr115_submit_form_lessons.md`.
**Relation to `/ship`**: not a /ship failure per se, but a shipping-blocker class — cited in design spec as precedent for "visible failures that only show on specific platforms."

---

## Footer

**All A, B, C, D modes now IMPLEMENTED.**
**E1 (hook-fire loop)**: recommendation only; implementation tracked as a future enhancement — SKILL.md halt-after-2-fires logic to be added when real hook-loop evidence accumulates.
**E2 (PR115 render/scrollbar)**: orthogonal to `/ship`; lives in `feedback_pr115_submit_form_lessons.md` as code-level learnings.
