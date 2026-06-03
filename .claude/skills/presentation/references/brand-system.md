# Brand System — Per-Client Theme Configuration

> Every presentation inherits its visual identity from a brand configuration file.
> One brand change = every slide updated. No hardcoded colors anywhere.

---

## Brand Config Schema

Brand configurations are stored as JSON in `presentations/brands/{slug}.json`.

```json
{
  "name": "{{Brand Name}}",
  "slug": "{{brand-slug}}",

  "colors": {
    "primary": "#0F172A",
    "secondary": "#1E293B",
    "accent": "#3B82F6",
    "accent2": "#10B981",
    "text": "#F8FAFC",
    "textSecondary": "#CBD5E1",
    "textMuted": "#64748B",
    "danger": "#EF4444",
    "warning": "#F59E0B",
    "success": "#22C55E",
    "border": "#475569",
    "cardBg": "#334155"
  },

  "typography": {
    "heading": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "body": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "mono": "'JetBrains Mono', 'SF Mono', 'Fira Code', monospace",
    "headingWeight": "700",
    "bodyWeight": "400"
  },

  "logo": {
    "path": null,
    "base64": null,
    "width": "120px",
    "position": "top-right"
  },

  "theme": {
    "mode": "dark",
    "slideBackground": "#0F172A",
    "accentBarHeight": "4px",
    "borderRadius": "8px",
    "shadowIntensity": "0.3"
  },

  "footer": {
    "text": "{{Brand Name}}",
    "showSlideNumber": true,
    "showDate": false
  }
}
```

---

## Built-in Brands

### {{Your Brand}} (Default)

```json
{
  "name": "{{Your Brand}}",
  "slug": "your-brand",
  "colors": {
    "primary": "#0F172A",
    "secondary": "#1E293B",
    "accent": "#3B82F6",
    "accent2": "#10B981",
    "text": "#F8FAFC",
    "textSecondary": "#CBD5E1",
    "textMuted": "#64748B",
    "danger": "#EF4444",
    "warning": "#F59E0B",
    "success": "#22C55E",
    "border": "#475569",
    "cardBg": "#334155"
  },
  "typography": {
    "heading": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "body": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "mono": "'JetBrains Mono', 'SF Mono', 'Fira Code', monospace",
    "headingWeight": "700",
    "bodyWeight": "400"
  },
  "logo": { "path": null, "base64": null },
  "theme": { "mode": "dark", "slideBackground": "#0F172A" },
  "footer": { "text": "{{Your Brand}}", "showSlideNumber": true }
}
```

### {{Client Brand}}

```json
{
  "name": "{{Client Brand}}",
  "slug": "client-brand",
  "colors": {
    "primary": "#0C0A09",
    "secondary": "#1C1917",
    "accent": "#F97316",
    "accent2": "#EAB308",
    "text": "#FAFAF9",
    "textSecondary": "#D6D3D1",
    "textMuted": "#78716C",
    "danger": "#EF4444",
    "warning": "#F59E0B",
    "success": "#22C55E",
    "border": "#44403C",
    "cardBg": "#292524"
  },
  "typography": {
    "heading": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "body": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "mono": "'JetBrains Mono', monospace",
    "headingWeight": "800",
    "bodyWeight": "400"
  },
  "logo": { "path": null, "base64": null },
  "theme": { "mode": "dark", "slideBackground": "#0C0A09" },
  "footer": { "text": "{{Client Brand}}", "showSlideNumber": true }
}
```

### {{Client Brand 2}}

```json
{
  "name": "{{Client Brand 2}}",
  "slug": "client-brand-2",
  "colors": {
    "primary": "#022C22",
    "secondary": "#064E3B",
    "accent": "#10B981",
    "accent2": "#06B6D4",
    "text": "#F0FDF4",
    "textSecondary": "#BBF7D0",
    "textMuted": "#6EE7B7",
    "danger": "#EF4444",
    "warning": "#F59E0B",
    "success": "#22C55E",
    "border": "#065F46",
    "cardBg": "#064E3B"
  },
  "typography": {
    "heading": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "body": "'Inter', -apple-system, 'Segoe UI', sans-serif",
    "mono": "'JetBrains Mono', monospace",
    "headingWeight": "700",
    "bodyWeight": "400"
  },
  "logo": { "path": null, "base64": null },
  "theme": { "mode": "dark", "slideBackground": "#022C22" },
  "footer": { "text": "{{Client Brand 2}}", "showSlideNumber": true }
}
```

### Light Theme (Print-Friendly)

