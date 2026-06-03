---
name: ssh-claude-setup
description: |
  Set up a Mac for remote Claude Code execution via SSH tunnel from n8n.
  Use when connecting a new Mac to the SSH execution pipeline, setting up
  reverse SSH tunnels through a VPS, creating n8n SSH credentials, or
  troubleshooting SSH execution failures. Covers: Remote Login verification,
  autossh tunnel setup, launchd persistence, VPS firewall rules, n8n credential
  creation, workflow path configuration, and end-to-end testing.
version: 1.0
classification: encoded-preference
created: 2026-03-09
updated: 2026-03-09
validated_on:
  - "Mac setup via reverse SSH tunnel through VPS to n8n Docker"
parameters:
  - name: vps_ip
    type: string
    default: ""
    description: "Public IP of VPS hosting n8n"
  - name: vps_user
    type: string
    default: "root"
  - name: docker_gateway
    type: string
    default: "172.18.0.1"
    description: "Docker bridge gateway IP (n8n container reaches host via this)"
  - name: docker_subnet
    type: string
    default: "172.18.0.0/16"
  - name: n8n_host
    type: string
    default: ""
    description: "Base URL of your n8n instance (e.g., https://n8n.example.com)"
  - name: workflow_id
    type: string
    default: ""
    description: "ID of the SSH execution workflow in n8n"
  - name: webhook_path
    type: string
    default: ""
    description: "Webhook path for the SSH execution workflow"
  - name: org_slug
    type: string
    default: "{{organization_slug}}"
    description: "Organization slug for launchd plist naming"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
paths:
  - "infrastructure/**"
  - "deployment/**"
---

# SSH Claude Setup — Remote Execution via n8n

> Sets up a Mac to receive SSH commands from n8n (Docker on VPS) that execute Claude Code in local project repos.

## Architecture

```
n8n (Docker container) ──→ VPS host:{{tunnel_port}} ──→ reverse tunnel ──→ Mac:22 ──→ Claude Code
   172.18.0.2                 172.18.0.1 (gateway)          autossh           sshd      runs locally
```

**Why this architecture**: n8n runs in Docker on the VPS. It can't reach the Mac directly (behind NAT). The Mac opens a reverse tunnel TO the VPS, and n8n connects through the Docker gateway IP.

---

## Port Registry

Each Mac gets a unique port. **Never reuse ports.**

| Port | Machine | Status |
|------|---------|--------|
| 2222 | (assign to first Mac) | Available |
| 2223 | (assign to second Mac) | Available |
| 2224+ | Future machines | Available |

To find the next available port, check what's already listening on the VPS:
```bash
ssh {{vps_user}}@{{vps_ip}} "ss -tlnp | grep -E '222[0-9]'"
```

---

## Execution Steps

### Phase 0: Preflight Checks

Run ALL checks before any setup. Stop on first failure.

#### 0a. Detect Machine Identity

```bash
echo "Hostname: $(hostname)"
echo "Username: $(whoami)"
echo "macOS: $(sw_vers -productVersion)"
echo "Arch: $(uname -m)"
```

Store results for later steps. The username is critical — it appears in SSH credentials, paths, and launchd plists.

#### 0b. Verify Remote Login

```bash
sudo systemsetup -getremotelogin 2>/dev/null || echo "CHECK_MANUALLY"
```

If OFF: **Stop and ask user** to enable via System Settings → General → Sharing → Remote Login → ON for their user.

**Cannot be enabled programmatically** — requires System Settings UI.

#### 0c. Verify Password Authentication

```bash
grep -E "^PasswordAuthentication|^KbdInteractiveAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "DEFAULTS_APPLY"
```

- If both commented out or missing → defaults to `yes` (OK)
- If `PasswordAuthentication no` → **STOP** — n8n SSH node needs password auth
- Fix: `sudo sed -i '' 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config`

#### 0d. Verify autossh

```bash
which autossh 2>/dev/null || echo "NOT_INSTALLED"
```

If missing: `brew install autossh` (requires Homebrew)

#### 0e. Verify Claude Code

```bash
# Find claude binary
which claude 2>/dev/null || find /Users/$(whoami)/.local/bin /usr/local/bin /opt/homebrew/bin -name "claude" 2>/dev/null
```

Record the full path — needed for PATH setup in SSH commands.

#### 0f. Verify Node.js / nvm

```bash
# Find node version
ls /Users/$(whoami)/.nvm/versions/node/ 2>/dev/null || node --version 2>/dev/null
```

Record the node version path — needed for PATH setup. Format: `/Users/{{username}}/.nvm/versions/node/{{version}}/bin`

