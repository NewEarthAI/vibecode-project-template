---
name: digitalocean-infra
description: |
  DigitalOcean droplet health, disk, memory, and container diagnostics via SSH + doctl.
  Self-healing integration: reads infra_health_checks, triggers remediation, reports to portal.
  Covers Droplet status, metrics, resize, snapshots, firewall, and n8n-specific operations.
  Complements n8nspace (disk-level) with infrastructure-level visibility and control.
version: 1.0.0
created: 2026-04-13
updated: 2026-04-13
classification: infrastructure
user-invocable: true
triggers:
  - "digitalocean"
  - "droplet status"
  - "droplet health"
  - "VPS health"
  - "infra check"
  - "server status"
  - "disk space on server"
  - "n8n server"
  - "self-healing"
  - "remediate"
parameters:
  - name: droplet
    type: string
    default: primary
    note: "Registry key from VPS Registry table. 'primary' = n8n server."
  - name: mode
    type: string
    default: health
    note: "health | metrics | remediate | snapshot | resize"
  - name: format
    type: string
    default: summary
    note: "summary (one-card) | full (all sections) | json (machine-readable)"
validated_on:
  - "24h n8n outage caused by SQLite bloat + disk-guard misconfiguration (2026-04-13)"
  - "Disk 94% → emergency docker prune destroyed n8n container + image"
  - "Self-healing spec 14 (specs/14_N8N_INFRA_SELF_HEALING.md)"
---

# digitalocean-infra — Droplet Health & Self-Healing

**Target**: DigitalOcean droplets managed by your organization
**How to run**: `/digitalocean-infra` or `/digitalocean-infra mode=remediate`
**Complements**: `n8nspace` (app-level disk), your project's infra self-healing spec (if any)
**Safety**: Never resizes or destroys droplets without explicit confirmation. SSH-only operations are safe.

---

## VPS Registry

Fill in your droplet details during `/setup`. One row per managed droplet.

| Key | Droplet Name | IP | Disk | Region | SSH User | Purpose | n8n MCP |
|-----|-------------|-----|------|--------|----------|---------|---------|
| `primary` | {{primary_droplet_name}} | {{primary_ip}} | {{primary_disk}}GB | {{primary_region}} | {{ssh_user}} | n8n + automations | {{n8n_mcp_primary}} |
| `agent` | {{agent_droplet_name}} | {{agent_ip}} | {{agent_disk}}GB | {{agent_region}} | {{ssh_user}} | VPS agent execution | N/A |

**Auto-selection**: If user says "droplet", "server", "VPS", or "n8n" without specifying — use `primary`.
**All SSH commands**: `ssh -o ConnectTimeout=10 root@<IP> "<command>"`
**Connection test**: Always verify SSH first: `ssh -o ConnectTimeout=10 root@<IP> "echo OK"`

---

## Mode: health (default)

Run all checks, produce a single health card. This is the entry point for diagnostics.

### H1: System Vitals

```bash
ssh root@<IP> "echo '---DISK---' && df -h / && echo '---MEMORY---' && free -h && echo '---UPTIME---' && uptime && echo '---LOAD---' && cat /proc/loadavg"
```

### H2: Docker Container Status

```bash
ssh root@<IP> "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"
```

Flag: any container not "Up". Flag: n8n container missing entirely (see incident 2026-04-13).

### H3: n8n Application Health

```bash
ssh root@<IP> "curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5678/healthz"
```

Expected: `200`. Non-200 = n8n down despite container running.

### H4: SQLite Database Size

```bash
ssh root@<IP> "ls -lh /opt/n8n/n8n_data/database.sqlite && sqlite3 /opt/n8n/n8n_data/database.sqlite 'SELECT COUNT(*) FROM execution_entity; PRAGMA freelist_count; PRAGMA auto_vacuum;'"
```

Thresholds: >5GB = WARNING, >8GB = CRITICAL. Freelist >500k pages = needs VACUUM.

### H5: Cron Guard Status

```bash
ssh root@<IP> "cat /etc/cron.d/n8n-disk-guard 2>/dev/null && echo '---VACUUM-CRON---' && cat /etc/cron.d/n8n-sqlite-vacuum 2>/dev/null && echo '---LAST-GUARD-LOG---' && tail -5 /var/log/n8n-disk-guard.log 2>/dev/null"
```

Verify: THRESH_EMERG=95 (not 80). Verify: VACUUM cron exists.

### H6: Network / Firewall

```bash
ssh root@<IP> "ufw status numbered 2>/dev/null | head -15"
```

Flag: port 5678 exposed publicly (should be loopback only via Cloudflare tunnel).

### H7: External Accessibility

Run from LOCAL machine (not SSH):
```bash
curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://{{n8n_url}}/healthz
```

Expected: `200`. If SSH H3=200 but H7=502 → tunnel/proxy issue (not n8n).

### Health Card Output

