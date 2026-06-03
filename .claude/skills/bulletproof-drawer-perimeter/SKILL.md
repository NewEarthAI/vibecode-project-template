---
name: bulletproof-drawer-perimeter
description: |
  Playwright regression-test perimeter for drawers, detail-modals, side-sheets in
  React/Vite/Tailwind + Supabase/REST apps. Use when: building a drawer with inline-edit
  or write surfaces, adding tests to prevent silent UI regressions, or when the user says
  "bulletproof the drawer", "lock down the modal", "drawer regressions are killing me".
  Encodes eight patterns: virtualized-table cell[1] click (not bounding-box), drawer scope
  via role=dialog (text collisions), two-click display→edit toggle recognition, idempotent
  round-trip (capture → mutate → verify → cleanup), REST PATCH cleanup (bypasses Radix
  popover + React Query realtime race), serial mode for realtime-subscribed tests, auth
  token from Playwright storageState, zero-skip discipline. Rejects input:focus races,
  duplicate-text matches, UI-driven cleanup in realtime components. Composes with
  e2e-test and ui-design-system.
version: 1.0
classification: encoded-preference
created: 2026-04-23
updated: 2026-04-23
validated_on:
  - the app_seller_drawer_property_detail_sheet
triggers:
  - bulletproof the drawer
  - lock down the modal
  - add regression tests for drawer
  - drawer regression
  - drawer keeps breaking
  - modal write-surface tests
  - round-trip test drawer
  - playwright drawer
parameters:
  - name: framework
    type: enum
    values: [playwright, cypress]
    default: playwright
    description: Test framework (Cypress port pending)
  - name: backend
    type: enum
    values: [supabase, postgrest, generic-rest]
    default: supabase
    description: Backend REST provider for cleanup PATCHes
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
---

# Bulletproof Drawer Perimeter

## Core Premise

Drawers and detail-modals accumulate write surfaces: inline edits (fee, price, notes, tags), buttons that mutate state (status change, flag, escalate), popover editors, bulk actions. Each is a silent-regression opportunity. One cast that should have been a proper type, one click that doesn't bubble, one Escape that closes the wrong parent — and the user loses trust in the tool.

This skill lays down the **regression perimeter**: a small number of Playwright tests that exercise every write surface end-to-end and fail loudly when any pipeline step breaks. Tests are **idempotent** (captures original state, mutates, restores) and **bulletproof** (no graceful skips, no environmental dependencies, run green on any dev instance).

## When to Use

**Trigger when**:
- Building or extending a drawer/detail-modal that has any inline-edit, popover-editor, or state-mutation button
- Adding Playwright regression tests to an existing drawer that has zero test coverage
- A drawer has regressed silently >1 time (repeat-bug = missing perimeter, not a new bug)
- Auditing an app for "why do drawer regressions keep shipping"

**Do NOT use for**:
- Pure-display drawers (no write surfaces) — use `e2e-test` smoke pattern instead
- Form-page tests that aren't inside a drawer/modal — different locator strategy
- Visual regression / screenshot diffing — use a dedicated visual-regression skill

## The Eight Patterns

### 1. Row-click on cell[1], not the row bounding-box

Virtualized tables (TanStack Virtual, react-window, etc.) typically render a first column that is a **selection checkbox** — its click handler does NOT bubble to the row's `onClick` delegation. Clicking the row's bounding-box hits cell[0] (the checkbox) and the drawer never opens.

```typescript
// ❌ Flaky / doesn't open drawer
await page.locator('[data-tour="pipeline-first-row"]').click();

// ✅ Reliable — address cell carries the row-onClick delegation
await page.locator('table tbody tr').first().locator('td').nth(1).click();
```

Add a stable `data-tour="<your-table>-first-row"` (or equivalent anchor) on the first virtualized row.

### 2. Drawer scope disambiguation via role=dialog

Text like "Your Fee", "Asking Price", "Status" appears in BOTH the pipeline table column header AND inside the drawer's hero cards. Naive `page.getByText()` matches the WRONG element half the time.

