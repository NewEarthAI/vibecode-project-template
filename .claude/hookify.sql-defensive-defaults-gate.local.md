---
name: sql-defensive-defaults-gate
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-(a-logistics-app|the appai|your-org)__(apply_migration|execute_sql)
action: warn
---

**[SMART WARN] SQL defensive-defaults check — latent timebomb patterns**

Triggered when the migration / SQL body matches any of these high-risk patterns. These are the two patterns that caused the 2026-05-14 a logistics app `data_conflicts` cascade (~$435 silent loss, 29 days latent before detection).

## Pattern A — string-truncation on counter-derived defaults

If the SQL contains `lpad(`, `rpad(`, `substring(`, `left(`, or `right(` applied to `nextval(`, `currval(`, or any sequence-returning expression — STOP.

```sql
-- WRONG — silently truncates once counter exceeds the pad width
SET DEFAULT (... || lpad(nextval('seq')::text, 4, '0'));
```

`lpad/rpad/substring/left/right` ALL truncate when input exceeds target length. They are NOT "pad-only" — they actively destroy data. Once the counter crosses 10^pad_width, every consecutive value collapses to the same suffix, producing PK collisions.

**Pre-deploy checklist** (every item required before approving):
```
SQL DEFENSIVE DEFAULTS — PATTERN A:
[ ] 1. Counter has a CHECK constraint that bounds it BELOW the padding limit, OR
[ ] 2. Padding width is wide enough that counter cannot reach it in the system's lifetime
      (Rule of thumb: width ≥ 12 for any production sequence)
[ ] 3. Migration body includes a boundary self-test that PERFORM setval(...) at the
      cliff value and verifies no collision
[ ] 4. If none of (1-3) hold, default expression is REWRITTEN to use raw
      nextval()::text or gen_random_uuid() with no truncation
```

## Pattern B — non-essential INSERTs inside plpgsql without graceful degradation

If the SQL contains `CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql` AND the body contains an `INSERT INTO` that is NOT the function's primary purpose (audit log, denormalised cache, analytics, observability), it MUST be wrapped in `BEGIN ... EXCEPTION` OR use `ON CONFLICT DO NOTHING`.

**Pre-deploy checklist**:
```
SQL DEFENSIVE DEFAULTS — PATTERN B:
[ ] 1. For each INSERT inside the function body, classify: PRIMARY (function purpose) vs SECONDARY (side effect)?
[ ] 2. Every SECONDARY INSERT is wrapped in BEGIN ... EXCEPTION WHEN OTHERS THEN ... END
      OR carries ON CONFLICT DO NOTHING
[ ] 3. Heuristic test: if the secondary INSERT is deleted entirely, does the function's
      primary purpose still work? If yes — it's secondary — guards are required.
[ ] 4. Same rule applies to UPDATE / DELETE side-effects that are not the function's purpose
```

## Root cause precedent

**2026-05-14, a logistics app fleet automation** — `data_conflicts.conflict_id` default used `lpad(nextval()::text, 4, '0')`. Sequence crossed 9,999 on 2026-04-15. From then on, 9 out of every 10 audit-log inserts produced duplicate `conflict_id` values, causing PK collisions. The calling function `classify_media_final` had no `EXCEPTION` wrapper on its audit INSERT, so each collision rolled back the entire classification. WhatsApp photos stayed marked unclassified; n8n's 10-minute schedule trigger kept re-picking them up; gpt-4o was re-called 6× per photo. Bug was invisible to all static analysis — only the OpenAI billing dashboard surfaced it (~$15/day for 29 days = ~$435 silent loss).

---
**Reference**: 📄 `.claude/rules/sql-defensive-defaults.md`
