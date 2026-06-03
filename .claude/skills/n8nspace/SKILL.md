---
name: n8nspace
description: |
  n8n disk space manager for Ubuntu VPS. Supports Docker Compose AND bare Node.js runtimes.
  Preflights sudo/service-name, snapshots usage, cleans logs/apt/docker, reclaims binaryData
  (age-first → stop/rename), offers volume-move, audits pruning env vars inside container.
  Includes emergency mode (full purge), dry-run audit mode, cron guard health check, and
  remote SSH trigger reference. Complements autonomous n8n-disk-guard.sh cron script.
  Safe: never deletes .BAK without explicit confirmation.
version: 2.1
created: 2026-02-18
updated: 2026-03-04
supersedes: "n8nspace v1.0"
validated_on:
  - "n8n VPS at 90% disk due to accumulated binaryData and Docker image layers"
  - "Pruning env vars in .env but not injected into container after docker run outside compose"
  - "25GB disk hit 100% — 9GB binaryData on root filesystem"
parameters:
  - name: threshold_warn
    type: integer
    default: 80
    note: "Auto-adjusted to 70 if disk < 50GB"
  - name: threshold_action
    type: integer
    default: 85
    note: "Auto-adjusted to 80 if disk < 50GB"
  - name: journal_vacuum_days
    type: integer
    default: 7
  - name: binaryData_large_gb
    type: integer
    default: 1
  - name: keep_binary_backup
    type: boolean
    default: true
  - name: max_age_hours
    type: integer
    default: 168
  - name: prune_max_count
    type: integer
    default: 5000
  - name: emergency
    type: boolean
    default: false
    note: "Skip age-based cleanup, go straight to full purge"
  - name: dry_run
    type: boolean
    default: false
    note: "Show what WOULD be deleted without deleting anything"
paths:
  - "infrastructure/**"
  - "deployment/**"
---

# n8nspace — n8n VPS Disk Space Manager

**Target**: Ubuntu VPS, n8n in Docker Compose at `/opt/n8n` (also supports bare Node.js)
**How to run**: Type `/n8nspace` inside **Claude Code** — runs remotely via SSH. No need to be SSH'd in.
**Safety contract**: Never deletes backups without explicit user confirmation. Never prints .env.
**Complement**: Deploy `n8n-disk-guard.sh` (in `scripts/`) as hourly cron for unattended protection.

---

## VPS Registry — Known Infrastructure

Look up the target VPS from this registry. **Do NOT ask the user for SSH details** if the instance is listed here. Ask the user which instance only if multiple match.

| Instance | Droplet Name | IP | Disk | Region | SSH User | n8n URL | n8n MCP Server |
|----------|-------------|-----|------|--------|----------|---------|----------------|
| `primary` | (assign name) | {{primary_ip}} | (TBD) | (TBD) | {{ssh_user}} | {{n8n_url}} | {{n8n_mcp_server}} |
| `agent` | (assign name) | {{agent_ip}} | (TBD) | (TBD) | {{ssh_user}} | N/A (agent only) | N/A |

**Auto-selection**: If the user says "n8n" or the primary instance name without specifying, use the primary row.
**All SSH commands**: Prefix with `ssh {{ssh_user}}@<IP>` — this skill runs remotely from the local machine.
**Connection test**: Always verify SSH connectivity first: `ssh -o ConnectTimeout=10 {{ssh_user}}@<IP> "echo OK"`

---

## How This Skill Runs

This skill is executed by Claude Code (the AI agent). When you type `/n8nspace` in the
Claude Code prompt (not a regular terminal), Claude reads this skill and executes the bash
commands below for you, pausing at confirmation gates.

If you want a non-interactive snapshot-only version, use Section A commands manually in bash.

**For unattended automation**, deploy the `n8n-disk-guard.sh` cron script (see Section G).

---

## Critical Safety Rules

