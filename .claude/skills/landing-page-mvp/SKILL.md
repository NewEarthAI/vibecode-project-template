---
name: landing-page-mvp
description: |
  GSAP-powered cinematic landing page architect. Scaffolds complete React 19 + Vite +
  Tailwind + GSAP projects with scroll-driven animations, parallax, and theatrical section
  transitions. Provides 8 aesthetic presets (A-H) each with coupled motion choreography,
  color system, and typography pairing. Runs executable quality gates post-build.
  DISAMBIGUATION: This is the cinematic/animation-heavy tier for scroll-driven pages.
  For general frontend UI without scroll-driven animation requirements, the frontend-design
  plugin handles it instead.
  Use when: "cinematic landing page", "GSAP animations", "scroll-driven page",
  "parallax landing page", "motion-heavy page", "premium animated site",
  "theatrical scroll experience", "animated hero with GSAP".
version: 2.3
classification: capability-uplift
created: 2026-03-10
updated: 2026-07-08
triggers:
  - "cinematic landing page"
  - "GSAP landing page"
  - "scroll-driven landing page"
  - "parallax landing page"
  - "motion-heavy landing page"
  - "animated landing page with GSAP"
  - "premium animated site"
  - "theatrical scroll experience"
parameters:
  - name: preset
    type: enum
    values: [auto, A, B, C, D, E, F, G, H, custom]
    default: auto
    description: |
      Aesthetic preset. "auto" infers from user brief. "custom" composes
      a motion language from the user's description using the 2 closest presets.
  - name: output_dir
    type: path
    default: "."
    description: "Directory to scaffold the Vite project in"
  - name: include_seo
    type: boolean
    default: true
    description: "Generate SEO meta tags, Open Graph, JSON-LD during scaffold"
  - name: noise_overlay
    type: enum
    values: [auto, on, off]
    default: auto
    description: |
      SVG grain texture overlay. "auto" enables for texture presets
      (A, B, D, H) and disables for clean presets (C, E, F, G).
  - name: run_quality_gate
    type: boolean
    default: true
    description: "Run scripts/quality-gate.sh after build to verify output"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
paths:
  - "clients/**"
validated_on:
  - "Dark tech SaaS with scroll-driven animations (Preset B — midnight luxe)"
  - "Warm bakery brand with gentle organic motion (Preset E — warm harbor)"
  - "Clinical biotech startup with exact animations (Preset F — clinical exact)"
  - "Playful children's toy brand with bouncy kinetics (Preset G — playful kinetic)"
---

# Cinematic Web Architect V2.2

## Role

Act as a Senior Creative Technologist and Lead Frontend Engineer. Architect high-fidelity,
cinematic landing pages where every scroll is intentional, every animation weighted, every
interaction magnetic. Each site must feel like a meticulously crafted digital experience
that embodies the brand's unique personality — not a generic template.

Eradicate generic AI layout patterns. Match motion language to brand personality.

## Disambiguation — frontend-design Plugin

This skill and the `frontend-design` plugin serve different tiers of frontend work:

| Skill | Scope | Trigger Signal |
|-------|-------|---------------|
| **landing-page-mvp** | Cinematic GSAP pages with scroll choreography | "cinematic", "GSAP", "scroll-driven", "parallax", "motion-heavy" |
| **frontend-design** | General UI — components, pages, apps with broad aesthetic range | "build a page", "web component", "UI", "interface", general frontend |

**When both could apply**: If animations and scroll experience are central to the brief,
this skill wins. If the request is about UI design without animation specificity,
defer to frontend-design.

**Composition**: This skill owns the cinematic layer (GSAP timelines, scroll choreography,
theatrical transitions). It may reference frontend-design principles for component-level
decisions (spacing, accessibility, typography selection).

## Agent Flow — MUST FOLLOW

When invoked, pause and ask these 5 questions. **Do not write code until answered.**

1. **"What is the brand name and its one-line purpose?"**
2. **"Define the Aesthetic Direction."** Choose a Preset (A-H below), describe a custom vibe, OR share an existing website URL for brand extraction (experimental).
3. **"What are your 3 key value propositions?"** Data-driven props work best: "99.9% uptime" > "we are reliable."
4. **"What is the primary Call to Action (CTA) for visitors?"**
5. **"Any specific requirements?"** (Dark/light mode preference, existing brand colors, content sections, target audience.)

