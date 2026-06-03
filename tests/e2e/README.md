# E2E Smoke Tests — Zero-Regression Infrastructure

This directory holds Playwright smoke tests that run against Vercel preview deploys on every PR. They are the last line of defense against regressions that slip past `check` (lint + tsc + vitest).

## Pattern

Every test file:
- Uses `.smoke.spec.ts` suffix
- Tags tests with `@smoke` so the workflow can filter via `--grep @smoke`
- Asserts on `data-testid` attributes (stable selectors) rather than text content or CSS classes
- Uses the authenticated `storageState` from `playwright/.auth/user.json` (populated by `playwright/global-setup.ts`)

## Files

| File | Purpose |
|---|---|
| `sanity.smoke.spec.ts` | Always-passing sentinel. Ensures the playwright job has ≥1 passing test when project-specific suites are skipped. |

## Adding project-specific smoke tests

When adding a new smoke test, follow the checklist:

1. **Name**: `{page-name}.smoke.spec.ts`
2. **Tag**: `test.describe('@smoke {Feature}', ...)` so `--grep @smoke` picks it up
3. **Selectors**: use `data-testid="..."` in your components; never assert on CSS classes or auto-generated IDs
4. **Auth**: by default the test context is authenticated via global-setup.ts. If the test needs UNauthenticated state, override: `test.use({ storageState: { cookies: [], origins: [] } });`
5. **Patience**: use `expect().toBeVisible({ timeout: 15000 })` or `await page.waitForLoadState('networkidle')` before asserting — cold Vercel previews take 3-10s to hydrate
6. **Data-assertion philosophy**: don't assert that a page "loaded." Assert that real data rendered — no `NaN`, no `undefined`, currency values present, addresses in title case, etc.

## Temporarily skipping a suite

If a spec file is too flaky to ship but you don't want to block CI:

```ts
test.describe.skip('@smoke Feature', () => {
  // ...
});
```

Document why in a comment at the top of the file, and track the un-skip work in a follow-up issue. The sanity sentinel will keep the job green.

## Workflow integration

The `playwright` job in `.github/workflows/e2e.yml`:
- Triggers on `deployment_status.success && environment == 'Preview'` (Vercel preview) and `merge_group`
- Uses `mcr.microsoft.com/playwright:vX.Y.Z-noble` docker image (keep version in sync with `@playwright/test` in `package.json`)
- Passes `BASE_URL`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `E2E_USER_EMAIL`, `E2E_USER_PASSWORD` as env vars from GitHub Secrets
- Reports as a required check on branch protection
