# Silver Signature — The NewEarth AI Fingerprint

> **What this is**: The one visual element that unmistakably marks a NewEarth-built interface. Silver is not used for information — it is used for *identity*. A client should never ask "what is that color", but over time they should recognize that every NewEarth dashboard has the same quiet metallic quality.

---

## The Seven Silver Applications

Each has a distinct purpose. C is always-on; A and D are opt-in defaults for marked components; B, E, F, G are reserved opt-ins for premium / presentation contexts.

| Mode | Visibility | Where | When |
|------|------------|-------|------|
| **A. Hairline metallic border** | Subtle — only visible on close inspection | Opt-in on premium cards (KPI heroes, drawer headers, hero panels) | Always-on for marked components |
| **B. Top-edge accent stripe (card)** | More visible — a thin brand watermark | Hero KPI cards, proposal headers, page banners | Opt-in, reserved for specific surfaces |
| **C. Silver hover ring** | Invisible until interaction | Every interactive card | Always-on, universal |
| **D. Silver section divider** | Visible — replaces flat gray dividers | Inside drawers between sections, between dashboard zones | Opt-in, strong for proposals |
| **E. Silver button (fill)** | Brushed silver primary action | Proposal CTAs, landing-page primary action, hero deal-card "Submit Offer" | Opt-in, premium contexts only — at most ONE silver button per viewport |
| **F. Silver header stripe (bottom)** | 2px silver band at bottom of `<PageHeader>` | Proposal pages, landing heroes, report covers, dashboard brand-anchor view | Opt-in, at most ONE per project (the brand-anchor page) |
| **G. Silver edge button (gradient ring)** | Quiet — 1px metallic ring around neutral fill | Premium secondary CTAs, presentation toolbars, brand-anchor surfaces where Mode E would over-signal | Opt-in, up to 2 per viewport (looser than Mode E) |

---

## Mode A — Hairline Metallic Border (Default Premium Card)

**Rule**: Apply to cards that want to feel "this is a premium surface". Not every card. KPI heroes, drawer headers, and hero panels only.

### CSS Implementation

```css
.ne-silver-edge {
  position: relative;
  background: var(--ne-bg-base);
  border-radius: 0.75rem; /* rounded-xl */
}

.ne-silver-edge::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  padding: 1px;
  background: var(--ne-silver-gradient);
  -webkit-mask:
    linear-gradient(#fff 0 0) content-box,
    linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
          mask-composite: exclude;
  pointer-events: none;
}
```

**Why `::before` with mask-composite**: CSS cannot apply a gradient directly to `border-color`. The mask-composite trick paints the gradient on a 1px ring and masks out the interior.

### Tailwind Usage

```tsx
<Card className="ne-silver-edge rounded-xl bg-[var(--ne-bg-base)]">
  {/* content */}
</Card>
```

### When To Apply

| Component | Apply? |
|-----------|--------|
| Hero KPI card (Total Loads, etc.) | YES |
| Drawer header panel | YES |
| Page banner / stat overview | YES |
| Standard list item card | NO — too decorative at scale |
| Inline badge | NO |
| Button (default) | NO — buttons use primary color. **Opt-in silver Button variant exists — see Mode E below.** |
| Form input | NO |
| Table row | NO |

**Rule of thumb**: if the surface conveys *status or achievement*, apply silver edge. If it's a *utility* (button, input, row), do not.

---

## Mode B — Top-Edge Accent Stripe (Reserved)

**Rule**: A 1-2px silver stripe along the top of a card only. More assertive than Mode A. Used when a single hero surface anchors a page — never on multiple cards in the same view.

### CSS Implementation

```css
.ne-silver-top {
  position: relative;
  background: var(--ne-bg-base);
  border-radius: 0.75rem;
  border: 1px solid var(--ne-border-hairline);
  overflow: hidden;
}

.ne-silver-top::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--ne-silver-edge-strip);
  pointer-events: none;
}
```

### Tailwind Usage

```tsx
<Card className="ne-silver-top rounded-xl">
  {/* content */}
</Card>
```

### When To Apply

