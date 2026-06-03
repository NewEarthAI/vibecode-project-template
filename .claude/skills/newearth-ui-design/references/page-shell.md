# PageShell — Unified Page Scaffold

> **Load when**: building any non-landing page, replacing ad-hoc "Back to X" buttons, or fixing a page where the header scrolls away and leaves the user without orientation or primary actions.

## The Problem This Solves

Three cross-cutting UX issues that surface together in every dashboard-style app:

1. **Ad-hoc back buttons.** Each page invents its own "Back to X" — different placement, different styling, sometimes missing entirely. On long-scroll pages they disappear and the user is stranded.
2. **Header scroll-loss.** Static page headers (title + primary CTAs) scroll out of view. The user loses both orientation ("where am I?") and primary actions ("how do I get back / create new / export?").
3. **Duplicated composition.** Every page re-invents the `title + meta + action-row` layout, with drift in spacing, typography, and responsive behavior.

## The Pattern — Collapsing App Bar

Industry-leading apps (Linear, Vercel, Stripe, Notion, Apple HIG large-title) converge on the same pattern:

```
┌─────────────────────────────────────────────────────┐
│ [← Back]   Buyboxes › team – AZ     [Pause][Dup][×] │  ← STICKY, z-40
│                                                      │     (back + breadcrumb +
│                                                      │      actions ALWAYS
│                                                      │      rendered here)
├─────────────────────────────────────────────────────┤
│                                                      │
│   team – AZ (8% Yield)  ● Active                    │  ← HERO: title + meta only
│   Created 19/04/2026                                 │     (scrolls away normally)
│                                                      │
│   [page content]                                     │
└─────────────────────────────────────────────────────┘

ON SCROLL (after hero title scrolls past viewport top):
┌─────────────────────────────────────────────────────┐
│ [← Back]   team – AZ (8% Yield)  [Pause][Dup][×]    │  ← STICKY expands:
│                                                      │     compact title fades
│                                                      │     in, actions unchanged
```

- **Back + breadcrumb + actions live in the sticky bar from the start** — never leave viewport, never scroll away.
- **Actions are rendered ONCE** in the sticky bar. Do NOT duplicate in the hero. This prevents duplicate `data-tour` attrs, duplicate Radix dialog/popover providers, and screen-reader double-announce. (Industry convention — Linear, Vercel, Stripe all put primary actions in the sticky bar from page load.)
- **Title compacts into the bar** only after the hero title scrolls past. Hero title stays as the visual hero; compact title in the bar is the orientation cue after scroll.
- **IntersectionObserver drives the transition** — zero scroll listeners, no jank, no passive-listener overhead.

## Hard Rules

1. **Stacking context: `z-40` exactly.** Must sit above page content but below every drawer/dialog primitive. Radix defaults are `z-50`; custom portal'd modals often reach `z-[9999]`–`z-[10150]`. Never use `z-50` or higher on the shell — it bleeds over open sheets.
2. **No `backdrop-blur` on the bar.** House rule — glassmorphism is banned on content surfaces (see `anti-vibe-coded.md`). Use solid `bg-background` with a hairline bottom border that appears only when scrolled.
3. **Hairline border, two-layer shadow on scroll.** Border is `border-border` (1px); shadow is the `shadow-xs` two-layer spec from `design-tokens.md`. Never a single blurry drop-shadow.
4. **Back arrow is the only teal affordance.** Hover color shifts to `hsl(var(--dispo-teal))` (or client `primary_color`). Icon slides `-translate-x-0.5` on hover, button compresses `scale-[0.97]` on click — 180ms ease with `cubic-bezier(0.2, 0.8, 0.2, 1)`.
5. **Alt/Cmd + ←** triggers back navigation for keyboard parity with trackpad gestures. Suppressed inside inputs/textareas/contenteditable. **Must guard on `e.repeat`** — browsers fire keydown at ~30Hz on chord-hold; without the guard, a held chord stacks ~15 `navigate()` calls/sec and pops past the intended destination.
6. **Touch targets: 44px mobile, 36px desktop.** Back button is `h-10 sm:h-9`. Meets WCAG 2.5.5.
7. **Slot-preserved height.** The sticky bar is always `h-14` regardless of compact state. Content beneath it never reflows mid-scroll.

## API (reference implementation)

