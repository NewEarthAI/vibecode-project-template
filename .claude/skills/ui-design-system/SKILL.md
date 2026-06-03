---
name: ui-design-system
description: |
  the agency's house UI/UX design system for React/Vite/Tailwind dashboards and web apps.
  Use this skill when: building any user-facing interface, creating new components, reviewing
  existing UI for quality, adding cards/drawers/KPI displays/badges/buttons, theming a client
  project, auditing a codebase for design consistency, or when the user says "build the UI",
  "design this page", "make this look premium", "review the design", "audit the UI", or
  "does this look vibe-coded". Enforces the the agency signature: monochrome-first palette with
  strict semantic color discipline, warm off-white neutrals paired with cool silver metallic
  accents, DM Sans + JetBrains Mono typography, 300ms card hover curve with translate-y lift,
  rounded-xl maximum radius, hairline borders, two-layer shadows. Rejects AI-era cliches:
  rounded-2xl chunkiness, glassmorphism backdrop-blur, pastel status pills, decorative emoji,
  purple-on-white gradients, one-card-one-color decoration. Composes with frontend-design
  plugin for bold aesthetic direction and guided-tour skill for onboarding consistency.
version: 1.5
classification: encoded-preference
user-invocable: true
note: Human entry point for BUILDING in the the agency house style. Composes the L1/L2/L3 stack under the hood. Sibling entry point is /design-review (audit).
created: 2026-04-10
updated: 2026-04-26
validated_on:
  - Reverse-engineered from a logistics app fleet dashboard (React/Vite/Tailwind/shadcn-ui)
  - Hover curve + color discipline verified across 20+ components
  - Extended council unanimous approval 2026-04-10 (all 5 agents → Option C)
  - Progressive disclosure 4-level depth pattern captured 2026-04-10 (validated against Stripe, Linear, Vercel)
triggers:
  - "build the UI" / "design this page" / "make this look premium" / "premium feel"
  - "review the design" / "audit my UI" / "does this look vibe-coded"
  - "set up dark mode" / "theme setup" / "add dark mode toggle" / "dark mode toggle"
  - "build a card" / "build a KPI card" / "build a drawer" / "build a badge"
  - "apply the agency aesthetic" / "use house style" / "the agency design"
  - "refine semantic colors" / "adjust silver signature" / "silver hover"
  - "silver button" / "silvery button" / "brushed silver CTA" / "premium primary action"
  - "silver edge button" / "shimmery silver border button" / "silver ring button" / "gradient border button" / "metallic edge CTA"
  - "silver header" / "silvery header" / "silver bottom stripe" / "brand-anchor page header"
  - "Atelier Dark" / "editorial preset" / "premium proposal site"
  - "theme a new client project" / "set up tokens.css" / "scaffold design tokens"
  - "progressive disclosure" / "drill down" / "drawer depth" / "evidence reveal" / "multi-level drawer"
  - "show me more detail" / "expand this" / "deeper view"
  - "add back button" / "back to X" / "sticky header" / "collapsing header" / "page shell"
  - "header scrolls away" / "lose orientation on scroll" / "can't find back" / "fixed top bar"
  - "migrate page to PageShell" / "unified page scaffold"
do-not-trigger:
  - "build a generic Tailwind component without the agency context" → use tailwind-shadcn-system
  - "extract brand colors from an existing client website via Playwright" → use brand-visual-identity
  - "general UI review with priority-weighted accessibility rules (contrast ratios, touch targets, CLS)" → use design-review
  - "holistic website audit (SEO, legal, security, E-E-A-T)" → use audit-website
  - "creative bold aesthetic direction for a marketing hero page" → use frontend-design plugin
composition:
  - "guided-tour (shared primary_color, font_family)"
  - "frontend-design plugin (bold creative direction + house style tokens)"
  - "bulletproof-drawer-perimeter — invoke after building any drawer/modal with write surfaces"
  - "Replaces shadcn-ui Card/Badge/Button when installed"
