---
name: site-speed-boost
description: |
  Systematic performance diagnosis and optimization for React + Supabase + Vercel apps.
  Use when: "site is slow", "page takes forever", "speed up", "optimize performance",
  "loading spinner too long", "white flash", "pipeline slow", or any page-level perf complaint.
  Runs a 6-phase diagnostic: browser measurement → network waterfall → database EXPLAIN →
  targeted fixes (indexes, views, query consolidation, React Query tuning) → deploy → verify.
  NOT for: CSS animations, bundle size, lighthouse scores, or SEO performance.
version: 1.0
classification: capability-uplift
created: 2026-04-08
validated_on:
  - Pipeline page 3,557 rows (2,397ms → 585ms DB, 6.3s → 2.7s browser)
  - Stats hook full-table scan elimination
  - 8 parallel Supabase requests → 3 via RPC consolidation
parameters:
  - name: target_url
    type: string
    default: production URL from CLAUDE.md
  - name: db_tool
    type: string
    default: mcp__supabase-{project}__execute_sql
  - name: slow_page_route
    type: string
    default: detected from user complaint
---

# Site Speed Boost — Performance Diagnosis & Optimization

> **Philosophy:** Measure first. Fix what the data shows, not what theory suggests.
> Hypotheses are wrong ~50% of the time. EXPLAIN ANALYZE is right 100% of the time.

---

## When to Use

- User reports a page "takes ages" or "shows a spinner"
- White flash / loading skeleton visible during navigation or filter changes
- Browser tab return triggers a full refetch
- Any page backed by Supabase views with >1,000 rows

## When NOT to Use

- Bundle size optimization (use Vite chunking / code splitting)
- Lighthouse audit (use `/audit-website`)
- CSS animation jank (use Chrome DevTools Performance tab)
- SEO / Core Web Vitals (different domain entirely)

---

## Phase 1: Measure (NEVER skip)

**Every optimization starts with a number.** Without a baseline, you cannot prove improvement.

### 1A. Browser-Side Timing

Navigate to the slow page with Playwright MCP or agent-browser. After data loads:

```javascript
// Inject via browser_evaluate or agent-browser eval
() => {
  const entries = performance.getEntriesByType('resource')
    .filter(e => e.name.includes('supabase') || e.name.includes('/api/'))
    .map(e => ({
      url: e.name.split('?')[0].split('/').pop(),
      query: (e.name.split('?')[1] || '').substring(0, 80),
      duration: Math.round(e.duration),
      size: e.transferSize
    }))
    .sort((a, b) => b.duration - a.duration);
  return { total_requests: entries.length, entries };
}
```

**Record:**
- Number of API requests fired on page load
- Duration of each request (ms)
- Transfer size per request
- Which endpoints/views are hit

### 1B. Database-Side Timing

For each slow Supabase request identified in 1A, run EXPLAIN ANALYZE:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT {{columns_from_frontend_query}}
FROM {{view_or_table}}
{{WHERE_clauses_from_frontend}}
ORDER BY {{sort_column}} {{direction}}
LIMIT {{limit_from_frontend}};
```

**CRITICAL RULES:**
- Use the EXACT query the frontend fires (copy from network tab)
- Never guess which query is slow — measure ALL of them
- Record Planning Time + Execution Time separately
- Look for `Seq Scan` nodes — these are your targets

### 1C. Check Existing Indexes

Before hypothesizing missing indexes, CHECK:

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = '{{table_name}}'
ORDER BY indexname;
```

**The #1 mistake in performance work is creating indexes that already exist.**

### 1D. Baseline Summary

Create a markdown table:

```markdown
| Query | Duration (DB) | Duration (Browser) | Rows | View |
|-------|--------------|-------------------|------|------|
| {{query}} | {{ms}} | {{ms}} | {{n}} | {{view}} |
```

---

## Phase 2: Diagnose

Map each slow query to its bottleneck category:

### Database Bottlenecks

