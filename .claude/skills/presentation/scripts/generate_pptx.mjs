#!/usr/bin/env node

/**
 * PptxGenJS Presentation Generator
 *
 * Generates professional .pptx files from a JSON configuration.
 * All content linked to Slide Master layouts. Theme-aware colors and fonts.
 *
 * Usage:
 *   node generate_pptx.mjs --config <config.json> --output <output.pptx>
 *
 * Config JSON structure:
 * {
 *   "title": "Presentation Title",
 *   "brand": { ... brand config ... },
 *   "slides": [ ... slide definitions ... ]
 * }
 */

import { readFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Parse CLI args
const args = process.argv.slice(2);
const configIndex = args.indexOf('--config');
const outputIndex = args.indexOf('--output');

if (configIndex === -1 || outputIndex === -1) {
  console.error('Usage: node generate_pptx.mjs --config <config.json> --output <output.pptx>');
  process.exit(1);
}

const configPath = resolve(args[configIndex + 1]);
const outputPath = resolve(args[outputIndex + 1]);

if (!existsSync(configPath)) {
  console.error(`Config file not found: ${configPath}`);
  process.exit(1);
}

// Dynamic import of PptxGenJS (installed in scripts/)
let PptxGenJS;
try {
  PptxGenJS = (await import('pptxgenjs')).default;
} catch (e) {
  console.error('PptxGenJS not installed. Run: cd .claude/skills/presentation/scripts && npm install pptxgenjs');
  process.exit(1);
}

// Load config
const config = JSON.parse(readFileSync(configPath, 'utf8'));
const brand = config.brand || getDefaultBrand();
const slides = config.slides || [];

// Strip '#' from hex colors for PptxGenJS (it expects without hash)
function c(hex) {
  return (hex || '').replace('#', '');
}

function getDefaultBrand() {
  return {
    name: 'Default Brand',
    colors: {
      primary: '#0F172A', secondary: '#1E293B', accent: '#3B82F6',
      accent2: '#10B981', text: '#F8FAFC', textSecondary: '#CBD5E1',
      textMuted: '#64748B', danger: '#EF4444', warning: '#F59E0B',
      success: '#22C55E', border: '#475569', cardBg: '#334155'
    },
    typography: {
      heading: 'Inter', body: 'Inter', mono: 'Courier New',
      headingWeight: '700', bodyWeight: '400'
    },
    footer: { text: 'Presentation', showSlideNumber: true }
  };
}

// Extract primary font name from font stack
function fontName(fontStack) {
  if (!fontStack) return 'Inter';
  return fontStack.split(',')[0].replace(/['"]/g, '').trim();
}

// ─── Initialize Presentation ───
const pptx = new PptxGenJS();
pptx.layout = 'LAYOUT_16x9';
pptx.author = brand.name || 'Presentation';
pptx.company = brand.name || 'Presentation';
pptx.subject = config.title || 'Presentation';
pptx.title = config.title || 'Presentation';

const headingFont = fontName(brand.typography?.heading);
const bodyFont = fontName(brand.typography?.body);

// ─── Define Slide Masters ───

// Base master (shared footer)
pptx.defineSlideMaster({
  title: 'MASTER_BASE',
  background: { color: c(brand.colors.primary) },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.04, fill: { color: c(brand.colors.accent) } } },
    { text: {
      text: brand.footer?.text || brand.name,
      options: { x: 0.5, y: '93%', w: 3, h: 0.35,
        color: c(brand.colors.textMuted), fontSize: 8, fontFace: bodyFont }
    }}
  ]
});

// Title layout
pptx.defineSlideMaster({
  title: 'LAYOUT_TITLE',
  background: { color: c(brand.colors.primary) },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.04, fill: { color: c(brand.colors.accent) } } },
    { placeholder: {
      options: { name: 'title', type: 'title',
        x: 1, y: 2.2, w: 8, h: 1.5,
        color: c(brand.colors.text), fontSize: 44, fontFace: headingFont,
        bold: true, align: 'center' }
    }},
    { placeholder: {
      options: { name: 'subtitle', type: 'body',
        x: 1.5, y: 4, w: 7, h: 1,
        color: c(brand.colors.textSecondary), fontSize: 20, fontFace: bodyFont,
        align: 'center' }
    }}
  ]
});

