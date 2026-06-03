# Operational Guardrails — Preventing Wrong-First-Approach

## Project Context Verification (Before Any Work)

1. **Check for parallel session work** before starting ANY task:
   - Run `git log --oneline -10` — scan for commits that may already address this task
   - If the task involves files you didn't create, check `git log --oneline -- <path>` for recent changes
   - Ask yourself: "Could another session have already done this?" before investigating from scratch

2. **Verify working directory** before ANY file operation or git command:
   - Confirm you are in the correct project root
   - For private repos: use LOCAL CLONE PATH first (Read/Glob/Grep), not GitHub MCP/API/gh CLI
   - GitHub MCP is for repos you do NOT have cloned locally

3. **Identify the correct Supabase instance** before ANY query:
   - `supabase-yourproject` — Agency OS (the agency internal, KI pipeline, agency tables)
   - `supabase-yourproject` — a SaaS app (deal analysis, PropTech)
   - `supabase-yourproject` — a logistics app (fleet ops, trips, fuel)
   - `supabase-yourproject` — a client app (separate client)
   - When in doubt: check `clients/{slug}/CLAUDE.md` for the correct instance
   - NEVER query one instance assuming it has another instance's tables

4. **Verify column names** before writing ANY SQL or REST query:
   - Query `information_schema.columns` for the target table FIRST
   - Never assume column names from memory or prior sessions
   - Column names may differ between Supabase projects

5. **Verify git status before claiming completion**:
   - After ANY deployment, migration, or multi-step change: run `git status` + `git log --oneline -3`
   - Confirm all intended changes are staged/committed
   - Check for untracked files that should be committed (workflow JSONs, migration SQL)
   - NEVER mark work as "complete" without verifying the mutation actually succeeded

## n8n Workflow JSON Format

6. **n8n connection format** — when building or editing workflow JSON:
   - Connection keys are SOURCE node names; targets specified via `node` field:
     ```json
     "connections": {
       "Source Node Name": {
         "main": [[{"node": "Target Node Name", "type": "main", "index": 0}]]
       }
     }
     ```
   - WRONG: `{"source": "...", "target": "..."}` — this is NOT n8n format
   - WRONG: `{"from": "...", "to": "..."}` — this is NOT n8n format
   - Always copy format from existing working workflow JSON in `clients/{slug}/workflows/`

7. **n8n node structure** — when constructing nodes:
   - `position` is `[number, number]` array
   - `typeVersion` is a number, not string
   - Copy format from existing working workflows — never construct from memory

## Git Branching Convention (Trunk-Based Development)

8. **Branch naming** — all feature branches must follow this prefix convention:
   - `feat/` — new workflow, feature, or automation (e.g., `feat/ki-phase6-dashboard`)
   - `fix/` — bug fix or broken behaviour repair (e.g., `fix/n8n-booking-parser`)
   - `mig/` — database schema migration (e.g., `mig/add-relevance-column`)
   - `exp/` — experimental, not yet committed to (e.g., `exp/newclaw-prototype`)
   - `ops/` — infrastructure or credential changes (e.g., `ops/doppler-setup`)
   - Direct commits to `main` allowed for non-code changes (doc fixes) with team sync

9. **PR size guideline**: Keep PRs under 200 lines where possible.

8. **Branch lifetime**: Delete branch immediately after merge. No long-lived branches except `main`.

9. **Environment verification before any mutation**:
   - Before ANY Supabase write: confirm you are targeting `staging.*` or `public.*` (production)
   - Before ANY n8n workflow activation: confirm the workflow uses staging credentials, not production
   - Production changes require a PR — not direct commits to `main`

## Template & Cross-Project Rules

10. **Keep template examples client-agnostic**:
   - Template files (pushed via /push-to-template) must NOT contain:
     - Hardcoded project refs, API keys, or credentials
     - Client-specific table names, workflow IDs, or node names
   - Use placeholders: `{{db_tool}}`, `{{workflow_tool}}`, `{{project_ref}}`

## Continuation Prompt Rules

11. **Prompt type determines content depth**:
   - **Micro prompt**: Short pointer for same-day continuation (file link + 2 sentences)
   - **Master/Macro prompt**: Comprehensive multi-section handoff for multi-day or cross-person continuation
   - When user says "continuation prompt" without qualifier: default to master type
   - When user says "quick handoff" or "wrap up for today": use micro type

12. **Verify all file paths in continuation prompts**:
   - Before writing ANY continuation prompt, verify every referenced file path exists on disk
   - Run `ls <path>` for each spec, plan, session file, or workflow JSON referenced
   - If a referenced file doesn't exist, either create it or remove the reference
   - NEVER write a continuation prompt that references uncommitted or non-existent files

