# Modern Web-Platform Standards — Grading Reference for /design-review

> **last-verified: 2026-06-24** · **reverify-trigger: any Chrome/Safari major release, or quarterly.**
> This file encodes platform standards inline (so the audit doesn't depend on a live fetch). The trade-off is staleness: standards shift. When the trigger fires, WebFetch the upstream sources below and reconcile. A stale frozen copy is a QUIET failure — the date above is how you catch it. To confirm the latest at audit time, optionally WebFetch `vercel.com/design/guidelines` + `web.dev/articles/inp`.

---

## 1. Core Web Vitals (current — FID is retired)

| Metric | Good | Needs work | Poor | Notes |
|--------|------|-----------|------|-------|
| **INP** (Interaction to Next Paint) | ≤ 200ms | 200–500ms | > 500ms | **Replaced FID as a Core Web Vital on 2024-03-12.** Grade INP, not FID. |
| **LCP** (Largest Contentful Paint) | ≤ 2.5s | 2.5–4s | > 4s | Unchanged. |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | 0.1–0.25 | > 0.25 | Unchanged. Reserve image/embed dimensions; never inject layout-shifting content above the fold. |

Source: web.dev/articles/inp, web.dev Core Web Vitals 2024–2025. **FID < 100ms is no longer a metric — do not grade it.**

## 2. Contrast — APCA preferred, WCAG2 floor

- **WCAG 2.x** (4.5:1 normal text, 3:1 large/UI) is the **legal floor** — still the compliance baseline.
- **APCA** (Accessible Perceptual Contrast Algorithm) is **advanced-practice** — a WCAG 3 *draft*, NOT a ratified standard. It models perception better, especially for the grey-on-dark / monochrome surfaces the NewEarth house uses (where WCAG2 mis-scores).

**Severity rule (R7 — avoids false legal-failure findings):**
- An APCA-only shortfall (passes WCAG2 4.5:1, fails APCA target) → **SUGGESTION**. Label it "APCA advanced-practice, not a legal failure."
- A WCAG2 failure → **CRITICAL** (legal floor breached), regardless of APCA.
- **Tiebreaker when they disagree**: more-restrictive wins for *text*; APCA is authoritative for *non-text UI* elements.
- Tertiary tokens (e.g. `--ne-fg-tertiary`) are deliberately low-emphasis — exclude them from body-text use; don't flag them as body-text failures.

## 3. Touch / pointer targets (WCAG 2.2)

- **Mobile**: ≥ 44×44px (Apple HIG / iOS).
- **Desktop pointer**: ≥ 24×24px (**WCAG 2.2 SC 2.5.8 Target Size (Minimum)**, ratified Oct 2023).
- Expand the hit area when the *visual* target is smaller than the minimum.
- **Spacing-offset nuance**: SC 2.5.8 is also met if a 24px-diameter circle centred on the target doesn't intersect an adjacent target — relevant for dense dashboards where shrinking targets isn't an option.

## 4. Modern platform features (build technique + grading)

Encode as build-techniques for `/ui-design-system` and as grading checks here.

| Feature | Use it for | Guard |
|---------|-----------|-------|
| `dvh` / `svh` / `lvh` | Full-height heroes — `100dvh` not `100vh` so mobile browser chrome doesn't clip | Baseline 2023 |
| `:focus-visible` | Focus rings — NOT `:focus` (which fires on mouse-click too, producing rings premium reviewers reject) | Baseline 2022 |
| `prefers-contrast: more` | Ship a higher-contrast override (pairs with APCA) | progressive enhancement |
| `prefers-reduced-motion: reduce` | Mandatory branch on every animation | see Motion Review below |
| `@container` (container queries) | Component-level responsiveness (a card adapts to its slot, not the viewport) | Baseline 2023; `@supports` not required but test |
| `:has()` | Parent-state styling without JS | Baseline 2023 |
| `text-wrap: balance` / `pretty` | Balanced headlines / no orphan widows in body | progressive enhancement, degrades gracefully |
| `color-mix()` + OKLCH | Perceptual colour mixing (state-layers, tints) | Baseline 2023 |
| `content-visibility: auto` | Defer off-screen render on long lists (INP/LCP win) | progressive enhancement |
| `<meta name="theme-color">` + `color-scheme` | Correct browser chrome + scrollbar contrast in dark mode | — |
| **View Transitions API** | Same-document + cross-document transitions | **wrap in `@supports (view-transition-name: x)`** — Safari support is recent; degrade to no-transition |
| **CSS scroll-driven animations** (`animation-timeline: scroll()/view()`) | Scroll-linked reveals without JS | **wrap in `@supports (animation-timeline: scroll())`** — degrade to static; not universal |
| `input { font-size: 16px }` (mobile) | Prevent iOS Safari auto-zoom-on-focus | classic polish miss |

## 5. Motion-Review Rubric (grade these)

`/design-review` was motion-blind. Grade motion against [ui-design-system's motion whitelist](../../ui-design-system/references/motion-approved-recipes.md) + run `scripts/audit-restraint.sh` for the mechanical checks.

| Flag | Severity | How to detect |
|------|----------|---------------|
| Animation with no `prefers-reduced-motion` fallback | **CRITICAL** (a11y) | CSS keyframes/transition or `gsap.*`/`ScrollTrigger` in a file with no `matchMedia`/`@media reduce` (audit-restraint Rule 6) |
| Animates layout props (`width/height/top/left/margin`) | **IMPORTANT** (perf/CLS) | should be `transform`/`opacity` only (audit-restraint Rule 5) |
| Motion causes layout shift (CLS) | **IMPORTANT** | reveal pushes siblings; element reserves no space |
| Scroll-jacking / full-viewport pin without narrative payload | **IMPORTANT** | `pin:true`+`scrub` on a hero with no content reason |
| Decorative-only / ambient / infinite-loop animation | **IMPORTANT** | fails the earned-gate; no `motion-earned` comment |
| Motion implementation missing the `/* motion-earned: <reason> */` comment | **IMPORTANT** | the earned-gate marker is absent |
| Duration > 600ms routine, or < 120ms (feels broken) | SUGGESTION | check vs the duration tokens |
| `will-change` left on permanently / on everything | SUGGESTION | should be added before, removed after |
| Overshoot/bounce/elastic as a default (not the ≤1 signature moment) | SUGGESTION | reads playful, off-brand |
| Char-by-char text animation, or text reveal without a mask | SUGGESTION | use line/word + mask |

> **New-criterion note (R15)**: the motion criteria are NEW as of design-review v2.1. The first audit of an existing project may surface pre-existing motion gaps (missing reduced-motion, decorative animation) — these are **real pre-existing gaps now made visible, not regressions** from recent changes. Say so in the report.

## 6. Vercel Web Interface Guidelines (distilled — encode inline, was "offer to fetch")

Grouped, terse, gradeable. Source: `vercel.com/design/guidelines` (verify on reverify-trigger).

**Accessibility / focus** — keyboard-operable all flows; visible ring via `:focus-visible`; focus traps in modals (move + return focus; focus first error on submit); semantic `<a>`/`<button>`/`<label>`/`<table>` before `aria-*`; hierarchical `<h1–h6>` + skip-to-content; icon-only buttons need `aria-label`; decorative elements `aria-hidden`; announce async updates via polite `aria-live`; never disable zoom.

**Targets / touch** — ≥44px mobile, expand sub-24px desktop to ≥24px; visual & hit target match (no dead zones on checkbox/radio + label); `touch-action: manipulation`; configure `-webkit-tap-highlight-color`; input `font-size ≥16px` mobile.

**Inputs / forms** — label every control; submit on Enter (single input), ⌘/⌃+Enter in textarea; keep submit enabled until submission starts then disable + spinner; warn on unsaved-data navigation; correct `type`/`inputmode`/`autocomplete`; allow paste (incl. one-time codes); trim trailing whitespace.

**Animation** — honor `prefers-reduced-motion`; CSS > WAAPI > JS libs; animate `transform`/`opacity` only; never `transition: all`; cancelable; correct transform-origin; no autoplay.

**Layout / content** — safe-area insets via `env()`; verify mobile/laptop/ultra-wide; CSS layout over JS measurement; curly quotes + `…` ellipsis char; no widows/orphans; `font-variant-numeric: tabular-nums` for number columns; `&nbsp;` to bind units ("10 MB", "⌘ + K"); `scroll-margin-top` on anchored headers; design empty/sparse/dense/error states; never colour alone (text label for status); localize dates/numbers/currency; deep-link state (filters, tabs, pagination) into the URL.

**Performance** — INP < 200ms, LCP < 2.5s, CLS < 0.1; mutations < 500ms; explicit image dimensions; preload above-the-fold only, lazy-load rest; `content-visibility: auto` / virtualize long lists; `preconnect` CDN; preload + subset critical fonts.

**Visual** — layered shadows (≥2 layers); child radius ≤ parent radius (concentric); tint borders/shadows toward the bg hue on coloured surfaces; **prefer APCA over WCAG2** for contrast; increase contrast on hover/active/focus; `color-scheme: dark` + `<meta theme-color>` in dark themes; **optical alignment over geometric — adjust ±1px when perception beats geometry** (the clearest "award vs decent" tell).

## 7. Award-Grade Scoring Lens (premium-minimalist, 2026)

For "make this award-grade" reviews, score against the **Awwwards weighting** so aesthetics can't carry alone:

| Axis | Weight |
|------|--------|
| Design | 40% |
| Usability | 30% |
| Creativity | 20% |
| Content | 10% |

Usability + Content = 40% combined. A beautiful site that's hard to use or thin on content cannot top-score. Open every award-grade review with the **"intentionality > intensity" framing**: *Purpose · Tone · Differentiation · the ONE memorable thing*. Hold the **HIG north-star**: clarity, deference (chrome defers to content), depth (hierarchy via space + weight, not decoration). Sources: Awwwards evaluation criteria; Figma/Vercel/web.dev design guidance 2025–2026.

---

## Composes with

- [ui-design-system/references/motion-approved-recipes.md](../../ui-design-system/references/motion-approved-recipes.md) — the build-side motion whitelist this rubric grades against
- [ui-design-system/references/restraint-preflight.md](../../ui-design-system/references/restraint-preflight.md) — the mechanical restraint checks
- `scripts/audit-restraint.sh` (in ui-design-system) — the WARN-tier mechanical audit
