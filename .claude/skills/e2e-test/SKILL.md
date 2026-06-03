---
name: e2e-test
description: |
  Self-healing end-to-end test orchestrator. Auth-aware, API-validating,
  snapshot-first. Runs browser tests with DB validation, auto-retries
  transient failures, generates structured reports.
version: 2.0
classification: encoded-preference
created: 2026-02-26
updated: 2026-03-07
supersedes: e2e-test v1.2
validated_on:
  - different_react_dashboard_with_postgres
  - nextjs_ecommerce_with_sqlite
  - static_site_no_database
  - template_project_no_journeys_file
triggers:
  - e2e test
  - end-to-end test
  - run e2e
  - smoke test suite
  - regression test
  - test the dashboard
  - test all journeys
  - run all tests
  - verify everything works
parameters:
  - name: url
    type: string
    default: "http://localhost:8080"
  - name: journeys
    type: string
    default: "all"
    description: Comma-separated journey slugs or "all"
  - name: mode
    type: enum
    values: [full, quick, single]
    default: full
    description: full=research+test, quick=JOURNEYS file only, single=one journey
  - name: auth_email
    type: string
    default: "{{E2E_TEST_EMAIL}}"
    description: Test account email (env var or literal)
  - name: auth_password
    type: string
    default: "{{E2E_TEST_PASSWORD}}"
    description: Test account password (env var or literal)
  - name: browser_tool_prefix
    type: string
    default: "mcp__chrome-devtools__"
    description: Auto-detected in pre-flight; override to force backend
  - name: db_tool
    type: string
    default: "mcp__supabase-.*__execute_sql"
    description: Regex matching DB tool; empty string = browser-only mode
  - name: dev_command
    type: string
    default: "npm run dev"
  - name: dev_port
    type: number
    default: 8080
  - name: screenshot_dir
    type: string
    default: "e2e-screenshots"
---

# E2E Test Orchestrator v2.0

## Permission Model

**E2E tests run with ZERO permission prompts.** This is non-negotiable:
- NEVER ask for permission to navigate, click, fill, screenshot, or run DB queries
- NEVER ask for permission to create directories or write screenshot/report files
- NEVER ask "should I proceed?" between journeys — just run them all
- NEVER pause for confirmation on any step — e2e is part of plan implementation
- All Bash commands (agent-browser, curl, mkdir) execute immediately
- If a step fails, log it and continue to the next step — do NOT ask the user

This skill is invoked as part of approved plan execution. The user has already
consented to all testing actions by running `/e2e-test`.

## Core Principle

Snapshot-first, auth-aware, API-validated, self-healing.

```
ALWAYS: snapshot -> get uids -> interact -> re-snapshot -> validate response -> DB check
NEVER: screenshot-only, skip auth for protected routes, treat 200 as success
NEVER: ask permission for ANY test step — run everything autonomously
ON FAILURE: log it, continue to next step, report all failures at the end
```

