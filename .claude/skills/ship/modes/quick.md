# /ship quick — Single-branch commit + push

**Use when**: dirty tree on a feature branch, no open PR (detected automatically), user wants changes pushed without PR ceremony.

## Flag handling

If invocation includes `--format=json`, **suppress all prose output** and emit ONLY the JSON block from the "Output (--format=json)" section below to stdout as the FINAL message. Stderr from sub-scripts may still appear (humans want to see it; Autovibe ignores stderr) but the final stdout line MUST be parseable JSON. Do not interleave prose and JSON in the same response.

## Flow

```
preflight.sh         → exit 1 if disk/path/stale-lock/tsc fails
lock.sh acquire      → exit 5 if another ship holds this commit_sha
snapshot tracked+uncommitted (if any)
                     → ~/.claude-ship-snapshots/<ts>/ + MANIFEST.md
git add <explicit paths from user or staged+tracked>
                     → never `git add -A` (that's commit-guardian's job to backstop)
git commit           → commit-guardian inherits
git push                         → plain push (revert/new-commit is fast-forward)
                                   if rejected: fetch + rebase + retry, never --force
                                   on rebase: rebase-conflict-guard.sh FIRST (code-file
                                   conflict in unattended mode = HARD STOP, exit 3)
verify-push-landed.sh <branch>   → assert "pushed" ONLY on remote-SHA match (exit 0)
lock.sh release                  → idempotent; skipped if user ^C'd (TTL catches it)
write ship-state.json with exit_code: 0 + rollback hint
```

## Pre-conditions (must be true before entry)

- Not in detached HEAD (detect-mode.sh returns `detached` → halt exit 1)
- Current branch is NOT `main` (detect-mode.sh returns `hotfix-guard` → halt exit 1)
- `path-check.sh` of `$PWD` returns exit 0 (not iCloud/OneDrive/Dropbox/tmp)

## Post-conditions (verified before exit 0)

- `git log -1` shows the new commit
- `git status` shows clean or only unstaged-but-unchanged
- `bash ../scripts/verify-push-landed.sh <branch>` exits 0 (remote SHA == local HEAD — `@{u}` is a local tracking ref and can be stale; the remote read cannot lie)
- `.claude/ship-state.json` has `completed_at` + `exit_code: 0` + rollback command

## Output (human default)

```
✓ ship quick complete
  commit:   <sha>  <first 60 chars of message>
  branch:   <name>  pushed to origin
  rollback: git revert HEAD && git push origin <name>   (preferred — never destructive)
```

## Output (--format=json)

```json
{"exit_code":0,"commit_sha":"<sha>","branch":"<name>","rollback":"git revert HEAD && git push origin <name>"}
```

## Edge cases handled

- **Nothing to commit**: exit 0 with "clean tree, nothing to ship" message (no push)
- **Remote moved since last fetch**: plain `git push` rejects (non-fast-forward). Halt exit 1 with recovery: `git fetch && git rebase origin/<branch> && git push`. If that rebase conflicts, `rebase-conflict-guard.sh` HARD STOPS on any code-file conflict in unattended mode (exit 3) — never auto-`--ours/--theirs` (reversed semantics during rebase)
- **Push exits 0 but nothing landed** (protected branch / swallowed hook / blip): `verify-push-landed.sh` catches the mismatch; "pushed" is never claimed on exit code alone
- **^C mid-commit**: lock dir + state file persist (Bash tool calls are independent subshells; no trap is viable). Recovery: next `/ship` within 10 min hits exit 5 with the explicit `rm -rf .claude/ship-state.lock .claude/ship-state.json` recovery line in stderr; after 10-min TTL, next acquire auto-takes-over. Git's commit itself is atomic — either made or not.
- **Push rejected by branch protection**: halt exit 1 with "branch protected — use `/ship pr` (Phase B)" message

## What quick mode does NOT do

- Open PRs (Phase B)
- Watch CI (Phase B)
- Merge to main (Phase B)
- Post-deploy smoke (Phase C)
- Auto-rollback on deploy fail (Phase C)

If any of the above is needed, the user invokes the relevant phase explicitly. Phase A intentionally ships the narrowest useful flow.
