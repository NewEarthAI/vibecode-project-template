# Loading-State Invariants

**Scoped**: any code that affects how data appears (or fails to appear) on user-facing surfaces — list queries, deploy config, query-cache configuration, error toast formatting, page-level Suspense boundaries.

**Auto-loaded via** `code-review-domain-routing.md` on: `vercel.json`, `vite.config.ts`, `src/App.tsx`, primary list-data hooks (`src/hooks/use*.ts` that drive list pages), any new `v_*` view migration, any new RPC migration with `SETOF` return type, any change to `pg_cron` jobs.

**Rule class**: loading/perf failures are **regressions**, in the same regression class as any explicit invariant file. Originating user statement (2026-04-25 incident): *"whatever steps we've put into place to prevent regression should be ensuring nothing we do to the live site causes these dumb loading issues."*

---

## The Six Invariants

### 1. Hashed assets MUST have `immutable` cache headers
Vite produces content-hashed chunk filenames (`index-AbC123.js`). The hash IS the cache key — the file is immutable by definition. `Cache-Control: public, max-age=31536000, immutable` for `/assets/(.*)` in `vercel.json`. HTML must NOT be cached aggressively (it points to current chunk hashes).

**CI gate**: post-deploy `curl -sI <preview>/assets/<chunk>.js | grep -i cache-control` must contain `immutable`. Failing this = blocking PR check.

**Failure precedent**: 2026-04-25 — every hashed chunk served `max-age=0, must-revalidate` because `vercel.json` had no `/assets/**` rule. Every navigation forced a conditional GET. Fix recipe in `.claude/skills/deploy-vercel/references/vercel.json.template`.

### 2. Wide views MUST NOT be the LIST surface
A view that has any of:
- > 50 columns
- COALESCE chains across multiple joined tables
- LATERAL subqueries or correlated aggregates
- Sits on a base table with > 5 RLS policies

is acceptable for **single-row detail** queries (`/v_<wide_view>?id=eq.X`) but BANNED as the source for **list/aggregation** surfaces. Use a base-table RPC instead — pattern: `get_<surface>_counts(filters jsonb) RETURNS TABLE (...)` reading from base tables only, with the necessary composite index on `(filter_col, ordered_col DESC)`.

**Code review BLOCKING** when a PR adds `.from('v_*')` for list/aggregation contexts. See `supabase-safety.md` "Wide-View Aggregation Anti-Pattern" (project-side) or this file's diagnostic order section for the recipe.

### 3. Statement timeouts on a user-facing surface are P0
Reaching the 8s `statement_timeout` ceiling = the page is un-usable for anyone whose data shape hits the slow path. There is no "we'll fix it next sprint." Every reported timeout requires an immediate canary investigation:

```sql
EXPLAIN (ANALYZE, TIMING ON) <the failing query>;
SELECT relname, last_analyze, last_autoanalyze, n_mod_since_analyze
FROM pg_stat_user_tables WHERE relname IN ('<involved tables>');
```

If `last_autoanalyze IS NULL` on any involved table, run `ANALYZE` immediately. This single command resolved the 2026-04-25 incident (27s → 54ms). Schedule periodic ANALYZE if autovacuum's defaults aren't catching the access pattern.

**Failure precedent (originating incident, 2026-04-25)**: a hot list table had `last_autoanalyze = NULL` since creation. List query → 27s timeout. Fixed by an explicit `analyze_list_tables()` RPC + daily pg_cron job + hourly canary with self-heal (canary runs the LIST query shape, classifies severity, runs `ANALYZE` inline on red). Reference template: `.claude/skills/deploy-vercel/references/list-canary-self-healing.sql.template`.

### 4. Error toasts must be human-readable
The `QueryCache.onError` handler MUST produce a user-facing message that:
- Filters out non-string queryKey parts (no `[object Object]`)
- Uses `extractErrorMessage()` from `@/lib/observability` for the error body
- Preserves full structured key in Sentry tags (developer fidelity is independent of user fidelity)

The pattern at `QueryClient` instantiation (`src/App.tsx`) is canonical: filter the queryKey to string parts only, format `{key}: {message}`. New caches added elsewhere must mirror it.

**Failure precedent**: 2026-04-25 — toast read `Data load failed: propertyEnriched/[object Object]: canceling statement due to statement timeout`. The `[object Object]` was a JSON-shaped queryKey segment that got coerced via raw `String()`. Filter the queryKey to string parts before joining.