```tsx
import { PageShell } from "@/components/ui/page-shell";

<PageShell
  backTo="/buyboxes"                         // string path, or number (history delta)
  backLabel="Buyboxes"                       // optional; falls back to breadcrumb
  breadcrumbs={[
    { label: "Buyboxes", to: "/buyboxes" },
    { label: criteria.name },                // last crumb is non-clickable, marks aria-current
  ]}
  title={<>{criteria.name} <StatusBadge /></>}   // ReactNode — inline badges welcome
  meta={`Created ${date}`}                   // optional subtitle line
  eyebrow="SECTION LABEL"                    // optional uppercase tracker line
  actions={<><Button>Pause</Button><Button>Duplicate</Button></>}
  compactActions={<Button size="sm">···</Button>}  // optional narrower set for compact state
  maxWidth="3xl"                             // 3xl | 4xl | 5xl | 6xl | 7xl | full
>
  {/* page body — already inside the width container */}
</PageShell>
```

## When To Use vs Skip

**Use PageShell for**:
- Every list page (manager, inbox, index, dashboard)
- Every detail page (entity-by-id routes)
- Every form page (wizard step, create, update, settings)
- Every empty/error state (keep the shell; swap the body for a Card)

**Skip PageShell for**:
- **Landing / marketing pages** — those have their own hero + nav systems.
- **Sidebar-driven apps** (Pipeline, Admin consoles with persistent left nav) — those compose a different frame. The shell can mount *inside* the main content column, but evaluate each layout individually.
- **Full-bleed canvases** (maps, whiteboards, editors) — they need unconstrained width.
- **Modal/drawer content** — drawers have their own header contract.

## Accessibility Contract

- `<header role="banner">` on the sticky bar.
- `aria-label="Back to {label}"` on the back button.
- `<nav aria-label="Breadcrumb">` with the final crumb marked `aria-current="page"`.
- Compact title has `aria-hidden={!compact}` so screen readers aren't double-announced during transitions.
- Focus-visible ring on back button: teal, 2px, offset 2px from the background.

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `position: fixed` on the bar | Content can hide under it on short viewports | `position: sticky` with natural flow |
| `z-50` on the bar | Bleeds over Radix drawers | `z-40` |
| `backdrop-blur-md bg-background/80` | Banned by house rules + conflicts with guided-tour | Solid `bg-background` + scroll-triggered hairline border |
| `hover:text-[hsl(var(--dispo-teal))]` (raw legacy token) | Diverges from `--accent` in dark mode; violates brand naming rule | `hover:text-accent` — semantic Tailwind class that tracks the dark override |
| `{actions}` rendered in both hero + header | Duplicates DOM, breaks Radix provider trees (AlertDialog mounts twice) | Render `{actions}` **once** in the sticky bar only; hero shows title + meta only |
| Missing `e.repeat` guard in keyboard handler | Holding Alt/Cmd+← stacks ~30 navigate()/sec | `if (e.repeat) return` at top of handler |
| Scroll listener w/ `throttle(100)` | Main-thread work on every frame | IntersectionObserver on a sentinel div |
| Back button disappears in compact | User loses primary escape hatch | Back button is always visible |
| Bar height changes on scroll | Reflows content, causes CLS | Bar is always `h-14`; only contents fade in/out |
| Breadcrumb wraps on narrow screens | Breaks bar height | `hidden md:flex` — hide on narrow, keep back button |

## Failure Precedent

Before this skill existed, the BuyBox `BuyboxManager` + `BuyboxDetail` pages each had:
- Back button at `mb-4` above the content (outside a container)
- Header row at `mb-8` with its own title/actions layout
- `BuyboxManager` additionally had a "Back to Dashboard" ghost button at the *bottom* of the page — 600px below the primary action
- No sticky behavior — scrolling past the "New Buybox" button meant the user had to scroll all the way up to create another one

User feedback (2026-04-19): *"They can't go back or up easily, or click New Buybox or Import. There's not even a back button at the top when there should be."*

The PageShell migration eliminated the entire class of issue in three 20-line diffs per page.

## Implementation Notes

- **IntersectionObserver `rootMargin: "-56px 0px 0px 0px"`** — this is the sticky bar's own height; it ensures the sentinel is considered "out of view" the moment it slips under the bar, not when it crosses the viewport top.
- **Sentinel is 1px tall** — invisible, but always observable.
- **Compaction transition: 220ms** with `cubic-bezier(0.2, 0.8, 0.2, 1)` — Apple-style ease-out. Fast in, settles without bounce.
- **Back button transition: 180ms** — slightly snappier than the bar; the interaction feels immediately responsive.
- **Keyboard shortcut Alt/Cmd+←** — add to the keyboard-shortcut help sheet if the project has one.

## Related Files

- `src/components/ui/page-shell.tsx` — implementation
- `references/design-tokens.md` — shadow / spacing / motion values
- `references/color-discipline.md` — why teal is reserved for the back arrow
- `references/anti-vibe-coded.md` — backdrop-blur ban
