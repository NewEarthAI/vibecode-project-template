---
name: competitive-intelligence
description: |
  Produce decision-grade competitive intelligence aligned with a project's Strategic Intelligence (SI) skeleton: hybrid JTBD competitor profiles with YAML frontmatter + rubric scoring, SWOT roll-ups, positioning cross-references, decisions-log entries, and ongoing tracking. Use when user asks about competitor analysis, competitive analysis, competitor deep-dive, competitor profile, market SWOT, market landscape, positioning, battlecard, teardown, feature comparison, keyword gap, link gap, competitor tracking, or "analyze {competitor}." Phase 0 auto-discovers project `strategy/competitive-intel/` skeleton OR scaffolds from bundled templates on first use OR runs fallback mode. Every metric has a source URL; every scrape respects robots.txt and TOS. Supersedes 7 earlier competitor-* skills.
version: "1.0.0"
classification: capability-uplift
allowed-tools: WebSearch, WebFetch, Read, Write, Grep, Glob, Bash
parameters:
  - name: scope
    type: string
    default: auto
    description: "auto (Phase 0 discovery) | platform-saas | seo-geo | app-store | marketplace | generic"
  - name: depth
    type: string
    default: profile
    description: "profile (single competitor) | swot-rollup (≥3 profiles) | ongoing (recurring delta)"
  - name: category
    type: string
    default: direct
    description: "direct | indirect | adjacent"
  - name: priority
    type: string
    default: P1
    description: "P0 (this quarter) | P1 (next 90d) | P2 (backlog)"
  - name: max_requests_per_minute
    type: number
    default: 60
    description: "Rate-limit ceiling for scraping + API calls"
  - name: enable_surveillance_patterns
    type: boolean
    default: false
    description: "Adversarial search patterns (lawsuits, layoffs, exec tracking). OFF by default."
validated_on:
  - "Generic 7-dim rubric (template fallback)"
  - "PropTech 11-dim rubric (a SaaS app strategic-intelligence-skeleton-design spec — binding verified when strategy/ scaffolded)"
  - "Platform-SaaS competitor profile + JTBD analysis"
  - "SEO/GEO domain audit"
triggers:
  - "competitor analysis"
  - "competitive analysis"
  - "competitive intelligence"
  - "competitor research"
  - "competitor deep-dive"
  - "competitor profile"
  - "competitor teardown"
  - "market SWOT"
  - "SWOT analysis"
  - "market landscape"
  - "competitive landscape"
  - "positioning analysis"
  - "feature comparison"
  - "battlecard"
  - "analyze {competitor}"
  - "keyword gap"
  - "content gap"
  - "link gap"
  - "track competitors"
  - "competitor monitoring"
  - "predict competitor next moves"
  - "竞品分析"
  - "对标分析"
metadata:
  supersedes:
    - competitor-analysis
    - competitor-analysis-seo
    - competitor-teardown
    - beat-competitors
    - competitor-research
    - competitor-tracking
    - competitor-intel
  complements:
    - apify-ultimate-scraper (optional scraping backend)
    - agent-research (parallel multi-source research)
    - presentation (stakeholder deck output)
  schema_version: 1
  template_assets:
    - templates/_template-competitor-profile.md
    - templates/_rubric-definitions.md
    - templates/_research-runbook.md
    - templates/_swot-rollup-template.md
    - templates/catalog-README.md
    - templates/positioning-README.md
    - templates/decisions-log.md
---

# Competitive Intelligence

> Decision-grade competitor profiles + SWOT roll-ups + positioning cross-refs that **plug into an existing Strategic Intelligence (SI) catalog** when present, scaffold one when absent, and never silently produce output into a parallel silo.

---

## Phase 0 — Context Discovery (MANDATORY, runs FIRST, HARD-STOPS if unresolved)

Before any research. Resolve project root, discover SI infrastructure, emit Binding Report, obtain explicit user consent on output path.

### 0.1 Resolve project root (prevents worktree misfire)

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

All subsequent paths are `$PROJECT_ROOT`-anchored. Never cwd-relative.

### 0.2 Discover SI infrastructure

Glob in this order (first match wins for `$SI_ROOT`):

