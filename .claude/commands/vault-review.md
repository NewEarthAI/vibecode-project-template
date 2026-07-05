---
description: "Run overdue vault commands in one session based on cadence tracking"
argument-hint: "[--force-all] [--skip drift,emerge]"
---

# /vault-review — Vault Maintenance Meta-Command

Checks which Obsidian Second Brain commands are overdue and runs them in priority order. One command to rule them all.

**Invokes**: `vault-review` skill (v1.0) + `obsidian-second-brain` skill (v2.0)

---

## What It Does

1. Reads your cadence tracking file (`.claude/vault-cadence.local.md`) to see when each vault command last ran
2. Checks for pending KI deposits (vault-sync)
3. Shows you which commands are overdue and why
4. Runs the overdue commands in priority order after your approval
5. Updates cadence dates so the next review knows what's fresh

---

## Usage

```
/vault-review              # Check and run overdue commands
/vault-review --force-all  # Run all commands regardless of schedule
/vault-review --skip drift # Skip specific commands even if overdue
```

---

## Cadence Schedule

| Command | How often | What it does |
|---------|-----------|-------------|
| `/vault-sync` | Every session (if deposits exist) | Pull KI research findings into vault |
| `/drift` | Every 14 days | Surface recurring themes you haven't explicitly connected |
| `/emerge` | Every 30 days | Find idea clusters ready to become projects |
| `/challenge` | On demand | Pressure-test a belief (only with `--force-all`) |

Commands not managed by vault-review (run manually when needed):
- `/trace <topic>` — requires a specific topic argument
- `/graduate <file>` — requires a specific file/cluster to promote

---

## After the Review

The summary tells you:
- What ran and what it found
- Per-entity note counts (using VAULT_LOCATIONS to search all entity folders)
- When each command is next due
- Any graduation candidates from /emerge clusters

Note counting uses VAULT_LOCATIONS from the `obsidian-second-brain` skill to search all entity and content-type folders, respecting the active `--scope` (default from config).

The daily plan's **Vault Pulse** section also tracks these cadences — so even if you don't run `/vault-review` directly, you'll see reminders in your daily plan.

---

## Related Commands

- `/daily-plan` — includes Vault Pulse section showing overdue cadences
- `/vault-sync` — pull KI deposits (also triggered by vault-review)
- `/drift` — theme detection (also triggered by vault-review)
- `/emerge` — cluster identification (also triggered by vault-review)
- `/trace <topic>` — track idea evolution (manual only)
- `/graduate <file>` — promote to spec + KI (manual only)
- `/challenge <belief>` — pressure-test assumptions (manual only)

---

*Not template-managed | vault-review v1.0 | 2026-03-08*
