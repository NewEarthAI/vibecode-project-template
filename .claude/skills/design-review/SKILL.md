---
name: design-review
description: |
  The NewEarth Design Suite entry point for reviewing and fixing UI/UX on a running website,
  a screenshot, a Figma link, or a code path. Pulls the FULL three-layer stack — L1 identity
  contracts (PRODUCT.md + DESIGN.md), L2 anti-slop overlay (design-taste-frontend), and L3
  house specialty skills (ui-design-system + data-table-design + kpi-dashboard-design +
  brand-visual-identity) — and grades the surface against ALL layers in one pass. Priority-
  weighted rules with numeric thresholds (contrast ratios, touch targets, CLS, variance
  ceilings per surface type). Iterative screenshot → fix → verify loop. Use this when the
  request is "review this UI", "design audit", "make this perfect", "look at this page and
  fix what's wrong", or any signal that the user wants a deep multi-layer critique against
  NewEarth brand standards. For BUILDING components/theming, use tailwind-shadcn-system
  or ui-design-system directly. For HOLISTIC website audit (SEO, legal, security), use
  audit-website.
version: 2.1
classification: capability-uplift
allowed-tools: Read, Grep, Glob, Bash, WebFetch
user-invocable: true
triggers:
  - "review this UI"
  - "design audit"
  - "accessibility check"
  - "UX review"
  - "visual inspection"
  - "fix design issues"
  - "make this perfect"
  - "make this look premium"
  - "look at this page and tell me what's wrong"
  - "audit this design"
  - "design-review this"
  - "screenshot review"
  - "review this screenshot"
  - "review this URL"
do-not-trigger:
  - "build a component" → use tailwind-shadcn-system
  - "audit website for SEO" → use audit-website
  - "build a landing page" → use landing-page-mvp
  - "build a dashboard" → use build-dashboard
paths:
  - "clients/**/*.tsx"
  - "clients/**/*.jsx"
  - "clients/**/*.html"
---

# Design Review — NewEarth Design Suite Entry Point

> Priority-weighted UI/UX review with iterative verification. The single surface that pulls the FULL NewEarth Design Suite — L1 brand identity + L2 anti-slop dial baselines + L3 house specialty rules — and grades any input (URL, screenshot, Figma link, or code path) against every layer in one pass.

---

## Mandatory Design Suite Contract — READ BEFORE ANY REVIEW

This skill is the **entry point for the entire NewEarth Design Suite v2 three-layer stack**. Before producing any verdict, suggestion, or fix, you MUST load the full stack in the order below. Skipping a layer makes the review meaningless — it produces generic "looks fine" output instead of the brand-aligned critique the operator asked for.

### Stack to load on every invocation

| Layer | File | What it gives you |
|---|---|---|
| **L1 — Identity** | `PRODUCT.md` at repo root | Register, audience, tone, brand personality |
| **L1 — Visual system** | `DESIGN.md` at repo root | Colour palette (OKLCH), typography defaults + escalation paths, elevation, motion, **variance ceilings per surface type** (hero 10 / product UI 7 / dashboard 12) |
| **L2 — Anti-slop overlay** | `.claude/skills/design-taste-frontend/SKILL.md` | `DESIGN_VARIANCE` / `MOTION_INTENSITY` / `VISUAL_DENSITY` dial baselines (8/6/4), 10+ dial-driven bans |
| **L3 — House signature** | `.claude/skills/ui-design-system/SKILL.md` + `references/anti-vibe-coded.md` | 25 NEVER rules (22 absolute + 3 anti-AI-tell WARN: em-dash, Space Grotesk, fake-numbers), silver signature, hairline borders, 300ms hover curve, DM Sans + JetBrains Mono, monochrome-first, "motion is earned" |
| **L3 — Motion + restraint** | `ui-design-system/references/motion-approved-recipes.md` + `restraint-preflight.md` | The motion whitelist + earned-gate (grade the `/* motion-earned */` comment); the mechanically-counted restraint pre-flight (eyebrow/zigzag/layout-variety counters, required-state matrix, consistency locks) |
| **Platform standards** | `references/modern-web-platform.md` (THIS skill) | INP (not FID), APCA + WCAG2, two-tier touch targets, View Transitions / scroll-driven CSS / container queries / `dvh` / `:focus-visible`, the **motion-review rubric**, the **Awwwards scoring lens** + clarity-deference-depth north-star — load EVERY review |
| **L3 — Specialty (conditional)** | Load BASED on what's being reviewed: |
| ↳ if tables on the page | `.claude/skills/data-table-design/SKILL.md` | 7 non-negotiable table rules |
| ↳ if KPI cards on the page | `.claude/skills/kpi-dashboard-design/SKILL.md` | KPI selection + visualisation discipline |
| ↳ if brand-token questions arise | `.claude/skills/brand-visual-identity/SKILL.md` | Palette extraction, brand contract |

