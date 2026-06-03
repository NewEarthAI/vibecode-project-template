---
name: master-security-review
description: |
  Confidence-calibrated security review for the project stack (Supabase, n8n, Next.js, Edge Functions).
  Three modes: secure-by-default (while coding), passive detection (background), full audit (on request).
  Only reports HIGH confidence findings with confirmed attacker-controlled input.
  For system-level threat modeling, also invoke security-threat-model.
  For Better Auth library hardening, see better-auth-security.
  For AI agent config security, see security-scan-agentshield.
version: 1.0
classification: capability-uplift
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
triggers:
  - "security review"
  - "security audit"
  - "check for vulnerabilities"
  - "is this secure?"
do-not-trigger:
  - "threat model" → use security-threat-model
  - "Better Auth config" → use better-auth-security
  - "scan Claude Code config" → use security-scan-agentshield
  - "code review" → use master-code-reviewer
---

# Master Security Reviewer

> Confidence-calibrated, stack-aware security review. Research before reporting.
> Synthesized from: security-review-sentry (A-), security-best-practices-openai, vibe-security, security-review-affaan, security-reviewer-jeffallan, security-review-antigravity, mapbox-token-security.

---

## Core Philosophy

```
RESEARCH before REPORTING.
Only flag findings where attacker-controlled input is CONFIRMED.
LOW-confidence findings are SUPPRESSED, not shown.
```

---

## Companion Skills — Invoke When Conditions Met

Before generating output, evaluate these conditions:

- **System-level threat analysis needed** → invoke `security-threat-model` for trust boundary mapping, attacker capability enumeration, abuse path analysis
- **Better Auth library detected in project** → invoke `better-auth-security` for library-specific rate limits, session config, CSRF, OAuth token encryption
- **Auditing Claude Code configuration files** → invoke `security-scan-agentshield` for CLAUDE.md prompt injection, settings.json permissions, MCP supply chain, hook injection
- **Code quality issues alongside security** → invoke `master-code-reviewer` for full review with scoring and LLM smell detection

These are NOT mutually exclusive — invoke all that match.

---

## Operating Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Mode 1: Secure-by-Default** | While writing code | Proactively write secure patterns. No report — just secure code. |
| **Mode 2: Passive Detection** | While working on other tasks | Flag HIGH-confidence only. One-line warnings, no full report. |
| **Mode 3: Full Audit** | Explicit request (`/security-review`) | Complete 4-tier review with structured output. |

---

## Full Audit Process (Mode 3)

### Tier 1 — Automated Scanning

Run these checks first (always available, no external tools needed):

```bash
# Hardcoded secrets
grep -rn "sk_live\|sk_test\|AKIA\|-----BEGIN.*KEY" --include="*.ts" --include="*.js" --include="*.env*" .

# Exposed service role keys
grep -rn "service_role\|SUPABASE_SERVICE_ROLE" --include="*.ts" --include="*.tsx" --include="*.js" .

# Dangerous patterns
grep -rn "dangerouslySetInnerHTML\|eval(\|new Function(" --include="*.ts" --include="*.tsx" --include="*.js" .

# If available: gitleaks, npm audit, semgrep
gitleaks detect --source . --report-format json 2>/dev/null || true
npm audit --json 2>/dev/null || true
semgrep --config auto . --json 2>/dev/null || true
```

### Tier 2 — Pattern-Based Review

| Category | What to Search | Grep Pattern | Severity |
|----------|---------------|--------------|----------|
| SQL Injection | Raw SQL with interpolation | `\.raw\(`, `EXECUTE.*\|\|`, `\$\{.*\}.*query` | CRITICAL if user input |
| XSS | Unescaped output | `dangerouslySetInnerHTML`, `v-html`, `\|safe` | CRITICAL if user input |
| Auth Bypass | Missing auth checks | API routes without `getSession`, `auth()` | HIGH |
| SSRF | Unvalidated URLs in fetch | `fetch\(.*\$\{`, `axios\(.*\+` | HIGH if user-controlled |
| IDOR | Predictable resource access | `params.id` without ownership check | HIGH |
| Secrets Exposure | Env vars in client code | `NEXT_PUBLIC_.*SECRET`, `NEXT_PUBLIC_.*SERVICE_ROLE` | CRITICAL |
| RLS Bypass | Missing row-level security | Tables without RLS, `service_role` in client | CRITICAL |
| File Upload | Unrestricted upload | Missing size limit, extension-only validation | MEDIUM |
| CSRF | Missing token validation | State-changing GET requests | MEDIUM |

