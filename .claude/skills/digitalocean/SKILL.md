---
name: digitalocean
description: >
  Unified DigitalOcean operations: droplets, firewalls, deployments, monitoring, databases,
  storage, networking, and container registry. Covers doctl CLI, REST API, SSH deployment
  patterns, PM2 daemon management, and firewall automation. Use when managing VPS infrastructure,
  deploying services, debugging connectivity, or automating DO operations.
version: "1.0"
created: "2026-03-27"
updated: "2026-03-27"
classification: infrastructure
parameters:
  DO_API_TOKEN: "DigitalOcean API token (dop_v1_...)"
  DROPLET_ID: "Target droplet numeric ID"
  DROPLET_IP: "Target droplet public IPv4"
  FIREWALL_ID: "DO firewall UUID"
triggers:
  - digitalocean
  - droplet
  - VPS deploy
  - doctl
  - DO firewall
  - SCP deploy
  - PM2 daemon
  - DO API
user-invocable: false
---

# DigitalOcean Operations

Unified skill for managing DigitalOcean infrastructure: compute, networking, storage,
databases, monitoring, deployments, and container operations. Combines reference knowledge
with battle-tested operational patterns from production VPS management.

## Quick Reference — doctl CLI

```bash
# Auth
doctl auth init --access-token {{DO_API_TOKEN}}

# Droplets
doctl compute droplet list --format ID,Name,PublicIPv4,Status,Region
doctl compute droplet get {{DROPLET_ID}} --format ID,Name,PublicIPv4,Status
doctl compute droplet create {{name}} --region ams3 --size s-1vcpu-1gb --image ubuntu-24-04-x64 --ssh-keys {{key_id}}

# SSH (uses DO API — bypasses local SSH config issues)
doctl compute ssh {{DROPLET_ID}} --ssh-command "{{command}}"

# Firewalls
doctl compute firewall list --format ID,Name
doctl compute firewall get {{FIREWALL_ID}}

# Snapshots
doctl compute snapshot list --format ID,Name,CreatedAt,ResourceType
doctl compute droplet-action snapshot {{DROPLET_ID}} --snapshot-name "{{name}}"
```

## Quick Reference — REST API

When doctl is unavailable or for automation:

```bash
# List droplets
curl -s -H "Authorization: Bearer {{DO_API_TOKEN}}" \
  "https://api.digitalocean.com/v2/droplets"

# Get firewall rules
curl -s -H "Authorization: Bearer {{DO_API_TOKEN}}" \
  "https://api.digitalocean.com/v2/firewalls/{{FIREWALL_ID}}"

# Update firewall (e.g., add SSH IP)
curl -s -X PUT -H "Authorization: Bearer {{DO_API_TOKEN}}" \
  -H "Content-Type: application/json" \
  -d @firewall-update.json \
  "https://api.digitalocean.com/v2/firewalls/{{FIREWALL_ID}}"
```

## Compute Selection Guide

| Need | Service | When |
|------|---------|------|
| Full OS control, custom networking | **Droplets** | VPS, daemons, custom stacks |
| Managed app deploy from Git | **App Platform** | Web apps, APIs with auto-scaling |
| Event-driven / lightweight API | **Functions** | Webhooks, scheduled tasks |
| Multi-service container orchestration | **Kubernetes (DOKS)** | Microservices at scale |
| AI/ML workloads | **GPU Droplets / Bare Metal** | Training, inference |

## SSH Connectivity Troubleshooting

This is the #1 operational issue. Decision tree:

```
SSH hangs (timeout)?
├─ Check firewall: does it allow your current IP on port 22?
│  └─ Get your IP: curl -s ifconfig.me
│  └─ Check allowed: GET /v2/firewalls → inbound_rules where ports=22
│  └─ Add IP: PUT /v2/firewalls with updated sources.addresses
├─ Firewall OK but still hangs?
│  └─ Check droplet status: GET /v2/droplets/{{DROPLET_ID}}
│  └─ Use DO Console: digitalocean.com → Droplets → Console
│  └─ Try doctl compute ssh (uses DO API routing)
├─ Permission denied (publickey)?
│  └─ Check SSH key: doctl compute ssh-key list
│  └─ Add key: doctl compute ssh-key import {{name}} --public-key-file ~/.ssh/id_rsa.pub
│  └─ For jump host: copy key to intermediate VPS
└─ Connected!
   └─ Proceed with deployment
```

