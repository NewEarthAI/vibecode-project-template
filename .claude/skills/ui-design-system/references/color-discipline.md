# Color Discipline — "Maximum Practical Value Only"

> **The rule**: every non-neutral color in the interface must map to exactly one operational state. If it doesn't earn its place by making information clearer, it is decoration. Decoration is rejected.

---

## The Only Approved Color Categories

There are exactly **four** reasons to use a non-neutral color in a the agency UI:

| Category | Example States | Approved Colors |
|----------|---------------|-----------------|
| **1. Severity** | critical, warning, info | Critical `#B42318` / Warning `#B54708` / Info `#175CD3` |
| **2. Confidence / threshold crossing** | high confidence / medium / low (correlation scoring, data quality grades) | Success `#067647` ≥85% / Warning `#B54708` 45-84% / Critical `#B42318` <45% |
| **3. Variance direction** | positive variance, negative variance, on-target | Success `#067647` positive / Critical `#B42318` negative / Neutral gray on-target |
| **4. Compliance state** | compliant / violation / pending | Success `#067647` / Critical `#B42318` / Warning `#B54708` |

**If your use of color does not fit one of these four categories, it is decoration. Remove it or justify in comments.**

---

## The Semantic Slot Map

| Semantic Slot | When To Use | Token | Backing Bg |
|---------------|-------------|-------|-----------|
| Critical | Severity=critical, destructive action, negative variance, confidence <45%, compliance violation | `--ne-critical` | `--ne-critical-bg` |
| Warning | Severity=medium, caution, confidence 45-84%, compliance pending | `--ne-warning` | `--ne-warning-bg` |
| Success | State=resolved, positive variance, confidence ≥85%, compliant | `--ne-success` | `--ne-success-bg` |
| Info | Neutral action, announcement, non-critical highlight | `--ne-info` | `--ne-info-bg` |
| Brand Primary | Primary CTA, active nav state, tour button, key affordance | `--ne-primary` | — |
| Neutral (default) | Everything else — labels, borders, card backgrounds, body text | `--ne-fg-*`, `--ne-bg-*` | — |

---

## Examples: Approved vs Rejected

### Approved: Severity in an Issue Drawer

```tsx
// ✓ Color carries severity information
const PRIORITY_STYLES = {
  critical: { bg: 'var(--ne-critical-bg)', text: 'var(--ne-critical)', border: 'var(--ne-critical)' },
  high:     { bg: 'var(--ne-warning-bg)',  text: 'var(--ne-warning)',  border: 'var(--ne-warning)' },
  medium:   { bg: 'var(--ne-bg-muted)',    text: 'var(--ne-fg-secondary)', border: 'var(--ne-border-hairline)' },
  low:      { bg: 'var(--ne-bg-muted)',    text: 'var(--ne-fg-tertiary)',  border: 'var(--ne-border-hairline)' },
};
```

**Why approved**: each color maps to a documented severity level. Medium and low intentionally use neutral grays because they are *not* urgent — giving them color would falsely elevate them.

### Approved: Variance Arrows

```tsx
// ✓ Color carries direction of change
function VarianceIndicator({ value }: { value: number }) {
  const direction = value > 0 ? 'positive' : value < 0 ? 'negative' : 'neutral';
  const color = {
    positive: 'var(--ne-success)',
    negative: 'var(--ne-critical)',
    neutral:  'var(--ne-fg-secondary)',
  }[direction];

  return <span style={{ color }}>{value > 0 ? '+' : ''}{value}%</span>;
}
```

### Rejected: Decorative Card Colors

```tsx
// ✗ REJECTED — color is decoration, not information
<div className="grid grid-cols-3 gap-4">
  <Card className="bg-blue-50 border-blue-200">Total Drivers</Card>
  <Card className="bg-green-50 border-green-200">Active Trucks</Card>
  <Card className="bg-purple-50 border-purple-200">Revenue</Card>
</div>
```

**Why rejected**: these are three independent metrics. Blue, green, and purple here mean *nothing* — they are chosen for "visual interest". The audit script flags this.

**Corrected version**:
```tsx
// ✓ All three cards neutral. Color only appears inside the card for variance.
<div className="grid grid-cols-3 gap-4">
  <Card className="bg-[var(--ne-bg-base)] border-[var(--ne-border-hairline)]">
    <Label>Total Drivers</Label>
    <Value>59</Value>
    <VarianceIndicator value={2} /> {/* +2% in success green — earned */}
  </Card>
  <Card className="bg-[var(--ne-bg-base)] border-[var(--ne-border-hairline)]">
    <Label>Active Trucks</Label>
    <Value>47</Value>
  </Card>
  <Card className="bg-[var(--ne-bg-base)] border-[var(--ne-border-hairline)]">
    <Label>Revenue</Label>
    <Value>R1 151 700</Value>
    <VarianceIndicator value={-8} /> {/* -8% in critical red — earned */}
  </Card>
</div>
```

### Rejected: Pastel Status Pills with Decorative Icons

