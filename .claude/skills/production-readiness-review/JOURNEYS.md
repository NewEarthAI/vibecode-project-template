# Journeys — surfaces the prod-readiness reviewer can drive  (TEMPLATE SKELETON — customise per project)

Journey slugs referenced by `surface-map.md`. The skill drives each one with `/e2e-quick`'s mechanics
(CDP connect → snapshot → interact by ref → re-snapshot → `console` → `network`) against the **LIVE**
`url`. Auth-gated journeys log in first (operator smoke creds).

> **This is a generic skeleton.** Replace the two example journeys below with your project's real
> ones, and keep them in sync with the `MAP` rules in `surface-map.md`. The **Universal smoke
> assertions** section is project-agnostic — keep it verbatim; it is what catches the P0 class.
> If a journey reuses your `/e2e-quick` built-in smokes, you can pass the slug straight through
> rather than redefining it here.

## Universal smoke assertions (applied to EVERY journey — this is what catches the P0 class)

A journey PASSES only if all four hold; any failure is a **RED** regression:

1. **Renders non-empty** — the route's primary container/heading is present in the snapshot (not a
   blank page, not a bare spinner that never resolves within the wait window).
2. **No ErrorBoundary fallback** — the snapshot does NOT contain "Something went wrong", "Couldn't
   load", "Application error", or a framework error overlay.
3. **No uncaught console errors** — `console` is clean after filtering the known-ignorable set (dev-tools
   noise, favicon 404, ResizeObserver loop, HMR logs, realtime-connect logs, browser-extension errors,
   third-party-cookie warnings).
4. **No non-2xx on app data calls** — `network` shows no `4xx`/`5xx`/**`522`** and no
   `Content-Type: text/html` on your app's data/API endpoints (e.g. `/api/*`, `/rest/v1/*`,
   `/functions/v1/*`). A `522` (or HTML where JSON is expected) here is the exact "site up, every data
   call dead" P0 signature a code/DB check is blind to — generalise the endpoint globs to your stack.

A journey whose route cannot be reached (auth fails, route 404s, no data id available) is **UNREACHABLE
→ contributes to AMBER**, never a silent pass.

```yaml
# --- EXAMPLE journeys — replace with your project's real surfaces (match surface-map.md MAP rules) ---
- name: home
  url: /
  auth: required          # set to none for a public landing page
  steps:
    - verify: the app's primary authed surface renders its main heading/container (not blank, not a
      never-resolving spinner)
    - verify: at least one piece of real content OR an explicit empty-state (not an error fallback)

- name: login
  url: /login             # or /auth — your auth route
  auth: none
  steps:
    - verify: the login form renders (email + password fields, submit button)
    - action: sign in with the operator smoke account
    - verify: redirect to an authed landing surface; no error fallback; no non-2xx on data calls
```

## Notes
- These are **smoke** journeys (does it render + behave for a logged-in user), not deep regression.
  When a smoke fails, escalate the single failing slug to the full `/e2e-test` orchestrator for DB
  validation + self-healing.
- Keep this list honest: only add a journey the skill can actually reach. A journey that's flaky or
  unreachable produces a false RED, which erodes trust faster than an honest AMBER. If a surface
  cannot be reliably driven yet, leave its files UNMAPPED in `surface-map.md` (→ honest AMBER) rather
  than claim a journey that lies.