// Content layout
pptx.defineSlideMaster({
  title: 'LAYOUT_CONTENT',
  background: { color: c(brand.colors.primary) },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.04, fill: { color: c(brand.colors.accent) } } },
    { placeholder: {
      options: { name: 'heading', type: 'title',
        x: 0.8, y: 0.3, w: 8.4, h: 0.8,
        color: c(brand.colors.accent), fontSize: 28, fontFace: headingFont, bold: true }
    }},
    { placeholder: {
      options: { name: 'body', type: 'body',
        x: 0.8, y: 1.4, w: 8.4, h: 4.8,
        color: c(brand.colors.text), fontSize: 16, fontFace: bodyFont,
        paraSpaceAfter: 8 }
    }}
  ]
});

// Bold Claim layout
pptx.defineSlideMaster({
  title: 'LAYOUT_CLAIM',
  background: { color: c(brand.colors.primary) },
  objects: [
    { placeholder: {
      options: { name: 'stat', type: 'title',
        x: 1, y: 1.2, w: 8, h: 2.5,
        color: c(brand.colors.accent), fontSize: 72, fontFace: headingFont,
        bold: true, align: 'center' }
    }},
    { placeholder: {
      options: { name: 'context', type: 'body',
        x: 1.5, y: 4, w: 7, h: 1.5,
        color: c(brand.colors.textSecondary), fontSize: 20, fontFace: bodyFont,
        align: 'center' }
    }}
  ]
});

// Split layout
pptx.defineSlideMaster({
  title: 'LAYOUT_SPLIT',
  background: { color: c(brand.colors.primary) },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.04, fill: { color: c(brand.colors.accent) } } },
    { placeholder: {
      options: { name: 'heading', type: 'title',
        x: 0.8, y: 0.3, w: 8.4, h: 0.8,
        color: c(brand.colors.accent), fontSize: 28, fontFace: headingFont, bold: true }
    }},
    { placeholder: {
      options: { name: 'left', type: 'body',
        x: 0.5, y: 1.4, w: 4.2, h: 4.8,
        color: c(brand.colors.text), fontSize: 14, fontFace: bodyFont }
    }},
    { placeholder: {
      options: { name: 'right', type: 'body',
        x: 5.3, y: 1.4, w: 4.2, h: 4.8,
        color: c(brand.colors.text), fontSize: 14, fontFace: bodyFont }
    }}
  ]
});

// Data layout
pptx.defineSlideMaster({
  title: 'LAYOUT_DATA',
  background: { color: c(brand.colors.primary) },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.04, fill: { color: c(brand.colors.accent) } } },
    { placeholder: {
      options: { name: 'heading', type: 'title',
        x: 0.8, y: 0.3, w: 8.4, h: 0.8,
        color: c(brand.colors.accent), fontSize: 28, fontFace: headingFont, bold: true }
    }}
  ]
});

// CTA layout
pptx.defineSlideMaster({
  title: 'LAYOUT_CTA',
  background: { color: c(brand.colors.primary) },
  objects: [
    { rect: { x: 0, y: 0, w: '100%', h: 0.04, fill: { color: c(brand.colors.accent) } } },
    { placeholder: {
      options: { name: 'heading', type: 'title',
        x: 1, y: 2, w: 8, h: 1.5,
        color: c(brand.colors.text), fontSize: 36, fontFace: headingFont,
        bold: true, align: 'center' }
    }},
    { placeholder: {
      options: { name: 'body', type: 'body',
        x: 2, y: 3.8, w: 6, h: 2,
        color: c(brand.colors.textSecondary), fontSize: 18, fontFace: bodyFont,
        align: 'center' }
    }}
  ]
});

// ─── Generate Slides ───