1. **Never `rm -rf` binaryData backups** without explicit "yes" confirmation
2. **Never print `/opt/n8n/.env` contents** — grep only specific lines
3. **Renaming binaryData to .BAK does NOT free disk space** on the same filesystem
4. **Never change `N8N_ENCRYPTION_KEY`** — will break all saved credentials
5. **Never use `docker compose exec -T <service> env`** — hookify blocks `env` commands. Use `docker inspect` instead (see Section E2)
6. **If disk >= 95%**: some Docker and apt operations may fail; warn user, minimize writes
7. **Section F is strictly opt-in** — never apply prune_max_count unless user explicitly requests
8. **Emergency mode requires explicit `emergency=true` parameter** — never auto-apply
9. **Chain SSH commands carefully** — hookify may block compound commands with certain patterns. Keep commands focused and single-purpose. If a command is blocked, split into smaller parts.
10. **All commands run via SSH** — prefix every command with `ssh {{ssh_user}}@<IP>` from the VPS registry

---

## Small Disk Auto-Adjustment

If root disk total size < 50GB:

```
threshold_warn  -> auto-set to 70 (instead of 80)
threshold_action -> auto-set to 80 (instead of 85)
```

Check total disk size in Preflight:
```bash
TOTAL_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$2); print $2}')
if (( TOTAL_GB < 50 )); then
    threshold_warn=${threshold_warn:-70}
    threshold_action=${threshold_action:-80}
fi
```

Print if adjusted: `Note: Small disk ({{TOTAL_GB}}GB) — thresholds adjusted to warn={{threshold_warn}}%, action={{threshold_action}}%`

---

## Dry-Run Mode

If `dry_run=true`: prefix all destructive actions with `[DRY-RUN]` and skip execution.
Show what WOULD be deleted (file counts, estimated size) without deleting anything.
Still run all detection, measurement, and env var audit sections normally.

---

## Emergency Mode

If `emergency=true`: skip age-based deletion (Phase D1), go directly to:
1. Stop n8n
2. Purge ALL binaryData contents
3. Restart n8n
4. Health check

This matches the `--emergency` flag on the cron guard script.

---

## Critical Disk Warning

If root disk >= 95%, print before any actions:

```
CRITICAL: Root disk is {{X}}% full. Some operations may fail due to no space.
Prioritizing deletions over writes. Skipping any operations that write to disk.
Move binaryData backup to an external volume immediately after reclaim.
```

---

## Preflight Checks (Run Before Any Section)

### P1: sudo/root availability

```bash
whoami
sudo -n true 2>/dev/null && echo "sudo: OK (passwordless)" || echo "sudo: requires password or not available"
```

### P2: Detect runtime (Docker Compose OR bare Node.js)

```bash
ls /opt/n8n/docker-compose.yml 2>/dev/null && echo "RUNTIME: Docker Compose at /opt/n8n"
```

**If docker-compose.yml found**: proceed with Docker Compose commands.

**If docker-compose.yml NOT found**: check for bare Node.js:
```bash
pgrep -fa "n8n" || echo "No n8n process found"
docker ps --format '{{.Names}}' 2>/dev/null | grep -x "n8n" && echo "RUNTIME: Standalone Docker container"
```

If bare Node.js detected, adapt commands:
- Replace `docker compose stop/start` with `systemctl stop/start n8n` or process signals
- Read env vars from process: `cat /proc/$(pgrep -f n8n | head -1)/environ | tr '\0' '\n' | grep EXECUTIONS`
- Find binaryData via `N8N_BINARY_DATA_STORAGE_PATH` env or filesystem search

If no n8n found at all: WARN and proceed with cleanup-only (Sections A-C).

### P3: Detect service name (never hardcode "n8n")

```bash
docker compose --env-file .env config --services 2>/dev/null || true
```

Parse the output to find the service containing "n8n". Store as `N8N_SERVICE`.
Use `{{N8N_SERVICE}}` everywhere below.

### P4: Check for mounted volumes (backup move option)

```bash
df -h | grep "/mnt/" || echo "No mounted volumes detected at /mnt/"
ls /mnt/ 2>/dev/null || true
```

### P5: Detect binaryData path

```bash
cd /opt/n8n 2>/dev/null
docker inspect $(docker compose --env-file .env ps -q {{N8N_SERVICE}}) --format '{{range .Config.Env}}{{println .}}{{end}}' | grep N8N_BINARY_DATA_STORAGE_PATH || true
find /opt /root /home -type d -name binaryData -prune -print 2>/dev/null
```

---

## Section A — Snapshot

```bash
df -h /
cd /opt/n8n
docker compose --env-file .env ps
du -sh /opt/n8n/n8n_data/binaryData 2>/dev/null || true
```