### Halt-loud-on-missing-contract

If `PRODUCT.md` OR `DESIGN.md` OR `.claude/skills/design-taste-frontend/SKILL.md` is missing, halt immediately and surface this error:

```
ERROR (design-review): NewEarth Design Suite contract files missing.
Expected at repo root: PRODUCT.md, DESIGN.md
Expected skill:        .claude/skills/design-taste-frontend/SKILL.md

Phase 3 of the NewEarth Design Suite v2 build has not completed.
Refusing to produce a review until the brand contract layer exists —
a review without L1 contracts is generic critique, not NewEarth review.

Run: bash .claude/skills/ui-design-system/scripts/preflight-contract-files.sh
Then: run impeccable teach (interactive, Justin in the loop) to author L1.

Ref: continuations/NEWEARTH-DESIGN-SUITE-V2-MASTER-CONTINUATION-2026-05-13.md §15 (A1, A2, A6).
```

Sibling L3 specialty skills (data-table-design, kpi-dashboard-design, brand-visual-identity) are conditional — only halt on PRODUCT.md / DESIGN.md / design-taste-frontend missing. The others get loaded as the review surface needs them.

### Auto-loaded libraries (operator never invokes these directly)

The L2 + specialty L3 skills below are **libraries**, not human entry points. Their `user-invocable: false` frontmatter hides them from the slash-command picker. They get loaded by THIS skill (and by `/ui-design-system` for builds) on a conditional basis. If you ever feel the urge to "/kpi-dashboard-design" something — don't. Just `/design-review` the surface and the right libraries pull themselves in.

| Library | When this skill loads it |
|---|---|
| `design-taste-frontend` (L2) | Always — every review |
| `ui-design-system` (L3 house) | Always — every review |
| `data-table-design` | When the surface contains tabular row × column displays |
| `kpi-dashboard-design` | When the surface contains KPI cards / metric grids |
| `brand-visual-identity` | When the surface raises brand-token questions (palette, typography, contrast against brand identity) |

The same library list powers `/ui-design-system` during builds — that skill loads them when generating tables, KPI grids, or brand-asset surfaces respectively. Two human-facing entry points (`/design-review` for audit, `/ui-design-system` for build), one shared library set underneath. That's the whole architecture.

### Application order during review

Walk the input through these passes in order:

1. **L1 pass** — does the surface match the register, tone, and personality declared in `PRODUCT.md`? Does it use the colours, typography, and motion rules from `DESIGN.md`?
2. **L2 pass** — what `DESIGN_VARIANCE` / `MOTION_INTENSITY` / `VISUAL_DENSITY` does the surface actually present? Is that appropriate for the surface type (hero / dashboard / form / product-UI)? Does it trigger any dial-driven L2 bans?
3. **L3 absolute pass** — walk the 25 NEVER rules in `references/anti-vibe-coded.md` (22 absolute + the 3 anti-AI-tell WARN-tier: em-dash in UI copy, Space Grotesk, fake-precise numbers). Each violation = a flagged issue. Tag with severity per the priority weights below.
4. **L3 specialty pass** — for each loaded specialty skill, walk its specific rules against the matching elements on the surface.
5. **Motion + platform-standards pass** — walk the **motion-review rubric** and the **modern web-platform standards** in `references/modern-web-platform.md`: INP (not FID), APCA + WCAG2, two-tier touch targets, `:focus-visible`, reduced-motion fallback (CRITICAL if missing), layout-prop animation, the `/* motion-earned */` comment. Run `ui-design-system/scripts/audit-restraint.sh` for the mechanical checks where code is available.
6. **Restraint pre-flight pass** — apply `ui-design-system/references/restraint-preflight.md`: count eyebrows/zigzags/layout-families, check consistency locks + the required-state matrix.
7. **Cross-layer reconciliation** — when L2 and L3 conflict (rare), the stricter rule wins per the anti-vibe-coded composition section. When L1 (brand contract) and L3 (house default) conflict, surface the conflict explicitly — never silently override the brand contract.

