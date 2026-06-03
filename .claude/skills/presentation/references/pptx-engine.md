# PPTX Engine — PptxGenJS Corporate Presentation Generator

> Complete reference for generating professional .pptx files using PptxGenJS.
> All content linked to Slide Masters. Theme-aware colors and fonts.
> Charts linked to embedded data. Compatible with PowerPoint, Keynote, Google Slides.

---

## Architecture

```
Brand Config (JSON)
      ↓
PptxGenJS Script (generate_pptx.mjs)
      ↓
Slide Master + Layouts defined
      ↓
Content mapped to layouts
      ↓
Charts generated from data
      ↓
.pptx file output
```

---

## Script Usage

```bash
# Install dependency (one-time)
cd .claude/skills/presentation/scripts && npm install pptxgenjs

# Generate presentation
node .claude/skills/presentation/scripts/generate_pptx.mjs \
  --config presentation-config.json \
  --output presentations/my-deck/presentation.pptx
```

---

## Slide Master & Layout System

### Why Masters Matter

| Without Masters | With Masters |
|----------------|-------------|
| Loose shapes that can't be bulk-edited | Layout-linked placeholders |
| Colors hardcoded per element | Theme-linked accent colors |
| Fonts manually set per text box | Theme font families |
| PowerPoint "Design Ideas" broken | Design Ideas fully compatible |
| Rebrand = touch every slide | Rebrand = change master once |

### Defining the Master

```javascript
import PptxGenJS from 'pptxgenjs';

const pptx = new PptxGenJS();

// Set presentation properties
pptx.layout = 'LAYOUT_16x9';
pptx.author = '{{brand_name}}';
pptx.company = '{{brand_name}}';
pptx.subject = '{{presentation_subject}}';

// Define Slide Master
pptx.defineSlideMaster({
  title: 'MASTER_SLIDE',
  background: { color: '0F172A' },
  objects: [
    // Top accent bar
    { rect: { x: 0, y: 0, w: '100%', h: 0.05, fill: { color: '3B82F6' } } },
    // Footer with page number
    { text: {
      text: '{{brand_name}}',
      options: { x: 0.5, y: '93%', w: 3, h: 0.4,
        color: '64748B', fontSize: 8, fontFace: 'Inter' }
    }},
    // Slide number
    { text: {
      text: { type: 'slideNumber' },
      options: { x: '90%', y: '93%', w: 0.8, h: 0.4,
        color: '64748B', fontSize: 8, align: 'right', fontFace: 'Inter' }
    }}
  ]
});
```

### Layout Definitions

