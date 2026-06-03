# Dependency Health — Supply-Chain Review Thresholds

> Reference for `newearth-security` category 9 (vulnerable dependencies) + OWASP LLM03 (Supply Chain).
> Package-health signals a reviewer checks before a dependency is trusted, and the threshold defaults
> NewEarth uses for triage.
> **Source pattern**: `snyk/studio-recipes` package-health thresholds (ABSORB-PATTERN, 2026-05-22 council).

## Next Review

**2026-08-22** (90-day cadence per Amendment 16).

> **Threshold caveat** (`.claude/rules/research-before-threshold-lock.md`): the numeric thresholds below
> are NewEarth-chosen triage defaults informed by Snyk's package-health guidance — they are NOT a
> regulated standard and carry no industry-codified authority. At every review, re-verify against the
> current Snyk guidance and adjust if the ecosystem norms have shifted. Frame any citation of these
> numbers as "NewEarth triage default", not "industry standard".

---

## Why dependency health is a security category, not just hygiene

A dependency you cannot vouch for is an attacker's foothold. The 2025 OWASP LLM Top 10 elevated Supply
Chain (LLM03) precisely because the agentic stack pulls in: npm packages inside n8n/edge functions,
third-party model providers, and an expanding MCP server fleet. Each is code (or a service) running with
your trust. Supply-chain compromise is a documented, recurring attack class — not a theoretical worry.

---

## Health signals (check before trusting a new dependency)

| Signal | Healthy | Flag |
|--------|---------|------|
| **Known CVEs** | none open, or all patched in the pinned version | any unpatched CRITICAL/HIGH CVE |
| **Maintenance** | commit/release within ~12 months | no release in >24 months (abandonment risk) |
| **Maintainer count** | ≥2 active maintainers | single maintainer + high download count (bus-factor + takeover target) |
| **Transitive depth** | shallow, well-known deps | deep tree pulling obscure transitives |
| **Install scripts** | none, or audited | unexplained `postinstall` / `preinstall` scripts |
| **Popularity vs age** | proportionate | brand-new package with sudden high downloads (typosquat / hype-jack signal) |
| **License** | permissive, compatible | missing, GPL-incompatible, or changed recently |

These are the same axes Snyk's package-health score weighs; NewEarth uses them as a checklist rather than
a single numeric score, because the *reason* a package is risky matters for the fix.

---

## Triage thresholds (NewEarth defaults — re-verify per caveat above)

| Finding | Default action |
|---------|----------------|
| Unpatched CRITICAL/HIGH CVE in a runtime dependency | **BLOCK** — do not ship until patched, replaced, or risk explicitly accepted in writing |
| Unpatched MEDIUM CVE | report; fix in the same sprint if a patched version exists |
| Abandoned (>24mo no release) on a runtime-critical path | report; plan a replacement |
| Single-maintainer high-value dependency | note as a supply-chain risk; pin the exact version + checksum |
| Unexplained install script | **BLOCK** pending audit of what the script does |
| Typosquat signal (name close to a popular package, recent, sudden downloads) | **BLOCK** + verify you pulled the intended package |

> The "no release in >24 months" and ">=2 maintainers" cutoffs are conventional ecosystem heuristics, not
> hard rules. A mature, complete, rarely-changing library can be healthy with no recent release — judgement
> applies. Use the threshold to *surface* the dependency for a human look, not to auto-reject it.

---

## How a reviewer runs the check

1. **Tier 1 automated** (conductor): `npm audit --json` if available — capture in the tool-status block.
   Absence of the tool is NOT a clean result.
2. **For any flagged package**: walk the health signals table; classify the *reason* (CVE / abandonment /
   takeover-target / typosquat).
3. **Apply the triage thresholds** → BLOCK / report / note.
4. **MCP + model-provider supply chain**: not visible to `npm audit`. Manually check that new MCP servers
   come from a trusted source and that model-provider credentials are scoped minimally
   (cross-reference `prompt-injection-defence.md` least-privilege).

---

## How this composes

- This is the depth behind category 9 in `security-categories.md`.
- Maps to OWASP LLM03 (Supply Chain) in `owasp-standards.md`.
- The conductor `SKILL.md` Tier 1 `npm audit` line feeds this file's triage.
- MCP/model-provider supply chain overlaps `security-scan-agentshield` (Claude Code config + MCP supply
  chain) — invoke that skill for the config-file side.
