---
name: verify-shipped
description: Walk the full BuyBox repo state across 6 layers (worktrees, branches, PRs, Vercel deploy, edge function deploy-vs-main drift, migrations applied-vs-repo) and produce a punch-list with exact fix commands. Use when - "verify fleet", "fleet check", "is everything actually shipped", "what's loose", "drift check", "shipping audit", before any major demo, or auto-fired by /autovibe post-ship + /daily-plan morning brief. Catches the silent killers - edge function source-vs-deployed drift (Cedar Hurst doctrine pattern) and migration file-vs-applied drift - that /ship and /autovibe alone cannot see because each operates on ONE branch at a time.
---

# /verify-shipped — Fleet Audit Across 6 Shipping Layers

> **Philosophy**: `/ship` handles ONE branch. `/autovibe` handles ONE feature. `/verify-shipped` walks the full stable. Different jobs.

> **Status**: v1.1. Layers 1, 2, 3, 5, 6 implemented. Layer 4 (Vercel deploy lag) queued (see `references/v2-queued.md`). v1.1 adds parallel-session lock, suppress-file mechanism, autovibe Phase 4.5 hook, and daily-plan Phase 1.5 fleet-status snippet.

---

## The 6 Layers (Justin's "shipped" definition)

| Layer | What it catches | Source of truth | This skill detects |
|---|---|---|---|
| **1. Worktree state** | "I committed it" — but the side-folder has dirty changes | Local git | ✅ implemented |
| **2. Branch state** | "I pushed" — but you pushed an old commit; new commits local-only | Local + origin | ✅ implemented (v1.1) |
| **3. PR state** | "I opened a PR" — but it's still open / failing CI / un-merged | GitHub | ✅ implemented (v1.1) |
| **4. Vercel deploy lag** | "Main got merged" — but Vercel's last deploy was 2 hrs before that | Vercel API | ⏳ queued v1.2 |
| **5. Edge function drift** | "Code is on main" — but `supabase functions deploy` was never run; partner-facing data still on old logic (**Cedar Hurst silent-killer class**) | Supabase MCP | ✅ implemented |
| **6. Migration drift** | "Migration file is in the repo" — but it was never applied to production | Supabase MCP | ✅ implemented |

Layers 5 + 6 are the silent killers. They produce no error, no log, no signal — just wrong-but-plausible production behaviour for hours/days/weeks. `loading-state-invariants.md` Invariant 7 is the doctrinal witness.

---

## Dispatch

```
/verify-shipped                  # Run all enabled layers, default tier
/verify-shipped quick            # Layers 1+6 only (~10s) — pre-demo gate
/verify-shipped deep             # All layers + Vercel deploy log inspection (~3min)
/verify-shipped --layer=5        # Single layer (e.g., edge function drift only)
```

