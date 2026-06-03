---
name: security-scan-agentshield
description: |
  Meta-security — audit Claude Code's own configuration for vulnerabilities. Prompt injection
  in CLAUDE.md, permissive settings.json, MCP supply chain risks, hook command injection.
  Completely orthogonal to newearth-security (which audits application code).
  For app code security, use newearth-security instead.
version: 1.1
source: affaan-m/everything-claude-code (enhanced for NewEarth AI)
classification: capability-uplift
triggers:
  - "scan Claude config"
  - "audit agent security"
  - "check MCP servers for risks"
  - "AgentShield"
do-not-trigger:
  - "security review" (application code) → use newearth-security
  - "threat model" → use security-threat-model
---

# Security Scan (AgentShield)

> Meta-security: audits the AI agent's own configuration — CLAUDE.md, settings.json, hooks, MCP servers.
> This is orthogonal to `newearth-security` (application code). Both can run on the same project.

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
# Guard 1 — npx absent (Amendment 8: `command -v` not `which`, for macOS portability).
# Graceful degradation: the tool isn't installable here; fall back to grep coverage.
command -v npx >/dev/null 2>&1 || {
  echo "agentshield scan SKIPPED — npx unavailable; Tier 1 grep in newearth-security covers agentic config"
  exit 0
}

# Guard 2 — npx present but ecc-agentshield errors (code-council 2026-05-22 item K).
# This is DISTINCT from npx-absent: a non-zero exit here means the package failed to
# fetch/run (network, registry, version) — a coverage GAP, not a clean skip. Surface it
# loudly so the operator knows agentic-config scanning did NOT happen.
#
# Capture rc on the SAME line as the command — NEVER inside `if ! cmd; then rc=$?`, because
# the `!` negation makes $? reflect the negation's result (always 0), masking the real exit.
# (shell-portability.md rule 1; this exact trap was caught by code-council 2026-05-22.)
npx ecc-agentshield scan "$@"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "agentshield scan ERRORED (exit $rc) — npx is present but ecc-agentshield failed to run." >&2
  echo "This is a COVERAGE GAP, not a clean result. Re-run, check network/registry, or pin a known-good version." >&2
  echo "Interim: Tier 1 grep in newearth-security partially covers agentic config, but the agentshield-specific checks (MCP supply chain, hook injection, settings permissions) did NOT run." >&2
  exit "$rc"
fi
```

**Other invocations** (each is an ALTERNATIVE to the primary scan above — run ONE, not in sequence after it):
```bash
npx ecc-agentshield scan --path /path/to/.claude   # scan a specific config dir
npx ecc-agentshield scan --min-severity medium      # raise the severity floor
```

**Why two guards**: "npx not installed" (Guard 1) is a legitimate environment where the tool can't run — degrade gracefully to grep. "npx installed but the package errored" (Guard 2) is a coverage gap masquerading as a skip — fail loud so a clean-looking run never hides that the agentic-config checks were absent. Mirrors the conductor's tool-status-block discipline (Amendment 18): a missing tool ≠ a clean scan.
