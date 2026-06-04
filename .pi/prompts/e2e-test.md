---
description: Run self-healing end-to-end tests with DB validation and structured reports
argument-hint: [--url URL] [--journey SLUG] [--quick] [--responsive]
---

# E2E Test: $ARGUMENTS

Load and execute the e2e-test orchestrator skill.

## Setup

1. Read `.claude/skills/e2e-test/SKILL.md` — this is the master orchestration protocol
2. Parse `$ARGUMENTS` for flags:
   - `--quick` → set mode=quick (skip Phase 2 research, use JOURNEYS file directly)
   - `--journey SLUG` → set mode=single, run only that journey
   - `--url URL` → override target URL (default: http://localhost:8080)
   - `--responsive` → add responsive viewport testing after journeys
   - No flags → mode=full (research + test all journeys)

## Execution

Follow the 7-phase workflow defined in SKILL.md:

1. **Phase 1**: Pre-flight checks (browser, frontend, DB, journeys) — run in parallel
2. **Phase 2**: Parallel research with 3 sub-agents (skip in `--quick` mode). When no JOURNEYS file exists, Agent C auto-generates up to 5 journeys from codebase analysis
3. **Phase 3**: Dev server management (start if needed, skip for remote URLs)
4. **Phase 3.5**: Data preconditions — verify test data exists via DB before browser testing
5. **Phase 4**: Create TodoWrite task list from discovered journeys
6. **Phase 5**: Execute E2E test loop with self-healing (includes Navigate to Entity pattern for efficient entity lookup)
7. **Phase 6**: Cleanup and generate structured report

## Journey Discovery

- Check for `JOURNEYS.*.md` files in `.claude/skills/e2e-test/`
- If found (and mode is quick/single): use JOURNEYS file directly
- If not found (or mode is full): Phase 2 sub-agents discover journeys from codebase

## Report

Always generate the structured report at the end. Ask the user if they want it exported to `e2e-test-report-{date}.md`.