parameters:
  - name: primary_color
    type: string
    default: "#6EF1D6"
    description: "Client brand primary — the only color that varies per project. Matches guided-tour skill parameter."
  - name: primary_color_foreground
    type: string
    default: "#0A0A0B"
    description: "Text color used on top of primary_color surfaces (buttons, active states)."
  - name: font_family
    type: string
    default: "'DM Sans', system-ui, -apple-system, sans-serif"
    description: "Primary sans typeface. Matches guided-tour skill parameter for cross-skill consistency."
  - name: font_family_mono
    type: string
    default: "'JetBrains Mono', ui-monospace, SFMono-Regular, monospace"
    description: "Monospace typeface for data, numbers, IDs, code. Separate from font_family so guided-tour (which only needs sans) remains compatible."
  - name: target_project_root
    type: string
    default: "."
    description: "Used by audit scripts to know which project to scan."
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# the agency UI/UX Design Skill

> **Philosophy**: Pre-AI-era craftsmanship. Premium by restraint. Color only where practically valuable. The user should feel they're using something built by a senior developer in 2019, not something vibe-coded in 2025.

## Mandatory Layer Contract — READ BEFORE GENERATING ANY OUTPUT

This skill is the **L3 house-tokens layer** of the the agency Design Suite v2 three-layer stack. It does NOT generate output in isolation. Before producing any code, mockup, audit, or recommendation, you MUST read the upstream contract files IN FULL:

1. **`PRODUCT.md`** at the repo root — the the agency identity contract (register, brand tokens, audience, tone).
2. **`DESIGN.md`** at the repo root — the visual system contract (colour palette, typography defaults + escalation paths, elevation, motion, variance ceilings per surface type).
3. **`.claude/skills/design-taste-frontend/SKILL.md`** — the **L2 anti-slop overlay** (DESIGN_VARIANCE / MOTION_INTENSITY / VISUAL_DENSITY dial baselines, ban-list of LLM defaults).

Application order is non-negotiable: **L1 register (`PRODUCT.md` + `DESIGN.md`) → L2 dial baseline (`design-taste-frontend`) → L3 house tokens (the principles section of this skill).**

**If ANY of those three files are missing, HALT immediately and surface this loud error to the operator — do NOT silently fall back to L3 alone:**

```
ERROR (ui-design-system): L1/L2 contract files missing.
Expected at repo root: PRODUCT.md, DESIGN.md
Expected skill:        .claude/skills/design-taste-frontend/SKILL.md

Phase 3 of the the agency Design Suite v2 build has not completed.
Refusing to generate output until all three contract files exist.

Reference: continuations/NEWEARTH-DESIGN-SUITE-V2-MASTER-CONTINUATION-2026-05-13.md §15 amendment A1.
```

This contract was codified by 8-agent extended council on 2026-05-13 (amendments A1 BLOCKING + reframe to 3-layer architecture). It supersedes the legacy `composition:` frontmatter field at the top of this file — that field stays as documentation but is NOT a load mechanism in the current Claude Code skill loader.

## When To Use This Skill

Activate when any of the following is happening:

- Building new React components (cards, drawers, tables, forms, KPI displays)
- Reviewing existing UI code for quality, consistency, or "does this look premium"
- Setting up a new client project's design tokens and Tailwind config
- Auditing a codebase for design debt or cliched AI-era patterns
- Choosing colors, spacing, shadows, or hover effects
- Integrating with the guided-tour skill (they share parameters by design)

## Core Principles

