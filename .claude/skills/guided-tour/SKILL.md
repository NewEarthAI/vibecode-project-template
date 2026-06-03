---
name: guided-tour
description: |
  Scaffold a complete three-layer contextual guidance system for React/Vite/Tailwind dashboards.
  Use when: building onboarding tours, adding guided walkthroughs, creating page-level help,
  implementing info tooltips, or when the user says "add a tour", "guided tour", "walkthrough",
  "onboarding", "help tooltips", "page guide", or "SOP system". Covers the full stack:
  driver.js tour infrastructure (registry, hooks, menu, styling), SOP page guides (collapsible
  reference cards), and info tooltips (ambient hover help). Research-backed: 4-step micro-tours
  (74% completion from Chameleon 550M data), zero gamification (NNGroup/DISC psychology),
  boss framing copy rules. Includes 9 guardrails (anchor polling, completion gating, force
  replay, iOS private browsing, double-tap guard, drawer detection, z-index management,
  dynamic step filtering, per-step overlay opacity).
version: 1.0
classification: encoded-preference
created: 2026-04-03
parameters:
  - name: project_name
    type: string
    default: "{{project_name}}"
  - name: primary_color
    type: string
    default: "#6EF1D6"
  - name: text_color
    type: string
    default: "#2F3437"
  - name: font_family
    type: string
    default: "'DM Sans', system-ui, sans-serif"
  - name: localStorage_prefix
    type: string
    default: "app_tour_"
  - name: demo_localStorage_prefix
    type: string
    default: "app_demo_"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Agent
---

# Guided Tour Skill — Three-Layer Contextual Guidance System

> **Research foundation**: Chameleon (550M data points), NNGroup (20-year senior usability),
> CrystalKnows (DISC psychology), Intercom (pause/resume UX), Appcues/Userpilot (progressive disclosure)

## When to Use This Skill

- User asks to add guided tours, walkthroughs, or onboarding to a React dashboard
- User wants page-level help (SOPs), info tooltips, or contextual guidance
- User says "add a tour", "guided tour", "walkthrough", "onboarding", "page guide"
- Expanding an existing tour system to new pages

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│  LAYER 3: GUIDED TOURS (driver.js)                       │
│  Push model — auto-triggers once, then replayable        │
│  Types: page tours, tab tours, contextual, demo          │
├──────────────────────────────────────────────────────────┤
│  LAYER 2: SOP PAGE GUIDES                                │
│  Pull model — collapsible cards, user clicks to expand   │
│  Sections: description → tables → features → steps → Q&A │
├──────────────────────────────────────────────────────────┤
│  LAYER 1: INFO TOOLTIPS                                  │
│  Ambient model — hover to discover                       │
│  Centralized content, Radix UI, plain language           │
└──────────────────────────────────────────────────────────┘
```

## Implementation Protocol

### Phase 1: Install Dependencies

```bash
npm install driver.js
```

No other dependencies required beyond what a typical React/Vite/Tailwind + Radix UI project already has.

### Phase 2: Scaffold Tour Infrastructure

Create these files in order. Each file is **project-agnostic infrastructure** — content is added separately.

#### 2.1 Tour Registry (`src/tours/tourRegistry.ts`)

Central state management for all tours. Manages:
- Tour IDs → localStorage keys mapping (prefixed with `{{localStorage_prefix}}`)
- Human-readable labels for menu display
- Route → tour ID mapping
- Tri-state completion: `true` | `'partial'` | `false`
- Safe localStorage access (iOS private browsing compatible)
- Force replay via `?tour=replay` URL param (G2 guardrail)

**Key exports**: `useTourState()`, `isForceReplay()`, `getTourForRoute()`, `TourId`, `TourStatus`

**Template pattern**:
```typescript
const TOUR_KEYS = {
  // Page tours — one per major page
  {{pageName}}: '{{localStorage_prefix}}{{page_slug}}',
  // Tab tours — one per tab within a page
  {{tabName}}: '{{localStorage_prefix}}{{tab_slug}}',
  // Demo tours
  {{demoName}}: '{{demo_localStorage_prefix}}{{demo_slug}}',
} as const;

export type TourId = keyof typeof TOUR_KEYS;