```typescript
// ❌ Matches the table column header, not the drawer hero card
const feeLabel = page.getByText('Your Fee', { exact: true }).first();

// ✅ Scoped to the drawer portal
const DRAWER_SELECTOR = '[role="dialog"][aria-modal="true"]';
const drawer = page.locator(DRAWER_SELECTOR).first();
const feeLabel = drawer.getByText('Your Fee', { exact: true });
```

Always scope drawer-internal queries to `drawer`. If the drawer is a custom `createPortal` without `role="dialog"`, add those attributes or use a stable `data-tour="drawer-header"`.

### 3. Two-click display→edit toggle recognition

Inline-edit components often have a **display mode** (shows a formatted value with pencil icon) that transitions to **edit mode** (mounts the input) on click. If the display mode is inside a popover, you need **two clicks**: one to open the popover, one to enter edit mode.

```typescript
// Fee card inside drawer
await feeLabel.click();                                              // Click 1: opens popover
await expect(popover.getByText('Edit Fee Label')).toBeVisible();
await popover.locator('button').first().click();                     // Click 2: enters edit mode
const input = popover.locator('input[inputmode="numeric"]');
await expect(input).toBeVisible();
```

Recognize this pattern in your target component by reading its source: look for `const [editing, setEditing] = useState(false)` and `if (editing) return <Input ... />; return <button onClick={() => setEditing(true)} />;`.

### 4. Idempotent round-trip test structure

Every round-trip test follows the same 4-phase structure. Tests that mutate DB state MUST restore original values so the test is safe to run 100 times back-to-back with zero net state drift.

```typescript
test('Round-trip: <surface> persists + restores', async ({ page }) => {
  const drawer = await openDrawerOnFirstRow(page);

  // PHASE 1 — Capture original state
  const editor = /* locate the editor */;
  await editor.openEditMode();
  const initialValue = await editor.getValue();
  const propertyId = await currentPropertyId(page);

  // PHASE 2 — Mutate via UI
  await editor.fillAndCommit(TEST_VALUE);

  // PHASE 3 — Verify the full write path via UI re-render
  await expect(drawer).toContainText(TEST_VALUE_FORMATTED, { timeout: 10000 });

  // PHASE 4 — Cleanup (always runs, even on failure) via REST
  await restoreField(page, propertyId, 'field_name', initialValue);

  await closeDrawer(page);
});
```

The Phase 3 `toContainText` assertion is the full-pipeline proof: DB write → view refetch → React Query cache → DOM render. If any step silently fails, the DOM doesn't reflect the new value.

### 5. Cleanup via direct REST PATCH

UI-driven cleanup (re-click → re-open → type → save) is **flaky** in apps with Radix popovers + React Query + realtime subscriptions. The popover close-animation races the realtime-driven refetch; the button re-renders mid-click; the test errors with "element was detached from the DOM, retrying."

