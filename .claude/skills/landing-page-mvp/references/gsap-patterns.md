# GSAP Performance Patterns & Safety Rules

> Mandatory directives for all GSAP animations in landing-page-mvp projects.
> Read this before writing ANY animation code.

## Mandatory Defaults

```javascript
// SET ONCE in App.jsx or main entry point
gsap.defaults({ force3D: true, overwrite: "auto" });
```

**Why**: `force3D: true` forces GPU-accelerated transforms (translateZ(0)) preventing jank.
`overwrite: "auto"` prevents animation conflicts when ScrollTrigger fires rapidly.

## React 19 Integration

### MANDATORY: useGSAP() Hook

```jsx
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

gsap.registerPlugin(ScrollTrigger);

function Section({ children }) {
  const container = useRef(null);

  useGSAP(() => {
    gsap.from(".animate-in", {
      y: 60,
      opacity: 0,
      duration: 1.2,
      ease: "expo.out",
      stagger: 0.2,
      scrollTrigger: {
        trigger: container.current,
        start: "top 80%",
        toggleActions: "play none none reverse"
      }
    });
  }, { scope: container });

  return <section ref={container}>{children}</section>;
}
```

### NEVER: Raw useEffect with GSAP

```jsx
// WRONG — breaks in React 19 StrictMode (double-render, no cleanup)
useEffect(() => {
  gsap.to(".box", { x: 100 });
}, []);
```

**Why**: React 19 StrictMode double-invokes effects. Without useGSAP cleanup,
animations stack and ScrollTrigger instances leak.

## Responsive Animation Cleanup

```javascript
// MANDATORY for any parallax or desktop-only animations
useGSAP(() => {
  const mm = gsap.matchMedia();

  mm.add("(min-width: 769px)", () => {
    // Desktop: full parallax, horizontal scroll
    gsap.to(".parallax-bg", {
      yPercent: -30,
      ease: "none",
      scrollTrigger: { trigger: ".hero", scrub: true }
    });
  });

  mm.add("(max-width: 768px)", () => {
    // Mobile: simplified animations, no parallax
    gsap.from(".hero-text", {
      y: 30,
      opacity: 0,
      duration: 0.8,
      ease: "power2.out"
    });
  });
}, { scope: container });
```

**Why**: Desktop parallax on mobile causes scroll jank and layout thrashing.

## ScrollTrigger Refresh After Async Loads

```javascript
// MANDATORY when using picsum.photos or any lazy-loaded images
useGSAP(() => {
  // Set up animations...

  // Refresh after all images load
  const images = document.querySelectorAll("img");
  let loaded = 0;
  images.forEach(img => {
    if (img.complete) {
      loaded++;
    } else {
      img.addEventListener("load", () => {
        loaded++;
        if (loaded === images.length) ScrollTrigger.refresh();
      });
    }
  });
  if (loaded === images.length) ScrollTrigger.refresh();
}, { scope: container });
```

**Why**: picsum.photos images load asynchronously. Without refresh,
ScrollTrigger calculates positions from pre-image layout — all scroll
triggers fire at wrong positions.

## Lazy Animation Initialization

```javascript
// RECOMMENDED for below-fold sections (3+ sections)
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      initSectionAnimation(entry.target);
      observer.unobserve(entry.target);
    }
  });
}, { rootMargin: "200px" });

document.querySelectorAll("[data-animate]").forEach(el => observer.observe(el));
```

**Why**: Initializing all animations on mount wastes CPU for sections
the user may never scroll to.

## Tree-Shakeable Imports

```javascript
// CORRECT — only imports what you use
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

// WRONG — imports entire GSAP bundle
import "gsap/all";
```

## GSAP Licensing

| Plugin | License | Available |
|--------|---------|-----------|
| ScrollTrigger | Free | Yes — always use |
| Observer | Free | Yes |
| Draggable | Free | Yes |
| SplitText | Club GreenSock | Paid — do NOT use without confirming license |
| MorphSVG | Club GreenSock | Paid — do NOT use without confirming license |
| DrawSVG | Club GreenSock | Paid — do NOT use without confirming license |
| ScrollSmoother | Club GreenSock | Paid — do NOT use without confirming license |

**Free-tier text animation alternative**: Wrap words in `<span>` elements manually
and animate with stagger. Works for word-level; character-level needs SplitText or manual splitting.

### Word-Wrap Pattern (SplitText Free Alternative)

```jsx
{/* In JSX — wrap each word in a span for GSAP word-level animation */}
<h1 data-hero-heading className="font-display text-6xl font-bold">
  <span className="word inline-block">Bread</span>{" "}
  <span className="word inline-block">That</span>{" "}
  <span className="word inline-block">Remembers</span>
</h1>

{/* In GSAP — animate the .word spans with stagger */}
gsap.from("[data-hero-heading] .word", {
  y: 60,
  opacity: 0,
  duration: 1.2,
  ease: "expo.out",
  stagger: 0.3, // Per-word delay
});
```

**Why `inline-block`**: GSAP transform animations need block-level rendering.
`inline-block` preserves text flow while allowing `y` transforms.
Without it, `translateY` has no visible effect on inline `<span>` elements.

## Performance Checklist

Before shipping, verify:
- [ ] `gsap.defaults({ force3D: true })` is set
- [ ] All animations use `useGSAP()`, never raw `useEffect`
- [ ] `gsap.matchMedia()` handles mobile breakpoint
- [ ] `ScrollTrigger.refresh()` fires after image loads
- [ ] No GSAP Club plugins used without license
- [ ] Bundle check: gsap + ScrollTrigger ~23KB gzipped
- [ ] No `console.log` in animation callbacks