If the user provides a custom vibe instead of a preset letter, infer the closest preset
or compose a custom motion language from the 2 nearest presets (see `references/motion-tokens.md`).

## Pro-Tier Inputs Guide

| Input Field | How to Make It Cinematic |
|------------|------------------------|
| **Aesthetic Direction** | Use "The Hybrid Method" — combine two eras/styles. Example: "1950s Swiss Typography meets 2024 dark-mode SaaS with one Electric Violet accent." |
| **Animations** | Describe the FEEL, not the code. Example: "The site should feel heavy and liquid — elements have physical mass when they slide in." |
| **Value Props** | Give data-driven specifics. "0ms latency scaling" or "99.9% accuracy" — the AI uses these to generate contextual micro-animations. |

## Aesthetic Presets

Each preset couples **color + typography + motion choreography** as a unified system.
Details in `references/` — here is the selection guide.

### A — "Organic Tech"
Dark forest palette, Space Grotesk + Inter. Heavy/liquid motion (power4.out, 1.4s).
**Noise**: Yes. **Feel**: Weighted, fluid. Elements have mass and settle into place.
**Best for**: DevTools, developer platforms, green-tech, data infrastructure.

### B — "Midnight Luxe"
True black + soft violet, Playfair Display + Source Sans 3. Luxury reveal (expo.inOut, 1.6s).
**Noise**: Yes. **Feel**: Slow dramatic unveiling. Every element earns its place.
**Best for**: Luxury brands, fashion-tech, premium SaaS, fintech.

### C — "Brutalist Signal"
Light stone + signal red, Bebas Neue + IBM Plex Mono. Magnetic/snappy (back.out, 0.5s).
**Noise**: No. **Feel**: Punchy, immediate. Snap-in with overshoot, raw energy.
**Best for**: Creative agencies, bold startups, media companies, crypto.

### D — "Vapor Clinic"
Deep indigo + soft indigo, Syne + DM Sans. Liquid/ethereal (sine.inOut, 1.2s).
**Noise**: Yes. **Feel**: Dreamlike, floating. Elements drift rather than snap.
**Best for**: Wellness-tech, meditation apps, VR/AR, ambient products.

### E — "Warm Harbor"
Warm cream + orange, Fraunces + Nunito. Warm/organic (expo.out, 1.2s, long stagger).
**Noise**: No. **Feel**: Gentle, unhurried. Like a warm hand guiding you through.
**Best for**: Bakeries, cafes, hospitality, family brands, lifestyle.

### F — "Clinical Exact"
Pure white + sky blue, Plus Jakarta Sans. Crisp/exact (power2.out, 0.4s, tight stagger).
**Noise**: No. **Feel**: Fast, exact, no wasted frames. Surgical timing.
**Best for**: Biotech, healthtech, medical devices, fintech dashboards.

### G — "Playful Kinetic"
Yellow-50 + rose, Outfit + Quicksand. Bouncy/energetic (elastic.out, 0.9s).
**Noise**: No. **Feel**: Springy, exuberant. Elements bounce into place with personality.
**Best for**: Kids brands, toy companies, edtech, gaming, fun consumer apps.

### H — "Editorial Noir"
Near-black + white-as-accent, Instrument Serif + Instrument Sans. Dramatic (expo.inOut, 1.0s, char-by-char text).
**Noise**: Yes (film grain). **Feel**: Magazine editorial. Typography IS the animation.
**Best for**: Publications, media brands, photography, architecture firms.

## Technical Architecture

**Stack**: React 19, Vite, Tailwind CSS v4 (`@tailwindcss/vite` plugin + `@theme` blocks), GSAP 3 + ScrollTrigger, Lucide React, clsx.

**Tailwind v4 Note**: Tailwind v4 uses `@import "tailwindcss"` in CSS and `@theme` blocks
for custom tokens. There is NO `tailwind.config.js` — all config is CSS-native. Install
via `npm i -D tailwindcss @tailwindcss/vite` and add the plugin to `vite.config.js`.

### GSAP Rules (MANDATORY)

1. **useGSAP()** from `@gsap/react` for ALL animations. Never raw `useEffect` + GSAP.
   Because: React 19 StrictMode double-renders; useGSAP handles cleanup automatically.
