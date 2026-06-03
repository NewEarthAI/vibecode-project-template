---
description: |
  Generate Excalidraw diagrams that argue visually. Produces .excalidraw JSON files
  with isomorphic visual patterns, evidence artifacts, and render-validated layouts.
  Works from conversation context or explicit topic.
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
  - Agent
---

# /diagram Command

Generate publication-quality Excalidraw diagrams that **argue visually** — shapes mirror concepts, evidence artifacts show real data, and a render-validate loop ensures clean layouts.

**Invokes**: `.claude/skills/diagram/SKILL.md`

## What Happens

1. **Topic Detection** — From your arguments, conversation context, or asks you
2. **Pattern Recommendation** — Auto-detects best visual pattern (assembly line, fan-out, etc.)
3. **Context Research** — Reads project architecture docs if topic is project-specific
4. **JSON Generation** — Builds Excalidraw JSON with proper shapes, arrows, colors, evidence
5. **Render-Validate Loop** — Screenshots the diagram, critiques it, fixes layout issues (2-4 iterations)
6. **Delivery** — Provides `.excalidraw` file ready for excalidraw.com or Obsidian

## Arguments

| Argument | Values | Default | Example |
|----------|--------|---------|---------|
| `[topic]` | Any string | Auto-detect from conversation | `/diagram the updates pipeline` |
| `--type` | `auto`, `assembly_line`, `fan_out`, `convergence`, `tree`, `spiral`, `side_by_side`, `cloud`, `gap_break`, `network`, `timeline` | `auto` | `--type fan_out` |
| `--depth` | `simple`, `standard`, `comprehensive` | `standard` | `--depth comprehensive` |
| `--audience` | `technical`, `business`, `mixed`, `layperson` | `mixed` | `--audience business` |

## Usage Examples

```
/diagram                                              # Auto-detect from conversation
/diagram the updates pipeline                         # Explicit topic, auto everything else
/diagram fuel lifecycle --type assembly_line           # Force assembly line pattern
/diagram idle nudge system --depth comprehensive      # Deep technical detail with evidence
/diagram manual vs automated --type side_by_side --audience layperson
/diagram system architecture --type network --audience business
```

## Instructions

You are an expert visual communicator. Your goal is to **argue visually** by creating an educational Excalidraw diagram. Follow these phases exactly:

### Phase 1: Topic & Depth Assessment

1. **Determine the topic:**
   - If arguments provided after `/diagram`: use that topic
   - If no arguments but conversation has a clear subject: detect from last 10-20 messages, confirm with user: *"I'll diagram: [detected topic]. Proceed?"*
   - If no arguments and no clear context: ask *"What would you like to diagram? Examples: a pipeline, a system architecture, a comparison, a process flow..."*

2. **Assess depth** (from `--depth` flag or infer):
   - **Simple**: Overview, pitch deck, quick explanation (5-12 nodes)
   - **Standard**: Working diagram, documentation (8-15 nodes)
   - **Comprehensive**: Full technical detail with evidence artifacts (15-30+ nodes)

3. **Check project relevance**: Does the topic reference a known system? Flag for Phase 3 research.

### Phase 2: Pre-Generation Strategy

1. **Read the SKILL.md** at `.claude/skills/diagram/SKILL.md` — load the full methodology
2. **Auto-detect visual pattern** using the keyword matrix in SKILL.md Step 1
3. **Present recommendation**: *"Recommended pattern: **Assembly Line** (detected sequential pipeline). Override with `--type [pattern]` or confirm."*
4. **If `--type` was specified**: use that pattern, no need to confirm
5. **If Comprehensive depth**: plan which sections to build and estimate section count
6. **Apply the 6 pre-generation design steps** from SKILL.md Step 2 — understand, map, ensure variety, sketch flow, plan evidence

### Phase 3: Context Research (If Project-Specific)

1. **Check the Context Research Protocol** in SKILL.md
2. **Read at most 2 relevant files** to extract real system names, RPCs, tables, data flows
3. **For generic topics**: skip this phase entirely
4. **Extract**: component names, decision points, data flow direction, real API/RPC names

### Phase 4: Iterative JSON Generation

1. **Read reference files**:
   - `.claude/skills/diagram/references/color-palette.md` — for ALL colors
   - `.claude/skills/diagram/references/element-templates.md` — for JSON element structure
   - `.claude/skills/diagram/references/json-schema.md` — for format validation

2. **Create output directory** if needed: `mkdir -p diagrams/`

3. **Generate the Excalidraw JSON**:
   - Start with the root structure: `type`, `version`, `source`, `appState`, `elements`, `files`
   - Apply the selected visual pattern from SKILL.md Step 3
   - Follow the Shape Meaning Matrix (Step 4) — use the RIGHT shape for each concept
   - Follow Container Discipline — <30% of text in containers
   - Apply colors from `color-palette.md` ONLY
   - Use descriptive element IDs: `{section}_{concept}_{shape}`
   - For Comprehensive: build section-by-section per SKILL.md Step 7

4. **Write to file**: `diagrams/{topic-slug}.excalidraw`

### Phase 5: Render-Validate Loop (MANDATORY — DO NOT SKIP)

1. **Check if render pipeline is set up**:
   ```bash
   cd .claude/skills/diagram/references && ls render_excalidraw.py pyproject.toml
   ```
   If first time, run: `uv sync && uv run playwright install chromium`

2. **Render the diagram**:
   ```bash
   cd .claude/skills/diagram/references && uv run python render_excalidraw.py ../../../../diagrams/{topic-slug}.excalidraw
   ```

3. **Read the PNG** to visually inspect the output

4. **Critique against checklist** (from SKILL.md Step 9):
   - Text clipping or overflow?
   - Overlapping elements?
   - Arrows crossing through shapes?
   - Labels floating ambiguously?
   - Uneven spacing?
   - Composition lopsided?

5. **Fix any issues** by editing the JSON

6. **Re-render and re-inspect** — repeat until clean (typically 2-4 iterations)

7. **If render pipeline unavailable** (e.g., no Python/Playwright): note it in output, still deliver the JSON file. The user can open it in excalidraw.com to visually validate themselves.

### Phase 6: Delivery

Present the result:

```
## Diagram Generated

**File**: `diagrams/{topic-slug}.excalidraw`
**Pattern**: {pattern_name}
**Depth**: {depth} ({node_count} elements)
**Audience**: {audience}

**How to view:**
- Drag & drop into [excalidraw.com](https://excalidraw.com) (free, instant)
- Or open with Obsidian Excalidraw plugin

**Want adjustments?** I can:
- Add more detail to a specific section
- Change the audience level
- Add evidence artifacts (code snippets, JSON examples)
- Adjust spacing or layout
```

## Related Commands

- `/agentresearch` — Deep research before diagramming complex topics
- `/prime` — Prime agent with full codebase context before comprehensive diagrams

---

*Command Version: 1.0 — Excalidraw Visual Arguing Engine*
