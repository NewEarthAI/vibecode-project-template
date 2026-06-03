---
name: security-scan-agentshield
description: |
  Meta-security — audit Claude Code's own configuration for vulnerabilities. Prompt injection
  in CLAUDE.md, permissive settings.json, MCP supply chain risks, hook command injection.
  Completely orthogonal to master-security-review (which audits application code).
  For app code security, use master-security-review instead.
version: 1.1
source: affaan-m/everything-claude-code (enhanced for the project)
classification: capability-uplift
triggers:
  - "scan Claude config"
  - "audit agent security"
  - "check MCP servers for risks"
  - "AgentShield"
do-not-trigger:
  - "security review" (application code) → use master-security-review
  - "threat model" → use security-threat-model
---

# Security Scan (AgentShield)

> Meta-security: audits the AI agent's own configuration — CLAUDE.md, settings.json, hooks, MCP servers.
> This is orthogonal to `master-security-review` (application code). Both can run on the same project.

Audit Claude Code configuration for security issues.

## What It Scans
| File | Checks |
|------|--------|
| CLAUDE.md | Hardcoded secrets, auto-run instructions, prompt injection |
| settings.json | Overly permissive allow lists, dangerous bypass flags |
| mcp.json | Risky MCP servers, hardcoded env secrets, npx supply chain |
| hooks/ | Command injection via interpolation, data exfiltration |
| agents/*.md | Unrestricted tool access, prompt injection surface |

## Usage
```bash
npx ecc-agentshield scan
npx ecc-agentshield scan --path /path/to/.claude
npx ecc-agentshield scan --min-severity medium
```