2. **`gsap.defaults({ force3D: true, overwrite: "auto" })`** in the entry point.
   Because: GPU-accelerated transforms prevent jank; overwrite prevents conflicts.
3. **`gsap.matchMedia()`** for responsive breakpoints.
   Because: Desktop parallax on mobile causes scroll jank and layout thrashing.
4. **`ScrollTrigger.refresh()`** after async image loads.
   Because: picsum.photos loads asynchronously; scroll positions miscalculate without refresh.
5. **Free-tier only** — ScrollTrigger, Observer, Draggable. No SplitText, MorphSVG, DrawSVG
   unless user confirms Club GreenSock license.
6. **`prefers-reduced-motion` is MANDATORY (a11y, not optional)** — every animation ships a
   reduced-motion branch via `gsap.matchMedia({ reduce: "(prefers-reduced-motion: reduce)" })`
   that sets the final state (or `duration: 0`). Rule 3's `matchMedia` is for *responsive*
   breakpoints; this is a *separate* obligation. A cinematic page that ignores reduced-motion
   is non-compliant, however beautiful. (This is distinct from — and stricter than — most
   motion skills, which omit it entirely.)
7. **Motion is earned, even here** — see "Restraint Within Cinema" below. Cinema is the point
   on this tier, but ambient/decorative/"because it looked cool" motion is still cut. Tag each
   beat with a `/* motion-earned: <narrative|attention|brand-feel|feedback> */` comment.

See `references/gsap-patterns.md` for implementation patterns and code examples.

### Motion Token System

Each preset defines 6 motion categories: entrance, hover, scroll, parallax, text, exit.
**Motion MUST match the selected preset.** A warm bakery with snappy tech animations = incoherent.

Read `references/motion-tokens.md` for the full easing/duration/stagger map per preset.
When composing custom presets, document the composition in a code comment.

## Restraint Within Cinema — NewEarth Discipline (v2.3)

> This is the cinematic/marketing tier, so it has more motion latitude than the product-UI
> house (`ui-design-system`). But "cinematic" is not "busy", and a landing hero is the #1
> place AI-tell copy and over-decoration show. This section imports the design-suite discipline
> at the level a marketing page needs — it does NOT impose the product-UI rulebook. It composes
> the design suite rather than duplicating it (the canonical rules live in those skills).

**1. Motion is earned (cinematic recast).** Every beat must serve **narrative, attention,
brand-feel, or feedback**. Cut ambient loops, decorative drift, and "because it looked cool."
The instinct is one orchestrated hero moment + restrained section reveals — not five competing
animations. Carry the `/* motion-earned: <reason> */` comment (GSAP Rule 7) so the intent is
auditable. `/design-review` grades for its presence.

**2. Reduced-motion is mandatory** — GSAP Rule 6. Not optional, even on a showcase page.

**3. Restraint counters** — landing pages over-decorate more than any surface. Apply the
mechanically-counted checks in
[`ui-design-system/references/restraint-preflight.md`](../ui-design-system/references/restraint-preflight.md):
eyebrow ≤ ceil(sections/3), zigzag ≤ 2 consecutive splits, ≥ 4 distinct layout families per 8
sections, marquee ≤ 1/page, hero ≤ 4 text elements + subhead ≤ 20 words, bento cells = content
count. Consistency locks: one accent, one radius scale, one theme.

**4. Anti-AI-tell COPY (universal — applies on every tier).** Hero headlines + stat rows are
where "a robot wrote this" leaks. No **em-dash** (`—`) in generated UI copy; no **invented
precise numbers** (`92%`, `4.1×`) unless real and sourced; run the Copy NEVER List. Canonical
rules: [`ui-design-system/references/anti-vibe-coded.md`](../ui-design-system/references/anti-vibe-coded.md)
#23–25. Mechanical check: `bash ../ui-design-system/scripts/audit-restraint.sh <project>`.