- **Proposal hero cards**: the single "here's what we're delivering" banner on a proposal page
- **Landing page hero sections**: the one big statement above the fold
- **Report cover panels**: "Fleet Report — April 2026" top card

**Do not combine with Mode A on the same component.** Pick one.

---

## Mode C — Silver Hover Ring (Universal Interaction Reward)

**Rule**: Every interactive card gets this. It is invisible at rest and appears on hover as a subtle metallic halo. The user never consciously notices it, but the interface feels "alive" because interactive elements quietly respond.

### CSS Implementation

```css
.ne-card-interactive {
  transition: all var(--ne-duration-base) var(--ne-ease-in-out);
  box-shadow: var(--ne-shadow-card);
  outline: 1px solid transparent; /* reserve space to prevent layout shift */
}

.ne-card-interactive:hover {
  box-shadow: var(--ne-shadow-card-hover);
  transform: translateY(-2px);
  outline-color: rgb(192 195 199 / 0.4); /* #C0C3C7 at 40% */
}

.ne-card-interactive:focus-visible {
  outline-color: rgb(192 195 199 / 0.6);
  outline-width: 2px;
}
```

### Tailwind Usage

```tsx
<div className="
  transition-all duration-300
  hover:shadow-lg hover:-translate-y-0.5
  hover:outline hover:outline-1 hover:outline-[#C0C3C7]/40
  focus-visible:outline focus-visible:outline-2 focus-visible:outline-[#C0C3C7]/60
">
```

Or via the provided utility class:
```tsx
<div className="ne-card-interactive">
```

### Interaction Sequence

```
rest          → hairline border, default shadow, no outline
hover         → shadow lifts + transform -2px + silver outline fades in (300ms)
focus-visible → silver outline becomes more visible (accessibility)
active        → transform returns toward 0, shadow compresses
```

**Never** use a colored hover ring (brand color, blue, etc.). The interaction reward is *always* silver — that is what makes it a signature.

---

## Mode D — Silver Section Divider (Structural)

**Rule**: Replaces flat `#EAEAEA` horizontal rules when the divider is conveying *structural importance* — e.g., between major drawer sections, between dashboard zones, between report sections. Not every divider — the skill hairline `border-b` is still the default.

### CSS Implementation

```css
.ne-divider-silver {
  height: 1px;
  border: none;
  background: var(--ne-silver-divider);
  margin: 1.5rem 0;
}
```

### When To Apply

| Context | Silver divider? |
|---------|-----------------|
| Between drawer sections (Booking / Activity / Timeline) | YES |
| Between page zones (Hero KPIs / Operations / Issues) | YES |
| Inside a single section, between rows | NO — flat `border-b` |
| Proposal / report section breaks | YES — strongest use case |
| Form field separators | NO |
| List item separators | NO |

### Tailwind Usage

```tsx
<hr className="ne-divider-silver my-6" />

// or inline:
<hr className="my-6 border-0 h-px bg-[linear-gradient(90deg,transparent_0%,#B8BCC2_20%,#B8BCC2_80%,transparent_100%)]" />
```

---

## Mode E — Silver Button (Opt-in Premium Action)

**Rule**: Default buttons remain brand-color primary. The silver button variant is **opt-in only** for premium contexts where the action itself is part of the brand moment — proposal "Download PDF", landing-page primary CTA, report cover "Open Report", hero deal-card "Submit Offer".

Do **not** use silver buttons in dense operational dashboards. At scale they read as decorative chrome and erode the discipline.

### CSS Implementation

The button uses brushed silver as the *fill* (one of the two places silver is allowed as fill — the other being Mode F header stripe). The inner highlight is the trick that prevents it reading as flat gray.

```css
.ne-button-silver {
  color: var(--ne-fg-primary);
  background: var(--ne-silver-gradient);
  border: 1px solid var(--ne-silver-mid);
  box-shadow:
    inset 0 1px 0 0 rgba(255, 255, 255, 0.45),
    0 1px 2px 0 rgba(0, 0, 0, 0.06);
  transition: all var(--ne-duration-base) var(--ne-ease-in-out);
}

.ne-button-silver:hover {
  filter: brightness(1.04);
  transform: translateY(-1px);
  box-shadow:
    inset 0 1px 0 0 rgba(255, 255, 255, 0.55),
    0 4px 8px -2px rgba(0, 0, 0, 0.10);
}
```