for (const slideDef of slides) {
  const type = slideDef.type || 'content';
  const layout = `LAYOUT_${type.toUpperCase()}`;

  // Check if layout exists, fallback to LAYOUT_CONTENT
  const masterName = ['LAYOUT_TITLE', 'LAYOUT_CONTENT', 'LAYOUT_CLAIM',
    'LAYOUT_SPLIT', 'LAYOUT_DATA', 'LAYOUT_CTA'].includes(layout) ? layout : 'LAYOUT_CONTENT';

  const slide = pptx.addSlide({ masterName });

  switch (type) {
    case 'title':
      if (slideDef.title) slide.addText(slideDef.title, { placeholder: 'title' });
      if (slideDef.subtitle) slide.addText(slideDef.subtitle, { placeholder: 'subtitle' });
      break;

    case 'content':
      if (slideDef.heading) slide.addText(slideDef.heading, { placeholder: 'heading' });
      if (slideDef.bullets) {
        const bulletText = slideDef.bullets.map(b => ({
          text: b + '\n', options: { bullet: true }
        }));
        slide.addText(bulletText, { placeholder: 'body' });
      } else if (slideDef.body) {
        slide.addText(slideDef.body, { placeholder: 'body' });
      }
      break;

    case 'claim':
      if (slideDef.stat) slide.addText(slideDef.stat, { placeholder: 'stat' });
      if (slideDef.context) slide.addText(slideDef.context, { placeholder: 'context' });
      break;

    case 'split':
      if (slideDef.heading) slide.addText(slideDef.heading, { placeholder: 'heading' });
      if (slideDef.left) slide.addText(slideDef.left, { placeholder: 'left' });
      if (slideDef.right) slide.addText(slideDef.right, { placeholder: 'right' });
      break;

    case 'data':
      if (slideDef.heading) slide.addText(slideDef.heading, { placeholder: 'heading' });

      // Table
      if (slideDef.table) {
        const rows = slideDef.table.map((row, i) => {
          if (i === 0) {
            return row.map(cell => ({
              text: cell,
              options: { bold: true, color: 'FFFFFF', fill: { color: c(brand.colors.accent) } }
            }));
          }
          return row;
        });
        slide.addTable(rows, {
          x: 0.5, y: 1.4, w: 9, h: 4.5,
          fontSize: 12, fontFace: bodyFont,
          color: c(brand.colors.text),
          border: { type: 'solid', pt: 0.5, color: c(brand.colors.border) },
          autoPage: true, autoPageRepeatHeader: true
        });
      }

      // Bar chart
      if (slideDef.chart?.type === 'bar') {
        slide.addChart(pptx.charts.BAR, slideDef.chart.data, {
          x: 0.8, y: 1.4, w: 8.4, h: 4.8,
          showTitle: false,
          catAxisLabelColor: c(brand.colors.textSecondary),
          valAxisLabelColor: c(brand.colors.textSecondary),
          chartColors: [c(brand.colors.accent), c(brand.colors.accent2),
            c(brand.colors.warning), c(brand.colors.danger)],
          dataLabelColor: c(brand.colors.text),
          showValue: true,
          valAxisMaxVal: slideDef.chart.maxVal || undefined,
        });
      }

      // Line chart
      if (slideDef.chart?.type === 'line') {
        slide.addChart(pptx.charts.LINE, slideDef.chart.data, {
          x: 0.8, y: 1.4, w: 8.4, h: 4.8,
          showTitle: false,
          lineDataSymbol: 'circle',
          lineDataSymbolSize: 8,
          chartColors: [c(brand.colors.accent), c(brand.colors.accent2)],
          catAxisLabelColor: c(brand.colors.textSecondary),
          valAxisLabelColor: c(brand.colors.textSecondary),
        });
      }

      // Donut chart
      if (slideDef.chart?.type === 'donut') {
        slide.addChart(pptx.charts.DOUGHNUT, slideDef.chart.data, {
          x: 2, y: 1.4, w: 6, h: 4.8,
          showTitle: false,
          chartColors: [c(brand.colors.accent), c(brand.colors.accent2),
            c(brand.colors.warning), c(brand.colors.danger)],
          dataLabelColor: c(brand.colors.text),
          showPercent: true,
          holeSize: 50,
        });
      }
      break;

    case 'cta':
      if (slideDef.heading) slide.addText(slideDef.heading, { placeholder: 'heading' });
      if (slideDef.body) slide.addText(slideDef.body, { placeholder: 'body' });
      break;

    default:
      // Fallback: treat as content
      if (slideDef.heading) slide.addText(slideDef.heading, { placeholder: 'heading' });
      if (slideDef.body) slide.addText(slideDef.body, { placeholder: 'body' });
  }

  // Add image if specified
  if (slideDef.image) {
    const imgOpts = {
      x: slideDef.image.x || 1,
      y: slideDef.image.y || 1.5,
      w: slideDef.image.w || 8,
      h: slideDef.image.h || 4.5,
    };
    if (slideDef.image.path) imgOpts.path = slideDef.image.path;
    if (slideDef.image.data) imgOpts.data = slideDef.image.data;
    slide.addImage(imgOpts);
  }

  // Speaker notes
  if (slideDef.notes) {
    slide.addNotes(slideDef.notes);
  }
}

// ─── Save ───
try {
  await pptx.writeFile({ fileName: outputPath });
  console.log(`Presentation saved: ${outputPath}`);
  console.log(`Slides: ${slides.length}`);
  console.log(`Brand: ${brand.name}`);
} catch (err) {
  console.error('Failed to save presentation:', err.message);
  process.exit(1);
}
