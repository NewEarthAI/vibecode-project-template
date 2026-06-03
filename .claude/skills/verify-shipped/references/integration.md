# /verify-shipped Composition with /autovibe, /daily-plan, /ship

How `/verify-shipped` plugs into the existing skill ecosystem.

---

## /autovibe Phase 4.5 (post-ship hook)

**Where**: `autovibe/SKILL.md` between Phase 4 (Post-Push Documentation Step) and Phase 5 (Session Learning Gate). Specifically: AFTER `/ship` exits 0 and the post-push doc is written; BEFORE the Session Learning Gate evaluation.

**What autovibe does**:
1. Read `.claude/ship-state.json` for the just-shipped artefacts (existing — already implemented)
2. Append session entry to `.claude/autovibe-sessions/<ts>.md` (existing)
3. **Phase 4.5 NEW**: try to read cached fleet state via `bash .claude/skills/verify-shipped/scripts/read-state.sh --max-age 0`
   - If the read returns a result fresher than 60 seconds (we just shipped — anything older is suspect), treat it as a hit and log `fleet status from cache`
   - Otherwise invoke `Skill verify-shipped quick` (Layers 1 + 6 only — Layer 5 was just affected by this very session's deploys, give it 30s buffer before next audit)
4. Parse the result:
   - On clean (`exit_code == 0`): log `fleet clean post-ship` and continue
   - On drift (`exit_code == 1`): append the punch-list to the autovibe session file AND surface to the user with prefix `🚧 shipped, but here's what else is loose:`
   - On error (`exit_code == 2`): log `fleet audit errored — continuing without fleet status` and continue (graceful degradation)
5. **Update Phase 5 trigger criteria**: ADD the row "fleet drift detected post-ship" to the Session Learning Gate evaluator. When fleet drift fires AND no other Phase 5 trigger fires, still invoke `/reflect` — the drift IS the learning.
6. Continue to Session Learning Gate

**Rationale**: shipping ONE PR doesn't guarantee the FLEET is clean. Other branches might be stale. Other migrations might be pending. The post-ship moment is when you're most-likely-to-act on a fix command.

**Tier choice**: `quick` — keeps autovibe under its existing wall-clock. `deep` would add 3 minutes to every autovibe run.

**Failure mode prevented**: ships PR #471, but PR #470's edge function never deployed because `supabase functions deploy` was forgotten. Without this hook, you wouldn't notice until the next morning's daily plan or a partner complaint. Cedar Hurst doctrine codifies this exact silent-killer class.

**Wall-clock budget**: <20s on Justin's 50-worktree fleet (autovibe hook MUST NOT block the post-ship flow significantly).

---

## /daily-plan Phase 1.5 (morning fleet snippet + NSM-rank integration)

**Where**: `daily-plan-generator/SKILL.md` between Phase 1 (state ingest) and the NSM-ranking pass. Specifically: AFTER existing context-loading; BEFORE work-item prioritisation.

**What daily-plan does**:
1. Try `bash .claude/skills/verify-shipped/scripts/read-state.sh` (default 24h staleness)
   - On exit 0: parse the returned JSON; use it directly
   - On exit 1 (missing/stale/interrupted): invoke `Skill verify-shipped quick` synchronously (~10s); re-read state
   - On exit 2 (malformed): log `[INFO] fleet state file malformed — skipping fleet section` and continue
2. **Render header snippet** at top of plan output (per master-continuation decision 4.1 — first-class signal, not decoration):

```
🚢 Shipping integrity: 7/10 (3 issues — 2 worktree, 1 PR, 1 deploy drift, last verified 2 hrs ago)
```

If clean:
```
🚢 Shipping integrity: 10/10 ✓ (last verified 2 hrs ago)
```

3. **Integrate fleet findings into NSM-impact ranking as candidate work items**. Each fleet finding becomes a work item with:
   - Verb-first label derived from the finding type:
     - `[DIRTY] /Users/justin/code/buybox-foo` → "Commit or stash 3 uncommitted changes in buybox-foo"
     - `[AHEAD] feat/bar 3` → "Push 3 unpushed commits on feat/bar"
     - `[STALE_OPEN_PR] PR #471` → "Decide on stale PR #471 (12 days no activity)"
     - `[MERGED_NOT_CLEANED] PR #481` → "Clean up merged-not-deleted worktree from PR #481"
     - `[DRIFT] sync-to-airtable` → "Deploy edge function sync-to-airtable to production"
     - `[PENDING_APPLY] <migration>` → "Apply pending migration <name> to production"
   - Effort tag: `[TRIVIAL]` for cleanup (push, branch -D, worktree remove); `[MODERATE]` for deploys + decisions
   - Action field: the exact fix command from the punch-list
   - NSM-impact weight: `severity × age_hours / urgency_decay`. Severity = 1.0 for DRIFT/PENDING_APPLY (production), 0.7 for AHEAD/STALE_OPEN_PR (work in progress), 0.3 for DIRTY/MERGED_NOT_CLEANED (housekeeping).
4. Suppressed findings (per `.claude/verify-shipped-suppress.json`) DO NOT appear as work items, but the suppress count is rendered in the header:
```
🚢 Shipping integrity: 8/10 (2 issues — 1 PR, 1 deploy; 3 suppressed)
```

**Rationale**: morning cadence is the natural moment to clean accumulated drift. Surfacing fleet items in NSM-rank means they compete fairly with feature work — Justin chooses based on impact, not whether the item happens to be visible.

**Failure mode prevented**: drift accumulates Mon-Fri until "Friday afternoon = surprise list of 12 things to fix before weekend." Daily snippet + ranking keeps awareness fresh AND makes triage automatic.

**Wall-clock budget**: <1s on warm cache (read-state.sh hits canonical, returns immediately); <12s on cold cache (10s for verify-shipped quick + 2s overhead).

---

## /ship (NOT invoked by ship)

**Why not**: `/ship` is single-branch by design. Calling `/verify-shipped` from `/ship` would couple `/ship`'s wall-clock to `/verify-shipped`'s plus inflate `/ship`'s mental model.

**Composition direction**: `/autovibe` calls BOTH `/ship` and `/verify-shipped`. `/ship` doesn't call `/verify-shipped`. Different jobs.

**Exception**: `/ship hotfix` mode is human-only AND production-emergency. `/verify-shipped` is read-only audit. Hotfix flow MIGHT benefit from a "before hotfix, what else is broken?" pre-flight — queue as v2.0 enhancement, not v1.0.

---

## Standalone (manual)

```
/verify-shipped            # auto-tier
/verify-shipped quick      # ~10s (Layers 1+6)
/verify-shipped deep       # ~3min (all layers, Vercel deep query)
/verify-shipped --layer=5  # single layer (e.g., edge fn drift only)
```

When to run manually:
- Pre-demo (before showing buyer or partner the live system)
- After a sprint of multiple PR merges (cumulative drift check)
- After "I think I shipped everything" — verify the claim
- When investigating "why is the partner seeing X?" — drift check is the first hypothesis

---

## Hookify rule (queued, not in v1)

A future hookify rule could fire `/verify-shipped quick` automatically on `Stop` event when the session committed migrations or edge functions. This catches drift the moment it's introduced. Queue as v2.0 — needs careful debouncing to avoid running on every Stop.

---

## State-file contract (v1.1 schema)

`/verify-shipped` writes:
- `.claude/verify-shipped-last-run.json` — full structured output (canonical path; consumed by `read-state.sh` + `/daily-plan` + `/autovibe`)
- `.claude/verify-shipped-last-run.txt` — Unix epoch timestamp (legacy field; some older code paths read this)

Defensive legacy fallback: `read-state.sh` will read `.claude/verify-fleet-last-run.json` if the canonical path is missing AND legacy is present. v1.0 always wrote canonical; this fallback is purely defensive (e.g., if a fork-of-this-skill ever wrote legacy in another repo).

Schema (v1.1 — extends v1.0 with named field `schema_version`):

```json
{
  "schema_version": "v1.1",
  "timestamp": "2026-05-07T14:42:00Z",
  "duration_ms": 9421,
  "tier": "quick",
  "interrupted": false,
  "session_uuid": "abc-123",
  "layers": {
    "1": { "issues": 2, "details": [...], "duration_ms": 8120 },
    "2": { "issues": 1, "details": [...], "duration_ms": 380 },
    "3": { "issues": 1, "details": [...], "duration_ms": 3120 },
    "5": { "issues": 1, "details": [...], "duration_ms": 1101 },
    "6": { "issues": 0, "details": [], "duration_ms": 200 }
  },
  "exit_code": 1,
  "fleet_integrity_score": 6,
  "punch_list_summary": "5 issues across 4 layers",
  "suppressed_count": 0
}
```

Stable contract — `/daily-plan` and `/autovibe` parse this format. Don't break it without bumping `schema_version`. v1.0 readers that miss `schema_version` should default to v1.0 semantics (Layers 1+5+6 only, no fleet_integrity_score).

**Interrupted runs**: when `/verify-shipped` is killed mid-flight (INT/TERM), the trap-on-EXIT writes a partial state file with `"interrupted": true`. `read-state.sh` returns exit 1 on interrupted state; the caller will refresh on next read.

---

## Suppress-file format

Optional file at `.claude/verify-shipped-suppress.json`. Used to silence known-working-on-it findings without alert fatigue (e.g., Wave B.1 phase 0 pending Justin authorisation — don't surface it again every audit).

Format:

```json
{
  "1:DIRTY:/Users/justin/code/buybox-foo": {
    "suppressed_until": "2026-05-14T00:00:00Z",
    "reason": "Wave 3a in flight; will commit when council session completes",
    "added_by_session": "2026-05-07-session-uuid"
  },
  "5:DRIFT:experimental-fn": {
    "suppressed_until": "2026-05-21T00:00:00Z",
    "reason": "intentionally main-ahead — testing locally before deploy",
    "added_by_session": "2026-05-07-session-uuid"
  }
}
```

**Key format**: `<layer>:<status>:<identifier>`
- Layer 1: `1:<status>:<path>` — e.g., `1:DIRTY:/Users/justin/code/buybox-comp-frontend`
- Layer 2: `2:<status>:<branch>` — e.g., `2:AHEAD:feat/foo`
- Layer 3: `3:<status>:<pr-number>` — e.g., `3:STALE_OPEN_PR:471`
- Layer 5: `5:DRIFT:<function-name>` — e.g., `5:DRIFT:sync-to-airtable`
- Layer 6: `6:PENDING_APPLY:<migration-name>` — e.g., `6:PENDING_APPLY:20260505000000_foo`

**Default expiry**: 7 days from add-time. `suppressed_until` MUST be present + parseable; missing or malformed = treat as expired = no suppression.

**Auto-purge**: every `/verify-shipped` run reads the suppress file, drops expired entries, writes back the cleaned file in Phase 8. Justin never has to manually clean expired suppressions.

**Adding entries**: today, hand-edit the JSON file. Future v1.2+ may add a `--suppress <key> --reason "..." --until 7d` flag to `/verify-shipped` for ergonomic add.

**Rendering**: matched findings render as `[SUPPRESSED] <original> — reason: <reason> (expires <ts>)` instead of `[ISSUE]/[DRIFT]`. NOT counted toward issue count or fleet_integrity_score.

**Why file-based**: env-var doesn't survive cross-Mac; session-scoped doesn't survive between sessions; file-based with explicit expiry is the only path that's both auditable AND self-cleaning. The file is gitignored (session state, not project doctrine).

---

## Lock contract (parallel-session safety)

`/verify-shipped` acquires a soft lock at `.claude/verify-shipped.lock/` via atomic `mkdir` (mirrors `ship/scripts/lock.sh` precedent — `mkdir` is POSIX-atomic, JSON-write is not).

**TTL**: 5 minutes. Matches the per-layer timeout-wrapper budget in `walk-worktrees.sh` × all layers. A genuinely stuck audit will be cleared on the next invocation.

**Acquisition flow** (Phase 0):
1. `mkdir .claude/verify-shipped.lock 2>/dev/null` — atomic; success = acquired, failure = held.
2. On acquisition: write `meta.json` inside the lock dir with `session_uuid` + `started_at`. Trap-on-EXIT/INT/TERM clears the dir.
3. On contention: check lock-dir mtime. If >5 min old, treat as stuck — `rm -rf` and re-acquire once.
4. If still contended after retry: degrade gracefully — call `read-state.sh --max-age 0` (read regardless of age) and emit `[INFO] Another session is running /verify-shipped; using cached state` to stderr. Exit with the cached state's exit code.

**Why this is wrong shape for read-lock or full mutex**:
- Read-lock would block parallel reads, but `/verify-shipped` writes (state file) — read-lock is wrong direction.
- Full mutex with no fallback would block autovibe + daily-plan when two chats run simultaneously — both surfaces are non-blocking by contract.
- Atomic-mkdir + degraded fallback is the right shape: the loser reads cached state and continues.

**Composition with autovibe + daily-plan**: both callers invoke `/verify-shipped` indirectly through the SKILL.md recipe. They don't need to know about the lock — the skill handles its own concurrency. If the skill returns cached state (because lock was held), the caller still gets a valid JSON result; the result was just from a previous run rather than a fresh audit.
