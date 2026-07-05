---
name: vault-review
description: |
  Meta-command that checks vault cadence dates and runs overdue Obsidian Second Brain
  commands in a single session. Reads cadence tracking file, identifies which commands
  are overdue (/drift, /emerge, /vault-sync, /challenge), runs them in priority order,
  and updates cadence dates on completion. Use when: "vault review", "check my vault",
  "run overdue vault commands", "vault health check", "vault maintenance".
version: 1.0
classification: encoded-preference
created: 2026-03-08
updated: 2026-03-08
template_managed: false
parameters:
  - name: vault_cadence_file
    type: path
    default: ".claude/vault-cadence.local.md"
    description: "Per-machine file tracking last-run dates for vault commands. Gitignored."
  - name: force_all
    type: boolean
    default: false
    description: "Run all vault commands regardless of cadence (useful for first-time setup)."
  - name: skip_commands
    type: array
    default: []
    description: "Commands to skip even if overdue. Values: drift, emerge, vault-sync, challenge."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, TodoWrite
validated_on:
  - "A project vault with 6 vault commands configured"
  - "Works when no commands are overdue (reports clean status)"
  - "Works on first run when cadence file doesn't exist (creates it, marks all as never-run)"
  - "Graceful degradation when Supabase MCP unavailable (skips vault-sync deposit check)"
---

# Vault Review

Meta-command that orchestrates overdue Obsidian Second Brain commands. Instead of remembering 6 commands and their ideal cadences, run `/vault-review` and it handles the rest.

**Invokes**: `obsidian-second-brain` skill (v1.0) for vault access

---

## Step 0 — Resolve Vault

Read `.claude/obsidian-second-brain.local.md` for vault path (per obsidian-second-brain skill Step 0).

If vault not configured: STOP — report "No vault configured. Create `.claude/obsidian-second-brain.local.md` with vault_path in frontmatter."

---

## Step 1 — Read Cadence Tracking File

```bash
Read .claude/vault-cadence.local.md
```

Expected YAML frontmatter:

```yaml
---
last_drift: "2026-03-01"
last_emerge: "2026-02-15"
last_vault_sync: "2026-03-07"
last_vault_review: "2026-03-01"
last_challenge: "never"
---
```

**If file doesn't exist**: Create it with all dates set to `"never"`. This triggers all commands on first run.

---

## Step 2 — Check Pending Vault Deposits

Query Supabase for pending `vault_deposit` actions:

```sql
SELECT COUNT(*) as pending_count
FROM knowledge_actions
WHERE action_type = 'vault_deposit'
  AND status = 'proposed';
```

**If MCP unavailable**: Set `pending_count = -1` (unknown). Note "Supabase MCP not connected — vault-sync deposit check skipped" in the report.

---

## Step 3 — Calculate Overdue Status

Using cadence dates from Step 1 and today's date:

| Command | Cadence | Overdue when | Priority |
|---------|---------|-------------|----------|
| `/vault-sync` | Every session (if deposits exist) | pending_count > 0 | 1 (highest) |
| `/drift` | Every 14 days | last_drift + 14 < today | 2 |
| `/emerge` | Every 30 days | last_emerge + 30 < today | 3 |
| `/challenge` | On demand (no cadence) | Only if `force_all` is true | 4 (lowest) |

**`force_all` override**: If `force_all` is true, mark ALL commands as overdue regardless of dates.

**`skip_commands` filter**: Remove any commands listed in `skip_commands` from the overdue list.

**Date "never"**: Treat as infinitely overdue — always triggers.

---

## Step 4 — Vault Health Quick Stats

Gather quick vault metrics for the report header:

```bash
find {vault_path} -name "*.md" -not -path "*/.obsidian/*" | wc -l
find {vault_path}/daily -name "*.md" 2>/dev/null | wc -l
find {vault_path}/graduated -name "*.md" 2>/dev/null | wc -l
find {vault_path}/research -name "*.md" 2>/dev/null | wc -l
```

---

## Step 5 — Present Review Plan

