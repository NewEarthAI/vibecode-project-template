---
name: production-readiness-review
description: |
  Post-deploy "did this break anything for a real user?" gate. Maps a diff to the logged-in surfaces
  it touched, drives a REAL browser over only those surfaces on the LIVE site (login, navigate,
  render-check, read console + network status), checks the DB for the connection-storm signature, and
  emits an HONEST-coverage verdict that never reports green over partial/stale/absent coverage. The
  post-deploy witness that catches the 522-class regression a code/DB/static check is blind to.
  Composes /e2e-quick (browser drive) + get_logs (DB) + verify-shipped (deploy drift) — does NOT
  rebuild them. Read-only against production: surfaces a verdict, never mutates prod.
version: 1.0
created: 2026-06-27
user-invocable: true
triggers:
  - production readiness
  - prod readiness
  - prod-readiness review
  - did this break prod
  - post-deploy check
  - verify the deploy
  - is the live site ok after this
parameters:
  - name: diff_range
    type: string
    default: "origin/main...HEAD"
    description: What changed — git range whose surfaces to verify.
  - name: url
    type: string
    default: "{{production_url}}"
    description: The LIVE deployed target (NOT localhost). Use a preview URL for a seeded-regression dry run.
  - name: auth_email
    type: string
    default: "{{smoke_account_email}}"
    description: Operator smoke account (an account that sees the full authed surface). Source from your project's smoke-creds reference / env.
  - name: auth_password
    type: string
    default: ""
    description: Smoke password (from the smoke-creds reference / env; never hardcode in a commit).
  - name: cdp_port
    type: number
    default: 9222
    description: Chrome DevTools Protocol port for the browser drive (handed to /e2e-quick).
  - name: public_report_id
    type: string
    default: ""
    description: Optional known-good id for a public (no-login) surface journey; if absent it is UNREACHABLE (AMBER), never fabricated.
---

# Production-Readiness Review — the post-deploy witness

## What this is (and is NOT)

The third autonomy pillar: after autovibe/autofire ships, this answers *"did the deployed change
actually work for a real user, and did anything regress?"* — by driving a real logged-in browser, not
by re-reading code. It exists because a code/DB/static gate is **blind to the `522`-class**: a real
user can see the whole site throw `522` (or HTML where JSON is expected) on every data call while the
database reports those queries as merely "slow" and every static check passes. Only a real-browser
drive sees that.

**Boundary vs `/dev-prod`:** `/dev-prod` is the *pre-ship* gatekeeper (staging-first, schema-drift,
rollback rehearsal) — it makes the *promote* safe. This is the *post-deploy* witness — it confirms the
*deploy* works. They compose: `/dev-prod`'s post-promotion smoke step can call this skill.

**Compose, never rebuild** (the framing reframe): the browser drive is `/e2e-quick`; the DB check is
`get_logs`; deploy/file drift is `/verify-shipped`. The only NEW code is the **diff→surface map**
(`scripts/map-diff-to-surfaces.sh` + `surface-map.md`) and the **honest verdict**
(`references/honest-coverage-verdict.md`).

**Hard stops:** READ-ONLY against production. NEVER deploy, mutate, auto-fix, admin-merge, or fabricate
prod data (Confident Mode). Surface the verdict; the operator acts.

> **First-run setup (per project):** fill `surface-map.md` (the `MAP` rules for your real surfaces) +
> `JOURNEYS.md` (their step definitions), set `url` / `auth_email` defaults to your project's values,
> and keep `scripts/map-diff-to-surfaces.sh --self-test` green after editing the map.

## Phase 1 — Resolve the diff

```bash
git diff --name-only {{diff_range}}
```
Empty diff → nothing to verify; report and stop.

## Phase 2 — Map diff → surfaces (the new glue, topology-grounded with honest fallback)

Run the deterministic mapper:
```bash
bash .claude/skills/production-readiness-review/scripts/map-diff-to-surfaces.sh --diff-range "{{diff_range}}"
```
It classifies every changed file: **MAPPED** (drive these journeys), **EXEMPT** (tests/docs/config/
migrations — no browser surface; migrations are the DB-storm check's job), or **UNMAPPED** (a source
or edge-function file with no surface → a genuine coverage gap).

- **Topology first (when it exists):** if a topology substrate is FRESH, prefer walking each changed
  node's `depended_on_by` edges to the surfaces that depend on it, and label `mapping_source=topology`.
  Topology is ABSENT by default, so the registry IS the normal path — that's expected, not a failure.
  Do NOT claim topology-grade confidence the run didn't have; the verdict prints `mapping_source=registry`.
