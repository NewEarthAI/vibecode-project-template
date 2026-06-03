# Atelier Dark — Optional Editorial Preset

> **Status**: preset variant, not default. Opt-in via `data-theme="atelier-dark"` attribute or the `NE_PRESET=atelier-dark` build env.
>
> **What this is**: a deliberate departure from the Linear/Vercel/Stripe-clone aesthetic. Where the default NewEarth system says "rigorous and efficient", Atelier Dark says "thoughtful and crafted". Think editorial publication, not product interface. Think Pentagram portfolio, not SaaS dashboard. Think "designed by a human who reads books" instead of "built fast".
>
> **When to use**: agency-facing internal dashboards, client proposal sites, hero landing pages, premium product showcases, presentation layers. **Never** for data-dense operational dashboards — the editorial personality competes with the data.
>
> **When NOT to use**: client operational dashboards where users spend 6+ hours per day. Editorial personality becomes fatigue over long sessions. Stick with the default monochrome system.

---

## Core Philosophy

| Default NewEarth | Atelier Dark |
|------------------|--------------|
| Linear / Stripe / Vercel lineage | Pentagram / NYT R&D / Apple Design Awards lineage |
| Restraint, hairlines, data-first | Craft, texture, narrative-first |
| DM Sans everywhere | Triple type system: display serif + body grotesk + data mono |
| 300ms functional hover | 400-600ms editorial reveals |
| Monochrome + earned color | 5-color committed palette |
| Warm off-white neutrals | Ink + parchment + oxide |
| Silver as signature | Bronze as signature accent |
| Two-layer grayscale shadow | Letterpress shadows + paper-grain texture |
| Symmetric grids | Asymmetric layouts with margin notes |
| "Works at scale" | "Feels handmade" |

---

## The Five-Color Palette

Atelier Dark commits to exactly five colors. No more. No less. Each has a specific role and never appears outside it.

| Role | Name | Hex | Usage |
|------|------|-----|-------|
| Base | **Ink** | `#0A0A0B` | Page background, deepest surface |
| Surface elevation | **Oxide** | `#2A1F1A` | Elevated surfaces, cards, hero panels. Deep rust-brown with warm undertone — NOT gray. |
| Foreground / reversal | **Parchment** | `#F0E8D8` | Primary text, light surfaces when reversed. Warm cream — NOT white. |
| Positive / earned accent | **Verdigris** | `#4A7C5D` | Success, growth, positive variance, verified. Aged copper green. |
| Brand / emphasis | **Bronze** | `#A87841` | The Atelier Dark signature. Primary CTAs, hero accents, key affordances. Burnished, not gold. |

**Discipline rules**:
1. No sixth color. Ever. Need an alert? Bronze is intense enough. Need a warning? Oxide darkens, bronze brightens.
2. Parchment is never pure white. Ink is never pure black. Oxide is never neutral gray.
3. Color pairs only: ink+parchment (high contrast body), oxide+parchment (card content), bronze+ink (primary CTA), verdigris+parchment (positive state).
4. Gradients are allowed ONLY between oxide and ink (depth gradient on hero surfaces). Never bronze-to-verdigris, never parchment gradients.

**Why these specific values**:
- Ink has warmth (`#0A0A0B` not `#000`) — avoids OLED-cheap feel
- Oxide is rust-adjacent — echoes aged iron, not brown
- Parchment is cream — evokes letterpress paper, not office copy paper
- Verdigris is aged copper — matches architectural patina on real bronze sculptures
- Bronze is burnished, not polished — matte, expensive, hand-finished

---

## Triple Type System

Atelier Dark uses three distinct typefaces with specific roles. This is where it differs most from the default (which is a two-typeface system: DM Sans + JetBrains Mono).

### Display — Serif

**Primary**: **PP Editorial New** (Pangram Pangram, licensed, ~$75/year)
- Role: page titles, hero numbers, proposal headings, section labels
- Weight usage: Ultralight (200) for hero displays, Regular (400) for section heads, Italic (400) for emphasis
- Character: high-contrast serif with editorial personality — evokes magazine masthead typography

**Free alternative**: **Fraunces** (Google Fonts, free)
- Variable font with optical sizing and soft/wonky axes
- Usage: Fraunces Normal 9pt for body, Fraunces Soft 18pt for display
- Less editorial but closer than any other free option

**Locked alternative**: **Canela** (Commercial Type, ~$300)
- Used if PP Editorial New is unavailable and budget allows