### React Usage

```tsx
import { Button } from '@/components/ui/button';

<Button variant="silver">Download PDF</Button>
<Button variant="silverOutline">Learn more</Button>
```

The `silverOutline` variant pairs alongside `silver` — primary + secondary CTA matched as a unit.

### When To Apply

| Context | Silver button? |
|---------|----------------|
| Proposal hero "Download PDF" / "Open Report" | YES |
| Landing page primary CTA above the fold | YES |
| Report cover panel actions | YES |
| Buyer hero card "Submit Offer" — single per page | YES |
| Toolbar actions in a dashboard | NO |
| Form submit in an admin panel | NO |
| Modal "Confirm" / "Cancel" | NO |
| Dropdown trigger | NO |

**Density rule**: at most ONE silver button per visible viewport. Two = decoration, not signal.

### Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Silver button on every form in a dashboard | Decorative chrome, dilutes signature | Default brand-color buttons; silver only on hero CTAs |
| Silver button + chrome-bright `#F0F0F0` background | Reads as cheap | Use the locked `--ne-silver-gradient` |
| Animated shimmer on hover | NFT energy | Static brightness shift only |
| Silver button on a semantic-colored card (red/amber surface) | Identity collides with state | Silver buttons live on neutral surfaces only |

---

## Mode F — Silver Header Stripe (Page / Section Anchor)

**Rule**: A 2px brushed silver stripe along the **bottom edge** of a `<PageHeader>`. Marks the page as a brand surface — proposal, landing, report, or designated dashboard anchor view. The default page header uses a plain hairline border; silver is opt-in.

Mode F is the header analogue of Mode B (top-edge stripe on a card) — same gradient, repositioned to the bottom of a page-level header so the rest of the page reads as content "underneath" the brand band.

### CSS Implementation

```css
.ne-header-silver {
  position: relative;
  background: var(--ne-bg-base);
  border-bottom: 1px solid var(--ne-border-hairline);
}

.ne-header-silver::after {
  content: '';
  position: absolute;
  inset-inline: 0;
  bottom: 0;
  height: 2px;
  background: var(--ne-silver-edge-strip);
  pointer-events: none;
}
```

### React Usage

```tsx
import { PageHeader } from '@/components/ui/page-header';
import { Button } from '@/components/ui/button';

<PageHeader
  variant="silver"
  eyebrow="Q2 2026"
  title="Investment Proposal"
  subtitle="Prepared for Acme Capital"
  actions={<Button variant="silver">Download PDF</Button>}
/>
```

### Optional: Silver Title Text

For ultra-premium contexts (one per project, max), the page title can render with a silver text gradient via `silverTitle` on `<PageHeader>`. This consumes a brand moment — use sparingly.

```tsx
<PageHeader variant="silver" silverTitle title="Annual Report 2026" />
```

### When To Apply

| Context | Silver header? |
|---------|----------------|
| Proposal pages (one-off branded document views) | YES |
| Landing page hero header | YES |
| Report cover / dashboard "report mode" | YES |
| Premium dashboard zone anchor (e.g., "Buyer Insights" in a multi-zone dashboard) | YES — at most one per app |
| Standard CRUD page header | NO |
| Settings / admin pages | NO |
| Modal / drawer header | NO — drawers use Mode A on the header card |

### Combination Rules

- **Mode F + Mode E button**: YES, recommended — proposal hero with silver header + silver primary CTA reads as a matched unit.
- **Mode F + Mode B card on the same page**: NO — two stripes compete. Pick one as the page anchor.
- **Mode F + `silverTitle`**: YES, but reserved for the strongest single page in the project.

### Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Silver header on every dashboard page | Becomes wallpaper, kills the signature | One per project, on the page that anchors the brand moment |
| Silver header + silver Mode B hero card together | Two competing stripes | Header OR hero card — never both |
| Silver header with bright top-of-header stripe | Inverts the convention; reads as a Windows 95 title bar | Stripe lives at the **bottom** of the header only |
| `silverTitle` everywhere | Loses meaning, looks like a theme | One titled page per project |

