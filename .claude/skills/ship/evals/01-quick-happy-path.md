# Eval 01 — `/ship quick` happy path

**Mode**: quick
**Scenario**: dirty feature branch, no open PR, healthy filesystem, no TS changes in diff.
**Expected exit code**: 0

## Pre-conditions

```bash
cd ~/code/<repo>-<slug>         # non-iCloud path
git status --porcelain          # non-empty (dirty tree)
git branch --show-current       # feature branch, not main
gh pr list --state open --head $(git branch --show-current) --json number
                                # returns []
df /System/Volumes/Data | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
                                # < 90
find .git -name "*.lock" -mmin +10
                                # empty
```

## Invocation

```bash
/ship quick
```

## Expected flow

1. `detect-mode.sh` → stdout `quick`, stderr `dirty tree, no open PR on <branch>`
2. `preflight.sh` → exit 0 (path OK, disk OK, no stale locks, tsc skipped if no .ts in diff)
3. `lock.sh acquire <commit_sha>` → exit 0 (no prior lock) → `.claude/ship-state.lock/` created + `.claude/ship-state.json` written
4. Snapshot tracked-modified files to `~/.claude-ship-snapshots/<ts>/MANIFEST.md`
5. `git add` explicit paths OR staged-already files
6. `git commit` (commit-guardian checks pass — no debug artifacts, no .env, no >1MB files)
7. `git push origin <branch>` (plain — push is fast-forward; bash-guardian blocks `--force` only)
8. `lock.sh release` → lock dir removed; state file updated with `completed_at` + `exit_code: 0`. Zombie recovery via 10-min TTL if user ^C'd mid-flow.

## Expected output (human)

```
✓ ship quick complete
  commit:   <sha8>  <first 60 chars>
  branch:   <name>  pushed to origin
  rollback: git revert HEAD && git push origin <name>   (preferred — non-destructive)
            (or `git reset --hard origin/<name>~1` + manual fix-and-push for local-only undo)
```

## Post-conditions (verify before claiming eval pass)

```bash
git log -1 --format='%H %s'             # shows new commit
git status --porcelain                  # empty OR only unstaged-but-unchanged
git rev-parse HEAD                      # matches
git rev-parse @{u}                      # matches HEAD (push landed)
cat .claude/ship-state.json | grep exit_code  # "exit_code": 0
ls .claude/ship-state.lock/ 2>/dev/null # should fail (released)
```

## Failure modes during eval

- `preflight.sh` exits 1: confirm specific gate that failed (path / disk / tsc / lock)
- `lock.sh acquire` exits 5: a prior ship is held on this commit; verify `cat .claude/ship-state.json`
- `git push` rejected (non-fast-forward): upstream moved; eval documents recovery path (`git fetch && git rebase origin/<branch> && git push`) but does not auto-apply. Plain push is the safer default — `--force-with-lease` is only used in pr-mode amend flows where intentional, never in quick-mode
- Commit-guardian blocks: staged debug artifact detected; eval is specifically for clean diffs