### Body — Grotesk

**Primary**: **Söhne** (Klim Type Foundry, licensed, ~$200+)
- Role: body text, labels, navigation, buttons, all non-display text
- Weight usage: Buch (400), Kräftig (500), Halbfett (600)
- Character: refined neo-grotesque, distinctive counters, excellent at small sizes

**Free alternative**: **Inter Tight** (Google Fonts, free)
- Tighter letter spacing than regular Inter
- Good counter design, passes the "does it look default" test better than Inter
- NOT Inter (banned as default elsewhere in the skill — Inter Tight is the exception)

**Locked alternative**: **GT America** (Grilli Type, ~$225)

### Data — Mono

**Primary**: **Berkeley Mono** (U.S. Graphics, licensed, ~$75)
- Role: numbers, timestamps, IDs, data values, code, mono labels
- Weight usage: Regular (400), Medium (500)
- Character: rounded terminals, typewriter heritage, warm personality

**Free alternative**: **JetBrains Mono** (Google Fonts, free — same as default skill)
- Falls back to the default system's mono choice
- Works but loses the editorial character

**Locked alternative**: **IBM Plex Mono** (IBM, free) — enterprise alternative

### Type Scale

Atelier Dark uses larger type than the default, with more vertical rhythm:

| Role | Size | Font | Weight | Line Height |
|------|------|------|--------|-------------|
| Display hero | `clamp(48px, 7vw, 96px)` | PP Editorial New | 200 | 0.95 |
| Display | `clamp(36px, 5vw, 64px)` | PP Editorial New | 400 | 1.05 |
| Section head | `clamp(24px, 2vw, 32px)` | PP Editorial New | 400 | 1.15 |
| Body large | `18px` | Söhne | 400 | 1.6 |
| Body | `16px` | Söhne | 400 | 1.6 |
| Body small | `14px` | Söhne | 400 | 1.55 |
| Label | `12px` | Söhne | 500 uppercase, tracking 0.16em | 1.4 |
| Data hero | `clamp(40px, 6vw, 80px)` | Berkeley Mono | 500 | 1.0 |
| Data | `16px` | Berkeley Mono | 400 | 1.45 |
| Margin note | `13px` | Söhne italic | 400 | 1.5 |

**Key difference from default**: labels get **0.16em letter-spacing** (vs 0.08em in default). Atelier Dark breathes more.

---

## Motion — Editorial Slow

Default NewEarth motion is 300ms — functional, immediate.
Atelier Dark motion is 400-600ms — considered, editorial.