---

## Mode G — Silver Edge Button (Gradient Ring)

**Rule**: A 1px metallic-gradient ring around a neutral-fill button. The button itself stays warm off-white (`--ne-bg-base`); the silver lives only in the edge ring. Sits between the brand-color default (heavy color) and Mode E silver fill (heaviest premium).

The ring fades from 65% to 100% opacity on hover. **Static — no continuous animation.** The "shimmer" perception comes from the gradient's diagonal angle catching simulated light at 135° (`#D4D7DC → #B8BCC2 → #D4D7DC`), not from any motion. Synthesised after audit of two 21st.dev community components (`liquid-metal-button`, `gradient-borders-button`); the WebGL shader path was rejected for violating the static-silver rule, the gradient-borders structure was kept and ported to NewEarth tokens.

### CSS Implementation

Lives as the `.ne-button-silver-edge` utility class in `tokens.css`. Uses the same mask-composite trick as Mode A on cards — the gradient is painted on a 1px ring and the interior is masked out so the parent's `bg-base` shows through.

```css
.ne-button-silver-edge {
  position: relative;
  background: var(--ne-bg-base);
}

.ne-button-silver-edge::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  padding: 1px;
  background: var(--ne-silver-gradient);
  -webkit-mask:
    linear-gradient(#fff 0 0) content-box,
    linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
          mask-composite: exclude;
  pointer-events: none;
  opacity: 0.65;
  transition: opacity var(--ne-duration-base) var(--ne-ease-in-out);
}

.ne-button-silver-edge:hover::before,
.ne-button-silver-edge:focus-visible::before {
  opacity: 1;
}
```

`border-radius: inherit` on the `::before` picks up whatever radius the button itself has (default `rounded-md` → 6px). Disabled state is handled by the base button's `disabled:opacity-50` cascading into the `::before` via alpha compositing — no separate disabled rule needed.

### React Usage

```tsx
import { Button } from '@/components/ui/button';

<Button variant="silverEdge">View Proposal</Button>
<Button variant="silverEdge" size="lg">Open Report</Button>
```

### When To Apply

| Context | Silver-edge button? |
|---------|---------------------|
| Premium secondary CTA next to a Mode E silver primary | YES — "Schedule Call" beside "Download PDF" |
| Premium-context primary where Mode E would over-signal | YES — proposal page that already has Mode F header doesn't need Mode E too |
| Brand-anchor dashboard toolbar (single zone) | YES — up to 2 per viewport |
| Dense operational dashboard toolbar | NO — same fatigue rule as Mode E |
| Form submit in admin panel | NO |
| Modal "Confirm" / "Cancel" | NO |
| Any Atelier Dark surface | NO — Atelier signature is bronze, not silver. Use the Atelier bronze button instead |

