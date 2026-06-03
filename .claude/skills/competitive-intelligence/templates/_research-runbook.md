# Research Runbook

> Day-1 enabler for competitive deep-dives. Every profile should cite this runbook as its source methodology.

---

## Source Checklist (in priority order)

### Tier 1 — Primary signals (always check)

| Source | What to extract | Gated? |
|--------|-----------------|--------|
| Company website | Positioning, pricing, ICP, feature surface | Public |
| Pricing page (+ Wayback Machine if gated) | Tier structure, hidden costs, minimum seats | Sometimes gated |
| LinkedIn company page | Employee count, recent hires, leadership background | Free, partial |
| LinkedIn founder profile(s) | Prior ventures, domain expertise, thesis | Free, partial |

### Tier 2 — User voice (REQUIRED for `confidence: complete`)

| Source | What to extract |
|--------|-----------------|
| G2 reviews | Pros, cons, switching reasons, feature requests |
| Capterra / TrustRadius | Corroborating voice; different user segment |
| Reddit (relevant subs) | Unfiltered sentiment, frustration, comparison threads |
| App Store / Play Store reviews (if applicable) | Mobile UX signals, rating trajectory |
| Product Hunt (if launched there) | Launch reception + commenter demographics |

### Tier 3 — Tech + product signals

| Source | What to extract |
|--------|-----------------|
| BuiltWith | Tech stack (CMS, analytics, marketing automation, hosting) |
| GitHub org (if public) | Open-source footprint, commit activity, contributor count |
| Job postings (own career page + LinkedIn) | Tech stack via job reqs; team expansion direction |
| YouTube demos / tutorials | Actual product UX, workflows, quality bar |

### Tier 4 — Strategic signals

| Source | What to extract |
|--------|-----------------|
| Crunchbase | Funding history, investor thesis, valuation signals |
| Press releases | Announced partnerships, launches, strategic pivots |
| Podcast appearances (founder) | Strategic thinking, roadmap hints, positioning evolution |
| Partnership announcements | Integration strategy, market expansion signals |

### NOT permitted by default (gated behind `enable_surveillance_patterns=true` + documented purpose)

- Lawsuits, legal filings, executive-level personal searches
- Layoff tracking, firing rumors
- "doesn't work / broken / terrible" adversarial framing queries

These are available for legitimate vendor due diligence with a stated purpose — never for competitive copy-writing.

---

## Minimum Quality Bar Before Marking `confidence: complete`

- [ ] ≥3 independent sources cited
- [ ] ≥1 user review cited (positive AND negative both present)
- [ ] Pricing verified OR explicitly marked "opaque — unverified"
- [ ] ≥1 JTBD inferred from direct user language (quote from review/forum, not marketing copy)
- [ ] Every rubric score cites evidence (source URL + confidence tier)
- [ ] Integration hypothesis considered (could they be a partner, not just a competitor?)

---

## Scraping Discipline

Before any automated scrape:

1. Verify the domain is owned by you OR scraping is authorized in writing
2. Check `robots.txt` — respect `Disallow` rules
3. Respect `Crawl-delay` if specified
4. Confirm target TOS permits automated access
5. Default rate limit: 60 requests/minute. Lower for aggressive anti-bot sites.

If any check fails → halt scraping that domain. Mark source as "user-provided only" in profile.

---

## `/agent-research` Prompt Template

Copy this prompt when dispatching an agent to research a competitor:

```
Research {{CompetitorName}} ({{url}}) as a {{direct|indirect|adjacent}} competitor.

Deliverables:
1. One-line positioning (≤12 words, in their voice)
2. Structured header: pricing_band, target_persona, gtm_motion, tech_signals
3. Job-To-Be-Done analysis (4 sub-sections per template)
4. Strengths (numbered, each with ≥1 source URL)
5. Weaknesses (numbered, each with ≥1 source URL)
6. Notable features / resources worth learning from
7. Rubric scores against _rubric-definitions.md (evidence + confidence tier for each)

Constraints:
- ≥3 independent sources minimum
- ≥1 positive user review + ≥1 negative user review cited
- Every metric has source URL OR is marked "Not publicly available"
- No adversarial queries (no lawsuit / layoff / "doesn't work" searches)
- Respect robots.txt on any scrape target
- Output as Markdown matching _template-competitor-profile.md structure exactly

Return the filled template. I will score, cross-reference positioning, and append decisions-log entries.
```

---

## When to Escalate to Council Session

Run `/council` deliberation when:

- Research findings directly CONFLICT with current positioning v0.1
- Two or more competitors occupy the exact space we claim as differentiated
- Rubric scoring reveals we rank below a competitor on a dimension we claim to win
- Integration hypothesis suggests a competitor is actually a partnership opportunity (changes go-to-market motion)
- Discovered competitor's funding or team signals suggest a 6-month pivot window

Link the council session in the profile's Review Log.

---

## Refresh Cadence (for ongoing monitoring)

| Priority | Default refresh | Triggers for ad-hoc refresh |
|----------|----------------|-----------------------------|
| P0 | Monthly | Funding round, leadership change, product launch, pricing change |
| P1 | Quarterly | Funding round, product launch |
| P2 | Semi-annually | Category-shifting event |

Append every refresh as a Review Log entry with date + changes observed.
