# /ship pr — Open PR, watch CI, merge when green

**Use when**: feature branch ready for review — dirty tree with open PR (amend flow), clean tree ahead of origin (push existing), or clean tree with open PR (watch + merge).

## Flow

```
detect-mode.sh                            → confirms pr mode (or explicit)
preflight.sh                              → exit 1 on blocker
lock.sh acquire <commit_sha> <pr_number>  → exit 5 if another ship holds this PR
snapshot                                  → pre-destructive capture of WIP
[if dirty tree]
  git add <explicit paths>                → commit-guardian inherits
  git commit
git push --force-with-lease               → bash-guardian permits
[if no open PR]
  gh pr create                            → use .github/PULL_REQUEST_TEMPLATE if present
ci-watch.sh <pr_number> --timeout 15      → exit 0 green, 1 red, 9 unknown
[if CI unknown (exit 9)]
  halt exit 2                             → "CI status unknown; inspect manually"
[if CI red]
  ADMIN-MERGE HEURISTIC (see below)
[NEW: Phase pre-merge — Negative-control of new e2e specs]
  for each NEW (added, not modified) tests/e2e/*.spec.ts in diff:
    run negative-control.sh <spec> <feature_file>
    [if exit 0]  → spec proven to catch regression
    [if exit 1]  → BLOCK merge: spec is vacuous (passes regardless of feature state)
    [if exit 2]  → halt + ask user (couldn't auto-detect feature to break)
[if CI green OR admin-merge approved AND negative-control passed]
  gh pr merge <pr> --squash [--admin]
  wait for Vercel production deploy
  smoke.sh <merged_sha> --min-wait 30 --retries 3 --backoff 10 [--bundle-marker <m>]
  [if smoke exit 0]  → continue to visual-smoke
  [if smoke exit 1]  → invoke auto-rollback.sh (exit_code: 4)
  [if smoke exit 9]  → halt exit 2 + "unverifiable — do not auto-rollback; inspect"
[NEW: Phase post-deploy — Visual smoke for UI surface diffs]
  if `git diff --name-only origin/main..HEAD` matches src/(components|pages)/.*\.(tsx|jsx)$:
    visual-smoke.sh <prod_url> <merged_sha>
    [if exit 0]  → success: markers found in deployed bundle
    [if exit 1]  → BLOCK + invoke auto-rollback (deploy succeeded but feature missing)
    [if exit 2]  → log skip reason (no markers detectable from diff)
    [if exit 9]  → halt exit 2 + "unverifiable; inspect manually"
output success + rollback hint
lock.sh release (trap)
```

## Admin-merge Heuristic