---

## Companion Skills — Invoke When Conditions Met

---

## Companion Skills — Invoke When Conditions Met

- **Building new components** → invoke `tailwind-shadcn-system` for composition rules and theming
- **Full website health audit (SEO, legal, security, technical)** → invoke `audit-website` for 230+ rule squirrelscan
- **Brand token questions** → invoke `brand-visual-identity` for color palette and typography
- **Building a landing page** → invoke `landing-page-mvp` for GSAP presets and conversion optimization

NOT mutually exclusive.

---

## Priority-Weighted Review Categories

### CRITICAL (Must fix — blocks deployment)
- Color contrast below 4.5:1 for normal text
- Missing alt text on meaningful images
- Keyboard-inaccessible interactive elements
- Broken layout at any standard viewport (375px, 768px, 1024px, 1440px)
- Missing form labels (screen reader inaccessible)

### HIGH (Should fix — significant UX impact)
- Touch/click targets below 44x44px
- Missing focus visible indicators
- CLS > 0.1 (layout shift)
- No responsive breakpoints (desktop-only)
- Form inputs without error states
- Missing loading states on async operations

### MEDIUM (Fix soon — polish issues)
- Inconsistent spacing/padding
- Misaligned elements (off-grid)
- Missing hover states on interactive elements
- Poor visual hierarchy (unclear primary action)
- Inconsistent border radius or shadow usage

### LOW (Nice to have — refinement)
- Font pairing suggestions
- Micro-interaction polish
- Animation timing improvements
- Whitespace optimization

---

## Accessibility Rules (Non-Negotiable)

| Rule | Threshold | How to Test |
|------|-----------|-------------|
| Text contrast (normal) | 4.5:1 minimum (WCAG2 legal floor) | Chrome DevTools Contrast checker |
| Text contrast (large ≥18px bold) | 3:1 minimum | Chrome DevTools |
| Contrast (perceptual, preferred) | APCA — advanced-practice (WCAG3 draft). APCA-only shortfall = SUGGESTION; WCAG2 fail = CRITICAL. See [modern-web-platform.md](references/modern-web-platform.md) §2 | APCA contrast tool |
| Touch/click targets | **44×44px mobile / 24×24px desktop** (WCAG 2.2 SC 2.5.8); expand hit area when visual < target | Inspect computed size |
| Focus indicator | visible ring on `:focus-visible` (NOT `:focus`) | Tab through, observe |
| Keyboard navigation | All interactive elements | Tab through entire page |
| Focus indicators | Visible ring/outline | Tab and observe |
| Screen reader labels | All form inputs + buttons | Check aria-label, label[for] |
| Base font size | 16px minimum | Inspect body font-size |

---

## Performance Thresholds

| Metric | Target | Tool |
|--------|--------|------|
| CLS | < 0.1 | Lighthouse |
| LCP | < 2.5s | Lighthouse |
| **INP** | **< 200ms** | Lighthouse / web-vitals | <!-- INP replaced FID as a Core Web Vital on 2024-03-12. Do NOT grade FID. -->
| Images | WebP/AVIF, explicit dimensions (CLS), lazy-load below fold, `content-visibility: auto` on long lists | Network tab |

> **FID is retired** — it was removed as a Core Web Vital on 2024-03-12 and replaced by INP. Grade INP. Full modern web-platform standards (View Transitions, scroll-driven CSS, container queries, `dvh`, `:focus-visible`, the motion-review rubric, the Awwwards scoring lens) live in [references/modern-web-platform.md](references/modern-web-platform.md) — load it on every review.

---

## Input Routing — Accept Any of Four Input Shapes

The operator can hand you any one of these; you route to the right loader.

| Input shape | How to load it |
|---|---|
| **Live URL** (`https://...`) | Use the playwright MCP server to navigate + take viewport screenshots at 375/768/1440. If playwright unavailable, fall back to `WebFetch` for HTML/CSS analysis only and flag that visual review is partial. |
| **Screenshot already attached** (image in chat) | Read the image directly — you already have multimodal vision. No screenshot tool needed. |
| **Screenshot file path** on disk | `Read` the file with the image extension; vision parses it. |
| **Code path** (`src/components/X.tsx`) | Static analysis of the component source + props + Tailwind classes. If a dev server is running, ALSO ask the operator for the URL so you can do the visual pass. |
| **Figma link** | Tell the operator you cannot read Figma directly — ask them to export a PNG and re-invoke. (Figma MCP integration is a future enhancement.) |

