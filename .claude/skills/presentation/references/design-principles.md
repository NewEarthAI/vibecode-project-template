# Design Principles — Visual Standards for Professional Presentations

> These principles ensure every output looks like a senior designer created it,
> not an AI that just dumped text onto slides.

---

## The Three Laws

1. **One Point Per Slide** — If a slide has two messages, split it into two slides
2. **Maximum Visual, Minimal Text** — Large typography, generous whitespace, purposeful graphics
3. **Back-End Integrity** — Every visual element links to a theme/master (never floating)

---

## Typography Scale

### Heading Hierarchy

| Level | HTML | PPTX Size | Usage |
|-------|------|-----------|-------|
| Hero | `clamp(3rem, 7vw, 6rem)` | 54-72pt | Title slides, hook numbers |
| H1 | `clamp(2rem, 4vw, 3.5rem)` | 36-44pt | Slide headings |
| H2 | `clamp(1.5rem, 3vw, 2.5rem)` | 28-32pt | Subheadings |
| Body | `clamp(1rem, 2vw, 1.4rem)` | 16-20pt | Bullet points, paragraphs |
| Caption | `clamp(0.75rem, 1.5vw, 1rem)` | 10-12pt | Footnotes, sources, metadata |
| Mono | Same scale, monospace | Same scale | Code, data, system names |

### Typography Rules

- **Line height**: 1.4 for body, 1.1 for headings
- **Letter spacing**: -0.02em for large headings, normal for body
- **Max line width**: 65 characters for readability
- **Font weight contrast**: Bold headings (700-800), regular body (400)
- **NEVER use all-caps** for body text (OK for small labels/tags)

---

## Color Usage

### The One-Accent-Per-Slide Rule

Each slide should use ONE accent color for emphasis. This creates clear visual hierarchy:

| Element | Color |
|---------|-------|
| Slide background | Primary (dark) |
| Heading | Accent |
| Body text | Text (light) |
| Emphasis word/number | Accent |
| Secondary info | Text Muted |
| Data positive | Success (green) |
| Data negative | Danger (red) |
| Data neutral | Warning (amber) |

### Color Meaning (Consistent Across All Slides)

| Color | Semantic Meaning |
|-------|-----------------|
| Accent (blue) | Primary emphasis, headings, interactive elements |
| Accent2 (green) | Positive outcomes, growth, success |
| Danger (red) | Problems, risks, declines, urgency |
| Warning (amber) | Caution, in-progress, attention needed |
| Success (green) | Completed, positive, achievements |
| Muted (gray) | Supporting info, metadata, footnotes |

### Never Do

