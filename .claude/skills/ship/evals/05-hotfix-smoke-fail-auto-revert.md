# Eval 05 — `/ship hotfix` smoke fail triggers auto-rollback

**Mode**: hotfix
**Scenario**: a production fix is merged + deployed; Vercel returns success but the production URL returns HTTP 502 on `/` after retry+backoff window. Auto-rollback fires WITHOUT confirmation (confident cascade).
**Expected exit code**: 4 (smoke-failed-reverted)

## Pre-conditions

```bash
cd ~/code/<repo>-hotfix-<slug>          # non-iCloud path
git branch --show-current               # hotfix/<slug>-<ts>
gh auth status && vercel whoami         # both authenticated
```

## Invocation

```bash
/ship hotfix
```

## Expected flow

1. `preflight.sh` → exit 0
2. `snapshot.sh --tag pre-hotfix-<sha>` → captures current WIP
3. `lock.sh acquire <commit_sha>` → exit 0
4. Commit + push + `gh pr create --label hotfix`
5. `/verify-pipeline --tier 3 --force` → pass (freshly run, not state-skipped)
6. `ci-watch.sh <pr>` → exit 0 or admin-merge heuristic
7. `gh pr merge <pr> --squash --admin` (admin auto-ok on hotfix)
8. Wait 30s (min-wait for Vercel propagation)
9. `smoke.sh <merged_sha> --retries 3 --backoff 10`
10. **Simulated fault**: path `/` returns 502 on all 3 attempts (30s total with backoff)
11. smoke exits 1
12. **Auto-rollback fires WITHOUT confirmation** (confident cascade on hotfix)
13. `auto-rollback.sh <merged_sha>`:
    a. `git fetch origin main`
    b. Snapshot current state: `pre-rollback-<merged_sha:0:8>`
    c. Enumerate post-merge commits (expect empty)
    d. `git checkout main && git pull --ff-only`
    e. `git revert --no-edit <merged_sha>` → creates revert commit
    f. `git push origin main` (plain — revert is fast-forward) → push lands
    g. Update `ship-state.json`: `exit_code: 4`, `rollback_sha`, `rollback_reason: "smoke_failed"`
14. `lock.sh release` (zombie recovery via 10-min TTL if user ^C'd; no trap because Bash tool calls are independent subshells)

## Expected output

```
⚠ ship hotfix auto-reverted
  Original:   <sha8>  [hotfix] <title>  (merged)
  Reverted:   <revert_sha8>  (auto)
  Reason:     post-deploy smoke fail (HTTP 502 on /)
  Status:     production restored to pre-hotfix state
  Snapshot:   ~/.claude-ship-snapshots/<ts>-pre-hotfix-<sha8>/
  Next:       investigate root cause before re-attempting
```

## Post-conditions

```bash
git log origin/main -2 --format='%H %s'
# Expect:
#   <revert_sha>  Revert "[hotfix] <title>"
#   <merged_sha>  [hotfix] <title>

cat .claude/ship-state.json | jq '.exit_code'            # 4
cat .claude/ship-state.json | jq '.rollback_sha'         # "<revert_sha>"
cat .claude/ship-state.json | jq '.rollback_reason'      # "smoke_failed"

ls ~/.claude-ship-snapshots | grep pre-hotfix-              # snapshot preserved
```

## Counter-scenarios

### 5a. `smoke` exit 9 (no sha header) — DO NOT auto-rollback
```
→ halt exit 2 + "unverifiable (no x-vercel-git-commit-sha header) — inspect manually; do NOT auto-rollback"
→ NO revert commit on main; ship-state.json exit_code: 2
```

### 5b. `smoke` exit 2 (Vercel auth expired)
```
→ halt BEFORE smoke fires (pre-check catches it)
→ "vercel login" prompt; no merge, no deploy, no rollback
```

### 5c. Auto-rollback hits conflict (post-merge commits on main)
```
→ auto-rollback.sh enumerates conflicted files
→ surfaces 3 manual recovery paths (abort+manual, nuclear reset, snapshot restore)
→ exits 3; human takes over
→ ship-state.json exit_code: 3 with recovery_required: true
```
