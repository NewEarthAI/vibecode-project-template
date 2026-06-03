import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.BASE_URL || 'http://localhost:4173';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? 'github' : 'html',
  // Bumped from default 5000ms to accommodate React Query auth hydration
  // on cold Vercel preview (authLoading spinner → login form transition
  // takes 3-10s on first paint).
  expect: { timeout: 15000 },
  timeout: 45000,
  use: {
    baseURL,
    trace: 'on-first-retry',
    storageState: 'playwright/.auth/user.json',
    actionTimeout: 15000,
    navigationTimeout: 30000,
  },
  globalSetup: './playwright/global-setup.ts',
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  // Only start local server when not using external BASE_URL
  ...(process.env.BASE_URL
    ? {}
    : {
        webServer: {
          command: 'npm run preview',
          port: 4173,
          reuseExistingServer: !process.env.CI,
        },
      }),
});
