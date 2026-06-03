---
name: diagram
description: |
  Generate Excalidraw diagrams that argue visually. Produces .excalidraw JSON files
  with isomorphic visual patterns, evidence artifacts, and render-validated layouts.
  Detects topic from conversation context or explicit input. Supports 10 visual patterns,
  4 audience levels, and a mandatory self-critique render loop.
  Universal — works for any topic, project-aware when architecture docs exist.
version: 1.0
created: 2026-03-02
user-invocable: true
triggers:
  - /diagram
  - diagram this
  - visualize
  - create diagram
  - excalidraw
  - visual explanation
parameters:
  - name: topic
    type: string
    description: "The subject to diagram. Auto-detected from conversation if omitted."
  - name: type
    type: enum
    default: auto
    values: [auto, assembly_line, fan_out, convergence, tree, spiral, side_by_side, cloud, gap_break, network, timeline]
    description: "Visual pattern. 'auto' infers from topic structure using keyword matrix."
  - name: depth
    type: enum
    default: standard
    values: [simple, standard, comprehensive]
    description: "Simple=5-12 nodes (overview), Standard=8-15 nodes, Comprehensive=15-30+ nodes with evidence artifacts."
  - name: audience
    type: enum
    default: mixed
    values: [technical, business, mixed, layperson]
    description: "Controls terminology, evidence level, and jargon."
validated_on:
  - "Pipeline architecture (assembly_line) — data ingestion to dashboard"
  - "System integration map (network) — multi-service architecture"
  - "Business comparison (side_by_side) — manual vs automated operations"
  - "Generic software architecture — CI/CD pipeline"
  - "Conceptual mind map (tree) — project breakdown"
---

# Excalidraw Diagram Skill — Visual Arguing Engine

> **Philosophy:** Diagrams should ARGUE, not just DISPLAY. Each shape mirrors the concept it represents. A fan-out pattern for a hub that distributes to many targets *looks like distribution*. A convergence pattern for data aggregation *looks like merging*. If you remove all text and the structure still communicates the concept — that's **isomorphism**. This is what separates educational diagrams from slide deck filler.

---

## Core Quality Tests

Apply these three tests to every diagram before delivery:

1. **Isomorphism Test**: If you removed all text, would the structure alone communicate the concept?
2. **Education Test**: Could someone learn something concrete from this diagram, or does it just label boxes?
3. **Audience Test**: Would the target audience understand the visual flow without reading fine print?

If any test fails, redesign before generating JSON.

---

## Step 0: Depth Assessment (BEFORE ANYTHING ELSE)

| Depth | When to Use | Node Count | Evidence Artifacts | Token Budget |
|-------|-------------|-----------|-------------------|--------------|
| **Simple** | Mental models, pitch decks, overviews, "explain it in 30 seconds" | 5-12 | Optional | Single response |
| **Standard** | Working diagrams, team documentation, process maps | 8-15 | Recommended | Single response |
| **Comprehensive** | Pipelines, architectures, debugging, "teach me everything" | 15-30+ | **Mandatory** | Section-by-section |

**Rule**: Default to Standard. Only use Comprehensive when the user asks for deep technical detail or uses `--depth comprehensive`.

---

## Step 1: Visual Type Auto-Detection

When `--type auto` (default), score the topic text against these keyword patterns. Use the highest-scoring pattern. Tie-breaker: prefer assembly_line > tree > network.

| Topic Pattern | Pattern Name | Detection Signals | Spatial Arrangement |
|---|---|---|---|
| Sequential steps, pipeline, process | **Assembly Line** | "step", "then", "after", "flow", "pipeline", "process", "lifecycle", "→" | Left-to-right or top-to-bottom chain |
| Central hub radiating outward | **Fan-Out** | "sources", "triggers", "hub", "distributes", "broadcasts", "entry point" | Center element with radiating arrows |
| Multiple inputs merging to one | **Convergence** | "aggregation", "merge", "combine", "funnel", "synthesis", "collect" | Multiple elements feeding into one |
| Categories, taxonomy, breakdown | **Tree** | "components", "types of", "breakdown", "categories", "aspects", "taxonomy" | Parent-child branching with lines + text |
| Feedback loop, iterative cycle | **Spiral/Cycle** | "loop", "recurring", "iterative", "feedback", "cycle", "continuous" | Circular sequence, arrow returns to start |
| Options, before/after, trade-offs | **Side-by-Side** | "vs", "compare", "before/after", "trade-off", "option", "alternative" | Two parallel structures |
| Context, states, fuzzy boundaries | **Cloud** | "context", "state", "memory", "environment", "fuzzy", "ambient" | Overlapping ellipses, varied sizes |
| Phase transitions, handoffs | **Gap/Break** | "phase change", "boundary", "handoff", "before and after", "transition" | Visual whitespace/barrier between sections |
| System integrations, APIs | **Network** | "integrates", "API", "connects to", "service", "architecture", "system" | Multi-hub with bidirectional connections |
| Chronological milestones | **Timeline** | "phase 1/2", dates, "history", "evolution", "roadmap", "sprint", "quarter" | Horizontal/vertical line with marker dots |

