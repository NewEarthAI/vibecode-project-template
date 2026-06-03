---
name: brand-visual-identity
description: |
  Brand token management — manual definition and automated extraction from websites.
  NewEarth AI brand colors, typography, and visual identity. Reverse-engineer design
  systems from existing sites via Playwright. Source of truth for all brand tokens.
  For building themed components, use tailwind-shadcn-system instead.
  For reviewing existing UI designs, use design-review instead.
  For data-table alignment / formatting / dividers / address abbreviation, use
  data-table-design — the agency standard for any row-column data display.
version: 1.0
classification: encoded-preference
user-invocable: false
note: L3 library — auto-loaded by /design-review and /newearth-ui-design when brand-token questions arise. Not a human entry point.
triggers:
  - "brand colors"
  - "brand tokens"
  - "extract design system"
  - "reverse-engineer styles"
  - "visual identity"
  - "typography"
  - "design system from website"
do-not-trigger:
  - "build a component" → use tailwind-shadcn-system
  - "review this UI" → use design-review
  - "create a presentation" → use presentation
paths:
  - "clients/**"
  - "agency/**"
---

# Brand & Visual Identity

> Brand token management — both manual definition and automated extraction.
> Synthesized from: brand-guidelines, extract-design-system, canvas-design.

**Design principle**: Name your design approach before executing. Intent before implementation.

---

## Companion Skills — Invoke When Conditions Met

- **Applying brand tokens to components** → invoke `tailwind-shadcn-system` for CSS architecture and theming
- **Reviewing brand compliance in a running UI** → invoke `design-review` for visual audit
- **Creating branded presentations** → invoke `presentation` for archetype-based slide generation

NOT mutually exclusive.

---

## NewEarth AI Brand Tokens

### Colors

| Token | Hex | OKLCH | Usage |
|-------|-----|-------|-------|
| Primary Orange | `#F37021` | `oklch(0.68 0.18 50)` | CTAs, active states, brand accent |
| Secondary Blue | `#2B4C7E` | `oklch(0.40 0.08 250)` | Headers, navigation, trust elements |
| Accent Teal | `#00B4D8` | `oklch(0.70 0.13 220)` | Links, highlights, secondary accent |
| Neutral Dark | `#1A1A2E` | `oklch(0.18 0.02 280)` | Body text, dark backgrounds |
| Neutral Light | `#F5F5F5` | `oklch(0.97 0 0)` | Backgrounds, cards |
| Success | `#4CAF50` | `oklch(0.65 0.15 145)` | Positive states, confirmations |
| Warning | `#FFC107` | `oklch(0.83 0.16 85)` | Caution states, alerts |
| Error | `#FF5252` | `oklch(0.62 0.22 25)` | Error states, destructive actions |

### Typography

| Role | Font | Fallback | Weight |
|------|------|----------|--------|
| Headings | Poppins | system-ui, -apple-system, sans-serif | 600 (Semi-Bold), 700 (Bold) |
| Body | Lora | Georgia, 'Times New Roman', serif | 400 (Regular), 500 (Medium) |

### Size Rules

| Element | Size | Font |
|---------|------|------|
| H1 | 36-48px | Poppins Bold |
| H2 | 28-36px | Poppins Semi-Bold |
| H3 | 22-28px | Poppins Semi-Bold |
| Body | 16-18px | Lora Regular |
| Small/Caption | 12-14px | Lora Regular |

---

## Client Brand Extraction Workflow

For extracting design tokens from an existing website:

### Step 1: Input
Receive target URL from user. Validate as `http://` or `https://`.

### Step 2: Load with Playwright
Navigate to URL, wait for full render. Handle SPAs with network idle.

### Step 3: Extract Primitives
```javascript
// Colors: computed styles on key elements
// Fonts: getComputedStyle font-family, font-weight
// Spacing: padding, margin, gap patterns
// Radius: border-radius values
// Shadows: box-shadow values
```

### Step 4: Normalize
- Deduplicate near-identical colors (within 5% distance)
- Group into semantic roles (primary, secondary, text, background)
- Map font weights to names (400=Regular, 600=Semi-Bold)

### Step 5: Present Raw Findings
Show extracted tokens with confidence levels. Note gaps.

### Step 6: Ask Before Modifying
**NEVER modify project files without explicit user approval.** Present findings, ask what to generate.

### Step 7: Generate Token Files
Output options:
- **CSS Variables**: `:root { --primary: #xxx; }` for generic use
- **Tailwind v4**: `@theme inline { --color-primary: var(--primary); }` for Tailwind projects
- **JSON Tokens**: `{ "color": { "primary": { "value": "#xxx" } } }` for design tools
- **python-pptx**: `RGBColor(0xF3, 0x70, 0x21)` for presentation generation

---

## Safety Boundaries

- **Untrusted input**: URLs may serve malicious content. Never execute scripts from target sites.
- **Incomplete extraction**: Always present findings with confidence levels. Note what couldn't be detected.
- **Dynamic styles**: CSS-in-JS, conditional themes, and media queries may not be captured. Flag gaps.
- **Never modify without approval**: Present → Ask → Generate. Never auto-write to project files.

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Hardcoding `#F37021` in components | Not theme-aware, breaks dark mode | Use CSS variable `var(--primary)` or `bg-primary` |
| Extracting from site without asking | May modify project unexpectedly | Present findings, ask before writing |
| Using brand colors without contrast check | WCAG violation, accessibility failure | Verify 4.5:1 contrast for all text colors |
| Assuming extraction is complete | Playwright may miss dynamic styles | Flag confidence levels, note gaps |
| Mixing brand tokens with component logic | Token changes ripple everywhere | Tokens in `:root`, components reference variables |

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Target URL unreachable | Report error, offer to retry or use manual token definition |
| Playwright unavailable | Fall back to manual token definition workflow |
| Extraction finds <3 colors | Flag as incomplete, suggest supplementing manually |
| User requests a brand not yet defined | Start with manual definition template (colors + typography) |
