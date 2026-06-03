# Document Archetypes — Content Structure Templates

> Each archetype defines a proven content structure for its document type.
> Map your source material to these sections, then generate slides from the outline.

---

## 1. Client Proposal

**When**: Pitching services to a prospective or existing client.
**Typical length**: 12-18 slides (HTML) / 12-18 slides (PPTX)

### Content Structure

```
1. TITLE SLIDE
   - Company name + logo
   - Proposal title: "AI Automation Proposal for {{client_name}}"
   - Date
   - "Prepared by {{agency_name}}"

2. THE CHALLENGE (1-2 slides)
   - Client's current pain points (gathered from discovery/conversation)
   - Quantified impact: time wasted, errors, revenue leakage
   - Slide type: Content or Bold Claim

3. THE OPPORTUNITY (1-2 slides)
   - Industry benchmarks / what "good" looks like
   - Competitive pressure or market shifts
   - Slide type: Split (current vs possible)

4. OUR APPROACH (2-3 slides)
   - Phase-by-phase methodology
   - Tools and technologies (automation platforms, databases, AI/ML)
   - Diagram: Assembly Line of the implementation pipeline
   - Slide type: Content + Diagram

5. SCOPE OF WORK (2-3 slides)
   - Detailed deliverables list
   - What's included vs excluded
   - Table format: Deliverable | Description | Timeline
   - Slide type: Data/Table

6. TIMELINE & MILESTONES (1-2 slides)
   - Gantt-style or milestone timeline
   - Key checkpoints and review meetings
   - Slide type: Timeline

7. INVESTMENT (1-2 slides)
   - Pricing tiers if applicable
   - Payment terms
   - ROI estimate (conservative/moderate/aggressive)
   - Slide type: Data + Bold Claim (ROI)

8. WHY US (1-2 slides)
   - Differentiators
   - Relevant case studies / experience
   - Team qualifications
   - Slide type: Content

9. NEXT STEPS / CTA (1 slide)
   - Clear call to action
   - Contact information
   - "Let's schedule a discovery call"
   - Slide type: CTA
```

---

## 2. AI Maturity Audit Report

**When**: Delivering results of an AI maturity assessment.
**Typical length**: 20-35 slides (HTML) / Longer for PPTX (maps to the 12-section report structure)
**Source**: `agency/AI_MATURITY_AUDIT_TEMPLATE.md` for methodology

### Content Structure

```
1. TITLE SLIDE
   - "AI Maturity Audit Report"
   - Client name + industry
   - Audit date range
   - Evidence level badge (Bronze/Silver/Gold)

2. EXECUTIVE SUMMARY (2-3 slides)
   - Composite maturity score (large number, Bold Claim slide)
   - Radar chart of 6 domains
   - Top 3 opportunities with estimated ROI
   - Recommended first action

3. METHODOLOGY (1 slide)
   - 6 domains, evidence types, dates, participants
   - Evidence level and confidence statement
   - Slide type: Content

4. MATURITY ASSESSMENT (6-8 slides)
   - One slide per domain OR grouped (2-3 domains per slide)
   - Domain score, current level, evidence summary, key gaps
   - Use color coding: red (1-2), amber (2-3), green (3-5)
   - Bar chart or gauge per domain
   - Slide type: Data + Content

5. PROCESS LANDSCAPE (2-3 slides)
   - Process inventory heatmap
   - Automation potential scoring
   - Before/After comparison for top processes
   - Slide type: Data + Split

6. OPPORTUNITY PORTFOLIO (3-5 slides)
   - Ranked opportunity table (Priority, Impact, Effort, Risk)
   - 2x2 matrix: Impact vs Effort
   - Per-opportunity detail (top 3-5)
   - Slide type: Data + Diagram

7. ROI ANALYSIS (2-3 slides)
   - 3-scenario table per top opportunity
   - Total potential annual savings
   - Payback period
   - Bold Claim: total ROI number
   - Slide type: Data + Bold Claim

8. IMPLEMENTATION ROADMAP (2-3 slides)
   - 30/60/90-day plan
   - 6-12 month horizon
   - Timeline with milestones
   - Slide type: Timeline + Content

9. DATA STRATEGY (1-2 slides)
   - Current vs target architecture (diagram)
   - Data quality improvement plan
   - Compliance gap analysis (GDPR/POPIA/CCPA as applicable)
   - Slide type: Diagram + Content

10. GOVERNANCE & RISK (1 slide)
    - Current posture assessment
    - AI-specific risks identified
    - Recommended actions
    - Slide type: Content

11. CHANGE MANAGEMENT (1-2 slides)
    - Stakeholder map
    - Training requirements
    - Communication plan
    - Slide type: Content

12. NEXT STEPS / CTA (1 slide)
    - Recommended engagement path
    - Timeline to start
    - Contact information
    - Slide type: CTA
```