---

## Section B — Find Biggest Offenders

```bash
du -xh --max-depth=2 /opt/n8n/n8n_data 2>/dev/null | sort -h | tail -n 30
du -xh --max-depth=1 /var 2>/dev/null | sort -h | tail -n 30
docker system df || true
```

---

## Section C — Safe Cleanup

**Threshold gate:**
- Root disk < `threshold_warn` %: SKIP.
- Root disk >= `threshold_warn` AND < `threshold_action` %: run steps 1-3, SKIP docker prune.
- Root disk >= `threshold_action` %: run all steps including docker prune.

```bash
sudo journalctl --vacuum-time={{journal_vacuum_days}}d || true
sudo apt-get clean || true
sudo rm -rf /var/cache/apt/archives/* || true
docker system df || true
```

Docker prune (ONLY if >= `threshold_action`):

```bash
docker system prune -af
```

---

## Section D — binaryData Reclaim

**Entry condition:** binaryData > `binaryData_large_gb` GB OR root disk >= `threshold_action` %.

**If `emergency=true`**: skip D1, go directly to stop + full purge + restart.

### Phase D1 — Age-Based Deletion (Always Run First)

Safe while n8n is running. Targets files older than `max_age_hours`.

**If `dry_run=true`**:
```bash
find /opt/n8n/n8n_data/binaryData -type f -mmin +$((max_age_hours * 60)) 2>/dev/null | wc -l
```

**If not dry_run**:
```bash
find /opt/n8n/n8n_data/binaryData -type f -mmin +$((max_age_hours * 60)) -delete 2>/dev/null || true
find /opt/n8n/n8n_data/binaryData -type d -empty -delete 2>/dev/null || true
```

If below thresholds after D1: STOP. Skip D2.

### Phase D2 — Stop / Rename / Restart

```bash
cd /opt/n8n
docker compose --env-file .env stop {{N8N_SERVICE}}
mv /opt/n8n/n8n_data/binaryData /opt/n8n/n8n_data/binaryData.BAK-$(date +%F)
docker compose --env-file .env up -d {{N8N_SERVICE}}
```

### CRITICAL: Rename Does NOT Free Disk Space

`.BAK` still occupies the same space. Freed only by deleting (confirmation required) or moving to another filesystem.

---

## Section E — Verify Pruning Env Vars

### E1: Compose config

```bash
cd /opt/n8n
docker compose --env-file .env config | grep "EXECUTIONS_DATA_" || echo "NOT found"
```

### E2: Container env (hookify-safe method)

**IMPORTANT**: Do NOT use `docker compose exec -T <service> env` — hookify blocks `env` commands.
Use `docker inspect` to read container environment variables instead:

```bash
docker inspect $(docker compose --env-file .env ps -q {{N8N_SERVICE}}) --format '{{range .Config.Env}}{{println .}}{{end}}' | grep "^EXECUTIONS_DATA_" | sort
```

**Expected:** `PRUNE=true`, `MAX_AGE={{max_age_hours}}`, `SAVE_ON_SUCCESS=none`, `SAVE_ON_ERROR=all`

If absent from container but in compose: `docker compose up -d --force-recreate`.
If absent from both: provide YAML snippet for docker-compose.yml.

---

## Section F — Optional: Prune Max Count Cap

**Only run if explicitly requested.** Never auto-apply.

---

## Section G — Cron Guard Health Check (v2.0)

Verify the autonomous `n8n-disk-guard.sh` cron is installed and working.

```bash
ls -la /usr/local/sbin/n8n-disk-guard.sh 2>/dev/null || echo "MISSING: Guard script not deployed"
cat /etc/cron.d/n8n-disk-guard 2>/dev/null || echo "MISSING: Cron not configured"
tail -15 /var/log/n8n-disk-guard.log 2>/dev/null || echo "No guard log found"
cat /etc/logrotate.d/n8n-disk-guard 2>/dev/null || echo "MISSING: Logrotate not configured"
```

