# Restraint Pre-Flight — Making "Minimalist" Testable

> Restraint is the house's defining asset, but "looks restrained" is a vibe until it is counted. This file turns it into **mechanically-checkable thresholds** an operator (or `scripts/audit-restraint.sh`) can verify before a surface ships. Adapted from leonxlnx/taste-skill's pre-flight discipline; tuned to the the house house.
>
> **Standalone-runnable**: this gate can run on its own (before any AI-generated page/copy ships), not only inside a full build. It is the design-layer equivalent of a lint pass.

---

## A. Section-Composition Counters (count the page, then check)

For a page/section tree, count the structural elements and check each threshold. A FAIL = the surface is over-decorated or repetitive.

| # | Rule | Threshold | FAIL when |
|---|------|-----------|-----------|
| 1 | **Eyebrow labels** (the small tracked-uppercase kicker above a heading) | ≤ `ceil(sections / 3)` | eyebrow count > ceil(sections/3) — eyebrows on every section is AI-template tell |
| 2 | **Zigzag** (alternating image+text split layout) | ≤ 2 consecutive | a 3rd consecutive image/text split — monotonous "marketing template" rhythm |
| 3 | **Layout variety** | ≥ 4 distinct layout families per 8 sections | < 4 families in 8 sections — the page is one layout repeated |
| 4 | **Marquee** (scrolling logo/text strip) | ≤ 1 per page | a 2nd marquee — visual noise |
| 5 | **Hero text load** | ≤ 4 text elements; subtext ≤ 20 words | hero has 5+ text blocks or a 20+ word subhead — heroes earn their impact by saying less |
| 6 | **Hero top padding** | `pt-24` (96px) cap as the default rhythm | wildly larger arbitrary padding with no system reason |
| 7 | **Bento grid** | cell count == content count | empty filler cells to "complete the grid" — bento is for real content, not decoration |

## B. Consistency Locks (one of each, page-wide)

| Lock | Rule |
|------|------|
| **Accent** | ONE accent colour locked page-wide. No per-section accent swaps. (Composes with "colour is earned".) |
| **Radius** | ONE radius scale. No mixing `rounded-md` cards with `rounded-xl` cards arbitrarily — pick the surface's tier and hold it. |
| **Theme** | ONE theme per page. No section-level light/dark inversion as decoration. |
| **Gray temperature** | ONE gray family (anti-vibe-coded #21) — warm cream + cool silver is the house; never introduce a third temperature. |

## C. Copy Anti-AI-Tell Checks (the visible-string discipline)

These catch the copy signatures that read "an LLM wrote this." Enforced as **WARN** (review-and-confirm), not hard-fail — they have legitimate exceptions (see the audit script's `// ne-allow:` mechanism).

| Check | Rule | Legitimate exceptions |
|-------|------|----------------------|
| **Em-dash in UI copy** | No `—` (em-dash, U+2014) in generated visible UI copy (button labels, headings, subtitles, badges, micro-copy). It is the #1 AI-copy tell in 2026. | Data strings from source (e.g. `"Jan – Dec"` — that's an en-dash anyway), long-form editorial prose on Atelier surfaces, `aria-label` natural language, code samples shown in `<code>`. Mark with `{/* ne-allow: em-dash */}`. |
| **Fake-precise numbers** | No invented precision (`92%`, `4.1×`, `3,847 users`) unless the number is real + sourced. | Real metrics with a source. |
| **Slop phrases** | Run the Copy NEVER List (anti-vibe-coded.md) — "Unlock your potential", "Supercharge", "Take it to the next level", "Streamline your workflow", fake-cheerful, infantilising. | None — rewrite. |
| **`Space Grotesk`** | Not in the type stack — it has become an AI-default tell (joins Inter/Roboto/Arial/system-ui). | A documented client brand font (per Client Brand Override Protocol). |

> Note: the em-dash and Space-Grotesk checks are WARN (exit 0) in the audit script because they have real false-positive surfaces; a hard FAIL there would erode trust and train operators to ignore the gate. The hard structural bans (rounded-2xl, backdrop-blur, emoji, raw-hex) stay FAIL.

## D. Required-State Matrix (component completeness)

Every **interactive** component must define ALL of these — a missing state is the most common premium-polish gap and an audit finding:

| State | Must define |
|-------|-------------|
| `default` | resting appearance |
| `hover` | the signature feedback (pointer) |
| `focus-visible` | a visible ring on keyboard focus (NOT `:focus` — that fires on mouse-click too) |
| `active` | pressed feedback |
| `disabled` | non-interactive appearance + `aria-disabled` |
| `loading` | async-in-progress (spinner / skeleton, never a layout-shifting swap) |
| `error` | invalid / failed state with a text label (never colour alone) |

Plus the edge cases: long labels (truncate or wrap deliberately), empty state (quiet + actionable, anti-vibe-coded #14), overflow (scroll vs clip decided, not accidental). Keyboard + pointer + touch all reachable.

---

## How to run it

```bash
# Standalone restraint gate (counters + copy WARN checks where mechanically checkable)
bash .claude/skills/ui-design-system/scripts/audit-restraint.sh <project_root_or_file>

# Self-test (proves the byte-safe em-dash check actually fires)
bash .claude/skills/ui-design-system/scripts/audit-restraint.sh --self-test
```

The section-composition counters (A) and the required-state matrix (D) need structural/visual judgement that a grep can't fully do — the script checks what it can (marquee count, em-dash, Space Grotesk, fake-number heuristic) and this file is the manual checklist for the rest. Run both: the script for the mechanical checks, this file for the eyes.

---

## Composes with

- [anti-vibe-coded.md](anti-vibe-coded.md) — the NEVER list (this is its "count it" companion)
- [design-tokens.md](design-tokens.md) §6-7 — the spacing + radius scales the locks reference
- `scripts/audit-restraint.sh` — the mechanical half
- `/design-review` — the audit skill applies these as gradeable findings