| EXPLAIN Node | Problem | Fix |
|-------------|---------|-----|
| `Seq Scan` on ORDER BY column | Missing index for sort | `CREATE INDEX CONCURRENTLY ON table(column DESC)` |
| `Seq Scan` on WHERE column | Missing filter index | `CREATE INDEX CONCURRENTLY ON table(column)` |
| `Nested Loop` with high loop count | LATERAL per-row scan | Check inner scan uses index; if not, add one |
| `Hash Join` on full table | CTE pre-aggregates all rows | Switch to LATERAL + index if query uses LIMIT |
| High `Planning Time` (>100ms) | View too complex | Create lightweight view with fewer columns |

### Network/API Bottlenecks

| Pattern | Problem | Fix |
|---------|---------|-----|
| 5+ parallel Supabase requests | Connection pool contention | Consolidate into RPC |
| Same view hit by list + stats + counts | View LATERALs evaluated N times | Create lightweight view for non-detail queries |
| `SELECT *` on wide view | Unnecessary column transfer | Explicit column projection or lightweight view |
| `head: true` count on complex view | Full view evaluated for count | Move counts to RPC or materialized counter |

### React Query Bottlenecks

| Symptom | Problem | Fix |
|---------|---------|-----|
| White flash on filter change | No `keepPreviousData` | Add `placeholderData: keepPreviousData` |
| Spinner on tab return | `refetchOnWindowFocus: true` | Set `refetchOnWindowFocus: false` |
| Data refetches every mount | `staleTime` too low | Bump `staleTime` (30s for counts, 60s for stats) |
| Stale data after mutation | Wrong cache key invalidated | Centralize query keys as named constants |
| Cache corruption after realtime event | Optimistic merge with raw table payload | Replace `setQueryData` with `invalidateQueries` |
| Refetch storm from batch writes | Realtime fires per-row | Add debounce (2s) on realtime handler |

---

## Phase 3: Fix (Dependency Order)

Apply fixes in this order — each layer compounds on the previous:

### Layer 1: Database (highest leverage, lowest risk)

**3A. Indexes** (reversible — can drop instantly)

```sql
-- Always CONCURRENTLY on production tables
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_{{table}}_{{column}}
  ON {{table}} ({{column}} DESC);

-- Verify it was used
EXPLAIN (ANALYZE) SELECT ... FROM {{view}} ORDER BY {{column}} DESC LIMIT 500;
-- Look for: Index Scan using idx_{{table}}_{{column}}

-- Verify it's valid (CONCURRENTLY can leave invalid indexes)
SELECT indexname, indisvalid
FROM pg_indexes i
JOIN pg_class c ON c.relname = i.indexname
JOIN pg_index pi ON pi.indexrelid = c.oid
WHERE i.tablename = '{{table}}' AND i.indexname = '{{index_name}}';
```

**3B. Lightweight View** (when main view has >100 columns)

Create a projection view with ONLY the columns needed for list display:

```sql
CREATE OR REPLACE VIEW {{view}}_list AS
SELECT
  -- Identity columns (always needed)
  -- Filter columns (ALL fields referenced by client-side filters)
  -- Display columns (all DataTable accessorKeys + row.original fields)
  -- Computed columns (same formulas as full view)
  -- Aggregate columns (same LATERAL strategy — NOT CTEs)
FROM {{base_table}} e
LEFT JOIN {{parsed_table}} p ON p.id = e.property_id
-- Same LATERALs as full view — fewer output columns
```

**CRITICAL DESIGN DECISIONS:**

| Decision | Right | Wrong | Why |
|----------|-------|-------|-----|
| Aggregation strategy with LIMIT | LATERAL + index | CTE pre-aggregate | CTEs scan ALL rows before LIMIT can apply. LATERALs stop after LIMIT rows. Measured: CTE=2,074ms vs LATERAL=524ms |
| Column for non-detail queries | Lightweight view | Full view with column subset | PostgreSQL evaluates ALL LATERALs regardless of selected columns |
| Zero-match rows | `LEFT JOIN` + `COALESCE(x, 0)` | `INNER JOIN` (drops rows) | `applyFilters` treats NULL and 0 differently |
| Original view | Leave UNTOUCHED | Modify in place | Edge functions, RPCs, other consumers depend on it |