```tsx
// ✗ REJECTED — pastel + emoji + decorative
<Badge className="bg-pink-100 text-pink-800">🎉 New</Badge>
<Badge className="bg-yellow-100 text-yellow-800">⚠️ Pending</Badge>
<Badge className="bg-green-100 text-green-800">✅ Done</Badge>
```

**Why rejected**:
1. Pastel backgrounds (`bg-pink-100`, `bg-yellow-100`) read as cute, not premium
2. Emojis in UI copy are banned
3. Colors are decorative — none map to an operational state ("new" is not a severity)

**Corrected version**:
```tsx
// ✓ Text-first, neutral for non-state, semantic color only where earned
<Badge variant="neutral">New</Badge>
<Badge variant="warning">Pending</Badge>
<Badge variant="neutral">Done</Badge>  // "done" is a normal state, not a success event
```

---

## The "Is This Color Earned?" Test

Before adding any color to a component, answer these questions:

```
1. Does this color map to exactly one documented operational state?
   → If no: DECORATION. Remove.

2. Would the information be equally clear in grayscale?
   → If yes: DECORATION. Use grayscale.

3. Is the color redundant with another signal (icon, label, position)?
   → If yes: OK if color reinforces, REMOVE if only decorative.

4. Is this color accessible (WCAG AA) against its background?
   → If no: use the backing --ne-*-bg token for the background pair.

5. Would a colorblind user lose information?
   → If yes: color must be paired with a non-color signal (icon or label).
```

**If you cannot defend the color with these five questions, the audit fails.**

---

## Backgrounds: The Hard Rule

**Card backgrounds are never colored.** They are always one of:

| Context | Background Token |
|---------|------------------|
| Default card | `--ne-bg-base` (`#FBFBFA`) |
| Subtle / section header | `--ne-bg-subtle` (`#F7F6F3`) |
| Muted / disabled | `--ne-bg-muted` (`#E8E7E3`) |

**Colored backgrounds are ONLY allowed on**:
- Badge internals (`--ne-critical-bg` etc.) — and even then only when the state warrants it
- Inline alert banners (one per page maximum)
- Never on Card components

The moment you see a PR that adds `bg-red-50` or `bg-blue-100` to a `Card`, reject it.

---

## Color Intensity Hierarchy

When a semantic color IS justified, use the appropriate intensity for the signal strength:

| Intensity | Use | Example |
|-----------|-----|---------|
| **Text only** (`--ne-critical` on neutral bg) | Subtle state hint — text changes color, background stays neutral | Variance `-8%` in critical red on a neutral card |
| **Backed text** (`--ne-critical` text on `--ne-critical-bg` background) | State-badge — small pill announcing a state | "3 critical" badge |
| **Full banner** (white text on `--ne-critical` background) | Page-level alert — demands attention immediately | "System outage affecting 12 fleets" banner |

**Never mix intensities in the same row** (e.g., one critical badge full-color + another critical badge text-only). Pick a consistent intensity per context.

---

## The "Three Colors Max" Guideline

Any single viewport should contain **at most 3 non-neutral colors** visible at once:

1. The brand primary (buttons, active nav) — 1 color
2. The most severe semantic state visible (critical OR warning OR success) — 1 color
3. An occasional secondary semantic (if a second state is also visible) — 1 color

**If your screen has 5+ colors visible, it is failing.** Audit the UI and ask which colors are actually carrying information vs. decorating. Usually 2 of them need to become neutral.

---

## Audit Enforcement

The `scripts/audit-colors.sh` script flags:

```bash
# Fails on any use of bg-{red,green,amber,blue,purple,pink,yellow,orange}-* on a Card component
# Fails on any use of text-{red,green,...}-* on an element without a nearby state keyword
# Fails on any hex color that isn't in the locked token list (with exception: client-specific primary)
# Fails on bg-white/X translucency patterns
```

Run it on every PR. A failure means the author must either:
1. Justify the color in a code comment with the semantic state it represents, AND
2. Use the locked semantic tokens (not Tailwind defaults)

---

## Anti-Patterns Summary

| Wrong | Why | Right |
|-------|-----|-------|
| Random pastel card backgrounds | Decoration | Neutral cards, color inside for state |
| Purple gradients | SaaS cliche | Neutral + single semantic |
| Rainbow charts | Too many colors | Grayscale base + 1-2 highlight colors |
| Every badge colored | Color inflation | Most badges neutral, color only for state |
| Colored shadows (`shadow-cyan-500/50`) | Glow = consumer, not premium | Pure grayscale shadows |
| `bg-red-500` on a decorative card | Unsemantic | Neutral card + red text only where state applies |
| Pastel backgrounds (`bg-pink-100`, `bg-blue-100`) | Cute, not premium | Use `--ne-*-bg` tokens (tuned neutrals) |
| `text-red-500` without a state | Decoration | Only use when severity=critical or variance=negative |

---

*The discipline is the product. Other dashboards throw color at problems. Ours solves them with hierarchy and restraint.*
