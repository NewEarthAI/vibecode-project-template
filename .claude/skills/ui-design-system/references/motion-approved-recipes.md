# Motion — Approved Recipes (WHITELIST)

> **This is a whitelist, not a menu.** The patterns below are the ONLY motion approved for the the house house. **Any motion not on this list is REJECTED by default.** The existence of a recipe here is not permission to use it — every use must first clear the earned-gate below. Default to *no motion*; add one purposeful move, never a chorus.
>
> Motion is **earned**, exactly like colour. "Premium by restraint" applies to time as much as to ink.

---

## STEP 0 — The Earned-or-Rejected Gate (answer BEFORE reaching for a recipe)

Before any animation, answer: **does this motion do one of these three things?**

1. **Communicates a state change** — a thing appeared / changed / was removed; a relationship in space.
2. **Guides attention to exactly one thing** — and only one.
3. **Gives feedback to a user action** — they did something; the UI confirms it.

- **None of the three → REJECTED.** No animation. Stop here.
- **One of the three → earned.** Pick the matching recipe below, apply its restraint guardrail, add the mandatory comment:

```jsx
/* motion-earned: confirms the drawer opened (state change) */
```

Every motion implementation **must** carry a `/* motion-earned: <which of the 3 + why> */` comment. The motion-review rubric (in `/design-review`) checks for its presence — a motion without it is a finding. This is the mechanical barrier that stops "available" from becoming "permission."

