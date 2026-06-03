---
name: {{CompetitorName}}
slug: {{competitor-slug}}
category: direct                # direct | indirect | adjacent
stage: growth                   # stealth | early | growth | mature | legacy
added: {{YYYY-MM-DD}}
last_verified: {{YYYY-MM-DD}}
priority: P1                    # P0 (this quarter) | P1 (next 90d) | P2 (backlog)
pricing_band: unknown           # free | freemium | starter-$X | mid-$X | enterprise | unknown
target_persona: {{primary user archetype}}
gtm_motion: self-serve          # self-serve | sales-led | plg | partnership-led | influencer-driven
tech_signals: []
confidence: stub                # stub | partial | complete | verified
schema_version: 1               # INCREMENT when rubric dimensions change
scores:                         # keys MUST match _rubric-definitions.md
  product_quality: 0
  pricing_clarity: 0
  positioning_sharpness: 0
  traction_signals: 0
  review_sentiment: 0
  content_velocity: 0
  team_signals: 0
---

# {{CompetitorName}} — {{one-line positioning ≤12 words}}

> Added {{YYYY-MM-DD}}. Sources: {{count}} independent sources. Confidence: {{confidence}}.

## Structured Header

| Field | Value |
|-------|-------|
| Pricing band | {{band}} |
| Target persona | {{persona}} |
| GTM motion | {{motion}} |
| Tech signals | {{stack detected via BuiltWith / hiring / GitHub}} |

## Job-To-Be-Done Analysis

### What job is the user hiring this tool to do?
{{Specific job statement — not "task management" but "coordinate distributed team across timezones so decisions don't stall." Draw from user language in reviews/forums, not marketing copy.}}

### How well does it do that job?
{{Evidence-backed assessment. Cite reviews, demo impressions, direct observation.}}

### Where does it fall short of the job?
{{Specific gaps with evidence from negative reviews, switching stories, feature requests.}}

### What jobs is it NOT hired to do?
{{The differentiation gold. What adjacent jobs does this tool not serve that a replacement or complement might? This feeds "Our Differentiation Hypothesis" below.}}

## Strengths (numbered, evidence-backed)

1. {{Strength}} — [source URL]
2. ...

## Weaknesses (numbered, evidence-backed)

1. {{Weakness}} — [source URL]
2. ...

## Notable Features / Resources Worth Learning From

- {{Playbook / Skill / Free resource / Integration pattern}} — [link]
- ...

## Our Differentiation Hypothesis

*Cross-reference `strategy/positioning/README.md`.*

### Job overlap with us
{{Which of our JTBD does this competitor also serve?}}

### Where we win (evidence)
{{Specific, evidence-backed.}}

### Where they win (evidence)
{{Specific, evidence-backed. Be honest — credibility matters.}}

### Where we don't compete
{{Explicit acknowledgment of non-overlap.}}

### Integration hypothesis
{{Could they be a partner rather than a competitor? If our positioning is "AI brain that plugs into CRMs," is this competitor actually a CRM platform we integrate into rather than displace? Document the hypothesis + what would prove or disprove it.}}

## Open Questions / Research Debt

- [ ] {{Metric we couldn't verify — suggest how to verify}}
- [ ] {{Claim needing second source}}

## Review Log

| Date | Reviewer | Change | Rationale |
|------|----------|--------|-----------|
| {{YYYY-MM-DD}} | {{name}} | Created as stub | {{why added, priority reasoning}} |