// Safe localStorage wrapper (iOS private browsing throws QuotaExceededError)
function safeGetItem(key: string): string | null {
  try { return localStorage.getItem(key); }
  catch { return null; }
}
```

#### 2.2 Page Tour Hook (`src/hooks/usePageTour.ts`)

Standard hook for page-level and contextual tours. Implements 3 council guardrails:

- **G3: Anchor polling** — Polls every 100ms (max 5s) for first step's DOM element before starting
- **G4: Completion gating** — Only marks `completed` if ALL steps were visible; otherwise `partial`
- **G2: Force replay** — `?tour=replay` URL param bypasses completion check

**Signature**:
```typescript
usePageTour(tourId: TourId, getSteps: () => DriveStep[], ready: boolean, options?: {
  maxWait?: number;      // Default 5000ms
  pollInterval?: number; // Default 100ms
  doneBtnText?: string;  // Default "Got it!"
})
```

**Critical implementation details**:
- `firedRef` prevents re-triggering on React re-renders
- Steps targeting missing DOM elements are silently filtered out
- `useEffect` cleanup destroys driver instance on unmount
- driver.js config: `showProgress: true`, `allowClose: true`, `overlayClickNext: false`
- **MUST set explicit button text** (`nextBtnText: 'Next →'`, `prevBtnText: '← Previous'`, `doneBtnText: 'Done'`) — driver.js innerHTML duplication bug causes doubled "Next" text without this
- **Brute-force DOM cleanup** in `onDestroyed` + 200ms setTimeout — driver.js orphans overlay elements
- **Drawer detection**: pause polling while `[role="dialog"]` exists in DOM; dispatch `bb-drawer-opened` event to kill active tour when drawer opens

#### 2.3 Demo Tour Hook (`src/hooks/useDemoTour.ts`)

Extended hook for interactive demos with per-step async actions:

```typescript
interface DemoStep extends DriveStep {
  action?: (driver, helpers) => Promise<void>;  // Runs on Next click
  cleanup?: (helpers) => void;                  // Runs when leaving step
  overlayOpacity?: number;                      // 0 = transparent, 0.15 = narration
  nextBtnText?: string;                         // "Watch..." / "Show me →"
}
```

**Critical guardrails**:
- **Double-tap guard**: `actionRunning` flag prevents rapid Next clicks during async actions
- **Button state**: Visually disables Next button (opacity 0.5) during action execution
- **SVG direct manipulation**: Sets overlay opacity on SVG path element directly — NEVER use `setConfig()` (it wipes entire driver.js config)
- **Body class**: Adds `demo-tour-active` during demo for CSS scoping
- **Fresh helpers**: Creates new helper instance on each replay (captures current state)

Returns `{ replay, isActive }` for TourMenu integration.

#### 2.4 Demo Helpers (`src/tours/demoHelpers.ts`)

Project-specific helpers for interactive demo tours. This file is the **primary customization point** — adapt to your app's state management and UI.

**Interface pattern** (adapt methods to your app):
```typescript
interface DemoHelpers {
  navigateTo: (target: string) => Promise<void>;   // App-specific navigation
  selectItem: (id: string) => Promise<void>;        // Select entity in UI
  deselectItem: () => void;                          // Clear selection
  toggleFeature: (id: string, on: boolean) => Promise<void>; // Toggle UI feature
  waitForElement: (selector: string, timeout?: number) => Promise<Element>;
  waitMs: (ms: number) => Promise<void>;
  getStats: () => Record<string, number>;            // Live stats from store
  cleanup: () => void;                               // Restore pre-demo state
}
```

**Key pattern**: Track all state changes during demo (Map/Set) and restore originals on cleanup.

#### 2.5 Tour Menu (`src/tours/TourMenu.tsx`)

Global floating button (bottom-right) with tour replay:

- Route-aware: shows current page's tour prominently
- Smart visibility: hides when header button visible, or when drawer/modal open
- Lazy loading: step files imported only when user clicks
- Demo replay: registered callback pattern
- `registerTourSteps(tourId, getSteps)` — called by pages at module load
- `registerDemoReplay(tourId, replay)` — called by demo tour pages

#### 2.6 Tour Styles (`src/styles/GuidedTourStyles.css`)

driver.js CSS overrides with your design language:

**Must customize** (parameterized):
- `{{font_family}}` — Font stack
- `{{text_color}}` — Primary text color
- `{{primary_color}}` — Button/accent color
- Background, border, shadow values

**Must include** (guardrails + quality):
- `.driver-popover-close-btn` min 44px tap target (mobile accessibility)
- `.driver-active-element` highlight glow animation
- `.driver-popover` entrance animation (tourSlideIn)
- `.driver-popover-arrow` directional bounce animations
- Mobile responsive: `@media (max-width: 640px)` full-width popovers
- Z-index: overlay 10000, popover 10002 (above modal libraries)
- Demo-specific: `.demo-act-start`, `.demo-narration`, `.demo-live-proof`
- `.demo-tour-active` body class scoping for hiding distractions
- **G10 safety net**: `body:not(.driver-active) .driver-overlay { display: none !important; pointer-events: none !important; }` — kills orphaned overlays after cleanup
- **G12 crisp edges**: `.driver-overlay { shape-rendering: crispEdges; }` — prevents fuzzy SVG cutout borders

**Premium popover pattern** (tested, production-validated):
```css
/* Accent top bar — subtle brand touch */
.driver-popover.bb-tour-popover::before {
  content: '';
  position: absolute;
  top: 0; left: 24px; right: 24px; height: 3px;
  background: linear-gradient(90deg, hsl(var(--accent)), hsl(var(--accent) / 0.4));
  border-radius: 0 0 3px 3px;
}
/* Elevated shadow with accent glow */
.driver-popover.bb-tour-popover {
  border-radius: 16px;
  box-shadow:
    0 0 0 1px hsl(var(--accent) / 0.08),
    0 4px 24px -4px hsl(var(--accent) / 0.12),
    0 12px 40px -8px rgba(0, 0, 0, 0.15);
}
/* Next button: pill with depth */
.driver-popover-next-btn {
  border-radius: 10px;
  box-shadow: 0 1px 3px hsl(var(--accent) / 0.25);
}
/* Previous button: transparent ghost */
.driver-popover-prev-btn {
  background: transparent;
  border: 1px solid hsl(var(--border));
}
```

### Phase 3: Scaffold SOP Page Guide System

#### 3.1 Types (`src/components/guide/types.ts`)

```typescript
export type SopId = 'sop-01' | 'sop-02' | /* add per page */;