Then the three universal gates, no exceptions:
- **GPU-only**: animate `transform` and `opacity` ONLY. Never `width/height/top/left/margin` (anti-vibe-coded #18).
- **Reduced-motion**: ships a `prefers-reduced-motion: reduce` branch (CSS `@media` or `gsap.matchMedia()`). A recipe without it is non-compliant.
- **Resolves and rests**: no infinite/ambient/looping motion. It plays, it finishes, it stays still.

---

## Scope — which skill owns which motion

| Surface | Owner | Motion register |
|---|---|---|
| **Product UI, dashboards, drawers, app surfaces** | THIS file (`ui-design-system`) | Restrained micro-motion + the recipes below |
| **Cinematic scroll-driven landing / marketing pages** | [`landing-page-mvp`](../../landing-page-mvp/SKILL.md) — `references/gsap-patterns.md` + `references/motion-tokens.md` | Theatrical scroll choreography (presets A–H) |

`landing-page-mvp` owns the GSAP cinematic tier — do NOT duplicate its recipes here. **Caveat**: several of its presets use `back.out(1.7)` / `elastic.out` overshoot, which the house REJECTS for product UI. Even on a landing page, prefer the restraint-aligned preset (its "Midnight Luxe" is closest) and strip overshoot from hover. The earned-gate and the reduced-motion mandate apply to BOTH skills.

---

## The Approved Recipes (house product-UI register)

Each uses the locked motion tokens from [design-tokens.md](design-tokens.md) §9. GSAP examples assume `landing-page-mvp`'s `useGSAP()` + `gsap.defaults({force3D:true, overwrite:'auto'})` discipline.

### 1. Signature card hover (already the house default)
The 300ms lift. Earned = feedback to pointer. `--ne-duration-base` + transform/box-shadow/outline only. Already in `tokens.css`; do not re-invent.

### 2. Scroll-reveal (once, on enter)
Earned = state change (content entered the viewport). Travel ≤24px, fade in, **reveal once** — never re-animate on scroll-by.
```js
/* motion-earned: section content entered viewport (state change) */
ScrollTrigger.batch('.ne-reveal', {
  start: 'top 85%',
  onEnter: b => gsap.to(b, { autoAlpha: 1, y: 0, stagger: 0.08, duration: 0.4, ease: 'power2.out', overwrite: true }),
});
```
CSS-only alternative (preferred when no GSAP in the project): IntersectionObserver toggling a class that transitions `translateY(12px)→0` + `opacity` over `--ne-duration-enter` with `--ne-ease-out`, stagger via `transition-delay: calc(var(--index) * 80ms)`.

### 3. Hero entrance timeline (once)
Earned = guides attention on first paint. Sequence eyebrow → headline → subhead → CTA, total ≤1.2s, decelerate easing, runs once.
```js
/* motion-earned: directs first attention through the hero hierarchy */
gsap.timeline({ defaults: { ease: 'power3.out', duration: 0.6 } })
  .from('.eyebrow', { autoAlpha: 0, y: 12 })
  .from('.h1', { autoAlpha: 0, y: 16 }, '<0.1')
  .from('.subhead', { autoAlpha: 0, y: 12 }, '<0.1')
  .from('.cta', { autoAlpha: 0, y: 10 }, '<0.1');
```

### 4. Masked headline reveal (lines/words, never chars)
Earned = guides attention to the one headline. Headlines ONLY, never body. `mask:'lines'`, words not chars (char-by-char reads gimmicky), stagger ≤0.06, screen-reader text preserved (`aria` intact).
```js
/* motion-earned: the single hero headline (attention) */
const s = SplitText.create('.h1', { type: 'lines,words', mask: 'lines', aria: 'auto' });
gsap.from(s.words, { yPercent: 110, stagger: 0.05, duration: 0.6, ease: 'power3.out' });
```

### 5. Magnetic primary CTA
Earned = feedback. **Primary CTA only** (there is exactly one). Pull ≤8px, snaps home on leave, **desktop fine-pointer only**.
```js
/* motion-earned: the one primary CTA (pointer feedback) */
const xTo = gsap.quickTo(btn, 'x', { duration: 0.4, ease: 'power3' });
const yTo = gsap.quickTo(btn, 'y', { duration: 0.4, ease: 'power3' });
// gate: @media (hover:hover) and (pointer:fine)
```

### 6. Number count-up (KPI / metric)
Earned = state change (the value arrived). Fire **once** on enter, ≤1s, integers snapped, reduced-motion → show the final value instantly. Pairs with the KPI cards.

### 7. Flip layout transition
Earned = state change (a genuine layout move: filter, expand, reorder). `Flip.getState()` → DOM change → `Flip.from(..., { duration: 0.5, ease: 'power2.inOut' })`. Only on a real layout change, never a decorative flourish.

### 8. Tasteful parallax
Earned = depth/hierarchy. Transform only, translate ≤15–20%, `scrub` numeric for lag. **Never** pin-jack the full viewport. One parallax layer per section, max.

### 9. Opt-in precision texture (Atelier Dark / hero only)
Not motion, but the same restraint class: a static noise/grain overlay `mix-blend-mode: overlay`, opacity 0.02–0.05, to "remove digital sterility." Atelier Dark already ships paper-grain at 0.03; cap any general-surface grain at ≤0.05 and **fixed-overlay only** (anti-vibe-coded #20 — never on a scrolling container).

---

## REJECTED motion (never absorb — the look or the technique)

- Sparkles, confetti, glow pulses, "celebration / peak-moment" dopamine animation
- `backdrop-blur` / glassmorphism motion, animated gradient accents
- Character / mascot animation, Duolingo-style emotional loops
- 3D card flips, draggable "tactile" charts, perpetually-moving glowing elements
- `elastic` / `bounce` / `back.out(>1.4)` overshoot as a **default** (one signature `back.out(1.4)` moment is the only exception, with the comment)
- Infinite / looping / ambient motion (marquees, perpetual float) — motion must resolve and rest
- Scroll-jacking / full-viewport pinned scroll **without** genuine narrative payload
- Char-by-char text animation; any text reveal without a mask
- Animating layout properties; raw `scroll` listeners (use ScrollTrigger / `useScroll`)

---

## Note (first-audit clarity)

The motion criteria here are **NEW as of v1.6 / design-review v2.1**. The first `/design-review` run on an existing project may surface pre-existing motion gaps (missing reduced-motion fallback, decorative animation) — these are **real pre-existing gaps now made visible, not regressions** introduced by recent changes.

---

## Composes with

- [design-tokens.md](design-tokens.md) §9 — the locked easing + duration vocabulary
- [anti-vibe-coded.md](anti-vibe-coded.md) #12, #18, #19, #20 — the motion NEVER bans this whitelist enforces
- [`landing-page-mvp`](../../landing-page-mvp/SKILL.md) — the cinematic scroll-driven tier (cross-link, not duplicate)
- `/design-review` motion-review rubric — the audit side that checks the `motion-earned` comment + reduced-motion + GPU-only
