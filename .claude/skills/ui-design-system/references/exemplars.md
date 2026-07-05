# Exemplars — The House at Its Ceiling (right vs too-much)

> Rules tell you the boundary; exemplars show you the target. Each entry below names a rule, then contrasts **RIGHT** (the restrained, award-grade expression) against **TOO MUCH** (the over-reach that reads template-y or AI-generated) and **TOO LITTLE** (the flat, unconsidered version). Use these as the reference an agent or developer compares their work against when the operator isn't in the room.
>
> Reference-grade real-world anchors (study these for the *feel*, never to copy a look): Linear, Stripe Dashboard, Vercel, Notion, Untitled UI. Premium-minimalist motion: study how Stripe and Linear use a single, brief, motivated transition — not a chorus.

---

## Motion (the earned-gate in practice)

| | Description |
|---|---|
| **RIGHT** | A dashboard where the only motion is the 300ms card hover-lift and a single scroll-reveal on first section entry. Nothing else moves. The page feels calm and fast; the one reveal earns attention. |
| **TOO MUCH** | Every card fades+slides on scroll, the hero headline does a char-by-char typewriter, numbers count up on every re-render, a magnetic effect on every button, a marquee of logos. Reads as a template demo. This is the "recipe menu" failure — availability treated as permission. |
| **TOO LITTLE** | Zero transitions; state changes snap with no feedback; a drawer that teleports open. Feels broken, not minimal. |

## Hero (text load + impact)

| | Description |
|---|---|
| **RIGHT** | Eyebrow (1) + a poster-scale `clamp()` headline of ≤8 words + a ≤20-word subhead + one primary CTA. Massive type carries the impact; whitespace does the rest. |
| **TOO MUCH** | Headline + sub-headline + descriptive paragraph + 3 feature bullets + 2 CTAs + a badge row, all in the hero. Five competing messages; nothing lands. |
| **TOO LITTLE** | A 16px headline centred in a sea of grey with no hierarchy. Restraint without intent reads as unfinished. |

## Colour (colour is earned)

| | Description |
|---|---|
| **RIGHT** | Monochrome surfaces; the one brand accent on the single primary CTA; semantic colour only inside data (a red variance arrow, a green delta). The eye goes exactly where it should. |
| **TOO MUCH** | Four KPI cards in four different colours, a purple→pink gradient hero, pastel status pills. The AI-default look. |
| **TOO LITTLE** | Pure greyscale everything including the CTA — the user can't find the action. Earned colour means *some* colour, precisely placed. |

## Depth (tone + hairline first, shadow last)

| | Description |
|---|---|
| **RIGHT** | Cards separated by a 1px hairline border + a subtle tonal step; a two-layer grayscale shadow only on hover-lift and floating menus. |
| **TOO MUCH** | `shadow-2xl` on every card, glowing coloured shadows, glassmorphism blur. Cards float on pillows. |
| **TOO LITTLE** | No borders, no shadows, no tonal steps — cards melt into the background and the structure is illegible. |

## Typography (one display face, weight-and-colour hierarchy)

| | Description |
|---|---|
| **RIGHT** | DM Sans throughout, JetBrains Mono for every number; hierarchy via weight (400/500/600) + size + the 100/72/55% ink-opacity ladder. Tabular-nums on KPIs. |
| **TOO MUCH** | Three display faces, six weights, letter-spacing on body, ALL-CAPS paragraphs, text-shadow. |
| **TOO LITTLE** | Inter at one weight for everything — the "we didn't choose a font" look. |

## Copy (senior-dev voice, no AI-tells)

| | Description |
|---|---|
| **RIGHT** | "Saved." · "Request failed. Retry or contact support." · "No results." Precise, calm, lowercase-confident. No em-dashes in micro-copy, no invented stats. |
| **TOO MUCH** | "Awesome! Your data was saved ✨" · "Unlock your potential — supercharge your workflow." Em-dash + slop phrase + fake cheer = three AI-tells in one line. |
| **TOO LITTLE** | Raw system strings ("ERR_CONN_500") surfaced to the user. Terse ≠ unhelpful. |

---

## How to use this file

When reviewing or building, for each surface ask: "is this RIGHT, TOO MUCH, or TOO LITTLE?" The skill's job is to land every surface in the RIGHT column. `TOO MUCH` is the more common failure for AI-generated work (it reaches for the menu); `TOO LITTLE` is the rarer failure of mistaking emptiness for restraint. Award-grade is the precise middle: every element earns its place, and the few that remain are executed to the pixel (optical ±1px alignment, tabular numbers, hairline borders, one motivated motion).

Composes with [anti-vibe-coded.md](anti-vibe-coded.md), [restraint-preflight.md](restraint-preflight.md), [motion-approved-recipes.md](motion-approved-recipes.md).
