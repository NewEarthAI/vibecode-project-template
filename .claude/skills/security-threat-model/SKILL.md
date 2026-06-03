---
name: security-threat-model
description: |
  System-level threat modeling — trust boundaries, attacker capabilities, assets, abuse paths.
  Different activity from code review: operates at system abstraction, includes human-in-the-loop.
  Companion to newearth-security (which reviews code); use both for full coverage.
  Method = STRIDE enumeration + DREAD scoring; taxonomy = OWASP LLM Top 10 2025.
  For code-level security review, use newearth-security instead.
version: 1.2
source: openai/skills (enhanced for NewEarth AI — V1.1 enrichment 2026-05-22)
classification: capability-uplift
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
triggers:
  - "threat model"
  - "map trust boundaries"
  - "attacker capabilities"
  - "system-level security"
do-not-trigger:
  - "security review" (code) → use newearth-security
  - "scan Claude config" → use security-scan-agentshield
---

# Security Threat Model

> System-level threat modeling — a different *activity* from code review.
> `newearth-security` reviews code for vulnerabilities. This skill maps trust boundaries, attacker
> capabilities, and abuse paths at the architecture level, including the human-in-the-loop.
> For comprehensive coverage: run this for the system view, then `newearth-security` for the code view.

> **V1.1 enrichment (2026-05-22)**: this skill now references the shared V1.1 reference library in
> `newearth-security/references/` rather than inlining method + taxonomy. Single source of truth; both
> skills cite the same docs. See council session
> `council/sessions/2026-05-22-newearth-security-skill-suite-extended-council.md`.

## Next-Audit

**2026-08-22** — re-run `/audit-artefact-grounding` on this skill (90-day cadence, Amendment 17).

---

## What this skill is (and is NOT)

| This skill | NOT this skill |
|------------|----------------|
| System-level: trust boundaries, assets, attacker capabilities, abuse paths | Line-level code vulnerabilities → `newearth-security` |
| Includes the human-in-the-loop and process controls | Claude Code config / MCP supply chain → `security-scan-agentshield` |
| Method: STRIDE + DREAD (a structured enumeration + scoring pass) | Code quality / lint → `newearthai-code-reviewer` |
| Output: a repo-specific threat-model document | A pass/fail gate — this informs, it does not block |

These compose. A thorough security posture runs this skill for the architecture view AND
`newearth-security` for the code view AND `security-scan-agentshield` for the agent-config view.

---

## Method — STRIDE + DREAD

The enumeration framework (STRIDE) and the scoring framework (DREAD) are documented once, in the shared
reference. Do NOT re-derive them here — read:

→ **[../newearth-security/references/stride-dread.md](../newearth-security/references/stride-dread.md)**

In short: for each trust boundary, walk the six STRIDE categories (Spoofing, Tampering, Repudiation,
Information disclosure, Denial of service, Elevation of privilege); for each enumerated threat, score
DREAD (Damage, Reproducibility, Exploitability, Affected users, Discoverability) → a CRITICAL/HIGH/MEDIUM/LOW
band. The reasoned `n/a — mitigated by X` entries are as valuable as the threats; they record why a
boundary is safe.

---

## Taxonomy — OWASP LLM Top 10 (2025)

For the agentic NewEarth stack, the relevant standard is the OWASP Top 10 for LLM Applications, not the
classic web Top 10. Read:

→ **[../newearth-security/references/owasp-standards.md](../newearth-security/references/owasp-standards.md)**

Threats enumerated via STRIDE should be tagged with their OWASP LLM ID (LLM01-LLM10) so the threat model
maps onto a recognised standard. The 2025-elevated items most relevant to NewEarth: LLM01 Prompt
Injection, LLM03 Supply Chain, LLM05 Improper Output Handling, LLM06 Excessive Agency, LLM08 Vector &
Embedding Weaknesses.

---

## Foundation — LLM output is untrusted input

The single most important architectural fact for NewEarth's pipelines:

> An LLM that has read attacker-controlled content can emit attacker-chosen content. Any downstream stage
> that *acts* on model output is a sink.

This governs every trust boundary where a model sits between untrusted input and a consequential action.
Read the depth + the n8n-vs-edge-function distinction:

→ **[../newearth-security/references/prompt-injection-defence.md](../newearth-security/references/prompt-injection-defence.md)**

---

## Workflow

1. **Scope** — enumerate components, data stores, external integrations, and the LLM call sites.
2. **Boundaries** — map every trust boundary with its protocol, auth mechanism, encryption, and input
   validation. Start from the NewEarth trust-boundary set below.
3. **Assets** — credentials (service_role, API keys, OAuth tokens), PII, integrity-critical state
   (`knowledge_items`, financial records), compute/quota resources.
4. **Attacker capabilities** — realistic capabilities given the actual exposure (anonymous internet,
   authenticated tenant, inbound-comms sender, compromised dependency, malicious ingested document).
5. **Threats** — run STRIDE per boundary → abuse paths (exfiltration, privilege escalation, integrity
   compromise, DoS, prompt-injection-driven action). Tag each with its OWASP LLM ID.
6. **Prioritise** — score DREAD per threat → band. Confidence-gate per
   `../newearth-security/references/security-categories.md`: only confirmed-path threats become findings.
