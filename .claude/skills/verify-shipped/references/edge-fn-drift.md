# Layer 5 — Edge Function Source-vs-Deployed Drift

The silent killer. PR merges to main do NOT auto-deploy edge functions on this repo. The `supabase functions deploy <name>` command is manual. Every time it's forgotten, partner-facing logic stays on the OLD code — silently — until someone notices.

Codified in `loading-state-invariants.md` Invariant 7. Witnessed at:
- 2026-05-03 CM.47e — Cedar Hurst $2.27M ARV
- 2026-05-06 Wave G — verify_jwt regression

This is the most-load-bearing layer of `/verify-shipped`.

---

## Recipe (Claude executes from the conversation)

### Step 1 — List source dirs on main

```bash
cd /Users/justin/code/a SaaS app
git fetch origin main --quiet
find supabase/functions -mindepth 1 -maxdepth 1 -type d \
  ! -name '_*' \
  ! -name 'debug-*' \
  ! -name '.*' \
  | xargs -n1 basename
```

Excludes:
- `_shared/` — not a deployable function (helper module)
- `_*` — convention for non-deployable helpers
- `debug-*` — temporary, per `debug-echo-edge-function-pattern.md` (these get deployed + deleted within a session)
- Hidden dirs

### Step 2 — Get last-modified-on-main timestamp per function (DIRECTORY scope, not just index.ts)

For each `<name>` from Step 1:

```bash
git log -1 --format=%ct origin/main -- supabase/functions/<name>/ 2>/dev/null
```

**Trailing slash matters** — picks up the most-recent commit touching ANY file in the function dir, not just `index.ts`. This catches helper-only changes (e.g., a fix to `lib.ts` that doesn't touch `index.ts`) which would otherwise produce a silent "OK" verdict against an actually-stale deployed version. Fixing this was a council-CRITICAL finding 2026-05-07.

`%ct` returns Unix epoch (seconds). If the directory doesn't exist on `main` (new function not yet merged), the command returns empty — handled in Step 4's three-state classification.

Capture as a map: `function_name → last_main_commit_epoch | null`.

### Step 3 — Get deployed updated_at per function

ONE MCP call:

```
mcp__supabase-{{project}}__list_edge_functions
```

Response shape (per Supabase API):
```json
[
  { "slug": "process-submission", "updated_at": "2026-05-06T14:25:13Z", "version": 12, ... },
  ...
]
```

Capture as a map: `slug → deployed_updated_at_epoch`. Convert `updated_at` ISO timestamp to epoch via:

```bash
date -j -f "%Y-%m-%dT%H:%M:%SZ" "2026-05-06T14:25:13Z" "+%s"
# macOS BSD date syntax. Linux: date -d "2026-05-06T14:25:13Z" "+%s"
```

(Claude can also do this conversion in-conversation without bash.)

### Step 4 — Diff with grace window

For each source `<name>` AND each deployed `slug`, classify:

| Source state | Deployed state | Verdict |
|---|---|---|
| `main_ts` exists, `deployed_ts` exists, `main_ts > deployed_ts + 60s` | main is ahead | **DRIFT** |
| `main_ts` exists, `deployed_ts` exists, `main_ts <= deployed_ts + 60s` | within grace window | **OK** |
| `main_ts` exists, `deployed_ts` does NOT exist | on main, never deployed | **NEVER_DEPLOYED** (rare; usually shipped immediately) |
| `main_ts` does NOT exist, `deployed_ts` exists, source dir present locally | local-only WIP source + production-deployed function | **ORPHAN_DEPLOYED** (deployed without a main commit — Dashboard upload OR pre-history function. Flag, do NOT auto-delete) |
| `main_ts` does NOT exist, `deployed_ts` does NOT exist | new local-only WIP | skip — not yet on main, not yet deployed |
| Source dir gone locally + on main, `deployed_ts` exists | orphan deployed (post-deletion) | **ORPHAN_DEPLOYED** (flag, do NOT auto-delete) |
| `deployed_ts` newer than `main_ts + 60s` | deployed is ahead of main | **DEPLOYED_AHEAD** (Dashboard hotfix OR rollback — informational, NOT a drift; this skill does not detect divergent-from-main, only stale-from-main) |

The 60-second grace window absorbs:
- Clock skew between local + Supabase
- Same-second deploys where the API returns the deploy completion timestamp slightly after the git commit timestamp
- CI lag if deploys are scripted

### Step 5 — Output

Per drift:
```
[DRIFT] <name> — main commit <main_iso> > deployed <deployed_iso> (<delta>s ahead)
  fix: supabase functions deploy <name> --project-ref {{supabase_project_ref}}
```

Per never-deployed:
```
[NEVER_DEPLOYED] <name> — on main since <main_iso>, no deployed version
  fix: supabase functions deploy <name> --project-ref {{supabase_project_ref}}
```

Per orphan:
```
[ORPHAN_DEPLOYED] <name> — deployed but no source on main; verify intentional
  fix (only if intentional): supabase functions delete <name> --project-ref {{supabase_project_ref}}
```

---

## Edge cases + gotchas

1. **`config.toml` lockstep**: when an edge function changes `verify_jwt` posture, the deploy MUST include the matching `[functions.<name>] verify_jwt = false` block in `supabase/config.toml`. The hookify rule `supabase-deploy-config-toml-lockstep.local.md` warns at action-time. This skill could ALSO check at audit-time — TODO future enhancement.

2. **Multi-file edge functions** — FIXED in Step 2 above (directory-scope git log). The recipe now picks up the most-recent commit on ANY file in the function dir, including helpers. No mitigation needed.

2b. **Dashboard-uploaded hotfix**: if someone uploaded code via the Supabase Dashboard (not git → CLI), `deployed_ts` reflects the upload moment. If `deployed_ts > main_ts`, this skill emits **DEPLOYED_AHEAD** (informational). It does NOT detect that the deployed code may DIVERGE from main (different content). This is an explicit scope limitation: this skill catches stale-from-main, not divergent-from-main. If divergence detection becomes a real concern, it goes in v2.0+ (would need content-hash comparison via `ezbr_sha256`).

3. **`debug-*` functions**: per `debug-echo-edge-function-pattern.md`, these are temporary diagnostic functions. They SHOULD be deleted from both source AND deployed state within a session. If audit finds a `debug-*` source dir on main, that's a separate violation (not handled here).

4. **Branch != main**: source-of-truth is `origin/main`, NOT the current worktree's HEAD. Functions on a feature branch that haven't merged yet are NOT drift — they're work-in-progress.

5. **Supabase API rate limits**: `list_edge_functions` is one call returning all functions. No pagination concern at current scale (~30 functions).

---

## Composes with

- `loading-state-invariants.md` Invariant 7 — the doctrinal witness
- `supabase-deploy-config-toml-lockstep.local.md` hookify rule — prevents verify_jwt regression at action-time
- `debug-echo-edge-function-pattern.md` — explains why `debug-*` is excluded
- `agentic-loop-guards.md` Pre-Exit Verification — claim-with-evidence (deployed_at must match main_ts)

## Future enhancements (queued)

- Multi-file edge function drift detection (helpers + index)
- `config.toml` verify_jwt audit for every function
- pg_cron canary that runs Layer 5 every 6h and alerts on Telegram if drift detected
- Auto-deploy mode behind explicit `--auto-deploy` flag (gated by Confident Mode HARD STOP — production deploy is irreversible-class)
