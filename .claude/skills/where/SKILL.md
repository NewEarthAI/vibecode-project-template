---
name: where
description: One plain-English answer to "where is all my work right now?" across every NewEarth repo. Live-derives from git only (worktrees, dirty state, ahead/behind, open PRs) — never a written registry, cannot lie. Detects FILE-LEVEL collisions between parallel sessions. Use when - "/where", "where is everything", "what's running", "any collisions", "am I about to clash with another chat", before opening a new parallel session, before an unattended /autovibe run.
---

# /where — the live state surface

> Git is the only source of truth that cannot lie. `/where` reads it live, every time.
> No written registry, no daemon, no cache. Composes `verify-shipped`'s worktree walker.

## What it answers

For every known NewEarth repo, in plain English:

- Which worktrees exist, and for each: is it clean or has unsaved work, is it ahead of /
  behind GitHub, is it heading for live (production branch) or a work-in-progress branch.
- **The collision question**: is any single file being changed in two worktrees at once?
  That is the silent-corruption case branch-level views miss — `/where` compares each
  worktree's changed-file list and warns by filename.
- Open pull requests per repo (degrades gracefully if GitHub CLI is unauthenticated).

## Invocation

| Command | Effect |
|---|---|
| `/where` | Full fleet status, layman output |
| `bash .claude/skills/where/scripts/where.sh` | Same, direct script |
| `WHERE_REPOS="/path/a:/path/b" /where` | Override the repo set |

A `.claude/where-repos.txt` file (one absolute repo path per line) overrides the built-in
default set if present. That file is plain config — it drives no automated decision and
holds no session state.

## Design invariants (locked by council 2026-05-19)

1. **Tool-blind**: reads git only — identical output whether launched from the Cursor
   extension, cmux, or a plain terminal. No session/tool detection anywhere.
2. **Compose, don't rebuild**: the per-worktree DIRTY/STALE/ahead-behind walk is
   `verify-shipped/scripts/walk-worktrees.sh`. `/where` only adds the net-new cross-repo
   loop, the file-level overlap intersection, and the layman translation.
3. **Cannot lie**: every line is derived from a fresh `git` read at invocation time.
4. **Read-only**: `/where` never writes, never removes, never mutates. The cleanup sibling
   is `sweep-stale-worktrees.sh` (separate, guarded, dry-run by default).

## Companion

- `scripts/sweep-stale-worktrees.sh` — the guarded janitor (clean ∧ merged ∧ old ∧
  heartbeat-stale ∧ disk-OK before it will remove anything; dry-run unless `--apply`).
  **ARMED 2026-05-25**: Check 4 reads a per-worktree session HEARTBEAT (a UTC timestamp the
  SessionStart hook `sessionstart-context-aggregator.sh` writes to
  `<primary>/.claude/worktrees/<basename>.heartbeat` every session start). A worktree
  untouched by any session for >48h (`--stale-hours N` to change) is heartbeat-STALE and —
  only in combination with clean+merged+old — eligible for removal. Heartbeat, NOT PID: a
  SessionStart hook is a throwaway subprocess whose `$$` dies instantly, so timestamp-
  freshness is the correct cross-boundary signal. **Grace (council 2026-05-25, option b)**:
  a worktree with NO heartbeat file (pre-existing / never-session'd) is treated as LIVE and
  never auto-removed — the heartbeat file itself is the "born into the heartbeat era" marker,
  so pre-existing folders stay manual-only with no unreliable mtime guessing. **--apply is
  human-invoke ONLY**: every automated surface shows the dry-run "WOULD remove" list; actual
  removal always needs a human to type `--apply`. Fail-safe parse: an empty/garbage/future-
  dated heartbeat is treated as LIVE, never ancient-eligible. Self-test: `--self-test`.
- `.claude/rules/session-environment-policy.md` — the policy that keeps this surface
  trustworthy (code work happens in the terminal, where git worktrees live).
- `.claude/hooks/sessionstart-context-aggregator.sh` — writes the heartbeat (the READ half is
  the janitor's Check 4) AND auto-surfaces this `/where` collision view at every session
  start: a LOUD ⚠️ hoisted to the top of the briefing on a real two-worktree same-file clash,
  a quiet 🟢 all-clear otherwise.