```json
{
  "name": "{{Your Brand}} Light",
  "slug": "your-brand-light",
  "colors": {
    "primary": "#FFFFFF",
    "secondary": "#F8FAFC",
    "accent": "#2563EB",
    "accent2": "#059669",
    "text": "#0F172A",
    "textSecondary": "#475569",
    "textMuted": "#94A3B8",
    "danger": "#DC2626",
    "warning": "#D97706",
    "success": "#16A34A",
    "border": "#E2E8F0",
    "cardBg": "#F1F5F9"
  },
  "theme": { "mode": "light", "slideBackground": "#FFFFFF" },
  "footer": { "text": "{{Your Brand}}", "showSlideNumber": true }
}
```

---

## Applying Brand to HTML

Map brand config keys to CSS variables:

```css
:root {
  --bg-primary: {{colors.primary}};
  --bg-secondary: {{colors.secondary}};
  --bg-card: {{colors.cardBg}};
  --text-primary: {{colors.text}};
  --text-secondary: {{colors.textSecondary}};
  --text-muted: {{colors.textMuted}};
  --accent: {{colors.accent}};
  --accent-2: {{colors.accent2}};
  --danger: {{colors.danger}};
  --warning: {{colors.warning}};
  --success: {{colors.success}};
  --border: {{colors.border}};
  --font-heading: {{typography.heading}};
  --font-body: {{typography.body}};
  --font-mono: {{typography.mono}};
}
```

---

## Applying Brand to PPTX

Map brand config to PptxGenJS Slide Master:

```javascript
// Background
background: { color: brand.colors.primary.replace('#', '') }

// Accent bar
fill: { color: brand.colors.accent.replace('#', '') }

// Text colors
color: brand.colors.text.replace('#', '')

// Font
fontFace: brand.typography.heading.split("'")[1] || 'Inter'
```

---

## Creating a New Brand

When the user wants to create a brand for a new client:

1. **Ask for brand assets**: Logo, primary color, secondary color, font preference
2. **Generate color palette**: From the primary color, derive secondary, accent, text colors
3. **Create brand file**: Write to `presentations/brands/{slug}.json`
4. **Verify contrast**: Ensure text is readable on background (WCAG AA minimum)

### Color Derivation from Single Primary Color

If only one color is provided, derive the full palette:

| Given | Derive |
|-------|--------|
| Primary (dark bg) | Lighten for secondary, accent stays user-provided or complementary |
| Primary (light) | Darken for secondary, accent stays vivid |

### Contrast Check

Minimum contrast ratios (WCAG AA):
- **Normal text**: 4.5:1 against background
- **Large text (≥18px bold)**: 3:1 against background
- **UI components**: 3:1 against adjacent colors

---

## Brand Discovery Protocol

When creating presentations for a known client:

1. Check `presentations/brands/{slug}.json` — if exists, use it
2. Check `presentations/brands/{slug}/` — folder with assets
3. Check `clients/{slug}/PROFILE.yaml` — may contain brand info
4. Check the client's website via WebFetch — scrape colors/fonts
5. Ask the user — "What are {{client}}'s brand colors?"
6. Default — Use {{Your Brand}} brand

---

## Brand Asset Ingestion (Image Upload Workflow)

### What You Can Upload

Users can provide brand materials in ANY of these ways:

| Asset Type | What Claude Does |
|-----------|-----------------|
| **Logo file** (PNG, SVG, JPG) | Reads the image, converts to base64, stores in brand config |
| **Style guide PDF** | Reads the PDF, extracts colors, fonts, spacing rules, logo |
| **Screenshot of existing materials** | Reads the image, identifies colors, layout style, typography |
| **Brand colors** (hex codes, list) | Maps directly to the color palette schema |
| **Website URL** | Fetches the site, extracts CSS colors, fonts, logo |
| **Existing presentation** | Reads the PPTX/PDF, reverse-engineers the brand theme |
| **Color palette image** | Reads the image, identifies dominant and accent colors |

### Workflow: Creating a Brand from Uploaded Assets

**Step 1: Collect Assets**

Ask the user (or they proactively provide):
```
To create a perfectly on-brand presentation, I can work with any of these:
1. Logo file (PNG, SVG, or JPG)
2. Brand style guide or PDF
3. Screenshot of existing branded material
4. Hex color codes (primary, accent)
5. Website URL
6. Existing presentation to match

What do you have available?
```

**Step 2: Asset Storage**

