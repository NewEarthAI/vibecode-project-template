# Color Systems — Per Preset

> Each preset defines a complete color system: background, foreground, accent, and surface tokens.
> Colors are defined as CSS custom properties for Tailwind integration.

## Token Structure

| Token | Purpose |
|-------|---------|
| `--bg-primary` | Main page background |
| `--bg-surface` | Card/section backgrounds |
| `--fg-primary` | Main text color |
| `--fg-secondary` | Muted/supporting text |
| `--accent` | Primary accent (CTAs, highlights) |
| `--accent-hover` | Accent interaction state |
| `--border` | Subtle borders, dividers |

## Preset Color Systems

### A — "Organic Tech"
```css
--bg-primary: #0a0f0d;      /* Deep forest black */
--bg-surface: #131a16;      /* Slightly lifted */
--fg-primary: #e8f0eb;      /* Soft green-white */
--fg-secondary: #7a9485;    /* Muted sage */
--accent: #22c55e;          /* Living green */
--accent-hover: #16a34a;
--border: #1e2d24;
```
**Mode**: Dark | **Noise overlay**: Yes

### B — "Midnight Luxe"
```css
--bg-primary: #09090b;      /* True black */
--bg-surface: #18181b;      /* Zinc-900 */
--fg-primary: #fafafa;      /* Near-white */
--fg-secondary: #a1a1aa;    /* Zinc-400 */
--accent: #c084fc;          /* Soft violet */
--accent-hover: #a855f7;
--border: #27272a;
```
**Mode**: Dark | **Noise overlay**: Yes

### C — "Brutalist Signal"
```css
--bg-primary: #fafaf9;      /* Stone-50 */
--bg-surface: #f5f5f4;      /* Stone-100 */
--fg-primary: #0c0a09;      /* Stone-950 */
--fg-secondary: #44403c;    /* Stone-700 */
--accent: #dc2626;          /* Signal red */
--accent-hover: #b91c1c;
--border: #0c0a09;          /* Heavy black borders */
```
**Mode**: Light | **Noise overlay**: No

### D — "Vapor Clinic"
```css
--bg-primary: #0f0b1e;      /* Deep indigo-black */
--bg-surface: #1a1433;      /* Purple-tinted dark */
--fg-primary: #e0dff5;      /* Lavender white */
--fg-secondary: #8b85b1;    /* Muted purple */
--accent: #818cf8;          /* Indigo-400 */
--accent-hover: #6366f1;
--border: #2e2654;
```
**Mode**: Dark | **Noise overlay**: Yes

### E — "Warm Harbor"
```css
--bg-primary: #fef7ed;      /* Warm cream */
--bg-surface: #ffffff;      /* Clean white */
--fg-primary: #422006;      /* Deep brown */
--fg-secondary: #92400e;    /* Amber-800 */
--accent: #ea580c;          /* Warm orange */
--accent-hover: #c2410c;
--border: #fed7aa;          /* Soft peach */
```
**Mode**: Light | **Noise overlay**: No

### F — "Clinical Precision"
```css
--bg-primary: #ffffff;      /* Pure white */
--bg-surface: #f8fafc;      /* Slate-50 */
--fg-primary: #0f172a;      /* Slate-900 */
--fg-secondary: #64748b;    /* Slate-500 */
--accent: #0ea5e9;          /* Sky-500 */
--accent-hover: #0284c7;
--border: #e2e8f0;          /* Slate-200 */
```
**Mode**: Light | **Noise overlay**: No

### G — "Playful Kinetic"
```css
--bg-primary: #fefce8;      /* Yellow-50 */
--bg-surface: #ffffff;
--fg-primary: #1e1b4b;      /* Indigo-950 */
--fg-secondary: #4338ca;    /* Indigo-700 */
--accent: #f43f5e;          /* Rose-500 */
--accent-hover: #e11d48;
--border: #c7d2fe;          /* Indigo-200 */
```
**Mode**: Light | **Noise overlay**: No

### H — "Editorial Noir"
```css
--bg-primary: #0c0c0c;      /* Near-black */
--bg-surface: #1a1a1a;
--fg-primary: #f5f5f5;      /* Near-white */
--fg-secondary: #737373;    /* Neutral-500 */
--accent: #f5f5f5;          /* White IS the accent */
--accent-hover: #d4d4d4;
--border: #262626;
```
**Mode**: Dark | **Noise overlay**: Yes (subtle film grain)

## Tailwind v4 Integration

Tailwind v4 uses CSS-native `@theme` blocks — no `tailwind.config.js` needed.

```css
/* In index.css, after @import "tailwindcss" and :root tokens */
@theme {
  --font-display: "Fraunces", serif;
  --font-body: "Nunito", sans-serif;
  --color-bg-primary: var(--bg-primary);
  --color-bg-surface: var(--bg-surface);
  --color-fg-primary: var(--fg-primary);
  --color-fg-secondary: var(--fg-secondary);
  --color-accent: var(--accent);
  --color-accent-hover: var(--accent-hover);
  --color-border: var(--border);
}
```

This registers `bg-bg-primary`, `text-fg-primary`, `text-accent`, `border-border`, etc.
as Tailwind utility classes. Font utilities: `font-display`, `font-body`.

## Custom Brief Color Selection

When user provides a custom brand description:
1. Determine light/dark mode from context (outdoor/warm/friendly = light; tech/luxury/dark = dark)
2. Extract brand colors if provided; otherwise select from closest preset
3. Ensure WCAG AA contrast ratio (4.5:1 for body text, 3:1 for large text)
4. Accent color should be the single most distinctive element — never use more than one accent
