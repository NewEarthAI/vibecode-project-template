# SQL Defensive Defaults — Latent Timebombs in Column Defaults and plpgsql Side-Effect Writes

**Origin**: 2026-05-14 — diagnosed a $400+ silent loss on the a logistics app fleet automation. Root cause was `lpad((nextval('conflict_seq'))::text, 4, '0')` in the `data_conflicts.conflict_id` column default. `lpad` truncates from the right when input exceeds target length, so once the sequence crossed 9,999, every 10 consecutive sequence values collapsed to identical 4-character suffixes, producing primary-key collisions on `data_conflicts`. The collisions rolled back the calling plpgsql function (`classify_media_final`) because its non-essential audit INSERT was not wrapped in `EXCEPTION`, leaving classified photos marked unclassified, which caused the n8n schedule trigger to re-pick them up every 10 minutes and re-call gpt-4o. Latent since function creation, activated 2026-04-15, detected 2026-05-13.

**Scope**: every migration, every `CREATE OR REPLACE FUNCTION`, every `ALTER COLUMN ... SET DEFAULT`, every plpgsql block that performs a write that is NOT the function's primary purpose.

**Composes with**: 📄 `rpc-replacement-safety.md`, 📄 `data-layer.md` § Function Migration Safety, 📄 `agentic-loop-guards.md` § Pre-Exit Verification.

---

## Rule 1 — NEVER combine string-truncation with counter-derived defaults

**The trap**: PostgreSQL's `lpad`, `rpad`, `substring`, `left`, and `right` ALL truncate when given input longer than the target length. They are not "pad-only" functions.

```sql
-- WRONG — silently truncates once counter exceeds 9999
SET DEFAULT ('PFX-' || to_char(now(),'YYYYMMDD') || '-' ||
             lpad(nextval('myseq')::text, 4, '0'));
-- nextval=10000 → 'PFX-20260514-1000' (last digit dropped)
-- nextval=10001 → 'PFX-20260514-1000' (same!)
-- nextval=10009 → 'PFX-20260514-1000' (same!)
-- All collide on PK.
```

**Acceptable alternatives**, in order of preference:

```sql
-- BEST — raw nextval text, variable-width, no truncation possible
SET DEFAULT ('PFX-' || to_char(now(),'YYYYMMDD') || '-' || nextval('myseq')::text);

-- ALSO FINE — UUID generator, infinite namespace
SET DEFAULT ('PFX-' || gen_random_uuid()::text);

-- ALSO FINE — explicit width guard that PROVES no truncation possible
-- Only acceptable when paired with a CHECK constraint that bounds the counter:
SET DEFAULT ('PFX-' || to_char(now(),'YYYYMMDD') || '-' || lpad(nextval('myseq')::text, 12, '0'));
-- Counter must be CHECK-bounded to < 10^12 by independent constraint, AND
-- the migration must include a self-test that inserts at the boundary.
```

**Detection signal for code-council and PR review**: any migration whose body matches the regex `lpad\s*\(\s*[^,]*nextval` is BLOCKING until proven safe. Same for `rpad(`, `substring(...nextval`, `left(...nextval`, `right(...nextval`.

---

## Rule 2 — Non-essential writes inside plpgsql MUST degrade gracefully

**The principle**: PostgreSQL plpgsql functions are transactional by default. ANY failure inside the function body rolls back the entire function, including writes that happened earlier. This is correct for the function's PRIMARY purpose but catastrophic for SECONDARY side-effects.

**Definition — "primary" vs "secondary" writes**:

| Class | Examples | Failure stance |
|-------|----------|----------------|
| Primary | The `UPDATE` / `INSERT` named in the function's purpose (e.g., `classify_media_final` updating `whatsapp_media`) | Allowed to roll back the transaction |
| Secondary | Audit log rows, denormalised cache writes, analytics events, observability writes, cross-table breadcrumbs | MUST NOT roll back the transaction |

**Required pattern** for every secondary write:

```sql
-- Option A — EXCEPTION block (catches any failure mode)
BEGIN
  INSERT INTO audit_log (...) VALUES (...);
EXCEPTION WHEN OTHERS THEN
  -- Secondary write failure must NEVER roll back primary work.
  -- Log to a safe channel if needed (RAISE NOTICE, system_alerts, etc.)
  NULL;
END;

-- Option B — ON CONFLICT DO NOTHING (only catches unique-violation, narrower)
INSERT INTO audit_log (...) VALUES (...)
ON CONFLICT DO NOTHING;

-- Option C — savepoint (advanced, when partial commit semantics matter)
SAVEPOINT before_audit;
BEGIN
  INSERT INTO audit_log (...) VALUES (...);
EXCEPTION WHEN OTHERS THEN
  ROLLBACK TO SAVEPOINT before_audit;
END;
```

**Heuristic for reviewers**: if you delete the secondary write entirely, does the function's primary purpose still work? If yes → it's secondary → MUST be EXCEPTION-wrapped or `ON CONFLICT`'d.

---

## Rule 3 — Every counter-derived default needs a boundary self-test in its migration