| Principle | How It Shows Up |
|-----------|-----------------|
| **Monochrome first** | Start every component in grayscale. Color is earned, not given. |
| **Semantic color only** | Every non-neutral color must map to one operational state (severity, confidence, variance, compliance). No decoration. |
| **Warm neutrals, cool silver** | Off-white cream base (`#FBFBFA`) with brushed-aluminium silver accents. Temperature contrast is the premium signal. |
| **Hairline borders** | 1px `#EAEAEA` or silver gradient. Never chunky. Never glowing. |
| **Precision radius scale** | Cap at `rounded-xl` (12px). `rounded-full` allowed for pills/avatars only. `rounded-2xl` and above are banned. |
| **Two-layer shadows (light) / inset highlights (dark)** | Depth through restraint, not blur or glow. |
| **300ms hover curve** | `transition-all duration-300 hover:shadow-lg hover:-translate-y-0.5` is the signature. Never deviate. |
| **Data typography** | JetBrains Mono for anything numeric. DM Sans for everything else. Tabular-nums on KPIs. |
| **Silver as signature** | the agency fingerprint — hairline metallic borders on premium cards + universal silver hover ring. |
| **Dark mode is required** | Every project ships with both light and dark modes from day one. No exceptions. Dark uses warm ink (`#0D0D0E`), brighter silver, inset highlights instead of drop shadows. See [references/dark-mode.md](references/dark-mode.md). |

## Theme Variants

The skill supports two distinct theme *systems*, each with light and dark modes:

| System | Light | Dark | When To Use |
|--------|-------|------|-------------|
| **Default (Monochrome Minimalist)** | Warm off-white + silver + semantic palette | Warm ink + bright silver + semantic palette | Every client operational dashboard. Daily drivers. Data-dense interfaces. |
| **Atelier Dark (Editorial Preset)** | Parchment reversal (light Atelier) | Ink + oxide + parchment + verdigris + bronze | Agency internal dashboards, client proposals, hero landing pages, premium product showcases. **Never** for long-session operational dashboards. See [references/atelier-dark-preset.md](references/atelier-dark-preset.md). |

**Default is always the safe choice.** Atelier Dark is opt-in and only appropriate for contexts where editorial personality serves the content better than efficiency.

## Composition With Other Skills

This skill **composes with**, never duplicates, two others:

| Skill | What It Owns | How We Compose |
|-------|--------------|----------------|
| `frontend-design` (plugin) | Bold aesthetic direction, anti-generic rules, creative composition | Reference for anti-AI-generic rules. Our skill is the *house style* layer; that skill is the *creative direction* layer. Both run together. |
| `guided-tour` (skill) | driver.js tour infrastructure, tour button, tooltips | Shares `primary_color`, `font_family` parameters. Our skill must respect z-index `10000/10001` (owned by guided-tour overlay/popover). Tour button uses our primary_color parameter for brand alignment. |

**Never**: override driver.js CSS from this skill. Never set `backdrop-filter` anywhere in the app (conflicts with guided-tour overlay rendering).

## Primary Workflow

### Mode 1: Building New UI

```
1. Read references/design-tokens.md   → get canonical values
2. Read references/component-recipes.md → get the right pattern for the component you're building
3. Use assets/component-templates/    → copy the starter, edit semantics only
4. Before writing color, check references/color-discipline.md → is this an approved semantic slot?
5. Run scripts/audit-forbidden-patterns.sh on the new file → catches rounded-2xl, backdrop-blur, emoji
```

### Mode 2: Reviewing Existing UI

```
1. Run scripts/audit-forbidden-patterns.sh {{target_project_root}}  → fails on any banned pattern
2. Run scripts/audit-colors.sh {{target_project_root}}              → flags unsemantic color usage
3. Run scripts/audit-hover-consistency.sh {{target_project_root}}   → checks card hover curve conformance
4. Read references/anti-vibe-coded.md → manually scan for soft violations (copy, icon choice, spacing feel)
5. Produce findings as markdown table with file:line references
```

### Mode 3: Theming A New Client Project

```
1. Collect from user: primary_color, primary_color_foreground, brand logo
2. Copy assets/tokens.css into project's src/styles/ or src/index.css
3. Replace {{primary_color}} and {{primary_color_foreground}} with client values
4. Do NOT change neutrals, semantic colors, or silver values — those are the agency house
5. Install DM Sans + JetBrains Mono via Google Fonts or fontsource
6. Run audit scripts to verify baseline compliance
```

