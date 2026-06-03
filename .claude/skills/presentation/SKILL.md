---
name: presentation
description: |
  Generate professional presentations, proposals, reports, and documents in HTML (broadcast-quality
  single-file) or PPTX (corporate Slide Master-linked) formats. Handles AI audit reports, client
  proposals, feedback reports, SOPs, case studies, pitch decks, and executive summaries. Pulls data
  from any source (Supabase, n8n, project files, web, conversation). Brand-aware with per-client
  theming. Integrates with diagram skill for visual assets.
version: 1.0
created: 2026-03-03
user-invocable: true
triggers:
  - /present
  - create presentation
  - make slides
  - build proposal
  - generate report
  - create SOP
  - case study
  - pitch deck
  - audit report
  - feedback report
  - executive summary
parameters:
  - name: format
    type: enum
    default: html
    values: [html, pptx, both]
    description: "Output format. HTML = broadcast-quality single-file. PPTX = corporate Slide Master-linked."
  - name: archetype
    type: enum
    default: auto
    values: [auto, proposal, audit-report, feedback-report, pitch-deck, sop, case-study, executive-summary, custom]
    description: "Document archetype. 'auto' infers from context. Each has a predefined content structure."
  - name: brand
    type: string
    default: auto
    description: "Brand config slug. Loads from presentations/brands/{slug}.json or uses built-in."
  - name: audience
    type: enum
    default: business
    values: [technical, business, executive, mixed]
    description: "Controls language, data depth, and visual density."
  - name: theme
    type: enum
    default: dark
    values: [dark, light, branded]
    description: "Visual theme. Dark = broadcast quality. Light = print-friendly. Branded = from brand config."
validated_on:
  - "AI Maturity Audit report for logistics client"
  - "Client proposal for process automation engagement"
  - "SOP for n8n workflow maintenance"
  - "Pitch deck for investor presentation"
  - "Monthly feedback report with Supabase KPI data"
---

# Presentation Skill — Professional Document Engine

> **Philosophy:** Presentations should be structurally sound, not visually fragile. Every element
> links to a master layout. Every chart links to real data. Every brand color lives in the theme,
> not hardcoded per-slide. Back-end integrity enables front-end beauty.

---

## Dual-Track Architecture

| Track | Technology | Output | Best For |
|-------|-----------|--------|----------|
| **HTML** | Single-file HTML (embedded CSS/JS) | `.html` | Digital delivery, broadcast, web, email |
| **PPTX** | PptxGenJS (Node.js) | `.pptx` | Corporate, editable, PowerPoint/Keynote/Slides |

Both tracks share: content structure, brand system, data ingestion, and diagram integration.

---

## Step 0: Archetype Detection (BEFORE ANYTHING ELSE)

If `--archetype auto`, detect from context:

| Signal | Archetype | Content Structure |
|--------|-----------|-------------------|
| "proposal", "scope", "pricing", "engagement" | **Proposal** | Problem → Solution → Scope → Timeline → Investment |
| "audit", "maturity", "assessment", "scoring" | **Audit Report** | Exec Summary → Methodology → Domains → Opportunities → ROI → Roadmap |
| "feedback", "progress", "monthly", "status" | **Feedback Report** | Period Summary → KPIs → Completed → In Progress → Blockers → Next Steps |
| "pitch", "investor", "funding", "deck" | **Pitch Deck** | Hook → Problem → Solution → Market → Traction → Team → Ask |
| "SOP", "procedure", "how to", "standard" | **SOP** | Purpose → Scope → Steps → Decision Points → Exceptions → Review |
| "case study", "success", "results" | **Case Study** | Challenge → Approach → Implementation → Results → Testimonial |
| "summary", "executive", "brief" | **Executive Summary** | Context → Key Findings → Recommendations → Next Steps |

Present the detection: *"Detected archetype: **Proposal**. Override with `--archetype [type]` or confirm."*

---

## Step 1: Content Planning (MANDATORY — Never Skip)

### 1a. Source Material Gathering

Before generating any slides, gather ALL source material:

1. **Conversation context** — What has the user discussed? Extract key points.
2. **Project files** — Read relevant ROADMAP.md, PROFILE.yaml, CONTEXT.md files
3. **Live data** — If KPIs/metrics needed, query Supabase or read dashboards
4. **Brand config** — Load brand from `presentations/brands/{slug}.json` or use defaults
5. **Diagrams** — Identify slides that need visual diagrams (invoke diagram skill)

