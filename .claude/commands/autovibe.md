---
description: Autonomous shipping orchestrator — plan→council→amend→execute→code-council→ship in one invocation
---

# /autovibe

Top-of-stack autonomous shipping orchestrator. Composes `/ship`, `/council --extended`, `/amend-plan`, `/execute`, `/code-council`, `/prompt-forge`, and `prime-lite`.

## Usage

```
/autovibe "<intent>"
```

The intent is a one-sentence description of what should ship. Triage classifies it and routes to either direct-implement (typos, comments) or full planned ceremony (migrations, edge functions, hooks, multi-file diffs).

## Examples

```
/autovibe "fix typo in /pipeline page header"
  → triage=direct → /execute → /ship quick

/autovibe "add new edge function for slack notification webhook"
  → triage=plan → forge if needed → plan → council → amend → execute → code-council → /ship pr

/autovibe "improve the dashboard"
  → triage=ambiguous → fail-closed to planned mode for safety
```

## Flags (env vars)

| Flag | Effect |
|---|---|
| `AUTOVIBE_DRYRUN=1` | Print every command, execute none, exit 0 |
| `AUTOVIBE_FORMAT=json` | One JSON line per phase to stdout |

## What this command does

1. Invokes `Skill autovibe` to load the skill
2. The skill runs `scripts/orchestrate.sh "<intent>"` for preflight + triage + state
3. Reads triage outcome and dispatches to `modes/direct.md` or `modes/planned.md`
4. Composes downstream skills (council, execute, ship, etc.) in sequence
5. Runs post-push documentation step
6. Releases lock, exits

## Exit codes

See `.claude/skills/autovibe/SKILL.md` §Exit Codes.

## Constraints

- Refuses to run from iCloud/cloud/tmp paths (preflight exits 6)
- Never auto-invokes `/ship hotfix` (exit 9 if conditions detected)
- Lock-collision protected (one autovibe per repo at a time)

## Reference

`.claude/skills/autovibe/SKILL.md`