| Check | Pattern | Meaning |
|---|---|---|
| A | `$PROJECT_ROOT/strategy/competitive-intel/` | Full SI umbrella — bind |
| B | `$PROJECT_ROOT/specs/*strategic-intelligence*skeleton*` | Spec approved, scaffold not executed yet |
| C | `$PROJECT_ROOT/docs/competitive-intelligence/` | Docs-based catalog — treat as alt umbrella |
| D | `$PROJECT_ROOT/specs/*rental-comp*competitive-intel*`, `$PROJECT_ROOT/specs/*data-layer-intel*` | Sister data-layer catalog — cross-link ONLY, do not merge |
| E | nothing | Greenfield — offer scaffold |

For check A, also probe for component completeness:

| File | Meaning if missing/empty |
|---|---|
| `$SI_ROOT/_template-competitor-profile.md` | PARTIAL — use bundled template, warn user |
| `$SI_ROOT/_rubric-definitions.md` | PARTIAL — block scoring (rubric drift risk). Hard-warn. |
| `$SI_ROOT/_research-runbook.md` | PARTIAL — use bundled fallback |
| `$SI_ROOT/_swot-rollup-template.md` | PARTIAL — use bundled fallback |
| `$SI_ROOT/README.md` | PARTIAL — catalog index will be generated |
| `$PROJECT_ROOT/strategy/our-profile.md` | **CRITICAL — no reference point for Differentiation Hypothesis.** HARD-WARN before first profile. Offer to seed via `/setup` wizard answers OR manual paste. |
| `$PROJECT_ROOT/strategy/positioning/README.md` at v0.0 placeholder | **CRITICAL — positioning ungrounded.** HARD-WARN before first profile. Differentiation Hypothesis will read "TBD" (circular dependency — see SI skeleton design §D5). |

### 0.3 Emit Binding Report (always visible)

```
━━━ Binding Report ━━━
Project root:       $PROJECT_ROOT
SI umbrella:        $SI_ROOT | NOT FOUND
Template source:    $SI_ROOT/_template-competitor-profile.md | BUNDLED-FALLBACK
Rubric source:      $SI_ROOT/_rubric-definitions.md | MISSING (scoring blocked) | BUNDLED-FALLBACK
Runbook source:     $SI_ROOT/_research-runbook.md | BUNDLED-FALLBACK
SWOT template:      $SI_ROOT/_swot-rollup-template.md | BUNDLED-FALLBACK
Existing profiles:  {{count_direct}} direct, {{count_indirect}} indirect, {{count_adjacent}} adjacent
Related catalog:    {{data-layer cross-link or "none"}}
Output target:      {{resolved absolute path}}
━━━━━━━━━━━━━━━━━━━━━━
```

### 0.4 HARD-STOP decision gate

If SI umbrella `NOT FOUND` AND `depth=profile`, HALT and present:

```
No SI infrastructure found at $PROJECT_ROOT/strategy/competitive-intel/.

(a) Scaffold skeleton now — writes 7 files from bundled templates to:
    $PROJECT_ROOT/strategy/competitive-intel/
    $PROJECT_ROOT/strategy/positioning/
    $PROJECT_ROOT/strategy/decisions-log.md
    Single-confirmation preview with absolute paths.

(b) Session-only fallback — proceed with embedded generic templates, write output
    to $PROJECT_ROOT/docs/competitive-intelligence/{{slug}}/{{YYYY-MM-DD}}/.
    No skeleton created. Catalog integrity not established.

Which mode? (a/b)
```

Do not proceed past this gate until user chooses. No silent fallback.

If SI umbrella FOUND but PARTIAL (rubric missing), warn:
```
WARNING: $SI_ROOT/_rubric-definitions.md is missing. Scoring without a rubric
definition file causes score drift across profiles. Proceed to score with
bundled 7-dim fallback, OR halt and complete the rubric file first?  (proceed/halt)
```

### 0.5 Slugify inputs

Any `{{topic}}` or `{{competitor}}` value passed to a write path MUST be slugified:
- lowercase
- spaces → hyphens
- strip non-`[a-z0-9\-]`
- collapse `-+` → `-`
- trim leading/trailing `-`

`"DispoGenius (2026)"` → `dispogenius-2026`. `"PropTech / Wholesalers"` → `proptech-wholesalers`.

