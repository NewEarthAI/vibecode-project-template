# Dark Mode — Required For Every Project

> **Rule**: every NewEarth project ships with both light and dark modes. Dark mode is not an afterthought or a "stretch goal" — it is built from the start using the same token system, the same component recipes, and the same discipline rules. Users must be able to toggle at any time with zero visual degradation.

---

## Philosophy

Dark mode in this skill is the **direct translation** of the light monochrome aesthetic — not a different aesthetic. The rules stay identical:

- Monochrome first, color only where earned
- Hairline borders, precision radius, two-layer depth
- Silver signature as the NewEarth fingerprint
- 300ms hover curve
- DM Sans + JetBrains Mono type stack

What changes:
- Neutrals invert (warm off-white → warm ink)
- Silver brightens (must be visible against dark background)
- Semantic colors brighten slightly (low-luminance reds/greens/ambers disappear against dark)
- Shadows shift strategy — drop shadows become inset highlights (shadows don't read against dark surfaces)

---

## Dark Neutrals — Warm Ink Stack

The warm off-white in light mode (`#FBFBFA`) has a subtle cream undertone. The dark mode inversion is **warm ink**, not pure OLED black. Pure `#000` reads as "cheap OLED display"; warm ink reads as "premium publication".

| Token | Light Value | Dark Value | Usage |
|-------|------------|------------|-------|
| `--ne-bg-base` | `#FBFBFA` | `#0D0D0E` | Page background, card base (warm ink, not pure black) |
| `--ne-bg-subtle` | `#F7F6F3` | `#151517` | Section headers, subtle zones |
| `--ne-bg-muted` | `#E8E7E3` | `#1E1E20` | Muted backgrounds, elevated cards |
| `--ne-bg-elevated` | — | `#232326` | NEW — dark-only: for popover/dropdown surfaces that need more elevation |
| `--ne-border-hairline` | `#EAEAEA` | `#27272A` | Standard hairline borders |
| `--ne-border-strong` | `#D4D4D4` | `#3F3F46` | Emphasis borders |
| `--ne-fg-primary` | `#0A0A0B` | `#FAFAFA` | Primary text (near-white, slightly warm) |
| `--ne-fg-secondary` | `#555555` | `#A1A1AA` | Secondary text |
| `--ne-fg-tertiary` | `#999999` | `#71717A` | Tertiary text, helper copy |
| `--ne-fg-disabled` | `#C9C9C9` | `#52525B` | Disabled text |

**Why these hexes**:
- `#0D0D0E` — subtle warm undertone (vs pure `#0A0A0A` which reads sterile)
- `#151517`, `#1E1E20` — elevation by 4-6 perceptual units per layer (not by 1 — too subtle to read)
- Foreground `#FAFAFA` not pure `#FFFFFF` — slightly softer, reduces retinal glare on OLED
- Cool undertones on borders (`#27272A`) contrast the warm backgrounds — echoes the warm-cool temperature trick from light mode

**Absolute rule**: never use `#000000` for background. Never use `#FFFFFF` for foreground text. Both produce eye strain and read as unrefined.

---

## Silver In Dark Mode — Brighter Metallic

The light-mode silver (`#B8BCC2`, `#C0C3C7`) is tuned for visibility against warm off-white. Against dark ink it disappears. Dark-mode silver must be lighter AND higher opacity.

| Token | Light Value | Dark Value |
|-------|------------|------------|
| `--ne-silver-light` | `#D4D7DC` | `#E5E8ED` |
| `--ne-silver-mid` | `#B8BCC2` | `#C9CDD3` |
| `--ne-silver-ring` | `#C0C3C7` | `#D4D7DC` |
| `--ne-silver-ring-opacity` | `0.4` | `0.55` |
| `--ne-silver-gradient` | `linear-gradient(135deg, #D4D7DC 0%, #B8BCC2 50%, #D4D7DC 100%)` | `linear-gradient(135deg, #E5E8ED 0%, #C9CDD3 50%, #E5E8ED 100%)` |

**The trick**: in dark mode the silver edge becomes MORE prominent (it's the main visual marker since shadows carry less information). This is intentional — silver is the NewEarth fingerprint and dark mode is when it should shine most.

---

## Semantic Colors In Dark Mode

Low-luminance colors (the light-mode palette) disappear against dark. Dark mode uses brighter, more saturated versions. These come from the Untitled UI dark palette — a validated enterprise-dark color system used by Linear, Stripe, and Notion.

| State | Light | Dark | Delta |
|-------|-------|------|-------|
| Critical | `#B42318` | `#F04438` | Brighter red — visible against ink |
| Critical bg | `#FEF3F2` | `#55160C` | Deep wine red backdrop |
| Warning | `#B54708` | `#F79009` | Brighter amber |
| Warning bg | `#FEF6EE` | `#4E1D09` | Deep bronze backdrop |
| Success | `#067647` | `#12B76A` | Brighter green |
| Success bg | `#ECFDF3` | `#053321` | Deep forest backdrop |
| Info | `#175CD3` | `#2E90FA` | Brighter blue |
| Info bg | `#EFF4FF` | `#102A56` | Deep navy backdrop |

**Key insight**: in dark mode, the *backing color* for each semantic becomes a **deep, desaturated version of the foreground color**, not white or light gray. A light-mode critical badge has `#FEF3F2` bg (cream) + `#B42318` text. A dark-mode critical badge has `#55160C` bg (deep wine) + `#F04438` text. Both maintain ~4.5:1 contrast.

---

## Shadow Strategy — Inset Highlights Replace Drop Shadows

**Problem**: `box-shadow: 0 1px 3px rgba(0,0,0,0.06)` is invisible against `#0D0D0E`. The entire light-mode depth system disappears in dark mode.

**Solution**: dark mode uses **inset top highlights** to create the illusion of elevation. A thin bright line across the top of a card simulates the light-catching upper edge of a raised surface.

| Token | Light Value | Dark Value |
|-------|------------|------------|
| `--ne-shadow-card` | `0 1px 2px 0 rgb(0 0 0 / 0.04), 0 1px 3px 0 rgb(0 0 0 / 0.06)` | `inset 0 1px 0 rgb(255 255 255 / 0.04)` |
| `--ne-shadow-card-hover` | `0 4px 6px -1px rgb(0 0 0 / 0.08), ...` | `inset 0 1px 0 rgb(255 255 255 / 0.08), 0 0 0 1px rgb(255 255 255 / 0.04)` |
| `--ne-shadow-dropdown` | `0 10px 15px -3px rgb(0 0 0 / 0.08), ...` | `0 10px 20px -3px rgb(0 0 0 / 0.6), 0 4px 6px -2px rgb(0 0 0 / 0.4)` |
| `--ne-shadow-modal` | `0 20px 25px -5px rgb(0 0 0 / 0.10), ...` | `0 20px 40px -5px rgb(0 0 0 / 0.7), 0 10px 20px -5px rgb(0 0 0 / 0.5)` |

**Rules**:
1. **Cards**: inset highlight top (1px bright line) + optional very subtle ambient shadow (barely visible)
2. **Dropdowns / popovers**: heavy drop shadows WITH blur (these float above — need to cast on ink)
3. **Modals**: even heavier drop shadows to create separation from the backdrop

**Anti-pattern**: trying to reuse the light-mode shadow values in dark mode. They will be invisible. The component will look flat.

---

## Hover Curve In Dark Mode — Unchanged Timing, New Signals

The signature hover curve (300ms, `translate-y-0.5`, silver ring) stays identical. What changes is the shadow on hover:

```css
/* Light mode */
.ne-card-interactive:hover {
  box-shadow: var(--ne-shadow-card-hover);  /* drop shadow */
  transform: translateY(-2px);
  outline-color: rgb(192 195 199 / 0.4);     /* silver ring */
}

/* Dark mode — same transform + silver, different depth strategy */
.dark .ne-card-interactive:hover {
  box-shadow:
    inset 0 1px 0 rgb(255 255 255 / 0.08),   /* inset highlight brightens */
    0 0 0 1px rgb(255 255 255 / 0.04);       /* subtle outline glow */
  transform: translateY(-2px);
  outline-color: rgb(212 215 220 / 0.55);     /* silver ring, brighter */
}
```

Effect: in dark mode, hovering a card makes its top edge *brighten* (as if catching more light). In light mode, hovering lifts it with a drop shadow. Same perceptual outcome, different mechanism.

---

## Implementation — Tailwind `.dark` Class Strategy

NewEarth projects use Tailwind's standard dark mode strategy: `darkMode: 'class'` in `tailwind.config.ts` and a `dark` class on `<html>`.

```ts
// tailwind.config.ts
export default {
  darkMode: 'class',  // NOT 'media' — we want user control
  // ... rest
};
```

Theme toggle hook:

```tsx
// src/hooks/useTheme.ts
import { useEffect, useState } from 'react';

type Theme = 'light' | 'dark' | 'system';

export function useTheme() {
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window === 'undefined') return 'system';
    return (localStorage.getItem('ne-theme') as Theme) ?? 'system';
  });

  useEffect(() => {
    const root = document.documentElement;
    const applied = theme === 'system'
      ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
      : theme;

    root.classList.toggle('dark', applied === 'dark');
    localStorage.setItem('ne-theme', theme);
  }, [theme]);

  // Listen to system changes when mode is 'system'
  useEffect(() => {
    if (theme !== 'system') return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = () => {
      document.documentElement.classList.toggle('dark', mq.matches);
    };
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, [theme]);

  return { theme, setTheme: setThemeState };
}
```

Toggle component:

```tsx
// src/components/ThemeToggle.tsx
import { Sun, Moon, Monitor } from 'lucide-react';
import { useTheme } from '@/hooks/useTheme';
import { Button } from '@/components/ui/button';

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const next = theme === 'light' ? 'dark' : theme === 'dark' ? 'system' : 'light';
  const Icon = theme === 'light' ? Sun : theme === 'dark' ? Moon : Monitor;

  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(next)}
      aria-label={`Switch to ${next} theme`}
    >
      <Icon className="h-4 w-4" />
    </Button>
  );
}
```

**Rules for theme toggle**:
- Default to `system` on first load (respects OS preference)
- Persist to localStorage under `ne-theme` key
- Listen to system preference changes when in `system` mode
- Three-state cycle: `light → dark → system → light` (not just light/dark)
- Toggle is a ghost icon button in the app header, never prominent

---

## Component Behavior In Dark Mode

Every component in the skill must be tested in both modes before declaring done. The checklist:

```
□ Card backgrounds visible (not blending into page)
□ Border visible (hairline reads against dark bg)
□ Text readable (≥4.5:1 contrast for body, ≥3:1 for large text)
□ Silver signature visible on hover (brighter than light mode)
□ Semantic badges readable (red/green/amber/blue all visible)
□ Shadows present via inset highlights, not drop shadows
□ Focus rings visible (silver, higher opacity)
□ Skeleton loaders visible (muted bg is readable against dark base)
□ Input borders visible on focus
□ Dropdown/popover surfaces elevated (use --ne-bg-elevated)
```

---

## Accessibility

| Rule | Light | Dark |
|------|-------|------|
| Body text contrast (WCAG AA) | `#0A0A0B` on `#FBFBFA` = 19.3:1 ✓ | `#FAFAFA` on `#0D0D0E` = 18.6:1 ✓ |
| Secondary text contrast (WCAG AA) | `#555555` on `#FBFBFA` = 7.4:1 ✓ | `#A1A1AA` on `#0D0D0E` = 6.8:1 ✓ |
| Tertiary text contrast (WCAG AA) | `#999999` on `#FBFBFA` = 3.5:1 — borderline, use only for large or helper text | `#71717A` on `#0D0D0E` = 3.1:1 — borderline, same rule |
| Focus ring contrast | silver at 60% against warm off-white | silver at 55% against warm ink |
| Semantic badge contrast | all pairs ≥4.5:1 | all pairs ≥4.5:1 (verified via Untitled UI values) |

**Never**: rely on color alone to convey meaning. Every state must also have a label, icon, or position signal.

---

## Integration With `guided-tour` Skill

Dark mode tour overlay: the `guided-tour` skill uses a semi-transparent dark overlay that reads fine in both light and dark modes. However, the tour popover background must switch:

```css
/* Override guided-tour popover in dark mode */
.dark .driver-popover {
  background: var(--ne-bg-elevated) !important;
  color: var(--ne-fg-primary) !important;
  border: 1px solid var(--ne-border-hairline) !important;
}

.dark .driver-popover-title {
  color: var(--ne-fg-primary) !important;
}

.dark .driver-popover-description {
  color: var(--ne-fg-secondary) !important;
}
```

Add this to the project's CSS after importing both `tokens.css` and `guided-tour` styles.

---

## Dark Mode Anti-Patterns

| Wrong | Why |
|-------|-----|
| `bg-black` (`#000000`) | Pure OLED black reads as cheap. Use warm ink (`#0D0D0E`). |
| `text-white` (`#FFFFFF`) | Eye strain against dark. Use `#FAFAFA`. |
| Reusing light-mode shadow values | Invisible against dark. Use inset highlights. |
| Same silver values in both modes | Silver disappears against dark. Use brighter dark-mode values. |
| Pastel semantic bgs in dark mode (`bg-red-50`) | Cream pastels look jarring on dark. Use deep desaturated versions. |
| "Dark mode" = just inverted (swap black/white) | Loses warmth, loses elevation, loses silver visibility. |
| Forgetting to test drop shadows (they disappear) | Components look flat. Use inset highlights. |
| Hard-coding colors instead of using CSS variables | Can't switch themes without rebuild. Always use `var(--ne-*)`. |

---

*Dark mode is not optional. Every project ships with it. No exceptions.*