export interface SopContent {
  id: SopId;
  title: string;
  pageDescription: string;
  features: SopFeature[];
  tables?: SopTable[];
  howToUse: SopStep[];
  commonQuestions: SopQuestion[];
}

export interface SopFeature { name: string; description: string; }
export interface SopStep { step: number; instruction: string; }
export interface SopQuestion { question: string; answer: string; }
export interface SopTable { heading: string; headers: string[]; rows: string[][]; }
```

#### 3.2 Content File (`src/components/guide/sopContent.ts`)

Centralized SOP content — **this is the primary content authoring file**. One entry per page.

**Content authoring rules** (per SOP):
1. `pageDescription`: 1-2 sentences — what the user sees
2. `tables` (optional): Reference data organized by section
3. `features`: 4-6 key capabilities with name + 1-sentence description
4. `howToUse`: 5-7 numbered steps (progressive disclosure)
5. `commonQuestions`: 5-6 Q&A pairs addressing real confusion points

#### 3.3 PageGuide Component (`src/components/guide/PageGuide.tsx`)

Collapsible card with BookOpen icon. Default collapsed. Renders:
What This Page Shows → Tables → Key Features → How to Use → Common Questions

#### 3.4 GuideSection Component (`src/components/guide/GuideSection.tsx`)

Sub-renderers: `FeaturesList`, `StepsList`, `QuestionsAccordion`, `DataTable`

### Phase 4: Scaffold Info Tooltip System

#### 4.1 Tooltip Content (`src/components/ui/tooltip-content.ts`)

Centralized tooltip strings — single file for all hover help:

```typescript
export const TOOLTIP_CONTENT = {
  // ── Section Name ──
  field_name: 'Plain English explanation for the user.',
  // ...
} as const;
```

#### 4.2 InfoTooltip Component (`src/components/ui/info-tooltip.tsx`)

Radix Tooltip wrapper with Info icon. Props: `{ text: string; side?: 'top'|'right'|'bottom'|'left' }`

### Phase 5: Add Tour Steps (Per Page)

For each page, create a step file in `src/tours/steps/`:

```typescript
// src/tours/steps/{{pageName}}Steps.ts
import type { DriveStep } from 'driver.js';

