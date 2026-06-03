# RPC Replacement Safety — NEVER Overwrite Without Diff

## The Rule

**BEFORE any `CREATE OR REPLACE FUNCTION` on a function that already exists in production:**

1. Extract the LIVE source from `pg_proc`:
   ```sql
   SELECT prosrc FROM pg_proc WHERE proname = '<function_name>' LIMIT 1
   ```
2. Diff the proposed replacement against the live source
3. If ANY lines from the live source are MISSING in the replacement → **STOP** — it's a regression
4. Prefer surgical patches over full replacement:
   ```sql
   DO $$
   DECLARE v_src text;
   BEGIN
     SELECT prosrc INTO v_src FROM pg_proc WHERE proname = '<fn>' LIMIT 1;
     v_src := REPLACE(v_src, '<old_text>', '<new_text>');
     EXECUTE format('CREATE OR REPLACE FUNCTION <fn>(...) RETURNS ... AS %L', v_src);
   END; $$;
   ```

## Why This Exists

**2026-03-31 incident**: A subagent patching `generate_brownie_daily_brief_v3` used an OLD migration file as its source. The deployed function had 3 subsequent fixes (RETURNING/MULTI-DAY removal, carry-forward route ordering, trip_fuel CTE). The `CREATE OR REPLACE` overwrote ALL of them. Brownie saw fake "RETURNING / MULTI-DAY" routes reappear and the Hub crashed on null route names.

**Root cause**: Migration files diverge from deployed functions. The live `pg_proc` source is the ONLY authoritative version.

## When This Applies

- ANY subagent that modifies SQL functions
- ANY migration that uses `CREATE OR REPLACE FUNCTION`
- ANY session that patches RPCs (email, daily brief, recon, etc.)

## Exceptions

- Brand new functions (no existing `pg_proc` entry) — safe to CREATE directly
- Functions explicitly being rewritten from scratch with user approval

## Enforcement

Subagents MUST include this in their prompt when touching SQL functions:
> "Before replacing any function, extract current source from pg_proc and diff against your proposed changes. Report any lines that would be lost."

## Composes With

- 📄 `sql-defensive-defaults.md` — sibling rule. Function replacements MUST also satisfy: (a) no `lpad/rpad/substring/left/right` on counter-derived defaults the function depends on, (b) every secondary INSERT/UPDATE in the function body wrapped in `BEGIN ... EXCEPTION` or `ON CONFLICT DO NOTHING`. The 2026-05-14 Nirvana cascade was a textbook case where a clean function replacement was undermined by an unguarded secondary INSERT.
- 📄 `data-layer.md` § Function Migration Safety — never change parameter order on replacement.