```typescript
// ❌ Flaky — races realtime-driven remounts
await feeLabel.click();
await popover.locator('button').first().click();  // ← "element is not stable"
await reopenedInput.fill(initialValue);

// ✅ Deterministic — direct REST PATCH
async function restoreField(page, propertyId, field, value) {
  const token = getAccessTokenFromStorageState();
  const res = await page.request.patch(
    `${supabaseUrl}/rest/v1/${table}?id=eq.${propertyId}`,
    {
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${token}`,
        Prefer: 'return=minimal',
      },
      data: { [field]: value },
    }
  );
  if (!res.ok()) throw new Error(`Cleanup PATCH failed (${res.status()}): ${await res.text()}`);
}
```

RLS/auth is still enforced — the test user's token goes with the PATCH — so the permission boundary stays in the test.

### 6. Serial mode for realtime-subscription sharing

If the app uses Supabase Realtime or similar WebSocket subscriptions, parallel test execution lets one test's UPDATE reach another test's browser context and disrupt its state.

```typescript
// At top of spec file
test.describe.configure({ mode: 'serial' });
```

Also set `fullyParallel: false` at the project level in `playwright.config.ts` for test files known to share realtime state.

### 7. Access-token capture from Playwright storageState

For REST PATCH cleanup (pattern #5), you need the test user's access token. It lives in the Supabase JS client's `localStorage` under `sb-<project-ref>-auth-token` and is persisted by Playwright's `globalSetup` into `playwright/.auth/user.json`.

```typescript
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function getAccessToken(): string {
  const storage = JSON.parse(
    fs.readFileSync(
      path.resolve(__dirname, '../../playwright/.auth/user.json'),
      'utf8'
    )
  );
  for (const origin of storage.origins ?? []) {
    for (const item of origin.localStorage ?? []) {
      if (item.name?.startsWith('sb-') && item.name.endsWith('-auth-token')) {
        const parsed = JSON.parse(item.value);
        if (parsed?.access_token) return parsed.access_token;
      }
    }
  }
  throw new Error('Could not extract access_token from storageState');
}
```

For non-Supabase backends (plain PostgREST, Firebase, custom API), adapt the storage key pattern.

### 8. Zero-skip discipline

**Graceful skip is a failure mode here**, not a feature. A skipped test provides zero regression signal — the user can't tell if the feature works or if the test is broken.

```typescript
// ❌ Graceful skip — this test provides NO regression guarantee
test('Flag button works', async ({ page }) => {
  const flagBtn = drawer.getByRole('button', { name: /flag/i });
  if (await flagBtn.count() === 0) {
    test.skip(true, 'Flag button not visible — data dependency');
    return;
  }
  // ...
});

// ✅ Re-target the invariant at an always-available surface
// (e.g., Escalate button mirrors Flag's Escape-close pattern but has no SOP gate)
test('Inline-reason Escape does NOT close drawer', async ({ page }) => {
  const escalateBtn = drawer.getByRole('button', { name: /escalate/i });
  await escalateBtn.click();  // Always available
  const input = drawer.locator('input[placeholder*="Escalation"]');
  await input.press('Escape');
  await expect(drawer).toBeVisible();
});
```

If an invariant truly requires environmental setup, **seed the fixture via `beforeAll`** — don't skip. Graceful skip hides UI regressions.

## Anti-Patterns

### AP1: Waiting on `input:focus`

`input:focus` resolves whichever input happens to be focused at the moment the selector is evaluated. With auto-focus timing + Radix portal mounts, this races in ways that produce "element not found" errors that re-running "fixes" non-deterministically.

```typescript
// ❌ Racy
const input = page.locator('input:focus');
await expect(input).toBeVisible({ timeout: 3000 });