**Data ingestion protocol**: Read `references/data-ingestion.md` for source-specific patterns.

### 1b. Slide Outline

Map content to slides. **One major point per slide.** Present the outline:

```
Slide 1: [Hook/Title] — {one-sentence description}
Slide 2: [Problem/Context] — {one-sentence description}
...
Slide N: [CTA/Next Steps] — {one-sentence description}
```

### 1c. Slide Type Classification

Classify each slide into a visual archetype:

| Slide Type | Visual Treatment | When to Use |
|------------|-----------------|-------------|
| **Title/Hook** | Full-bleed background, large typography, brand mark | Opening, section breaks |
| **Bold Claim** | Single large quote or statistic, accent color | Key statistics, testimonials |
| **Content** | Heading + 3-5 bullet points or short paragraphs | Information delivery |
| **Split/Comparison** | Two-column layout with visual divider | Before/after, pros/cons |
| **Data/Chart** | Chart or table with supporting context | KPIs, financials, scoring |
| **Diagram** | Embedded visual diagram (from diagram skill) | Architecture, flows, processes |
| **Image** | Full or half-bleed image with overlay text | Impact moments, brand |
| **Timeline** | Horizontal/vertical milestone markers | Roadmaps, project phases |
| **CTA** | Clear action item, contact info, next steps | Closing |

---

## Step 2: Brand System

### Load Brand Configuration

Check for brand config in this order:
1. `presentations/brands/{slug}.json` — Custom brand file
2. Built-in defaults ({{Your Brand}} brand)

**Read `references/brand-system.md`** for the full brand configuration schema.

### Default Brand

```json
{
  "name": "{{Your Brand}}",
  "colors": {
    "primary": "#0F172A",
    "secondary": "#1E293B",
    "accent": "#3B82F6",
    "accent2": "#10B981",
    "text": "#F8FAFC",
    "textMuted": "#94A3B8",
    "danger": "#EF4444",
    "warning": "#F59E0B",
    "success": "#22C55E"
  },
  "typography": {
    "heading": "'Inter', 'Segoe UI', sans-serif",
    "body": "'Inter', 'Segoe UI', sans-serif",
    "mono": "'JetBrains Mono', 'Fira Code', monospace"
  },
  "logo": null
}
```

---

## Step 3: Generate Output

### Track Decision

| Condition | Track |
|-----------|-------|
| `--format html` or digital delivery | HTML Track |
| `--format pptx` or editable/corporate | PPTX Track |
| `--format both` | Generate both |
| No flag, audience is executive | PPTX Track |
| No flag, audience is technical | HTML Track |
| No flag, default | HTML Track |

### HTML Track

**Read `references/html-engine.md`** for the complete HTML generation guide.

Key requirements:
- Single-file HTML (ALL CSS/JS embedded, images as base64 or CSS)
- Keyboard navigation (Left/Right arrows)
- Slide counter (X/Y top-right)
- Chapter sidebar (collapsible left nav)
- Dark mode default, light mode via toggle
- Responsive scaling (vw/vh units)
- CSS transitions (300-500ms, cubic-bezier easing)
- Print-friendly via `@media print`
- Fullscreen API support (F key)

### PPTX Track

**Read `references/pptx-engine.md`** for the complete PPTX generation guide.

Key requirements:
- PptxGenJS library via Node.js script
- Content linked to Slide Master layouts (NEVER loose shapes)
- Theme-linked colors and fonts (not hardcoded RGB)
- Charts linked to embedded data (not static images)
- Speaker notes on every slide
- 16:9 aspect ratio default

---

## Step 4: Diagram Integration

When a slide needs a visual diagram:

1. **Identify diagram need** — Architecture slides, process flows, comparisons
2. **Invoke diagram skill** — Use `/diagram` with appropriate `--type` and `--audience`
3. **Render to image** — Use the diagram skill's render pipeline to get PNG
4. **Embed in presentation**:
   - HTML: Inline as base64 `<img>` or SVG
   - PPTX: Add as image via PptxGenJS `slide.addImage()`

### Auto-Diagram Detection