**If guard not deployed**, offer to deploy from bundled script:
```bash
# Deploy guard script (bundled at .claude/skills/n8nspace/scripts/n8n-disk-guard.sh)
sudo cp .claude/skills/n8nspace/scripts/n8n-disk-guard.sh /usr/local/sbin/n8n-disk-guard.sh
sudo chmod +x /usr/local/sbin/n8n-disk-guard.sh

# Hourly cron
sudo tee /etc/cron.d/n8n-disk-guard <<'EOF'
15 * * * * root RETENTION_MINUTES=1440 /usr/local/sbin/n8n-disk-guard.sh >> /var/log/n8n-disk-guard.log 2>&1
EOF

# Logrotate
sudo tee /etc/logrotate.d/n8n-disk-guard <<'EOF'
/var/log/n8n-disk-guard.log { weekly rotate 4 compress missingok notifempty }
EOF
```

---

## Remote Trigger Reference (v2.0)

For running from a remote terminal without Claude Code:

```bash
# Quick disk check
ssh {{ssh_user}}@YOUR_N8N_IP "df -h / && du -sh /opt/n8n/n8n_data/binaryData 2>/dev/null"

# Run guard
ssh {{ssh_user}}@YOUR_N8N_IP "/usr/local/sbin/n8n-disk-guard.sh"

# Dry run
ssh {{ssh_user}}@YOUR_N8N_IP "/usr/local/sbin/n8n-disk-guard.sh --dry-run"

# Emergency
ssh {{ssh_user}}@YOUR_N8N_IP "/usr/local/sbin/n8n-disk-guard.sh --emergency"

# Last report
ssh {{ssh_user}}@YOUR_N8N_IP "cat /var/log/n8n-disk-guard-report.json | python3 -m json.tool"
```

---

## Section H — n8n Health Verification (MANDATORY)

**Always run this section.** Disk health means nothing if n8n itself is broken.

This section verifies n8n is actually functional — not just that the container is running.

### H1: Container + Process Health

```bash
docker compose --env-file .env ps --format '{{.Name}} {{.Status}}'
```

Check for "Up" status and note uptime. If "Restarting" or "Exited", flag immediately.

### H2: n8n API Health Check (via SSH curl)

Test the n8n REST API from inside the VPS (avoids firewall/DNS issues):

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz
```

**Expected**: `200`. If non-200, n8n is down despite container running.

### H3: n8n API Workflow Count (via SSH curl)

Verify n8n can query its database and return data:

```bash
curl -s -H "Accept: application/json" http://localhost:5678/api/v1/workflows?limit=1 -H "X-N8N-API-KEY: $(grep N8N_API_KEY /opt/n8n/.env 2>/dev/null | cut -d= -f2)" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Workflows: {len(d.get(\"data\",[]))} returned, nextCursor: {d.get(\"nextCursor\",\"none\")}')" 2>/dev/null || echo "API query failed"
```

**Note**: If API key grep fails, fall back to the n8n MCP server:
Use `{{n8n_mcp_server}}` to list workflows as a secondary verification.

### H4: n8n MCP Server Verification

After SSH checks, verify the MCP connection works from Claude Code:

1. Use the corresponding n8n MCP server (from VPS Registry `n8n MCP Server` column)
2. Attempt a lightweight MCP call (e.g., list workflows with limit=1)
3. Compare MCP result with SSH curl result — they should match

**If MCP works but SSH curl fails**: n8n is accessible via tunnel but unhealthy internally.
**If SSH curl works but MCP fails**: MCP token/config issue, not an n8n issue.
**If both fail**: n8n is genuinely down.

### H5: Webhook Endpoint Check (optional, if n8n URL known)

Test external accessibility from the local machine (not SSH):

```bash
curl -s -o /dev/null -w "%{http_code}" {{n8n_url}}/healthz
```

**Expected**: `200` (or `401` if auth required — still means n8n is responding).

### H6: Infrastructure Baseline Checks

These checks catch common misconfigurations flagged by cloud provider best practices.

**Monitoring agent (DigitalOcean example):**
```bash
systemctl is-active do-agent 2>/dev/null || dpkg -l do-agent 2>/dev/null | grep -q ii && echo "do-agent: INSTALLED" || echo "do-agent: NOT INSTALLED (no cloud dashboard metrics)"
```
If missing, recommend installing your cloud provider's monitoring agent.

**Backup status (informational):**
Report whether cloud backups are enabled. This requires the cloud provider MCP/API.
If unavailable, print: `BACKUPS: Unknown (enable cloud provider MCP to check)`

**Firewall sanity check:**
```bash
ufw status | grep -E "5678|DENY|ALLOW"
```
Flag if port 5678 has both ALLOW and DENY rules (contradictory).
Flag if n8n port is ALLOW when bound to loopback (unnecessary exposure).

### Health Summary Format

```
N8N HEALTH:
  Container: {{UP/DOWN}} (uptime: {{X}})
  API (local):  {{http_code}} — {{OK/FAIL}}
  API (query):  {{workflow_count}} workflows accessible
  MCP Server:   {{CONNECTED/FAIL}}
  External URL: {{http_code}} — {{OK/FAIL}}

