# /ship hotfix — Expedited production fix with force-T3 verify + auto-rollback

**Use when**: production is broken (or will be within minutes) and a one-file fix must ship NOW. Explicit invocation only — `detect-mode.sh` returns `hotfix-guard` on main/master to prevent accidental direct pushes.

## Flag handling

If invocation includes `--format=json`, **suppress all prose output** and emit ONLY the JSON block from the "Output (--format=json)" section below to stdout as the FINAL message. Stderr from sub-scripts may still appear (humans want to see it; Autovibe ignores stderr) but the final stdout line MUST be parseable JSON.

**Trust contract**: hotfix mode runs the SAME pre-flight gates as pr mode, PLUS forces T3 verify-pipeline (full audit, even if recent pass is in state file), PLUS enables auto-rollback on smoke fail without confirmation (confident cascade). No ceremony reduction — hotfixes need MORE verification, not less, because the time pressure is exactly when mistakes compound.

## Flow

```
[requires explicit `/ship hotfix` — never auto-detected]
preflight.sh                              → exit 1 on blocker
snapshot --tag pre-hotfix-<ts>            → always, before any destructive op
lock.sh acquire <commit_sha>              → exit 5 if another ship holds
[create branch off main if on main]
  git checkout -b hotfix/<slug>-<ts>
git add + git commit                      → commit-guardian inherits
git push (plain)
gh pr create --label hotfix
/verify-pipeline --tier 3 --force         → ALWAYS run; never skip from state file
ci-watch.sh <pr> --timeout 15             → exit 0 green, 1 red, 9 unknown
[admin-merge heuristic as in pr mode]
wait for Vercel production deploy
smoke.sh <merged_sha> --min-wait 30 --retries 3
[if smoke exit 1]  → auto-rollback.sh WITHOUT CONFIRM (confident cascade)
[if smoke exit 9]  → halt exit 2 (unverifiable; FLAG 1)
lock.sh release                           → zombie recovery via 10-min TTL + explicit rm-rf in collision message
capture lessons to feedback_ship_<slug>.md auto-memory if novel failure
```

## Why force-T3 verify-pipeline

A hotfix ships with time pressure. The `/verify-pipeline` state-file skip is optimized for routine shipping where "same commit passed recently" is trustworthy evidence. Hotfixes are exactly when that optimization lies — the symptom driving the hotfix may have changed since last T2, and T3's static-audit + live checks catch regressions T2 skips. Hotfix mode ignores the state file and runs fresh.

## Auto-rollback authority (confident cascade)

Hotfix is the ONLY mode where `auto-rollback.sh` fires without a confirmation prompt. Reasoning:
- User explicitly invoked `/ship hotfix` → confident cascade authorizes recovery from failed recovery
- Smoke-after-hotfix failure = production is still broken; prompting for approval while prod is down multiplies MTTR
- Rollback is `git revert` + push (reversible; not a destroy)
- On conflict, `auto-rollback.sh` halts with exit 3 + full recovery path — human takes over for genuine hazard

## Pre-conditions

- Explicit `/ship hotfix` invocation (never auto-detected)
- `path-check.sh` of `$PWD` passes
- Remote auth valid
- User aware that smoke-fail → auto-revert WILL fire

## Post-conditions (success = exit 0)

Same as pr mode, plus:
- `gh pr view --json labels` shows `hotfix` label
- T3 verify-pipeline ran fresh (not state-skip)
- `.claude/ship-state.json` has `tier_results.T3: "pass"` (not skipped)

## Post-conditions (auto-rollback fired = exit 4)

- Original merge commit exists in `git log`
- Revert commit `git revert <merged>` also exists
- Production smoke passes on revert commit (secondary verification)
- `ship-state.json` has `exit_code: 4` + `rollback_sha` + `rollback_reason`
- Snapshot preserved at `~/.claude-ship-snapshots/<ts>-pre-hotfix-*`

## Output (human default — success path)

```
✓ ship hotfix complete
  PR:         #<num>  [hotfix] <title>
  commit:     <sha8>  (squash-merged)
  T3 verify:  fresh pass (deployment detection skipped; force-T3 always on hotfix)
  Smoke:      / OK, /pipeline OK — sha=<sha8> ✓
  Rollback:   auto-ready (auto-rollback.sh <sha>)
```

## Output (--format=json — success path)

```json
{"exit_code":0,"mode":"hotfix","pr_number":<num>,"merged_sha":"<sha>","admin_merged":true,"t3_pass":true,"smoke":"pass","rollback_cmd":"bash .claude/skills/ship/scripts/auto-rollback.sh <sha>"}
```

## Output (--format=json — auto-rollback fired)

```json
{"exit_code":4,"mode":"hotfix","pr_number":<num>,"merged_sha":"<sha>","rollback_sha":"<revert_sha>","rollback_reason":"smoke_failed","smoke_status":"<HTTP code>","snapshot_dir":"~/.claude-ship-snapshots/<ts>-pre-hotfix-<sha8>"}
```

## Output (--format=json — auto-rollback conflict, exit 3)

```json
{"exit_code":3,"mode":"hotfix","merged_sha":"<sha>","rollback_status":"conflict","conflicted_files":["<file1>","<file2>"],"snapshot_dir":"~/.claude-ship-snapshots/<ts>-pre-hotfix-<sha8>","recovery_options":["abort_and_manual","nuclear_reset","snapshot_restore"]}
```

## Output (human default — auto-rollback fired)

```
⚠ ship hotfix auto-reverted
  Original:    <sha8>  [hotfix] <title>  (merged)
  Reverted:    <revert_sha8>  (auto)
  Reason:      post-deploy smoke fail (HTTP <code> on <path>)
  Status:      production restored to pre-hotfix state
  Snapshot:    ~/.claude-ship-snapshots/<ts>-pre-hotfix-<sha8>/
  Next steps:  investigate root cause before re-attempting
```

## Output (auto-rollback conflict — exit 3)

See `auto-rollback.sh` conflict path — enumerates files, surfaces 3 manual recovery paths (abort+manual, nuclear reset, snapshot restore). Production is broken AND auto-revert failed; human intervention required.

## Edge cases handled

- **Concurrent hotfix landed on main between merge and rollback**: `auto-rollback.sh` detects post-merge commits via `git log <merged>..origin/main`, warns explicitly before attempting revert; surfaces conflict enumeration if revert fails
- **Squash-merge reverting only the single squash commit**: `git revert <squash_sha>` correctly reverts the full PR (that's what squash does)
- **Smoke unverifiable (no sha header)**: halt exit 2 — do NOT auto-rollback (council FLAG 1)
- **Vercel auth expired**: halt exit 2 before smoke runs — never confuse 401 with 502

## What hotfix mode does NOT do

- Skip gates for "speed" — opposite; it adds T3
- Auto-fix conflicts in the revert — human-only
- Retry the original hotfix automatically after rollback

## Reference

- `scripts/auto-rollback.sh` — revert + push + conflict handling
- `scripts/smoke.sh` — Vercel pre-check + retry+backoff
- Failure modes: `references/failure-inventory.md` D2–D4
- Council deliberation: `council/sessions/2026-04-19-ship-skill-plan-deliberation.md` (FLAG 1 discussion)
