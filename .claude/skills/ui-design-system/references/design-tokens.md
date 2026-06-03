# Design Tokens — Frozen Values

> **This file is the source of truth.** Every value here is LOCKED across all the agency projects except where marked `{{parameter}}`. When refining shades later, edit this file and `tokens.css` together.

---

## 1. Neutral Palette (Warm Off-White Stack) — LOCKED

The warm undertone is a distinctive signature. Most dashboards use cool grays; ours lean warm to pair with cool silver accents.

| Token | Hex | Usage |
|-------|-----|-------|
| `--ne-bg-base` | `#FBFBFA` | Page background, card background (the default canvas) |
| `--ne-bg-subtle` | `#F7F6F3` | Section headers inside drawers, sidebar backgrounds, muted zones |
| `--ne-bg-muted` | `#E8E7E3` | Muted badge backgrounds, disabled states, secondary chips |
| `--ne-border-hairline` | `#EAEAEA` | All standard borders and dividers (1px) |
| `--ne-border-strong` | `#D4D4D4` | Only for emphasis borders (active state, selected row) |
| `--ne-fg-primary` | `#0A0A0B` | Primary text (not pure black — subtle warmth) |
| `--ne-fg-secondary` | `#555555` | Secondary text, labels, metadata |
| `--ne-fg-tertiary` | `#999999` | Tertiary text, helper copy, inactive states |
| `--ne-fg-disabled` | `#C9C9C9` | Disabled text |

**Why these hexes**: the warm off-white stack reads as "expensive paper" rather than "cheap screen" in enterprise dashboard contexts. `#FBFBFA` is 1 shade warmer than pure white, `#F7F6F3` has a perceptible cream cast. Do not substitute `#FFFFFF` or `#FAFAFA` — pure white reads sterile and cheap under office lighting conditions.

---

## 2. Silver Signature Tokens (the agency Fingerprint) — LOCKED

See [silver-signature.md](silver-signature.md) for the application rules. These are the raw values.

| Token | Value | Usage |
|-------|-------|-------|
| `--ne-silver-light` | `#D4D7DC` | Gradient start/end (lighter edge of metallic) |
| `--ne-silver-mid` | `#B8BCC2` | Gradient center (deepest metallic tone) |
| `--ne-silver-ring` | `#C0C3C7` | Hover ring base color, used at 40% opacity |
| `--ne-silver-gradient` | `linear-gradient(135deg, #D4D7DC 0%, #B8BCC2 50%, #D4D7DC 100%)` | Applied as 1px border on premium cards |
| `--ne-silver-edge-strip` | `linear-gradient(90deg, transparent 0%, #B8BCC2 50%, transparent 100%)` | Optional top-edge accent strip (1-2px) for hero cards |
| `--ne-silver-divider` | `linear-gradient(90deg, transparent 0%, #B8BCC2 20%, #B8BCC2 80%, transparent 100%)` | Optional silver section divider for proposals and presentations |

**Temperature rationale**: `#B8BCC2` has a slight blue undertone (cool). Against the warm `#FBFBFA` neutral base this creates warm-cool contrast — the same trick used in luxury watch design (warm ivory dial + cool steel case). Do not substitute pure grays (`#888`, `#999`) which read as mouse-gray, not metal.

---

## 3. Semantic Color Palette — LOCKED

Every color in this section maps to exactly one operational state. Never use them decoratively.

| Token | Hex | State | Example Usage |
|-------|-----|-------|---------------|
| `--ne-critical` | `#B42318` | Severity: critical, destructive, loss | Error banners, critical alerts, negative variance |
| `--ne-critical-bg` | `#FEF3F2` | Critical background (subtle, for badges only) | Light backdrop behind critical text |
| `--ne-warning` | `#B54708` | Severity: warning, caution, attention needed | Warning banners, amber alerts, medium severity |
| `--ne-warning-bg` | `#FEF6EE` | Warning background | Light backdrop behind warning text |
| `--ne-success` | `#067647` | State: success, positive, resolved, gain | Success confirmations, positive variance, completed states |
| `--ne-success-bg` | `#ECFDF3` | Success background | Light backdrop behind success text |
| `--ne-info` | `#175CD3` | State: informational, action available | Info banners, neutral action highlights (non-primary) |
| `--ne-info-bg` | `#EFF4FF` | Info background | Light backdrop behind info text |

**Why these values over Tailwind defaults**:

| Tailwind Default | the agency Value | Difference |
|-----------------|---------------|------------|
| red-600 `#DC2626` | `#B42318` | 1 step deeper, less pink — reads as "serious loss" |
| amber-600 `#D97706` | `#B54708` | Darker, more bronze — less school-bus |
| green-600 `#16A34A` | `#067647` | Deeper, slightly desaturated — "financial ledger green" |
| blue-600 `#2563EB` | `#175CD3` | Deeper royal — distinct from any cyan primary |

