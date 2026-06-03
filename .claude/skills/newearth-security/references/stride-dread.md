# STRIDE + DREAD — Threat-Modelling Method

> Reference for `newearth-security` and `security-threat-model`. STRIDE is the threat-enumeration
> framework; DREAD is the severity-scoring framework. Together they turn "is this secure?" into a
> structured, repeatable pass.
> **Source pattern**: `dralgorhythm/claude-agentic-framework` (ABSORB-PATTERN, 2026-05-22 council).

## Next Review

**2026-08-22** (90-day cadence per Amendment 16). STRIDE/DREAD are stable Microsoft-origin methods;
re-verify only that the agentic-stack mapping examples still match the current NewEarth architecture.

---

## STRIDE — threat enumeration

For each trust boundary (see the conductor's Tier 4 table), walk the six STRIDE categories and ask
"can an attacker do *this* across *this* boundary?"

| Letter | Threat | Violates | NewEarth-stack example |
|--------|--------|----------|------------------------|
| **S** | **Spoofing** | Authentication | Forged JWT to a Next.js API route; unauthenticated caller hitting an edge function |
| **T** | **Tampering** | Integrity | Modifying a webhook body in transit; altering a `knowledge_items` row that drives a decision |
| **R** | **Repudiation** | Non-repudiation | An action with no audit trail — can't prove who triggered a dispatch (cf. the toggle audit log) |
| **I** | **Information disclosure** | Confidentiality | service_role key in client bundle; PII in model logs; system-prompt leakage |
| **D** | **Denial of service** | Availability | Unbounded model consumption; an open n8n webhook hammered into quota exhaustion |
| **E** | **Elevation of privilege** | Authorisation | Prompt-injection driving an edge function to act with service_role; IDOR reaching another tenant's rows |

**Method**: list the trust boundaries → for each boundary, for each STRIDE letter, name the concrete
threat or write "n/a — mitigated by X". The n/a-with-reason entries are as valuable as the threats; they
record *why* a boundary is safe, so a future reviewer doesn't re-derive it.

---

## DREAD — severity scoring

Once a threat is enumerated, score it 1-3 on five axes. Sum gives a 5-15 band that drives priority.

| Letter | Axis | 1 (low) | 3 (high) |
|--------|------|---------|----------|
| **D** | **Damage** | cosmetic / low-value data | full data loss, fund movement, tenant breach |
| **R** | **Reproducibility** | hard, timing-dependent | trivially repeatable every time |
| **E** | **Exploitability** | needs deep skill + access | scriptable by a novice |
| **A** | **Affected users** | one edge-case account | all users / all tenants |
| **D** | **Discoverability** | requires source access | visible from outside, well-known pattern |

**Score → band**:

| Sum | Band | Action |
|-----|------|--------|
| 12-15 | **CRITICAL** | fix before merge / immediate hotfix |
| 9-11 | **HIGH** | fix before the feature ships |
| 6-8 | **MEDIUM** | scheduled fix, document the interim risk |
| 5 | **LOW** | note; usually accept |

> **Caveat** (`.claude/rules/research-before-threshold-lock.md`): the band cutoffs above are a
> conventional DREAD mapping, not a regulated standard. They are NewEarth-chosen for triage consistency.
> DREAD is known to be subjective (the same threat scores differently across reviewers) — use the band as
> a *sorting aid*, never as the sole gate. A HIGH-confidence exploit (per `security-categories.md`
> confidence schema) overrides a low DREAD sum.

---

## STRIDE + DREAD together — the pass

1. **Map trust boundaries** (conductor Tier 4 table is the starting set).
2. **Enumerate** per boundary with STRIDE → a list of concrete threats + reasoned n/a entries.
3. **Score** each enumerated threat with DREAD → a band.
4. **Confidence-gate**: only threats with a confirmed attacker path (HIGH/MEDIUM per the confidence
   schema) become reported findings. A high DREAD sum on an unconfirmed path is a research task, not a
   finding.
5. **Record** the full table (including n/a-with-reason) in the threat-model output so the next pass
   inherits the reasoning.

---

## When to use which

- **Quick code review** → skip formal STRIDE/DREAD; use the conductor's Tier 2 grep + Tier 3 data-flow.
- **System / architecture review** (`security-threat-model`) → run the full STRIDE enumeration per
  boundary + DREAD scoring. This is the method that file operationalises.
- **Single suspicious finding** → confidence schema alone; STRIDE/DREAD is overkill for one line.

---

## How this composes

- `security-threat-model` SKILL.md is the operational home of this method.
- `owasp-standards.md` is the complementary *taxonomy* (what categories of threat exist); this file is
  the *method* (how to enumerate + score them).
- `severity-modes.md` decides how deep a given review mode goes — a full STRIDE/DREAD pass is a Mode-3 /
  threat-model activity, not a per-edit check.