**Composition** (reference, don't duplicate):
- Browser patterns: `references/BROWSER-BACKENDS.md`
- Auth patterns: `references/auth-patterns.md`
- API validation: `references/api-validation.md`
- Self-healing: `references/self-healing.md`

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Screenshot -> guess coordinates | No refs in screenshots | Snapshot -> use uid/ref |
| `SELECT * FROM raw_table` for validation | Token-heavy, bypasses canonical views | Use canonical views/RPCs with LIMIT |
| Auto-fix source code SILENTLY on failure | Causes regressions, conflicts with managed platforms | Diagnose root cause, report fix in final report |
| Run full research on every `--quick` | Wastes 3000+ tokens rediscovering known journeys | Use JOURNEYS file, skip Phase 2 |
| Hardcode element selectors in JOURNEYS | Selectors change on every deploy | Use semantic text waits + re-snapshot for uids |
| Take fullPage screenshots | 10x token cost | Viewport-only screenshots, organized by journey |
| Navigate by random clicking / screenshot coords | Wastes 5-10 snapshot cycles to find entity | Search/filter -> wait -> snapshot -> click uid |
| Start UI tests without verifying test data | Wasted browser cycles on empty states | Run data preconditions check first (Phase 3.5) |
| Skip auth'd routes | Misses 30-40% of app functionality | AUTH micro-pattern before journey |
| 200 = success | HTML error pages return 200 | 200 + Content-Type:json + parseable body = success |
| Inline self-healing (huge SKILL.md) | Token waste on every load | Extract to references/self-healing.md |
| Write test that clears the failure state before asserting | Test passes against broken code — regression theater | Seed the exact failure state, then assert correct behavior |
| Ship a test without proving it fails on broken code | No signal that test actually catches the regression | Run negative-control: revert fix, watch test go red, restore fix |
| `wait_for` response truncated → re-snapshot blindly to look for target uid | Same truncation fires again; wastes another tool call | Read the saved file with a narrow `grep` (e.g. `grep -nE 'button "Satellite\|Map"' /path/to/saved.txt`) to find the uid. Re-snapshot only after navigation changes the tree. |

---

## Negative-Control Discipline (MANDATORY for regression tests)

**A test is untrustworthy until you've watched it fail.** Every new regression test MUST pass a negative-control run before being trusted.

### Protocol

1. Write the test asserting the *fixed* behavior
2. **Before committing**: revert the fix in a worktree (`git stash` the fix, or check out parent commit)
3. Run the test — it MUST fail with an assertion error (not a setup/import error)
4. Restore the fix
5. Run the test — it MUST pass
6. Document the negative-control proof in commit message: `Verified: test fails on $PARENT_SHA, passes on HEAD`

### Why

- Tests that clear localStorage / reset state BEFORE asserting are the #1 false-green pattern
- Tests that assert on the wrong element (typo in selector, wrong text) silently pass regardless of code state
- Tests with conditional skips (`test.skip(condition)`) can disable themselves invisibly

### Red flags in test PRs

- New test, no mention of negative-control run → reviewer must require one
- Test added in same commit as fix, no separate "failed before, passes now" evidence
- Test uses `.addInitScript()` to clear state matching the regression being tested

### Failure precedent

2026-04-18: `tests/e2e/submit.smoke.spec.ts` cleared `submit_mode` localStorage before asserting ModeSelector — test was green for 3+ weeks while the exact stale-state bug shipped to prod. Rewritten to SEED the failure state, not clear it. Commit `ed6d87e`.

---

## Browser Tool Abstraction

Pre-flight auto-detects which backend is available. `browser_tool_prefix` parameter overrides.

**Detection order**: Chrome DevTools MCP -> Playwright MCP -> agent-browser CLI.

Full operation mapping: `references/BROWSER-BACKENDS.md` (load on demand during Phase 1 if auto-detection fails).

---

## Phase 1: Pre-flight Checks

Run 5 checks in parallel:

1. **Browser**: Call `{{prefix}}list_pages` -- if fails, guide user to launch Chrome with `--remote-debugging-port=9222`
2. **Frontend**: Check `package.json` for `{{dev_command}}` script
3. **Database**: Run `SELECT 1` via `{{db_tool}}` -- if fails, degrade to browser-only mode
4. **Journeys**: Check for `JOURNEYS.*.md` in `.claude/skills/e2e-test/`
5. **Auth**: Check if `{{auth_email}}` and `{{auth_password}}` resolve to non-empty values

Output: `{ browser_ok, browser_backend, frontend_framework, db_ready, journeys_source, auth_ready }`

If browser is unavailable, STOP with clear setup instructions. All other failures are soft (graceful degradation).

---

## Phase 2: Parallel Research (3 Sub-Agents)

**Skip entirely in `quick` mode** -- uses JOURNEYS file directly. This saves ~3000 tokens.

Launch 3 agents via Task tool (`subagent_type: "Explore"`):

**Agent A — App Structure**: Read `package.json`, scan `src/pages/`, `src/components/`, router config. Return: routes, key components, dev port, auth requirements.

**Agent B — DB Schema**: Query `information_schema.tables` + `information_schema.columns` for tables referenced by frontend. Discover RPCs via `information_schema.routines`. Return: tables, RPCs, data flow mapping. Use `LIMIT 50` on all queries.

**Agent C -- Journey Discovery**:
- If JOURNEYS file exists: read and parse it
- If JOURNEYS file is missing: **generate journeys** from codebase analysis:

```
Journey Generation Protocol (when no JOURNEYS file exists):
1. Collect routes from Agent A output
2. For each route, identify: page component, data dependencies, key interactions
3. Generate up to 5 concrete journeys, prioritized:
   a. Critical path (login -> main entity list -> entity detail)
   b. CRUD operations (create/edit/delete if forms exist)
   c. Navigation flows (between major sections)
   d. Edge cases (empty states, error boundaries)
   e. Data display (verify key metrics render correctly)
4. Each generated journey MUST include:
   - name: descriptive slug
   - url: route path
   - auth: none|buyer|seller|admin (inferred from route guards)
   - steps: [{action, target_text, expected_outcome}]
   - db_check: validation query (if DB available)
   - preconditions.db_check: data existence query
5. Cap at 5 journeys to control scope and token budget
```

Also grep for TODO/FIXME/HACK in discovered components. Return: journeys array, known bugs.

Merge results into a unified journey plan.

---

## Phase 3: Dev Server Management

1. Check port: `lsof -i :{{dev_port}} -t`
2. If running: navigate to verify it loads, set `server_was_running=true`
3. If not running: start `{{dev_command}}` in background, wait for ready signal
4. If `{{url}}` is non-localhost: skip server management entirely

---

## Phase 3.5: Data Preconditions

Before browser testing, verify test data exists. Prevents wasted browser cycles on empty states.

```
1. If journey defines `preconditions.db_check`:
   - Run each query via {{db_tool}} with LIMIT 1
   - If returns rows -> precondition MET, continue

2. If precondition FAILS and `preconditions.setup_hint` exists:
   - REPORT: "Test data missing: {description}. Suggested setup: {hint}"
   - SKIP the journey and log "precondition failed: {description}" in report

3. If {{db_tool}} unavailable:
   - SKIP all precondition checks (browser-only mode)
   - Log: "DB unavailable -- skipping data preconditions"
```

---

## Phase 3.7: Authentication

If journey defines `auth: buyer|seller|admin`, run the AUTH micro-pattern before journey execution.

```
AUTH FLOW:
1. Check if already authenticated for this role (cached from prior journey)
   - YES → skip login, proceed to journey
   - NO → run AUTH micro-pattern (see references/auth-patterns.md)

2. AUTH micro-pattern (5 steps):
   navigate(/auth) → snapshot → fill(email, password) → click(submit) →
   wait_for(role_landing_page)

3. If auth_ready=false (from Phase 1):
   - SKIP all auth-required journeys
   - REPORT: "Auth credentials not configured — skipping {n} authenticated journeys"
   - Continue with auth:none journeys

4. If login fails:
   - REPORT auth_failure with error details
   - SKIP remaining journeys for this role
```

Full auth patterns including session persistence, expiry healing, and failure handling: `references/auth-patterns.md`

---

## Phase 4: Task List Creation

Create TodoWrite items from discovered journeys:

```
For each journey in priority order:
  - "E2E: {journey.name}" (pending)
Add at end:
  - "E2E: Responsive testing" (pending, if --responsive flag)
  - "E2E: Cleanup & generate report" (pending)
```

Mark each journey `in_progress` as you start it, `completed` when done.

---

## Phase 5: E2E Test Loop (THE CORE)

For each journey, for each step:

```
1. PRE-CHECK
   - take_snapshot()
   - Verify preconditions (expected elements in accessibility tree)

2. ACTION
   - Navigate / click / fill / wait / eval based on step type
   - Use uid from snapshot (NEVER hardcoded selectors)

3. POST-CHECK
   - take_snapshot()
   - Verify expected outcome (text present, element state changed)

4. SCREENSHOT
   - take_screenshot({{screenshot_dir}}/{date}/{journey-slug}/{NN}-{step-name}.png)
   - Viewport only (NOT fullPage)

5. CONSOLE CHECK
   - list_console_messages()
   - Filter: errors only, exclude known ignorable (see references/self-healing.md)

6. NETWORK + API VALIDATION
   - list_network_requests()
   - Flag any 4xx/5xx responses
   - Apply VALIDATE pattern on API responses (see references/api-validation.md):
     a. Content-Type must be application/json (not text/html)
     b. JSON.parse body — parse failure = REPORT api_invalid_json
     c. Check for {error: ...} in 200 responses = REPORT api_error_in_200

7. DB VALIDATION (if step.db_check defined)
   - Run step.db_check query via {{db_tool}}
   - Compare: DB values vs displayed values
   - Apply tolerance rules (rounding, currency formatting, timing windows)

8. SELF-HEALING (if any check failed)
   - Apply decision tree from references/self-healing.md
   - NEW: Auth expiry (401) → re-login via AUTH pattern
   - NEW: Content-type mismatch → REPORT (never retry)
```

### Navigate to Entity Micro-Pattern

Standard pattern for finding and opening a specific entity. Prevents the 8+ snapshot/click cycle problem.

```
NAVIGATE TO ENTITY (max 5 cycles):

1. SEARCH/FILTER (if search input exists):
   - take_snapshot()
   - Find search/filter input by uid
   - fill(uid, "{{entity_identifier}}")
   - Wait for results to filter

2. LOCATE:
   - take_snapshot()
   - Scan accessibility tree for target entity text
   - If FOUND: note the uid of the clickable row/card/link
   - If NOT FOUND and pagination exists:
     a. Click next page (max 3 pages)
     b. Re-snapshot and scan
     c. If still not found after 3 pages -> REPORT navigation_failure

3. SELECT:
   - click(uid) on the target entity
   - take_snapshot()
   - Verify: detail view loaded

4. WRONG ENTITY:
   - Navigate back, re-snapshot, try adjacent element (max 2 retries)

5. FAILURE:
   - After 5 total cycles -> REPORT navigation_failure
```

---

## Phase 6: Cleanup & Report

1. **Cleanup**: Kill dev server if WE started it (`server_was_running=false`)
2. **Generate report** (see format below)
3. **Ask user**: Export full report to `e2e-test-report-{date}.md`?

---

## Responsive Testing (optional, --responsive flag)

After journey testing, test 3 viewports on key pages:

| Viewport | Width | Height | Device |
|----------|-------|--------|--------|
| Mobile | 375 | 812 | iPhone 13 |
| Tablet | 768 | 1024 | iPad |
| Desktop | 1440 | 900 | Standard |

For each: resize -> navigate -> snapshot -> screenshot -> check layout.

---

## Report Format

```markdown
# E2E Test Report
**Date**: {date} | **URL**: {url} | **Mode**: {mode} | **Duration**: {elapsed}

## Summary
| Metric | Count |
|--------|-------|
| Journeys Run | {n} |
| Passed | {n} |
| Failed | {n} |
| Self-Healed | {n} |
| DB Validations | {n} |
| JS Errors | {n} |
| API Failures | {n} |
| API Validation Failures | {n} |

## Auth Status
| Role | Status | Method |
|------|--------|--------|
| {role} | {authenticated/skipped/failed} | {env_var/cached/re-login} |

## Journey Results
| # | Journey | Auth | Steps | Pass | Fail | Healed | Duration |
|---|---------|------|-------|------|------|--------|----------|
| 1 | {name} | {role} | {n} | {n} | {n} | {n} | {s}s |

## Failures (if any)
### {journey} > {step}
- **Type**: {selector_drift|data_mismatch|js_error|api_failure|api_content_type_mismatch|api_invalid_json|api_error_in_200|code_defect|navigation_failure|auth_failure}
- **Expected**: {expected}
- **Actual**: {actual}
- **Screenshot**: {path}
- **Diagnosis**: {root cause analysis}

## API Validation Failures (if any)
| Journey | Step | Endpoint | Issue | Detail |
|---------|------|----------|-------|--------|
| {name} | {step} | {url} | {content_type_mismatch|invalid_json|error_in_200} | {first 200 chars} |

## Data Mismatches (if any)
| Journey | Metric | DB Value | Display Value | Delta |
|---------|--------|----------|---------------|-------|

## Self-Healing Log (if any)
| Journey | Step | Error | Strategy | Retries | Outcome |
|---------|------|-------|----------|---------|---------|

## Screenshots
{tree listing of screenshot_dir/}
```

---

## Integration with Existing Skills

This skill **composes** (not duplicates) existing skills:

**Reference Files** (loaded on demand):
- `references/BROWSER-BACKENDS.md` → backend operation mapping
- `references/auth-patterns.md` → login flows, session management, expiry healing
- `references/api-validation.md` → content-type, JSON parse, error-in-200 rules
- `references/self-healing.md` → retry decision tree, known ignorable errors

**Pattern References** (follows these conventions):
- `browser-automation` -> snapshot-first interaction, anti-patterns
- `dashboard-data-integrity` -> canonical data source mapping (if exists)
- `supabase-query-optimization` -> LIMIT, no SELECT *, progressive disclosure (if exists)

---

## Screenshot Organization

```
{{screenshot_dir}}/
  {YYYY-MM-DD}/
    {journey-slug}/
      01-{step-name}.png
      02-{step-name}.png
      FAILURE-{step-name}.png
    responsive/
      mobile-{page-slug}.png
      tablet-{page-slug}.png
      desktop-{page-slug}.png
```

---

## Token Efficiency Notes

- **`--quick` mode**: Skips Phase 2 research entirely (~3000 token savings per run)
- **JOURNEYS file**: Caches journey definitions -- no re-discovery on repeat runs
- **Canonical views**: Pre-aggregated DB views vs raw table scans
- **Snapshots over screenshots**: Accessibility tree text (100-500 tokens) vs base64 image (5000-50000 tokens)
- **Progressive reporting**: Accumulate findings in memory, generate report once at end
- **Skill composition**: References existing skills by path, doesn't inline their content
- **Navigate to Entity pattern**: Search/filter instead of random clicking (max 5 cycles)
- **Reference file extraction**: Self-healing, auth, API validation loaded on demand (~800 token savings)
- **Data preconditions (Phase 3.5)**: Verify data exists before browser testing
- **Auth caching**: Login once per role, not once per journey
- **Journey generation cap**: Max 5 journeys when auto-generating

---

## Negative-Control Protocol for NEW E2E Specs (added 2026-04-25)

**Background**: A new e2e test passing green proves nothing about whether it catches future regressions. The Bug 4 precedent (PR #188, 2026-04-21) showed that without negative-control, a test can ship green while testing nothing. This protocol makes proof-of-catch automatic.

**Rule**: Any newly-added (not modified) `tests/e2e/*.spec.ts` file in a PR MUST be negative-controlled before merge.

**Mechanism**: `.claude/skills/ship/scripts/negative-control.sh` — runs the spec twice:
1. Against the unbroken feature: must PASS
2. Against the same feature with one identifying line broken (commented out): must FAIL

If both runs pass → spec is **vacuous**. Block merge until the spec author tightens assertions.

**Auto-detection**: the script identifies the "feature under test" by:
- Reading `getByTestId('...')` / `data-testid="..."` selectors from the spec
- Grepping `src/` for the file that emits that testid
- Falling back to imported component names from spec's `import` statements

**Caller integration**: `/ship pr` mode runs negative-control automatically when the diff includes new e2e files. Manual invocation:
```bash
.claude/skills/ship/scripts/negative-control.sh tests/e2e/my-new.spec.ts \
  [--feature-file src/components/X.tsx] \
  [--marker "data-testid-or-component-name"] \
  [--base-url http://localhost:4173]
```

**Exit codes**:
- 0 — spec proven to catch its claimed regression (proceed to merge)
- 1 — spec is vacuous (BLOCKING)
- 2 — couldn't auto-detect feature; pass `--feature-file` and `--marker`
- 3 — Playwright/preview infrastructure error (not a verdict)

**When this is overkill**: simple smoke tests that only assert `200 OK` or page-loads-without-error don't need negative-control — the assertion is broad enough that any breakage trips it. This protocol targets specs that claim to catch a SPECIFIC regression (e.g., "tab-switch state preservation," "feature X visible in mode Y").

**Reference**: `council/sessions/2026-04-21-buyer-bug4-negative-control.md` for the foundational precedent.
