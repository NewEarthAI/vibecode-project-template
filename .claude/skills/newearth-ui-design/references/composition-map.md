# Composition Map — How This Skill Plays With Others

> **Rule**: this skill is the *house style* layer. It does not replace `frontend-design` (creative direction), `guided-tour` (onboarding infrastructure), or `shadcn-ui` (primitives). It composes with them. Know the boundaries.

---

## Skill Stack (Bottom Up)

```
┌─────────────────────────────────────────────────────────┐
│  newearth-ui-design    ← THIS SKILL                     │
│  House style: tokens, hover curve, silver signature,    │
│  color discipline, anti-vibe-coded rules                │
├─────────────────────────────────────────────────────────┤
│  guided-tour           ← composes with                  │
│  driver.js tours, SOP guides, info tooltips             │
├─────────────────────────────────────────────────────────┤
│  frontend-design       ← composes with (plugin)         │
│  Bold aesthetic direction, anti-AI-generic rules        │
├─────────────────────────────────────────────────────────┤
│  shadcn-ui             ← sits on top of                 │
│  Radix primitives: Sheet, Dialog, Select, etc.          │
├─────────────────────────────────────────────────────────┤
│  Tailwind CSS          ← sits on top of                 │
│  Utility classes and token system                       │
└─────────────────────────────────────────────────────────┘
```

---

## Composition 1 — With `guided-tour` Skill

### What guided-tour owns

- **driver.js integration**: tour registry, step definitions, tour player
- **Tour button**: the "Take a Tour" floating/header button
- **Info tooltips**: ambient hover help
- **SOP page guides**: collapsible reference cards
- **Z-index 10000 (overlay) and 10001 (popover)** — do not touch
- **`backdrop-filter` on the tour overlay** — do not imitate

### What this skill contributes

- **Tour button styling**: brand color (`{{primary_color}}`), DM Sans type, hairline radius
- **Info tooltip styling**: neutral background, JetBrains Mono for any data values inside
- **SOP card styling**: uses the Card recipe with optional silver edge for premium SOP panels
- **Focus ring for tour navigation**: silver, not brand color
- **Drawer depth boundary**: tours should target Level 0 and Level 1 sections only. Level 2 (inline reveal) and Level 3 (deep-dive) are operator-initiated, not guided. See [progressive-disclosure.md](progressive-disclosure.md).

### Shared parameters

Both skills use the same parameters — theming one themes both automatically:

| Parameter | Consumed by |
|-----------|------------|
| `primary_color` | guided-tour tour button + newearth-ui primary button variant |
| `primary_color_foreground` | newearth-ui button text on primary |
| `font_family` | guided-tour tooltip copy + newearth-ui body text — **same parameter name in both skills for theming alignment** |
| `font_family_mono` | newearth-ui-only — for numeric data, IDs, code. guided-tour does not need a mono font, so this parameter is exclusive to newearth-ui-design. |

### Integration rules

1. **Never set `backdrop-filter` anywhere in your app** — conflicts with tour overlay rendering
2. **Never use z-index ≥ 1000** except the tour layers — reserve for guided-tour
3. **When building a dashboard header**, include `data-tour-header-btn` on the tour button so guided-tour can detect visibility
4. **Import order matters**: import guided-tour's CSS (`src/styles/GuidedTourStyles.css`) AFTER `tokens.css` so the tour button picks up the brand color override

### Correct header pattern

```tsx
// The tour button gets primary color via tokens.css CSS variables.
// This composes with guided-tour without either skill overriding the other.
<header className="border-b border-[var(--ne-border-hairline)] bg-[var(--ne-bg-subtle)] px-6 py-4">
  <div className="flex items-center justify-between">
    <h1 className="text-2xl font-semibold">Fleet Dashboard</h1>
    <Button
      variant="primary"
      data-tour-header-btn
      onClick={() => driver.start()}
    >
      Take a Tour
    </Button>
  </div>
</header>
```

---

## Composition 2 — With `frontend-design` Plugin Skill

### What frontend-design owns

