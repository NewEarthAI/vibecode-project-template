# Security Categories — Review Taxonomy

> Reference for `newearth-security`. The category taxonomy a full audit (Mode 3) walks,
> the non-goals it explicitly does NOT chase, and the confidence schema every finding carries.
> **Source pattern**: `anthropics/claude-code-security-review` (ABSORB-PATTERN, 2026-05-22 council Amendment).

## Next Review

**2026-08-22** (90-day cadence per Amendment 16). At review: re-verify the category list against the
upstream `anthropics/claude-code-security-review` taxonomy and the current OWASP LLM Top 10 (see
`owasp-standards.md`). This is an industry-rule citation surface — primary-source check required per
`.claude/rules/research-before-threshold-lock.md`.

---

## The 10 review categories

Each finding maps to exactly one primary category. The category drives the grep patterns in the
conductor's Tier 2 table and the trust-boundary checks in Tier 4.

| # | Category | What it covers | Stack-specific hot spot |
|---|----------|----------------|-------------------------|
| 1 | **Injection** | SQL/NoSQL injection, command injection, template injection — any attacker string reaching an interpreter | Supabase raw SQL, n8n Code nodes, edge-function shell-outs |
| 2 | **Broken authentication** | Missing/weak session checks, JWT misvalidation, auth bypass on API routes | Next.js API routes missing `getSession`, edge functions trusting unauthenticated callers |
| 3 | **Sensitive data exposure** | Secrets in client code, PII in logs, over-broad API responses | `NEXT_PUBLIC_*` leaking secrets, service_role in frontend |
| 4 | **Broken access control / IDOR** | Predictable resource IDs without ownership checks, missing RLS | Supabase tables without row-level security, `params.id` lookups |
| 5 | **Cross-site scripting (XSS)** | Unescaped user output reaching the DOM | `dangerouslySetInnerHTML` on KI/user content, `v-html` |
| 6 | **SSRF** | Unvalidated URLs in server-side fetches | edge functions/n8n HTTP nodes fetching attacker-supplied URLs |
| 7 | **Insecure deserialisation / mass assignment** | Trusting structure of untrusted input wholesale | webhook bodies spread into DB writes without an allowlist |
| 8 | **Security misconfiguration** | Permissive CORS, debug endpoints, default creds, over-broad scopes | open n8n webhooks, broad Supabase grants, verbose error leakage |
| 9 | **Vulnerable dependencies** | Known-CVE packages, unmaintained transitive deps | see `dependency-health.md` |
| 10 | **Prompt injection / excessive agency** | LLM output treated as trusted, model given more authority than the task needs | see `prompt-injection-defence.md` — the agentic-stack category |

Categories 1-9 are the classic application-security set (maps to OWASP — see `owasp-standards.md`).
Category 10 is the agentic-AI addition that makes this taxonomy stack-appropriate for NewEarth's
n8n + edge-function + LLM pipelines.

---

## Non-goals (explicitly OUT of scope)

A confidence-calibrated reviewer earns trust by NOT chasing these. Surfacing them as findings is noise:

- **Stylistic / lint issues** — that's `newearthai-code-reviewer`, not this skill.
- **Defence-in-depth nice-to-haves with no confirmed attacker path** — "you could also add X" without a
  traced exploit is a MEDIUM at best, usually SUPPRESS.
- **Framework-mitigated patterns** — React's default XSS escaping, ORM parameterisation, Next.js CSRF on
  Server Actions. Flagging these is the classic false-positive that destroys signal.
- **Theoretical crypto critiques** — unless a concrete downgrade/break path is shown.
- **Compliance attestations** (SOC2/POPIA wording) — that is a documentation exercise, not a code finding.
- **Claude Code config security** (CLAUDE.md injection, settings.json permissions, MCP supply chain) —
  that is `security-scan-agentshield`'s jurisdiction.

When a reviewer is tempted by a non-goal, the correct action is to name the right tool and move on.

---

## Confidence schema (every finding carries one)

| Level | Definition | Action |
|-------|-----------|--------|
| **HIGH** | Attacker-controlled input is confirmed to reach a dangerous sink without adequate sanitisation. Full data flow traced (source → chain → sink). | **REPORT** — file:line, data flow, fix code. |
| **MEDIUM** | Suspicious pattern; sanitisation may exist but could be bypassable, OR the trace is partial. | **REPORT with caveat** — state exactly what must be verified. |
| **LOW** | Likely false positive (test fixture, server-controlled value, framework-handled). | **SUPPRESS** — never shown in output. |

The schema is asymmetric on purpose: a HIGH finding asserts a complete exploit path, so it must be
defensible to file:line. A MEDIUM finding hands the operator a specific verification task rather than a
vague worry. LOW is suppressed because alert fatigue is itself a security failure — it trains the
operator to ignore the channel.

**Tool-status interaction**: a clean scan with missing tools is NOT a HIGH-confidence "no findings".
The output header's tool-status block (Amendment 18) makes coverage gaps visible so "nothing found"
is never mistaken for "nothing there".

---

## How this composes

- The conductor `SKILL.md` Tier 2 table is the operational instantiation of categories 1-9.
- Category 10 routes to `prompt-injection-defence.md` for the agentic-specific depth.
- `owasp-standards.md` maps these categories onto the OWASP LLM Top 10 2025 numbering.
- `severity-modes.md` governs how many of these categories a given review mode actually walks.