- Use more than 3 colors on one slide (background + text + accent)
- Use pure white (#FFFFFF) on dark backgrounds (use off-white #F8FAFC)
- Use pure black (#000000) on light backgrounds (use near-black #0F172A)
- Use color as the ONLY way to convey information (accessibility)

---

## Spacing & Layout

### The 8-Point Grid

All spacing should be multiples of 8px (0.5rem):
- Tight: 8px (0.5rem)
- Default: 16px (1rem)
- Medium: 24px (1.5rem)
- Large: 32px (2rem)
- XL: 48px (3rem)
- XXL: 64px (4rem)

### Slide Padding

| Element | Padding |
|---------|---------|
| Slide edges | 8vmin (responsive to viewport) |
| Between sections | 4vmin |
| Card/box padding | 2vmin |
| Between bullet items | 0.5rem |

### Alignment

- **Left-align** body text (never center long text)
- **Center** hero numbers, single-line quotes, CTAs
- **Consistent** alignment within a slide (don't mix left and center)

---

## Data Visualization Standards

### Chart Selection Guide

| Data Type | Chart | When |
|-----------|-------|------|
| Comparison across categories | Horizontal bar | 3-10 categories |
| Trend over time | Line chart | 5+ time periods |
| Part-to-whole | Donut / pie | 2-5 segments max |
| Single metric score | Gauge / donut | Maturity scores, progress |
| Multi-dimensional assessment | Radar / spider | 4-8 axes (audit domains) |
| Distribution | Histogram | Continuous data |
| Ranking | Horizontal bar (sorted) | Ordered comparison |
| Before vs After | Grouped bar | Two time periods |

### Chart Design Rules

1. **Remove chartjunk** — No 3D effects, no gratuitous gradients, no shadow decorations
2. **Label directly** — Put labels on the data, not in a legend when possible
3. **Start Y-axis at zero** for bar charts (line charts may truncate if range is small)
4. **Use consistent colors** — Same color = same entity across all charts
5. **Right-size the chart** — Chart should fill 60-80% of the available slide area
6. **Add context** — "40% improvement" means nothing without "from X to Y"

### Data Tables

| Principle | Implementation |
|-----------|---------------|
| Header row stands out | Bold, accent color background, white text |
| Alternating rows | Subtle striping for readability |
| Right-align numbers | Numbers column-aligned for comparison |
| Left-align text | Text always left-aligned |
| Highlight key values | Accent color for the most important data point |
| No vertical borders | Horizontal lines only (cleaner) |

---

## Slide Transitions

### For HTML

```css
/* Standard slide transition */
transition: opacity 400ms cubic-bezier(0.25, 0.46, 0.45, 0.94),
            transform 400ms cubic-bezier(0.25, 0.46, 0.45, 0.94);

/* Element stagger (each element 100ms after previous) */
.animate-in:nth-child(1) { animation-delay: 100ms; }
.animate-in:nth-child(2) { animation-delay: 200ms; }
```

### Rules

- **Duration**: 300-500ms (never faster, never slower)
- **Easing**: Always cubic-bezier or ease-out (never linear)
- **Direction**: Content enters from right, exits to left (reading direction)
- **Subtlety**: Small movements (20-60px translate), never bounce or flip
- **Respect accessibility**: `prefers-reduced-motion` disables all animations

---

## Responsive Design (HTML)

### Breakpoints

```css
/* Desktop (default) */
.slide { padding: 8vmin; }

/* Tablet */
@media (max-width: 1024px) {
  .slide { padding: 6vmin; }
  h1 { font-size: clamp(1.5rem, 4vw, 2.5rem); }
}

/* Mobile */
@media (max-width: 640px) {
  .slide { padding: 4vmin; }
  .slide--split { flex-direction: column; }
}
```

### Key Rule: Use Relative Units

- `vw` / `vh` / `vmin` for slide-relative sizing
- `clamp()` for fluid typography
- `%` for flexible widths
- Never use fixed `px` for layout dimensions

---

## Anti-Patterns: What Makes AI Presentations Look Bad

| Anti-Pattern | Why It's Bad | Professional Fix |
|-------------|-------------|-----------------|
| Wall of text (>6 lines) | Audience reads, not listens | Max 5 bullet points, 8 words each |
| Uniform card grid | Everything looks equal importance | Vary slide types and visual weight |
| Centered paragraphs | Hard to read, feels amateur | Left-align body text |
| Drop shadows on everything | Dated, visual noise | Subtle shadow or none |
| Gradient text | Illegible, gimmicky | Solid color text |
| Clipart or stock icons | Looks generic | CSS icons, brand shapes, or real photos |
| Overly complex charts | Audience can't parse in 3 seconds | Simplify to one insight per chart |
| Tiny fonts to fit more content | Unreadable at distance | Split into two slides |
| Logo on every slide | Visual noise | Title slide + CTA only |
| Inconsistent bullet styles | Looks unfinished | Use one bullet style throughout |
| Rainbow colors | Chaotic, no hierarchy | Max 3 colors per slide |

---

## The 3-Second Test

After generating any slide, ask:

> **"Can the audience understand the main point within 3 seconds?"**

If not, the slide needs to be simplified. This is the single most important quality gate.

---

*Reference Version: 1.0 — Visual Standards & Anti-Patterns*