export function get{{PageName}}Steps(): DriveStep[] {
  return [
    // Step 1: Intro (no element — centered popover)
    {
      popover: {
        title: '{{Page Title}}',
        description: '{{What the user sees — value-first, max 2 sentences}}',
      },
    },
    // Steps 2-4: Target key UI elements
    {
      element: '[data-tour="{{element-id}}"]',
      popover: {
        title: '{{Element Name}}',
        description: '{{What it does — plain language, one idea}}',
        side: 'bottom' as const,
        align: 'center' as const,
      },
    },
    // ... max 3-5 steps total
  ];
}
```

### Phase 6: Integrate in Pages

```typescript
// In page component
import { registerTourSteps } from '@/tours/TourMenu';
import { get{{PageName}}Steps } from '@/tours/steps/{{pageName}}Steps';

// Register for menu
registerTourSteps('{{tourId}}', get{{PageName}}Steps);

// Auto-trigger on first visit
usePageTour('{{tourId}}', get{{PageName}}Steps, true);

// Add data-tour attributes to key elements
<div data-tour="{{element-id}}">...</div>

// Optionally add SOP guide
<PageGuide sopId="sop-{{nn}}" />
```

---

## Research-Backed Copy Rules (Non-Negotiable)

| Rule | Why |
|------|-----|
| Max 3-5 steps per tour | 4-step tours: 74% completion. 7+: 16% (Chameleon 550M) |
| One idea per step | Cognitive load management |
| Max 2 sentences per step | Memory load reduction |
| First step shows value, not explanation | Red DISC: decides in 30 seconds (CrystalKnows) |
| No gamification (no levels/badges/points) | Backfires for goal-oriented users (NNGroup) |
| Boss framing ("Your data" not "our tool") | Psychological ownership |
| No jargon — user's vocabulary | Comprehension across skill levels |
| No exclamations | Professional tone |
| Escape always visible (X, Skip, Close) | User must feel in control |
| "Click" not "tap" (desktop-first) | Consistent language convention |

## 9 Guardrails (All Must Be Implemented)

| # | Guardrail | Implementation |
|---|-----------|----------------|
| G1 | **Anchor polling** | 100ms intervals, 5s max — don't start tour until first DOM element exists |
| G2 | **Force replay** | `?tour=replay` URL param bypasses completion check |
| G3 | **Completion gating** | Only mark `completed` if ALL steps visible; else `partial` |
| G4 | **Dynamic filtering** | Steps targeting missing DOM elements silently skipped |
| G5 | **iOS private browsing** | `safeGetItem/safeSetItem` try/catch wrappers |
| G6 | **Double-tap guard** | `actionRunning` flag during async demo actions |
| G7 | **Drawer/modal detection** | Hide TourMenu when drawer open (MutationObserver on body class) |
| G8 | **Z-index management** | Overlay 10000, popover 10001 (above modal libraries) |
| G9 | **No setConfig for opacity** | Manipulate SVG directly — setConfig wipes entire driver.js config |
| G10 | **CSS safety net** | `body:not(.driver-active) .driver-overlay { display: none !important; pointer-events: none !important; }` — kills orphaned overlays |
| G11 | **Explicit button text** | Always set `nextBtnText`, `prevBtnText`, `doneBtnText` — driver.js innerHTML duplication bug doubles button text without these |
| G12 | **Crisp SVG edges** | `shape-rendering: crispEdges` on `.driver-overlay` — prevents fuzzy/blurred cutout borders |

## Tour Taxonomy (4 Types)

| Type | Trigger | Use When |
|------|---------|----------|
| **Page tour** | First page visit | Every major page gets one (3-5 steps) |
| **Contextual tour** | First interaction (drawer, modal, expand) | Nested UI that needs separate explanation |
| **Tab tour** | First tab switch | Multi-tab pages where each tab is distinct |
| **Demo tour** | Manual trigger / TourMenu | Cinematic "show don't tell" for presentations |

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| **Tour inside `createPortal` drawer** | **CRITICAL: driver.js overlay (z-10000) sits above the portal (z-9999). SVG `<path>` has inline `pointer-events:auto`. After tour ends, overlay persists and blocks ALL clicks in the drawer. 6 fix attempts failed — React state updates in destroy callbacks cause re-renders that corrupt driver.js cleanup. This is unfixable without migrating the drawer to shadcn/ui Sheet.** | **NEVER run driver.js tours inside `createPortal` drawers. Only use tours inside standard React components or shadcn/ui Sheet (which handles z-index via Radix Portal). If drawer tour is needed, migrate drawer to `<Sheet>` first.** |
| `setIsActive()` or React state updates in `onDestroyStarted` | Triggers React re-render mid-destroy — DOM shifts under driver.js, cleanup fails, overlay persists | Only call `driverRef.current?.destroy()` in `onDestroyStarted`. Track state changes via polling or `onDestroyed` callback AFTER destroy completes |
| 7+ step tour | 16% completion rate | Split into 3-5 step micro-tours |
| `setConfig({ overlayOpacity })` mid-tour | Wipes entire driver.js config | Manipulate SVG path element directly |
| Gamification ("Level 1", badges, points) | Backfires for goal-oriented users | Checkmarks in menu, nothing more |
| Technical jargon in step copy | Comprehension barrier | User's own vocabulary |
| Auto-trigger on every visit | No recovery if tour fails | Fire once, store in localStorage, replay via menu |
| Fixed delay before tour start | Unreliable with async data | Anchor polling (100ms intervals, 5s max) |
| `boolean` completion state | Can't distinguish "saw all" from "some missing" | Tri-state: `true` / `'partial'` / `false` |
| Steps without element checks | Tour breaks if section not rendered | Filter steps before passing to driver.js |

## File Checklist

After scaffolding, verify these files exist:

```
src/tours/
  ├── tourRegistry.ts     ← Central state (required)
  ├── TourMenu.tsx         ← Global floating button (required)
  ├── demoHelpers.ts       ← Demo actions (if using demos)
  ├── steps/               ← One file per page (required)
  └── demos/               ← Demo tour scripts (if using demos)