#### 0g. Verify SSH Key for VPS

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 {{vps_user}}@{{vps_ip}} "echo KEY_AUTH_OK" 2>&1
```

If fails: Copy key to VPS:
```bash
ssh-copy-id {{vps_user}}@{{vps_ip}}
```

---

### Phase 1: Assign Port

**Ask user**: "Is this the primary Mac, secondary Mac, or a new addition?"

Based on response:
- Primary → `tunnel_port=2222`
- Secondary → `tunnel_port=2223`
- New → Check VPS for next available port starting at 2224

Verify port not already in use on VPS:
```bash
ssh {{vps_user}}@{{vps_ip}} "ss -tlnp | grep :{{tunnel_port}}" 2>&1
```

If in use → choose next available port.

---

### Phase 2: VPS Configuration

#### 2a. Ensure GatewayPorts enabled

```bash
ssh {{vps_user}}@{{vps_ip}} "grep -E '^GatewayPorts' /etc/ssh/sshd_config"
```

If not set or set to `no`:
```bash
ssh {{vps_user}}@{{vps_ip}} "sudo sed -i 's/^#*GatewayPorts.*/GatewayPorts clientspecified/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
```

**CRITICAL**: Use `clientspecified` not `yes` — this lets the client control which interface to bind to without opening all tunnels to the world.

#### 2b. Add UFW Rules

Two rules per tunnel port — block public, allow Docker:

```bash
# Block public internet access to tunnel port
ssh {{vps_user}}@{{vps_ip}} "sudo ufw deny in on eth0 to any port {{tunnel_port}} comment 'Block public SSH tunnel port {{tunnel_port}}'"

# Allow n8n Docker subnet to reach tunnel port
ssh {{vps_user}}@{{vps_ip}} "sudo ufw allow from {{docker_subnet}} to any port {{tunnel_port}} comment 'Allow n8n Docker to SSH tunnel {{tunnel_port}}'"
```

Verify:
```bash
ssh {{vps_user}}@{{vps_ip}} "sudo ufw status | grep {{tunnel_port}}"
```

Expected: DENY from eth0, ALLOW from Docker subnet.

---

### Phase 3: Create Reverse Tunnel

#### 3a. Start tunnel manually first (test)

```bash
autossh -M 0 -f -N -R 0.0.0.0:{{tunnel_port}}:localhost:22 {{vps_user}}@{{vps_ip}} \
  -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "ExitOnForwardFailure yes"
```

#### 3b. Verify tunnel is listening on VPS

```bash
ssh {{vps_user}}@{{vps_ip}} "ss -tlnp | grep :{{tunnel_port}}"
```

Expected: `LISTEN 0 128 0.0.0.0:{{tunnel_port}} 0.0.0.0:*`

#### 3c. Test SSH through tunnel from VPS

```bash
ssh {{vps_user}}@{{vps_ip}} "ssh -o ConnectTimeout=5 -p {{tunnel_port}} $(whoami)@localhost 'echo TUNNEL_OK'" 2>&1
```

This will prompt for password (expected). If it connects → tunnel works.

---

### Phase 4: Create launchd Plist (Persistence)

#### 4a. Kill the manual autossh process

```bash
pgrep -f "autossh.*{{tunnel_port}}" | xargs kill 2>/dev/null
```

#### 4b. Write the plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.{{org_slug}}.ssh-tunnel</string>

    <key>ProgramArguments</key>
    <array>
        <string>{{autossh_path}}</string>
        <string>-M</string>
        <string>0</string>
        <string>-N</string>
        <string>-R</string>
        <string>0.0.0.0:{{tunnel_port}}:localhost:22</string>
        <string>{{vps_user}}@{{vps_ip}}</string>
        <string>-o</string>
        <string>ServerAliveInterval 30</string>
        <string>-o</string>
        <string>ServerAliveCountMax 3</string>
        <string>-o</string>
        <string>ExitOnForwardFailure yes</string>
        <string>-o</string>
        <string>StrictHostKeyChecking no</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>AUTOSSH_GATETIME</key>
        <string>0</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/ssh-tunnel.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/ssh-tunnel.err</string>
</dict>
</plist>
```

Write to: `~/Library/LaunchAgents/com.{{org_slug}}.ssh-tunnel.plist`