7. **Validate** — ask the operator 1-3 targeted questions where the architecture is ambiguous (auth
   model, tenant isolation, which credentials reach which surface).
8. **Mitigate** — tie each prioritised threat to a concrete location and a control type (architectural
   constraint, validation, least-privilege, monitoring).
9. **Quality check** — every entrypoint covered, every boundary represented (including n/a-with-reason),
   every CRITICAL/HIGH threat has a named mitigation.

---

## NewEarth-stack trust boundaries (starting set)

These are the recurring boundaries across the NewEarth stack. Begin every threat model from this set,
then add repo-specific ones.

| Trust boundary | Attacker position | Primary STRIDE concerns | Key checks |
|----------------|-------------------|-------------------------|------------|
| **Internet → Next.js API / Server Action** | anonymous or authenticated user | Spoofing, Elevation | session check on every route; Zod validation on all inputs; no `"use server"` on raw-input functions |
| **Client → Supabase (anon key)** | any visitor with the anon key | Info disclosure, Elevation (IDOR) | RLS on every table reached by anon; no service_role in client; ownership checks on `params.id` |
| **Inbound comms (WhatsApp / email) → n8n** | anyone who can message the channel | Tampering, Elevation (prompt injection) | message content is untrusted; webhook auth (shared secret/HMAC); see prompt-injection-defence |
| **n8n model node → HTTP Request node** | author of any ingested content (indirect injection) | Elevation (SSRF), Info disclosure | model output never builds a request URL/target; HTTP node is a data sink (replaces `$json`) |
| **Edge function → Supabase (service_role)** | whoever can invoke the function | Elevation, Info disclosure | service_role only in edge fn, never exposed; parameterised RPCs; model output never picks the SQL/row |
| **KI ingestion → knowledge_items / RAG** | author of scraped/ingested external content | Tampering (LLM04 poisoning), Elevation (LLM01) | treat every ingested doc as hostile; validate model output against schema before it drives action |
| **Dependency / MCP supply chain** | a compromised or typosquatted package/server | Tampering, Elevation | see ../newearth-security/references/dependency-health.md; minimal-scope model-provider creds |
| **Operator → toggle / config** | the operator themselves (repudiation) | Repudiation | toggle disable is audit-logged (`security-toggle-audit.log`); config changes traceable |

For each, walk STRIDE, tag OWASP LLM IDs, score DREAD.

---

## Risk prioritisation (DREAD bands)

| Band | Examples |
|------|----------|
| **CRITICAL (DREAD 12-15)** | pre-auth RCE, auth bypass, cross-tenant access, service_role/key theft, sandbox escape, prompt-injection driving a service_role action |
| **HIGH (9-11)** | IDOR reaching another tenant's rows, SSRF from model-built URLs, secret in client bundle |
| **MEDIUM (6-8)** | targeted DoS, partial data exposure, rate-limit bypass, log poisoning |
| **LOW (5)** | low-sensitivity info leak, noisy DoS with trivial mitigation |

Band cutoffs are NewEarth triage defaults (not a regulated standard) — see the caveat in stride-dread.md.
A confirmed HIGH-confidence exploit overrides a low DREAD sum.

---

## Output

Write the threat model to `<repo-name>-threat-model.md` with these sections:

```markdown
# Threat Model — <repo/system>

**Date**: YYYY-MM-DD
**Scope**: <components, data stores, integrations, LLM call sites>
**Method**: STRIDE enumeration + DREAD scoring (see newearth-security/references/stride-dread.md)

## Assets
| Asset | Sensitivity | Where it lives |

## Trust boundaries
| Boundary | Protocol | Auth | Validation | STRIDE concerns | OWASP LLM ID |

## Threats (prioritised)
### CRITICAL
#### [T-001] <STRIDE category> across <boundary> — <OWASP LLM ID>
**DREAD**: D_/R_/E_/A_/D_ = sum (band)
**Abuse path**: <attacker position → step → consequence>
**Mitigation**: <concrete location + control type>

### HIGH / MEDIUM / LOW

## Boundaries verified safe (n/a with reason)
| Boundary | STRIDE letter | Why n/a |

## Open questions for operator
1. ...
```

---

## Anti-patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Inlining STRIDE/DREAD/OWASP definitions here | drifts from the shared reference; two sources of truth | reference the V1.1 docs in `newearth-security/references/` |
| Threat-modelling code line-by-line | that's `newearth-security`, different activity | stay at system abstraction; hand line-level to the code reviewer |
| Skipping n/a-with-reason entries | the next pass re-derives why a boundary is safe | record reasoned n/a — it's institutional memory |
| Treating a high DREAD sum as a confirmed finding | DREAD scores unconfirmed paths too | confidence-gate: only confirmed attacker paths become findings |
| Forgetting the prompt-injection boundary on LLM call sites | the agentic-stack blind spot | every model→action path gets the LLM01/LLM06 treatment |

---

## How this composes

- **Method + taxonomy + foundation**: the three reference files in `newearth-security/references/`
  (stride-dread, owasp-standards, prompt-injection-defence). This skill orchestrates them at the system level.
- **Code-level companion**: `newearth-security` — run after this for the line-level view.
- **Agent-config companion**: `security-scan-agentshield` — run for CLAUDE.md / settings.json / MCP supply chain.
- **Periodic grounding audit**: `/audit-artefact-grounding` on the Next-Audit date above.