// ✅ Scoped to the popover by known attribute
const input = popover(page).locator('input[inputmode="numeric"]');
await expect(input).toBeVisible({ timeout: 3000 });
```

### AP2: Clicking text that has duplicate matches

Text like "Status", "Fee", "Price", "Owner" appears in column headers AND drawer content. `.first()` is a lie when the "first" is the column header.

Always scope by the drawer container, OR disambiguate by additional attribute (placeholder, aria-label, testid).

### AP3: UI re-click cleanup inside realtime-subscribed components

The React Query realtime refetch fires mid-cleanup, remounts the popover trigger, and Playwright errors with "element was detached from the DOM." This is **not flaky hardware** — it's a deterministic race.

Fix: REST PATCH cleanup (pattern #5).

### AP4: `expect(x).toHaveCount(0)` for popover unmount

Radix popovers don't always fully unmount on close; they may animate out over several frames. Waiting for `count === 0` can time out even when the popover is visibly gone. Wait on the NEW state's marker instead of the OLD state's absence.

### AP5: Assuming pipeline/list loads fast enough

Pipeline queries against production views (with 10+ CTE JOINs, aggregates, LATERAL joins) can take 5–15 seconds on dev DBs and occasionally hit statement-timeout ("canceling statement due to statement timeout"). Test setup should wait for the first row anchor explicitly (`[data-tour="<your-first-row>"]` with `timeout: 30000`), not rely on `networkidle`.

### AP6: Testing every write surface separately when one path covers them all

If three editors (fee, price, notes) all route through the same `useUpdateResource` hook, ONE round-trip test against one surface proves the hook works. The other editors need smoke tests (input accepts + save triggers) but not full round-trips.

Don't write 8 redundant round-trip tests. Write 1 round-trip per distinct hook/mutation path + light assertions for each surface.

## Structure of the Spec File

A bulletproof drawer spec looks like this:

```
tests/e2e/<feature>-drawer-regression.spec.ts
├── Imports (test, expect, fs, path)
├── test.describe.configure({ mode: 'serial' })
├── Helpers
│   ├── DRAWER_SELECTOR constant
│   ├── openDrawerOnFirstRow(page) → returns drawer Locator
│   ├── closeDrawer(page)
│   ├── popover(page) → returns Radix popper wrapper
│   ├── getAccessToken() → extracts from storageState
│   ├── restoreField(page, id, field, value) → REST PATCH
│   └── currentResourceId(page) → reads from sessionStorage
└── Tests
    ├── A1: Primary write-surface round-trip (the HIGHEST-value test)
    ├── A2-Aₙ: Secondary round-trips per distinct mutation path
    ├── B1: Inline-reason Escape does NOT close drawer (invariant)
    └── B2: Top-level Escape DOES close drawer (complement to B1)
```

See `examples/round-trip-test-template.ts` for a fully parameterized template.

## Verification

Before considering the perimeter "bulletproof", all these must be true:

- [ ] Every distinct mutation path has a round-trip test (not every surface — see AP6)
- [ ] Every test is idempotent (runs 100× with zero net state drift)
- [ ] Zero tests skip in a clean dev environment
- [ ] Cleanup happens even on test failure (via `afterEach` or try/finally)
- [ ] Tests run in `mode: 'serial'` if app has realtime subscriptions
- [ ] The spec has Escape-close invariant coverage (positive + negative cases)
- [ ] Access-token capture handles token-refresh gracefully (24h sessions)
- [ ] Local run passes 3× in a row with no "retry" flakes

## Composition

| Composes with | When |
|---|---|
| `e2e-test` | Orchestrates the broader test suite; drawer-perimeter specs are ONE input |
| `ui-design-system` | Defines the drawer components BEING tested — design + test co-evolve |
| `guided-tour` | If tours render on first load, tour-dismissal must be in Playwright globalSetup |

## Escape Hatches

If a surface genuinely can't be tested without environmental seeding (rare):

1. Add a fixture-seeding `beforeAll` that creates the needed state idempotently (`INSERT ... ON CONFLICT DO NOTHING`)
2. Document the fixture as part of the spec file's header comment
3. Add a corresponding `afterAll` that removes the fixture ONLY if this test created it
4. Never use `test.skip(true, ...)` as a workaround — it's a regression-coverage lie

---

**Incident log (why each pattern exists)**:
- Pattern 1: virtualized-table first-row click produced zero drawer opens in a client project; ~30 min to diagnose.
- Pattern 2: "Your Fee" column header duplicated the drawer hero label, breaking first locator attempt silently.
- Pattern 3: Discovered that inline-edit popovers require two clicks by reading component source; tests clicking once timed out.
- Pattern 4: First A1 version re-opened the popover to verify persistence; races caused flakes.
- Pattern 5: UI cleanup consistently failed "element detached from DOM" due to React Query realtime refetch.
- Pattern 6: Parallel tests leaked state across browser contexts via Supabase Realtime.
- Pattern 7: Access token needed for REST cleanup; storageState parse pattern not documented elsewhere.
- Pattern 8: Graceful skip masked an SOP-gate data dependency; user (correctly) pushed back that "skip is a failure mode."

Validated against a SaaS app seller drawer 2026-04-23 — 3 tests PASS in 20.9s.
