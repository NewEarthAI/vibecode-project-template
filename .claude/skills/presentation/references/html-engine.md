# HTML Presentation Engine — Single-File Broadcast Quality

> Complete reference for generating self-contained HTML presentations. Everything embedded —
> CSS, JavaScript, images as base64. Zero external dependencies. Works offline, via email,
> on any web server.

---

## Architecture: Single-File Pattern

```
┌──────────────────────────────────────────┐
│ <!DOCTYPE html>                          │
│ <html>                                   │
│ <head>                                   │
│   <style>   ← ALL CSS embedded          │
│   </style>                               │
│ </head>                                  │
│ <body>                                   │
│   <nav>     ← Chapter sidebar            │
│   <main>    ← Slide content              │
│   <footer>  ← Slide counter              │
│   <script>  ← ALL JS embedded           │
│   </script>                              │
│ </body>                                  │
│ </html>                                  │
└──────────────────────────────────────────┘
```

**Rule**: No `<link>`, no `<script src="">`, no external fonts via CDN.
Fonts: Use system font stacks. If brand requires custom fonts, embed as base64 `@font-face`.

---

## Core HTML Structure

```html
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{presentation_title}}</title>
  <style>
    /* === RESET & BASE === */
    /* === THEME VARIABLES === */
    /* === LAYOUT === */
    /* === SLIDE TYPES === */
    /* === NAVIGATION === */
    /* === ANIMATIONS === */
    /* === PRINT === */
  </style>
</head>
<body>
  <!-- Chapter Sidebar -->
  <nav id="sidebar" class="sidebar">
    <div class="sidebar-toggle" onclick="toggleSidebar()">☰</div>
    <div class="sidebar-content">
      <h3>{{presentation_title}}</h3>
      <ul id="chapter-list">
        <!-- Auto-populated by JS -->
      </ul>
    </div>
  </nav>

  <!-- Slide Container -->
  <main id="slides-container">
    <section class="slide active" data-chapter="{{chapter_name}}">
      <!-- Slide content -->
    </section>
    <!-- More slides -->
  </main>

  <!-- Slide Counter -->
  <div id="slide-counter" class="slide-counter">1 / N</div>

  <!-- Progress Bar -->
  <div id="progress-bar" class="progress-bar"></div>

  <script>
    /* === NAVIGATION === */
    /* === SIDEBAR === */
    /* === KEYBOARD === */
    /* === FULLSCREEN === */
    /* === TOUCH === */
  </script>
</body>
</html>
```

---

## CSS Architecture

### Theme Variables (Dark Mode Default)

```css
:root {
  /* Dark theme (default) */
  --bg-primary: #0F172A;
  --bg-secondary: #1E293B;
  --bg-card: #334155;
  --text-primary: #F8FAFC;
  --text-secondary: #CBD5E1;
  --text-muted: #64748B;
  --accent: #3B82F6;
  --accent-hover: #60A5FA;
  --accent-2: #10B981;
  --danger: #EF4444;
  --warning: #F59E0B;
  --success: #22C55E;
  --border: #475569;
  --shadow: rgba(0, 0, 0, 0.3);

  /* Typography */
  --font-heading: 'Inter', -apple-system, 'Segoe UI', sans-serif;
  --font-body: 'Inter', -apple-system, 'Segoe UI', sans-serif;
  --font-mono: 'JetBrains Mono', 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;

  /* Spacing */
  --slide-padding: 8vmin;
  --gap: 2vmin;

  /* Transitions */
  --transition-speed: 400ms;
  --transition-ease: cubic-bezier(0.25, 0.46, 0.45, 0.94);
}

[data-theme="light"] {
  --bg-primary: #FFFFFF;
  --bg-secondary: #F8FAFC;
  --bg-card: #F1F5F9;
  --text-primary: #0F172A;
  --text-secondary: #475569;
  --text-muted: #94A3B8;
  --border: #E2E8F0;
  --shadow: rgba(0, 0, 0, 0.1);
}
```

### Layout System

```css
* { margin: 0; padding: 0; box-sizing: border-box; }

body {
  font-family: var(--font-body);
  background: var(--bg-primary);
  color: var(--text-primary);
  overflow: hidden;
  height: 100vh;
  width: 100vw;
}

.slide {
  position: absolute;
  top: 0; left: 0;
  width: 100vw;
  height: 100vh;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: var(--slide-padding);
  opacity: 0;
  transform: translateX(100%);
  transition: opacity var(--transition-speed) var(--transition-ease),
              transform var(--transition-speed) var(--transition-ease);
  pointer-events: none;
}

.slide.active {
  opacity: 1;
  transform: translateX(0);
  pointer-events: auto;
}

.slide.prev {
  opacity: 0;
  transform: translateX(-100%);
}
```

### Slide Type Styles

