/**
 * Bulletproof Drawer Regression Perimeter — Spec Template
 *
 * Copy this file into `tests/e2e/<feature>-drawer-regression.spec.ts`
 * and replace {{PLACEHOLDER}} values with your project's specifics.
 *
 * Required env (in .env):
 *   {{SUPABASE_URL_VAR}}={{https://your-project.supabase.co}}
 *   {{SUPABASE_KEY_VAR}}={{publishable-anon-key}}
 *   E2E_USER_EMAIL={{test-user-email}}
 *   E2E_USER_PASSWORD={{test-user-password}}
 *
 * Required globalSetup in playwright.config.ts that authenticates
 * E2E_USER_EMAIL via Supabase REST and writes storageState to
 * `playwright/.auth/user.json`.
 */

import { test, expect, type Page, type Locator } from '@playwright/test';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ─── Serial mode for realtime-subscription sharing (Pattern 6) ────────────

test.describe.configure({ mode: 'serial' });

// ─── Selectors ─────────────────────────────────────────────────────────────

/**
 * Drawer scope disambiguation (Pattern 2).
 * If your drawer uses a custom createPortal without role="dialog",
 * add role + aria-modal attributes OR use a stable data-testid.
 */
const DRAWER_SELECTOR = '[role="dialog"][aria-modal="true"]';

/**
 * Stable first-row anchor on your virtualized pipeline/list table.
 * Add this as `data-tour="{{TABLE}}-first-row"` in your DataTable render.
 */
const FIRST_ROW_SELECTOR = '[data-tour="{{TABLE}}-first-row"]';

/**
 * sessionStorage key your app persists the selected-resource pointer to.
 * Example: `selected_{{resource}}` or `{{app}}_drawer_target`.
 */
const SELECTED_RESOURCE_STORAGE_KEY = 'selected_{{resource}}';

// ─── Helpers ──────────────────────────────────────────────────────────────

async function openDrawerOnFirstRow(page: Page): Promise<Locator> {
  await page.goto('/{{pipeline-route}}');
  await page.locator(FIRST_ROW_SELECTOR).waitFor({ state: 'visible', timeout: 30000 });
  // Pattern 1: click cell[1] (address/name cell), not the row bounding-box.
  // cell[0] is typically the selection checkbox whose click doesn't bubble.
  await page.locator('table tbody tr').first().locator('td').nth(1).click();
  const drawer = page.locator(DRAWER_SELECTOR).first();
  await expect(drawer).toBeVisible({ timeout: 8000 });
  return drawer;
}

async function closeDrawer(page: Page) {
  await page.keyboard.press('Escape');
  await expect(page.locator(DRAWER_SELECTOR)).not.toBeVisible({ timeout: 5000 });
}

/**
 * Radix Popover portal — use `.last()` because earlier popovers may
 * linger during close-transitions.
 */
function popover(page: Page): Locator {
  return page.locator('[data-radix-popper-content-wrapper]').last();
}

// ─── Auth-token capture from storageState (Pattern 7) ─────────────────────

let cachedAccessToken: string | null = null;
function getAccessToken(): string {
  if (cachedAccessToken) return cachedAccessToken;
  const storageStatePath = path.resolve(__dirname, '../../playwright/.auth/user.json');
  const storage = JSON.parse(fs.readFileSync(storageStatePath, 'utf8'));
  for (const origin of storage.origins ?? []) {
    for (const item of origin.localStorage ?? []) {
      // Supabase JS client key pattern: sb-<project-ref>-auth-token
      if (item.name?.startsWith('sb-') && item.name.endsWith('-auth-token')) {
        const parsed = JSON.parse(item.value);
        if (parsed?.access_token) {
          cachedAccessToken = parsed.access_token;
          return cachedAccessToken;
        }
      }
    }
  }
  throw new Error('Could not extract access_token from playwright/.auth/user.json');
}

// ─── REST PATCH cleanup (Pattern 5) ───────────────────────────────────────

/**
 * Direct REST PATCH to bypass the Radix popover close + React Query
 * realtime-refetch race that makes UI-driven cleanup flaky.
 * Still auth'd so RLS is enforced.
 */
async function restoreField(
  page: Page,
  resourceId: string,
  field: string,
  value: unknown
) {
  const supabaseUrl = process.env.{{SUPABASE_URL_VAR}} ?? '';
  const apikey = process.env.{{SUPABASE_KEY_VAR}} ?? '';
  const token = getAccessToken();
  const res = await page.request.patch(
    `${supabaseUrl}/rest/v1/{{TABLE}}?id=eq.${resourceId}`,
    {
      headers: {
        'Content-Type': 'application/json',
        apikey,
        Authorization: `Bearer ${token}`,
        Prefer: 'return=minimal',
      },
      data: { [field]: value },
    }
  );
  if (!res.ok()) {
    throw new Error(`Cleanup PATCH failed (${res.status()}): ${await res.text()}`);
  }
}

async function currentResourceId(page: Page): Promise<string> {
  const raw = await page.evaluate(
    (key) => window.sessionStorage.getItem(key),
    SELECTED_RESOURCE_STORAGE_KEY
  );
  if (!raw) throw new Error(`No selected resource in sessionStorage (key: ${SELECTED_RESOURCE_STORAGE_KEY})`);
  const parsed = JSON.parse(raw);
  if (!parsed?.id) throw new Error('Selected resource has no id');
  return parsed.id;
}

