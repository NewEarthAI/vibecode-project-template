# Typography Pairings — Per Preset

> Font selections that reinforce each preset's personality.
> All fonts are Google Fonts (free, self-hostable via `@fontsource`).

## Pairing Structure

Each preset specifies:
- **Display**: Hero headings, large statements (weight 600-900)
- **Body**: Paragraphs, descriptions (weight 300-500)
- **Mono** (optional): Code, data, technical details

## Preset Typography

### A — "Organic Tech"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Space Grotesk | 700 | Geometric but warm, tech-organic bridge |
| Body | Inter | 400 | Clean readability, pairs with geometric display |
| Mono | JetBrains Mono | 400 | For data/metrics display |

### B — "Midnight Luxe"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Playfair Display | 800 | High-contrast serifs, luxury editorial feel |
| Body | Source Sans 3 | 300 | Thin, elegant, recedes behind display |
| Mono | — | — | Not typical for luxury aesthetic |

### C — "Brutalist Signal"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Bebas Neue | 400 | All-caps, condensed, raw power |
| Body | IBM Plex Mono | 400 | Monospace body = brutalist commitment |
| Mono | IBM Plex Mono | 400 | Same — monospace IS the body |

### D — "Vapor Clinic"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Syne | 700 | Futuristic, wide, ethereal geometry |
| Body | DM Sans | 400 | Soft, rounded, clinical clarity |
| Mono | Space Mono | 400 | For technical/clinical data |

### E — "Warm Harbor"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Fraunces | 700 | Soft serif with optical size axis, warm and approachable |
| Body | Nunito | 400 | Rounded terminals, friendly and readable |
| Mono | — | — | Not typical for warm aesthetic |

### F — "Clinical Precision"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Plus Jakarta Sans | 700 | Geometric, crisp, modern medical feel |
| Body | Plus Jakarta Sans | 400 | Same family, weight contrast = clean hierarchy |
| Mono | Fira Code | 400 | For data, metrics, clinical results |

### G — "Playful Kinetic"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Outfit | 800 | Geometric with personality, scales well for play |
| Body | Quicksand | 500 | Rounded, bouncy, matches kinetic energy |
| Mono | — | — | Not typical for playful aesthetic |

### H — "Editorial Noir"
| Role | Font | Weight | Why |
|------|------|--------|-----|
| Display | Instrument Serif | 400 | Refined italic serif, magazine editorial DNA |
| Body | Instrument Sans | 400 | Same family, sans-serif body for contrast |
| Mono | — | — | Not typical for editorial aesthetic |

## Implementation

```html
<!-- Google Fonts import (adjust per preset) -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DISPLAY_FONT:wght@WEIGHT&family=BODY_FONT:wght@WEIGHT&display=swap" rel="stylesheet">
```

```css
/* Tailwind config extension */
fontFamily: {
  display: ['DISPLAY_FONT', 'sans-serif'],
  body: ['BODY_FONT', 'sans-serif'],
  mono: ['MONO_FONT', 'monospace'],
}
```

## Custom Brief Font Selection

When user provides a custom aesthetic description:
1. Identify the emotional register (warm/cool, playful/serious, modern/classic)
2. Select display font from the closest preset
3. Select body font that creates intentional contrast
4. Never use the same font for both display and body (exception: Preset F)