INFRA BASELINE:
  Monitoring:  {{INSTALLED/MISSING}}
  Backups:   {{ENABLED/DISABLED/Unknown}}
  Firewall:       {{CLEAN/ISSUES FOUND}}
```

---

## Final Summary Output Format

```
===================================================
  n8nspace v2.1 — {{date +%F %H:%M}}
  Host: {{hostname}} ({{IP}}) | Disk: {{TOTAL_GB}}GB
===================================================

DISK:  {{X}}% -> {{Y}}% ({{delta}})
BINARY: {{path}} — {{before}} -> {{after}}
ACTIONS: {{list}}
ENV VARS: {{PASS/FAIL}}
CRON GUARD: {{installed/MISSING}}

N8N HEALTH:
  Container: {{UP/DOWN}} (uptime: {{X}})
  API (local):  {{http_code}} — {{OK/FAIL}}
  API (query):  {{workflow_count}} workflows accessible
  MCP Server:   {{CONNECTED/FAIL}}
  External URL: {{http_code}} — {{OK/FAIL}}

INFRA BASELINE:
  Monitoring:  {{INSTALLED/MISSING}}
  Backups:   {{ENABLED/DISABLED/Unknown}}
  Firewall:       {{CLEAN/ISSUES FOUND}}

WARNINGS: {{list or none}}
NEXT: {{recommendations}}
===================================================
```

---

## Anti-Patterns

| # | Wrong | Why | Right |
|---|-------|-----|-------|
| 1 | `docker exec n8n env` | Hookify blocks `env` cmd | `docker inspect ... --format '{{range .Config.Env}}...'` |
| 2 | `docker compose exec -T <svc> env` | Hookify blocks `env` cmd | `docker inspect` (see E2) |
| 3 | `rm -rf .BAK-*` no confirm | Data loss | Confirmation gate |
| 4 | `cat /opt/n8n/.env` | Exposes secrets | grep specific line |
| 5 | Skip D1 to D2 | Unnecessary downtime | Age-delete first |
| 6 | `prune -af` below threshold | Removes needed images | Gate behind threshold_action |
| 7 | Change N8N_ENCRYPTION_KEY | Breaks credentials | Never touch |
| 8 | Assume .BAK frees space | Same filesystem | Warn; delete or move |
| 9 | Auto-apply Section F | Unwanted DB cap | Opt-in only |
| 10 | Skip compose config check | Recreate won't help | E1 before E2 |
| 11 | No sudo on non-root | Silent failure | P1 detects privilege |
| 12 | Assume Docker Compose | May be bare Node.js | P2 detects runtime |
| 13 | Default thresholds on small disk | 80% of 25GB = 5GB free | Auto-adjust < 50GB |
| 14 | Asking user for VPS IP | Wastes time, breaks flow | Use VPS Registry lookup |
| 15 | Chaining many cmds in one SSH | Hookify may block compound | Split into focused commands |
| 16 | Skipping n8n health verification | Disk OK but n8n broken | Always run Section H |

---

## Usage Examples

```bash
/n8nspace                                    # Default (auto-adjusts for small disks)
/n8nspace dry_run=true                       # Audit mode
/n8nspace emergency=true                     # Full purge
/n8nspace threshold_action=90 keep_binary_backup=false  # Custom
/n8nspace max_age_hours=72                   # 3-day retention
```

---

*n8nspace v2.1 — Preflight (multi-runtime) -> Snapshot -> Cleanup -> Reclaim -> Env Audit -> Cron Check -> Health Verify*
*Created: 2026-02-18 | Updated: 2026-03-04*