12b. **When a referenced file doesn't exist on the current branch — check sibling branches BEFORE asking the user**:
   - Pattern: user invokes a skill with a file path argument (e.g., `/autovibe <continuation>`, `/execute <plan>`) OR references a continuation/spec/memory file in chat. The current branch is stale; the file landed on `main` or a sibling branch since the current branch was created.
   - BEFORE asking the user "I can't find the file — did you mean a different one?" run:
     ```bash
     git fetch --all --quiet
     git log --all --source --oneline --since="14 days ago" -- <file>
     ```
   - If the file appears on a sibling ref, surface the location + commit + PR (if recent) and proceed with `git show <ref>:<file>` to read it. Do NOT block the user with a clarifying question.
   - Cost-of-asking principle: per the system prompt's "Asking the user a clarifying question has a cost — it interrupts them, and often they could have answered it themselves with a grep." `git log --all` answers this question in under 1 second.
   - Composes with: §10 stale-context warning + §13 file-state re-verification (this rule is the *detection* step that precedes the fetch; that rule is the *re-read* step that follows).

13. **Re-verify file state before executing a plan authored earlier** (multi-worktree hazard):
   - BEFORE editing any file a plan targets, run:
     - `git fetch` — pull latest refs
     - `git log --oneline -20 -- <file>` for each target file — did commits land since the plan was authored?
     - `git worktree list` — if 2+ worktrees exist, sibling activity has likely landed on your branch
   - If ANY target file has changed since plan authorship, re-read it at HEAD and regenerate plan deltas before editing
   - **Diagnostic rule**: if an Edit "reverts" to a state you didn't write, your FIRST hypothesis is state drift, NOT a hostile process. Verify with `git log -p -- <file> | head -50` before concluding concurrent writer.

14. **Shell cwd does NOT persist across Bash tool calls** (iCloud vs `~/code/` split):
   - Each Bash tool invocation starts in the session's default cwd, which may be `~/Documents/GitHub/<repo>` (iCloud-poisoned) or another context.
   - Branch-modifying git ops MUST run in the non-iCloud worktree (typically `~/code/<repo>`). Prepend `cd /Users/<user>/code/<repo> &&` to every Bash command when the default cwd is iCloud-rooted, even for commands that looked local to a prior invocation.
   - Do NOT rely on an earlier `cd` having "stuck" — it did not. The shell state resets between tool calls.
   - Verify with `git status` after commits; if the commit landed in the iCloud path by accident, rollback before it syncs.

15. **Agent writes to `.claude/settings.json` are hard-blocked by self-modification guardrail**:
   - `.claude/settings.json` (shared, checked-in) is OFF-LIMITS to agent writes. Attempting triggers a permission denial with "self-modification of agent configuration."
   - `.claude/settings.local.json` (gitignored, per-machine) IS writable and takes effect immediately.
   - **For PROJECT-WIDE hook registration**: write to `settings.local.json` for immediate effect on the current machine, AND surface a "human manual commit" reminder with the copy-pastable JSON snippet for the shared `settings.json`. Do not loop retrying the blocked write.

## Disk Pressure — Pre-flight Before Git Writes

APFS copy-on-write degrades severely past ~90% data-volume usage. Git commands that rewrite `.git/index` (`add`, `commit`, `reset`, `checkout`, `worktree add`) can hang 60-90s or corrupt the index outright when free space is tight.

Before any branch-modifying git op, verify:
```bash
df /System/Volumes/Data | awk 'NR==2 {gsub(/%/,"",$5); if ($5>=90) exit 1}'
```

Exit nonzero → halt git work. Free 5GB+ via `~/.cache/uv`, `~/.npm`, `~/Library/Caches/ms-playwright`, `~/Library/Caches/Google`, Homebrew cache — all rebuildable. Observed failure: 94% full caused 90-second hang on `git reset` which then renamed `.git/index` without rebuilding, leaving the repo in worse state than before.

## `git checkout --ours/--theirs` — Rebase vs Merge Semantics (REVERSED)

During **rebase**: `--ours` = branch being rebased ONTO (upstream/main). `--theirs` = commits being replayed (incoming branch).
During **merge**: `--ours` = current branch. `--theirs` = branch being merged in.

These are **reversed** from each other — the single most misapplied git command. Before any `git checkout --ours` or `--theirs`:
1. Confirm mode: `git status` shows "You are currently rebasing" vs "All conflicts fixed but you are still merging"
2. **Code-file conflicts (*.ts, *.tsx, *.js, *.sql) during rebase**: do NOT auto-resolve — open editor or halt for human review. Auto-resolution has a ~50% chance of dropping the intended side silently.
3. Docs-only conflicts (*.md, *.yaml, comments) can use auto-resolution IF the duplicate content is provable via prior commits.

