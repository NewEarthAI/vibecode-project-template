# Eval 03 — `/ship pr` full flow (happy path)

**Mode**: pr
**Scenario**: feature branch, existing commits ahead of origin OR dirty tree, CI will pass green, Vercel deploys cleanly.
**Expected exit code**: 0

## Pre-conditions

```bash
cd ~/code/<repo>-<slug>
git branch --show-current              # feature branch (not main)
git status --porcelain                 # dirty OR clean-but-ahead
gh pr list --head $(git branch --show-current) --json number --jq length
                                       # 0 (no open PR yet) OR 1 (existing)
gh auth status                         # authenticated
vercel whoami                          # authenticated
df /System/Volumes/Data                # <90% used
```

## Invocation

```bash
/ship pr
```

## Expected flow

1. `detect-mode.sh` → `pr` (with reason logged)
2. `preflight.sh` → exit 0
3. `lock.sh acquire <commit_sha> <pr_number>` → exit 0
4. `snapshot.sh --tag pre-pr` → prints snapshot path
5. If dirty: `git add + git commit` (commit-guardian inherits)
6. `git push origin <branch>` (plain — push is fast-forward; bash-guardian blocks `--force` only)
7. If no open PR: `gh pr create` using template if present
8. `ci-watch.sh <pr> --timeout 15` → exit 0 (all checks SUCCESS)
9. `gh pr merge <pr> --squash`
10. Wait 30s, then `smoke.sh <merged_sha> --retries 3 --backoff 10`
11. smoke exit 0 → success
12. `lock.sh release` (zombie recovery via 10-min TTL if user ^C'd)
13. `ship-state.json` updated: `exit_code: 0`, `completed_at`, `rollback_cmd`

## Expected output

```
✓ ship pr complete
  PR:        #<num>  <title>
  commit:    <sha8>  (merge-squash)
  CI:        green  |  Vercel: success  |  Playwright: green
  Smoke:     / OK, /pipeline OK — sha=<sha8> ✓
  Rollback:  bash .claude/skills/ship/scripts/auto-rollback.sh <sha>
```

## Post-conditions

```bash
gh pr view <pr> --json state -q .state                     # MERGED
git log origin/main -1 --format='%H %s'                    # merged commit on main
cat .claude/ship-state.json | jq '.exit_code'              # 0
cat .claude/ship-state.json | jq '.tier_results'           # T1/T2 pass; T3 null (pr mode, not hotfix)
ls .claude/ship-state.lock/ 2>/dev/null                    # ENOENT (released)
curl -sI https://<production-url>/ | grep -i x-vercel-git-commit-sha
                                                           # matches merged_sha
```

## Failure modes (documented, not triggered in happy path)

- `ci-watch` exit 1 (real red) → halt exit 2; no merge
- `ci-watch` exit 9 (timeout) → halt exit 2; no merge
- `smoke` exit 1 (confirmed fail) → `auto-rollback.sh` fires → exit 4
- `smoke` exit 9 (unverifiable) → halt exit 2; DO NOT auto-rollback
- `smoke` exit 2 (Vercel auth expired) → halt exit 2; prompt `vercel login`