```javascript
// Title Slide Layout
pptx.defineSlideMaster({
  title: 'LAYOUT_TITLE',
  background: { color: '0F172A' },
  objects: [
    { placeholder: {
      options: { name: 'title', type: 'title',
        x: 1, y: 2.5, w: 8, h: 1.5,
        color: 'F8FAFC', fontSize: 44, fontFace: 'Inter',
        bold: true, align: 'center' }
    }},
    { placeholder: {
      options: { name: 'subtitle', type: 'body',
        x: 1.5, y: 4.2, w: 7, h: 1,
        color: 'CBD5E1', fontSize: 20, fontFace: 'Inter',
        align: 'center' }
    }}
  ]
});

// Content Slide Layout
pptx.defineSlideMaster({
  title: 'LAYOUT_CONTENT',
  background: { color: '0F172A' },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.05, fill: { color: '3B82F6' } } },
    { placeholder: {
      options: { name: 'heading', type: 'title',
        x: 0.8, y: 0.4, w: 8.4, h: 0.8,
        color: '3B82F6', fontSize: 28, fontFace: 'Inter', bold: true }
    }},
    { placeholder: {
      options: { name: 'body', type: 'body',
        x: 0.8, y: 1.5, w: 8.4, h: 4.5,
        color: 'F8FAFC', fontSize: 16, fontFace: 'Inter',
        paraSpaceAfter: 8 }
    }}
  ]
});

// Split Slide Layout (Two Columns)
pptx.defineSlideMaster({
  title: 'LAYOUT_SPLIT',
  background: { color: '0F172A' },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.05, fill: { color: '3B82F6' } } },
    { placeholder: {
      options: { name: 'heading', type: 'title',
        x: 0.8, y: 0.4, w: 8.4, h: 0.8,
        color: '3B82F6', fontSize: 28, fontFace: 'Inter', bold: true }
    }},
    { placeholder: {
      options: { name: 'left', type: 'body',
        x: 0.5, y: 1.5, w: 4.2, h: 4.5,
        color: 'F8FAFC', fontSize: 14, fontFace: 'Inter' }
    }},
    { placeholder: {
      options: { name: 'right', type: 'body',
        x: 5.3, y: 1.5, w: 4.2, h: 4.5,
        color: 'F8FAFC', fontSize: 14, fontFace: 'Inter' }
    }}
  ]
});

// Data Slide Layout (Chart Area)
pptx.defineSlideMaster({
  title: 'LAYOUT_DATA',
  background: { color: '0F172A' },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.05, fill: { color: '3B82F6' } } },
    { placeholder: {
      options: { name: 'heading', type: 'title',
        x: 0.8, y: 0.4, w: 8.4, h: 0.8,
        color: '3B82F6', fontSize: 28, fontFace: 'Inter', bold: true }
    }}
    // Chart area left open for dynamic placement
  ]
});

// Bold Claim Layout
pptx.defineSlideMaster({
  title: 'LAYOUT_CLAIM',
  background: { color: '0F172A' },
  objects: [
    { placeholder: {
      options: { name: 'stat', type: 'title',
        x: 1, y: 1.5, w: 8, h: 2.5,
        color: '3B82F6', fontSize: 72, fontFace: 'Inter',
        bold: true, align: 'center' }
    }},
    { placeholder: {
      options: { name: 'context', type: 'body',
        x: 1.5, y: 4.2, w: 7, h: 1.5,
        color: 'CBD5E1', fontSize: 20, fontFace: 'Inter',
        align: 'center' }
    }}
  ]
});
```

---

## Adding Slides

```javascript
// Title slide
const titleSlide = pptx.addSlide({ masterName: 'LAYOUT_TITLE' });
titleSlide.addText('AI Maturity Audit Report', { placeholder: 'title' });
titleSlide.addText('Prepared for {{client_name}} — {{date}}', { placeholder: 'subtitle' });
titleSlide.addNotes('Welcome slide. Introduce the audit scope and methodology.');

// Content slide
const contentSlide = pptx.addSlide({ masterName: 'LAYOUT_CONTENT' });
contentSlide.addText('Key Findings', { placeholder: 'heading' });
contentSlide.addText([
  { text: 'Data maturity at Level 2 — significant opportunity\n', options: { bullet: true } },
  { text: 'Process documentation gaps identified\n', options: { bullet: true } },
  { text: '3 quick wins identified (30-day implementation)\n', options: { bullet: true } },
  { text: 'Estimated 40% time savings on fleet dispatch\n', options: { bullet: true } },
], { placeholder: 'body' });
contentSlide.addNotes('Walk through each finding. Emphasize quick wins.');

// Bold claim slide
const claimSlide = pptx.addSlide({ masterName: 'LAYOUT_CLAIM' });
claimSlide.addText('40%', { placeholder: 'stat' });
claimSlide.addText('estimated time savings on fleet dispatch operations', { placeholder: 'context' });
```

---

## Charts

### Bar Chart
```javascript
const chartData = [
  { name: 'Strategy', labels: ['Score'], values: [2] },
  { name: 'Data', labels: ['Score'], values: [1.5] },
  { name: 'Technology', labels: ['Score'], values: [3] },
  { name: 'People', labels: ['Score'], values: [2] },
  { name: 'Process', labels: ['Score'], values: [1.5] },
  { name: 'Governance', labels: ['Score'], values: [2.5] },
];

const dataSlide = pptx.addSlide({ masterName: 'LAYOUT_DATA' });
dataSlide.addText('Maturity Scores by Domain', { placeholder: 'heading' });
dataSlide.addChart(pptx.charts.BAR, chartData, {
  x: 0.8, y: 1.5, w: 8.4, h: 4.5,
  showTitle: false,
  catAxisLabelColor: 'CBD5E1',
  valAxisLabelColor: 'CBD5E1',
  chartColors: ['3B82F6', '10B981', 'F59E0B', 'EF4444', '8B5CF6', '06B6D4'],
  dataLabelColor: 'F8FAFC',
  showValue: true,
  valAxisMaxVal: 5,
});
```

