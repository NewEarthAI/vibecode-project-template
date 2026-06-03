---
name: tailwind-shadcn-system
description: |
  Build UIs with Tailwind CSS v4 + shadcn/ui. Theming architecture, component composition rules,
  v3→v4 migration, WCAG accessibility, OKLCH color tokens, React Hook Form + Zod validation.
  For design review/audit of running sites, use design-review instead.
  For brand token management, use brand-visual-identity instead.
version: 1.0
classification: capability-uplift
user-invocable: true
triggers:
  - "build a component"
  - "set up theming"
  - "Tailwind v4"
  - "shadcn"
  - "design tokens"
  - "dark mode"
  - "form validation"
  - "migrate from v3"
do-not-trigger:
  - "review this UI" → use design-review
  - "brand colors" → use brand-visual-identity
  - "build a dashboard" → use build-dashboard
  - "build a landing page" → use landing-page-mvp
paths:
  - "clients/**/*.tsx"
  - "clients/**/*.jsx"
  - "**/*.css"
---

# Tailwind v4 + shadcn/ui Component System

> Unified component system guide. Synthesized from: shadcn-ui-official, shadcn-ui-patterns, tailwind-design-system, tailwind-theme-builder.

---

## Companion Skills — Invoke When Conditions Met

- **Reviewing/auditing a running UI** → invoke `design-review` for priority-weighted assessment
- **Need brand color tokens** → invoke `brand-visual-identity` for NewEarth AI palette or client extraction
- **Building a landing page** → invoke `landing-page-mvp` for GSAP presets and conversion formulas
- **Building a dashboard** → invoke `build-dashboard` for Chart.js patterns and data tables

NOT mutually exclusive — invoke all that match.

---

## 1. Four-Step CSS Architecture

Mandatory ordering in `src/index.css`:

```css
/* Step 1: Import Tailwind */
@import "tailwindcss";

/* Step 2: Define CSS Variables */
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0.064 285.885);
  --primary-foreground: oklch(0.985 0 0);
  /* ... every color needs a foreground pair */
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  /* ... dark mode overrides via variable switching */
}

/* Step 3: Map to @theme (Tailwind v4) */
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
}

/* Step 4: Use in components via utilities */
/* bg-primary, text-primary-foreground, etc. */
```

---

## 2. v3 → v4 Migration Reference

| v3 (Old) | v4 (New) | Notes |
|----------|----------|-------|
| `tailwind.config.js` | CSS-first `@theme` | No more JS config |
| `theme.extend.colors` | `@theme inline { --color-* }` | CSS variables native |
| `@apply` in CSS | Still works, prefer utilities | Unchanged |
| `darkMode: 'class'` | HTML `.dark` class + CSS vars | Variables switch automatically |
| PostCSS `@tailwind base` | `@import "tailwindcss"` | Single import |
| `tw-animate-css` | `@import "tw-animate-css"` | After tailwind import |

---

## 3. OKLCH Color Token System

Use OKLCH for perceptual uniformity — colors with the same lightness LOOK equally light:

```css
/* OKLCH format: oklch(lightness chroma hue) */
--primary: oklch(0.205 0.064 285.885);    /* Dark blue-purple */
--destructive: oklch(0.577 0.245 27.325);  /* Red, same visual weight */
```

Benefits: Predictable contrast ratios, better dark mode transitions, P3 gamut support.

---

## 4. shadcn/ui Composition Rules

### Mandatory Patterns
- **Items ALWAYS in Groups**: `<SelectGroup>`, `<DropdownMenuGroup>`, `<CommandGroup>`
- **Semantic colors**: `bg-primary` not `bg-blue-500`. `text-muted-foreground` not `text-gray-400`.
- **Class merging**: Always use `cn()` utility for conditional classes
- **Icon pattern**: Use `data-icon` attribute on icon wrappers

### Anti-Patterns (Never Do)

| Wrong | Why | Right |
|-------|-----|-------|
| `space-x-4` on flex containers | Breaks with conditional children | `gap-4` |
| `bg-blue-500` hardcoded | Not theme-aware, breaks dark mode | `bg-primary` |
| Manual `dark:bg-gray-900` overrides | Duplicates logic, breaks theming | CSS variables switch automatically |
| Items outside Groups | Breaks accessibility, keyboard nav | Always wrap in Group components |
| `className="..."` without `cn()` | Breaks class merging/overrides | `className={cn("base", props.className)}` |

---

## 5. Form Validation: React Hook Form + Zod

```tsx
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"

const schema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(50),
})

const form = useForm({
  resolver: zodResolver(schema),
  defaultValues: { email: "", name: "" },
})

// Use shadcn Form components:
// <Form>, <FormField>, <FormItem>, <FormLabel>, <FormControl>, <FormMessage>
```

---

## 6. WCAG Accessibility Standards

| Requirement | Threshold | Check |
|-------------|-----------|-------|
| Text contrast (normal) | 4.5:1 minimum | foreground vs background |
| Text contrast (large, ≥18px bold) | 3:1 minimum | foreground vs background |
| Touch/click targets | 44x44px minimum | buttons, links, inputs |
| Focus indicators | Visible on all interactive | `ring-*` utilities |
| Keyboard navigation | All interactive elements | Tab order, Enter/Space |

Every color must have a paired foreground color that meets contrast requirements.

---

## 7. Dark Mode

Dark mode via HTML `.dark` class + CSS variable switching:

```tsx
// Toggle dark mode
document.documentElement.classList.toggle('dark')

// In components — no dark: prefixes needed
// bg-background automatically switches via CSS variables
```

**Never use** manual `dark:` overrides when CSS variables handle it. Only use `dark:` for truly conditional styles that aren't covered by the theme system.

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| v3 project detected | Suggest migration, show v3→v4 table |
| Missing tw-animate-css | Show install command and import order |
| Colors not working | Check: @theme inline present? CSS vars defined? Import order correct? |
| Dark mode broken | Check: .dark class on html? CSS variable overrides in .dark selector? |