**5. Modern web-platform standards + award lens.** The quality gate checks bundle size but not
INP or the award bar. For a page that's *judged on* exactly this, also apply
[`design-review/references/modern-web-platform.md`](../design-review/references/modern-web-platform.md):
**INP** ≤ 200ms (not FID), `dvh` for full-height heroes, `:focus-visible`, and — where a reveal
is simple — prefer **CSS scroll-driven animations** (`animation-timeline: view()`, behind
`@supports`) over a GSAP ScrollTrigger (lighter, no JS). Score the result against the
**Awwwards weighting** (Design 40 / Usability 30 / Creativity 20 / Content 10) — usability +
content are 40% combined; a beautiful page that's hard to use can't top-score.

**6. House alignment (NewEarth-brand pages).** For NewEarth's *own* sites prefer the restrained
presets — **B (Midnight Luxe)**, **F (Clinical Exact)**, **H (Editorial Noir)** — with DM Sans /
Sora, per the 2026-06-05 NewEarth landing (worked run below). The **Space Grotesk** pairing
(preset A) and the **overshoot** presets (**C Brutalist Signal** `back.out`, **G Playful Kinetic**
`elastic.out`) are *intentional client-brand personalities* — keep them for clients whose brand
genuinely calls for that energy; they are NOT the NewEarth house default. (Space Grotesk is a
product-UI AI-tell in `ui-design-system`; on a client marketing page it's a legitimate brand
choice — tier-appropriate, not a contradiction.)

Composes with the full NewEarth Design Suite: `/design-review` audits a built landing page
against all of the above; `ui-design-system` owns the product-UI motion + restraint canon
this section imports.

### SVG Noise Overlay (CONDITIONAL)

Apply the SVG noise filter only when the preset calls for texture:
- **Enable**: Presets A, B, D, H (dark/textured aesthetics)
- **Disable**: Presets C, E, F, G (clean/bright aesthetics)
- **Override**: User can force on/off via the `{{noise_overlay}}` parameter

```jsx
{/* Only render when preset uses noise */}
{useNoise && (
  <svg className="fixed inset-0 pointer-events-none z-50 opacity-[0.03]">
    <filter id="noise"><feTurbulence baseFrequency="0.65" /></filter>
    <rect width="100%" height="100%" filter="url(#noise)" />
  </svg>
)}
```

### Images

Use `https://picsum.photos/seed/[DESCRIPTIVE_WORD]/WIDTH/HEIGHT` for placeholders.
Always add `loading="lazy"` for below-fold images and meaningful `alt` text.

### SEO Meta (Generated During Scaffold)

When `{{include_seo}}` is true, generate in `index.html` during scaffold — not as afterthought:
- `<title>` and `<meta name="description">` from brand name + purpose
- Open Graph + Twitter Card meta tags
- JSON-LD schema (Organization, Product, or LocalBusiness — inferred from brand type)
- Font loading hints for Google Fonts
- `<link rel="preload">` for hero font

See `references/seo-templates.md` for templates.

### Color System Integration

Each preset's colors are defined as CSS custom properties and extended into Tailwind config.
See `references/color-systems.md` for the full palette per preset.

```css
@import "tailwindcss";

:root {
  /* Tokens change per preset — see references/color-systems.md */
  --bg-primary: #fef7ed;   /* example: Warm Harbor cream */
  --fg-primary: #422006;
  --accent: #ea580c;
}

@theme {
  --font-display: "Fraunces", serif;
  --font-body: "Nunito", sans-serif;
  --color-bg-primary: var(--bg-primary);
  --color-fg-primary: var(--fg-primary);
  --color-accent: var(--accent);
}
```

### Typography Integration

Each preset pairs a display + body + optional mono font from Google Fonts.
See `references/typography-pairings.md` for the full map.

## Scaffold Sequence

1. `npm create vite@latest {{output_dir}} -- --template react`
2. Install deps: `npm i gsap @gsap/react lucide-react clsx` AND `npm i -D tailwindcss @tailwindcss/vite`
3. Add `tailwindcss()` to `vite.config.js` plugins array
4. Delete Vite boilerplate: `App.css`, `assets/react.svg`, `public/vite.svg`
5. Write `index.css` with `@import "tailwindcss"` + `@theme` block + preset color tokens
6. Generate `index.html` with SEO meta (if enabled)
7. Build component structure:
   - `App.jsx` — Layout, noise overlay (if enabled), GSAP defaults
   - `components/Hero.jsx` — Hero section with preset entrance animation
   - `components/Features.jsx` — Value prop section with scroll-triggered reveals
   - `components/CTA.jsx` — Call-to-action with hover animation
   - `components/Footer.jsx` — Minimal footer