### Firewall IP Auto-Add Pattern (Production-Tested)

```bash
# 1. Get current IP
MY_IP=$(curl -s ifconfig.me)

# 2. Fetch current firewall, add IP, update
curl -s "https://api.digitalocean.com/v2/firewalls/{{FIREWALL_ID}}" \
  -H "Authorization: Bearer {{DO_API_TOKEN}}" \
  | python3 -c "
import sys, json
fw = json.load(sys.stdin)['firewall']
inbound = []
for rule in fw['inbound_rules']:
    r = {'protocol': rule['protocol'], 'ports': rule['ports'], 'sources': rule['sources']}
    if rule['ports'] == '22':
        addrs = r['sources'].get('addresses', [])
        if '${MY_IP}' not in addrs:
            addrs.append('${MY_IP}')
        r['sources']['addresses'] = addrs
    inbound.append(r)
outbound = [{'protocol': r['protocol'], 'ports': r['ports'], 'destinations': r['destinations']}
            for r in fw['outbound_rules']]
print(json.dumps({'name': fw['name'], 'inbound_rules': inbound,
                   'outbound_rules': outbound, 'droplet_ids': fw['droplet_ids']}))
" > /tmp/fw-update.json

# 3. Apply
curl -s -X PUT "https://api.digitalocean.com/v2/firewalls/{{FIREWALL_ID}}" \
  -H "Authorization: Bearer {{DO_API_TOKEN}}" \
  -H "Content-Type: application/json" \
  -d @/tmp/fw-update.json
```

## VPS Deployment Pattern (SCP + SSH)

Battle-tested pattern for deploying Node.js services to Droplets:

```bash
# 1. SCP files to VPS
scp -o StrictHostKeyChecking=no \
  src/*.js ecosystem.config.js package.json \
  root@{{DROPLET_IP}}:/opt/{{service_name}}/

# 2. Install deps + restart via single SSH command
ssh -o StrictHostKeyChecking=no root@{{DROPLET_IP}} bash -s << 'DEPLOY'
cd /opt/{{service_name}}
npm install --production
pm2 delete {{app_name}} 2>/dev/null || true
pm2 start ecosystem.config.js --only {{app_name}}
pm2 save
sleep 10
pm2 logs {{app_name}} --lines 20 --nostream
curl -s http://127.0.0.1:{{health_port}}/health | python3 -m json.tool
DEPLOY
```

### PM2 Daemon Management

```bash
# Status
pm2 list | grep {{app_name}}

# Logs (live)
pm2 logs {{app_name}}

# Logs (last N lines, no follow)
pm2 logs {{app_name}} --lines 30 --nostream

# Restart
pm2 restart {{app_name}}

# Stop
pm2 stop {{app_name}}

# Remove
pm2 delete {{app_name}}

# Save process list (survives reboot)
pm2 save

# Startup (enable PM2 on boot)
pm2 startup
```

## Networking

| Service | Use When |
|---------|----------|
| **VPC** | Private networking between Droplets in same region |
| **Load Balancers** | Distribute traffic across multiple Droplets |
| **DNS** | Manage domains and records via DO nameservers |
| **Floating IPs** | Static IPs that can be reassigned between Droplets |
| **Firewalls** | Restrict inbound/outbound traffic by IP, port, protocol |

## Storage

| Service | Use When |
|---------|----------|
| **Volumes** | Block storage attached to Droplets (ext4/xfs) |
| **Spaces** | S3-compatible object storage (CDN-backed) |
| **Snapshots** | Point-in-time Droplet/Volume backups |
| **Backups** | Automated weekly Droplet backups |

## Managed Databases