**Column Audit Checklist** (must include ALL of these):

```
□ All DataTable accessorKey values (~75 fields)
□ All row.original.* fields accessed in cell renderers
□ All client-side filter field IDs (SELLER_PIPELINE_FILTERS or equivalent)
□ All server-side filter columns (deal_type, portfolio_id, submitter_user_id, etc.)
□ All columns used in computed pipeline status CASE expressions
□ Pipeline control columns (deal_status, enrichment_status, etc.)
```

**Row-Count Validation** (mandatory before switching frontend):

```sql
SELECT
  (SELECT COUNT(*) FROM {{full_view}}) AS full_count,
  (SELECT COUNT(*) FROM {{list_view}}) AS list_count;
-- Must be equal. If not, a JOIN is wrong (INNER instead of LEFT).
```

**3C. Consolidate Count Queries into RPC**

When the frontend fires N parallel count queries, replace with one RPC:

```sql
CREATE OR REPLACE FUNCTION get_{{domain}}_counts(
  p_user_role TEXT DEFAULT 'admin',
  p_user_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE sql STABLE
AS $$
  SELECT json_build_object(
    'count_a', COUNT(*) FILTER (WHERE {{condition_a}}),
    'count_b', COUNT(*) FILTER (WHERE {{condition_b}}),
    'count_c', COUNT(*) FILTER (WHERE {{condition_c}})
  )
  FROM {{lightweight_view}}
  WHERE CASE WHEN p_user_role = 'seller' THEN submitter_user_id = p_user_id ELSE true END
$$;
```

### Layer 2: React Query (immediate UX wins)

**3D. Query Key Constants**

```typescript
// Define in ONE file, import everywhere
export const QUERY_KEYS = {
  list: 'entityList',
  detail: 'entityDetail',
  stats: 'entityStats',
  counts: 'entityCounts',
} as const;
```

Then grep ALL `invalidateQueries`, `setQueryData`, `getQueryData`, `cancelQueries` calls across the codebase. Every string literal must reference the constants. This prevents the silent failure where renaming a query key in the hook doesn't propagate to mutation handlers in other files.

**3E. Cache Configuration**

```typescript
// Main list query
useQuery({
  queryKey: [QUERY_KEYS.list, filters],
  placeholderData: keepPreviousData,  // No white flash
  queryFn: ...
});

// Stats/aggregate query
useQuery({
  queryKey: [QUERY_KEYS.stats],
  staleTime: 60_000,  // 1 min — stats don't need real-time
  queryFn: ...
});

// Global config
new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 2 * 60 * 1000,      // 2 min default
      gcTime: 10 * 60 * 1000,         // 10 min cache retention
      refetchOnWindowFocus: false,     // Realtime handles freshness
      retry: 1,
    },
  },
});
```

**3F. Fix Realtime Handlers**

The #1 silent bug in Supabase realtime subscriptions:

```typescript
// WRONG — payload.new is raw table data, missing view-computed columns
.on('postgres_changes', { event: 'UPDATE', table: '{{table}}' }, (payload) => {
  queryClient.setQueryData([QUERY_KEYS.list, filters], (old) =>
    old.map(item => item.id === payload.new.id ? (payload.new as Entity) : item)
  );
});

// RIGHT — invalidate and let React Query refetch from the view
.on('postgres_changes', { event: 'UPDATE', table: '{{table}}' }, () => {
  queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.list] });
});
```

**Why invalidate over merge:** Raw table payloads lack computed columns (ARV cascades, yield calculations, MAO tiers, match counts). Optimistic merge silently replaces computed values with `undefined`.