8. Apply preset motion tokens to all animated components
9. Run `npm run build` to verify
10. Run quality gate (if enabled)

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `useEffect(() => { gsap.to(...) }, [])` | Breaks in React 19 StrictMode — double-render, no cleanup, ScrollTrigger leaks | `useGSAP(() => { gsap.to(...) }, { scope: ref })` |
| Same motion for all presets (e.g., always `power3.out, 0.8s`) | Motion language must match brand personality — a warm bakery needs different choreography than a brutalist agency | Read `references/motion-tokens.md` and apply preset-specific easings |
| `import "gsap/all"` | Imports entire GSAP bundle including paid plugins, bloats bundle | `import gsap from "gsap"; import { ScrollTrigger } from "gsap/ScrollTrigger"` |
| SVG noise overlay on every page | Film grain fights against clean, clinical, warm, or playful aesthetics | Check preset noise flag — only enable for A, B, D, H |
| Hardcoding all animations at mount | Wastes CPU for below-fold sections; long initial paint | Use IntersectionObserver or ScrollTrigger for lazy init |
| `style={{ color: "red" }}` inline styles | Breaks Tailwind-first approach, harder to maintain, can't responsive-modify | Use Tailwind classes or CSS custom properties |
| Desktop parallax without `matchMedia()` | Scroll jank on mobile, layout thrashing, broken touch gestures | Wrap desktop animations in `gsap.matchMedia("(min-width: 769px)")` |
| Using SplitText without license check | Club GreenSock paid plugin — build fails in CI without license | Use manual `<span>` word wrapping, or confirm user has Club GreenSock |
| `style={{ direction: "rtl" }}` for alternating layouts | Inline styles get flagged by quality gate and break Tailwind-first | Use conditional JSX rendering: `{isReversed ? <>{content}{image}</> : <>{image}{content}</>}` |

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| `npm create vite` fails | Node.js not in PATH, npm not installed | Check `node -v` and `npm -v`; install via nvm if missing |
| `Cannot find module 'gsap'` | Dependencies not installed after scaffold | Run `npm install` in project root |
| Port 5173 already in use | Another Vite dev server running | Kill process on port: `lsof -ti:5173 \| xargs kill` or use `--port 5174` |
| ScrollTrigger positions wrong | Images loaded after layout calculation | Add `ScrollTrigger.refresh()` in window load handler |
| `useGSAP is not a function` | `@gsap/react` not installed | `npm i @gsap/react` |
| Build fails with JSX errors | Missing React import in Vite config | Verify `@vitejs/plugin-react` in vite.config.js |
| Animations stutter on mobile | No `matchMedia()` cleanup + heavy parallax | Add responsive breakpoint with simplified mobile animations |

## Token Economics

Full scaffold with GSAP + SEO + 8 presets is token-intensive:
- **Scaffold + single preset**: ~15K-20K output tokens
- **With quality gate verification**: +3K-5K tokens
- **Full build + fix cycle**: ~25K-35K total

To reduce cost: provide clear brief upfront (fewer iterations), select a preset rather
than "custom" (avoids composition reasoning), skip SEO if not needed.

## Quality Gate

After building, run the executable verification script:

```bash
bash .claude/skills/landing-page-mvp/scripts/quality-gate.sh
```

This checks 7 gates: dependencies, build, GSAP safety, accessibility, responsive
breakpoints, code hygiene, and bundle size. See `scripts/quality-gate.sh` for details.

**What the gate cannot verify** (requires human review):
- Aesthetic quality and "cinematic" feel
- Motion coherence with brand personality
- Production Lighthouse score (needs deployed environment)
- Real-world load performance under network conditions

For aesthetic verification, reference `evals/aesthetic-criteria.json` — per-preset
should/should-not descriptors for reviewer comparison.

## Self-Review Checklist

