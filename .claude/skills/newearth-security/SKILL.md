---
name: newearth-security
description: |
  Confidence-calibrated security review for the NewEarth AI stack (Supabase, n8n, Next.js, Edge Functions).
  Three modes: secure-by-default (while coding), passive detection (background), full audit (on request).
  Only reports HIGH confidence findings with confirmed attacker-controlled input.
  For system-level threat modeling, also invoke security-threat-model.
  For AI agent config security, see security-scan-agentshield.
version: 1.1
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
  - "scan Claude Code config" → use security-scan-agentshield
  - "code review" → use newearthai-code-reviewer
---

# NewEarth Security Reviewer

> Confidence-calibrated, stack-aware security review. Research before reporting.
> Synthesized from: security-review-sentry (A-), security-best-practices-openai, vibe-security, security-review-affaan, security-reviewer-jeffallan, security-review-antigravity, mapbox-token-security.
> **Renamed 2026-05-22** from `newearthai-security-review` per council 2026-05-22 (`council/sessions/2026-05-22-newearth-security-skill-suite-extended-council.md`).

## Next-Audit

**2026-08-22** — re-run `/audit-artefact-grounding` on this skill + its reference library (90-day cadence, Amendment 17). The OWASP + dependency-health threshold surfaces also re-verify against primary sources on this date (Amendment 16 + `research-before-threshold-lock`).

---

## Toggle Check (MANDATORY first action)

Before doing anything else, check the toggle. Honour disabled state; halt on indeterminate.

```bash
bash .claude/skills/newearth-security/scripts/is-enabled.sh
case $? in
  0) ;;  # enabled — proceed
  1) echo "🔒 newearth-security disabled — re-enable via: unset NEWEARTH_SECURITY_ENABLED OR rm .claude/newearth-security.disabled OR edit settings.local.json"; exit 0 ;;
  2) echo "⚠️ toggle value unrecognised — HALTING for safety. Fix the NEWEARTH_SECURITY_ENABLED value or the settings.local.json key (expected 1/true/yes/on/enabled or 0/false/no/off/disabled)."; exit 2 ;;
  3) echo "⚠️ toggle installation broken — HALTING. jq missing, settings.local.json is invalid JSON, or repo root unresolvable. Investigate scripts/is-enabled.sh + your environment."; exit 3 ;;
esac
```

Toggle mechanism + sub-agent propagation: see [references/toggle.md](references/toggle.md).

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
- **Auditing Claude Code configuration files** → invoke `security-scan-agentshield` for CLAUDE.md prompt injection, settings.json permissions, MCP supply chain, hook injection
- **Code quality issues alongside security** → invoke `newearthai-code-reviewer` for full review with scoring and LLM smell detection

These are NOT mutually exclusive — invoke all that match.

> **Note**: `better-auth-security` was DEPRECATED 2026-05-22 (archived to `.claude/skills/_archived/better-auth-security/`). For Better Auth projects, use this skill's general patterns + the archived reference if needed.

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

Run these checks first (always available, no external tools needed). The `--exclude-dir=".claude"` is mandatory per Amendment 11 — skill bodies legitimately reference key patterns and would produce false positives.

```bash
# Hardcoded secrets
grep -rn "sk_live\|sk_test\|AKIA\|-----BEGIN.*KEY" --include="*.ts" --include="*.js" --include="*.env*" --exclude-dir=".claude" --exclude-dir="node_modules" --exclude-dir=".git" .

# Exposed service role keys
grep -rn "service_role\|SUPABASE_SERVICE_ROLE" --include="*.ts" --include="*.tsx" --include="*.js" --exclude-dir=".claude" --exclude-dir="node_modules" --exclude-dir=".git" .

# Dangerous patterns
grep -rn "dangerouslySetInnerHTML\|eval(\|new Function(" --include="*.ts" --include="*.tsx" --include="*.js" --exclude-dir=".claude" --exclude-dir="node_modules" --exclude-dir=".git" .

# If available: gitleaks, npm audit, semgrep, CodeQL — capture availability for tool-status block
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
| Supply Chain (OWASP LLM03, 2025) | Vulnerable/unmaintained deps, unverified MCP servers | `npm audit`; new entries in `package.json`; unaudited `postinstall` | HIGH if unpatched CRITICAL/HIGH CVE — see [references/dependency-health.md](references/dependency-health.md) |
| Improper Output Handling (OWASP LLM05 "mishandling", 2025) | LLM output reaching a sink unvalidated | `$json.<field>` from a model node interpolated into a query, URL, or DOM | CRITICAL if model output reaches sink — see [references/prompt-injection-defence.md](references/prompt-injection-defence.md) |

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

**Per Amendment 18 — tool-status block is REQUIRED in the output header. Missing tool ≠ clean scan.**

```markdown
═══ TOOLS THAT RAN ═══
semgrep: [✓ ran | ✗ not available]
CodeQL: [✓ ran | ✗ not available]
npm audit: [✓ ran | ✗ not available]
gitleaks: [✓ ran | ✗ not available]
═══════════════════════

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