// ─── Tests ────────────────────────────────────────────────────────────────

test.describe('@regression {{Feature}} drawer', () => {

  /**
   * A1 — Primary write-surface round-trip.
   *
   * The HIGHEST-value test — exercises the full write path:
   *   DrawerHeroCard → InlineEdit → useUpdateResource hook
   *   → PostgREST UPDATE → view refetch → React Query cache
   *   → MetricCard re-render.
   *
   * Idempotent (Pattern 4): captures initial value, writes test value,
   * restores original via REST PATCH (Pattern 5). Can run 100× with
   * zero net state drift.
   */
  test('A1: {{primary-field}} round-trip persists + clears correctly', async ({ page }) => {
    test.setTimeout(120000);
    const drawer = await openDrawerOnFirstRow(page);

    // Pattern 2: scope lookups to the drawer to avoid text collisions
    // (column headers commonly duplicate drawer hero labels).
    const label = drawer.getByText('{{FIELD_LABEL}}', { exact: true });
    await expect(label).toBeVisible({ timeout: 5000 });
    await label.click();

    // Pattern 3: two-click display→edit toggle recognition.
    // First click opened the popover; second click enters edit mode.
    await expect(popover(page).getByText('Edit {{FIELD_LABEL}}')).toBeVisible({ timeout: 3000 });
    await popover(page).locator('button').first().click();
    const input = popover(page).locator('input[inputmode="numeric"]');
    await expect(input).toBeVisible({ timeout: 3000 });

    const initialValue = await input.inputValue();
    const TEST_VALUE = {{TEST_VALUE_NUMERIC}};
    const resourceId = await currentResourceId(page);

    await input.fill(String(TEST_VALUE));
    await input.press('Enter');

    // Full-pipeline proof: DOM reflects the persisted value.
    // If ANY step silently fails (cast hides schema drift, mutation
    // rolls back, cache doesn't invalidate), this assertion fails.
    await expect(drawer).toContainText(/{{TEST_VALUE_REGEX}}/, { timeout: 10000 });

    // Cleanup (Pattern 5): direct REST PATCH.
    const restoreValue = initialValue === '' ? null : Number(initialValue);
    await restoreField(page, resourceId, '{{primary_field_db_name}}', restoreValue);

    await closeDrawer(page);
  });

  /**
   * B1 — Inline-reason Escape does NOT close the drawer (invariant).
   *
   * Pressing Escape inside any inline text input in the drawer header
   * (flag reason, escalate reason, search, etc.) must close THAT input
   * without bubbling to the drawer's document-level keydown listener.
   *
   * Implementation requirement: inline input's onKeyDown must call
   *   e.stopPropagation()
   *   e.nativeEvent.stopImmediatePropagation?.()
   * on Escape.
   *
   * Pattern 8: this test runs on every property — use an ALWAYS-AVAILABLE
   * inline input (e.g., "Escalate" which has no data-gate) as the
   * always-green surface. The invariant coverage is identical.
   */
  test('B1: inline-reason Escape does NOT close the drawer', async ({ page }) => {
    test.setTimeout(60000);
    const drawer = await openDrawerOnFirstRow(page);

    const triggerBtn = drawer.getByRole('button', { name: /{{INLINE_TRIGGER_REGEX}}/i });
    await expect(triggerBtn).toBeVisible({ timeout: 5000 });
    await triggerBtn.click();

    const inlineInput = drawer.locator('input[placeholder*="{{INLINE_INPUT_PLACEHOLDER_FRAGMENT}}"]');
    await expect(inlineInput).toBeVisible({ timeout: 3000 });
    await expect(inlineInput).toBeFocused();

    await inlineInput.fill('e2e escape guard');

    // Pre-fix: Escape bubbled to the drawer's document keydown listener
    // and unmounted the drawer. Post-fix: drawer stays, input closes.
    await inlineInput.press('Escape');

    await expect(drawer).toBeVisible({ timeout: 2000 });
    await expect(inlineInput).not.toBeVisible({ timeout: 2000 });
    await expect(drawer.getByRole('button', { name: /{{INLINE_TRIGGER_REGEX}}/i })).toBeVisible({ timeout: 2000 });

    await closeDrawer(page);
  });

  /**
   * B2 — Top-level Escape DOES close the drawer (complement to B1).
   *
   * Verifies the drawer's own Escape-close handler still works when no
   * inline input has focus. Guards against an over-eager stopPropagation
   * somewhere else in the tree that might accidentally neutralize the
   * intended close.
   */
  test('B2: top-level Escape DOES close the drawer', async ({ page }) => {
    test.setTimeout(30000);
    const drawer = await openDrawerOnFirstRow(page);

    // Click a neutral drawer area to ensure no inline input retains focus.
    await drawer.click({ position: { x: 10, y: 10 } });

    await page.keyboard.press('Escape');
    await expect(page.locator(DRAWER_SELECTOR)).not.toBeVisible({ timeout: 5000 });
  });

});
