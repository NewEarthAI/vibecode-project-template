# make-safe-baseline — the universal pattern (system-agnostic)

> **What this is.** A database whose migration history is a long, drifted, partly-hand-applied
> ledger CANNOT be rebuilt cleanly from code — so you cannot stand up a throwaway copy to test a
> change against, which means you are flying blind every time you touch production. This recipe
> makes the history **trustworthy**: it captures the live structure as one clean baseline, makes it
> safe to replay, and reconciles the bookkeeping so a fresh copy rebuilds byte-for-what-prod-is.
> Once that holds, you can prove any change on a disposable copy before it ever reaches prod.
>
> **This file is the PATTERN.** The tooling for each database system lives in
> `references/db-adapters/<system>.md`. Postgres/Supabase is `WIRED` (proven on a real production
> baseline). Other systems are `STUB` until a client runs on them. The skill reads the adapter's
> `STATUS:` token — anything other than `wired` = STOP, do not invent a recipe.

---

## When to run this

- A database's migration history is drifted / squash-overdue and you need it rebuildable from code
  (the precondition for a dev/prod staging copy, Supabase Branching, or any throwaway-copy test).
- ONE-TIME per database, per major baseline. Not a routine op — it edits migration bookkeeping.

**Do NOT run this routinely, and NEVER run it while migrations are actively shipping** (step 0).

---

## The two hard lessons (these are STEPS, not advice)

Both cost real time on the first real production run (2026-06-24). They are non-negotiable steps below.

1. **FREEZE during baseline + reconcile (step 0).** A snapshot taken while migrations are shipping
   is **stale-on-arrival** — a migration that landed seconds before the snapshot is already absent
   from it, so the baseline bakes in drift and every throwaway copy rebuilds a DB that is subtly
   NOT production. On the first run the ledger grew 909→914 mid-baseline and a parallel migration
   was missed. The recipe must DETECT active shipping and REFUSE until a quiet window.

2. **A history-squash BREAKS code/tests that read migration files by path (step 5).** Archiving the
   old migration files moves them — any test or script that opens a migration by its path then
   fails to find it. On the first run two test files broke this way. The recipe must GREP for
   path-readers and re-point them BEFORE archiving, not after the suite goes red.

---

## The 7 steps (universal) + what each adapter must supply

Each step names the **universal intent**; the adapter file supplies the **concrete tooling**.

### Step 0 — Freeze-check (REFUSE if mid-shipping)
**Intent:** confirm no migration is landing during the baseline window.
**Adapter supplies:** a way to read the migration-ledger size/HEAD twice ~60s apart. If it changed,
a parallel session is shipping → **REFUSE**. Proceed only on a stable read (a ~15-min quiet window).
**Why a hard stop:** this is lesson #1. A baseline captured mid-ship is worse than no baseline — it
manufactures false confidence.

### Step 0b — Topology shape read (drift signal, optional)
**Intent:** cross-check the live structure against the system's known shape before trusting it.
**Adapter supplies:** read the system's `topology-substrate` shape if a topology map exists.
**Honest-degradation:** if no map exists, say so plainly and proceed — NEVER launder absence into a
green light (per the system-awareness honest-degradation matrix). Absent map ≠ "aligned".

### Step 1 — Snapshot live structure → one baseline
**Intent:** capture the complete current structure (all schemas/collections) as a single artefact.
**Adapter supplies:** the structure-only dump command + the connection method + any host/auth quirks.
**Credentialed step** — stays an operator action (real DB password), not an autonomous one.

### Step 2 — Strip incompatible wrapper
**Intent:** remove client-only/tool-only directives the dump adds that a replay engine rejects.
**Adapter supplies:** which wrapper lines to strip.

### Step 3 — Fold in add-on extensions / structures the dump omits
**Intent:** dumps often omit installed extensions/plugins scoped to a schema — replay needs them.
**Adapter supplies:** how to enumerate the live add-ons + how to inject idempotent create statements.
**Freshness assertion:** grep the baseline for the newest known migration's artefact — it MUST be
present, else a migration landed mid-dump (freeze failed) → repeat the freeze.

### Step 4 — Make safe-to-replay (idempotent)
**Intent:** every create/alter in the baseline must be re-runnable without error (a preview branch
may replay it onto a parent that already has some objects).
**Adapter supplies:** the idempotency transform (e.g. `CREATE … IF NOT EXISTS`).

### Step 5 — Path-reader rescan + re-point, THEN archive
**Intent:** find everything that reads a migration file by path; re-point it; ONLY then archive.
**Adapter supplies:** the grep patterns for migration-path references in code/tests/scripts.
**Order is the lesson:** rescan + re-point FIRST, archive SECOND. This is lesson #2.

### Step 6 — Reconcile bookkeeping (in the frozen window)
**Intent:** leave the ledger holding ONLY the baseline version, so local + remote agree.
**Adapter supplies:** the ledger-reconcile command (prefer the tool's blessed repair path).
**Recoverable:** edits bookkeeping rows only — never live data/structure; the archived old files +
git are the recovery path. Still a **production write** → explicit operator nod at the moment
(plan approval is NOT a blanket prod nod).

### Step 7 — Prove on a throwaway copy (the completion gate)
**Intent:** rebuild a disposable copy FROM the baseline and confirm it comes up healthy.
**Adapter supplies:** the throwaway-rebuild mechanism + the "healthy" signal to read.
**Generic shape:** rebuild the baseline into a scratch DB, then diff scratch-vs-prod structure.
**Completion bar:** the throwaway copy reads healthy AND local+remote ledger agree. Anything less is
NOT done — name the gap, do not declare green.

---

## Completion gate (all must hold)

- [ ] Step 0 freeze held (ledger stable across the window).
- [ ] Baseline contains the newest migration's artefact (freshness assertion passed).
- [ ] Path-readers re-pointed BEFORE archive; the existing test suite is green.
- [ ] Ledger reconciled: local + remote agree, only the baseline version remains.
- [ ] A throwaway copy rebuilt from the baseline reads HEALTHY.

## Anti-patterns

| Wrong | Why | Right |
|---|---|---|
| Snapshot while a parallel session ships migrations | Stale-on-arrival; bakes drift into the baseline (lesson #1) | Step-0 freeze: refuse until the ledger is stable |
| Archive old migration files, then run the test suite | Path-reading tests break red after the fact (lesson #2) | Step-5 rescan + re-point BEFORE archiving |
| Declare done after the reconcile | The reconcile is bookkeeping, not proof | Step-7: prove a throwaway copy rebuilds healthy |
| Treat an absent topology map as "aligned" | Launders absence into false confidence | Step-0b honest-degradation: say "no map", proceed with the gap stated |
| Run the recipe for a `STUB` adapter system | A guessed recipe risks a real client DB | Stop at the stub; tell the operator the system is not wired |

## References
- `references/db-adapters/_PATTERN.md` — the adapter contract (what every `<system>.md` must answer)
- `references/db-adapters/postgres-supabase.md` — WIRED concrete recipe + the script
- `scripts/make-safe-baseline-postgres.sh` — automates the brittle Postgres edits + step-0/3/5 guards
