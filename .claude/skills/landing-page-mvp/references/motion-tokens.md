# Motion Tokens — Preset-Coupled Choreography

> Each preset defines a complete motion vocabulary. Motion MUST match aesthetic personality.
> Never mix motion from different presets unless building a deliberate custom composite.

## Token Structure

Every preset defines 6 motion categories:
- **entrance**: How elements first appear (hero, sections, cards)
- **hover**: Interactive feedback on pointer interaction
- **scroll**: ScrollTrigger scrub behavior for scroll-linked animations
- **parallax**: Background/foreground depth separation
- **text**: Typography animation (word/char splits, reveals)
- **exit**: How elements leave viewport or transition out

## Preset Motion Map

### A — "Organic Tech" (Heavy + Liquid)
```
entrance:  ease "power4.out", duration 1.4s, stagger 0.2s
hover:     ease "back.out(1.7)", duration 0.4s, scale 1.02
scroll:    ease "sine.inOut", scrub 1.5
parallax:  speed -0.3, ease "none"
text:      ease "expo.inOut", duration 0.8s, splitBy "words"
exit:      ease "power3.in", duration 0.6s, y -20, opacity 0
```
**Feel**: Weighted, fluid. Elements have mass and settle into place.

### B — "Midnight Luxe" (Luxury Reveal)
```
entrance:  ease "expo.inOut", duration 1.6s, stagger { amount: 0.8 }
hover:     ease "sine.out", duration 0.5s, scale 1.01, opacity shift
scroll:    ease "sine.inOut", scrub 2.0
parallax:  speed -0.2, ease "none"
text:      ease "expo.inOut", duration 1.0s, splitBy "words", stagger 0.05
exit:      ease "expo.in", duration 0.8s, y -30, opacity 0
```
**Feel**: Slow, dramatic unveiling. Every element earns its place.

### C — "Brutalist Signal" (Magnetic + Snappy)
```
entrance:  ease "back.out(1.7)", duration 0.5s, stagger 0.08s
hover:     ease "elastic.out(1, 0.3)", duration 0.4s, scale 1.03
scroll:    ease "power2.out", scrub 0.6
parallax:  speed -0.5, ease "none"
text:      ease "power3.out", duration 0.4s, splitBy "chars"
exit:      ease "power3.in", duration 0.3s, x -40, opacity 0
```
**Feel**: Punchy, immediate. Snap-in with overshoot, raw energy.

### D — "Vapor Clinic" (Liquid + Ethereal)
```
entrance:  ease "sine.inOut", duration 1.2s, stagger 0.18s
hover:     ease "circ.inOut", duration 0.6s, scale 1.015, blur shift
scroll:    ease "sine.inOut", scrub 2.5
parallax:  speed -0.15, ease "none"
text:      ease "sine.inOut", duration 1.0s, splitBy "words"
exit:      ease "sine.in", duration 1.0s, y -15, opacity 0
```
**Feel**: Dreamlike, floating. Elements drift rather than snap.

### E — "Warm Harbor" (Warm + Organic)
```
entrance:  ease "expo.out", duration 1.2s, stagger 0.3s
hover:     ease "sine.out", duration 0.5s, scale 1.01
scroll:    ease "sine.inOut", scrub 2.0
parallax:  speed -0.15, ease "none"
text:      ease "expo.out", duration 1.0s, splitBy "words"
exit:      ease "sine.in", duration 0.8s, y -10, opacity 0
```
**Feel**: Gentle, unhurried. Like a warm hand guiding you through.

### F — "Clinical Precision" (Crisp + Exact)
```
entrance:  ease "power2.out", duration 0.4s, stagger 0.06s
hover:     ease "power2.out", duration 0.25s, scale 1.005
scroll:    ease "power2.out", scrub 0.4
parallax:  speed -0.1, ease "none"
text:      ease "power2.out", duration 0.35s, splitBy "words"
exit:      ease "power2.in", duration 0.3s, y -10, opacity 0
```
**Feel**: Fast, precise, no wasted frames. Surgical timing.

### G — "Playful Kinetic" (Bouncy + Energetic)
```
entrance:  ease "elastic.out(1, 0.5)", duration 0.9s, stagger 0.1s
hover:     ease "back.out(2.5)", duration 0.3s, scale 1.05, rotate 2
scroll:    ease "power2.out", scrub 0.8
parallax:  speed -0.4, ease "none"
text:      ease "back.out(1.7)", duration 0.6s, splitBy "chars"
exit:      ease "power2.in", duration 0.4s, y 30, opacity 0
```
**Feel**: Springy, exuberant. Elements bounce into place with personality.

### H — "Editorial Noir" (Dramatic + Typography-Driven)
```
entrance:  ease "expo.inOut", duration 1.0s, stagger 0.12s
hover:     ease "power3.out", duration 0.35s, letterSpacing shift
scroll:    ease "expo.inOut", scrub 1.2
parallax:  speed -0.25, ease "none"
text:      ease "expo.inOut", duration 0.8s, splitBy "chars", stagger 0.02
exit:      ease "expo.in", duration 0.6s, y -20, opacity 0
```
**Feel**: Magazine editorial. Typography IS the animation.

## Custom Composite Motion

When user provides a custom brief instead of selecting a preset, compose motion by:
1. Identify the closest 2 presets to the described feel
2. Take entrance/scroll from the dominant preset
3. Take hover/text from the secondary preset
4. Adjust durations to match described energy level (fast/slow/medium)
5. Document the composition in a code comment at the top of the animation file

## GSAP Implementation Notes

- All easings use GSAP 3 syntax (string format)
- `stagger` values can be numbers OR objects (`{ amount: 0.8, from: "center" }`)
- `splitBy "chars"` requires SplitText (GSAP Club plugin) — fall back to word-level animation with free tier
- Duration ranges are starting points; adjust +-20% based on content density
