# SWOT Roll-up — {{Market / Category}}

> Generated {{YYYY-MM-DD}}. Rolling up {{count}} profiles at `schema_version: {{N}}`.
> Gates: ≥3 profiles required. All profiles must share `schema_version` — mixed versions refuse roll-up.

---

## Methodology

This roll-up aggregates signals across the catalog. Every cell cites specific profiles. No unsourced claims.

- **Strengths** — Our strengths that exploit documented competitor weaknesses. Each strength cites the competitor weakness(es) it exploits.
- **Weaknesses** — Our gaps vs. documented competitor strengths. Each weakness cites the competitor strength(s) we lack.
- **Opportunities** — Market gaps nobody fills. Each opportunity requires ≥2 profiles with the same blind spot.
- **Threats** — Competitor strengths we must respond to within 90 days. Priority-weighted by profile `priority:` field.

---

## Catalog Snapshot

| Profile | Category | Priority | Schema | Confidence |
|---------|----------|----------|--------|------------|
| `direct/{{slug1}}.md` | direct | P0 | 1 | complete |
| `direct/{{slug2}}.md` | direct | P1 | 1 | partial |
| `indirect/{{slug3}}.md` | indirect | P2 | 1 | complete |

---

## Strengths (our wins backed by their gaps)

| Our Strength | Competitor Weakness Exploited | Source Profiles |
|--------------|-------------------------------|-----------------|
| {{our capability}} | {{their gap, e.g., "no multi-tenant SSO"}} | [slug1](direct/slug1.md#weaknesses), [slug2](direct/slug2.md#weaknesses) |

---

## Weaknesses (our gaps backed by their wins)

| Our Gap | Competitor Strength | Source Profiles | Response Track |
|---------|---------------------|-----------------|----------------|
| {{our gap}} | {{their strength}} | [slug1](direct/slug1.md#strengths) | Quick Win / Gap Fill / Long-Term / Accept |

---

## Opportunities (nobody fills — first-mover potential)

Requirements: ≥2 profiles must share the blind spot to qualify as a market gap.

| Opportunity | Evidence (≥2 profiles) | Feasibility | Time Horizon |
|-------------|------------------------|-------------|--------------|
| {{capability nobody offers}} | [slug1](direct/slug1.md), [slug3](indirect/slug3.md) | Low / Med / High | 0-3mo / 3-6mo / 6-12mo |

---

## Threats (must respond within 90 days)

Priority-weighted by profile `priority:` field. P0 threats surface first.

| # | Threat | Source Profile | Signal Tier | Recommended Response |
|---|--------|----------------|-------------|----------------------|
| 1 | {{competitor capability threatening our position}} | [slug1](direct/slug1.md#strengths) | HIGH | {{specific action}} |

---

## Cross-Cutting Patterns

Observations that span ≥3 profiles:

- **Data hierarchy** — {{which data tiers competitors occupy; where we sit; where the gap is}}
- **Common JTBD under-served** — {{jobs multiple competitors fail at}}
- **Tech stack convergence** — {{patterns in tech_signals indicating category norms}}
- **GTM motion distribution** — {{self-serve vs sales-led split in the category}}

---

## Prioritized Action Plan

| Priority | Action | Track | Owner | Target Date |
|----------|--------|-------|-------|-------------|
| 1 | {{specific action derived from SWOT}} | Quick Win / Gap Fill / Long-Term | {{owner}} | {{date}} |

---

## Open Questions (escalate to council if unresolved)

- [ ] {{unresolved strategic question surfaced by the roll-up}}
- [ ] ...

## Review Log

| Date | Reviewer | Change |
|------|----------|--------|
| {{YYYY-MM-DD}} | {{name}} | Generated from {{count}} profiles |