Populate the tool-status block from Tier 1's `command -v` checks. Mark each tool ✓ only if it ran cleanly; ✗ if absent or errored.

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
| Reporting clean scan when tools missing | Hides coverage gap | Tool-status block at top — operator sees what DIDN'T run |

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No code provided | Ask for file paths, PR URL, or git diff |
| External tools unavailable (gitleaks, semgrep) | Proceed with Tier 2-4 (grep-based), note in tool-status block |
| Companion skill unavailable | Proceed with master, note which specialist depth is missing |
| Zero findings after full audit | Explicitly state "No vulnerabilities found at HIGH/MEDIUM confidence" — and surface tool-status block so operator sees the coverage |
| Toggle indeterminate (`is-enabled.sh` exit 2) | HALT with banner. A toggle value is set but unrecognised (operator typo). Do NOT silently bypass — a security skill that doesn't know its own state is more dangerous than one that's off. |
| Toggle installation broken (`is-enabled.sh` exit 3) | HALT with banner. Environment problem — jq missing, `settings.local.json` is invalid JSON, or repo root unresolvable. Distinct from exit 2: fix the environment, not the toggle value. See [references/toggle.md](references/toggle.md). |

---

## Reference Library (V1.1 — shipped 2026-05-22)

The depth behind each tier lives in `references/`. Read the relevant file when a review needs more than
the conductor's surface checks:

| Reference | Covers | When to read |
|-----------|--------|--------------|
| [references/security-categories.md](references/security-categories.md) | 10-category taxonomy, non-goals, confidence schema | calibrating what to report vs suppress |
| [references/prompt-injection-defence.md](references/prompt-injection-defence.md) | LLM-output-untrusted foundation, n8n-vs-edge-fn distinction | any LLM call site (category 10 / LLM01 / LLM05 / LLM06) |
| [references/owasp-standards.md](references/owasp-standards.md) | OWASP LLM Top 10 2025 + agentic deltas | mapping findings onto a recognised standard |
| [references/stride-dread.md](references/stride-dread.md) | STRIDE enumeration + DREAD scoring method | system-level threat modelling (also `security-threat-model`) |
| [references/severity-modes.md](references/severity-modes.md) | 4-mode review depth + severity floors | deciding how deep to scan + what floor to report |
| [references/dependency-health.md](references/dependency-health.md) | supply-chain health signals + triage thresholds | category 9 / OWASP LLM03 dependency findings |
| [references/supabase-security.md](references/supabase-security.md) | Supabase RLS/edge-fn deep checks | Supabase-touching code |
| [references/n8n-security.md](references/n8n-security.md) | n8n workflow security deep checks | n8n workflow code |
| [references/toggle.md](references/toggle.md) | toggle mechanism, trust model, sub-agent propagation | configuring enable/disable |

Each enrichment reference carries a `## Next Review` 2026-08-22 header (Amendment 16). The OWASP +
dependency-health files carry the `research-before-threshold-lock` re-verify caveat.

> **SessionStart banner format**: V1.0 ships the disabled-state banner as an H3 (`### 🔒`) for visibility.
> Reconciled with plan v2 §5 Step 13 (single-line implied) → **KEEP H3** (council 2026-05-22 §3.6 recommendation:
> visibility over terseness for a security-state signal).