**Fallback** (all scores = 0):
- Topic is a noun phrase → **Tree**
- Topic contains a verb → **Assembly Line**
- Default → **Tree**

Always present the recommendation to the user: *"Recommended pattern: **Assembly Line** (detected sequential pipeline). Override with `--type [pattern]` or press Enter to accept."*

---

## Step 2: Design BEFORE JSON (6 Pre-Generation Steps)

**NEVER jump straight to JSON.** Plan the layout first:

1. **Assess Depth** — Simple, Standard, or Comprehensive?
2. **Understand the Subject** — What does this concept DO? What relationships exist? What flows where?
3. **Map Concepts to Visual Patterns** — Which of the 10 patterns best matches each section?
4. **Ensure Variety** — Each major concept should use a DIFFERENT visual treatment (not uniform cards)
5. **Sketch the Flow** — Trace the reader's eye movement. Left-to-right? Top-to-bottom? Center-out?
6. **Plan Evidence Artifacts** — What real code, data, or names should appear? (Comprehensive only)

---

## Step 3: Visual Pattern Library

### Assembly Line (Input → Process → Output)
**When**: Data transformations, processing pipelines, conversion chains, step-by-step workflows.
**Layout**: Horizontal chain. Each stage is a rectangle. Arrows connect left-to-right. Stages separated by consistent spacing (~150px).
**Enhancements**: Add parallel branches above/below for enrichment steps. Use dashed arrows for optional paths. Color-code stages by pipeline section.

### Fan-Out (Central Hub → Multiple Targets)
**When**: Event sources, triggers, distribution hubs, routers, entry points.
**Layout**: Central element (ellipse or large rectangle) with 3-7 arrows radiating outward to targets arranged in a semicircle or full circle.
**Enhancements**: Vary arrow lengths to show priority. Use different target shapes to show different types.

### Convergence (Multiple Inputs → Single Output)
**When**: Data aggregation, funnel analysis, synthesis, batch control, merge operations.
**Layout**: Multiple source elements arranged in a row/arc, all with arrows pointing to a single target.
**Enhancements**: Label arrows with what each source contributes.

### Tree (Parent → Children with Lines, NOT Boxes)
**When**: Hierarchies, taxonomies, breakdowns, org charts, category exploration.
**Layout**: Lines and text, minimal boxes. Parent text at top, vertical lines to children, horizontal lines connecting siblings.
**Key Rule**: Use lines as structural elements. Text is free-floating next to line endpoints. This looks cleaner than nested boxes.

### Spiral/Cycle (A → B → C → A)
**When**: Feedback loops, iterative processes, CI/CD, monitoring cycles.
**Layout**: 3-6 elements arranged in a circular or rectangular loop. Final arrow curves back to the first element.
**Enhancements**: Mark the "trigger" point. Show what changes each iteration.

### Side-by-Side (Option A | Option B)
**When**: Comparisons, before/after, trade-offs, decision support.
**Layout**: Two parallel vertical columns separated by a gap or line. Matching elements at the same vertical position for easy comparison.
**Enhancements**: Use color to show advantage (green) vs disadvantage (red). Add a "verdict" element at the bottom.

### Cloud (Overlapping Ellipses)
**When**: Abstract states, context, memory, fuzzy boundaries, environment description.
**Layout**: 3-5 ellipses of varying sizes that overlap partially. Text inside or next to each ellipse.
**Enhancements**: Vary opacity to show strength. Overlap areas represent shared properties.

### Gap/Break (Visual Whitespace)
**When**: Phase changes, context resets, handoffs between teams/systems.
**Layout**: Two diagram sections with significant whitespace or a dashed line between them. A label in the gap explains the transition.

