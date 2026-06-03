---
description: |
  Generate professional presentations, proposals, reports, and documents.
  Supports HTML (broadcast-quality) and PPTX (corporate) output formats.
  Pulls data from any source. Brand-aware with per-client theming.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - TodoWrite
  - WebSearch
  - WebFetch
  - Agent
---

# /present Command

Generate professional-grade presentations, proposals, reports, SOPs, case studies, and more.

**Invokes**: `.claude/skills/presentation/SKILL.md`

## What Happens

1. **Archetype Detection** — Auto-detects document type (proposal, audit report, pitch deck, etc.)
2. **Source Material Gathering** — Pulls from Supabase, n8n, project files, conversation, web
3. **Content Planning** — Outlines slides, maps content to slide types
4. **Brand Loading** — Applies client-specific or default brand theme
5. **Generation** — Produces HTML and/or PPTX output
6. **Diagram Integration** — Generates Excalidraw diagrams for visual slides
7. **Delivery** — Saves to `presentations/` directory

## Arguments

| Argument | Values | Default | Example |
|----------|--------|---------|---------|
| `[topic]` | Any string | Auto-detect from conversation | `/present Nirvana Freight Q1 report` |
| `--format` | `html`, `pptx`, `both` | `html` | `--format pptx` |
| `--archetype` | `auto`, `proposal`, `audit-report`, `feedback-report`, `pitch-deck`, `sop`, `case-study`, `executive-summary`, `custom` | `auto` | `--archetype proposal` |
| `--brand` | Brand slug | `newearth-ai` | `--brand nirvana-freight` |
| `--audience` | `technical`, `business`, `executive`, `mixed` | `business` | `--audience executive` |
| `--theme` | `dark`, `light`, `branded` | `dark` | `--theme light` |

## Usage Examples

```
/present                                              # Auto-detect from conversation
/present AI Maturity Audit for Nirvana Freight        # Specific topic, auto archetype
/present --archetype proposal --brand nirvana-freight  # Client proposal with brand
/present --format pptx --audience executive            # PPTX for executives
/present --archetype sop Fleet Dispatch Process        # SOP document
/present --format both --archetype pitch-deck          # Both formats, pitch deck
```

## Instructions

You are a professional presentation architect. Follow these phases exactly:

### Phase 1: Requirements Gathering

1. **Determine the topic:**
   - If arguments provided: use that topic
   - If conversation has a clear subject: detect and confirm
   - If unclear: ask *"What would you like to present? Examples: a client proposal, audit results, monthly report, SOP, pitch deck..."*

2. **Detect archetype** using the signal table in SKILL.md Step 0

3. **Confirm with user:**
   *"I'll create a **{{archetype}}** about {{topic}}.*
   *Format: {{format}} | Brand: {{brand}} | Audience: {{audience}}*
   *Proceed?"*

### Phase 2: Content Planning

1. **Read SKILL.md** at `.claude/skills/presentation/SKILL.md`
2. **Read the archetype template** at `.claude/skills/presentation/references/document-archetypes.md`
3. **Gather source material** following `.claude/skills/presentation/references/data-ingestion.md`
4. **Load brand config** following `.claude/skills/presentation/references/brand-system.md`
5. **Create slide outline** — Present to user for approval before generating

### Phase 3: Generation

1. **Read design principles** at `.claude/skills/presentation/references/design-principles.md`
2. **For HTML track**: Read `.claude/skills/presentation/references/html-engine.md`
   - Use `.claude/skills/presentation/templates/base-presentation.html` as the structural reference
   - Generate single-file HTML with all CSS/JS embedded
3. **For PPTX track**: Read `.claude/skills/presentation/references/pptx-engine.md`
   - Create config JSON for the generator script
   - Run: `node .claude/skills/presentation/scripts/generate_pptx.mjs --config <config> --output <output>`

### Phase 4: Diagram Integration

For slides needing visual diagrams:
1. Identify which slides need diagrams
2. Use `/diagram` skill with appropriate `--type` and `--audience`
3. Embed rendered diagrams into the presentation

### Phase 5: Delivery

1. Save output to `presentations/{archetype}-{topic-slug}/`
2. Present the delivery summary from SKILL.md Step 6
3. Offer adjustment options

## Related Commands

- `/diagram` — Generate standalone Excalidraw diagrams
- `/agentresearch` — Deep research before creating data-heavy presentations
- `/prime` — Prime agent with codebase context for project-specific presentations

---

*Command Version: 1.0 — Professional Document Engine*