```css
/* Title/Hook Slide */
.slide--title {
  text-align: center;
  justify-content: center;
  align-items: center;
}
.slide--title h1 {
  font-size: clamp(2.5rem, 6vw, 5rem);
  font-weight: 800;
  line-height: 1.1;
  margin-bottom: 1rem;
}
.slide--title .subtitle {
  font-size: clamp(1rem, 2vw, 1.5rem);
  color: var(--text-secondary);
}

/* Bold Claim Slide */
.slide--claim {
  text-align: center;
  justify-content: center;
}
.slide--claim .stat {
  font-size: clamp(4rem, 12vw, 10rem);
  font-weight: 900;
  color: var(--accent);
  line-height: 1;
}
.slide--claim .context {
  font-size: clamp(1rem, 2.5vw, 1.8rem);
  color: var(--text-secondary);
  margin-top: 2rem;
}

/* Content Slide */
.slide--content h2 {
  font-size: clamp(1.8rem, 3.5vw, 3rem);
  font-weight: 700;
  margin-bottom: 3vmin;
  color: var(--accent);
}
.slide--content ul {
  list-style: none;
  font-size: clamp(1rem, 2vw, 1.4rem);
  line-height: 1.8;
}
.slide--content li::before {
  content: '→';
  color: var(--accent);
  margin-right: 1rem;
  font-weight: bold;
}

/* Split/Comparison Slide */
.slide--split {
  flex-direction: row;
  gap: 4vmin;
}
.slide--split .column {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.slide--split .divider {
  width: 2px;
  background: var(--border);
  align-self: stretch;
}

/* Data Slide */
.slide--data table {
  width: 100%;
  border-collapse: collapse;
  font-size: clamp(0.8rem, 1.5vw, 1.1rem);
}
.slide--data th {
  background: var(--accent);
  color: white;
  padding: 1vmin 2vmin;
  text-align: left;
  font-weight: 600;
}
.slide--data td {
  padding: 1vmin 2vmin;
  border-bottom: 1px solid var(--border);
}
.slide--data tr:nth-child(even) {
  background: var(--bg-secondary);
}

/* Timeline Slide */
.slide--timeline .timeline {
  display: flex;
  align-items: flex-start;
  gap: 2vmin;
  position: relative;
  padding-top: 4vmin;
}
.slide--timeline .timeline::before {
  content: '';
  position: absolute;
  top: 0;
  left: 5%;
  right: 5%;
  height: 3px;
  background: var(--accent);
}
.slide--timeline .milestone {
  flex: 1;
  text-align: center;
  position: relative;
}
.slide--timeline .milestone::before {
  content: '';
  width: 14px;
  height: 14px;
  background: var(--accent);
  border-radius: 50%;
  display: block;
  margin: -10px auto 1rem;
}

/* CTA Slide */
.slide--cta {
  text-align: center;
  justify-content: center;
  align-items: center;
}
.slide--cta h2 {
  font-size: clamp(2rem, 4vw, 3.5rem);
  margin-bottom: 2rem;
}
.slide--cta .cta-button {
  display: inline-block;
  padding: 1rem 3rem;
  background: var(--accent);
  color: white;
  border-radius: 8px;
  font-size: 1.2rem;
  font-weight: 600;
  text-decoration: none;
}
```

### Navigation Components

```css
/* Sidebar */
.sidebar {
  position: fixed;
  left: 0;
  top: 0;
  width: 300px;
  height: 100vh;
  background: var(--bg-secondary);
  border-right: 1px solid var(--border);
  transform: translateX(-300px);
  transition: transform 300ms ease;
  z-index: 1000;
  overflow-y: auto;
}
.sidebar.open { transform: translateX(0); }
.sidebar-toggle {
  position: fixed;
  top: 1rem;
  left: 1rem;
  cursor: pointer;
  font-size: 1.5rem;
  z-index: 1001;
  color: var(--text-muted);
  opacity: 0.6;
  transition: opacity 200ms;
}
.sidebar-toggle:hover { opacity: 1; }
.sidebar-content { padding: 4rem 1.5rem 2rem; }
.sidebar-content h3 {
  font-size: 0.9rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--text-muted);
  margin-bottom: 1.5rem;
}
.sidebar-content li {
  list-style: none;
  padding: 0.5rem 0;
  cursor: pointer;
  color: var(--text-secondary);
  transition: color 200ms;
  font-size: 0.9rem;
}
.sidebar-content li:hover,
.sidebar-content li.active { color: var(--accent); }

/* Slide Counter */
.slide-counter {
  position: fixed;
  top: 1rem;
  right: 1.5rem;
  font-family: var(--font-mono);
  font-size: 0.85rem;
  color: var(--text-muted);
  z-index: 100;
}

/* Progress Bar */
.progress-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  height: 3px;
  background: var(--accent);
  transition: width 300ms ease;
  z-index: 100;
}
```

