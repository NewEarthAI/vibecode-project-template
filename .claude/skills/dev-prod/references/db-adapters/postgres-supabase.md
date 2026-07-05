# postgres-supabase adapter
STATUS: wired

> Proven end-to-end on a real production baseline (2026-06-24): full prod schema squashed
> to one baseline → ledger reconciled → main rebuilt GREEN (`FUNCTIONS_DEPLOYED`) → Supabase
> Branching working. This adapter carries the concrete tooling for each `make-safe-baseline` step
> plus the live-fact gotchas that cost time on that run.
>
> **Identifiers are parameters, never hardcoded.** Project ref, pooler host, and schema list are
> passed to the script / commands at call time. The skill's own hardcoded-prod-ref-audit
> anti-pattern forbids baking a prod ref into a file. The placeholders below are filled per project
> in `entity-routing.md`, NOT here.

## Prerequisites
- `pg_dump` matching the prod major version (e.g. Postgres 17 → `/opt/homebrew/opt/postgresql@17/bin/pg_dump`).
- Supabase CLI linked (`supabase link --project-ref <ref>`), authenticated by the personal access token `sbp_…`.
- The REAL DB password (for `pg_dump` only — see gotcha #2).

## Step-by-step tooling

### Step 0 — Freeze-check
```bash
# read the ledger twice ~60s apart; if it changed, a parallel session is shipping → REFUSE
mcp__supabase-<project>__execute_sql "SELECT count(*), max(version) FROM supabase_migrations.schema_migrations;"
# (the script does this automatically: scripts/make-safe-baseline-postgres.sh --freeze-check)
```

### Step 0b — Topology shape read
Read the project's `topology-substrate` shape if a map exists; absent ⇒ say so, proceed (honest-degrade).

### Step 1 — Snapshot (operator, credentialed)
```bash
/opt/homebrew/opt/postgresql@17/bin/pg_dump --schema-only --no-owner --no-privileges --verbose \
  -n public -n <schema2> -n <schema3> \
  "postgresql://postgres.<ref>:<REAL_DB_PASSWORD>@<pooler-host>:5432/postgres" \
  -f supabase/migrations/<baseline_version>_baseline_prod_schema.sql
```
- `-n <schema>` for EACH custom schema (e.g. `public` + your project's custom schemas). A missing `-n` = a missing
  schema = the preview branch fails on the first object that depends on it.
- `<baseline_version>` = the earliest ledger version (sorts first).

### Step 2 — Strip incompatible wrapper
Strip the psql-only `\restrict <token>` (near line 5) and `\unrestrict <token>` (last line). The
migration replay engine is not psql and rejects them. **The script does this.**

### Step 3 — Fold in add-on extensions + freshness assertion
`pg_dump -n` omits public-schema extensions. Enumerate the live ones and inject idempotent creates:
```sql
SELECT extname FROM pg_extension JOIN pg_namespace n ON n.oid=extnamespace WHERE n.nspname='public';
-- e.g. citext, pg_trgm, unaccent, postgis
```
Inject after the first `CREATE SCHEMA IF NOT EXISTS public;`:
`CREATE EXTENSION IF NOT EXISTS <ext> WITH SCHEMA public;` for each. **The script does this** (pass
the live list with `--extensions`). **Freshness:** grep the dump for the newest migration's artefact
(e.g. its newest column) — absent ⇒ a migration landed mid-dump → re-freeze. **The script asserts this** (`--assert-present`).

### Step 4 — Idempotent
`CREATE SCHEMA <x>` → `CREATE SCHEMA IF NOT EXISTS <x>`. **The script does this.**

### Step 5 — Path-reader rescan + re-point, THEN archive
```bash
# find code/tests that open a migration file by path (on the first real run, 2 test files broke this way)
grep -rEn "migrations/[0-9]{14}|migrations-archive|supabase/migrations/" \
  src/ supabase/ tests/ scripts/ --include="*.ts" --include="*.tsx" --include="*.js" --include="*.sql" \
  | grep -v "supabase/migrations/<baseline_version>"
```
Re-point each hit at the archive path FIRST. THEN archive:
```bash
mkdir -p supabase/migrations-archive-pre-baseline-<date>
git mv supabase/migrations/2025*.sql supabase/migrations/2026*.sql supabase/migrations-archive-pre-baseline-<date>/
# active dir now holds ONLY the baseline file
git add -A && git commit   # baseline + archive TOGETHER (archive alone empties the active dir → branching breaks)
```
**The script runs the grep** (`--path-rescan`) and refuses to print "clear to archive" if hits remain.

### Step 6 — Reconcile the ledger (operator + explicit nod — production write)
Fresh read first (in the frozen window), then leave only the baseline:
```bash
supabase migration list                      # FRESH — capture the live old-version set
supabase migration repair --status reverted <all non-baseline versions…>
supabase migration repair --status applied <baseline_version>
supabase migration list                      # verify Local + Remote agree
```
Equivalent atomic path (avoids a ~900-arg command), bookkeeping-only, recoverable from the archive + git:
```sql
DELETE FROM supabase_migrations.schema_migrations WHERE version <> '<baseline_version>';
SELECT count(*) FROM supabase_migrations.schema_migrations;  -- expect 1
```

### Step 7 — Prove on a throwaway copy (completion gate)
```
mcp__supabase-<project>__list_branches   # the new PR's preview branch MUST read MIGRATIONS_HEALTHY
```
If it fails: `mcp__supabase-<project>__get_logs` service `branch-action` → the failing statement is
usually a missing `-n` schema or an object depending on a managed-schema object → fix the baseline →
re-test. Do NOT re-touch the ledger unless `migration list` shows fresh divergence.

## Live-fact gotchas (cost time on the first run — read before running)
1. **Branching reads the PARENT (prod) ledger** — repo migration files AND the prod ledger must
   AGREE for a preview to go green. That's why step 6 (reconcile) is required, not optional.
2. **The `sbp_` access token authenticates the CLI + `--linked` ops but is REJECTED by `pg_dump`.**
   `pg_dump` needs the real DB password.
3. **The direct DB host `db.<ref>.supabase.co` is IPv6-only** (DNS-unresolvable on many Macs) → use
   the **session pooler** `<region>.pooler.supabase.com:5432`, user `postgres.<ref>`. (`aws-0…`
   returns "tenant not found"; use the region the project actually lives in.)
4. **`supabase db dump` needs Docker** — if Docker is banned in your environment, use `pg_dump`
   directly (above), not the CLI wrapper.
5. **Merge any open proven-fix PRs to main BEFORE the baseline** so their migration files fold into
   the squash; otherwise they re-apply on later preview branches (idempotent DDL = harmless but
   avoidable).
6. **Giant-diff PRs may get NO preview branch** — Supabase can skip a preview for an enormous diff.
   Then the proof is main's own post-merge re-check reading `FUNCTIONS_DEPLOYED` instead.

## Security
- The `sbp_` token + DB password are credentials. Never commit them; never paste into a shared
  artefact. If exposed during a run, rotate both after.