**3G. Debounce Batch Realtime Events**

```typescript
// Batch operations (e.g., buyer matching) insert 50+ rows at once.
// Without debounce, each INSERT fires invalidateQueries → refetch storm.
let debounceTimer: ReturnType<typeof setTimeout>;
supabase.channel('related_table_changes')
  .on('postgres_changes', { event: '*', table: '{{related_table}}' }, () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.list] });
    }, 2000);  // 2-second debounce
  })
  .subscribe();
```

### Layer 3: Rendering (defer unless measured)

Only apply after Layers 1-2 are verified:

**3H. View Preservation** (for multi-view pages)

| View Type | Has Virtualizer? | Strategy |
|-----------|-----------------|----------|
| DataTable (TanStack Virtual) | Yes | Conditional render + scroll save/restore to ref |
| Card grid / Kanban / Gallery | No | CSS hiding: `visibility:hidden; height:0; overflow:hidden; position:absolute` |

**Before CSS-hiding any component:** audit it for active subscriptions, WebSocket channels, or DnD kit listeners. Hidden components with active subscriptions waste resources and can exhaust Supabase Realtime channel limits.

**3I. Drawer Instant-Hydrate from List Cache**

The highest-leverage UX optimization: seed detail queries with data already in the list cache. The drawer opens instantly — full data loads in the background.

```typescript
export function useEntityById(id: string | null) {
  const queryClient = useQueryClient();

  return useQuery({
    queryKey: [QUERY_KEYS.detail, id],
    queryFn: () => fetchFullDetail(id),
    enabled: !!id,
    // initialData is always treated as stale — React Query refetches in background
    initialData: () => {
      if (!id) return undefined;
      const allListData = queryClient.getQueriesData<Entity[]>({
        queryKey: [QUERY_KEYS.list],
      });
      for (const [, data] of allListData) {
        const match = data?.find((item) => item.id === id);
        if (match) return match;
      }
      return undefined;
    },
  });
}
```

**Why `initialData` not `setQueryData`**: `initialData` is always treated as stale — React Query will always refetch the full detail in the background. `setQueryData` with staleTime > 0 would prevent the refetch, leaving the drawer with partial list-level data permanently.

**3J. Stats Hooks — COUNT Not Full-Row Fetch**

Stats hooks that fetch all rows to count client-side are a hidden bottleneck. Replace with server-side COUNT queries:

```typescript
// WRONG — fetches ALL rows, counts in JS
const { data } = await supabase.from('matches').select('status').eq('buyer_id', id);
const stats = { new: 0, reviewing: 0 };
data?.forEach(m => { if (m.status === 'New') stats.new++; });

// RIGHT — 4 parallel counts, zero row transfer
const buildCount = (statuses: string[]) =>
  supabase.from('matches')
    .select('id', { count: 'exact', head: true })
    .eq('buyer_id', id)
    .in('status', statuses);

const [newRes, reviewRes] = await Promise.all([
  buildCount(['New']),
  buildCount(['Reviewing']),
]);
return { new: newRes.count ?? 0, reviewing: reviewRes.count ?? 0 };
```

**3K. Sequential Query Chains — Identify and Consolidate**

The dashboard pattern: query 1 fetches matches, query 2 backfills enriched data using IDs from query 1. This serializes two full round-trips.

Diagnostic: check for `await query1; const ids = results.map(...); await query2.in('id', ids)` patterns.

Fixes (in order of effort):
1. **Denormalize at write time** — add needed fields to the match table when matches are created (n8n workflow change)
2. **Create a JOIN view** — `v_buyer_matches` that joins matches + enriched server-side
3. **Create an RPC** — single function returns the shaped data the client needs

---

## Phase 4: Deploy & Verify

### 4A. Build Check

```bash
npx tsc --noEmit  # Zero type errors
npm run build     # Zero build errors
```

### 4B. Deploy

```bash
vercel --prod --yes  # Vercel production deploy
```