### Animation System

```css
/* Slide transition variants */
.slide-enter { animation: slideEnter var(--transition-speed) var(--transition-ease); }
.slide-exit { animation: slideExit var(--transition-speed) var(--transition-ease); }

@keyframes slideEnter {
  from { opacity: 0; transform: translateX(60px); }
  to { opacity: 1; transform: translateX(0); }
}
@keyframes slideExit {
  from { opacity: 1; transform: translateX(0); }
  to { opacity: 0; transform: translateX(-60px); }
}

/* Element animations (staggered on slide enter) */
.slide.active .animate-in {
  animation: fadeSlideUp 500ms var(--transition-ease) both;
}
.slide.active .animate-in:nth-child(1) { animation-delay: 100ms; }
.slide.active .animate-in:nth-child(2) { animation-delay: 200ms; }
.slide.active .animate-in:nth-child(3) { animation-delay: 300ms; }
.slide.active .animate-in:nth-child(4) { animation-delay: 400ms; }
.slide.active .animate-in:nth-child(5) { animation-delay: 500ms; }

@keyframes fadeSlideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### Print Styles

```css
@media print {
  .sidebar, .sidebar-toggle, .slide-counter, .progress-bar { display: none; }
  .slide {
    position: relative;
    opacity: 1;
    transform: none;
    page-break-after: always;
    height: auto;
    min-height: 100vh;
    pointer-events: auto;
  }
  body { overflow: visible; }
}
```

---

## JavaScript Engine

```javascript
(function() {
  'use strict';

  // === STATE ===
  let currentSlide = 0;
  const slides = document.querySelectorAll('.slide');
  const totalSlides = slides.length;
  const counter = document.getElementById('slide-counter');
  const progressBar = document.getElementById('progress-bar');
  const sidebar = document.getElementById('sidebar');
  const chapterList = document.getElementById('chapter-list');

  // === INITIALIZATION ===
  function init() {
    buildChapterNav();
    updateUI();
    document.addEventListener('keydown', handleKeyboard);
    addTouchSupport();
  }

  // === NAVIGATION ===
  function goToSlide(index) {
    if (index < 0 || index >= totalSlides) return;
    slides[currentSlide].classList.remove('active');
    slides[currentSlide].classList.add('prev');
    currentSlide = index;
    slides.forEach((s, i) => {
      s.classList.remove('active', 'prev');
      if (i === currentSlide) s.classList.add('active');
      else if (i < currentSlide) s.classList.add('prev');
    });
    updateUI();
  }

  function nextSlide() { goToSlide(currentSlide + 1); }
  function prevSlide() { goToSlide(currentSlide - 1); }

  // === KEYBOARD ===
  function handleKeyboard(e) {
    switch(e.key) {
      case 'ArrowRight': case 'ArrowDown': case ' ':
        e.preventDefault(); nextSlide(); break;
      case 'ArrowLeft': case 'ArrowUp':
        e.preventDefault(); prevSlide(); break;
      case 'Home': e.preventDefault(); goToSlide(0); break;
      case 'End': e.preventDefault(); goToSlide(totalSlides - 1); break;
      case 'f': case 'F':
        e.preventDefault(); toggleFullscreen(); break;
      case 'Escape':
        if (sidebar.classList.contains('open')) {
          e.preventDefault(); toggleSidebar();
        }
        break;
      case 't': case 'T':
        e.preventDefault(); toggleTheme(); break;
    }
  }

  // === TOUCH SUPPORT ===
  function addTouchSupport() {
    let startX = 0;
    let startY = 0;
    document.addEventListener('touchstart', (e) => {
      startX = e.touches[0].clientX;
      startY = e.touches[0].clientY;
    }, { passive: true });
    document.addEventListener('touchend', (e) => {
      const dx = e.changedTouches[0].clientX - startX;
      const dy = e.changedTouches[0].clientY - startY;
      if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 50) {
        dx > 0 ? prevSlide() : nextSlide();
      }
    }, { passive: true });
  }

  // === SIDEBAR ===
  function buildChapterNav() {
    const chapters = new Map();
    slides.forEach((slide, i) => {
      const chapter = slide.dataset.chapter;
      if (chapter && !chapters.has(chapter)) {
        chapters.set(chapter, i);
      }
    });
    chapters.forEach((slideIndex, name) => {
      const li = document.createElement('li');
      li.textContent = name;
      li.onclick = () => { goToSlide(slideIndex); toggleSidebar(); };
      chapterList.appendChild(li);
    });
  }

  // === UI UPDATES ===
  function updateUI() {
    counter.textContent = `${currentSlide + 1} / ${totalSlides}`;
    progressBar.style.width = `${((currentSlide + 1) / totalSlides) * 100}%`;

    // Update sidebar active chapter
    const currentChapter = slides[currentSlide].dataset.chapter;
    chapterList.querySelectorAll('li').forEach(li => {
      li.classList.toggle('active', li.textContent === currentChapter);
    });
  }

  // === FULLSCREEN ===
  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen();
    }
  }

  // === THEME TOGGLE ===
  function toggleTheme() {
    const html = document.documentElement;
    const current = html.dataset.theme;
    html.dataset.theme = current === 'dark' ? 'light' : 'dark';
  }

  // === EXPOSE GLOBALS ===
  window.toggleSidebar = function() { sidebar.classList.toggle('open'); };
  window.toggleTheme = toggleTheme;

  // === BOOT ===
  init();
})();
```

---

## Image Embedding

### Base64 Encoding

For logos and small images (< 500KB), embed as base64:
```html
<img src="data:image/png;base64,iVBORw0KGgo..." alt="Logo" class="logo" />
```

### SVG Inline

For diagrams and icons, embed SVG directly:
```html
<svg viewBox="0 0 100 100" class="icon">
  <circle cx="50" cy="50" r="40" fill="var(--accent)" />