These are in the Untitled UI / Radix Colors family used by Stripe Dashboard, Linear, Notion — read as "enterprise software" rather than "Tailwind starter template".

---

## 4. Primary Brand Color — PARAMETERIZED

| Token | Default | Scope |
|-------|---------|-------|
| `--ne-primary` | `{{primary_color}}` | Per-client brand primary |
| `--ne-primary-fg` | `{{primary_color_foreground}}` | Text on primary surfaces |
| `--ne-primary-hover` | `color-mix(in srgb, {{primary_color}} 90%, black)` | Hover state for primary buttons |

**Rule**: primary is used for:
- Primary CTA buttons (one per view, maximum)
- Active navigation state
- Key interactive affordances (tour button, the one "take action" slot)
- Links (when they matter)

**Never** used for:
- Card backgrounds
- Section headers
- Status indicators (those are semantic colors)
- Decoration

---

## 5. Typography — LOCKED

| Role | Font Stack | Weights Loaded |
|------|-----------|---------------|
| Sans (body, headings) | `'DM Sans', system-ui, -apple-system, sans-serif` | 400, 500, 600, 700 |
| Mono (data, numbers, code) | `'JetBrains Mono', ui-monospace, SFMono-Regular, monospace` | 400, 500, 600 |

**Import** (Google Fonts, use `display=swap`):
```html
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
```

**Or fontsource** (preferred for production):
```bash
npm install @fontsource/dm-sans @fontsource/jetbrains-mono
```

### Type Scale (Responsive KPIs)

| Token | Value | Usage |
|-------|-------|-------|
| `--ne-kpi-label` | `clamp(12px, 0.9vw + 10px, 14px)` | "TOTAL LOADS", "AVG LOADS / DRIVER" — uppercase, tracked-wide |
| `--ne-kpi-value` | `clamp(32px, 5vw, 56px)` | The big number |
| `--ne-kpi-value-hero` | `clamp(40px, 6vw, 72px)` | Hero KPI cards only |
| `--ne-text-xs` | `0.75rem` (12px) | Badges, helper text |
| `--ne-text-sm` | `0.875rem` (14px) | Body small, metadata |
| `--ne-text-base` | `1rem` (16px) | Body default |
| `--ne-text-lg` | `1.125rem` (18px) | Section headers |
| `--ne-text-xl` | `1.25rem` (20px) | Page subtitles |
| `--ne-text-2xl` | `1.5rem` (24px) | Card titles |
| `--ne-text-3xl` | `1.875rem` (30px) | Page titles |

### Typography Rules

1. **Numbers always `tabular-nums`** — prevents digit jitter on live-updating KPIs
2. **Uppercase labels always tracked wide** — `letter-spacing: 0.08em` minimum, 0.12em preferred
3. **JetBrains Mono for anything numeric in a data context** — IDs, timestamps, counts, percentages, codes
4. **DM Sans for everything else** — headings, body, labels, navigation
5. **No more than 3 type sizes per viewport** — keeps hierarchy clean

---

## 6. Spacing Scale — LOCKED (Tailwind Compatible)

Standard Tailwind spacing scale. No customization — the discipline comes from *usage*, not invention.

| Class | Value | Usage |
|-------|-------|-------|
| `gap-1` | 4px | Tight inline groups (icon + label) |
| `gap-2` | 8px | Default inline group spacing |
| `gap-3` | 12px | Card internal sections |
| `gap-4` | 16px | Card-to-card spacing, form field spacing |
| `gap-6` | 24px | Section-to-section spacing |
| `gap-8` | 32px | Page section breaks |

### Card Padding Patterns

| Context | Pattern | Notes |
|---------|---------|-------|
| Card header | `px-6 py-4` | 24h/16v — the drawer header standard |
| Card content | `px-4 py-6` | 16h/24v — more vertical room for data |
| Drawer section header | `px-6 py-3` | Compact, uses `--ne-bg-subtle` background |
| Inline badge | `px-2.5 py-0.5` | Tight pill |
| Micro badge | `px-1 py-0.5` | Inline micro-tags (counts) |
| Button default | `px-4 py-2` | |
| Button large | `px-6 py-3` | |

---

## 7. Border Radius Scale — LOCKED

| Token | Value | Usage |
|-------|-------|-------|
| `rounded-sm` | 2px | Micro-tags only |
| `rounded` | 4px | Small inputs |
| `rounded-md` | 6px | Buttons, default inputs |
| `rounded-lg` | 8px | Standard cards |
| `rounded-xl` | 12px | **Maximum allowed** — used for hero cards and primary surfaces |
| `rounded-full` | 9999px | Pills, avatars, circular badges only |

**BANNED**: `rounded-2xl` (16px), `rounded-3xl` (24px). These produce the "chunky iOS consumer app" look that AI-generated dashboards default to. They are rejected by the audit script.

---