Create the brand folder structure:
```
presentations/brands/{slug}/
├── {slug}.json             # Brand config (generated)
├── logo.png                # Primary logo (uploaded or extracted)
├── logo-light.png          # Light version (if provided)
├── logo-dark.png           # Dark version (if provided)
├── icon.png                # Favicon/icon version (if provided)
├── source-assets/          # Original uploaded files (for reference)
│   ├── style-guide.pdf
│   ├── screenshot.png
│   └── existing-deck.pptx
└── README.md               # Brand notes and extraction log
```

**Step 3: Color Extraction from Images**

When reading an uploaded image (logo, screenshot, style guide):

1. **Read the image** using the Read tool (Claude is multimodal — it can see images)
2. **Identify colors visually**:
   - Primary background color
   - Primary accent/brand color
   - Secondary accent color
   - Text colors (heading vs body)
   - Any warning/success/danger indicator colors
3. **Map to brand schema**:
   ```json
   {
     "colors": {
       "primary": "[extracted dark bg color]",
       "accent": "[extracted brand highlight color]",
       "accent2": "[extracted secondary highlight]",
       "text": "[extracted heading text color]"
     }
   }
   ```
4. **Verify with user**: "I extracted these colors from your materials: [show swatches]. Look correct?"

**Step 4: Logo Processing**

When a logo is uploaded:

1. **Read the image** to verify it's a valid logo
2. **Convert to base64** for embedding:
   ```bash
   base64 -i presentations/brands/{slug}/logo.png | tr -d '\n' > /tmp/logo-b64.txt
   ```
3. **Store both ways**:
   - `logo.path`: relative path to the file (for local generation)
   - `logo.base64`: base64 string (for embedding in HTML/PPTX)
4. **Size check**: Recommend PNG at 400-800px wide for presentations

**Step 5: Website Scraping**

When a website URL is provided:

1. **WebFetch the site** with prompt: "Extract the brand identity: primary colors (hex), accent colors, fonts used, logo URL"
2. **Map extracted values** to brand schema
3. **Download logo** if found
4. **Cross-reference** with any uploaded assets

**Step 6: Generate Brand Config**

Combine all extracted data into `presentations/brands/{slug}.json`:

```json
{
  "name": "{{Client Name}}",
  "slug": "{{client-slug}}",
  "source": {
    "extractedFrom": ["logo.png", "website", "style-guide.pdf"],
    "extractedDate": "2026-03-04",
    "verifiedByUser": true
  },
  "colors": { ... },
  "typography": { ... },
  "logo": {
    "path": "presentations/brands/{{slug}}/logo.png",
    "base64": "data:image/png;base64,...",
    "width": "120px",
    "position": "top-right"
  },
  "theme": { ... },
  "footer": { ... }
}
```

**Step 7: Verify**

Generate a single test slide using the extracted brand and show it to the user:
```
Here's a test slide using the extracted brand. Does this look right?
- Colors match your brand?
- Logo positioned correctly?
- Typography feels right?
```

---

## Multiple Logo Variants

Brands often have different logo versions:

| Variant | Use When | Config Key |
|---------|----------|-----------|
| Primary | Default, dark backgrounds | `logo.path` |
| Light | Light backgrounds | `logo.lightPath` |
| Dark | Very dark backgrounds | `logo.darkPath` |
| Icon only | Small spaces, favicons | `logo.iconPath` |
| Horizontal | Wide header areas | `logo.horizontalPath` |
| Stacked | Title slides, square spaces | `logo.stackedPath` |

The skill auto-selects the right variant based on slide type and theme mode.

---

## Brand Inheritance

For client-facing presentations where both agency and client brands appear:

```json
{
  "name": "{{Client Brand 2}} (by {{Your Brand}})",
  "inherits": "client-brand-2",
  "overrides": {
    "footer": {
      "text": "Prepared by {{Your Brand}} for {{Client Brand 2}}"
    }
  },
  "coBranding": {
    "enabled": true,
    "agencyLogo": "presentations/brands/your-brand/logo.png",
    "agencyLogoPosition": "bottom-right",
    "clientLogoPosition": "top-right"
  }
}
```

---

## Quick Brand Creation Prompts

Users can say:
- *"Create a brand for [client name]"* → Full wizard
- *"Here's their logo and website"* → Auto-extract
- *"Match this screenshot"* → Reverse-engineer from image
- *"Use these colors: #1a1a2e, #16213e, #0f3460"* → Direct color mapping
- *"Make it look like this PDF"* → Extract from document

---

*Reference Version: 1.1 — Per-Client Brand System with Asset Ingestion*