**CRITICAL**: `AUTOSSH_GATETIME=0` prevents autossh from exiting if the first connection attempt fails (important during boot when network isn't ready yet).

#### 4c. Load the agent

```bash
launchctl load ~/Library/LaunchAgents/com.{{org_slug}}.ssh-tunnel.plist
```

#### 4d. Verify

```bash
launchctl list | grep {{org_slug}}
# Expected: PID  0  com.{{org_slug}}.ssh-tunnel (exit status 0 = running)

pgrep -f "autossh.*{{tunnel_port}}"
# Expected: a PID number

ssh {{vps_user}}@{{vps_ip}} "ss -tlnp | grep :{{tunnel_port}}"
# Expected: LISTEN on the port
```

---

### Phase 5: Create n8n SSH Credential

**This step requires manual action in the n8n UI.** Guide the user:

```
1. Open {{n8n_host}} in browser
2. Go to Settings → Credentials → Add Credential
3. Search for "SSH" → select "SSH" (not SFTP)
4. Fill in:
   - Credential Name: "{{hostname}} SSH - {{machine_role}}"
   - Authentication: Password
   - Host: {{docker_gateway}}     ← NOT localhost, NOT VPS public IP
   - Port: {{tunnel_port}}
   - Username: {{username}}
   - Password: (Mac login password)
5. Click "Test" — should show green checkmark
6. Save
7. Note the credential ID from the URL
```

**WHY `{{docker_gateway}}` not `localhost`**: n8n runs inside a Docker container. `localhost` inside the container refers to the container itself, not the VPS host. The Docker gateway IP (`{{docker_gateway}}`) routes traffic from the container to the host, where the tunnel port is listening.

**Ask user for the credential ID after saving.**

---

### Phase 6: Update SSH Execution Workflow

The workflow's path-resolution node contains a `REPO_MAP` that maps project slugs to local filesystem paths. This is **machine-specific** — each Mac has its own path structure.

#### 6a. Detect repo locations on this Mac

```bash
# Find known project repos — customize this list for your projects
for slug in $(ls clients/ 2>/dev/null | grep -v _template); do
  found=$(find /Users/$(whoami) -maxdepth 4 -name "*$slug*" -type d 2>/dev/null | head -1)
  echo "$slug: ${found:-NOT_FOUND}"
done
```

#### 6b. Build the REPO_MAP

Map project slugs to discovered paths:
```javascript
const REPO_MAP = {
  '{{slug_1}}': '{{path_1}}',
  '{{slug_2}}': '{{path_2}}',
  // Add all project repos on this Mac
};
```

#### 6c. Update the workflow

Read the current workflow JSON, update the REPO_MAP in the path resolution node, and also update the SSH credential reference in the SSH execution node:

```json
"credentials": {
  "sshPassword": {
    "id": "{{credential_id}}",
    "name": "{{credential_name}}"
  }
}
```

#### 6d. Deploy via API

```bash
# Deactivate → PUT → Activate
N8N_KEY=$(cat ~/.claude/settings.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mcpServers']['{{n8n_mcp_server}}']['env']['N8N_API_KEY'])")

curl -s -X POST "{{n8n_host}}/api/v1/workflows/{{workflow_id}}/deactivate" \
  -H "X-N8N-API-KEY: $N8N_KEY" -H "Content-Type: application/json"

# PUT the updated workflow (strip tags, staticData, active)
cat updated-workflow.json | curl -s -X PUT "{{n8n_host}}/api/v1/workflows/{{workflow_id}}" \
  -H "X-N8N-API-KEY: $N8N_KEY" -H "Content-Type: application/json" -d @-

curl -s -X POST "{{n8n_host}}/api/v1/workflows/{{workflow_id}}/activate" \
  -H "X-N8N-API-KEY: $N8N_KEY" -H "Content-Type: application/json"
```

---

### Phase 7: End-to-End Test

#### 7a. Fire test webhook

```bash
curl -s -X POST "{{n8n_host}}/webhook/{{webhook_path}}" \
  -H "Content-Type: application/json" \
  -d '{"project_slug": "{{default_slug}}", "prompt": "What is the current git branch? Reply with just the branch name.", "action_type": "followup_research"}'
```

Expected response: `{"message":"Workflow was started"}` (because `onReceived` mode)

#### 7b. Wait and check execution

```bash
sleep 30
N8N_KEY=$(cat ~/.claude/settings.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mcpServers']['{{n8n_mcp_server}}']['env']['N8N_API_KEY'])")

curl -s "{{n8n_host}}/api/v1/executions?workflowId={{workflow_id}}&limit=1&includeData=true" \
  -H "X-N8N-API-KEY: $N8N_KEY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
e = d['data'][0]
print(f'Status: {e[\"status\"]}')
run = e.get('data', e).get('resultData', {}).get('runData', {})
ssh = run.get('Execute via SSH', [])
if ssh:
    j = ssh[0].get('data', {}).get('main', [[]])[0][0].get('json', {})
    print(f'Exit code: {j.get(\"code\")}')
    print(f'Output: {j.get(\"stdout\",\"\")[:200]}')
parse = run.get('Parse Results', [])
if parse:
    j = parse[0].get('data', {}).get('main', [[]])[0][0].get('json', {})
    print(f'Success: {j.get(\"result_success\")}')
    print(f'Summary: {j.get(\"result_summary\",\"\")[:200]}')
"
```

**Success criteria**:
- Execution status: `success`
- SSH exit code: `0`
- Parse Results success: `True`

#### 7c. Verify launchd persistence

```bash
# Kill the autossh process — launchd should restart it
pgrep -f "autossh.*{{tunnel_port}}" | head -1 | xargs kill
sleep 5
pgrep -f "autossh.*{{tunnel_port}}" && echo "PERSISTENCE_OK" || echo "PERSISTENCE_FAILED"
```

---

## Troubleshooting

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| SSH credential test: ECONNREFUSED | Tunnel not running or wrong port | Check `ss -tlnp` on VPS for tunnel port |
| SSH credential test: timeout | UFW blocking Docker→host traffic | Add `ufw allow from {{docker_subnet}} to any port {{tunnel_port}}` |
| SSH exit code 0 but Parse Results shows -1 | n8n SSH node returns `code` not `exitCode` | Use `$json.code` in Parse Results node |
| SSH command runs but `cd` fails silently | Wrong REPO_MAP paths for this Mac | Check paths with `ls` on Mac, update path resolution node |
| `authentication: "privateKey"` with password credential | SSH node auth param mismatch | Change to `"authentication": "password"` in SSH node |
| Tunnel binds to 127.0.0.1 only | Missing `0.0.0.0:` prefix in -R flag | Use `-R 0.0.0.0:{{port}}:localhost:22` |
| Tunnel works from VPS host but not from Docker | Docker→host blocked by UFW default deny | Allow Docker subnet in UFW |
| autossh dies and doesn't restart | launchd not loaded or AUTOSSH_GATETIME not set | Check `launchctl list | grep {{org_slug}}` |
| Bot loop: SSH result triggers inbound | Inbound classifier missing bot guard patterns | Add SSH message patterns to classifier node |

### Debug Commands

```bash
# Check tunnel status (from Mac)
pgrep -f "autossh" && echo "autossh running" || echo "autossh NOT running"
launchctl list | grep {{org_slug}}

# Check tunnel on VPS
ssh {{vps_user}}@{{vps_ip}} "ss -tlnp | grep {{tunnel_port}}"

# Test SSH from Docker perspective (on VPS)
ssh {{vps_user}}@{{vps_ip}} "ssh -p {{tunnel_port}} -o ConnectTimeout=5 {{username}}@{{docker_gateway}} 'echo OK'" 2>&1

# Check n8n Docker network
ssh {{vps_user}}@{{vps_ip}} "docker network inspect n8n_default | grep -A5 Gateway"

# Check launchd logs
cat /tmp/ssh-tunnel.log
cat /tmp/ssh-tunnel.err
```

---

## Anti-Patterns

| # | Wrong | Why | Right |
|---|-------|-----|-------|
| 1 | SSH credential host = `localhost` | Inside Docker, localhost = container | Use `{{docker_gateway}}` (e.g., `172.18.0.1`) |
| 2 | Tunnel binds to `127.0.0.1` | Docker can't reach 127.0.0.1 on host | Bind to `0.0.0.0` with UFW protection |
| 3 | `$json.exitCode` in Parse Results | n8n SSH node uses `code` field | Use `$json.code` |
| 4 | `authentication: "privateKey"` with password | Silent auth failure → exit -1 | Match auth param to credential type |
| 5 | Hardcoded repo paths | Paths differ per Mac | Machine-specific REPO_MAP in workflow |
| 6 | No UFW rules on tunnel port | Exposes Mac SSH to entire internet | Block eth0, allow only Docker subnet |
| 7 | Manual autossh (no launchd) | Dies on reboot or disconnect | Use launchd with KeepAlive + RunAtLoad |
| 8 | Missing `AUTOSSH_GATETIME=0` | autossh exits if first attempt fails | Set env var in launchd plist |
| 9 | No bot guard in inbound classifier | SSH results trigger bot loop | Add SSH message patterns to classifier node |
| 10 | `responseMode: "responseNode"` on webhook | Holds connection during Claude execution (minutes) | Use `"onReceived"` — fire and forget |

---

## Post-Setup Checklist

```
[ ] Remote Login enabled on Mac
[ ] autossh installed
[ ] SSH key authorized on VPS
[ ] GatewayPorts clientspecified on VPS
[ ] UFW rules added (deny public, allow Docker)
[ ] Reverse tunnel running (launchd)
[ ] n8n SSH credential created and tested (green checkmark)
[ ] SSH execution workflow REPO_MAP updated for this Mac
[ ] SSH execution workflow credential reference updated
[ ] Webhook test returns successful execution
[ ] Tunnel survives kill (launchd restart)
[ ] Inbound classifier has bot guard patterns for SSH messages
```

---

*ssh-claude-setup v1.0 — Created: 2026-03-09*