- **Bold aesthetic direction**: picking tones (minimalist, brutalist, editorial, luxury, etc.)
- **Anti-AI-generic rules**: rejecting Inter, purple gradients, generic layouts
- **Creative composition**: asymmetry, layered transparencies, decorative borders, custom cursors
- **Framework-agnostic**: works across React, Vue, plain HTML/CSS

### What this skill adds

- **House style precision**: the exact hexes, the locked hover curve, the silver signature
- **Domain specificity**: cards, drawers, KPIs, tables, forms — the dashboard component vocabulary
- **Enforcement**: scripts that actually check conformance, not just principles
- **React/Tailwind/shadcn-ui specificity**: opinionated about the stack

### When each skill leads

| Task | Primary skill |
|------|---------------|
| Marketing landing page, hero section, illustration-forward surface | `frontend-design` (creative direction) |
| Internal dashboard, data-dense interface, CRUD app | `newearth-ui-design` (house style) |
| Client proposal site, branded microsite | Both — frontend-design for composition, newearth-ui-design for token precision |
| Component library for a new client | Both — frontend-design for initial tone, newearth-ui-design for system lockdown |

### Overlap resolution

If the two skills give conflicting guidance:
- **Token-level conflicts** (color, spacing, shadow) → this skill wins (we have locked values)
- **Composition-level conflicts** (layout, motion language, hero treatment) → frontend-design wins (it's the creative layer)
- **Anti-pattern conflicts** → whichever is more restrictive wins (both reject generic AI aesthetics, so alignment is natural)

### Inherit anti-patterns by reference

Do not duplicate the `frontend-design` banned list. Instead, in [anti-vibe-coded.md](anti-vibe-coded.md), reference it:

> *"See `frontend-design` plugin skill for the general AI-cliche ban list (purple gradients, generic Inter, cookie-cutter hero layouts). This file adds the NewEarth-specific hard rules on top."*

---

## Composition 3 — With `shadcn-ui`

### What shadcn-ui provides

- Radix UI primitive wrappers (Sheet, Dialog, Popover, Select, Tooltip, etc.)
- Base component structure (Button, Card, Badge, Input with `cva` variants)
- Accessibility out of the box
- TypeScript types

### What this skill does

- **Re-skins** the shadcn-ui base components with NewEarth tokens
- **Replaces** some components entirely (our Card has premium variant, shadcn-ui Card does not)
- **Augments** others (we add `interactive` prop, silver edge, hover ring to Card)
- **Keeps** Radix primitives unchanged (Sheet's behavior, Dialog's focus trap, etc.)

### When to edit vs replace

| shadcn-ui component | Action | Why |
|---------------------|--------|-----|
| `Button` | Replace variants | Our primary/secondary/ghost system differs |
| `Card` | Replace | We add `interactive`, `premium` props and signature hover |
| `Badge` | Replace variants | Our semantic variant set is locked |
| `Sheet` | Keep, wrap in our `Drawer` recipe | Radix behavior is good, we just theme the inside |
| `Dialog` | Keep, apply token theming | |
| `Input` | Replace | Our focus ring is silver, not brand |
| `Select` | Keep, apply token theming | |
| `Tooltip` | Keep | Used by info tooltips in guided-tour |
| `Command` (cmdk) | Keep, apply token theming | |

### Edit pattern

```tsx
// src/components/ui/card.tsx — replaced per this skill's Card recipe
// src/components/ui/button.tsx — replaced per this skill's Button recipe
// src/components/ui/sheet.tsx — kept as-is, theming happens in consumer Drawer wrapper
```

### Never do

- **Never install shadcn-ui themes** (stone, zinc, slate, etc.) — they override our neutrals with cool grays
- **Never run `shadcn init` with default options** — it picks Inter and stone gray, both banned
- **Never use shadcn-ui's `bg-background` / `bg-foreground` tokens directly** — use `--ne-bg-base` / `--ne-fg-primary` so future refinements propagate

---

## Composition 4 — With Client Brand Guidelines

Every NewEarth project inherits from the house style but parameterizes one thing: the **primary brand color**.

### What the client controls

| Token | Required from client |
|-------|---------------------|
| `{{primary_color}}` | Brand primary (e.g., `#06B6D4` for cyan, `#EA580C` for orange) |
| `{{primary_color_foreground}}` | Text on primary — usually `#FFFFFF` or `#0A0A0B` depending on primary luminance |
| Optional: licensed brand typeface | Replaces DM Sans if the client has a premium font they own (e.g., Söhne, GT America) |

### What the client does NOT control

- Neutral palette (always NewEarth warm off-white stack)
- Silver signature (always NewEarth silver)
- Semantic colors (always the four locked values)
- Hover curve (always 300ms, always `translate-y-0.5`)
- Radius scale (always caps at `rounded-xl`)
- Shadow scale (always two-layer grayscale)

**Why**: these are what make every NewEarth project recognizably NewEarth. They are the *signature*. If they varied per client, the agency would have no house style — just a collection of disconnected projects.

### Client brand color contrast check

When a client provides a brand color, verify WCAG AA contrast against `primary_color_foreground`:

```bash
# Manual check — plug into https://webaim.org/resources/contrastchecker/
# primary: {{primary_color}}
# fg: {{primary_color_foreground}}
# Required: 4.5:1 for normal text, 3:1 for large text
```

If the brand color is low-contrast (e.g., a pastel yellow), use `#0A0A0B` foreground and document the decision. Never accept a brand color that produces a button unreadable by someone with low vision.

---

## Composition 5 — With Existing Projects (Adoption Path)

When applying this skill to an existing project that wasn't built with it:

### Phase 1 — Assessment (read-only)

```bash
# Run all three audit scripts
bash .claude/skills/newearth-ui-design/scripts/audit-forbidden-patterns.sh ./
bash .claude/skills/newearth-ui-design/scripts/audit-colors.sh ./
bash .claude/skills/newearth-ui-design/scripts/audit-hover-consistency.sh ./
```

Document violations. This is the "debt assessment".

### Phase 2 — Tokens

1. Copy `assets/tokens.css` into `src/styles/tokens.css`
2. Import in main `index.css` or `app.css`
3. Do NOT remove existing tokens yet — run in parallel until migration is complete

### Phase 3 — Base components

Replace in order:
1. `Button` — the most-used component, biggest visual impact
2. `Card` — establishes the hover curve and signature
3. `Badge` — cleans up status indicators
4. `Input` — fixes the focus ring
5. Custom `Drawer` wrapper around `Sheet`

### Phase 4 — Page-by-page refactor

Work through pages. For each:
1. Replace colored card backgrounds with neutral
2. Remove emoji
3. Remove backdrop-blur
4. Replace `rounded-2xl+` with `rounded-xl`
5. Apply hover curve to interactive cards
6. Apply silver edge to hero KPIs

### Phase 5 — Verification

Re-run the three audit scripts. Target: zero violations. Any remaining violations must be documented with justification (e.g., "user-generated content view — emoji exempt").

---

## Skill Invocation Patterns

### Fresh new project

```
User: "Set up a new client project called Acme Logistics with brand color #EA580C"
  → newearth-ui-design handles tokens, components, layout
  → guided-tour handles onboarding infrastructure
  → both share the primary_color parameter
```

### Existing project review

```
User: "Audit my dashboard for design quality"
  → newearth-ui-design runs the three audit scripts
  → Reports violations with file:line
  → Suggests fixes using the recipe patterns
```

### New component on existing project

```
User: "Add a revenue KPI card to the dashboard"
  → newearth-ui-design applies Recipe 2 (KPI Hero Card)
  → Uses locked tokens from design-tokens.md
  → Applies variance indicator with semantic color only if justified
```

### Theming for new client

```
User: "Create theme tokens for this client — brand is teal #14B8A6"
  → newearth-ui-design copies assets/tokens.css
  → Substitutes {{primary_color}} and {{primary_color_foreground}}
  → Verifies contrast against foreground
  → Does NOT touch neutrals, silver, or semantic palette
```

---

*This skill sits at the top of the stack. It inherits bold direction from frontend-design, infrastructure from guided-tour, and primitives from shadcn-ui — and locks them all together with NewEarth house style.*