### Network (Multi-Hub with Connections)
**When**: System architectures, API integrations, service meshes, component interactions.
**Layout**: Multiple rectangles/ellipses with bidirectional arrows. No strict flow direction.
**Enhancements**: Group related components with frames. Label arrows with protocol/data type. Use line style (solid=sync, dashed=async).

### Timeline (Dots + Lines)
**When**: Chronological events, project phases, roadmaps, evolution.
**Layout**: Horizontal or vertical line with small marker ellipses (10-12px) at each milestone. Labels above/below alternating.
**Enhancements**: Color-code phases. Add branching for parallel tracks.

---

## Step 4: Shape Meaning Matrix

| Concept Type | Shape | Why |
|---|---|---|
| Labels, descriptions, details | **none** (free-floating text) | Typography creates hierarchy without visual noise |
| Section titles, annotations | **none** (free-floating text) | Font size/weight is enough |
| Timeline markers | small `ellipse` (10-12px) | Visual anchor point |
| Start, trigger, input | `ellipse` | Soft, origin-like |
| End, output, result | `ellipse` | Completion, destination |
| Decision, condition, branch | `diamond` | Classic decision symbol |
| Process, action, step | `rectangle` | Contained, bounded action |
| Abstract state, context | overlapping `ellipse` | Fuzzy, cloud-like |
| Hierarchy node | lines + text (no boxes) | Structure through lines, not containers |
| Code/data artifact | `rectangle` (dark fill) | Distinct from regular elements |

### Container Discipline

**Rule: <30% of text elements should be inside containers.** Add shapes only when they carry meaning.

| Use a Container When... | Use Free-Floating Text When... |
|---|---|
| It's the focal point of a section | It's a label or description |
| It needs visual grouping | It's supporting detail or metadata |
| Arrows need to connect TO it | It describes something nearby |
| The shape itself carries meaning | It's a title, subtitle, or annotation |
| It represents a distinct "thing" | Typography alone creates hierarchy |

### Size Hierarchy

| Element Size | Use For | Approximate Dimensions |
|---|---|---|
| **Hero** | Visual anchor, most important concept | 300×150 |
| **Primary** | Main elements, pipeline stages | 180×90 |
| **Secondary** | Supporting elements, sub-steps | 120×60 |
| **Small** | Markers, bullets, minor annotations | 60×40 or 10-12px (dots) |

---

## Step 5: Evidence Artifacts (Comprehensive Depth MUST Include)

Evidence artifacts make diagrams educational, not just decorative. For comprehensive/technical diagrams, include at least 2-3 of these:

### Code Snippets
```json
{
  "type": "rectangle",
  "backgroundColor": "#1e293b",
  "strokeColor": "#475569",
  "fillStyle": "solid"
}
```
Text inside uses syntax-colored font: function names in `#60a5fa`, strings in `#22c55e`, keywords in `#c084fc`.

### Data/JSON Examples
Same dark rectangle. Text in green (`#22c55e`). Show what actual data looks like at that pipeline stage.

### Real System Names
Use actual function names, table names, workflow names from your project. NEVER use placeholders like "Database" or "API Call".

### Sample Inputs
Show what a real message, request, or data record looks like. E.g., an API request, a user message, or a database record.

---

## Step 6: Multi-Zoom Architecture (Comprehensive Only)

For comprehensive diagrams, structure content at three zoom levels:

1. **Level 1 — Summary Flow** (top of diagram): Simplified 5-7 node overview showing the full pipeline
2. **Level 2 — Section Boundaries** (middle): Labeled rectangular regions grouping related components
3. **Level 3 — Detail Inside Sections** (within boundaries): Evidence artifacts, code, concrete examples

This gives readers both the big picture and the ability to zoom into details.

---

## Step 7: Multi-Section Spacing Formula

For diagrams with multiple vertical sections (common in comprehensive depth):

1. **Decide total canvas height** first: `section_count × 200px` is a good starting point
2. **Allocate Y-bands**: Divide evenly. Section 1 = y:0–200, Section 2 = y:200–400, etc.
3. **Place section header text** at the top of each band (free-floating, title color)
4. **Place elements within their band** — never let elements from section N overlap into section N+1
5. **Cross-section arrows** should be the ONLY things that span bands
6. **Sidebar panels** (reference boxes, legends): Place to the RIGHT of the main flow, spanning multiple bands. Keep x-offset consistent (e.g., all sidebars start at x:850).

