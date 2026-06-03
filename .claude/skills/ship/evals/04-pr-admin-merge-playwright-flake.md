# Eval 04 — `/ship pr` admin-merge on Playwright-only flake

**Mode**: pr
**Scenario**: feature branch ready, `check` green, `Vercel` green, ONLY `playwright` check is red (chronic flake pattern observed across multiple historical PRs (project to document its own precedent)). Admin-merge heuristic fires.
**Expected exit code**: 0 (successful admin-merge + smoke pass)

## Pre-conditions

```bash
gh pr checks <pr> --json name,conclusion --jq '.[] | {name, conclusion}'
# Expected output:
#   {"name": "check", "conclusion": "SUCCESS"}
#   {"name": "Vercel", "conclusion": "SUCCESS"}
#   {"name": "playwright", "conclusion": "FAILURE"}
```

## Invocation

```bash
/ship pr
```

## Expected flow

1-7. Same as eval 03 (preflight, lock, snapshot, commit, push, create PR)
8. `ci-watch.sh` runs `gh pr checks --watch --fail-fast`
9. `ci-watch` exits 1 (one check failed — playwright)
10. `/ship pr` reads check details: parses `gh pr checks <pr> --json name,conclusion`
11. **Admin-merge heuristic**:
    - `check` = SUCCESS ✓
    - `Vercel` = SUCCESS ✓
    - Only `playwright` = FAILURE ✓
    → proceed with `gh pr merge <pr> --admin --squash`
12. Output one-sentence FYI: `Admin-merge: playwright flake only (matches documented chronic-flake precedent for this repo)`
13. Continue with smoke.sh as normal
14. smoke exit 0 → success

## Expected output

```
✓ ship pr complete
  PR:        #<num>  <title>
  commit:    <sha8>  (merge-squash)
  CI:        check ✓  Vercel ✓  playwright ✗ (admin-merge: matches chronic flake pattern)
  Smoke:     / OK, /pipeline OK — sha=<sha8> ✓
  Rollback:  bash .claude/skills/ship/scripts/auto-rollback.sh <sha>
```

## Counter-scenarios (expected to HALT, not admin-merge)

### 4a. `check` red + playwright red → halt exit 2
```
checks: {"check": "FAILURE", "Vercel": "SUCCESS", "playwright": "FAILURE"}
→ real regression; halt with "check failed — inspect before re-running /ship pr"
```

### 4b. `Vercel` red + playwright red → halt exit 2
```
checks: {"check": "SUCCESS", "Vercel": "FAILURE", "playwright": "FAILURE"}
→ deploy itself broken; halt with "Vercel deploy failed — inspect before merging"
```

### 4c. Unknown-new red check → halt exit 2 + ask user
```
checks: {"check": "SUCCESS", "Vercel": "SUCCESS", "playwright": "SUCCESS", "lighthouse": "FAILURE"}
→ new check not in heuristic; halt with "unfamiliar failed check 'lighthouse' — approve admin-merge? (/ship pr --admin)"
```

## Post-conditions

Same as eval 03 plus:
```bash
gh pr view <pr> --json mergeCommit,mergedBy
# mergedBy should match actor with admin privilege
```