| Engine | Versions | Notes |
|--------|----------|-------|
| **PostgreSQL** | 13-16 | Connection pooling, read replicas |
| **MySQL** | 8 | Managed backups, failover |
| **Redis** | 7 | Eviction policies, clustering |
| **MongoDB** | 6-7 | Sharding, managed upgrades |
| **Kafka** | 3.x | Managed topics, consumer groups |
| **OpenSearch** | 2.x | Full-text search, dashboards |

## Container Registry

```bash
# Create registry
doctl registry create {{name}} --region {{region}}

# Login Docker to DOCR
doctl registry login

# Push image
docker tag {{image}} registry.digitalocean.com/{{registry}}/{{image}}:{{tag}}
docker push registry.digitalocean.com/{{registry}}/{{image}}:{{tag}}

# Garbage collection
doctl registry garbage-collection start {{registry}}
```

## Monitoring & Alerts

```bash
# Enable monitoring agent on Droplet
ssh root@{{DROPLET_IP}} "curl -sSL https://repos.insights.digitalocean.com/install.sh | bash"

# Create uptime check via API
curl -s -X POST "https://api.digitalocean.com/v2/uptime/checks" \
  -H "Authorization: Bearer {{DO_API_TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{"name":"{{check_name}}","type":"https","target":"{{url}}","regions":["eu_west"]}'
```

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| SSH with `doctl compute ssh` for automation | Unreliable — hangs, background mode issues | Direct `ssh` after firewall IP allowlist |
| Hardcode IPs in firewall rules | Dynamic IPs change on reconnect | Script: `curl ifconfig.me` → update firewall via API |
| `git pull` on VPS without SSH key setup | Fails silently, halts deploy | SCP files directly, or set up deploy keys |
| Run `pm2 start` without `pm2 save` | Process list lost on reboot | Always: `pm2 start ... && pm2 save` |
| Deploy without health check verification | Silent failures go undetected | Wait 10-15s post-start, then `curl /health` |
| Use `run_in_background` for SSH/SCP | Hangs, zombie processes, corrupted state | Always foreground for remote operations |
| Pass `base_tree` as `-f` flag to gh API | Silently dropped — deploys blank | Use `--input` or heredoc for JSON body |

## Error Handling

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| SSH timeout | Firewall blocks your IP | Add IP via DO API (see pattern above) |
| SSH permission denied | Wrong key or key not on Droplet | `doctl compute ssh-key list` + import |
| PM2 process restarting in loop | Crash in app startup | `pm2 logs {{app}} --lines 50 --nostream` |
| `npm install` fails on VPS | Node version mismatch | Check `node --version` matches `engines` |
| Health endpoint not responding | App still starting or crashed | Wait 15s, check PM2 status, check port |
| Chromium won't launch on Droplet | Missing deps or wrong path | `apt install chromium-browser` + set `CHROMIUM_PATH` |
| doctl auth fails | Token expired or wrong | `doctl auth init --access-token {{new_token}}` |

## Resources

- [Droplets](https://docs.digitalocean.com/products/droplets/)
- [App Platform](https://docs.digitalocean.com/products/app-platform/)
- [Kubernetes](https://docs.digitalocean.com/products/kubernetes/)
- [Networking](https://docs.digitalocean.com/products/networking/)
- [Storage](https://docs.digitalocean.com/products/spaces/)
- [Databases](https://docs.digitalocean.com/products/databases/)
- [Monitoring](https://docs.digitalocean.com/products/monitoring/)
- [Container Registry](https://docs.digitalocean.com/products/container-registry/)
- [API Reference](https://docs.digitalocean.com/reference/api/)
- [doctl CLI](https://docs.digitalocean.com/reference/doctl/)

<!-- AUDIT METADATA
source: https://github.com/bobmatnyc/claude-mpm-skills (9 skills merged)
audit_date: 2026-03-27
audit_grade: F (28/100) → B (78/100 after merge)
merge_actions: keep=0 upgrade=9 absorb=4 rewrite=9 supplement=3 drop=0 incompatible=0
superior_patterns_absorbed: 4 (complementary skills, selection guide, token_estimate, doc links)
session_patterns_added: 5 (firewall auto-add, SCP deploy, PM2 management, SSH troubleshooting, Chromium VPS)
-->