**Rule**: If you have >4 sections, sketch the Y-band allocation in a comment before writing any JSON elements.

---

## Step 8: Large Diagram Strategy (>32K tokens)

If the diagram will exceed ~32,000 output tokens (typically >20 elements with evidence), build it **section by section**:

### Phase 1: Foundation
- Create the base `.excalidraw` file with `type`, `version`, `source`, `appState`, empty `elements`
- Add the first logical section (e.g., "Ingestion" for a pipeline)
- Write file to disk

### Phase 2: Incremental Sections
- Read existing file
- Add next section's elements with namespaced IDs (section 1: `100xxx`, section 2: `200xxx`)
- Use descriptive string IDs: `ingestion_trigger_rect`, `enrichment_arrow_fan`
- Add cross-section arrows connecting to previous section elements
- Write updated file

### Phase 3: Review & Validate
- Read entire JSON, verify cross-section arrow bindings are correct
- Run render-validate loop

**ID Naming Convention**:
- Shapes: `{section}_{concept}_{shape}` — e.g., `batch_control_rect`, `media_analysis_ellipse`
- Arrows: `{section}_arrow_{from}_{to}` — e.g., `enrich_arrow_media_to_classify`
- Text: `{section}_{concept}_text` — e.g., `persist_results_text`
- Seeds: Section 1 = `100000-199999`, Section 2 = `200000-299999`, etc.

---

## Step 8: Audience Adaptation

Adapt the SAME diagram structure for different audiences by changing labels and evidence:

| Audience | Label Style | Evidence | Example Label |
|---|---|---|---|
| **Technical** | System names, RPCs, tables | Code snippets, JSON, SQL | `save_record()` |
| **Business** | Outcomes, metrics, time savings | KPI numbers, before/after stats | "Event saved (< 2 min)" |
| **Mixed** | Balanced — system name + plain description | Selected evidence, annotated | "Save Record (save_record)" |
| **Layperson** | Analogies, plain language | Visual metaphors, no code | "Record what happened" |

---

## Step 9: Render-Validate Loop (MANDATORY)

**BLOCKER: You MUST complete at least one render-validate cycle BEFORE presenting or discussing the diagram with the user.** Delivering unrendered JSON is prohibited — you cannot judge a diagram from JSON alone.

1. **Render** — Run: `cd .claude/skills/diagram/references && python3 render_excalidraw.py <path-to-file.excalidraw>` (use `python3`, NOT `uv run python`)
2. **View** — Read the generated PNG to visually inspect
3. **Critique** — Check for:
   - Text clipped or overflowing containers
   - Text or shapes overlapping
   - Arrows crossing through elements (should route around)
   - Arrows landing on wrong elements
   - Labels floating ambiguously (not clear what they describe)
   - Uneven spacing between elements
   - Text too small to read
   - Overall composition lopsided or cramped
   - Color contrast issues (light text on light background)
4. **Fix** — Edit the JSON to address issues
5. **Re-render & Re-view** — Run the script again, read the new PNG
6. **Repeat** — Typically 2-4 iterations

**When to stop**: Diagram matches conceptual design, no text issues, arrows route cleanly, spacing is consistent, composition is balanced.

**If the render script is not set up** (first-time): Run setup commands from the references directory, then proceed.

---

## Anti-Patterns (What NOT to Do)

| Wrong | Why | Right |
|---|---|---|
| Uniform card grid | Everything looks equal importance | Vary patterns per concept |
| Everything in boxes | Visual noise, no hierarchy | <30% of text in containers |
| Skip render-validate | Can't judge diagram from JSON | ALWAYS render, ALWAYS critique |
| Generic placeholder text | No educational value | Real system names, real data |
| 20+ nodes, no sub-sections | Unreadable, overwhelming | Split into sections with Level 1 overview |
| Ambiguous pronouns in labels | "It processes this" is meaningless | "Router classifies by chat_id" |
| Python generator scripts | Harder to debug than direct JSON | Write JSON directly |
| One giant JSON response | Exceeds token limit | Section-by-section building |
| Same shape for everything | Loses semantic meaning | Match shape to concept type |
| Arrows without labels | Reader guesses what flows | Label with data type or action |
| Invented colors | Inconsistent, unprofessional | Use color-palette.md ONLY |
| `opacity` < 100 | Looks faded, unclear | Use color/size for hierarchy |
| Version numbers in element IDs | Fragile, breaks on refactor | Descriptive concept-based IDs |
| `containerId` on text elements | Text silently fails to render when parent shape dimensions are too small | **Always use free-floating positional text** — place text at the same x,y as the shape center, never bind via containerId |
| Delivering diagram before rendering | User sees broken/messy output, erodes trust | **BLOCKER**: Complete render-validate loop before presenting to user |

