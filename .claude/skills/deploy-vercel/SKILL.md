---
name: deploy-vercel
description: |
  Make Vercel deploys reliable in under an hour. Covers both first-time SETUP
  (vercel.json, env vars, build config, DB readiness, cron canaries) and
  per-deploy GATES (build → commit → push → preview-check → smoke). Use when:
  "set up Vercel for this project", "make deploys reliable", "speed up the
  site", "prevent deploy regressions", "deploy", "push to prod", "go live",
  "ship it", or when completing work that should reach production.

  Two modes:
    1. SETUP (one-time per project) — sections 1-4 below. Goal: a fresh project
       reliably deploying to prod within an hour, with anti-regression machinery
       in place from day one.
    2. DEPLOY (every change) — section 5 manual gate checklist. For autonomous
       end-to-end deploy, prefer the `/ship` skill which composes this skill
       + CI watch + admin-merge heuristic + rollback.

  Composes with: ship (autonomous deploy orchestrator), loading-state-invariants
  rule (regression class), supabase-postgres-best-practices (DB-side performance).
classification: encoded-preference
version: 3.0
created: 2026-04-07
updated: 2026-04-26
triggers:
  - "deploy" / "push to prod" / "go live" / "ship it"
  - "set up vercel" / "configure vercel" / "vercel setup" / "vercel init"
  - "make deploys reliable" / "prevent deploy regressions" / "deploy is slow"
  - "speed up the site" / "page is slow on prod" / "site is slow"
  - "loading spinner regression" / "back nav spinner" / "white flash"
  - "vercel.json" / "cache headers" / "immutable"
do-not-trigger:
  - "deep performance diagnosis on a slow page" → use site-speed-boost skill
  - "autonomous full deploy with rollback + smoke" → use ship skill
  - "n8n deploy" → not applicable
---

# Deploy to Production (Vercel)

**Architecture (target):** PR branches → preview deploy (auto via Git integration). Merge to main → production deploy (auto). Hashed assets cached `immutable`. DB-side canary self-heals planner-stats regressions inside one hour. Smoke runs post-deploy with auto-rollback on failure (via `/ship`).

**Why this skill exists**: deploys regress in three ways the v2.0 checklist did not catch:
1. **Cache regressions** that nuke perceived speed (no `immutable` rule on hashed assets → every navigation is a conditional GET — see [loading-state-invariants.md](../../rules/loading-state-invariants.md) Invariant 1).
2. **DB-side regressions** invisible to Vercel (stale planner stats produce 27s+ list timeouts; deploy is fine, app is broken — see Invariant 3).
3. **Build green ≠ runtime healthy** (Vite/esbuild strip types without checking; tests pass but app crashes on first user click — see [typecheck-and-review-gates.md](../../rules/typecheck-and-review-gates.md)).

This skill fixes all three at the SETUP layer so the per-deploy gate stays simple.

---

## 1. Setup — `vercel.json` (Speed + Security From Day One)

Drop the template at [references/vercel.json.template](references/vercel.json.template) into the repo root, no edits needed for any React/Vite/Next-static project. It bundles:

| Concern | Rule | Why |
|---|---|---|
| Cache | `/assets/(.*)` → `Cache-Control: public, max-age=31536000, immutable` | Hashed filenames are immutable by definition. Without this rule perceived speed dies on back-nav. |
| Cache | `/(.*)` (HTML) → no aggressive cache | HTML must revalidate to pick up new chunk hashes after deploys. |
| Security | HSTS, X-Frame-Options DENY, X-Content-Type-Options nosniff, Referrer-Policy strict-origin, Permissions-Policy locked, X-DNS-Prefetch-Control on | Defense-in-depth + clean Lighthouse security score. |
| Routing | SPA rewrite with negative-lookahead on `/assets/` | Without the lookahead, requests for hashed assets rewrite to `/index.html` and serve HTML where JS was expected → console errors. |

**Verification (post-deploy):**
```bash
curl -sI https://<your-domain>/assets/<any-chunk>.js | grep -i cache-control
# MUST contain: max-age=31536000, immutable

curl -sI https://<your-domain>/ | grep -iE "strict-transport|x-frame"
# MUST list both
```

If either fails, `vercel.json` did not pick up — re-deploy or check Vercel build log for parse errors.

---

## 2. Setup — Build Config (Type Safety + No Silent Drift)

Vite/esbuild/SWC **strip TypeScript types without checking them**. `npm run build` alone is NOT a typecheck on this stack. Add a separate `typecheck` script and wire it into CI:

```json
// package.json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "typecheck": "tsc --noEmit -p tsconfig.app.json",
    "lint": "eslint .",
    "test": "vitest run",
    "preview": "vite preview"
  }
}
```

**Hard rule** — never run bare `npx tsc --noEmit` on a Vite project with project references; the root `tsconfig.json` typically has `"files": []` and the bare command is a silent no-op (returns exit 0 always). The `-p tsconfig.app.json` form is required. See [typecheck-and-review-gates.md](../../rules/typecheck-and-review-gates.md) for the 5-PR-deep silent-bug precedent.