Before presenting the final output, verify:
- [ ] Motion language matches the selected preset (check `references/motion-tokens.md`)
- [ ] Color system matches the selected preset (check `references/color-systems.md`)
- [ ] Typography matches the selected preset (check `references/typography-pairings.md`)
- [ ] Noise overlay is correctly enabled/disabled for the preset
- [ ] All `useGSAP()` — no raw `useEffect` with GSAP
- [ ] `gsap.defaults({ force3D: true })` is set
- [ ] `gsap.matchMedia()` handles mobile breakpoint
- [ ] `ScrollTrigger.refresh()` fires after image loads
- [ ] SEO meta generated in `index.html` (if enabled)
- [ ] Quality gate passes with 0 failures
- [ ] Output matches aesthetic criteria for the selected preset
- [ ] Every animation has a `prefers-reduced-motion` branch (GSAP Rule 6) + a `/* motion-earned */` comment (Rule 7)
- [ ] Restraint counters pass (eyebrow/zigzag/layout-variety/hero-word-limit — see Restraint Within Cinema #3)
- [ ] No em-dash + no invented stats in hero/UI copy (anti-vibe-coded #23–25); `audit-restraint.sh` run
- [ ] INP-aware (not FID), `dvh` heroes, `:focus-visible`; scored against the Awwwards lens for award-grade briefs
- [ ] House-brand page uses a restrained preset (B/F/H) + DM Sans; overshoot/Space-Grotesk reserved for client brands that call for it

## Worked Runs (gotchas from real builds)

### 2026-06-05 — NewEarth AI agency landing page (premium-minimal, custom preset)

Reusable for **client** landing pages (a sellable capability). Build:
`sites/newearth-landing/` in Agency-Main. Custom preset = B (Midnight-Luxe dark +
luxury reveal) + H (Editorial-Noir masked-line headline), palette/type overridden
to a brand brief (silver-on-carbon + one restrained signal colour, Sora/Inter).

Gotchas worth keeping:

1. **Use the `react-ts` template, not `react`.** The brief mandated a `npm run
   typecheck` gate; the skill's default JS scaffold makes that gate vacuous (nothing
   to check = silent no-op, the exact class `typecheck-and-review-gates.md` warns of).
   Add `"typecheck": "tsc --noEmit -p tsconfig.app.json"` to scripts.
2. **`@fontsource-variable/*` side-effect imports** need a `declare module` stub
   (`src/fontsource.d.ts`) or TS errors TS2882. Variable fonts = one import, all weights.
3. **Optimise raster logos to WebP** with `sharp` (devDep) — a 2048² chrome PNG was
   1.46MB; a 1280² WebP @q92 is 214KB (-85%), and 1280 covers @2x/@3x of a ~340px hero.
   Clean-low-res cut-out upscaled beats dirty-high-res (a render with a baked dark bg
   has unusable alpha for compositing).
4. **Chrome shine-sweep from a flat raster**: overlay a `mask-image: url(logo)` div
   over a moving linear-gradient, `mix-blend-mode: screen` → highlight rides only the
   logo's alpha shape. No vector needed. (chrome logos don't vectorise — keep PNG/WebP.)
5. **Screenshotting reveal-on-scroll content for review**: launch the browser with
   `reducedMotion: 'reduce'` so `prefers-reduced-motion` guards set all reveal targets
   visible immediately → full-page screenshot shows everything. Capture the hero in
   normal motion separately (wait ~3s for the load timeline).
6. **No Playwright MCP? Use `playwright-core` + the cached chromium headless-shell**
   (`~/Library/Caches/ms-playwright/chromium_headless_shell-*/.../chrome-headless-shell`)
   via `executablePath` — no browser download. See `scripts/shoot.mjs` + `smoke.mjs`.
7. **Escalatable motion = a config object** (`motion.config.ts`) of named beat flags
   (`heroSweep: once|loop|hover|off`, `heroTilt: settle|pointer|off`, count-ups, grain).
   Build quiet-spectacle; dial beats up in the review pass with zero re-architecture.
8. **Tailwind v4: wrap ALL base resets in `@layer base` — this is load-bearing.**
   `@import 'tailwindcss'` puts every utility inside a cascade *layer*. In CSS, an
   UNLAYERED rule beats ANY layered rule regardless of specificity. So a hand-written
   `p { margin: 0 }` / `h1,h2,h3 { margin: 0 }` sitting outside a layer silently kills
   EVERY `mt-*`/`mb-*` utility on those elements — site-wide, no error, no warning.
   Symptom: you bump a margin class and nothing moves. Fix: `@layer base { …resets… }`.
   (2026-06-08: this exact bug made every paragraph/heading margin dead; gap utilities
   read 0px in-browser until the resets were layered.)
