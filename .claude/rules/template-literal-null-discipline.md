# Template-Literal NULL/Undefined Discipline

**Scoped to**: any TypeScript / JavaScript code that constructs strings used as:
- SQL `LIKE` / `ILIKE` patterns
- Postgres `regexp_replace` / regex patterns
- Database identifiers (idempotency keys, dedup keys, slug-style keys)
- Persisted address normalisation (`dd_property_parsed.normalized_address`, `original_address`, `full_address` source values)
- File system paths used as cache keys
- Any string later fed to an `eq` / `ilike` / `match` PostgREST or Supabase-JS filter

**Auto-loaded via**: `code-review-domain-routing.md` Edge Functions + Frontend/React domain on PRs touching `supabase/functions/**/*.ts`, `src/integrations/supabase/**`, any `*.ts`/`*.tsx` that calls `.from(...)` followed by `.ilike(...)` / `.like(...)` / `.match(...)`.

**Origin**: 2026-05-14 Edge Case dedup-graveyard P0 incident (GitHub #739, PR #743 + #744 + #745). 26 fresh wholesaler submissions lost to a single stale placeholder row via JavaScript template-literal interpolation of `null` values producing the literal pattern `%null%null%` against a graveyard row whose `normalized_address` literally contained "null" twice.

---

## The Trap

JavaScript template literals stringify `null` / `undefined` as the literal strings `"null"` / `"undefined"`:

```typescript
const x = null
const pattern = `%${x}%${x}%`
// pattern === '%null%null%'  ← matches any row whose target contains "null" twice
```

When this pattern is fed to Postgres `ILIKE`, it matches ANY row containing those words. The edge-case bug class: partner intake stored the address only in `full_address`, leaving the structured columns `NULL`. The edge function then built ILIKE patterns from those NULL columns and matched a graveyard row from 2026-05-11 whose `normalized_address` was the developer-side smoke test `<p>9876 Oak Drive, Phoenix, AZ 85003 — EXAMPLE SMOKE #3 Please Delete</p>, null, null null`. 26 real wholesaler submissions over 4 days absorbed silently into that one stale row.

Same trap applies to `normalize_address` writes, idempotency-key construction, regex patterns, and any string that later becomes a dedup target.

---

## The Rule

**Never interpolate a maybe-null value directly into a string used as a database identifier or pattern.** Use one of three safe shapes:

### Shape 1 — Pre-trim and filter-join (preferred for address normalisation)

```typescript
const safeStreet = (submission.street_address ?? '').toString().trim()
const safeCity = (submission.city ?? '').toString().trim()
const safeState = (submission.state ?? '').toString().trim()
const safeZip = (submission.zip ?? '').toString().trim()
const stateZip = [safeState, safeZip].filter(Boolean).join(' ')
const normalizedAddress = [safeStreet, safeCity, stateZip].filter(Boolean).join(', ')
// → '7370 10th St, Mobile, AL 36608' OR '7370 10th St, Mobile' OR '7370 10th St' OR ''
// Never contains "null" or "undefined"
```

### Shape 2 — Hard guard (preferred for dedup queries)

```typescript
if (!safeStreet || !safeCity) {
  // Bail — refuse to dedup with insufficient address signal
  return // or log + create fresh row
}
const { data } = await supabase
  .from('dd_property_parsed')
  .ilike('normalized_address', `%${safeStreet}%${safeCity}%`)
```

### Shape 3 — UUID-suffix on partial parse (preferred for idempotency keys)

```typescript
const idempotencyKey = safeCity
  ? `portal:${safeStreet}:${safeCity}:${safeState}`.toLowerCase().replace(/\s+/g, '-')
  : `portal:partial:${crypto.randomUUID()}`
// Partial-parse rows never collide on the unique index — always create fresh INSERTs
```

---

## Banned Patterns

```typescript
// ❌ ILIKE with template-literal interpolation of maybe-null values
.ilike('column', `%${submission.street_address}%${submission.city}%`)

// ❌ INSERT with template-literal-built normalized_address from maybe-null inputs
.insert({ normalized_address: `${submission.street_address}, ${submission.city}, ${submission.state} ${submission.zip}` })

// ❌ Idempotency key from maybe-null inputs
const key = `portal:${submission.street}:${submission.city}`.toLowerCase()

// ❌ Regex / LIKE pattern from maybe-null source
.like('source_company', `%${maybeSlug}%`)
```

Each of these recreates the `%null%null%` collision class if any input is NULL.

---

## Validation — Pre-PR Grep

Reviewers must grep PR diffs for the danger shape. Lightweight check:

```bash
# Find template-literal interpolation inside .ilike/.like/.match arguments
grep -rE "\.(ilike|like|match)\(\s*['\"]\w+['\"],\s*\`[^\`]*\\\$\{" supabase/functions/ src/
# Find template-literal-built normalized_address values
grep -rE "normalized_address:\s*\`[^\`]*\\\$\{" supabase/functions/ src/
```

Hits should EITHER use one of the three safe shapes OR carry an inline justification comment naming why the interpolated values are guaranteed non-null at this site.

---

## Audit-Trail Canaries

Three checkpoints in `dd_etl_events.event_type` fire if this bug class re-emerges:

| Checkpoint | Severity | Fires when |
|---|---|---|
| `DEDUP_REJECTED_STALE_PENDING` | warning | Layer 3 RPC body refused a pending-status dedup target older than 24h |
| `LAYER1B_PARTIAL_PARSE_NEW_PROPERTY_GUARDED` | warning | `parseFullAddress()` produced a partial result; filter-join omitted ≥1 component when building `normalized_address` |
| `LAYER1C_EMPTY_STREET_REJECTED` | alert | `parseFullAddress()` produced nothing usable; submission hard-flagged `needs_address_review` and 422 returned |

A non-zero count of any of these in the last 24 hours indicates a near-miss for the original bug class.

---

## Failure Precedent

**2026-05-14 — Edge Case form dedup-graveyard P0 (GitHub #739)**

- `submit_intake_deal` RPC stored `full_address` only; left `street_address`/`city`/`state`/`zip` NULL.
- `process-submission` edge function called `parseStreetComponents(null)` → all-null result → v2 dedup RPC skipped.
- Fallback ILIKE built `%null%null%` pattern → matched 2026-05-11 graveyard row `7337e842-...`.
- 26 submissions over 4 days silently absorbed into the graveyard.
- Detection horizon: the operator spotted via Step 2 SQL diagnostic (Step 2 PR #736), not via canary.

**Fix shipped**:
- PR #743 — Layers 1+2+3 read-side defence
- PR #744 — Layer-1b WRITE-side null-discipline (filter-join on new-property INSERT)
- PR #745 — Layer-1c empty-street reject + Layer-1d street-only UUID-suffix backstop

Three independent code-council runs (one in my session, one in the sibling autovibe chat, one post-merge on this PR) converged on the same defect-set, validating the council protocol.

---

## Related Rules

- 📄 `notification-dispatch-invariants.md` Rule 4 (audit-trail on destination identifier)
- 📄 `pipeline-philosophy.md` Anti-Pattern #2 (no wrong-but-plausible data on source failure)
- 📄 `loading-state-invariants.md` Invariant 7 (live-smoke against deployed-backend state before merging partner-facing data-fidelity changes)
- 📄 `arv-methodology-constraints.md` Rule 6 (seller-source-supremacy on structural-attribute cascade — analogous discipline for write-path data fidelity)
- 📄 `operational-guardrails.md` (Confident Mode HARD STOP on production-row hand-edits)