| Token | Default | Atelier Dark |
|-------|---------|--------------|
| `--ne-duration-fast` | `150ms` | `250ms` |
| `--ne-duration-base` | `300ms` | `500ms` |
| `--ne-duration-slow` | `500ms` | `700ms` |
| `--ne-ease-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | `cubic-bezier(0.22, 1, 0.36, 1)` |
| Hero reveal | (none) | `cubic-bezier(0.19, 1, 0.22, 1)` — "power4.out" feel |

**Usage**:
- Card hovers: 500ms slow lift with inset highlight fade
- Page transitions: staggered reveals, 80ms delay per element
- Section scroll-triggered animations: 600ms fade + translate-y-8
- Primary CTA hover: 250ms (still fast — don't make actions feel sluggish)

**Never**: animate every element. Atelier Dark uses motion sparingly — each animation should feel like a reveal, not a distraction.

---

## Letterpress Shadow Language

Atelier Dark replaces the default two-layer shadow with **letterpress shadows** — 1px offset, no blur, very low opacity. The effect: elements look like they were *pressed into paper*, with a crisp edge that catches one direction of light.

| Token | Value |
|-------|-------|
| `--ne-shadow-card` | `0 1px 0 0 rgb(240 232 216 / 0.03), inset 0 1px 0 0 rgb(240 232 216 / 0.04)` |
| `--ne-shadow-card-hover` | `0 1px 0 0 rgb(240 232 216 / 0.05), inset 0 1px 0 0 rgb(240 232 216 / 0.08), 0 0 20px -5px rgb(168 120 65 / 0.15)` |
| `--ne-shadow-letterpress-text` | `0 1px 0 rgb(0 0 0 / 0.3)` — for large display text on oxide surfaces |
| `--ne-shadow-inset-deep` | `inset 0 2px 4px 0 rgb(0 0 0 / 0.3)` — for "pressed" wells |

**The hover moment**: a card on hover gains a subtle **bronze glow** (not silver — silver is the default skill's signature, bronze is Atelier Dark's). The glow is diffuse and warm, 20px blur at 15% opacity.

---

## Paper-Grain Texture

Atelier Dark overlays every ink surface with a subtle SVG noise texture — invisible at first glance, but creates the "printed paper" feel on closer inspection.

```css
:root[data-theme="atelier-dark"] body {
  background-color: var(--ne-ink);
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix type='saturate' values='0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.03'/%3E%3C/svg%3E");
  background-size: 200px 200px;
  background-blend-mode: overlay;
}
```

**Rules**:
- Opacity: 0.03 (very subtle — should be felt, not seen)
- Monochrome (no color — the noise is gray)
- Tile size: 200×200 (avoid visible repetition patterns)
- Never on cards individually — only on the page body, so cards *contrast* the grain

---

## Asymmetric Layout Pattern

Default NewEarth: 12-column grid, symmetric. Atelier Dark: asymmetric two-column layout with a narrow **margin-note column** on the left (320px) and a wide content column (flex).

```
┌────────────┬─────────────────────────────────────────────┐
│            │                                             │
│  [margin]  │              [main content]                 │
│            │                                             │
│  small     │  Large display type, generous whitespace,   │
│  italic    │  textured surfaces, bronze accents           │
│  aside     │                                             │
│            │                                             │
│  date      │                                             │
│  authors   │                                             │
│  metadata  │                                             │
│            │                                             │
└────────────┴─────────────────────────────────────────────┘
```

The margin column contains:
- Metadata (dates, authors, sources)
- Margin notes (italic Söhne, small)
- Section navigation (sticky)
- Small-scale data that supports but doesn't lead

This mirrors editorial magazine layouts — the "left rail" of *The New Yorker*, *MIT Technology Review*, *Harper's*.

**Breakpoints**:
- Mobile: margin column collapses into an expandable drawer at the top
- Tablet: margin column narrows to 240px
- Desktop: full 320px margin column
- Large desktop: margin column can grow to 380px

**Never**: make Atelier Dark a 12-column symmetric grid. The asymmetry *is* the point.

---

## Atelier Dark Components

Components don't change their *behavior* — a Card is still a Card, a KPI is still a KPI — but their *skin* changes:

### Atelier Dark Card

```tsx
<Card className="ne-atelier-card p-8">
  <span className="ne-atelier-label">Revenue</span>
  <span className="ne-atelier-data-hero">R1 151 700</span>
  <p className="ne-atelier-margin-note">
    Down 8% versus last period. Driven by reduced weekend activity
    and two fleet breakdowns in Q2.
  </p>
</Card>
```

With styles:

```css
.ne-atelier-card {
  background: var(--ne-oxide);
  border: 1px solid rgb(240 232 216 / 0.08);  /* parchment at 8% */
  border-radius: 2px;  /* tighter than default — editorial */
  padding: 2rem;
  box-shadow: var(--ne-shadow-card);
  transition: all 500ms cubic-bezier(0.22, 1, 0.36, 1);
  position: relative;
}

.ne-atelier-card:hover {
  border-color: rgb(168 120 65 / 0.3);  /* bronze border on hover */
  box-shadow: var(--ne-shadow-card-hover);
  /* No translate-y — Atelier Dark cards don't lift, they glow */
}

.ne-atelier-label {
  font-family: var(--ne-font-grotesk, 'Söhne', 'Inter Tight', sans-serif);
  font-size: 12px;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.16em;
  color: rgb(240 232 216 / 0.6);  /* parchment at 60% */
}

.ne-atelier-data-hero {
  font-family: var(--ne-font-data, 'Berkeley Mono', 'JetBrains Mono', monospace);
  font-size: clamp(40px, 6vw, 80px);
  font-weight: 500;
  color: var(--ne-parchment);
  font-variant-numeric: tabular-nums;
  line-height: 1;
  display: block;
  margin-top: 0.5rem;
}