## 8. Shadow Scale — LOCKED

| Token | Value | Usage |
|-------|-------|-------|
| `--ne-shadow-card` | `0 1px 2px 0 rgb(0 0 0 / 0.04), 0 1px 3px 0 rgb(0 0 0 / 0.06)` | Default card rest state |
| `--ne-shadow-card-hover` | `0 4px 6px -1px rgb(0 0 0 / 0.08), 0 2px 4px -1px rgb(0 0 0 / 0.04)` | Card hover state |
| `--ne-shadow-dropdown` | `0 10px 15px -3px rgb(0 0 0 / 0.08), 0 4px 6px -2px rgb(0 0 0 / 0.04)` | Menus, dropdowns, popovers |
| `--ne-shadow-modal` | `0 20px 25px -5px rgb(0 0 0 / 0.10), 0 10px 10px -5px rgb(0 0 0 / 0.04)` | Modal dialogs only |

**Rule**: always two-layer shadows. Single-layer shadows look cheap. Never use `shadow-xl`/`shadow-2xl` (too blurry, consumer-feel). Never use colored shadows (`shadow-cyan-500/50`) — pure grayscale depth only.

**BANNED**: `backdrop-blur-*`, `backdrop-filter` — glassmorphism is rejected at the token level. See [anti-vibe-coded.md](anti-vibe-coded.md).

---

## 9. Motion Tokens — LOCKED

| Token | Value | Usage |
|-------|-------|-------|
| `--ne-duration-fast` | `150ms` | Color changes, focus rings |
| `--ne-duration-base` | `300ms` | **Signature card hover, drawer open, layout transitions** |
| `--ne-duration-slow` | `500ms` | Drawer close (asymmetric — close slower than open) |
| `--ne-ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | Hero animations |
| `--ne-ease-in-out` | `cubic-bezier(0.4, 0, 0.2, 1)` | Default transitions |

### The Signature Hover Curve

```css
.ne-card {
  transition: all var(--ne-duration-base) var(--ne-ease-in-out);
}
.ne-card:hover {
  box-shadow: var(--ne-shadow-card-hover);
  transform: translateY(-2px);
}
```

Tailwind equivalent:
```tsx
className="transition-all duration-300 hover:shadow-lg hover:-translate-y-0.5"
```

**Never deviate**. This curve is the the agency house signature hover. Different cards get different *content*, never a different *hover curve*.

---

## 10. Z-Index Scale — LOCKED (Coordinated with guided-tour)

| Layer | Value | Owner |
|-------|-------|-------|
| Base content | `0-10` | App |
| Sticky elements | `20` | App |
| Dropdown menus | `50` | shadcn-ui |
| Modal overlay | `100` | shadcn-ui |
| Modal content | `101` | shadcn-ui |
| Toast notifications | `200` | App |
| **Tour overlay** | **`10000`** | **guided-tour skill (do not override)** |
| **Tour popover** | **`10001`** | **guided-tour skill (do not override)** |

**Rule**: nothing in the app may use z-index ≥ 1000 except the tour layers. If you need a high-z overlay, either coordinate with guided-tour or use values ≤ 200.

---

---

## 11. Dark Mode Tokens — See `dark-mode.md`

Dark mode is **required for every project** and uses inverted neutrals, brighter silver, and inset-highlight shadows instead of drop shadows. The full token override table is in [dark-mode.md](dark-mode.md). Key differences:

| Token | Light | Dark |
|-------|-------|------|
| `--ne-bg-base` | `#FBFBFA` | `#0D0D0E` (warm ink, never `#000`) |
| `--ne-fg-primary` | `#0A0A0B` | `#FAFAFA` (never `#FFF`) |
| `--ne-silver-mid` | `#B8BCC2` | `#C9CDD3` (brighter for visibility) |
| `--ne-critical` | `#B42318` | `#F04438` (brighter) |
| `--ne-shadow-card` | `0 1px 2px, 0 1px 3px` (drop) | `inset 0 1px 0 rgba(255,255,255,0.04)` (highlight) |

Applied via Tailwind's `.dark` class on `<html>`. Full override block is in `assets/tokens.css`.

## 12. Atelier Dark Preset — See `atelier-dark-preset.md`

Atelier Dark is an **optional editorial preset** that replaces the entire token system when active. Opt-in via `<html data-theme="atelier-dark">`. Uses a locked 5-color palette (ink / oxide / parchment / verdigris / bronze), triple type system (serif display + grotesk body + mono data), editorial motion (400-600ms), letterpress shadows, and paper-grain texture.

**Never use Atelier Dark for long-session operational dashboards** — it's editorial personality, not efficiency. Reserve for agency internal tools, client proposals, hero landing pages. See [atelier-dark-preset.md](atelier-dark-preset.md) for full spec.

---

*Last updated: 2026-04-10. Edit this file and `assets/tokens.css` together — they must stay in sync.*
