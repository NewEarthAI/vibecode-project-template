# Single-Folder Workflow (Worktree Discipline)

**Default**: one project folder, feature branches inside it. A worktree — a separate
on-disk folder holding its own checkout on its own branch — is the rare, explicitly
justified **exception** for genuine simultaneous parallel work. It is never the
per-job default.

**Origin (2026-05-18)**: Justin — *"i am sick of this weird worktree stuff i never
know what's going on where to keep track."* The prior doctrine told every shipping
flow (`/ship`, `/autovibe`, `/build-with-agent-team`) to spawn a fresh worktree per
job. The cleanup step fired unreliably and **102 worktrees accumulated**; an audit on
2026-05-18 removed 100 stale ones (committed work was preserved as branch refs). This
rule flips the default to single-folder + feature-branch so the count never climbs
again.

---

## The Rule

**One project folder: `~/code/BuyBox-AI`.** It is the canonical clone. Every job is a
feature branch *inside that one folder*:

1. Branch off `origin/main`
2. Commit
3. Push
4. Open PR
5. Merge (squash)
6. `git switch main`
7. Delete the merged branch

No new folders, ever. `git worktree list` stays at **1** (the primary) in steady state.

### Branch-prefix convention (added 2026-05-24)

Every branch carries a prefix that encodes its merge-intent state. The prefix IS the signal — no metadata to remember, no separate marker file. It lives in the branch name where every tool already sees it (`git branch`, `git log`, GitHub PR list, `/where` output).

| Prefix | Meaning | `/where` auto-flag |
|---|---|---|
| `feat/` `fix/` `chore/` `docs/` `infra/` `perf/` | **READY-by-default.** Default state. Operator merges when CI passes. Adoption rate already ~95% in this repo. | Flag forgotten at >14 days since last commit |
| `wip/` | **In-flight, actively iterating.** Not yet ready to merge. | Flag at >30 days |
| `park/<reason>` | **PARKED with intent.** Deliberately on hold pending external signal. The branch name encodes the reason — e.g. `park/wave-c-trevor-buyer-csv`, `park/matrix-stream-3-foundation`. | NEVER auto-flags. Operator owns reactivation. |
| `wreck/` `dump/` | **FORGOTTEN-permitted.** Experiments. Safe to force-delete. | Flag at >7 days — gentle prompt to rename OR delete. |

**The decision-rule for picking a prefix at branch-creation**:

- Default: `feat/<slug>` for new features, `fix/<slug>` for bug fixes, `docs/<slug>` for documentation, `chore/<slug>` for tooling / hygiene
- Use `wip/` ONLY when the branch will iterate for ≥30 days before merge AND the operator has consciously chosen "this is a long-running experiment, don't flag it for me"
- Use `park/` when the operator EXPLICITLY decides to defer a branch indefinitely — partner-data pending, gated on upstream arc, etc.
- Use `wreck/` or `dump/` for throwaway experiments that should NEVER ship

The convention is **forward-only** from 2026-05-24. Today's 296+ existing branches inherit grandfathered status; `/where` flags them by age + state alone (no prefix interpretation needed for pre-2026-05-24 branches).

**Per `decide-dont-menu-extended.md` Class A**: when a chat needs to name a new branch and no intent is specified, the codified default is `feat/<slug>`. The chat MUST NOT ask the operator to pick a prefix unless the operator's intent is genuinely ambiguous (e.g., the same diff could be a feat OR a chore depending on framing).

### Non-negotiable filesystem constraints (unchanged — still load-bearing)

1. **`~/code/` only — never `~/Documents/GitHub/`.** iCloud syncs `.git/index.lock` /
   `.git/HEAD` mid-write, causing 10–15 min zombie checkouts and `.git/index 2.lock`
   duplicate artifacts. Reads (`git log`, `git diff`, Grep) in an iCloud path are fine;
   branch-modifying ops are not.
2. **Never `/tmp/*`** — macOS tmpfs triggers git auto-lock; checkout hangs silently
   mid-populate.
3. The canonical clone lives at `~/code/BuyBox-AI`. If it is not there, clone it there.
   Do not work from a cloud-synced path.

---

## Starting a new job (the single-folder flow)

**Working tree clean:**

```bash
git fetch origin main
git switch -c feat/<slug> origin/main
# ...work, commit...
git push -u origin HEAD
# ...PR, merge...
git switch main && git pull --ff-only && git branch -d feat/<slug>
```

**Working tree dirty with *unrelated* WIP** (common when a long-running branch has
accumulated edits): stash first so the switch starts from a clean tree.