.ne-atelier-margin-note {
  font-family: var(--ne-font-grotesk);
  font-size: 13px;
  font-style: italic;
  font-weight: 400;
  color: rgb(240 232 216 / 0.65);
  line-height: 1.5;
  margin-top: 1rem;
  max-width: 48ch;
}
```

**Key differences from default Card**:
- Radius drops from `rounded-xl` (12px) to `2px` — editorial typography papers use tight corners
- No translate-y lift on hover (cards don't *move*, they *glow*)
- Hover accent is bronze border, not silver ring
- Padding increases from `p-6` to `p-8` — more breathing room
- Margin note is built into the card pattern

### Atelier Dark Button

Primary button is bronze on ink:

```css
.ne-atelier-btn-primary {
  background: var(--ne-bronze);
  color: var(--ne-ink);
  font-family: var(--ne-font-grotesk);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  font-size: 13px;
  padding: 14px 28px;
  border: none;
  border-radius: 2px;
  transition: all 250ms cubic-bezier(0.22, 1, 0.36, 1);
  cursor: pointer;
}

.ne-atelier-btn-primary:hover {
  background: color-mix(in srgb, var(--ne-bronze) 90%, white);
  box-shadow: 0 0 30px -5px rgb(168 120 65 / 0.4);
  transform: translateY(-1px);
}
```

Notice: letter-spacing, uppercase, small size — editorial button style. Looks more like a "READ MORE →" in a magazine than a SaaS CTA.

---

## When Atelier Dark Makes Sense

**Use it for**:
- NewEarth AI agency internal dashboard (the context that prompted this preset)
- Client proposal sites and pitches
- Hero landing pages for premium products
- Presentation layers and report covers
- Agency portfolio pages
- Any surface where "this was thoughtfully made" is the primary message

**Do NOT use it for**:
- Client operational dashboards (fatigue over long sessions)
- Data-dense workbenches where users spend 6+ hours
- Mobile-first consumer applications
- Admin CRUD interfaces
- Any surface where efficiency > personality

**Rule of thumb**: if the user will spend more than 15 minutes continuously in the interface, use the default monochrome system. If they'll spend 2-5 minutes admiring, reading, or deciding, Atelier Dark is worth the commitment.

---

## Adoption Checklist

If the user wants to build a project in Atelier Dark:

```
□ Confirm the project type fits (see "When to use" above)
□ Budget for 3 licensed typefaces (~$350-500/year total) OR commit to free alternatives (Fraunces + Inter Tight + JetBrains Mono)
□ Install tokens.css with [data-theme="atelier-dark"] block
□ Set body attribute: <body data-theme="atelier-dark">
□ Replace all ne-card-* classes with ne-atelier-card
□ Replace button styles with ne-atelier-btn-*
□ Add paper-grain texture to body via CSS
□ Switch layout to asymmetric two-column with margin notes
□ Audit: remove symmetric grids, add margin column
□ Test in both ink mode (dark) and parchment mode (light reversal — yes, Atelier Dark has its own light mode using parchment as base and ink as foreground)
```

---

## Atelier Dark — Parchment Mode (Light Reversal)

Yes, Atelier Dark has its own light mode. It's not the same as the default monochrome light system — it reverses the 5-color palette to use parchment as the base and ink as the foreground, keeping oxide for elevation and bronze/verdigris unchanged.

| Role | Dark Mode | Light Mode (Parchment) |
|------|-----------|----------------------|
| Base | Ink `#0A0A0B` | Parchment `#F0E8D8` |
| Elevation | Oxide `#2A1F1A` | Warm beige `#E5DDCC` |
| Foreground | Parchment `#F0E8D8` | Ink `#0A0A0B` |
| Signature accent | Bronze `#A87841` | Bronze `#A87841` (unchanged) |
| Positive | Verdigris `#4A7C5D` | Verdigris `#4A7C5D` (unchanged) |

**Philosophy**: bronze and verdigris work in both modes because they are *mid-luminance* colors. Inverting the neutrals changes the mood from "late-night editorial" to "morning-newspaper editorial" — both still editorial.

---

## Future Work

- **Full token export** for Atelier Dark — currently lives in comments in `tokens.css`
- **Atelier Dark component templates** — currently only CSS classes provided; future work adds Card.tsx, KpiCard.tsx, Button.tsx variants
- **Audit script extensions** — the default audit scripts need Atelier-aware modes so they don't flag `rounded-[2px]` as "too small" in Atelier Dark context
- **Gallery of reference implementations** — NewEarth agency internal dashboard when it ships; client proposal sites

---

*Atelier Dark is a deliberate luxury. Treat it as such. A NewEarth project that uses Atelier Dark when the default system would have served better is a bigger failure than one that uses the default when Atelier Dark would have been more appropriate. Restraint about restraint is the meta-discipline.*