Before executing anything, show the user what will run:

```
VAULT REVIEW
━━━━━━━━━━━━
Vault: {vault_path}
Notes: {total} total | {daily} daily | {graduated} graduated | {research} KI deposits

CADENCE STATUS:
  /vault-sync: {last date} — {✓ no pending deposits | ⚠️ {N} deposits waiting | ❓ MCP unavailable}
  /drift:      {last date} — {✓ on schedule | ⚠️ overdue by {N} days}
  /emerge:     {last date} — {✓ on schedule | ⚠️ overdue by {N} days}

ACTIONS:
  1. {command} — {reason it's overdue}
  2. {command} — {reason}
  ...

{No overdue commands — vault is healthy! ✓}

Run overdue commands? (go / skip / pick N)
```

**WAIT** for user approval before executing any commands.

**User responses**:
- `go` — run all overdue commands in priority order
- `skip` — skip this review, update `last_vault_review` date only
- `pick N` or `pick 1,3` — run only the specified numbered actions
- `go {command}` — run only that specific command (e.g., `go drift`)

---

## Step 6 — Execute Overdue Commands

Run each approved command in priority order. Between commands:

1. **Execute the command** — invoke the corresponding vault command's full process
2. **Update cadence date** — edit the cadence tracking file with today's date for that command
3. **Report result** — brief summary of what the command found/produced
4. **Proceed to next** — no additional approval needed (user already approved the batch)

### Command execution details:

**`/vault-sync`** (Priority 1):
- Follow the vault-sync command process (query proposed vault_deposits, write to vault, update status)
- Updates `last_vault_sync` in cadence file

**`/drift`** (Priority 2):
- Run with default `--days 30`
- Updates `last_drift` in cadence file

**`/emerge`** (Priority 3):
- Run with default `--threshold 3`
- Updates `last_emerge` in cadence file
- If any clusters are READY FOR GRADUATION, note them for the summary

**`/challenge`** (Priority 4 — only with `force_all`):
- Skip unless user provided a specific belief to challenge
- If `force_all`, scan vault for recent `#belief` tagged notes and challenge the most recent one
- Updates `last_challenge` in cadence file

---

## Step 7 — Update Cadence File & Summary

After all commands complete:

1. **Update `last_vault_review`** in the cadence file to today's date
2. **Present summary**:

```
VAULT REVIEW COMPLETE
━━━━━━━━━━━━━━━━━━━━
Commands run: {N}

/vault-sync: {synced N deposits | skipped — no deposits | skipped — MCP unavailable}
/drift: {found N themes | no themes detected | skipped — on schedule}
/emerge: {found N clusters (M ready) | no clusters | skipped — on schedule}

Next review due: {today + 14 days}
Next /drift due: {last_drift + 14}
Next /emerge due: {last_emerge + 30}

Graduation candidates: {list any READY clusters from /emerge, or "none"}
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Auto-run commands without user approval | User must control what runs in their session | Always show plan, wait for "go" |
| Run /trace or /graduate from vault-review | These need specific topics/files as input | Only orchestrate cadence-based commands |
| Hardcode cadence intervals | User may want different rhythms | Cadences defined in skill, easily adjustable |
| Skip cadence file update on error | Command partially ran, date stays stale | Update date even on partial completion — prevents infinite retry loops |
| Block on Supabase MCP failure | vault-sync is just one check | Degrade gracefully — report unknown, skip vault-sync |
| Run /emerge with < 10 vault notes | Clustering needs volume | Warn "vault too small for meaningful clusters" but still run |

---

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| No vault configured | STOP — report error, link to setup |
| Cadence file missing | Create with all dates "never", triggers first-run of everything |
| Supabase MCP unavailable | Skip vault-sync deposit check, run other commands normally |
| All commands on schedule | Report "vault is healthy" — no commands to run |
| Vault has < 5 notes | Warn about low note count, run commands anyway (they handle graceful degradation internally) |
| Individual command fails | Report error, continue to next command, don't block the batch |

---

*Skill version: 1.0 | Created 2026-03-08*