When invoked with no args, the skill auto-selects tier based on time-since-last-run + recent git activity (mirroring `/verify-pipeline`'s pattern).

---

## Step-by-step recipe (Claude follows this)

When this skill loads, execute in order:

### Phase 0 — Preflight
1. Confirm cwd is a git repo: `git rev-parse --is-inside-work-tree`
2. Confirm `gh` CLI authenticated: `gh auth status` (non-fatal — Layer 3 will degrade)
3. Confirm `supabase-buyboxai` MCP available (used by Layers 5 + 6)
4. **Pre-fetch origin refs** (REQUIRED for Layer 2 STALE_LOCAL detection per code-council 2026-05-07 IMPORTANT #1):
   ```bash
   git fetch --all --prune --quiet 2>/dev/null || echo "[INFO] git fetch failed; Layer 2 STALE_LOCAL detection may under-report" >&2
   ```
   Non-fatal — composition-aware (autovibe already runs `preflight.sh` Gate 5 which fetches; daily-plan does its own sync).
5. Set start timestamp; persist to `.claude/verify-shipped-last-run.txt` at end
6. **Acquire parallel-session lock** (atomic-mkdir per `ship/scripts/lock.sh` precedent):
   ```bash
   LOCK_DIR=".claude/verify-shipped.lock"
   START_TS_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   SESSION_UUID="${CLAUDE_SESSION_ID:-$(uuidgen 2>/dev/null || echo $$)}"

   # Function that writes interrupted-state JSON before releasing lock (per code-council
   # 2026-05-07 SUGGESTION #2 — interrupted-state writeback contract)
   write_interrupted_state_and_release() {
     cat > .claude/verify-shipped-last-run.json <<EOF
   {"schema_version":"v1.1","timestamp":"$START_TS_ISO","duration_ms":0,"tier":"$TIER","interrupted":true,"session_uuid":"$SESSION_UUID","layers":{},"exit_code":2,"fleet_integrity_score":null,"punch_list_summary":"interrupted before completion","suppressed_count":0}
   EOF
     rm -rf "$LOCK_DIR" 2>/dev/null
   }

   if mkdir "$LOCK_DIR" 2>/dev/null; then
     # Acquired — write metadata + install interrupt-safe trap
     echo "{\"session_uuid\":\"$SESSION_UUID\",\"started_at\":\"$START_TS_ISO\"}" > "$LOCK_DIR/meta.json"
     trap write_interrupted_state_and_release INT TERM
     trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT
   else
     # Held by another session — compute lock age via stat (BSD %B birth, GNU %Y mtime)
     # Bound the result: negative ages (clock skew, NTP correction) treated as corrupt.
     # Code-council 2026-05-07 CRITICAL #1.
     LOCK_BIRTH=$(stat -f %B "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
     NOW=$(date +%s)
     LOCK_AGE_SEC=$((NOW - LOCK_BIRTH))
     if [ "$LOCK_AGE_SEC" -lt 0 ] || [ "$LOCK_AGE_SEC" -gt 300 ]; then
       # Negative age = clock skew / corrupt; >300s = stuck. Clear + retry once.
       echo "[INFO] clearing stuck/corrupt lock (age ${LOCK_AGE_SEC}s)" >&2
       rm -rf "$LOCK_DIR"
       mkdir "$LOCK_DIR" || { echo "[ERROR] could not acquire lock after clear; aborting" >&2; exit 2; }
       echo "{\"session_uuid\":\"$SESSION_UUID\",\"started_at\":\"$START_TS_ISO\"}" > "$LOCK_DIR/meta.json"
       trap write_interrupted_state_and_release INT TERM
       trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT
     else
       # Fresh lock held — degrade gracefully via cached state. read-state.sh --max-age 0
       # bypasses BOTH staleness AND interrupted checks (per its --max-age 0 contract)
       # so we always get a result rather than triggering a retry-storm.
       echo "[INFO] Another session is running /verify-shipped; using cached state" >&2
       bash .claude/skills/verify-shipped/scripts/read-state.sh --max-age 0
       exit $?
     fi
   fi
   ```
7. **Load suppress-file** (optional — skip if absent): read `.claude/verify-shipped-suppress.json`. Parse JSON map keyed by `<layer>:<finding-key>`. Filter expired entries (purge in Phase 8). Carry the active-suppress map into Phase 7 synthesis.

### Phase 1 — Worktree state (Layer 1)
Run `bash .claude/skills/verify-shipped/scripts/walk-worktrees.sh`. Capture stdout. Each line is one of:
- `[CLEAN] <path>` — no action needed
- `[DIRTY] <path> <count> uncommitted` — fix command: `cd <path> && git status` (then commit or stash)
- `[STALE] <path> on <branch>, <count> commits ahead of origin` — fix command: `cd <path> && git push`

### Phase 2 — Branch state (Layer 2)
Run `bash .claude/skills/verify-shipped/scripts/walk-branches.sh`. Capture stdout. Each line is one of:
- `[CLEAN] <branch>` — suppressed when fleet >10 branches; summary line at end shows clean count
- `[AHEAD] <branch> <count>` — fix command: `git push origin <branch>`
- `[BEHIND] <branch> <count>` — informational; remote has commits the local branch doesn't
- `[DIVERGED] <branch> <ahead>/<behind>` — fix command: `git fetch && git checkout <branch> && git pull --rebase`
- `[NO_UPSTREAM] <branch>` — fix command: `git push -u origin <branch>` (or delete if abandoned)
- `[STALE_LOCAL] <branch>` — remote-tracking ref gone (branch deleted on origin); fix: `git branch -D <branch>` if work merged, else investigate
- `[ERROR] <branch> <reason>` — couldn't probe (rare)

Excludes `main` and `master` from the walk (those are baseline, not fleet items).

### Phase 3 — PR state (Layer 3)
Follow `references/pr-fleet.md` recipe. Briefly:
1. `gh auth status` — if not authenticated, emit `[skip] Layer 3 — gh CLI not authenticated` and exit Layer 3 with 0 issues; do NOT fail the skill.
2. `gh pr list --author "@me" --state open --limit 50 --json number,title,headRefName,isDraft,mergeStateStatus,statusCheckRollup,createdAt,updatedAt`
3. For each open PR, classify:
   - `[STALE_OPEN_PR] #<N> "<title>" — <age> old, no activity` (open >7 days with no recent commits or comments)
   - `[FAILING_CI] #<N> "<title>" — <check> = FAILURE` (any required check failing)
   - `[MERGEABLE] #<N> "<title>" — clean + green + ready to merge` (informational; no fix needed)
   - `[CONFLICTS] #<N> "<title>" — has merge conflicts` (fix: `git rebase origin/main`)
4. `gh pr list --author "@me" --state merged --limit 20 --json number,title,headRefName,mergedAt` — for each merged PR, check whether the corresponding local branch + worktree still exist:
   - `[MERGED_NOT_CLEANED] PR #<N> "<title>" merged <age> ago — worktree at <path>, branch <name>` (fix: `git worktree remove <path> && git branch -D <name> && git push origin --delete <name>`)
5. Emit raw findings to stdout. Phase 7 cross-reference logic dedupes against Layer 2 STALE_LOCAL.

### Phase 4 — Vercel deploy lag (Layer 4 — QUEUED v1.2)
Per `references/v2-queued.md`, output: `[V1.2_QUEUED] Layer 4 — Vercel deploy lag` and skip. Auth-surface proof-out is recorded in `references/v2-queued.md` Layer 4 section.

### Phase 5 — Edge function drift (Layer 5)
Follow `references/edge-fn-drift.md` recipe exactly. Briefly:
1. List source dirs: `find supabase/functions -mindepth 1 -maxdepth 1 -type d ! -name '_*' ! -name 'debug-*'`
2. For each `<name>`: get last commit timestamp on its `index.ts` from `main` branch (NOT current worktree — main is the source of truth)
3. Call `mcp__supabase-{{project}}__list_edge_functions` once; capture every function's `updated_at`
4. Diff: if `main_commit_ts > deployed_updated_at` for a function → DRIFT
5. Fix command per drift: `supabase functions deploy <name> --project-ref {{supabase_project_ref}}`

Edge cases the recipe covers (read the reference for full handling):
- New source dir, never deployed → fix is initial deploy
- Deployed but source deleted → fix is `supabase functions delete <name>` (with confirmation gate)
- `_shared/` and `debug-*` dirs are excluded (not deployable / temporary)
- `verify_jwt` config drift — separately covered by hookify rule `supabase-deploy-config-toml-lockstep.local.md`

### Phase 6 — Migration drift (Layer 6)
Follow `references/migration-drift.md` recipe exactly. Briefly:
1. List repo migrations: `ls supabase/migrations/*.sql | xargs -n1 basename | sed 's/\.sql$//'`
2. Call `mcp__supabase-{{project}}__list_migrations` once; capture `version` field of every applied migration
3. Diff: any repo file whose version is NOT in the applied set → DRIFT
4. Fix command per drift: `mcp__supabase-{{project}}__apply_migration` with the migration's name + SQL contents

Edge cases:
- Applied migrations not in repo → orphan applied; flag but do NOT auto-roll-back (would destroy production state)
- Migration filename pattern: `<version>_<name>.sql` — version is the leading numeric/timestamp prefix
- Skip files marked with `-- ROLLBACK` header (those are intentional rollback scripts, not forward migrations)

### Phase 7 — Synthesis + punch-list output

**Cross-reference Layer 2 ↔ Layer 3** (decision 4.3 of master-continuation): when Layer 3 emits `MERGED_NOT_CLEANED` for a branch, suppress any matching Layer 2 `STALE_LOCAL` for the same branch name. The MERGED_NOT_CLEANED finding is more specific (carries PR # + age + worktree path) and includes the same fix commands plus the worktree-removal step.

Implementation: build a `suppressed_by_l3 = {<branch_name>: True}` set from Layer 3 MERGED_NOT_CLEANED outputs; when iterating Layer 2 findings, skip any STALE_LOCAL whose branch is in that set.

**Apply suppress-file** (decision 4.4): for each remaining finding, compute a finding-key:
- Layer 1: `1:<status>:<path>` (e.g., `1:DIRTY:/Users/justin/code/buybox-comp-frontend`)
- Layer 2: `2:<status>:<branch>` (e.g., `2:AHEAD:feat/foo`)
- Layer 3: `3:<status>:<pr-number>` (e.g., `3:STALE_OPEN_PR:471`)
- Layer 5: `5:DRIFT:<function-name>` (e.g., `5:DRIFT:sync-to-airtable`)
- Layer 6: `6:PENDING_APPLY:<migration-name>`

If finding-key matches a non-expired entry in the suppress map, render as:
```
  [SUPPRESSED] <original-line> — reason: <reason> (expires <ts>)
```
NOT counted in the layer's issue count. NOT counted in the total. Auto-purge expired entries (write back the cleaned suppress.json in Phase 8).

**Output format** — punch-list:

```
🚧 Fleet Audit — <timestamp> — <duration>s

LAYER 1 (worktrees): 2 issues
  [DIRTY] /Users/justin/code/buybox-comp-frontend  3 uncommitted
    fix: cd /Users/justin/code/buybox-comp-frontend && git status

LAYER 2 (branches): 1 issue
  [AHEAD] feat/foo 3 commits not pushed
    fix: git push origin feat/foo

LAYER 3 (PRs): 1 issue
  [MERGED_NOT_CLEANED] PR #481 "Track 1: match_score truthiness fix" merged 4 days ago — worktree at /Users/justin/code/buybox-track1, branch feat/track1
    fix: git worktree remove /Users/justin/code/buybox-track1 && git branch -D feat/track1 && git push origin --delete feat/track1

LAYER 5 (edge function drift): 1 issue
  [DRIFT] sync-to-airtable — main 2 commits ahead of deployed
    fix: supabase functions deploy sync-to-airtable --project-ref {{supabase_project_ref}}

LAYER 6 (migration drift): 0 issues — ✓ clean

LAYER 4: ⏳ queued v1.2

Summary: 4 issues across 4 layers. Run the 4 fix commands above to clean.
Fleet integrity score: 6/10
```

If zero issues across all enabled layers, output ONE line:
```
✓ Fleet clean — <duration>s — last verified <timestamp>
Fleet integrity score: 10/10 ✓
```

**Fleet integrity score** (decision 4.1): `score = max(0, 10 - total_issues_across_enabled_layers)`. Surfaced for daily-plan NSM-rank integration.

### Phase 8 — Persist + return
1. Write JSON summary to `.claude/verify-shipped-last-run.json` (canonical path) with extended schema:
   ```json
   {
     "schema_version": "v1.1",
     "timestamp": "<ISO-8601 UTC>",
     "duration_ms": <int>,
     "tier": "quick|full|deep",
     "interrupted": false,
     "session_uuid": "<claude session id>",
     "layers": {
       "1": { "issues": <int>, "details": [...], "duration_ms": <int> },
       "2": { "issues": <int>, "details": [...], "duration_ms": <int> },
       "3": { "issues": <int>, "details": [...], "duration_ms": <int> },
       "5": { "issues": <int>, "details": [...], "duration_ms": <int> },
       "6": { "issues": <int>, "details": [...], "duration_ms": <int> }
     },
     "exit_code": <0|1|2>,
     "fleet_integrity_score": <0-10>,
     "punch_list_summary": "<one-line summary>",
     "suppressed_count": <int>
   }
   ```
2. Update `.claude/verify-shipped-last-run.txt` with timestamp (Unix epoch — used by older code paths)
3. **Write back purged suppress.json** if any expired entries were removed in Phase 7
4. **Release lock**: `rm -rf .claude/verify-shipped.lock` (already trapped on EXIT/INT/TERM in Phase 0; this is the explicit release on success)
5. **Interrupt-safe write**: on INT/TERM mid-run, write partial state with `"interrupted": true`. The trap clears the lock + writes the interrupted state file before exit. `read-state.sh` treats interrupted state as "stale" and triggers refresh.
6. Exit code: `0` if clean, `1` if any DIRTY/DRIFT/AHEAD/STALE_OPEN_PR/MERGED_NOT_CLEANED/etc., `2` if any layer errored

---

## Composition with /autovibe + /daily-plan + /ship

See `references/integration.md` for full hook-points + state-file contract + suppress-file format. Quick reference:

| Caller | When | Tier | Wall-clock budget |
|---|---|---|---|
| `/autovibe` Phase 4.5 | After `/ship` exits 0, before Session Learning Gate | `quick` | <20s on 50-worktree fleet |
| `/daily-plan` Phase 1.5 | First state ingest, before NSM ranking | reads cached state if <24h fresh; else `quick` | <1s warm cache, <12s cold |
| `/ship` | NOT auto-invoked — `/ship` is single-branch by design | n/a | n/a |
| Manual | Pre-demo, post-merge-spree, morning routine | full or `deep` | up to ~3min on `deep` |

**Graceful degradation contract** — both autovibe Phase 4.5 and daily-plan Phase 1.5 NEVER block on /verify-shipped failure:
- If lock held by another session: read cached state via `read-state.sh --max-age 0` and continue.
- If state-file missing or malformed: log `[INFO]` and continue without fleet status.
- If layer errors: degrade per-layer; never abort the caller.

---

## What this skill is NOT

- **Not a fix executor** — it produces commands, doesn't run them. User confirms each fix per `operational-guardrails.md` Confident Mode.
- **Not a continuous canary** — runs on-demand or composed, not as a cron. (A pg_cron canary for Layer 5 specifically is queued as a future operability extension.)
- **Not a replacement for hookify guards** — `worktree-guard.sh`, `commit-guardian.sh`, `supabase-migration-guard.sh` fire pre-action; this skill scans existing state.
- **Not for marketing pages or admin pages** — git/deploy fleet only. Frontend route audits are out of scope.

---

## Failure precedents (the doctrine this skill exists to enforce)

- **2026-05-03 CM.47e** — PR #420 merged frontend pill at 15:42:10 UTC; PR #402 (enricher cascade flip) closed 38s later assuming "merge = deploy." Schema + frontend went live; enricher cascade flip did NOT (no `supabase functions deploy`). Partners saw wrong final_sqft / final_arv (Cedar Hurst $2.27M ARV) for hours. Layer 5 of this skill catches this class.
- **2026-05-06 Wave G** — verify_jwt regression caught at 14:25 UTC because Supabase CLI default flipped post-deploy. Hookify rule `supabase-deploy-config-toml-lockstep.local.md` prevents at action-time; Layer 5 catches at audit-time if rule was bypassed.
- **Pre-2026-05-07** — no doctrinal canary watched edge-function-source-vs-deployed drift. This skill closes that gap.

---

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| **v1.0** | Layers 1, 5, 6 + composition stubs | ✅ shipped 2026-05-07 (PR #492) |
| **v1.1** | Layers 2 + 3 + parallel-session lock + suppress-file + autovibe Phase 4.5 + daily-plan Phase 1.5 | ✅ THIS SESSION |
| **v1.2** | Layer 4 (Vercel deploy lag) | Queued — auth-surface proof-out done in v1.1 (`references/v2-queued.md`) |
| **v2.0** | Auto-fix mode (`--auto-deploy-edge-fn-drift` flag) gated by Confident Mode HARD STOP | Speculative |
| **v3.0** | pg_cron canary for Layer 5/6 (every 6h, alerts on Telegram) | Speculative — operate-cost lens |

---

## References

- `references/edge-fn-drift.md` — Layer 5 detailed recipe + edge cases
- `references/migration-drift.md` — Layer 6 detailed recipe + edge cases
- `references/pr-fleet.md` — Layer 3 detailed recipe + cross-reference logic (v1.1)
- `references/v2-queued.md` — Layer 4 specification + acceptance criteria for v1.2
- `references/integration.md` — composition with /autovibe, /daily-plan, /ship + suppress-file format + state-file contract
- `scripts/walk-worktrees.sh` — Layer 1 implementation
- `scripts/walk-branches.sh` — Layer 2 implementation (v1.1)
- `scripts/read-state.sh` — state-file read primitive (v1.1) — used by autovibe + daily-plan
- `loading-state-invariants.md` Invariant 7 — partner-facing data-fidelity merge gate (the doctrinal witness)
- `operational-guardrails.md` Confident Mode — fix execution gating