```
DROPLET HEALTH: {{droplet_name}} ({{IP}})
═══════════════════════════════════════════
  Disk:       {{pct}}% ({{free}} free / {{total}})    {{OK/WARN/CRIT}}
  Memory:     {{available}} available                  {{OK/WARN/CRIT}}
  Load:       {{1m}} / {{5m}} / {{15m}}                {{OK/WARN}}
  Container:  n8n {{Up Xh}} | cloudflared {{Up Xw}}   {{OK/DOWN}}
  n8n API:    {{http_code}} ({{ms}}ms)                 {{OK/FAIL}}
  SQLite:     {{size}} ({{exec_count}} execs)          {{OK/WARN/CRIT}}
  Cron Guard: EMERG={{thresh}}%                        {{OK/MISCONFIGURED}}
  Firewall:   {{rule_count}} rules                     {{CLEAN/ISSUES}}
  External:   {{http_code}}                            {{OK/FAIL}}
  Uptime:     {{days}}d {{hours}}h
═══════════════════════════════════════════
  OVERALL: {{HEALTHY / DEGRADED / CRITICAL}}
  {{If degraded/critical: recommended action}}
```

Thresholds:
| Check | OK | WARN | CRIT |
|-------|-----|------|------|
| Disk | <70% | 70-90% | >90% |
| Memory available | >500MB | 200-500MB | <200MB |
| Load (1m) | <2.0 | 2.0-4.0 | >4.0 |
| SQLite | <5GB | 5-8GB | >8GB |
| n8n API | 200 | — | non-200 |

---

## Mode: metrics

Deeper performance data for investigation (not default — use when health shows issues).

```bash
ssh root@<IP> "echo '---TOP-CPU---' && ps aux --sort=-%cpu | head -6 && echo '---TOP-MEM---' && ps aux --sort=-%mem | head -6 && echo '---DISK-IO---' && iostat -x 1 2 2>/dev/null | tail -5 && echo '---DOCKER-STATS---' && docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'"
```

---

## Mode: remediate

Auto-fix common issues. Each action has guards to prevent cascading failures.

### R1: n8n Container Down → Restart

**Trigger**: H2 shows n8n not running OR H3 returns non-200
**Guard**: Max 3 attempts per hour. Check disk >2GB free before pulling image.

```bash
ssh root@<IP> "cd /opt/n8n && docker compose up -d n8n"
```

If container was destroyed (not in `docker ps -a`): image pull required. Verify disk has >2GB free first.

### R2: Disk High → Run n8nspace Guard

**Trigger**: H1 shows disk >85%
**Guard**: Max 1 per hour.

```bash
ssh root@<IP> "/usr/local/sbin/n8n-disk-guard.sh"
```

If still >90% after guard: escalate to VACUUM (R3).

### R3: SQLite Bloated → Orphan Cleanup + VACUUM

**Trigger**: H4 shows SQLite >5GB
**Guard**: Max 1 per 24h. Requires disk >3GB free. Requires n8n stop.

```bash
ssh root@<IP> "cd /opt/n8n && docker compose stop n8n && sqlite3 /opt/n8n/n8n_data/database.sqlite 'DELETE FROM execution_data WHERE executionId NOT IN (SELECT id FROM execution_entity); VACUUM;' && docker compose up -d n8n"
```

If disk too low for VACUUM: delete in 5k batches first (same pattern as incident 2026-04-13).

### R4: Cron Guard Misconfigured → Fix

**Trigger**: H5 shows THRESH_EMERG != 95
**Action**: Rewrite cron file with correct thresholds.

### Remediation Output

```
REMEDIATION REPORT: {{droplet_name}}
═════════════════════════════════════
  Action:  {{R1/R2/R3/R4}}
  Trigger: {{what was detected}}
  Command: {{exact command run}}
  Result:  {{SUCCESS / FAILED}}
  Before:  {{metric before}}
  After:   {{metric after}}
  Duration: {{seconds}}
═════════════════════════════════════
```

---

## Mode: snapshot

Create a point-in-time snapshot of the droplet (requires `doctl` or DigitalOcean API).

```bash
doctl compute droplet-action snapshot <droplet_id> --snapshot-name "pre-maintenance-$(date +%F)" --wait
```

If `doctl` not available: use DigitalOcean API via curl:
```bash
curl -s -X POST "https://api.digitalocean.com/v2/droplets/<droplet_id>/actions" \
  -H "Authorization: Bearer $DO_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"snapshot","name":"pre-maintenance-'$(date +%F)'"}'
```

**Always snapshot before resize or major maintenance.**

---

## Mode: resize

Resize droplet (DESTRUCTIVE — requires explicit confirmation).

**CONFIRMATION GATE**: Print current size, target size, estimated cost delta, and downtime estimate. Wait for explicit "yes" before proceeding.

```bash
doctl compute droplet-action resize <droplet_id> --size <slug> --wait
```

Common size slugs for reference:
| Slug | vCPUs | RAM | Disk | $/mo |
|------|-------|-----|------|------|
| `s-2vcpu-4gb` | 2 | 4GB | 80GB | $24 |
| `s-2vcpu-4gb-amd` | 2 | 4GB | 25GB | $21 (current) |
| `s-4vcpu-8gb` | 4 | 8GB | 160GB | $48 |