```bash
git stash push -u -m "park WIP for <slug>"
git switch -c feat/<slug> origin/main
# ...work, commit, push, PR, merge...
git switch <original-branch> && git stash pop
```

Stashing `-u` **before** the switch means the tree is empty at switch time — no
carry-over, no conflict. The `git stash pop` happens back on the ORIGINAL branch
(which has not moved), so it restores cleanly. This is the safe variant; the unsafe
one is in the pitfall section below.

### Pre-flight (before any branch-modifying git op)

**Disk:**

```bash
df /System/Volumes/Data | awk 'NR==2 {gsub(/%/,"",$5); if ($5>=90) exit 1}'
```

Exit non-zero (≥90% used) → halt. APFS copy-on-write corrupts `.git/index` past 90%.
Free space first (`~/.cache`, `~/Library/Caches`, npm + Playwright caches are
rebuildable).

**Stale locks:**

```bash
find .git -name "*.lock" -type f -mmin +10 2>/dev/null
```

Results → stale locks from a prior crash. Remove if >10 min old. `.git/index 2.lock`
is the iCloud "filename 2" duplicate — always safe to remove when stale.

---

## The stash-and-switch pitfall — `git checkout HEAD -- .` is the trap, not the stash

The single-folder flow stashes and switches routinely. That is fine **in the safe
order above** (stash `-u` FIRST → clean tree → switch → pop onto the original branch).

The trap is a DIFFERENT sequence: `git stash apply` AFTER switching, onto a branch
where the stashed files conflict. That leaves `UU` (both-modified) state, and the
instinct to clean it with `git checkout HEAD -- .` **reverts agent-generated edits to
tracked files** — untracked NEW files survive, modifications are lost.

- **DO** stash `-u` BEFORE switching (clean tree → no conflict possible).
- **DO** pop the stash back onto the branch it was created on (unmoved → clean restore).
- **DO NOT** `git stash apply` onto a different branch and then `git checkout HEAD -- .`
  to "clean up" — that is where edits vanish.
- If you hit a conflicted apply mid-stream: pull individual files with
  `git checkout stash@{N} -- <file>`, never `git checkout HEAD -- .`.

**Failure precedent (2026-05-05)**: a conflicted stash-apply followed by
`git checkout HEAD -- .` reverted 4 files of agent work; ~20 min recovery. The fix is
order discipline, not a worktree.

---

## node_modules

A fresh clone (and an exception worktree) does NOT have `node_modules`. Before
`npm run test` / `npx tsc` / `npm run build`:

- **Fresh clone**: `npm install`.
- **Exception worktree** on a branch with an identical `package-lock.json`: symlink is
  instant — `ln -sfn ~/code/BuyBox-AI/node_modules <worktree>/node_modules`.
- `git stash -u` stashes a symlinked `node_modules` too; re-create the symlink after
  popping.

---

## The exception — genuine simultaneous parallel work

