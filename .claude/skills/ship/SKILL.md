---
name: ship
description: |
  Autonomous code-ship skill with tiered modes (quick/pr/hotfix). Auto-detects
  mode from git state, applies pre-flight gates (filesystem path, disk free,
  stale locks, typecheck), snapshots before destructive sub-ops, and composes
  existing guardrails (worktree-guard, bash-guardian, commit-guardian,
  verify-pipeline, e2e-quick). Dual-use: same code path serves direct human
  invocation and future Autovibe orchestrator (state file is the contract,
  not the caller identity). Use when: /ship, "ship this", "commit and push",
  "open a PR for this", "hotfix to prod".
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
user-invocable: true
version: 1.0.0
classification: encoded-preference
status: Full build (quick + pr + hotfix modes; auto-rollback wired)
---

# /ship — Autonomous Code-Ship Workflow

> **Philosophy**: Pre-flight gates prevent regrets. Compose existing infra. State file is the contract. Snapshot before destructive. Auto-detect mode; cascade confident.

**Supersedes**: `/vercel:deploy` (35-line `vercel --prod` only — insufficient for 2026-04-19-class failure prevention).

---

## Phase Status

| Phase | Modes | Status |
|-------|-------|--------|
| **A** | `quick` | **Shippable.** Pre-flight + commit + push. |
| **B** | `pr` | **Shippable.** Adds `gh pr create`, `ci-watch.sh` (15m timeout + exit 9 unknown), admin-merge heuristic on Playwright flake, `smoke.sh` with Vercel auth pre-check + retry+backoff. |
| **C** | `hotfix` + auto-rollback | **Shippable.** Adds force-T3 verify-pipeline, `auto-rollback.sh` with squash-conflict enumeration + 3-path recovery. Auto-rollback fires WITHOUT confirmation on hotfix (confident cascade). |

**Non-shippable fixes from council 2026-04-19 — all resolved in this build**:
- FLAG 1 (smoke auth disambiguation): `smoke.sh` pre-checks `vercel whoami`; missing `x-vercel-git-commit-sha` → exit 9 UNVERIFIABLE (do NOT rollback)
- FLAG 2 (lock zombie recovery): handled via the 10-min TTL auto-expire in `lock.sh` + explicit `rm -rf` recovery command in the exit-5 collision message. **NOTE**: traditional shell `trap` handlers cannot fire across independent Bash tool invocations (each tool call is a fresh subshell), so the documented trap approach is not achievable in this execution model — TTL + loud collision recovery is the implemented mechanism. MTTR on a zombie lock is bounded by TTL (10 min) or a one-command manual `rm`
- FLAG 3 (ci-watch timeout): `ci-watch.sh` wraps `gh pr checks --watch` with portable `timeout`/`gtimeout`/manual-kill fallback + distinct exit 9
- FLAG 5 (snapshot TTL): `preflight.sh` runs `find ~/.claude-ship-snapshots -mtime +7 -delete` every invocation

---

## Dispatch

| Invocation | Action |
|---|---|
| `/ship` (no args) | Run `detect-mode.sh` → dispatch to detected mode |
| `/ship quick` | See `modes/quick.md` |
| `/ship pr` | See `modes/pr.md` — PR + CI watch + admin-merge heuristic + smoke |
| `/ship hotfix` | See `modes/hotfix.md` — force-T3 + auto-rollback on smoke fail |
| `SHIP_DRYRUN=1 /ship ...` | Full command preview, execute nothing |
| `/ship --format=json ...` | Machine-readable output (for Autovibe; human default is prose) |
| `/ship --caller=<name> ...` | Logging only; does NOT branch internal logic |
| `/ship --no-push` | Run all checks, report, stop before push |

---

## Mode Detection (ASCII decision tree)

`scripts/detect-mode.sh` emits `quick|pr|hotfix|ambiguous|detached` on stdout + reason on stderr. Exit 0 always (ambiguity is data, not error).

```
detect-mode.sh
├── HEAD is detached                                → detached (halt; checkout branch first)
├── Current branch == main                          → hotfix-guard (halt; hotfix must be explicit)
├── Explicit mode passed (quick|pr|hotfix)          → honor, skip detection
├── Dirty tree + no open PR for current branch      → quick
├── Dirty tree + open PR for current branch         → pr (amend flow, Phase B)
├── Clean tree + branch ahead of origin             → pr (push existing commits, Phase B)
├── Clean tree + branch even with origin + open PR  → pr (CI watch / merge, Phase B)
└── Any other state                                 → ambiguous (one-sentence ask w/ recommendation)
```