</svg>
```

### CSS-Only Fallbacks

When brand assets aren't available, create CSS text logos:
```css
.brand-mark {
  font-family: var(--font-heading);
  font-weight: 900;
  font-size: 1.2rem;
  letter-spacing: 0.05em;
  color: var(--accent);
  text-transform: uppercase;
}
```

---

## Chart Generation (CSS-Only)

### Bar Chart
```html
<div class="chart-bar">
  <div class="bar" style="--value: 85%;" data-label="Q1">
    <span class="bar-value">85%</span>
  </div>
  <div class="bar" style="--value: 62%;" data-label="Q2">
    <span class="bar-value">62%</span>
  </div>
</div>
```

```css
.chart-bar {
  display: flex;
  align-items: flex-end;
  gap: 2vmin;
  height: 40vmin;
  padding: 2vmin 0;
}
.bar {
  flex: 1;
  height: var(--value);
  background: linear-gradient(to top, var(--accent), var(--accent-hover));
  border-radius: 4px 4px 0 0;
  position: relative;
  transition: height 800ms var(--transition-ease);
}
.bar::after {
  content: attr(data-label);
  position: absolute;
  bottom: -2rem;
  left: 50%;
  transform: translateX(-50%);
  color: var(--text-muted);
  font-size: 0.9rem;
}
.bar-value {
  position: absolute;
  top: -1.5rem;
  left: 50%;
  transform: translateX(-50%);
  font-weight: 700;
  font-size: 0.9rem;
}
```

### Radar Chart (for AI Maturity Audits)

Use SVG polygon for radar/spider charts — ideal for 6-domain maturity scoring:
```html
<svg viewBox="0 0 400 400" class="radar-chart">
  <!-- Grid circles -->
  <circle cx="200" cy="200" r="150" fill="none" stroke="var(--border)" stroke-opacity="0.3"/>
  <circle cx="200" cy="200" r="100" fill="none" stroke="var(--border)" stroke-opacity="0.2"/>
  <circle cx="200" cy="200" r="50" fill="none" stroke="var(--border)" stroke-opacity="0.1"/>
  <!-- Data polygon -->
  <polygon points="{{computed_points}}"
    fill="var(--accent)" fill-opacity="0.2"
    stroke="var(--accent)" stroke-width="2"/>
  <!-- Axis labels positioned around perimeter -->
</svg>
```

### Donut/Gauge Chart
```html
<svg viewBox="0 0 120 120" class="gauge">
  <circle cx="60" cy="60" r="50" fill="none" stroke="var(--border)" stroke-width="10" opacity="0.2"/>
  <circle cx="60" cy="60" r="50" fill="none" stroke="var(--accent)" stroke-width="10"
    stroke-dasharray="{{value * 3.14}} 314" transform="rotate(-90 60 60)"/>
  <text x="60" y="65" text-anchor="middle" fill="var(--text-primary)"
    font-size="20" font-weight="700">{{value}}%</text>
</svg>
```

---

## Deployment

### Local
Simply open the `.html` file in any browser. No server needed.

### GitHub Pages
1. Place `index.html` at repo root
2. Enable GitHub Pages in repo settings
3. Access at `https://{user}.github.io/{repo}/`

### Quick Share
The HTML file can be emailed directly — it's fully self-contained.

---

## Keyboard Reference (Shown to User)

| Key | Action |
|-----|--------|
| `→` / `↓` / `Space` | Next slide |
| `←` / `↑` | Previous slide |
| `Home` | First slide |
| `End` | Last slide |
| `F` | Toggle fullscreen |
| `T` | Toggle dark/light theme |
| `Esc` | Close sidebar |

---

*Reference Version: 1.0 — Single-File HTML Broadcast Engine*