If the operator says **"make this perfect"** or any equivalent quality-push signal, treat it as instruction to run ALL layers + iterate until clean, not just flag-and-stop.

---

## Review Process

### Step 0: Load the NewEarth Design Suite stack (MANDATORY)

Before anything else, follow the Mandatory Design Suite Contract section at the top of this file. Halt loudly if any L1/L2 contract is missing. Load conditional L3 specialty skills based on what the input surface contains (tables → load data-table-design; KPI cards → load kpi-dashboard-design; brand-token questions → load brand-visual-identity).

### Step 1: Detect framework + surface type

Identify: Next.js, React SPA, Vue, static HTML, or other. ALSO classify the surface type — `hero` / `landing-page` / `dashboard` / `product-ui` / `form` — because the L2 dial ceiling from `DESIGN.md` differs per type (hero ≤ 10, dashboard ≤ 12, product UI ≤ 7).

### Step 2: Load visual evidence per input routing

Per the Input Routing table above. For live URLs, viewport screenshots at 375px / 768px / 1440px (NOT full-page — saves tokens and time). For attached/file screenshots, parse directly. For code-only review, note explicitly that visual verification is limited.

### Step 3: Walk all five passes against priority rules

In order: L1 pass → L2 pass → L3 absolute pass → L3 specialty pass → cross-layer reconciliation. Each flagged issue gets a layer tag in the output (e.g. `[L1 brand contract]`, `[L2 dial ceiling]`, `[L3 house rule #5 — Inter banned]`, `[L3 data-table rule #2 — headers must be centred]`). Walk through CRITICAL → HIGH → MEDIUM → LOW priorities.

### Step 4: Fix Issues Found
Implement fixes for CRITICAL and HIGH issues. Ask before fixing MEDIUM/LOW.

### Step 5: Re-Screenshot and Verify
Take new screenshot after fixes. Confirm issues resolved, no new regressions introduced.

### Step 6: Iterate
Repeat Steps 3-5 until clean or user indicates stop.

### Optional: Fetch Latest Vercel Guidelines
Offer to WebFetch from `vercel-labs/web-interface-guidelines` for current best practices.

---

## Output Format

**Finding discipline (HIG severity rigour)**: every finding (a) cites the specific rule it violates (layer tag + rule name), (b) shows the offending pattern, and (c) ends with a concrete fix — a snippet or exact change, never "consider improving." For an award-grade / "make this perfect" review, open with the **intentionality > intensity** framing (Purpose · Tone · Differentiation · the ONE memorable thing) and score against the **Awwwards weighting** (Design 40 / Usability 30 / Creativity 20 / Content 10 — so usability + content genuinely count). North-star: clarity, deference (chrome defers to content), depth (hierarchy via space + weight, not decoration). See [modern-web-platform.md](references/modern-web-platform.md) §7.