**Note**: Disk resize is permanent (cannot downsize disk). RAM/CPU can flex.

---

## Integration: Spec 14 Self-Healing

This skill provides the **execution layer** for spec 14's three tiers:

| Spec 14 Layer | This Skill's Role |
|---|---|
| L1 Prevention | `mode=health` detects drift before failure |
| L2 Detection | Health card feeds `infra_health_checks` table |
| L3 Remediation | `mode=remediate` executes auto-fix actions |

### Writing to infra_health_checks (L2)

After each health check, write results to Supabase:
```sql
INSERT INTO infra_health_checks (droplet_name, check_type, status, value_numeric, value_text)
VALUES
  ('{{droplet_name}}', 'disk', '{{ok/warning/critical}}', {{pct}}, '{{free}} free'),
  ('{{droplet_name}}', 'n8n_api', '{{ok/critical}}', {{http_code}}, '{{response_time}}ms'),
  ('{{droplet_name}}', 'sqlite', '{{ok/warning/critical}}', {{size_gb}}, '{{exec_count}} execs'),
  ('{{droplet_name}}', 'container', '{{ok/critical}}', NULL, '{{container_status}}'),
  ('{{droplet_name}}', 'memory', '{{ok/warning/critical}}', {{avail_mb}}, '{{avail_human}}');
```

### Triggering Remediation (L3)

When `mode=remediate` runs (manually or via n8n workflow), log to `infra_remediation_log`:
```sql
INSERT INTO infra_remediation_log (health_check_id, action_type, command, result, output)
VALUES ('{{check_id}}', '{{restart/disk_cleanup/vacuum}}', '{{cmd}}', '{{success/failed}}', '{{stdout}}');
```

---

## Complementary Skills

| Skill | Relationship |
|-------|-------------|
| `n8nspace` | App-level disk management (binaryData, env vars, pruning). This skill = infra-level. |
| `ssh-claude-setup` | SSH tunnel and remote Claude Code execution. This skill uses SSH for diagnostics. |
| Your infra self-healing spec | Architecture spec (if written). This skill = execution layer. |

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `docker system prune -af` while n8n is stopped | Destroys container + image → can't restart without re-pull | Only prune while n8n is running (image in use = protected) |
| THRESH_EMERG=80 on a 25GB disk | SQLite bloat keeps disk >80% permanently → hourly kill cycle | THRESH_EMERG=95 for small disks; clean SQLite separately |
| Deleting all `execution_entity` but not `execution_data` | execution_data has the large JSON blobs; entity is just metadata | Always clean both: `DELETE FROM execution_data WHERE executionId NOT IN (SELECT id FROM execution_entity)` |
| VACUUM without checking free disk | VACUUM creates temp copy → needs free space equal to final DB size | Check `df` before VACUUM; delete in batches first if tight |
| VACUUM while n8n is running | SQLite write lock blocks n8n → timeouts and errors | Stop n8n → VACUUM → restart |
| Resizing disk down | DigitalOcean disk resize is permanent (up only) | Always snapshot before resize; plan disk size carefully |
| Polling droplet status from n8n on the same droplet | If n8n is down, the monitor is down too | Use external dead-man's switch (edge function or Mac cron) |
| Assuming `docker ps` "Up" = healthy | Container can be "Up" but n8n crashed inside it | Always check `curl localhost:5678/healthz` after container status |

---

## Error Handling

| Condition | Action |
|-----------|--------|
| SSH connection refused | Check: Is droplet running? (DigitalOcean console). Check: SSH key authorized? Check: Firewall port 22. |
| SSH timeout | Check: Droplet responsive? Try DigitalOcean console. May need hard reboot via API. |
| n8n container missing from `docker ps -a` | Image may also be missing. Check `docker images`. If missing: need `docker compose up -d` (pulls image). Verify disk has >2GB free. |
| VACUUM fails "disk full" | Delete execution_data in batches of 5000. Delete old backups. Then retry VACUUM. |
| `doctl` not installed | Fall back to DigitalOcean API via curl with `$DO_API_TOKEN`. |
| DigitalOcean API 401 | Token expired or missing. Check `$DO_API_TOKEN` env var. |
| Auto-remediation exceeds retry limit | Stop retrying. Send WhatsApp alert. Log failure to `infra_remediation_log`. |

<!-- AUDIT METADATA
source: bobmatnyc/claude-mpm-skills (digitalocean-management + digitalocean-compute)
source_grade: F (23/100)
audit_date: 2026-04-13
merge_actions: keep=0 upgrade=0 absorb=2 rewrite=6 supplement=0 drop=4 incompatible=0
superior_patterns_absorbed: 2 (complementary skills, compute selection guide)
merge_type: REWRITE — source was documentation summaries; rebuilt from operational experience
validated_against: specs/14_N8N_INFRA_SELF_HEALING.md, incident 2026-04-13
-->