---

## 3. Feedback Report (Monthly/Quarterly)

**When**: Regular progress update to client or stakeholders.
**Typical length**: 8-15 slides

### Content Structure

```
1. TITLE SLIDE
   - "{{Period}} Progress Report"
   - Client name
   - Date range

2. PERIOD SUMMARY (1 slide)
   - High-level status: On Track / At Risk / Blocked
   - Key metric: "X automations deployed" or "Y% efficiency gain"
   - Slide type: Bold Claim or Content

3. KEY METRICS / KPIs (2-3 slides)
   - Dashboard-style data visualization
   - Charts: trend lines, bar comparisons, gauges
   - Source: Supabase queries, n8n execution data
   - Slide type: Data

4. COMPLETED WORK (1-2 slides)
   - What was delivered this period
   - Linked to original scope
   - Slide type: Content (checklist style)

5. IN PROGRESS (1-2 slides)
   - Current work items and status
   - Expected completion dates
   - Slide type: Content or Timeline

6. BLOCKERS & RISKS (1 slide)
   - Active blockers and mitigation plans
   - Risks identified and owners
   - Slide type: Content (red/amber/green)

7. NEXT PERIOD PLAN (1-2 slides)
   - Priorities for next period
   - Dependencies and decisions needed
   - Slide type: Content

8. CTA / DISCUSSION ITEMS (1 slide)
   - Questions for the client
   - Decisions needed
   - Next meeting date
   - Slide type: CTA
```

---

## 4. Pitch Deck

**When**: Investor presentation, partner pitch, or stakeholder buy-in.
**Typical length**: 10-15 slides (tight, high-impact)

### Content Structure

```
1. HOOK (1 slide)
   - Provocative statement or compelling statistic
   - "{{Industry}} loses $X billion annually to {{problem}}"
   - Slide type: Title/Hook with Bold Claim

2. PROBLEM (1-2 slides)
   - The pain point in vivid detail
   - Who experiences it and how often
   - Slide type: Content or Split (pain vs aspiration)

3. SOLUTION (1-2 slides)
   - Your product/service in one sentence
   - How it works (simplified)
   - Diagram: Assembly Line or Fan-Out of the solution
   - Slide type: Content + Diagram

4. MARKET (1-2 slides)
   - TAM/SAM/SOM if applicable
   - Target customer profile
   - Market trends supporting timing
   - Slide type: Data + Content

5. TRACTION (1-2 slides)
   - Current metrics: revenue, users, deployments
   - Growth trajectory
   - Key milestones achieved
   - Slide type: Data (charts) + Bold Claim

6. BUSINESS MODEL (1 slide)
   - How you make money
   - Pricing structure
   - Unit economics
   - Slide type: Content or Data

7. COMPETITIVE ADVANTAGE (1-2 slides)
   - Why you vs alternatives
   - Moat / defensibility
   - Slide type: Split or Content

8. TEAM (1 slide)
   - Key team members + relevant experience
   - Advisors if applicable
   - Slide type: Content (photo + bio layout)

9. THE ASK (1 slide)
   - What you're asking for (investment, partnership, commitment)
   - What you'll do with it
   - Timeline
   - Slide type: CTA
```

---

## 5. Standard Operating Procedure (SOP)

**When**: Documenting a repeatable process for team execution.
**Typical length**: 8-20 slides (depends on process complexity)

