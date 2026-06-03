# Excalidraw Color Palette — Single Source of Truth

All diagram colors MUST come from this file. Do not invent new colors.

## Shape Colors (Semantic Purpose)

| Semantic Purpose | Fill | Stroke | When to Use |
|---|---|---|---|
| **Primary/Neutral** | `#3b82f6` | `#1e3a5f` | Main pipeline stages, primary components |
| **Secondary** | `#60a5fa` | `#1e3a5f` | Supporting components, sub-steps |
| **Tertiary** | `#93c5fd` | `#1e3a5f` | Background elements, minor annotations |
| **Start/Trigger** | `#fed7aa` | `#c2410c` | Entry points, triggers, inputs (warm orange) |
| **End/Success** | `#a7f3d0` | `#047857` | Completion, outputs, success states (green) |
| **Warning/Reset** | `#fee2e2` | `#dc2626` | Errors, warnings, breaks, failures (red) |
| **Decision** | `#fef3c7` | `#b45309` | Decision diamonds, conditionals (amber) |
| **AI/LLM** | `#ddd6fe` | `#6d28d9` | AI classification, LLM calls, ML processing (purple) |
| **Inactive/Disabled** | `#dbeafe` | `#1e40af` | Disabled paths, optional steps (use dashed stroke) |
| **Error** | `#fecaca` | `#b91c1c` | Error states, failure paths (strong red) |

## Text Colors (Hierarchy)

| Level | Color | Use For |
|---|---|---|
| **Title** | `#1e40af` | Section headings, major labels, diagram title |
| **Subtitle** | `#3b82f6` | Subheadings, secondary labels |
| **Body/Detail** | `#64748b` | Descriptions, annotations, metadata, supporting text |
| **On light fills** | `#374151` | Text inside light-colored shapes |
| **On dark fills** | `#ffffff` | Text inside dark-colored shapes (evidence artifacts) |

## Evidence Artifact Colors

| Artifact Type | Background | Text Color | Stroke |
|---|---|---|---|
| **Code snippet** | `#1e293b` | Syntax-colored (see below) | `#475569` |
| **Data/JSON example** | `#1e293b` | `#22c55e` (green) | `#475569` |
| **API/RPC name** | `transparent` | `#6d28d9` (purple) | none |

### Syntax Coloring (Inside Code Artifacts)

| Element | Color |
|---|---|
| Function names | `#60a5fa` (blue) |
| Strings | `#22c55e` (green) |
| Keywords | `#c084fc` (purple) |
| Numbers | `#f97316` (orange) |
| Comments | `#64748b` (gray) |

## Rules

1. **Always pair darker stroke with lighter fill** for contrast
2. **Never use colors outside this palette** — consistency is non-negotiable
3. **Semantic meaning is mandatory** — don't use "Decision" amber for a non-decision element
4. **Evidence artifacts always use dark backgrounds** (`#1e293b`) for visual distinction
5. **Background color**: `#ffffff` (white canvas) — set in `appState.viewBackgroundColor`

---

*Single source of truth for all diagram colors. Update here to change everywhere.*
