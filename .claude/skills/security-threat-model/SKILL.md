---
name: security-threat-model
description: |
  System-level threat modeling — trust boundaries, attacker capabilities, assets, abuse paths.
  Different activity from code review: operates at system abstraction, includes human-in-the-loop.
  This is a companion to master-security-review (which reviews code); use both for full coverage.
  For code-level security review, use master-security-review instead.
version: 1.1
source: openai/skills (enhanced for the project)
classification: capability-uplift
triggers:
  - "threat model"
  - "map trust boundaries"
  - "attacker capabilities"
  - "system-level security"
do-not-trigger:
  - "security review" (code) → use master-security-review
  - "scan Claude config" → use security-scan-agentshield
---

# Threat Model Source Code Repo

> System-level threat modeling — a different *activity* from code review.
> `master-security-review` reviews code for vulnerabilities. This skill maps trust boundaries, attacker capabilities, and abuse paths at the architecture level.
> For comprehensive security: run this for system-level analysis, then master-security-review for code-level scanning.

Deliver actionable AppSec-grade threat model specific to the repository.

## Workflow
1. **Scope**: Identify components, data stores, external integrations
2. **Boundaries**: Map trust boundaries with protocol, auth, encryption, validation
3. **Assets**: Credentials, PII, integrity-critical state, compute resources
4. **Attacker Capabilities**: Realistic capabilities based on exposure
5. **Threats**: Abuse paths (exfiltration, privilege escalation, integrity compromise, DoS)
6. **Prioritize**: Likelihood x impact with justifications
7. **Validate**: Ask user 1-3 targeted questions
8. **Mitigate**: Tie to concrete locations and control types
9. **Quality Check**: All entrypoints covered, boundaries represented

## Risk Prioritization
- **High**: Pre-auth RCE, auth bypass, cross-tenant access, key theft, sandbox escape
- **Medium**: Targeted DoS, partial data exposure, rate-limit bypass, log poisoning
- **Low**: Low-sensitivity info leaks, noisy DoS with easy mitigation

## Output
Write to `<repo-name>-threat-model.md`