Slug collision check: before writing `$SI_ROOT/$category/$slug.md`, glob `$SI_ROOT/*/$slug.md` AND `$SI_ROOT/*/*${slug}*.md` for fuzzy match. If a match exists, surface "possible duplicate" and require user confirmation.

---

## Ethical & Compliance Baseline (MANDATORY)

| Rule | How Applied |
|------|-------------|
| Scraping legality | Own domain OR written auth. Else: verify `robots.txt`, respect `Crawl-delay`, confirm TOS. Print URL + robots.txt + TOS check before any scrape. Fallback: manual-data mode. |
| Source citation | Every metric has source URL OR marked "Not publicly available". No estimates. No "likely" numbers. |
| Constructive framing | Focus: product, pricing, positioning, UX, public reviews. NO adversarial searches (lawsuits, layoffs, exec tracking) unless `enable_surveillance_patterns=true` + user states purpose. |
| Credential hygiene | API tokens in `.env`. Never hardcoded. Pattern: `node --env-file=.env`. Never `KEY="apk_your_key"`. |
| Rate limits | Default `{{max_requests_per_minute}}`=60. Lower for aggressive anti-bot sites. |
| Honest confidence | High / Medium / Low applied honestly. High = ≥2 independent sources. |

---

## Phase 1 — Identify Competitors

If user provides → skip. If SI catalog has stubs → offer to use them.

| Type | Definition | How to Find |
|------|-----------|-------------|
| Direct | Same job, same persona | Top SERP for primary keywords; "who do customers compare you to?" |
| Indirect | Different solution, same job | Problem-focused keywords; alternative workflows |
| Content / Keyword | Competes for same keywords regardless of product | `site:competitor.com`; includes media + blogs |
| Adjacent / Aspirational | Larger player, adjacent category | Category leaders; king-makers |

Target: 3-5 (hard cap).

---

## Phase 2 — Select Depth

| depth | Trigger | Output |
|-------|---------|--------|
| `profile` (default) | Single competitor deep-dive | One hybrid JTBD profile, rubric-scored, YAML-framed |
| `swot-rollup` | ≥3 profiles in catalog | Market SWOT, every cell cites specific profiles |
| `ongoing` | Recurring monitoring | Delta report + decisions-log append for material changes |

---

## Phase 3 — Research

### When runbook bound

Read `$SI_ROOT/_research-runbook.md` for authoritative source checklist, quality bar, and `/agent-research` prompt template. Use verbatim.

### Fallback source checklist (runbook absent)

- **Company**: website, LinkedIn (founders + headcount + hires), pricing page (Wayback if gated)
- **Reviews**: G2, Capterra, TrustRadius, App Store, Product Hunt, Reddit (relevant subs)
- **Tech signals**: BuiltWith, GitHub org (if public), job postings (tech stack)
- **Content / PR**: blog, podcast, press, partnerships
- **Reputation (constructive only)**: Reddit, YouTube demos, Trustpilot

### Minimum quality bar before `confidence: complete`

- ≥3 independent sources
- ≥1 user review (positive + negative both)
- Pricing verified OR marked "opaque — unverified"
- ≥1 JTBD inferred from direct user language (not marketing copy)

---

## Phase 4 — Output (binds to project templates)

### 4.1 Competitor Profile → `$SI_ROOT/$category/$slug.md`

**When SI template bound**: use `_template-competitor-profile.md` verbatim.

**Fallback (bundled template)**: hybrid JTBD + YAML frontmatter.

