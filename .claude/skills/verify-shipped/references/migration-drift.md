# Layer 6 — Migration File-vs-Applied Drift

The second silent killer. A migration file checked into the repo doesn't take effect until `supabase migration up` (or `apply_migration` MCP) actually runs against production. PR merges do NOT auto-apply.

Failure mode: code on main references a column / RPC / RLS policy that the migration file says exists, but the migration was never applied. Code 500s in production until someone notices.

---

## Recipe (Claude executes from the conversation)

### Step 1 — List repo migration files FROM origin/main (NOT from current worktree)

```bash
git fetch origin main --quiet
git ls-tree --name-only origin/main supabase/migrations/ \
  | grep '\.sql$' \
  | xargs -n1 basename \
  | sed 's/\.sql$//'
```

**Reading from `origin/main`, not the worktree, is mandatory.** the operator runs ~50 worktrees in parallel, many with WIP migration files on feature branches. Reading `ls supabase/migrations/*.sql` from the current worktree would produce flood-of-false-PENDING_APPLY findings — every WIP migration on every feature branch shows up as "pending apply." This trains the operator to ignore PENDING_APPLY exactly when a real one arrives. Council-CRITICAL fix 2026-05-07.

Each filename has the shape `<version>_<name>` where `<version>` is the leading digits (typically a 14-digit timestamp like `20260507123456` OR a 8-digit date like `20260507`).

Capture as a set: `repo_versions = { "20260505120000_notification_dispatch_atomic_claim_and_reaper", ... }`.

#### Filter rollback files

Some `*.sql` files in the migrations directory are rollback helpers, not forward migrations. Skip them BEFORE the diff:

```bash
# For each repo_version, check the file's first 3 lines on origin/main:
for version_name in <repo_versions>; do
  head_lines=$(git show "origin/main:supabase/migrations/${version_name}.sql" 2>/dev/null | head -3)
  if echo "$head_lines" | grep -qE '^-- ROLLBACK\b'; then
    continue   # skip — rollback helper, not forward migration
  fi
  if echo "$version_name" | grep -q '_rollback_'; then
    continue   # skip — filename signals rollback
  fi
  # Otherwise, include in the forward-migration set
done
```

Extract the version prefix from each:
```bash
echo "20260505120000_notification_dispatch_atomic_claim_and_reaper" | grep -oE '^[0-9]+'
# → 20260505120000
```

### Step 2 — List applied migrations on production

ONE MCP call:

```
mcp__supabase-{{project}}__list_migrations
```

Response shape:
```json
[
  { "version": "20260505120000", "name": "notification_dispatch_atomic_claim_and_reaper" },
  ...
]
```

Capture as a set: `applied_versions = { "20260505120000", ... }`.

### Step 2.5 — Pre-diff version-format reconciliation

Before diffing, scan for version-format mismatch (8-digit vs 14-digit). Some applied migrations may have been recorded under a SHORTER prefix than the repo filename uses. Catches a class of false PENDING_APPLY / false ORPHAN_APPLIED.

```bash
# For each applied_version, check if a repo_version starts with it OR vice versa
# (when one is a strict prefix of the other AND length differs — that's a format mismatch)
# If mismatches found, emit a [VERSION_FORMAT_MISMATCH] line and require manual reconciliation
# BEFORE running Step 3 diff. Don't auto-rewrite.
```

Output template per mismatch:
```
[VERSION_FORMAT_MISMATCH] applied=<applied_ver> repo=<repo_ver> — manually reconcile before treating as drift
```

### Step 3 — Diff (after rollback filter + version reconciliation)

For each forward repo file:
- Extract `<version>` (numeric prefix)
- If `<version>` NOT in `applied_versions` → **PENDING_APPLY**
- If `<version>` IN `applied_versions` → clean

For each applied version:
- If NO repo file matches that version → **ORPHAN_APPLIED**

### Step 4 — Output

Per pending:
```
[PENDING_APPLY] <version>_<name> — file in repo, not applied to production
  fix: cat supabase/migrations/<version>_<name>.sql | apply via mcp__supabase-{{project}}__apply_migration
       (use the migration's <name> as the apply name; copy SQL contents as the query)
```

Per orphan:
```
[ORPHAN_APPLIED] <version> — applied to production, no matching file in repo
  context: investigate before action — could be a manually-applied hotfix, a deleted-but-applied migration, or repo drift
  fix: AUDIT MANUALLY — do NOT auto-rollback (production state cannot be recreated from a missing file)
```

---

## Edge cases + gotchas

1. **Rollback scripts**: some `*.sql` files in the migrations directory are rollback helpers (header `-- ROLLBACK <version>`), not forward migrations. Skip these. Detection: first non-blank line starts with `-- ROLLBACK` or filename contains `_rollback_`.

2. **Squash migrations**: when multiple migrations get squashed into one (e.g., for a release), the squashed file's version is NEW; the old versions still appear in `applied_versions` until they're explicitly cleaned. Result: many `ORPHAN_APPLIED` lines after a squash. Don't auto-flag as fix-required — flag with a "POST_SQUASH_NORMAL" sub-classification.

3. **Multi-statement migrations**: some files contain multiple `CREATE / ALTER` statements. The MCP `apply_migration` runs the WHOLE file as one transaction. Don't split.

4. **Migration ordering**: Postgres applies in lexical order of `<version>`. If a `PENDING_APPLY` exists with an OLDER version than already-applied migrations (out-of-order check-in), flag separately as **OUT_OF_ORDER** — applying it now might fail or have surprising effects.

5. **`NOTIFY pgrst, 'reload schema'`**: many migrations end with this line to refresh PostgREST's schema cache. If a migration adds a column, the API won't see it until the NOTIFY runs. After applying a `PENDING_APPLY`, ALWAYS verify the new column/RPC is queryable via PostgREST before claiming success. This skill outputs a reminder line; doesn't auto-verify.

6. **Schema drift not detectable here**: if someone manually ran SQL via Dashboard, that change isn't in any migration file AND isn't in `list_migrations`. No way to detect from this layer. Future enhancement: snapshot schema via `generate_typescript_types` and diff against last known-good.

---

## Composes with

- `operational-guardrails.md` Confident Mode HARD STOP — production-row hand-edits require per-write authorisation; same applies to applying migrations
- `drop-column-safety.md` — DROP COLUMN migrations specifically need consumer-grep before applying (this skill doesn't enforce, but the pre-commit hook does)
- `supabase-migration-guard.sh` hookify hook — prevents committing migrations that would silently break production

## Future enhancements (queued)

- Schema-drift detection via TypeScript type diff
- pg_cron canary that runs Layer 6 every 12h
- `--auto-apply` mode (gated by Confident Mode HARD STOP — same risk class as edge function auto-deploy)
- Out-of-order detection per Edge Case #4