The `hookify.rebase-ours-theirs-guard.local.md` rule (if installed) auto-injects this reminder when the pattern is detected at tool-call time.

## Snapshot Before Destructive Ops

Before any of these ops, copy at-risk files to `~/{{repo_stem}}-snapshots/$(date +%Y%m%d-%H%M%S)/` with a `MANIFEST.md` naming source path + git state:
- `git reset --hard`, `mv .git/index*`
- `git worktree remove --force`, `git branch -D`
- `git push --force-with-lease` on a branch with divergent remote
- `rm -rf` any directory containing uncommitted work

Cost: ~5 seconds per snapshot, typically <1MB per file. Payoff: full recoverability when a "safe" op turns out unsafe.

## Recovery from a bad commit on a just-pushed feature branch (verified 2026-05-07)

When you have committed wrong content (wrong files, wrong message, wrong scope) and pushed it to a feature branch, both `git reset --hard` and `git push --force` are bash-guardian-blocked. Use this non-destructive recovery sequence instead:

1. Stash the staged-but-good fix: `git stash push -m "fix WIP" -- <good-files>`
2. Fast-forward local to remote: `git pull --ff-only` (re-applies the bad commit locally)
3. Revert the bad commit: `git revert <bad-sha> --no-edit` (creates a new commit that undoes it)
4. Restore the staged-but-good fix: `git stash pop`
5. Stage + commit the real fix
6. Plain `git push` (no force needed — adds new commits on top)

Result on PR history: bad-commit → revert-of-bad → real-fix. Reviewer sees the recovery transparently. Non-destructive. Survives bash-guardian.

**Edge case**: if the FF in step 2 is blocked by untracked files (e.g., the bad commit added them and they conflict with local untracked copies), `mv` the conflicting untracked files to `/tmp/<repo>-checkout-aside/` first, complete steps 2–6, then `mv` them back from the aside directory. This works because git refuses to clobber untracked files but happily adds tracked ones — moving them aside makes git treat the slot as unoccupied for the duration.

**Failure precedent (2026-05-07)**: a foundation PR had a misordered `git add -A` that pulled 3 unrelated component files into a config-lockstep commit. Force-push blocked at bash-guardian; reset --hard blocked at bash-guardian. Recovery via the sequence above produced a clean PR history (foundation → bad → revert → real-fix) without any destructive ops. Total recovery time after the technique was identified: under 90 seconds.

## Recovery from a divergent local main after `gh pr merge --squash --admin --delete-branch` (verified 2026-05-08)

Symptom: the squash-merged commit landed on origin/main (state=MERGED, mergedAt set), but `gh pr merge`'s post-merge `git checkout main` failed locally because main was held in another worktree (`fatal: 'main' is already checked out at '<other-path>'`). After fast-forwarding the worktree that DOES hold main, you commit something else there (an end-log entry, a status-flip, etc.). Now `git push origin main` is blocked by branch protection — but if your local commit was a manual application of the same diff that the squash captured, your local main carries a divergent SHA representing logically-identical content. `git pull --ff-only` fails with `Not possible to fast-forward, aborting.`

`git reset --hard origin/main` is bash-guardian-blocked. Don't try to bypass.

**Non-destructive reconciliation**:
1. `git checkout --detach` — detaches HEAD at the divergent SHA (preserves it on the reflog for ~90 days)
2. `git branch -f main origin/main` — force-update the local main pointer to origin/main (metadata-only ref-write, allowed by guardrails)
3. `git checkout main` — back on main, now matching origin

The detached commit lives on the reflog if you ever need it. Loss-free. Verify clean against `git log --oneline -3` showing origin/main HEAD.

**Edge note**: `gh pr merge --delete-branch` ALSO silently skips the REMOTE branch deletion when the post-merge local checkout fails. Verify with `git ls-remote origin <branch>` and explicitly `git push origin --delete <branch>` if it's still listed.

**Failure precedent (2026-05-08)**: a feature PR was admin-merged from a feature worktree while main was held in a sibling worktree. Post-merge checkout failed; the remote branch survived; an end-log commit on the main-holding worktree diverged from origin after the squash. Recovery via detach + `branch -f` + checkout completed in under 30 seconds with zero data loss.

## Confident Mode — HARD STOP Operations

Proceed confidently on reads, writes, queries, and local git (permissions pre-allow these). But **ALWAYS confirm** before:
- `git push` (any variant) — affects shared remote state
- `DROP TABLE`, `TRUNCATE`, `DELETE FROM` (without WHERE) — data destruction
- Sending messages to real humans (WhatsApp, email) — external communication
- Deploying to production (edge functions, serverless) — production state change
- Modifying `.env` files — credential exposure risk
- `rm -rf`, `git reset --hard`, `git clean -f` — irreversible local destruction