**Behavior across modes**:
- `detached` → halt exit 1 ("checkout a branch first")
- `hotfix-guard` (on main/master) → halt exit 1 ("hotfix must be explicit — use `/ship hotfix`")
- `ambiguous` → one-sentence ask with recommendation, then proceed on user choice
- `quick`/`pr` → dispatch directly
- `hotfix` → only reachable via explicit `/ship hotfix` invocation

---

## Invocation Model (Dual-Use)

Two callers share ONE code path. Only the output serializer differs.

| Flag | Human default | Autovibe (future) |
|---|---|---|
| Output | Prose summary | `--format=json` — structured lines |
| Cascade | Confident-mode cascade (user "ship it" authorizes flow) | Pre-authorized same way |
| Pre-flight | Always runs | Always runs (no "trust caller" shortcut) |
| State | Writes `.claude/ship-state.json` | Reads/writes same file |

**Exit codes** (stable contract — both callers):

| Code | Meaning |
|---|---|
| 0 | Shipped |
| 1 | Pre-check failed (path, disk, tsc, detached HEAD, unimplemented mode) |
| 2 | CI failed (Phase B/C) |
| 3 | Deploy failed (Phase C) |
| 4 | Post-deploy smoke failed; auto-rollback fired (Phase C) |
| 5 | Halted — another `/ship` holds the lock on this PR/commit |
| 6 | Halted — user/filesystem blocker (iCloud path, multi-open-PR, corrupt lock) |

---

## Lock Contract (`.claude/ship-state.json` + `.claude/ship-state.lock/`)

**Design decision (council 2026-04-19)**: atomic `mkdir` as lock primitive (NOT JSON-write). `mkdir` is atomic on APFS and every POSIX fs. The JSON file carries metadata only; the lock IS the directory.

**Scope**: lock is keyed by `pr_number` for Phase B/C and by `commit_sha` for Phase A. Two `/ship` on DIFFERENT commits proceed in parallel.

**TTL**: 10 minutes on `started_at`. ALSO bounded on upper end: if `started_at > now + 60min`, treat as corrupt (clock skew) and halt with exit 6.

**Zombie lock recovery**: a traditional `trap 'lock.sh release' INT TERM EXIT` would only work inside a single bash invocation — but each Claude Code Bash tool call starts a fresh subshell, so an acquire-then-^C-then-next-call sequence cannot be trapped. The real recovery mechanism is the **TTL (10 min)** combined with the **collision message** (exit 5): when a second `/ship` finds a held lock, the stderr explicitly includes the one-line `rm -rf .claude/ship-state.lock .claude/ship-state.json` recovery so the user can bypass TTL if they know the prior session crashed. Maximum user-visible MTTR: TTL (passive) or 5-second manual recovery (active).

**Corrupt-lock behavior**: zero-byte / unparseable JSON / missing required fields = halt with exit 6 and explicit "inspect `.claude/ship-state.json` before removing" — never silently proceed.

**Schema** (`.claude/ship-state.json` — provisional; not a permanent Autovibe API):
```json
{
  "pr_number": null,
  "session_uuid": "<claude session id>",
  "caller": "human|autovibe",
  "started_at": "<iso8601 UTC>",
  "current_step": "prechecks|push|pr_create|ci_watch|merge|deploy_watch|smoke|complete",
  "commit_sha": "<sha>",
  "tier_results": {"T1": "pass|fail|skipped", "T2": "...", "T3": "..."},
  "completed_at": null,
  "exit_code": null
}
```

---

## Composition Inventory (compose, don't rebuild)