Based on documented 6-PR precedent (#112, #113, #115, #116, #119, #120) where Playwright CI was chronically red due to flakes not regressions, AND the 2026-04-25 PR #289 incident where a 3-second Playwright "failure" was admin-merged as a "flake" when it was actually budget-refusal (the job never ran):

```
gh pr checks <pr> --json name,status,conclusion → parse
gh run view <playwright_run_id> --json jobs → extract duration
  if check=SUCCESS AND Vercel=SUCCESS AND ONLY playwright=FAILURE:
    if playwright_duration_seconds < 10:
      → "DID NOT RUN" path (NOT a flake — GHA budget refusal or runner refusal)
      → detect touched surfaces from `git diff origin/main..HEAD --name-only`
      → run matching Playwright tests LOCALLY against `npm run preview`
        (e.g., src/components/pipeline/** → `npx playwright test seller-drawer-*`)
      → if local tests pass → gh pr merge --admin --squash
                              (FYI: "Playwright CI didn't run — verified locally")
      → if local tests fail  → halt exit 2 (real regression caught by local run)
      → if no matching tests → halt exit 2 + ask user (unverifiable shipping)
    else:
      → "REAL FLAKE" path (job ran ≥10s, hit a flaky assertion or network)
      → gh pr merge --admin --squash    (one-sentence FYI in output)
  elif check=FAILURE OR Vercel=FAILURE:
    → halt exit 2 (real regression — not flake)
  else:
    → halt exit 2 + ask user (unfamiliar CI state)
```

**Rationale**: A Playwright job duration <10 seconds is structurally impossible for a real test run (`actions/checkout` + `setup-node` alone take ~15s on the SaaS app runner). Treating "didn't run" as "flake" silently ships unverified UI changes. The duration gate forces touched-surface verification when CI's coverage is absent. This rule was added after PR #289 shipped a "first seller-drawer Playwright E2E" that never actually executed on CI — defeating the trust-repair narrative the test was written for.

**Three Playwright surfaces are available** when CI's Playwright didn't run. Pick by purpose:

| Need | Tool | When |
|---|---|---|
| Run existing test suites against the diff | **Playwright CLI** (`npx playwright test`) | Pre-merge regression check on touched surfaces |
| Interactive verification of new UI behavior or unresolved council uncertainties (visual contrast, rendered state, hover/click flow) | **Playwright MCP** (`mcp__plugin_playwright_playwright__browser_*`) | When a council session left a >50% uncertainty resolvable only by seeing the page |
| Performance / network / console inspection | **Chrome DevTools MCP** (`mcp__plugin_chrome-devtools-mcp_chrome-devtools__*`) | When the diff might affect bundle size, latency, console errors |

**Pre-merge surface verification table** (CLI regression — when CI's Playwright didn't run):

| Diff path pattern | Run locally |
|---|---|
| `src/components/pipeline/**`, `src/components/pipeline/detail/**` | `npx playwright test seller-drawer-*` |
| `src/components/buyer/**`, `src/pages/Dashboard.tsx`, `src/lib/calculator/methods/flip/**` | `npx playwright test buyer-*` |
| `src/pages/Submit*.tsx`, `src/components/wholesaler/**` | `npx playwright test submit*` |
| `src/integrations/supabase/**`, `supabase/functions/**` | `npx playwright test --grep @smoke` |
| Anything else not matched | Halt + ask user (unverifiable surface) |

**MCP visual verification** (when council left an unresolved >50% spread on rendered behavior):

The skill MUST close visual/behavioral uncertainties before merge using Playwright MCP browser tools. Example pattern (PR #289 retroactive):

1. `browser_navigate` → preview URL
2. `browser_resize` 1280×800 (the contested viewport)
3. Authenticate if needed via stored credentials path
4. `browser_navigate` to the changed surface (e.g., `/pipeline`, then click a property row)
5. `browser_take_screenshot` (full page or element)
6. Inspect screenshot — confirm the council uncertainty is resolved (e.g., checkmark contrast readable)
7. If unresolved → halt + show screenshot to user + apply fallback CSS / wait for human review
8. If resolved → record in ship-state.json and proceed to merge

**Trigger condition for MCP visual verification**: any of —
- Council session for this PR/feature recorded an "unresolved uncertainty" >50% spread
- Diff modifies CSS, layout, color, font-size, or icon size on a user-facing surface
- User said "show me before merge" anywhere in the workflow and the visual check was deferred

**Cost**: ~60-180s of local Playwright run + MCP browser session vs. shipping unverified UI. Always worth it.

## Pre-conditions

- Not detached HEAD
- Branch != main/master (that's hotfix territory)
- `path-check.sh` of `$PWD` passes
- Remote auth (gh + git) valid

## Post-conditions (verified before exit 0)

- `gh pr view <pr> --json state -q .state` = "MERGED" (or closed if --no-merge)
- `gh api repos/{owner}/{repo}/commits/<merged_sha>` exists
- Production URL responds 200 on configured paths
- `x-vercel-git-commit-sha` header matches merged SHA (when present)
- `.claude/ship-state.json` has `exit_code: 0` + rollback command

## Output (human default)

```
✓ ship pr complete
  PR:        #<num>  <title>
  commit:    <sha8>  (merge-squash)
  CI:        green  |  Vercel: success  |  Playwright: flake (admin-merged)
  Smoke:     / OK, /pipeline OK — sha=<sha8> ✓
  Rollback:  bash .claude/skills/ship/scripts/auto-rollback.sh <sha>
```

## Output (--format=json)

```json
{"exit_code":0,"pr_number":<num>,"merged_sha":"<sha>","admin_merged":true,"smoke":"pass","rollback_cmd":"..."}
```

## Edge cases handled

- **Multiple open PRs for same branch**: `detect-mode.sh` returns `ambiguous`; halt exit 6
- **PR in DRAFT state**: halt exit 1 with "PR is draft — gh pr ready <pr> first"
- **ci-watch timeout**: exit 9; halt without merge ("status unknown — re-run after inspecting")
- **Branch protection blocks non-admin merge + CI all-green**: proceed with admin-merge (confident cascade)
- **Vercel deploy fails**: smoke exit 1 → auto-rollback fires → exit 4
- **Smoke returns 200 but no sha header**: exit 9 → halt, do NOT rollback (unverifiable; council FLAG 1). When `--bundle-marker` is provided, smoke escalates to bundle-content verify before declaring unverifiable.
- **Visual-smoke fails (deploy succeeded but new component absent from bundle)**: visual-smoke exit 1 → invoke auto-rollback (deploy gap, not flake)
- **New e2e spec doesn't catch its claimed regression** (negative-control fails): BLOCK merge with "spec is vacuous" — author must fix the spec before ship
- **Vercel auth expired**: smoke exit 2 → halt before rollback; surface `vercel login`

## What pr mode does NOT do

- Deploy directly to prod (merge → Vercel handles via git integration)
- Modify main directly (hotfix does that — Phase C)
- Bypass the smoke test (it's what distinguishes pr from quick)

## Reference

- `scripts/ci-watch.sh` — gh pr checks wrapper with 15m timeout + exit 9
- `scripts/smoke.sh` — Vercel auth pre-check + retry+backoff + header verify
- `scripts/auto-rollback.sh` — invoked on smoke exit 1
- Failure modes: `references/failure-inventory.md` sections B6, C*, D1–D5