### Tier 3 — Data Flow Analysis

For each potential finding from Tier 2:

1. **Identify input source** (request param, form field, webhook body, URL param)
2. **Trace through every function** to the sink (SQL query, HTML render, redirect, file write)
3. **Check for sanitization/validation** at each step
4. **Only flag** if attacker-controlled input reaches sink without adequate sanitization
5. **Confidence**: HIGH only if full path confirmed. MEDIUM if sanitization exists but may be bypassable.

### Tier 4 — Architecture Review

| Trust Boundary | What to Verify |
|----------------|---------------|
| **Client → Supabase** | RLS on every table accessed by anon key. No service_role in client. |
| **Client → Next.js API** | Server Actions validate all inputs with Zod. No `"use server"` on raw input functions. |
| **n8n Webhook → Processing** | Webhook authentication (shared secret, HMAC). Input validation before DB writes. |
| **Edge Function → DB** | Service role key only in edge functions, never exposed. Input validation on all parameters. |
| **API Key Taxonomy** | Public tokens: client-safe, domain-restricted, minimal scopes. Secret tokens: server-only, never in `NEXT_PUBLIC_*`. |
| **WhatsApp → n8n** | Message content treated as untrusted. No command injection via messages. |

See [references/supabase-security.md](references/supabase-security.md) and [references/n8n-security.md](references/n8n-security.md) for stack-specific deep checks.

---

## Confidence Calibration

| Level | Criteria | Action |
|-------|----------|--------|
| **HIGH** | Attacker input confirmed to reach sink without sanitization. Full data flow traced. | **REPORT** — include file:line, data flow, fix code |
| **MEDIUM** | Suspicious pattern, sanitization may exist. Partial trace. | **REPORT with caveat** — "Verify that X is sanitized at Y" |
| **LOW** | Likely false positive (test file, server-controlled, framework-handled). | **SUPPRESS** — do not include in output |

### Do Not Flag

- Test files or test fixtures
- Server-controlled values (not user input)
- Framework auto-mitigated patterns (React default XSS escaping, ORM parameterization)
- Development-only settings (unless production audit mode specified)

---

## Output Format (Mode 3)

```markdown
## Security Review — [repo/path]

**Mode**: Full Audit
**Confidence threshold**: HIGH + MEDIUM
**Date**: YYYY-MM-DD

### CRITICAL (immediate fix required)

#### [VULN-001] [Category] — [file:line]
**Confidence**: HIGH
**Data flow**: [input source] → [function chain] → [dangerous sink]
**Impact**: [what an attacker can do]
**Fix**:
[exact fix code]

### HIGH (fix before merge)

### MEDIUM (fix soon)

### Architecture Notes
- [Trust boundary observations]
- [Missing security controls]

### Scan Summary
| Tier | Findings | HIGH | MEDIUM | Suppressed |
|------|----------|------|--------|------------|
| 1. Automated | X | Y | Z | W |
| 2. Pattern | ... | ... | ... | ... |
| 3. Data Flow | ... | ... | ... | ... |
| 4. Architecture | ... | ... | ... | ... |
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Pattern matching without data flow trace | False positives, alert fatigue | Tier 3: trace input to sink before reporting |
| Flagging React default XSS escaping | Framework handles it | Only flag `dangerouslySetInnerHTML` with user input |
| Reporting LOW confidence findings | Noise, wastes reviewer time | Suppress LOW, note MEDIUM with caveat |
| Skipping RLS check on Supabase tables | Most common real vulnerability | Tier 4: query pg_tables for rowsecurity |
| Sending client code to external scanners | Data leakage risk for agency | Use local grep patterns + free tools only |
| Using `service_role` key in frontend | Bypasses all RLS | Only in Edge Functions, never NEXT_PUBLIC_* |

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No code provided | Ask for file paths, PR URL, or git diff |
| External tools unavailable (gitleaks, semgrep) | Proceed with Tier 2-4 (grep-based), note reduced Tier 1 coverage |
| Companion skill unavailable | Proceed with master, note which specialist depth is missing |
| Zero findings after full audit | Explicitly state "No vulnerabilities found at HIGH/MEDIUM confidence" |