---

## Quality Checklist

### Depth & Evidence
- [ ] Depth level assessed and matches user intent
- [ ] Evidence artifacts included (Comprehensive: mandatory, Standard: recommended, Simple: optional)
- [ ] Real system names used (not placeholders) when project context is available
- [ ] Sample inputs/data shown for technical diagrams

### Conceptual Design
- [ ] Visual pattern matches the concept's behavior (isomorphism test)
- [ ] Multiple visual patterns used across sections (no uniform treatment)
- [ ] Eye flow is clear (reader knows where to start and how to follow)
- [ ] Hierarchy communicated through size, position, and color

### Container Discipline
- [ ] <30% of text elements are inside containers
- [ ] Every container carries semantic meaning (not just "holding text")
- [ ] Free-floating text used for labels, descriptions, annotations

### Structural
- [ ] Node count matches depth level (Simple: 5-12, Standard: 8-15, Comprehensive: 15-30+)
- [ ] Large diagrams built section-by-section
- [ ] Cross-section arrows properly bound
- [ ] Descriptive element IDs used

### Technical (JSON)
- [ ] **No `containerId`** on any text element — use free-floating positional text only
- [ ] `text` property contains only readable words (no JSON, no escaped chars)
- [ ] `fontFamily: 3` (monospace) for all text
- [ ] `roughness: 0` (clean lines) for all elements
- [ ] `opacity: 100` for all elements
- [ ] Arrow bindings are bidirectional (arrow refs shape AND shape refs arrow)
- [ ] All colors from `color-palette.md`
- [ ] Seeds namespaced by section

### Visual Validation
- [ ] Rendered to PNG at least once
- [ ] No text clipping or overflow
- [ ] No overlapping elements
- [ ] No arrows crossing through shapes
- [ ] Spacing is consistent and balanced
- [ ] Composition is visually balanced (not lopsided)
- [ ] Passes all three core quality tests (isomorphism, education, audience)

---

## Context Research Protocol

When the topic references a known system, read project files to get accurate names:

| Topic References | Where to Look (max 2 files) |
|---|---|
| Project-specific system or pipeline | Architecture docs, README, or CLAUDE.md references |
| API or database schema | Schema files, migration history, or type definitions |
| Workflow or automation | Workflow documentation, orchestrator configs |
| Dashboard or reporting | KPI definitions, view/RPC reference docs |
| Generic/non-project topic | Skip research, use general knowledge |

**Customize this table** for your project by mapping topic keywords to specific architecture files.

**Never read more than 2 files.** Extract: component names, RPC names, table names, data flow direction, decision points.

---

## Output Location & Viewer Instructions

Generated diagrams are written to: `diagrams/{topic-slug}.excalidraw`

Create the `diagrams/` directory in the project root if it doesn't exist. Use kebab-case for filenames: `updates-pipeline.excalidraw`, `fuel-lifecycle.excalidraw`, `manual-vs-automated.excalidraw`.

### Post-Generation (MANDATORY)

After writing the `.excalidraw` file, **always** print viewer instructions for the user:

> **To view your diagram:**
>
> **VS Code / Cursor** (with `pomdtr.excalidraw-editor`): Right-click the editor tab → **"Reopen Editor With..."** → **"Excalidraw Editor"**. To make permanent: Cmd+Shift+P → "Configure Default Editor for '*.excalidraw'" → Excalidraw Editor.
>
> **Browser**: Open excalidraw.com → menu (☰) → Open → select the file.
>
> **Obsidian** (with Excalidraw plugin): Copy/move file into vault — renders natively.

The `.excalidraw` JSON format is universally compatible across all three environments. No conversion needed.

---

*Skill Version: 1.2 — Excalidraw Visual Arguing Engine. Adapted from coleam00/excalidraw-diagram-skill with visual type auto-detection, audience adaptation, and project-aware context research.*