### 4C. Measure Again (same method as Phase 1)

Navigate to the page, run the Performance API script, compare:

```markdown
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Supabase requests | {{n}} | {{n}} | {{diff}} |
| Slowest request | {{ms}} | {{ms}} | {{x}}x |
| Total wall time | {{ms}} | {{ms}} | {{x}}x |
```

### 4D. Verify Data Correctness

- Row counts match between full and lightweight views
- Filter fields all work (especially multi-selects that do `row[fieldId]`)
- Detail drawer still loads all columns
- Realtime updates propagate correctly
- Match counts refresh within debounce window

---

## Phase 5: Commit & Document

Commit with performance metrics in the message:

```
perf: {{what changed}} — {{before}}ms → {{after}}ms ({{x}}x faster)
```

---

## Anti-Patterns (Battle-Tested)

| Wrong | Why | Right |
|-------|-----|-------|
| Create indexes without EXPLAIN ANALYZE | Indexes may already exist; wrong column targeted | Always measure first |
| Replace LATERAL with CTE for LIMIT queries | CTE scans ALL rows before LIMIT applies (4x slower measured) | Keep LATERAL + add index on ORDER BY column |
| Select subset of columns from complex view | PostgreSQL evaluates ALL LATERALs regardless | Create lightweight view |
| Fire N parallel count queries | Each is a full Supabase REST round-trip (3-6s each) | Consolidate into single RPC |
| Optimistic merge realtime payload into view cache | Raw table data lacks computed columns → silent corruption | Use `invalidateQueries` instead |
| Create new query key as string literal | Key rename in hook doesn't propagate to mutation handlers | Centralize as named constants |
| `staleTime: 0` with realtime subscription | Every subscription event triggers immediate refetch | `staleTime: 30_000+` with debounced subscription |
| CSS `display:none` on virtualizer container | `getBoundingClientRect` returns 0 → broken measurement | `visibility:hidden` + `height:0` |
| Skip row-count validation after view creation | INNER JOIN silently drops zero-match rows | Always `SELECT COUNT(*)` from both views |
| Bump global staleTime without adding realtime | Data goes stale with no refresh mechanism | Ship subscription atomically with staleTime bump |

---

## Decision Tree

```
User reports "page is slow"
  │
  ├─ Phase 1: Measure (browser + DB)
  │    └─ Where is the time?
  │         │
  │         ├─ DB query >500ms → Phase 2: Check EXPLAIN for Seq Scan → Add index
  │         │
  │         ├─ Network >2s but DB <500ms → Supabase REST overhead
  │         │    ├─ Multiple parallel requests? → Consolidate into RPC
  │         │    └─ Wide view? → Create lightweight view
  │         │
  │         ├─ Browser rendering >1s → React Query / rendering issue
  │         │    ├─ White flash? → Add keepPreviousData
  │         │    ├─ Refetch on every mount? → Bump staleTime
  │         │    └─ View switch rebuilds DOM? → CSS hiding or scroll save
  │         │
  │         └─ All layers fast but still feels slow → Perceived perf
  │              └─ Prefetch on hover, skeleton states, progressive loading
  │
  └─ Phase 4: Verify improvement with same measurement method
```

---

## Reference: Supabase-Specific Performance Rules

1. **Views evaluate fully** — PostgreSQL cannot skip LATERAL/CROSS JOIN even when output columns aren't selected
2. **`CREATE INDEX CONCURRENTLY`** — Required on production tables. Regular `CREATE INDEX` locks the table.
3. **CONCURRENTLY can leave invalid indexes** — Always verify with `indisvalid` check after creation
4. **RPC > multiple REST calls** — One `supabase.rpc()` call is faster than 6 `supabase.from().select()` calls
5. **`head: true` still evaluates view** — Count-only queries on complex views are just as slow as data queries
6. **Connection pooling** — Supabase free tier has limited connections. 8+ parallel requests hit the pool ceiling.