When a migration creates or alters a column default that depends on a counter (`nextval`, `currval`, custom sequence, hash modulo, etc.), the same migration MUST include a self-test that proves correctness at the BOUNDARY where the bug would activate.

**Template**:

```sql
-- After ALTER TABLE ... SET DEFAULT ...
DO $$
DECLARE
  v_test_id TEXT;
  v_existing INT;
BEGIN
  -- Advance the sequence to one beyond the padding boundary
  PERFORM setval('myseq', 9999, true);  -- next call = 10000
  -- Generate a test value using the same expression as the default
  v_test_id := ('PFX-' || to_char(now(),'YYYYMMDD') || '-' || nextval('myseq')::text);
  -- Verify uniqueness invariant
  SELECT COUNT(*) INTO v_existing FROM mytable WHERE id = v_test_id;
  IF v_existing > 0 THEN
    RAISE EXCEPTION 'Boundary self-test FAILED: default produces collision at counter boundary. Default expression is unsafe.';
  END IF;
  -- Roll the sequence back so production isn't affected
  PERFORM setval('myseq', currval('myseq') - 1, true);
END $$;
```

If the migration cannot pass this self-test, the column default is broken and must not ship.

---

## Rule 4 — Detection queries every quarter

The two patterns this rule prevents are easy to miss in code review but easy to detect by query. Run these on every Supabase project quarterly (or wire them into a scheduled cron that writes to `system_alerts`):

```sql
-- Find any column default that uses string-truncation functions on counter output
SELECT
  c.table_schema, c.table_name, c.column_name, c.column_default
FROM information_schema.columns c
WHERE c.column_default ~* '(lpad|rpad|substring|left\s*\(|right\s*\()\s*\(?[^,]*(nextval|currval)';

-- Find every plpgsql function whose body contains an INSERT not protected by EXCEPTION or ON CONFLICT
-- (This is a heuristic — produces false-positives — but is a good triage shortlist)
SELECT
  n.nspname AS schema, p.proname AS function_name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
  AND p.prosrc ILIKE '%INSERT INTO%'
  AND p.prosrc NOT ILIKE '%EXCEPTION WHEN%'
  AND p.prosrc NOT ILIKE '%ON CONFLICT%'
  AND n.nspname = 'public';
```

---

## Rule 5 — Edge-function error handling that matches the database-side discipline

The user-facing rule for any edge function (Supabase Edge Functions / Vercel functions / n8n Code nodes / etc.) that wraps a database call:

| Class | Examples | Failure stance |
|-------|----------|----------------|
| Primary outcome | Calling an RPC that performs the function's named purpose | Surface the error; do NOT silently swallow |
| Secondary observability | Posting to a logging/metrics endpoint, writing to an analytics queue | Wrap in try/catch; degrade silently |
| Idempotency-sensitive | Anything that costs money per call (OpenAI, Twilio, payment APIs) | MUST be guarded by an idempotency key OR a successful-recent-call check, so retries do not double-charge |

**The expensive-API-retry rule**: any external API call that bills per-invocation (LLM, SMS, vision-OCR, payment, geocoding) MUST be preceded by a check that the work hasn't already succeeded. The check must look at the PRIMARY persistence target, not at a derived state. Example: before calling gpt-4o on a photo, query `whatsapp_media.final_classification IS NULL` — never trust an in-memory "did we just call?" flag.

---

## Failure precedents

### 2026-05-14 — a logistics app `data_conflicts` lpad-truncation cascade

| Layer | What happened |
|-------|---------------|
| Schema bug | `data_conflicts.conflict_id` default used `lpad(nextval()::text, 4, '0')` |
| Activation | Global sequence crossed 9999 on 2026-04-15; 9 out of every 10 new conflict_ids collided on PK |
| Function bug | `classify_media_final` performed a secondary INSERT to `data_conflicts` without EXCEPTION wrapping |
| Cascade | PK collision rolled back the entire function → `whatsapp_media.final_classification` stayed NULL → schedule trigger re-picked photos every 10 minutes → gpt-4o was re-called |
| Cost | ~$15/day for 29 days = ~$435 of silent waste before the OpenAI dashboard surfaced the spike |
| Fix | Dropped the `lpad`, kept raw `nextval::text`. Wrapped secondary INSERT in `BEGIN ... EXCEPTION WHEN OTHERS THEN ... END`. |
| Detection | Only because a fresh API key labelled the cost as a separate line item on the OpenAI dashboard |

The bug was **invisible to every static-analysis tool**, every code review, every council, and every Supabase advisor. The only thing that detected it was a billing line item. This rule exists so the next instance is caught at migration time, not at billing time.

---

## References

- 📄 `rpc-replacement-safety.md` — sibling rule: never overwrite a function without diff
- 📄 `data-layer.md` § Function Migration Safety — parameter-order and overload safety
- 📄 `agentic-loop-guards.md` § Pre-Exit Verification — self-test artefact requirement
- 📄 `code-review-domain-routing.md` — auto-load matcher for SQL migrations