| Slide Content | Diagram Type | Diagram Skill Args |
|--------------|-------------|-------------------|
| Pipeline/workflow steps | Assembly Line | `--type assembly_line` |
| System architecture | Network | `--type network` |
| Before vs After | Side by Side | `--type side_by_side` |
| Project timeline | Timeline | `--type timeline` |
| Data aggregation | Convergence | `--type convergence` |
| Decision tree | Tree | `--type tree` |

---

## Step 5: Data Integration

For slides requiring live data (KPIs, metrics, charts):

**Read `references/data-ingestion.md`** for source-specific protocols.

Quick reference:

| Source | Method | Use When |
|--------|--------|----------|
| **Supabase** | MCP `execute_sql` | Dashboard KPIs, client data, audit scores |
| **n8n** | MCP workflow/execution data | Automation metrics, workflow status |
| **Project files** | Read tool | Roadmaps, specs, context docs |
| **Airtable** | MCP | Legacy data, CRM records |
| **Web** | WebFetch/WebSearch | External data, market research |
| **Conversation** | Context extraction | User-provided information |
| **Chrome/Playwright** | Screenshot tools | Dashboard captures, visual evidence |

---

## Step 6: Output & Delivery

### File Output

```
presentations/
├── brands/                    # Brand configurations
│   └── {slug}.json
├── {archetype}-{topic-slug}/  # Per-presentation folder
│   ├── presentation.html      # HTML output
│   ├── presentation.pptx      # PPTX output
│   ├── assets/                # Embedded diagrams, images
│   └── data/                  # Source data (xlsx, csv)
```

Create `presentations/` directory if it doesn't exist.

### Delivery Message

```
## Presentation Generated

**File**: `presentations/{folder}/presentation.{ext}`
**Format**: {HTML/PPTX/Both}
**Archetype**: {archetype_name}
**Slides**: {count}
**Brand**: {brand_name}
**Audience**: {audience}

**How to use:**
- HTML: Open in any browser. Arrow keys to navigate. F for fullscreen.
- PPTX: Open in PowerPoint, Keynote, or Google Slides. Fully editable.

**Diagrams included**: {count} (generated via diagram skill)
**Data sources**: {list of sources used}

**Want adjustments?** I can:
- Change the brand/theme
- Add or remove slides
- Update data from a different source
- Change audience level
- Export to the other format
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Loose shapes on blank PPTX slides | Not theme-aware, breaks Design Ideas | Link to Slide Master layouts |
| Hardcoded RGB colors per slide | Can't rebrand globally | Theme-linked accent colors |
| Static screenshot charts | Can't update data | Linked data or regenerated charts |
| Wall of text slides | Audience loses focus | One point per slide, max 5 bullets |
| Skip content planning | Incoherent narrative | Always outline before generating |
| Generic placeholder logos | Looks unprofessional | Verify asset exists, CSS fallback if not |
| External CSS/JS dependencies | HTML not portable | Everything embedded in single file |
| Same visual treatment every slide | Monotonous | Vary slide types per content |
| Tiny fonts for "more content" | Unreadable at distance | Larger font, fewer words |
| Skip brand loading | Inconsistent look | Always load brand config first |

---

## Quality Checklist

### Content
- [ ] Archetype detected and confirmed
- [ ] Source material gathered from all relevant sources
- [ ] Slide outline presented and approved
- [ ] One major point per slide
- [ ] Speaker notes on every slide (PPTX)

### Visual
- [ ] Brand colors applied from config (not hardcoded)
- [ ] Typography from brand system
- [ ] Slide types varied (not all "content" slides)
- [ ] Charts/data visualizations where data exists
- [ ] Diagrams generated for architecture/flow slides

### Technical (HTML)
- [ ] Single-file, no external dependencies
- [ ] Keyboard navigation works (arrows, F, Esc)
- [ ] Slide counter visible
- [ ] CSS transitions smooth (300-500ms)
- [ ] Responsive at common resolutions

### Technical (PPTX)
- [ ] PptxGenJS generates valid .pptx
- [ ] Content linked to Slide Master layouts
- [ ] Theme-linked colors and fonts
- [ ] 16:9 aspect ratio
- [ ] Opens correctly in PowerPoint/Keynote/Slides

### Data Integrity
- [ ] All data sourced and attributed
- [ ] Numbers verified against source
- [ ] Charts reflect actual data (not fabricated)
- [ ] Date/period context clear

---

*Skill Version: 1.0 — Professional Document Engine. Dual-track HTML/PPTX with brand system, data integration, and diagram skill interop.*