- Read the `JOURNEYS:` line (the deduped set to drive), `UNMAPPED:` (the gap list → AMBER), and
  `VERDICT_HINT:` (the mapping-coverage dimension only — the mapper NEVER decides GREEN).

If `VERDICT_HINT: NO_SURFACE` (only exempt/non-UI files changed): skip the browser drive, run the
DB-storm check (Phase 4), and report — a migration-only or docs-only diff has no browser surface.

## Phase 3 — Drive the LIVE browser over ONLY the mapped journeys (compose /e2e-quick)

Invoke `/e2e-quick` against the **live** target, filtered to the mapped journeys — do NOT rebuild the
browser mechanics:
```
/e2e-quick url={{url}} cdp_port={{cdp_port}} journeys=<comma-joined JOURNEYS from Phase 2> \
           auth_email={{auth_email}} auth_password={{auth_password}}
```
- The mapped journey slugs are defined in `JOURNEYS.md` (some may reuse `/e2e-quick`'s built-in smokes —
  pass those straight through). Drive each with the same CDP-connect → snapshot → interact → `console`
  → `network` pattern.
- Apply the **four universal smoke assertions** from `JOURNEYS.md` to every journey: renders non-empty,
  no ErrorBoundary fallback, no uncaught console error, no non-2xx (esp `522`) / `text/html` on your
  app's data/API endpoints. Any failure = **RED** with the surface + signal named.
- A journey that can't be reached (login fails, route 404s, no `public_report_id`) = **UNREACHABLE →
  AMBER**, never an assumed pass.
- If a journey fails, escalate that one slug to full `/e2e-test` for DB validation + self-healing
  before concluding (avoids a flaky false RED).

## Phase 4 — DB connection-storm signature check (the P0 class)

The browser drive catches the user-visible `522`; this confirms the cause and catches a storm even on
a surface the diff didn't touch. Use your DB logs (e.g. `get_logs(service='postgres')`) over the recent
window and scan for the pool-exhaustion / runaway signature, e.g.:
- `53300` / "too many clients already" / "remaining connection slots are reserved" (pool exhaustion)
- a `statement timeout` flood (a runaway/herd scheduled job saturating the pool)

Optionally confirm pool headroom. **Surface only** — never pause/alter a scheduled job or restart the
DB here (that's an operator action). Present is **RED**; clear is a clean DB dimension.

## Phase 5 — Honest-coverage verdict

Fold the three dimensions per `references/honest-coverage-verdict.md`:
- **GREEN / READY** — zero UNMAPPED, every driven journey clean, DB-storm clear.
- **AMBER / PARTIAL** — driven journeys clean BUT coverage incomplete (UNMAPPED files, registry-only
  mapping caveat, or an UNREACHABLE journey). Name exactly what was not covered.
- **RED / REGRESSION** — any journey failed a universal assertion, or the DB-storm signature is present.
- **Never GREEN over partial/stale/absent coverage.** RED dominates.

Print the verdict block from the verdict reference (state, coverage line, per-journey results, DB-storm
line, WHY, and a surface-only PUNCH-LIST).

## Phase 6 — Surface, don't act

Emit the verdict + punch-list. Do not mutate prod, auto-fix, or merge. If the operator wants a fix, that
is a separate authorised action.

## Self-test
```bash
bash .claude/skills/production-readiness-review/scripts/map-diff-to-surfaces.sh --self-test
```
Proves the mapper's classification contract (mapped/exempt/unmapped + journey set + the never-silent-
green PARTIAL hint) on a known file list. Exercises the GENERIC skeleton rules — keep the fixture in
sync when you customise `surface-map.md`.

## Composition map (what this skill leans on — do NOT reimplement)
| Need | Composed from |
|---|---|
| Browser drive (CDP, auth, snapshot, console, network) | `.claude/skills/e2e-quick/SKILL.md` (+ `/e2e-test` for escalation) |
| Deterministic browser fallback | your project's `playwright.config.ts` + `tests/e2e/*.spec.ts` (`npx playwright test --grep "@smoke"`) |
| DB-storm signal | your DB logs (e.g. `get_logs(service='postgres')` MCP) |
| Deploy/file drift (adjacent, optional pre-step) | `.claude/skills/verify-shipped/` |
| Honest-degradation doctrine | `.claude/rules/system-awareness-mandate.md` (cited, not copied) |
| Live-smoke discipline | your project's partner-/user-facing live-smoke rule (cite it; don't copy) |
| Operator smoke creds | your project's smoke-creds reference / env |

## Future (out of scope for v1 — deferred follow-ons)
- Wire as an autovibe post-ship phase so every clean `/ship` auto-runs it — only after this is
  proven against a seeded regression in your project.
- Replace the registry with a live topology walk once a topology map is built.