| Asset | Path | Role |
|---|---|---|
| `path-check.sh` | `scripts/path-check.sh` | iCloud/OneDrive/Dropbox/tmp detection + `~/code/` redirect. Pre-built. |
| `worktree-guard.sh` | `../../hooks/worktree-guard.sh` | PreToolUse Bash hook — stale-lock scan + worktree reminder. Registered 2026-04-19. |
| `bash-guardian.sh` | `../../hooks/bash-guardian.sh` | Blocks `git push --force` / `rm -rf` / `reset --hard`. `/ship` uses plain `git push` for normal flows (revert is fast-forward); `--force-with-lease` reserved for explicit pr-mode amend flow + the user-invoked manual recovery option B in `auto-rollback.sh` conflict-path documentation. |
| `commit-guardian.sh` | `../../hooks/commit-guardian.sh` | Blocks staged debug artifacts + `.env` + large files. Inherits automatically on `git commit`. |
| `/verify-pipeline` | `../verify-pipeline/` | T1/T2/T3 regression. `pr` mode reads `.claude/verify-pipeline-state.json` to skip redundant tiers; `hotfix` mode ALWAYS forces fresh T3 (never skips). |
| `/e2e-quick`, `/e2e-test` | `../e2e-*/` | Invoked by `pr` mode on UI-diff or critical-path changes. |
| `superpowers:using-git-worktrees` | plugin | Worktree creation wrapped (not rebuilt) when `pr` or `hotfix` needs a fresh worktree from main. |
| `scripts/snapshot.sh` | local | Capture tracked+modified + untracked files to `~/.claude-ship-snapshots/<ts>/` before any destructive sub-op. TTL-cleaned by preflight. |
| `scripts/ci-watch.sh` | local | `gh pr checks --watch` wrapper with 15m timeout + exit 9 UNKNOWN. |
| `scripts/smoke.sh` | local | Post-deploy Vercel pre-check + HTTP 200 + sha-header match + 3× retry with 10s backoff. |
| `scripts/auto-rollback.sh` | local | `git revert <sha>` + push + squash-conflict enumeration + 3-path recovery. |

---

## Constraints (from council 2026-04-19 + design spec)

**NEVER**:
- Work from `~/Documents/GitHub/` or any iCloud/OneDrive/Dropbox path (`path-check.sh` halts with exit 6)
- `git push --force` — always `--force-with-lease` (`bash-guardian.sh` blocks plain `--force`)
- `git checkout --ours/--theirs` on code files (`.ts, .tsx, .js, .sql, .py`) during rebase — rebase semantics are reversed from merge; auto-resolution in this direction fires hook cascades and corrupts state
- Mark work complete without `git status` + `git log --oneline -3` verification

**ALWAYS**:
- Pre-flight disk ≥5GB free on `/System/Volumes/Data` (APFS CoW degrades past 90%)
- `path-check.sh` of `$PWD` before any git write
- Stale-lock scan on `.git/` (`find .git -name "*.lock" -mmin +10`)
- Snapshot at-risk files to `~/.claude-ship-snapshots/<ts>/` before destructive sub-ops; TTL-cleanup >7 days old on every preflight
- Lock zombie protection: TTL-based (10 min) + explicit manual-recovery command in collision message — traps are not viable across Claude's independent Bash invocations
- Emit rollback hint in output (`git revert <sha>` for merged commit — Phase B/C)

---

## Hook Registration (follow-up)

`worktree-guard.sh` is registered in **`.claude/settings.local.json`** (per-machine, gitignored). To share across the team, a human must manually add the same PreToolUse Bash entry to `.claude/settings.json` (shared). Agent-driven writes to the shared settings file are blocked by self-modification guardrails (by design). Suggested shared entry:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/worktree-guard.sh", "timeout": 5}
        ]
      }
    ]
  }
}
```

## Rollback (if `/ship` itself misbehaves)

1. `rm -rf .claude/skills/ship/SKILL.md` — skill unregistered, `/vercel:deploy` plugin still works
2. Remove `worktree-guard.sh` entry from `.claude/settings.local.json` PreToolUse Bash array if it misfires
3. `rm -rf .claude/ship-state.lock/ .claude/ship-state.json` — clears stale lock (also auto-clears on 10-min TTL)
4. Hooks `bash-guardian` / `commit-guardian` are untouched — unaffected by rollback

Zero blast radius outside `.claude/skills/ship/` + one array entry in `settings.local.json`.

---

## References

- **Design spec**: `continuations/SHIP-SKILL-DESIGN-FORGED-2026-04-19.md`
- **Implementation plan**: `/Users/justin/.claude/plans/ethereal-seeking-pizza.md`
- **Council deliberation**: `council/sessions/2026-04-19-ship-skill-plan-deliberation.md`
- **Failure inventory**: `.claude/skills/ship/references/failure-inventory.md`
- **Worktree discipline**: `.claude/rules/worktree-discipline.md`
