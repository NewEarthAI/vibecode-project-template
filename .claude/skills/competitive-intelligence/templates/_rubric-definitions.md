# Rubric Definitions

> Single source of truth for 0-5 scoring across all competitor profiles in this catalog.
> Without consistent definitions, "3" means different things to different sessions → catalog becomes noise.

**This file defines a generic 7-dimension starter rubric.** Replace dimensions with domain-specific ones on first customization (e.g., a PropTech project replaces with `underwriting_ai`, `buybox_matching`, `crm_integration_depth`, etc.). When dimensions change, bump `schema_version` in the profile template and in all existing profiles.

---

## product_quality

How well does the product execute its core job?

- **0** — Broken / abandoned. Users report bugs, crashes, fundamental breakage.
- **1** — Works but painful. Frequent bugs, awkward UX, recent negative reviews dominate.
- **2** — Functional. Core features work. UX is average for category.
- **3** — Solid. Core features work well. Polish evident. Users generally satisfied.
- **4** — Strong. Core + secondary features work well. Delight moments. Power users praise.
- **5** — Exceptional. Best-in-category execution. Referenced as the quality bar others aim for.

## pricing_clarity

How understandable and accessible is pricing?

- **0** — No public pricing. "Contact sales" only.
- **1** — Opaque tiers. Requires sales call to understand real cost.
- **2** — Published tiers but significant hidden costs (overages, add-ons, setup fees).
- **3** — Published tiers, mostly transparent. Minor add-ons.
- **4** — Fully published, transparent. Clear value at each tier. Calculator available.
- **5** — Exceptional clarity. Interactive calculator + transparent usage-based metering + public rate card.

## positioning_sharpness

How clear and distinctive is their market positioning?

- **0** — No clear positioning. Generic "platform for X" copy.
- **1** — Positioning exists but is generic / interchangeable with competitors.
- **2** — Positioning has a point of view but isn't distinctive.
- **3** — Clear positioning. Distinguishable from 2-3 closest competitors.
- **4** — Sharp positioning. Clear ICP, clear non-ICP. Opinionated product.
- **5** — Category-defining. Known for one specific stance that shapes market conversation.

## traction_signals

Evidence of growth and market traction.

- **0** — No visible traction. No users, no press, no funding.
- **1** — Early stage. <100 visible users, minimal press.
- **2** — Modest traction. Some visible users, regional press, small funding.
- **3** — Clear traction. Thousands of users OR meaningful ARR OR Series A funding.
- **4** — Strong traction. 10K+ users OR $10M+ ARR OR Series B+ funding. Category listings.
- **5** — Dominant. Market leader position. Public or pre-IPO. Referenced as the benchmark.

## review_sentiment

What do actual users say?

- **0** — Majority negative. Recent reviews dominated by complaints.
- **1** — Mixed-leaning-negative. More complaints than praise in recent reviews.
- **2** — Mixed. Roughly equal positive and negative themes.
- **3** — Mixed-leaning-positive. More praise than complaint. Known pain points acknowledged.
- **4** — Positive. Strong satisfaction. Complaints are edge cases.
- **5** — Evangelism. Users recommend unprompted. Low churn.

*Source requirement*: minimum 1 positive and 1 negative review cited. Never score on marketing testimonials alone.

## content_velocity

How actively do they publish / engage?

- **0** — Inactive. No new content in >6 months.
- **1** — Sporadic. Occasional posts, no cadence.
- **2** — Regular but slow. Monthly posts, limited reach.
- **3** — Consistent. Weekly content across blog + social.
- **4** — High velocity. Multiple channels, multiple formats, strong engagement.
- **5** — Content leader. Original research, influential voice, drives category conversation.

## team_signals

What does the team composition suggest about trajectory?

- **0** — Team decay. Recent layoffs, key departures visible on LinkedIn.
- **1** — Stagnant. Same team >18 months, no hiring signals.
- **2** — Stable. Normal turnover, no aggressive hiring.
- **3** — Growing. Active hiring, roles filled. Normal investor-backed trajectory.
- **4** — Scaling hard. Aggressive hiring across engineering + GTM. Strong LinkedIn signals.
- **5** — Elite team. Hiring signals elite engineering talent. Leadership with track record.

---

## Scoring Discipline

Every score must include:

- A numeric value 0-5 matching one of the definitions above
- An evidence citation (URL or "user-provided on {date}")
- A confidence marker: HIGH (≥2 independent sources) / MEDIUM (1 source, plausible) / LOW (inference, flagged)

Example:
```
product_quality: 3  # HIGH — G2 avg 4.2/5 across 247 reviews [link], Reddit r/X thread praises core features [link]
```

## Schema Version

Current: **1** (generic 7-dim starter)

When adding, removing, or renaming dimensions → bump `schema_version` in this file AND in the profile template. Mixed-version profiles cannot be aggregated in SWOT roll-ups — the roll-up will refuse and surface a migration-needed error.