```markdown
## Design Review — [page/component or URL]

**Surface type**: hero / landing-page / dashboard / product-ui / form
**Stack loaded**: L1 ✓ · L2 ✓ · L3 absolute ✓ · L3 specialty: [list any conditional skills loaded]
**Dial baseline applied**: variance=N / motion=N / density=N  (from DESIGN.md surface-type ceiling)

### CRITICAL Issues
| # | Layer | Location | Issue | Fix |
|---|-------|----------|-------|-----|
| 1 | [L1 brand contract] | Hero H1 | Uses Inter font; PRODUCT.md register declares DM Sans default | Swap to DM Sans + tracking-tighter |

### HIGH Issues
| # | Layer | Location | Issue | Fix |
|---|-------|----------|-------|-----|

### MEDIUM Issues
| # | Layer | Location | Issue | Suggestion |
|---|-------|----------|-------|------------|

### LOW Issues
| # | Layer | Location | Suggestion |
|---|-------|----------|------------|

### Accessibility Score
- Contrast: PASS/FAIL (4.5:1 normal, 3:1 large)
- Keyboard: PASS/FAIL (all interactive elements tabbable)
- Screen reader: PASS/FAIL (all inputs labelled)
- Touch targets: PASS/FAIL (≥44×44px)

### Layer Compliance Summary
| Layer | Score | Notes |
|---|---|---|
| L1 — Brand contract (PRODUCT.md + DESIGN.md) | X / Y violations | One-line summary |
| L2 — Anti-slop dial baselines | X / Y violations | One-line summary |
| L3 — House signature (25 rules: 22 absolute + 3 WARN) | X / 22 absolute + X / 3 WARN | One-line summary |
| L3 — Loaded specialty skills | X / Y violations | One-line summary |

### Design Strengths
[Good patterns worth keeping — usually the ones the layer-compliance summary scored well on]

### Cross-Layer Conflicts (if any)
[When L1 brand says one thing and L3 house default says another — name the conflict and recommend a path. NEVER silently override L1.]
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Reviewing without screenshots | Can't verify visual issues | Screenshot first, then analyze |
| Fixing without re-verifying | May introduce new issues | Always re-screenshot after fixes |
| Flagging all contrast issues equally | Some CRITICAL, some MEDIUM | Use priority weighting |
| Ignoring mobile viewport | Most traffic is mobile | Test at 375px first |
| Full-page screenshots | Massive, slow, wastes tokens | Viewport or element screenshots |
| Generic "looks good" assessment | Not actionable | Specific issues with locations and fixes |
| Judging spacing/alignment by eye on a scaled screenshot | Scaled-down images hide px-level offsets; you'll "fix" the same gap repeatedly with no effect | Measure in-browser: `getBoundingClientRect` → element centre vs `innerWidth/2`, gap = nextTop − prevBottom. Numbers diagnose, screenshots confirm |
| Assuming a spacing/margin class works because it's in the markup | In Tailwind v4 an UNLAYERED base rule (`p{margin:0}`, `h1,h2,h3{margin:0}`) beats every layered utility — `mt-*`/`mb-*` on those elements silently do nothing | When a margin utility "doesn't move" the element, check `index.css` for unlayered resets; wrap them in `@layer base`. Confirm computed margin is non-zero in-browser |
| Treating "same centre" as "aligned" | Two centred blocks with different `max-width` share a centre but their edges don't line up → reads as shifted | Match `max-width` on sibling centred statement blocks; verify both centre AND left-edge in-browser |

### Spacing & alignment diagnostic (run before flagging "looks off")

When a section reads as crammed or misaligned, measure before theorising:
1. **Computed margin probe** — `getComputedStyle(el).marginTop/Bottom`. If a class is set but computes `0px`, suspect the Tailwind v4 unlayered-reset trap (above).
2. **Centre offset** — `rect.left + rect.width/2 − innerWidth/2`. Near 0 = centred. The "misaligned" block may already be centred; the real diff is often width, not position.
3. **Inter-element gap** — `next.top − prev.bottom`. This is the true visual gap (margins + line-box leading), not the class value.

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No running site | Review code/markup directly, note that visual verification is limited |
| Browser automation unavailable | Review code only, recommend manual testing at viewports |
| Dynamic content (SPA) | Navigate to target state before screenshot |
| No issues found | State "No issues found at CRITICAL/HIGH priority" with Design Strengths |

---

## Rejected Aesthetics — Do NOT Recommend (locked appendix)

When suggesting fixes, NEVER push the surface toward these — they contradict the restraint house even when "cutting-edge" sources promote them: glassmorphism / `backdrop-blur`, claymorphism, neumorphism, gradient / cosmic / aurora mesh, colorful / vibrant multi-hue, doodle / sketch, brutalism look (CRT, halftone, hazard-red, uppercase-everything, glow), fantasy / retro / game themes, skeuomorphism, Material-3 dynamic-seed multi-hue palettes, bouncy/morphing/elastic motion as default, sparkles / confetti / celebration motion, custom cursors, infinite/decorative marquees, and "premium/luxury" relabelled-default scaffolds (generic blue + Inter body). The discipline: **grade against craft, structure, and modern standards; reject aesthetic direction that fights the house.** Recorded so this is never re-litigated (council 2026-06-24, `council/sessions/2026-06-24-design-suite-cutting-edge-upgrade.md`).

---

*design-review v2.1 — modern web-platform standards (INP/APCA/View-Transitions/container-queries), motion-review rubric, Awwwards scoring lens, HIG severity discipline added 2026-06-24 (7-agent council). Push to template via `/template-push` when validated.*
