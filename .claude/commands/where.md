---
description: Plain-English "where is all my work?" across every NewEarth repo — live git, file-level collision warnings, no registry
---

# /where

Run the live fleet state surface. One command, plain-English answer, derived entirely from
git — no written registry, cannot lie.

## Steps

1. Run the walker:

   ```bash
   bash .claude/skills/where/scripts/where.sh
   ```

2. Relay its output to the operator **verbatim in layman voice** — it is already written in
   plain English with 📁 / 📄 icons. Do NOT re-summarise into jargon. Do NOT add raw paths
   as labels.

3. If the script printed a `⚠️ COLLISION` block, lead the reply with it — that is the
   silent-corruption case and is the single most important thing on the screen.

4. If the script reported GitHub CLI unauthenticated, pass through its one-line note; do not
   treat it as a failure (PR data degrades, worktree truth does not).

## Notes

- Read-only. `/where` never removes or mutates anything.
- For cleanup, the operator runs the guarded janitor explicitly:
  `bash .claude/skills/where/scripts/sweep-stale-worktrees.sh` (dry-run; `--apply` to act).
- Composes `verify-shipped`'s `walk-worktrees.sh` — see `.claude/skills/where/SKILL.md`.