A worktree is permitted ONLY when **two code-editing Claude sessions run at the same
time** and would otherwise fight over one working tree. Single-Mac sequential work
(Justin's norm — see `multi-session-arc-coordination.md` single-Mac calibration) never
needs one. If you are about to create a worktree and the work is sequential, stop —
use the single-folder flow above.

When the exception genuinely applies:

```bash
git fetch origin main
git worktree add ~/code/buybox-<slug> origin/main
cd ~/code/buybox-<slug> && git switch -c feat/<slug>
ln -sfn ~/code/BuyBox-AI/node_modules ./node_modules   # only if tests/build needed
```

### Mandatory cleanup — trap-registered, guaranteed on completion AND abort

The session that creates an exception worktree MUST register removal so it fires on
INT/TERM/EXIT — not "remember to clean up later", which is exactly the step that
failed 100 times:

```bash
cleanup() {
  rm -f ~/code/buybox-<slug>/node_modules
  git worktree remove --force ~/code/buybox-<slug> 2>/dev/null
  git worktree prune
}
trap cleanup INT TERM EXIT
```

After the run, verify `git worktree list | wc -l` is back to its pre-run count. A
worktree that outlives its session is a doctrine violation — it is the exact leak that
produced the 102-worktree pile-up.

### Cleanup commands (exception case)

```bash
git worktree remove <path>          # normal
git worktree remove -f <path>       # if auto-locked
git worktree unlock <path> && git worktree remove <path>
git worktree prune                  # drop stale metadata
```

If `.git/worktrees/<name>/` metadata lingers after remove, `rm -rf` it — git tolerates
stale metadata-dir cleanup.

### `gh pr merge --delete-branch` from an exception worktree

When `gh pr merge <N> --squash --admin --delete-branch` runs from a worktree while
`main` is checked out in a SIBLING worktree, the merge succeeds server-side but the
local post-merge step fails with `fatal: 'main' is already checked out at '<path>'`.
Two side effects: the remote branch is NOT deleted (verify with
`git ls-remote origin <branch>`; if listed, run `git push origin --delete <branch>`),
and the local feature branch persists. Recovery: explicit remote-branch delete, then
`git fetch origin main && git pull --ff-only` in the worktree that holds main. This
gotcha disappears under the single-folder default — it only applies to the parallel
exception.

---

## What changed (2026-05-18) and why

| Before | After |
|---|---|
| Every `/ship`, `/autovibe`, `/build-with-agent-team` job spawned a fresh worktree | One folder, feature branches inside it. Worktree is the parallel-only exception. |
| Cleanup ("`git worktree remove` after") fired unreliably | Exception worktrees use trap-registered cleanup (fires on completion AND abort) |
| 102 worktrees accumulated; operator lost track of "what's where" | `git worktree list` stays at 1 in steady state |

The iCloud / `/tmp` / disk-pressure hazards are unchanged — they apply to the
single-folder clone exactly as they applied to worktrees.

---

## Composes with

- `.claude/hooks/worktree-guard.sh` — PreToolUse Bash hook. **Structurally ENFORCES
  single-folder**: a bare `git worktree add` is BLOCKED fail-closed
  (`permissionDecision: deny`) so sprawl cannot recur through discipline-lapse. The
  genuine parallel exception opts in **per-command** with the inline env prefix
  `ALLOW_PARALLEL_WORKTREE=1 git worktree add <path> <ref>` (the flag must be in the
  command STRING — the hook runs before the command and can't read env exported inside
  it). `/build-with-agent-team` uses Agent-tool `isolation: "worktree"` (harness-created,
  not a Bash `git worktree add`) and bypasses the hook entirely. The hook still warns on
  dirty-tree branch work + cloud-synced paths, and scans stale `.git/*.lock`. Self-test:
  `bash .claude/hooks/worktree-guard.sh --self-test`.
  **Activation**: registered per-machine in `.claude/settings.local.json` on the primary
  Mac. For fleet-wide structural enforcement, register in committed `.claude/settings.json`
  (a one-time manual paste — agent writes to that file are guardrail-blocked; the snippet
  is in this skill's ship notes).
- `.claude/skills/ship/`, `.claude/skills/autovibe/` — both run the single-folder
  feature-branch flow; `path-check.sh` redirects an iCloud cwd to the `~/code` clone.
- `.claude/skills/build-with-agent-team/` — the one genuine multi-agent parallel case;
  uses per-agent worktree isolation with mandatory post-run cleanup (see that skill).
- `.claude/rules/multi-session-arc-coordination.md` +
  `.claude/rules/continuation-collision-safety.md` — single-folder is the default;
  genuinely-parallel chats use the documented worktree exception above.
- **The armed coordination layer (ARMED 2026-05-25)** — when an exception worktree DOES get
  created, three pieces keep the pile from re-accumulating without you tracking it:
  - `.claude/hooks/sessionstart-context-aggregator.sh` writes a per-worktree session
    HEARTBEAT (`<primary>/.claude/worktrees/<basename>.heartbeat`, gitignored) every session
    start AND auto-surfaces the `/where` fleet/collision view — a LOUD ⚠️ hoisted to the top
    of the briefing when one file is being edited in two worktrees at once, a quiet 🟢
    all-clear otherwise. (Writer/reader path agreement is via `git rev-parse
    --git-common-dir` — the shared `.git`, identical for every worktree — so the writer in
    any worktree and the janitor running from the primary resolve the SAME heartbeat dir.)
  - `.claude/skills/where/scripts/sweep-stale-worktrees.sh` Check 4 reads that heartbeat: a
    worktree untouched by any session for >48h (`--stale-hours N`) is heartbeat-STALE and,
    only with clean+merged+old, eligible for removal under `--apply`. **--apply is
    human-invoke ONLY**; automated surfaces show the dry-run "WOULD remove" list. Grace
    (option b): a worktree with NO heartbeat (pre-existing) is treated as LIVE and never
    auto-removed — the 23 worktrees that predate this layer clear via one-time manual review.
  - `.claude/hooks/cross-chat-collision-detect.sh` — the PreToolUse warn that fires at
    write-time (this layer's session-start counterpart fires at session-start).
  Council: `council/sessions/2026-05-25-session-coordination-armed-janitor.md` (note:
  council sub-agents were unavailable; the one load-bearing decision — the 48h threshold +
  grace policy — was solo-reasoned through the Devil's-Advocate / Edge-Case / Reliability
  lenses and operator-approved before the deletion logic shipped).