YAML schema (write THIS block on every profile output — Edge Case #2 fix):

```yaml
---
name: {{CompetitorName}}
slug: {{slug}}
category: direct          # direct | indirect | adjacent
stage: growth             # stealth | early | growth | mature | legacy
added: {{YYYY-MM-DD}}
last_verified: {{YYYY-MM-DD}}
priority: {{priority}}    # P0 | P1 | P2
pricing_band: {{band or "unknown"}}
target_persona: {{primary user}}
gtm_motion: self-serve    # self-serve | sales-led | plg | partnership-led | influencer-driven
tech_signals: [...]
confidence: stub          # stub | partial | complete | verified
schema_version: 1         # increment when rubric dimensions change (Edge Case #11 fix)
scores:                   # keys sourced from _rubric-definitions.md if present, else fallback 7-dim
  {{dim_1}}: 0
  {{dim_N}}: 0
---
```

Body sections (required, in order):
1. **One-line identity** (≤12 words)
2. **Structured header** — pricing, persona, GTM motion, tech signals
3. **Job-To-Be-Done Analysis** (4 sub-sections):
   - What job is the user hiring this to do? (specific)
   - How well does it do that job?
   - Where does it fall short?
   - What jobs is it NOT hired to do? *(differentiation gold)*
4. **Strengths** (numbered, evidence-backed)
5. **Weaknesses** (numbered, evidence-backed)
6. **Notable features / resources worth learning from**
7. **Our Differentiation Hypothesis** (cross-ref `$PROJECT_ROOT/strategy/positioning/`):
   - Job overlap with us
   - Where we win (evidence)
   - Where they win (evidence)
   - Where we don't compete
   - **Integration hypothesis**: could they be a partner, not a competitor?
8. **Open questions / research debt**
9. **Review log** (dated entries — prevents silent profile rot)

### 4.2 Rubric Scoring

- **SI rubric bound**: score on dimensions from `_rubric-definitions.md` verbatim. Every score cites evidence.
- **Rubric missing, SI partial**: HARD-WARN per Phase 0.4.
- **Full fallback**: use generic 7-dim (`product_quality`, `pricing_clarity`, `positioning_sharpness`, `traction_signals`, `review_sentiment`, `content_velocity`, `team_signals`).

### 4.3 SWOT Roll-up → `$SI_ROOT/swot-rollups/{{YYYY-MM-DD}}-{{scope}}-rollup.md`

Runs ONLY when `depth=swot-rollup` AND ≥3 profiles exist. **Schema version gate**: refuse to roll up profiles with mixed `schema_version` values — surface migration-needed error instead of silently averaging incompatible rubrics (Edge Case #11 fix).

- **Strengths**: our strengths that exploit documented competitor weaknesses. Cite profile paths.
- **Weaknesses**: our gaps vs. documented competitor strengths. Cite profiles.
- **Opportunities**: gaps nobody fills (find ≥2 profiles with same blind spot).
- **Threats**: competitor strengths we must respond to within 90d.

No unsourced claims.

### 4.4 Decisions Log → `$PROJECT_ROOT/strategy/decisions-log.md` (append-only, single-writer)

If research surfaces a strategic decision (pivot, reclassification, positioning shift):

```
## {{YYYY-MM-DD}} — {{Decision title}}
**Trigger**: {{what learning prompted this}}
**Decision**: {{what was chosen}}
**Alternatives considered**: {{what was rejected and why}}
**Source**: {{profile path, council session, user feedback}}
**Revisit by**: {{date or trigger condition}}
```

Concurrent-write protection (Edge Case #4): never append from automated hooks/agents. Sessions-sidecar pattern on collision — write to `decisions-log-{{YYYY-MM-DD}}-{{session}}.md` and request manual merge.

### 4.5 Catalog Index → `$SI_ROOT/README.md`

Add profile to catalog index table. Update confidence tally. Slug collision check (Phase 0.5).

### 4.6 Positioning Cross-Check → `$PROJECT_ROOT/strategy/positioning/README.md`

If profile's Differentiation Hypothesis conflicts with current positioning → flag for council session. Do not silently reconcile.

### 4.7 Ongoing Tracking → `$SI_ROOT/tracking/{{YYYY-MM-DD}}-{{slug}}.md`

Delta-only report. Append material changes to decisions-log.

### 4.8 Competitive Response Playbook (reusable trigger → response)

| Trigger | Response |
|---------|----------|
| Competitor launches feature you lack | Log in profile `Open questions`; assess roadmap fit |
| Competitor pricing change | Update `pricing_band`; re-check positioning; battlecard refresh |
| New competitor enters category | Create stub → promote to P0/P1 based on overlap |
| Competitor funding round | Update `stage`; watch for aggressive expansion |
| Leadership departure (LinkedIn) | Log as strategic signal; watch for pivot |
| Competitor appears in user conversations | Escalate to P0 if critical |

---

## Phase 5 — Tool-Augmented Gathering (OPTIONAL)

| Tool | When | Setup |
|------|------|-------|
| WebSearch / WebFetch | Always | Built-in |
| `apify-ultimate-scraper` (sibling) | Social, review bulk | `APIFY_TOKEN` in `.env` |
| `agent-research` (sibling) | Parallel multi-source | Built-in |
| SEO MCP (Ahrefs/SEMrush) | Keyword, backlink | MCP configured |
| App Store intel MCP | ASO rankings | API key in `.env` |

**Cost safety**: >100 results → confirm. >1,000 Apify → opt-in + estimated credit cost first.

---

## Phase 6 — Save & Promote

1. **Write** profile to `$SI_ROOT/$category/$slug.md` (absolute path confirmed)
2. **Update** catalog index `$SI_ROOT/README.md`
3. **Append** decisions-log if strategic signal surfaced
4. **Emit handoff summary**:
   - Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_INPUT
   - Profile written: `{{path}}` ({{confidence}})
   - Rubric scored: {{dims filled}}/{{total}}
   - Sources cited: {{count}}
   - Strategic signals: {{decisions appended, positioning conflicts flagged}}
   - Open research debt: {{unverifiable items}}
   - Recommended next skill: {{one move}}
5. **Flag** positioning conflicts for council session if any
6. **If `depth=ongoing`** → schedule next refresh per cadence

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Skip Phase 0 | Silent output to parallel silo; skeleton ignored | Phase 0 always runs; hard-stop if unresolved |
| Silent fallback without Binding Report | User can't see binding misfire | Always print Binding Report before any write |
| Invent persona vocabulary when project has personas | Catalog drift; cross-profile compare breaks | Use project's rubric + personas verbatim |
| Score a dimension without evidence | Rubric becomes opinion | Every score has source URL or "Not publicly verifiable" |
| `KEY="apk_your_key"` in bash | Key leaks into shell history | `node --env-file=.env` OR `${{API_KEY}}` |
| Surveil lawsuits, layoffs, exec personal life | Reputation warfare, not intel | Product / pricing / positioning / UX / public reviews |
| Skip robots.txt + TOS | Legal exposure | Verify before any scrape |
| Blanket `Bash({{cli}} *)` allowed-tools | Over-broad; can't audit | Narrow tool list + explicit opt-in for external CLIs |
| Scrape 55+ platforms "to gather everything" | Noise + credits + legal | Scope first — 1-3 sources per question |
| All findings "High Confidence" | False precision | High requires ≥2 independent sources |
| Feature-only comparison | Misses pricing, positioning, traction | JTBD + rubric + 7-layer |
| 10+ competitors at once | Analysis paralysis | 3-5 max per wave |
| Biased ("we're better") | Loses credibility | Honest about competitor strengths |
| Undated findings | Stale state drives decisions | Date + `last_verified` every finding |
| Estimating undisclosed metrics | Fabrications corrupt catalog | Mark "Not publicly available" |
| Mixing profiles with different `schema_version` in roll-up | Compares incompatible rubrics | Refuse mixed roll-up; surface migration-needed error |
| Merge new findings into positioning silently when conflict | Destroys traceability | Flag for council; log in decisions-log |

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No `strategy/` umbrella AND no skeleton spec | Phase 0.4 HARD-STOP — user chooses scaffold or session-only |
| SI umbrella present but rubric missing | Phase 0.4 HARD-WARN — user chooses proceed with fallback or halt |
| Profile exists with `confidence: stub` | Ask: augment in place or overwrite? |
| Slug collision detected | Surface match; require user confirmation |
| Mixed `schema_version` in SWOT roll-up | Refuse; surface migration-needed error |
| No API credentials | Fall back to manual; prompt for URLs + facts |
| WebSearch rate-limited | Reduce batch; prioritize; queue remainder |
| Competitor blocks scraping | Mark source "user-provided only"; halt that domain |
| Metric unverifiable after ≥2 attempts | Mark "Not publicly available" |
| User provides <2 competitors AND no stubs | Require min 2; assist via Phase 1 |
| Scrape >100 results | Confirm before continuing |
| Apify scrape >1,000 results | Opt-in + estimated credit cost first |
| `enable_surveillance_patterns=true` without purpose | HALT; require user to state purpose + acknowledge |
| Profile conflicts with positioning v0.1 | Flag for council; do NOT silently reconcile |
| Writing from git worktree | Resolve absolute path via `git rev-parse --show-toplevel`; confirm with user before write |

---

## Defaults

| Parameter | Default | Adjust When |
|-----------|---------|-------------|
| `{{scope}}` | `auto` | User specifies explicitly |
| `{{depth}}` | `profile` | ≥3 profiles → `swot-rollup`; recurring → `ongoing` |
| `{{category}}` | `direct` | Indirect / adjacent per Phase 1 |
| `{{priority}}` | `P1` | P0 this quarter; P2 backlog |
| `{{max_requests_per_minute}}` | 60 | Anti-bot sites → ≤20 |
| `{{enable_surveillance_patterns}}` | `false` | Documented purpose only |
| Confidence threshold for Executive Summary | High | Only High findings surface in TL;DR |
| Refresh cadence (ongoing) | Quarterly | High-velocity → monthly |

---

## Next Best Skills

- **`presentation`** — Stakeholder deck from SWOT roll-up or battlecard
- **`agent-research`** — Parallel multi-source investigation
- **`apify-ultimate-scraper`** — Social / review scraping at scale
- **`skill-auditor-merger`** — If another competitor-analysis skill worth absorbing

---

<!-- AUDIT METADATA
sources_audited: 8
source_grades: D (competitor-tracking, competitor-analysis-ASO) | D+ (competitor-research) | C- (competitor-teardown, beat-competitors, competitor-intel) | C (competitor-analysis-seo, apify-ultimate-scraper)
audit_date: 2026-04-18
council_review: 2026-04-18 (extended mode, 7 agents — Reframer skipped per user)
council_session: council/sessions/2026-04-18-competitive-intelligence-super-skill.md
merge_actions: keep=9 upgrade=7 absorb=11 supplement=4 rewrite=2 drop=4 incompatible=2
superior_patterns_absorbed: 17
skeleton_patterns_promoted: 8 (JTBD 4-sub-section, YAML frontmatter, 11-dim rubric, integration hypothesis, decisions-log append, SWOT-rollup cites profiles, review log, direct/indirect/adjacent)
skeleton_alignment: specs/2026-04-18-strategic-intelligence-skeleton-design.md
council_guardrails_implemented:
  - Phase 0 Context Discovery with git-root absolute-path resolution
  - Phase 0.4 HARD-STOP when skeleton absent + depth=profile (prevents silent-drift failure)
  - Phase 0.4 HARD-WARN when rubric missing (prevents score drift)
  - Slug sanitization + collision detection
  - YAML frontmatter generation on every profile output
  - schema_version field prevents cross-version roll-up corruption
  - Binding Report emitted before every write
security_hardening:
  - DROPPED "KEY=apk_your_key" bash pattern (competitor-tracking)
  - DROPPED lawsuit/sued/layoffs/firing adversarial searches (competitor-intel)
  - DROPPED "doesn't work / broken / terrible" search pattern (competitor-intel)
  - NARROWED allowed-tools (was "Bash(infsh *)" blanket)
  - PROMOTED robots.txt+TOS+Crawl-delay to mandatory baseline (competitor-analysis-seo)
  - PROMOTED source-citation-or-mark-unavailable to universal baseline (competitor-intel)
  - ADDED rate-limit default (60 rpm)
  - GATED adversarial patterns behind bool param + documented purpose
  - GENERALIZED proprietary "Appeeky" API references to generic polling pattern
supersedes (deleted 2026-04-18):
  - .claude/skills/competitor-analysis/
  - .claude/skills/competitor-analysis-seo/
  - .claude/skills/competitor-teardown/
  - .claude/skills/beat-competitors/
  - .claude/skills/competitor-research/
  - .claude/skills/competitor-tracking/
  - .claude/skills/competitor-intel/
known_validation_false_positives:
  - Prose words matching /rec[a-z]+/ hardcoded-ID regex: "recurring", "recommend". Content, not IDs. Flagged per skill-auditor-merger protocol.
-->