### Pie/Donut Chart
```javascript
slide.addChart(pptx.charts.DOUGHNUT, [{
  name: 'Distribution',
  labels: ['Automated', 'Semi-Auto', 'Manual'],
  values: [35, 25, 40]
}], {
  x: 1, y: 1.5, w: 4, h: 4,
  chartColors: ['22C55E', 'F59E0B', 'EF4444'],
  dataLabelColor: 'F8FAFC',
  showPercent: true,
  holeSize: 50,
});
```

### Line Chart (Trend)
```javascript
slide.addChart(pptx.charts.LINE, [{
  name: 'Efficiency',
  labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
  values: [55, 62, 68, 71, 78, 85]
}], {
  x: 0.8, y: 1.5, w: 8.4, h: 4.5,
  lineDataSymbol: 'circle',
  lineDataSymbolSize: 8,
  chartColors: ['3B82F6'],
  catAxisLabelColor: 'CBD5E1',
  valAxisLabelColor: 'CBD5E1',
});
```

---

## Tables

```javascript
const tableRows = [
  [
    { text: 'Domain', options: { bold: true, color: 'FFFFFF', fill: { color: '3B82F6' } } },
    { text: 'Score', options: { bold: true, color: 'FFFFFF', fill: { color: '3B82F6' } } },
    { text: 'Level', options: { bold: true, color: 'FFFFFF', fill: { color: '3B82F6' } } },
    { text: 'Gap', options: { bold: true, color: 'FFFFFF', fill: { color: '3B82F6' } } },
  ],
  ['Strategy & Leadership', '2.0', 'Emerging', 'No AI roadmap tied to KPIs'],
  ['Data & Information', '1.5', 'Ad Hoc → Emerging', 'Spreadsheet-based, no SOT'],
  ['Technology', '3.0', 'Defined', 'Core systems integrated'],
  ['People & Skills', '2.0', 'Emerging', 'Limited AI tool adoption'],
  ['Process & Operations', '1.5', 'Ad Hoc → Emerging', 'Undocumented processes'],
  ['Governance & Risk', '2.5', 'Emerging → Defined', 'Basic controls in place'],
];

slide.addTable(tableRows, {
  x: 0.5, y: 1.5, w: 9, h: 4,
  fontSize: 12,
  fontFace: 'Inter',
  color: 'F8FAFC',
  border: { type: 'solid', pt: 0.5, color: '475569' },
  rowH: [0.5, 0.45, 0.45, 0.45, 0.45, 0.45, 0.45],
  autoPage: true,
  autoPageRepeatHeader: true,
});
```

---

## Images & Diagrams

```javascript
// Add image from file path
slide.addImage({
  path: 'presentations/my-deck/assets/architecture-diagram.png',
  x: 1, y: 1.5, w: 8, h: 4.5,
});

// Add image from base64
slide.addImage({
  data: 'data:image/png;base64,iVBORw0KGgo...',
  x: 8.5, y: 0.2, w: 1.2, h: 0.6,
});

// Add SVG
slide.addImage({
  path: 'diagrams/architecture.svg',
  x: 1, y: 1.5, w: 8, h: 4,
});
```

---

## Speaker Notes

Every slide MUST have speaker notes:

```javascript
slide.addNotes(`
Key talking points:
- The composite maturity score of 2.1 puts the organization in the "Digital" band
- This is typical for SMEs in the logistics sector
- The good news: 3 quick wins identified that can show ROI within 30 days
- Recommend starting with fleet dispatch automation (highest impact/lowest effort)
`);
```

---

## Saving the File

```javascript
// Write to file (Node.js)
await pptx.writeFile({ fileName: 'presentations/my-deck/presentation.pptx' });
console.log('Presentation saved successfully.');
```

---

## Critical Rules

1. **NEVER create loose shapes** — Always use Slide Master layouts with placeholders
2. **NEVER hardcode colors** — Use theme-linked values from brand config
3. **NEVER skip speaker notes** — Every slide needs talking points
4. **NEVER reuse option objects** — PptxGenJS mutates them in-place (shadow → EMU conversion)
5. **16:9 aspect ratio** — Always use `LAYOUT_16x9`
6. **Font availability** — Use system fonts (Inter, Segoe UI) that are widely available

---

*Reference Version: 1.0 — PptxGenJS Corporate Engine*