**Density rule**: up to 2 per visible viewport (looser than Mode E's 1). The edge ring is quieter than fill, so two can coexist without reading as decoration. Three or more = revisit the visual hierarchy.

### Three-Tier Silver Button Spectrum

| Variant | Visual weight | Primary use | Density |
|---------|--------------|-------------|---------|
| `silverOutline` | Light — solid 1px silver line, transparent fill | Utility silver companion to Mode E | No hard cap — but still premium-context only |
| `silverEdge` (Mode G) | Medium — gradient metallic ring, neutral fill | Premium secondary OR quieter primary | Max 2 per viewport |
| `silver` (Mode E) | Heavy — brushed-silver fill | Premium hero/anchor primary CTA | Max 1 per viewport |

### Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Silver-edge buttons across an operational dashboard toolbar | Decorative chrome at scale, dilutes signature | Default brand-color buttons; reserve silver-edge for premium contexts |
| Adopting `liquid-metal-button` / WebGL-shader buttons | Continuous animation = NFT energy, banned by the static-silver rule | Mode G is the static answer to "shimmery silver button" |
| Mode G + Mode E + Mode F all on one viewport | Three competing silver moments | Pick the dominant: header stripe + ONE silver action (E or G), not both |
| Mode G in Atelier Dark | Silver clashes with bronze signature; gradient token is not Atelier-aware | Use Atelier bronze button instead (future Atelier component template) |
| Animating the ring opacity on a loop | Continuous = NFT energy. Transition on hover = OK | Hover/focus opacity transition only; never `@keyframes` or `infinite` |

---

## Combination Rules

| Combination | Allowed? | Notes |
|-------------|----------|-------|
| A + C (edge + hover ring) | YES — **default for premium interactive cards** | The recommended pattern |
| A + B (edge + top stripe) | NO | Visually loud — pick one |
| B + C (top stripe + hover ring) | YES — for hero card with interaction | |
| A + D (edge + divider) | YES | Different surfaces, no conflict |
| F + E (silver header + silver fill button) | YES — recommended for proposal hero | The matched-unit pattern |
| F + G (silver header + silver-edge button) | YES — quieter alternative to F + E | Use when Mode E would over-signal under the silver header |
| E + G (silver fill + silver-edge on same viewport) | RARE — only if hierarchy reads cleanly (one fill primary, one edge secondary) | Default to E + `silverOutline` instead |
| All seven modes | NO | Over-signaling |

**Default for most premium cards**: A (edge) + C (hover ring). This is the "NewEarth premium card" recipe.

**Default for proposal/brand-anchor pages**: F (silver header) + E (silver fill primary CTA) + `silverOutline` secondary. Switch the primary to G (silver-edge) when E feels too aggressive for the surface.

---

## Anti-Patterns (Silver Done Wrong)

| Wrong | Why | Right |
|-------|-----|-------|
| Applying Mode A to every card | Dilutes the signature; becomes noise | Only on premium surfaces |
| Using pure `#888` or `#999` instead of the gradient | Reads as "gray", not "metal" | Use the gradient with `#D4D7DC → #B8BCC2 → #D4D7DC` |
| Chrome-like bright silver (`#F0F0F0 → #FFFFFF`) | Reads as cheap mirror/plastic | Keep it in the `#B8BCC2 / #C0C3C7 / #D4D7DC` range — brushed aluminium, not chrome |
| Animated silver (shimmer, gradient-flow) | Reads as NFT / crypto landing page | Silver is STATIC. It shines because of its position, not animation |
| Silver as a background fill | Too heavy, takes over | Silver is EDGE, never FILL |
| Silver on semantic-colored surfaces | Mixes identity with state — confuses meaning | Silver only on neutral-surface cards |
| Rainbow / iridescent silver | Absolutely never. | `#B8BCC2` only. |

---

## Implementation Checklist

When applying silver to a new component:

```
□ Does this component warrant the signature? (Premium card? Hero? Drawer header? Premium CTA?)
□ Am I using the locked silver values from design-tokens.md?
□ Am I using the gradient technique (not a flat gray)?
□ Is the base surface neutral (#FBFBFA or #F7F6F3)? Silver on semantic colors is forbidden.
□ Did I pick ONE mode (A, B, C, D, E, F, or G) or an approved combination from the table?
□ If hover ring (C): does the reserved outline space prevent layout shift?
□ If card edge (A) or button edge (G): does mask-composite render correctly in Chrome and Safari?
□ If button (E or G): density check — at most 1 Mode E or 2 Mode G per viewport?
□ If button: are any animations transitions only (hover/focus state changes), never @keyframes loops?
□ If page header (F): is this the ONE brand-anchor page for the project, or am I diluting the signature?
□ Does it survive dark mode (auto-handled by token overrides) AND not collide with Atelier Dark (which uses bronze, not silver)?
```

---

## Future Work (Reserved)

- **Dark mode silver**: the current values are tuned for warm off-white backgrounds. Dark mode will need a separate silver stack (likely lighter: `#E5E8ED → #C9CDD3 → #E5E8ED` for visibility against dark neutrals). Defer until dark mode is in scope.
- **Motion silver**: if a client specifically requests animated brand moments (hero videos, proposal intros), a separate "motion silver" token may be introduced. Not for product UI.
- **Print stylesheets**: proposals and reports printed to PDF should preserve silver via SVG or high-DPI raster. CSS gradients do not print reliably.

---

*This is the NewEarth fingerprint. Treat it carefully — over-use destroys it.*