9. **Measure spacing/alignment in-browser, never by eye on a scaled screenshot.** A
   `getBoundingClientRect` probe via `playwright-core` gives exact px: element centre vs
   `innerWidth/2`, gap = nextTop − prevBottom. This caught the @layer bug above (gaps =
   0 despite large classes) and nailed nav centring to ±1px. Screenshots confirm;
   numbers diagnose.
10. **Centring the MIDDLE of an odd nav (logo · links · CTA).** `justify-between` puts
    the links group wherever the unequal logo/CTA widths leave it — not page centre. To
    put the middle link dead-centre (in line with a centred hero mark): absolutely
    position the links group `-translate-x-1/2` and correct for the side-item width
    asymmetry with a measured `left: calc(50% + Npx)` (the centre item ≠ group centre
    when flanking labels differ in width). Verify with the measure probe → ±1px.
11. **CSS-comment trap: a `*/` token inside a comment self-closes it.** Writing the
    pattern m-t-asterisk-slash-m-b-asterisk inside `/* … */` ends the comment early →
    "Missing opening (" build error. Write "margin/padding utilities" in prose instead.
12. **Adjacent centred statement blocks: match their `max-width`.** Two centred sections
    can share an identical centre (off=0) yet read as "misaligned" because their widths
    differ (e.g. `max-w-4xl` vs `max-w-3xl`) so left/right edges don't line up. Give
    sibling statement blocks the same max-width so the column is visually continuous.

Status: built + prod-build smoke PASS; go-live gated on `vercel login` + apex DNS.
Did NOT `/push-to-template` (single use ≠ proven; push gate is the 2nd client page).

---

## Hero Gradient Headline — Field Gotchas

Field-tested on a gradient "animated word" hero (a headline where one word cycles in a colour gradient). Three lessons for any premium gradient headline or rotating-word hero — they apply whether the motion lib is GSAP or Framer Motion.

### Gradient headline descenders — `bg-clip-text` shears g / p / y
`bg-clip-text text-transparent` paints the gradient into the glyph shapes, but only across the element's OWN box. Tailwind's text-size utilities (`text-6xl` / `text-7xl` / …) ship a coupled `line-height: 1`, and — being responsive utilities — they WIN over a separate `leading-[1.1]` on source order at that breakpoint. So the paint box ends up exactly font-size tall, with no room below the baseline, and descenders render transparent — sheared flat. **Fix: the descender room goes on the GRADIENT span itself** (a wrapper's padding can't extend a child's paint box), as `padding-bottom` in `em` so it holds at every breakpoint — its padding box is what the gradient fills. Padding is also layout space, so it floats the next line down; reclaim it with a **negative `margin-bottom`** (tuned by measuring) and set the reserved line-height to match the padded box so a word-swap never jumps. Worst-case test word: one with both a `p` and a `g`.

### Rotating-word headline under reduced-motion — keep cycling
When the rotation IS the message (N words cycling to say N things), do NOT freeze on one word under `prefers-reduced-motion` — that silently kills the whole message for every reduced-motion user. An opacity crossfade is not the motion that setting targets — it is about vestibular *movement* (translate / scale / parallax / spin), and Framer Motion's `reducedMotion="user"` keeps opacity/colour running anyway. So under reduced-motion keep the words cycling; drop *movement*, never the *content change*. (A purely decorative 2-phase reveal may still go static — the rule is specifically about message-carrying rotators.)

### Verify hero fixes against pixels, not DOM boxes
`getBoundingClientRect()` reports the *line box* — it cannot see glyph-ink overflow or gradient-clip, so a "the box says it's fine" check passes a visibly-clipped descender. Measure the real thing with canvas `measureText` on the **deployed** preview: `fontBoundingBoxAscent + fontBoundingBoxDescent` is the box the glyphs need; compare it to the painted box (`line-height + padding-bottom`) — any positive shortfall means clipped. The same tool balances stacked heading lines: measure each line's ink cap-top and descender-bottom, then equalise the gap above vs below. Pixels/metrics, not bounding boxes; deployed preview, not just local.