**CI gate:** `npm run typecheck` must exit 0 on every PR before merge. See [zero-regression infrastructure](#4-setup--zero-regression-infrastructure-ci--smoke) below.

---

## 3. Setup — DB Readiness (Prevent the 27s Timeout Class)

The most common Stage-1 production fire is not a Vercel issue — it's a Supabase/Postgres issue invisible to Vercel: planner stats go stale, the planner picks a brutal join plan, and a list query that ran in 50ms yesterday runs 27,000ms today and trips `statement_timeout`. App appears broken; deploy is fine.

**Install the self-healing canary at project bootstrap.** Drop [references/list-canary-self-healing.sql.template](references/list-canary-self-healing.sql.template) into a migration, replace the four `{{...}}` placeholders, and apply. Once installed it provides:

| Mechanism | What | When |
|---|---|---|
| `analyze_list_tables()` RPC | Explicit ANALYZE on hot tables, audit-logged | Daily 02:30 UTC via pg_cron |
| `list_canary_check()` RPC | Times the LIST query, classifies severity, **runs ANALYZE inline if red** | Hourly :17 via pg_cron |
| Audit-log entries | Trend visibility on LIST latency | Every canary run + every ANALYZE |
| Telegram/Slack alert on orange/red | Loud failure surface | Every red event (post-self-heal) |

**Max time to recovery: 60 minutes.** If a sluggish autovacuum or a write-spike re-stales stats, the next hourly canary catches it and self-heals before the first user-visible timeout.

**Read [loading-state-invariants.md](../../rules/loading-state-invariants.md) before any change to `vercel.json`, `vite.config.ts`, `src/App.tsx`, or list-data hooks** — this rule is auto-loaded by code-review domain routing.

---

## 4. Setup — Zero-Regression Infrastructure (CI + Smoke)

Three GitHub Actions / Vercel integration pieces, set once per project:

### 4a. CI gate (`check` job)
Runs on every PR + `merge_group`. Must pass before merge:
- `npm run lint`
- `npm run typecheck` (the real one — see Section 2)
- `npm run test`

Mark `typecheck` as a **REQUIRED** status check in branch protection. Admin-merge bypassing typecheck is **prohibited** — typecheck is deterministic, not a flake. See [typecheck-and-review-gates.md](../../rules/typecheck-and-review-gates.md) "Admin-Merge Policy".

### 4b. Playwright smoke (`@smoke` tag)
Triggered by Vercel preview `deployment_status` event. Hits the preview URL with a minimal "page loads, key element renders" test per surface. Cold-preview tolerant (`expect 15s, test 45s, navigation 30s`). Chromium-only on CI.

### 4c. Post-deploy smoke (via `/ship` skill)
After production deploy, the `/ship` skill runs `scripts/smoke.sh`:
- Pre-checks `vercel whoami` to disambiguate auth from app errors
- Hits production URL, verifies HTTP 200
- Verifies `x-vercel-git-commit-sha` header matches the SHA you just deployed (catches "Vercel served stale build" class)
- 3× retry with 10s backoff against cold cache
- On failure: auto-rollback (`vercel rollback`)

**For autonomous deploys, use `/ship pr` — it composes all three.** This skill's manual gates (Section 5) are the fallback for when you want eyes on each step.

---

## 5. Deploy Gates (Manual Per-Change Checklist)

For autonomous end-to-end deploys, use `/ship`. For manual deploys with eyes on each step, execute these gates in order, no skipping.

### Gate 1: Build + Typecheck Pass
```bash
npm run typecheck && npm run build
```
**HARD STOP if either fails.** Fix errors before proceeding. If the user says "just push it" without verification, run both first anyway.

### Gate 2: Commit Changes
- Stage only relevant files (`git add <specific files>` — never `git add .`)
- Commit with descriptive message
- Verify with `git status` — no untracked files that should be included

### Gate 3: Push to Feature Branch
```bash
BRANCH=$(git branch --show-current)
[ "$BRANCH" = "main" ] && { echo "ABORT: cannot push to main directly"; exit 1; }
git push origin "$BRANCH"
```
- **NEVER push directly to main** — always use a PR branch
- If no PR exists yet: `gh pr create --title "..." --body "..."`
- If PR exists, push updates it automatically

### Gate 4: Preview Verification
After push, Vercel auto-builds a preview deploy (~90 seconds):
```bash
sleep 5 && gh pr checks <number> --json name,link,state \
  --jq '.[] | select(.name == "Vercel") | .link'
```
Open the URL. **Smoke-test the actual changed surface** in a real browser before declaring ready. Static verdicts (build green, CI green) are advisory; runtime verdicts are authoritative.

### Gate 5: CI Green
```bash
gh pr checks <number>
```
- `check` (lint+typecheck+test) MUST be SUCCESS
- `Vercel` MUST be SUCCESS
- `playwright` MAY be FAILURE in narrow cases (chronic flake on the project) — see admin-merge heuristic in `/ship`'s `modes/pr.md`

### Gate 6: Merge → Production
```bash
gh pr merge <number> --squash --delete-branch
```
Production deploy auto-triggers. Watch with:
```bash
gh run watch
```

### Gate 7: Post-Deploy Smoke
```bash
SHA=$(git rev-parse HEAD)
curl -sI https://<your-domain>/ | grep -i x-vercel-git-commit-sha
# MUST contain the SHA you just merged

curl -sI https://<your-domain>/assets/<any-chunk>.js | grep -i cache-control
# MUST contain immutable
```

If either fails, rollback:
```bash
vercel rollback
```

---

## 6. The 1-Hour Reliable Deploy Checklist (For New Projects)

Goal: from `git init` to "production deploys reliably with anti-regression machinery" in under 60 minutes.

| Minute | Step |
|---|---|
| 0-5 | `vercel link` to project; copy `references/vercel.json.template` to repo root |
| 5-10 | Add `typecheck` script to `package.json`; verify `npm run typecheck` exits 0 |
| 10-20 | Apply `references/list-canary-self-healing.sql.template` migration with placeholders filled (skip if no Supabase) |
| 20-30 | Drop `.github/workflows/ci.yml` (lint+typecheck+test) and `.github/workflows/e2e.yml` (Playwright on Vercel preview) — both shipped as part of this template |
| 30-35 | Set `typecheck` as REQUIRED status check in branch protection on `main` |
| 35-40 | First test PR: tiny change → push → verify Vercel preview deploys, all three CI checks fire |
| 40-50 | Wire env vars in Vercel dashboard (Production + Preview + Development scopes); verify build picks them up via preview URL |
| 50-60 | Merge first PR. Run Gate 7 verification on production. Confirm both headers present. **Reliable deploy machinery installed.** |

If any minute marker slips by >2x, the template has rotted in a way that needs investigation — open an issue. Every step is a simple file copy or two-line config; if it's not, something has changed upstream.

---

## 7. Anti-Patterns (Do Not Ship)

| Wrong | Why | Right |
|---|---|---|
| Bare `npx tsc --noEmit` as typecheck | No-op on Vite project-references — exit 0 always | `tsc --noEmit -p tsconfig.app.json` via `npm run typecheck` |
| `vercel.json` with no `/assets/**` immutable rule | Every chunk served `must-revalidate`; back-nav spinner | Use the template, keep the rule |
| Per-route `<Suspense>` | Spawns spinner more often, not less | Single global Suspense at `<Routes>` |
| `staleTime: 0` everywhere | Refetch storm on focus/mount; needless DB load | Inherit global `staleTime: 2min`; override only with justifying comment |
| Trusting "build passes" as runtime-healthy | Vite strips types without checking; lints don't run on prod build | Typecheck + Playwright smoke on preview |
| Admin-merge with `typecheck` red | Typecheck is deterministic, not a flake | Fix the type error first — always |
| Ignoring DB-side perf in deploy planning | Stale planner stats produce silent 27s timeouts invisible to Vercel | Install the canary self-healing migration day one |
| Direct push to `main` | No preview, no smoke, no rollback path | PR branch always, even for "tiny fixes" |

---

## 8. Composition

| With this | …deploy-vercel does |
|---|---|
| `/ship` skill | Provides the SETUP foundation; `/ship` provides the per-deploy ORCHESTRATION (gates 1-7 automated + admin-merge heuristic + rollback) |
| `loading-state-invariants` rule | This skill installs the machinery; the rule documents the invariants that the machinery enforces |
| `supabase-postgres-best-practices` skill | DB-side perf rules; this skill installs the cron+canary that catches violations of those rules in production |
| `site-speed-boost` skill | Reactive (when a slow page is reported); this skill is preventive (canary catches regressions before they're noticed) |

---

## Reference Files

| File | Purpose |
|---|---|
| [references/vercel.json.template](references/vercel.json.template) | Drop-in `vercel.json` with immutable assets + security headers + SPA rewrite |
| [references/list-canary-self-healing.sql.template](references/list-canary-self-healing.sql.template) | DB-side migration — explicit ANALYZE + hourly canary + self-heal + alert. Replace 4 placeholders. |

---

## Failure Precedents (Originating Project)

- **2026-04-25** — List page 27s timeout in production. Pipeline un-loadable. Root cause: hot table's `last_autoanalyze = NULL` since creation. Manual ANALYZE → 27,659ms → 54ms (511× speedup). Self-healing canary shipped in same incident — prevents recurrence forever. Hashed-chunk cache regression (no `immutable` rule) and `[object Object]` toast regression caught in same incident.
- **2026-04-20** — 5 consecutive PRs (#168-172) shipped a scope bug undetected because bare `npx tsc --noEmit` was a silent no-op. Real `tsc -p tsconfig.app.json` surfaced 15+ pre-existing latent errors when finally run.
- **2026-04-19** — Manual `vercel --prod` deploy without smoke shipped a build that 404'd on the homepage. `/ship` skill built in response with mandatory smoke + auto-rollback. This skill's v3.0 SETUP sections are the missing prevention layer that v2.0 didn't have.