### 5. Page navigation must feel instant when chunks are cached
Spinner on cached-chunk navigation = regression. The architecture is:
- Single global `<Suspense fallback={<PageLoader />}>` wrapping `<Routes>` (in `src/App.tsx`)
- Every route lazy-loaded via `lazy(() => import('./pages/X'))`
- React Query global `staleTime: 2min, refetchOnWindowFocus: false`

Per-route Suspense boundaries are BANNED — they spawn the spinner more often, not less. Eager imports are BANNED — they regress initial bundle size.

If a spinner appears on back-nav, the fix is at the **AuthProvider remount** layer (`src/hooks/useAuth.tsx` or equivalent), NOT at the cache or Suspense layer. AuthProvider re-rendering invalidates the entire React tree under it; stabilize the Provider value via `useMemo`.

### 6. `staleTime: 0` overrides require a justifying comment
Every `useQuery({ staleTime: 0 })` or `refetchOnMount: 'always'` override of the global 2-minute default needs an inline comment stating why the data is genuinely volatile per-mount (e.g., live counts widget, post-mutation refetch, real-time subscription that already invalidates).

**Code review BLOCKING** for unjustified overrides. The default is "inherit the global" and the override is the exception that needs proof.

---

## Regression-Prevention Surfaces

| Surface | Catches | Where |
|---|---|---|
| `daily-analyze-list-tables` pg_cron | Stale planner stats on hot tables | recipe in `.claude/skills/deploy-vercel/references/list-canary-self-healing.sql.template` |
| `list-canary-hourly` pg_cron | LIST query > 5s with self-heal via ANALYZE | same recipe |
| Canary log table (project-defined `*_etl_events` or equivalent) | Trend visibility on LIST query latency | log queryable; downstream alerting subscribes to severity ≠ green |
| Vercel `/assets/**` `immutable` header | Hashed-chunk cache regression | `vercel.json` (template at `.claude/skills/deploy-vercel/references/vercel.json.template`) |
| `extractErrorMessage` + queryKey filter | `[object Object]` toast regression | `src/App.tsx` `QueryCache.onError` block |
| Code-review domain routing | This rule auto-loads on relevant PRs | `code-review-domain-routing.md` |
| Post-deploy smoke (`/ship` skill) | Build deployed but app broken at runtime | `.claude/skills/ship/scripts/smoke.sh` |
| Playwright `@smoke` | Page TTFB regression | project-specific test file |

---

## Diagnostic Order (when "Couldn't load data" appears)

1. **Check the canary log first** — `SELECT event_data FROM <your_etl_events_table> WHERE event_type LIKE '%LIST_CANARY%' ORDER BY created_at DESC LIMIT 5;` — gives you the recent latency trend without firing another query.
2. **Check planner stats** — `SELECT relname, last_autoanalyze, n_mod_since_analyze FROM pg_stat_user_tables WHERE relname IN ('<your hot list tables>');`. NULL or > 24h old = run ANALYZE immediately.
3. **Check Vercel/PostgREST cache** — `curl -sI` the failing endpoint. If 5xx persists past one cache TTL window, escalate to Supabase or Vercel logs.
4. **Check the user's auth context** — `params.orgId` and `params.userRole` must resolve correctly. Empty list with no error in console = an `org_id IS NULL` filter dropping rows the user expects to see.

Do NOT skip 1-2 in favor of "let me look at the React code." The user-visible loading surface is fed by a database query; the React code is downstream of the DB. Diagnosing top-down (UI → React → query → DB) wastes 90% of cases where the answer is at the DB.

---

## Failure Precedents (originating project)

- **2026-04-25** — List page 27s timeout → counts/UI showed 0. Root cause: hot list table `last_autoanalyze = NULL` since creation. Fix: explicit ANALYZE function + daily cron + canary with self-heal. Hashed-chunk cache regression and `[object Object]` toast regression diagnosed in same incident.
- **2026-04-23** — Counts RPC over a wide view took 51,571ms; replaced by base-table RPC + composite index. 325× speedup. Established the "wide view as LIST source = anti-pattern" doctrine.
- **2026-04-19** — Fiber-vs-DOM divergence (sibling-key collision in interactive lists). Different class but same regression principle: loading-state surface drift caught by user, not CI.
