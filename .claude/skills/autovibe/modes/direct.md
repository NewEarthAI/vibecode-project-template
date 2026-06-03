---
name: autovibe-mode-direct
description: Direct-implement mode for /autovibe. Triage returned `direct`. Skip plan + council; go straight to execute + /ship quick.
---

# Autovibe — Direct Mode

**When this mode runs:** triage classified the work as trivia (typo, comment, console.log, single-line ROADMAP reorder). No plan ceremony, no council review.

## Composition Sequence

The calling Claude session (after `orchestrate.sh` returns 0) executes:

```
1. Read /tmp/autovibe-prime-<pid>.md  ← context briefing
2. Implement the change directly with Edit/Write
3. Skill ship  (or invoke /ship quick directly)
   - If /ship returns 0 → continue
   - If /ship returns 1–6 → halt, surface remediation from
     .claude/skills/ship/references/failure-inventory.md, exit with same code
   - If /ship returns 9 (UNVERIFIABLE smoke) → halt, surface, exit 9
4. Read .claude/ship-state.json — capture commit_sha, completed_at
5. Run post-push doc step (see SKILL.md §Post-Push)
6. state.sh write phase "complete"
7. state.sh write exit_code "0"
8. state.sh release  (also fires via trap)
```

## Failure Modes

| Symptom | Cause | Action |
|---|---|---|
| `/ship quick` exits 1 | Pre-check failed (path/disk/tsc) | Halt, surface ship's stderr, exit 1 |
| `/ship quick` exits 6 | Filesystem blocker (iCloud path) | Should have been caught by autovibe preflight; surface and exit 6 |
| Hooks fire 2+ times during this turn | Death-march risk | Halt, recommend fresh-session reset, exit 1 |

## What This Mode NEVER Does

- ❌ Invoke `/council` (that's planned mode's job)
- ❌ Invoke `/amend-plan` or write a plan file
- ❌ Invoke `/code-council` (no plan to compare against)
- ❌ Invoke `/ship pr` (no PR for trivia)
- ❌ Invoke `/ship hotfix` — under any circumstance, autovibe never auto-invokes hotfix

## Reference

- Triage source: `.claude/skills/autovibe/scripts/triage.sh`
- Ship contract: `.claude/skills/ship/SKILL.md` §Exit Codes
- Failure inventory: `.claude/skills/ship/references/failure-inventory.md`