## Reference Files (Progressive Disclosure)

| File | When To Load |
|------|-------------|
| [references/design-tokens.md](references/design-tokens.md) | Before writing any component — frozen values for colors, spacing, shadows, curves, type |
| [references/component-recipes.md](references/component-recipes.md) | When building Card, Drawer, Badge, Button, KPI, Table patterns |
| [references/color-discipline.md](references/color-discipline.md) | When tempted to add color — checks the semantic justification |
| [references/silver-signature.md](references/silver-signature.md) | When applying the the agency metallic accent system |
| [references/dark-mode.md](references/dark-mode.md) | When building dark mode surfaces or setting up the theme toggle — required for every project |
| [references/atelier-dark-preset.md](references/atelier-dark-preset.md) | When the project warrants the editorial preset (agency, proposals, hero pages) — opt-in only |
| [references/anti-vibe-coded.md](references/anti-vibe-coded.md) | During review — the NEVER list with concrete counter-examples |
| [references/progressive-disclosure.md](references/progressive-disclosure.md) | When designing data-dense drawers, drill-down flows, or evidence-reveal patterns |
| [references/page-shell.md](references/page-shell.md) | When building or migrating any page scaffold — unified back button, sticky collapsing app bar, always-visible primary actions. Replaces ad-hoc "Back to X" buttons and scroll-away headers. |
| [references/composition-map.md](references/composition-map.md) | When integrating with guided-tour, frontend-design plugin, or shadcn-ui base |

## Scripts (Automated Enforcement)

| Script | Purpose | Runs On |
|--------|---------|---------|
| [scripts/audit-forbidden-patterns.sh](scripts/audit-forbidden-patterns.sh) | Fails on `rounded-2xl+`, `backdrop-blur`, emoji, `bg-white/X`, `Inter`/`Roboto` in type stack | Any project root |
| [scripts/audit-colors.sh](scripts/audit-colors.sh) | Flags unsemantic color usage — every `bg-red-*` / `text-green-*` etc. must be near a state keyword | Any project root |
| [scripts/audit-hover-consistency.sh](scripts/audit-hover-consistency.sh) | Verifies Card components use the signature hover curve, not bespoke variants | Any project root |

## Assets (Drop-in Starters)

| Asset | Purpose |
|-------|---------|
| [assets/tokens.css](assets/tokens.css) | Complete CSS variable system — copy into project root stylesheet |
| [assets/component-templates/Card.tsx](assets/component-templates/Card.tsx) | Base card with signature hover curve + optional silver edge |
| [assets/component-templates/Drawer.tsx](assets/component-templates/Drawer.tsx) | Sheet-based drawer with section header pattern |
| [assets/component-templates/KpiCard.tsx](assets/component-templates/KpiCard.tsx) | Hero KPI with responsive `clamp()` typography and optional silver top edge |
| [assets/component-templates/Badge.tsx](assets/component-templates/Badge.tsx) | Status pill with semantic variant system (no pastel, no decorative icons) |
| [assets/component-templates/Button.tsx](assets/component-templates/Button.tsx) | Default brand-color button + three opt-in silver tiers: `variant="silver"` (Mode E — brushed fill, max 1/viewport), `variant="silverEdge"` (Mode G — 1px gradient ring on neutral fill, max 2/viewport, the static answer to "shimmery silver button"), `variant="silverOutline"` (solid silver line companion). All reserved for premium contexts (proposals, landing heroes, report covers, brand-anchor surfaces). See [references/silver-signature.md](references/silver-signature.md) Modes E, F, G. |
| [assets/component-templates/PageHeader.tsx](assets/component-templates/PageHeader.tsx) | Page-level header with eyebrow + title + subtitle + actions. Opt-in `variant="silver"` adds a 2px brushed silver bottom-edge stripe; opt-in `silverTitle` renders the title with a silver text gradient. Reserved for the project's brand-anchor page. See Mode F. |