### Content Structure

```
1. TITLE SLIDE
   - SOP title: "SOP: {{Process Name}}"
   - Version, effective date, owner
   - Department / team

2. PURPOSE & SCOPE (1 slide)
   - Why this SOP exists
   - What it covers and doesn't cover
   - Who should follow it
   - Slide type: Content

3. PREREQUISITES (1 slide)
   - Required access / credentials
   - Required tools
   - Required knowledge
   - Slide type: Content (checklist)

4. PROCESS OVERVIEW (1 slide)
   - High-level flow diagram
   - 5-8 major steps in sequence
   - Diagram: Assembly Line
   - Slide type: Diagram

5. STEP-BY-STEP INSTRUCTIONS (3-10 slides)
   - One slide per major step OR grouped logically
   - Each step: Action → Expected Result → Verification
   - Screenshots/diagrams where helpful
   - Slide type: Content

6. DECISION POINTS (1-2 slides)
   - Conditional logic: "If X, do Y"
   - Decision tree or flowchart
   - Diagram: Tree or Gap/Break
   - Slide type: Diagram + Content

7. EXCEPTIONS & TROUBLESHOOTING (1-2 slides)
   - Common issues and resolutions
   - Escalation paths
   - Slide type: Content (table format)

8. REVIEW & REVISION (1 slide)
   - Review schedule
   - Change log
   - Approval authority
   - Slide type: Content
```

---

## 6. Case Study

**When**: Showcasing a successful client engagement.
**Typical length**: 8-12 slides

### Content Structure

```
1. TITLE SLIDE
   - "Case Study: {{Client Name}}"
   - Industry tag
   - Hero metric: "40% reduction in dispatch time"

2. THE CHALLENGE (1-2 slides)
   - Client background
   - Specific problems faced
   - Quantified pain (time, cost, errors)
   - Slide type: Content + Bold Claim

3. THE APPROACH (2-3 slides)
   - Discovery / audit findings
   - Solution design rationale
   - Technology stack used
   - Diagram: Network or Assembly Line
   - Slide type: Content + Diagram

4. THE IMPLEMENTATION (1-2 slides)
   - Timeline and phases
   - Key milestones
   - Challenges overcome
   - Slide type: Timeline + Content

5. THE RESULTS (2-3 slides)
   - Before vs After comparison
   - Quantified outcomes (charts)
   - Client testimonial/quote
   - Slide type: Split + Data + Bold Claim

6. KEY LEARNINGS (1 slide)
   - What we learned
   - What we'd do differently
   - Replicable patterns
   - Slide type: Content

7. CTA (1 slide)
   - "Ready for similar results?"
   - Contact / next steps
   - Slide type: CTA
```

---

## 7. Executive Summary

**When**: Distilling a larger document into 1-5 slides for leadership.
**Typical length**: 3-5 slides (extremely tight)

### Content Structure

```
1. TITLE SLIDE
   - "Executive Summary: {{Topic}}"
   - Date, prepared by

2. SITUATION + KEY FINDINGS (1-2 slides)
   - Context in 2-3 sentences
   - Top 3-5 findings as bullet points
   - One hero metric (Bold Claim)
   - Slide type: Content + Bold Claim

3. RECOMMENDATIONS (1 slide)
   - Prioritized action items
   - Expected outcomes
   - Resource requirements
   - Slide type: Content

4. NEXT STEPS (1 slide)
   - Decisions needed
   - Timeline
   - Owner assignments
   - Slide type: CTA
```

---

## Archetype Selection Guidance

| Your Need | Archetype | Why |
|-----------|-----------|-----|
| Selling to a new client | Proposal | Structured persuasion |
| Delivering audit results | Audit Report | Comprehensive evidence-based |
| Monthly client update | Feedback Report | Status + metrics + plan |
| Seeking investment/buy-in | Pitch Deck | High-impact storytelling |
| Documenting a process | SOP | Step-by-step instruction |
| Proving past success | Case Study | Results-driven narrative |
| Quick leadership brief | Executive Summary | Tight, decision-focused |

---

*Reference Version: 1.0 — 7 Document Archetypes*