src/hooks/
  ├── usePageTour.ts       ← Page tour hook (required)
  └── useDemoTour.ts       ← Demo tour hook (if using demos)
src/components/guide/
  ├── types.ts             ← SOP type definitions (if using SOPs)
  ├── sopContent.ts        ← SOP content (if using SOPs)
  ├── PageGuide.tsx        ← Collapsible SOP renderer (if using SOPs)
  └── GuideSection.tsx     ← Sub-renderers (if using SOPs)
src/components/ui/
  ├── info-tooltip.tsx     ← Tooltip component (if using tooltips)
  └── tooltip-content.ts   ← Centralized tooltip strings (if using tooltips)
src/styles/
  └── GuidedTourStyles.css ← driver.js overrides (required)
```

## Customization Points

| What to Customize | Where | How |
|------------------|-------|-----|
| Tour step content | `src/tours/steps/*.ts` | Write steps per page (3-5 each) |
| SOP content | `src/components/guide/sopContent.ts` | One entry per page |
| Tooltip strings | `src/components/ui/tooltip-content.ts` | One line per field |
| Demo actions | `src/tours/demoHelpers.ts` | Adapt to your app's state/UI |
| Colors/fonts | `src/styles/GuidedTourStyles.css` | Replace parameterized values |
| Tour IDs | `src/tours/tourRegistry.ts` | Add entries for your pages |
| localStorage prefix | `src/tours/tourRegistry.ts` | Change `{{localStorage_prefix}}` |

## Proven Origin

This skill is extracted from a production implementation powering 24 tours across 16 pages
of a real-time operations dashboard. Validated through 3 council sessions, 20+ git commits,
and research-backed design principles (Chameleon, NNGroup, CrystalKnows DISC psychology).