## The Six Hard Rules (Cannot Be Overridden)

1. **No `rounded-2xl` or `rounded-3xl`** — anywhere, ever. Cap at `rounded-xl` (12px). Atelier Dark preset uses `2px` — tighter, never looser.
2. **No `backdrop-blur-*` on content surfaces** — kills glassmorphism at the root. Only allowed on guided-tour's overlay (owned by that skill).
3. **No emoji in technical docs, commit messages, UI copy, or component children.** Icons from lucide-react only, one-per-context, never decorative.
4. **No unsemantic color** — any `bg-red-*`, `bg-green-*`, `bg-amber-*`, `bg-blue-*` on a Card or container must map to a documented state (severity / confidence / variance / compliance). Audit script enforces.
5. **No `Inter` / `Roboto` / `Arial` / `system-ui` as primary typeface** — DM Sans is the the agency default. Client-specific overrides must be a licensed premium typeface, never a system font. Atelier Dark preset uses PP Editorial New + Söhne + Berkeley Mono (or their free equivalents).
6. **Dark mode ships with every project** — no project launches without both modes tested and working. Never `#000` for background, never `#FFF` for text. Use `#0D0D0E` and `#FAFAFA` respectively.

## Anti-Patterns (Summary — see anti-vibe-coded.md for full list)

| Wrong | Why | Right |
|-------|-----|-------|
| `rounded-2xl` on a Card | Chunky iOS consumer look, reads as cute not premium | `rounded-xl` maximum |
| `backdrop-blur-md bg-white/30` | Glassmorphism cliche, performance hit, accessibility risk | Flat `bg-card` with two-layer shadow |
| `bg-purple-500 bg-gradient-to-br from-purple-600 to-pink-500` | SaaS landing page cliche | Neutral surface + single semantic accent |
| One card per color (red/green/amber cards side-by-side with no state meaning) | Decoration, not information | Monochrome cards; color only on data inside |
| `<Badge className="bg-pink-100 text-pink-800">🎉 Active</Badge>` | Pastel + emoji + decorative | `<Badge variant="neutral">Active</Badge>` or semantic variant |
| `font-family: Inter, system-ui, sans-serif` | Default Tailwind font, zero signature | DM Sans |
| `transition-colors` only on hover | Flat, no depth | `transition-all duration-300 hover:shadow-lg hover:-translate-y-0.5` |

## Quality Checklist (Run Before Declaring Done)

```
□ No rounded-2xl or rounded-3xl anywhere
□ No backdrop-blur-* on content surfaces
□ No emoji in code or copy
□ All color usage maps to documented semantic state
□ Cards use the signature 300ms hover curve
□ Type stack is DM Sans + JetBrains Mono (or Atelier Dark triple stack)
□ Neutrals match locked values (#FBFBFA / #F7F6F3 / #EAEAEA / #E8E7E3)
□ Silver signature applied to premium cards and interactive hover states
□ Semantic colors match locked values (#B42318 / #B54708 / #067647 / #175CD3)
□ Primary brand color properly parameterized, not hardcoded
□ All three audit scripts pass
□ Composes cleanly with guided-tour (no z-index or backdrop-filter conflicts)

-- Dark mode checks (required) --
□ Dark mode works: toggle via .dark class on <html>
□ Dark neutrals use warm ink (#0D0D0E), never pure #000
□ Dark foreground is #FAFAFA, never pure #FFF
□ Dark silver is brighter (#E5E8ED / #C9CDD3 / #D4D7DC at 55% opacity)
□ Shadows in dark mode use inset highlights, not drop shadows
□ Every component tested in both light AND dark modes
□ Semantic badges readable in both modes (4.5:1 contrast)
□ Theme toggle component installed and persists to localStorage
□ Default is "system" (respects OS preference on first load)
```

---

*Skill version 1.0 — the agency house design system. Push to template via `/template-push` when validated.*
