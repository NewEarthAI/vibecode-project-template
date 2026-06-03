# Progressive Disclosure — The the agency Depth Pattern

> **What this is**: the rule set for how the agency interfaces reveal complexity. An operator sees 70% of the story at a glance, reaches the rest in two clicks, and never sees raw source data unless they explicitly ask. Every data-dense drawer, detail panel, and inspector surface follows this depth architecture. When done right, the interface feels *shallow to scan, deep to investigate* — the defining quality that separates an operational tool from a spreadsheet with a theme.

---

## The Principle

Show synthesized state first. Reveal structured evidence on demand. Reveal raw source data on deeper demand. Each depth level costs the operator attention — earn the click by guaranteeing the next level is denser, not just wider.

Progressive disclosure is not "hiding things". It is *editing for attention*. A Level 0 verdict that says "On route, ETA 14:32" is more useful than a collapsed section labeled "Status" — the operator knows whether to drill down before they click.

---

## Vocabulary (Domain-Neutral)

These terms replace domain-specific language in the spec. When implementing for a specific domain, substitute freely — but the *structure* of the pattern does not change.

| Generic Term | Meaning | Logistics Example | PropTech Example | SaaS Example |
|---|---|---|---|---|
| **Entity** | The primary object the drawer describes | Fleet / Truck | Property / Unit | Customer / Account |
| **Entity Identifier** | The short label shown at Level 0 | Fleet 3 (FL 3) | Unit 7A | Acme Corp |
| **Primary Transaction** | The main lifecycle event | Load / Booking | Lease / Tenancy | Subscription / Contract |
| **Supporting Artifact** | Documentary proof attached to an event | POD (proof of delivery) | Inspection report | Invoice / Receipt |
| **Temporal Trace** | Time-series data for an event or period | Speed trace / GPS trail | Utility readings | Usage metrics / Uptime log |
| **Actor** | The person performing the action | Driver | Tenant / Contractor | End user |
| **Operator** | The person viewing the dashboard | Controller / Dispatcher | Property manager | Account manager / CSM |
| **Lifecycle Timeline** | The ordered sequence of status transitions | Load Start > Loaded > Delivered | Application > Approved > Move-in | Trial > Active > Renewal |
| **Evidence** | Any data that supports or contradicts a status | WhatsApp photo, telematics event | Inspection photo, meter reading | API log, support ticket |
| **State Anomaly** | A condition that deviates from normal | Idle detected, breakdown | Overdue maintenance, vacancy | Churn risk, degraded SLA |

---

## The Four Depth Levels

### Level 0 — At-a-Glance Verdict

**Purpose**: Deliver the synthesized answer in one sentence. The operator should know whether to drill deeper or move on *without clicking anything*.

**Affordance**: Always visible. Cannot be collapsed or hidden. Sits at the top of every drawer, above all sections.

**Anatomy**:
- A colored left border bar (4px) signaling the verdict tier (green / amber / red / gray)
- A matching icon
- One sentence: entity identifier + current state + the single most relevant metric
- No raw data. No timestamp arrays. No IDs.

**Closing behavior**: N/A — Level 0 is always rendered. It does not open or close.

**Implementation pattern**:

```tsx
interface VerdictBannerProps {
  level: 'ok' | 'warn' | 'critical' | 'neutral';
  summary: string;
}

function VerdictBanner({ level, summary }: VerdictBannerProps) {
  return (
    <div className={cn(
      'flex items-start gap-3 rounded-lg px-4 py-3',
      'border-l-4 bg-[var(--ne-bg-subtle)]',
      level === 'ok' && 'border-l-[var(--ne-success)]',
      level === 'warn' && 'border-l-[var(--ne-warning)]',
      level === 'critical' && 'border-l-[var(--ne-critical)]',
      level === 'neutral' && 'border-l-[var(--ne-border-strong)]',
    )}>
      <VerdictIcon level={level} className="mt-0.5 h-4 w-4 shrink-0" />
      <p className="text-sm font-medium text-[var(--ne-fg-primary)]">
        {summary}
      </p>
    </div>
  );
}
```

**a logistics app exemplar**: [FleetVerdictBanner.tsx](src/components/fleet-hub/drawer/FleetVerdictBanner.tsx) — computes verdict via `computeFleetVerdict()` from timeline, enrichment, and booking context.

---

### Level 1 — Primary Sections

**Purpose**: Group related data into collapsible blocks. Each section answers one question about the entity (e.g. "what is the current transaction?", "what happened recently?", "are there open issues?").

**Affordance**: Click the section header to expand or collapse. Sections show a title, an icon, and an optional count badge (e.g. "Events (12)").

**Anatomy**:
- Section header: icon + title + optional count badge + chevron indicator
- Collapsed: header only (single row)
- Expanded: header + section content (metric rows, mini-tables, timelines)
- Exactly one section may default to open (`defaultOpen`); the rest start collapsed

**Closing behavior**: Click the same header to collapse. State is local (`useState`): each section tracks its own expanded/collapsed independently. Closing the parent drawer resets all sections to their `defaultOpen` value.

**Implementation pattern**:

```tsx
interface SectionProps {
  title: string;
  icon: LucideIcon;
  count?: number;
  defaultOpen?: boolean;
  children: React.ReactNode;
}

function Section({ title, icon: Icon, count, defaultOpen = false, children }: SectionProps) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className="border-b border-[var(--ne-border-hairline)]">
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center gap-2 px-4 py-3 text-left"
      >
        <Icon className="h-4 w-4 text-[var(--ne-fg-secondary)]" />
        <span className="text-sm font-medium text-[var(--ne-fg-primary)]">{title}</span>
        {count != null && (
          <span className="ml-auto text-xs text-[var(--ne-fg-tertiary)]">{count}</span>
        )}
        <ChevronDown className={cn(
          'h-4 w-4 text-[var(--ne-fg-tertiary)]',
          'transition-transform',
          `duration-[var(--ne-duration-base)]`,
          open && 'rotate-180',
        )} />
      </button>
      {open && <div className="px-4 pb-4">{children}</div>}
    </div>
  );
}
```

**a logistics app exemplar**: [DrawerSection in DrawerPrimitives.tsx:23](src/components/fleet-hub/drawer/DrawerPrimitives.tsx#L23).

---

### Level 2 — Inline Detail Reveal

**Purpose**: Expand a single row within a Level 1 section to show additional detail *without leaving the section*. The operator can see more about one item while the rest of the section stays visible for context.

**Affordance**: Click a "More" / "Details" text link or a row-level chevron within a Level 1 section. The expansion is inline — no new surface opens.

**Anatomy**:
- Trigger: a subtle text link ("More", "Details", "View breakdown") or a clickable row
- Expanded state: additional metric rows, a mini-table, or a timeline fragment appear below the trigger, indented or inside a subdued container
- Collapsed state: the trigger text alone

**Closing behavior**: Click the same trigger ("Less", "Hide") to collapse. State is local `useState` scoped to the individual row — collapsing one row does not affect others.

**When to use Level 2 vs Level 3**: If the detail fits inside the existing section (3-10 additional rows), use Level 2. If the detail needs its own header, its own sections, or shows raw source data — use Level 3.

**a logistics app exemplar**: `showMore` state in [DrawerBookingContext.tsx](src/components/fleet-hub/drawer/DrawerBookingContext.tsx) — expands additional booking metadata inline.

---

### Level 3 — Deep-Dive Escape Hatch

**Purpose**: Open a focused workspace for a single item that needs its own drawer-level depth. This is the "I need to really look at this one thing" gesture.

**Affordance**: Click an item card, a row action button, or a "View details" link within a Level 1 or Level 2 context. A new surface opens on top of — not replacing — the parent drawer.

**Anatomy**:
- A new Sheet (Radix) or panel slides in from the right, layered over the parent
- The parent drawer is dimmed but its scroll position and expanded sections are preserved
- The new surface has its own Level 0 verdict (optional), Level 1 sections, and Level 2 reveals
- No further Level 3 nesting: this is the terminal depth

**Closing behavior**: Close button (X) or backdrop click dismisses the nested surface. The parent drawer reappears in its preserved state. Escape key (Radix default) also works.

**Critical rule**: **parent state must be preserved**. When the operator closes the Level 3 surface, the parent drawer must be exactly as they left it — same scroll position, same expanded sections, same data. If this is not preserved, the operator loses trust in the pattern.

**When to use Level 3 vs full-page navigation**: Use Level 3 when the operator needs to *compare back* to the parent entity. Use full-page navigation when the target is a standalone entity that doesn't relate back to the parent in the same session.

**a logistics app exemplar**: [FuelEventDetailDrawer.tsx:411](src/components/fleet-hub/drawer/FuelEventDetailDrawer.tsx#L411) — a second Radix Sheet layered over FleetDetailDrawer, showing fuel event lifecycle, slip images, and variance analysis.

---

## Interaction Rules — When to Use Which Level

| Scenario | Recommended Level | Rationale |
|---|---|---|
| Operator needs to know "is this entity OK?" | 0 (Verdict) | One sentence, no click required |
| Operator needs to see a category of data (events, issues, media) | 1 (Section) | Click to expand the relevant section |
| Operator needs more detail about one item in a list | 2 (Inline Reveal) | "More" inside the section — no context switch |
| Operator needs to deeply investigate one item (view images, timelines, raw data) | 3 (Deep Dive) | New surface with its own depth stack |
| Operator needs to navigate to a different entity entirely | Full-page navigation | Not a disclosure level — a route change |
| Operator needs to compare two items side by side | Avoid nested drawers | Consider split view or tabbed layout instead |

---

## Closing Discipline

Each depth level has explicit closing behavior. Ambiguous close states erode operator trust.

| Level | Close Trigger | State After Close | Scroll Preserved? |
|---|---|---|---|
| 0 (Verdict) | N/A — always visible | N/A | N/A |
| 1 (Section) | Click header again | Collapsed; other sections unaffected | Parent drawer scroll: yes |
| 2 (Inline Reveal) | Click "Less" / toggle | Collapsed; section stays open | Section scroll: yes |
| 3 (Deep Dive) | X button, backdrop click, Esc | Nested surface dismissed; parent restored | Parent drawer: yes (critical) |
| Entire drawer | X button, backdrop click, Esc | All state reset to defaults on next open | No — fresh render |

**On drawer reopen**: all Level 1 sections reset to their `defaultOpen` value. Level 2 expansions reset to collapsed. API data may be cached (React Query), but UI state is not persisted across drawer open/close cycles.

---

## Cross-Domain Applications

The four-level pattern applies identically regardless of domain. Only the vocabulary changes.

| Level | Logistics (Fleet Hub) | PropTech (Property Hub) | SaaS (Customer Hub) |
|---|---|---|---|
| **0 — Verdict** | "Fleet 3 — On route, ETA 14:32, no issues" | "Unit 7A — Rent-ready, 3 prospects viewing" | "Acme Corp — Active, 92% health score" |
| **1 — Sections** | Booking / Timeline / Issues / Media / Fuel | Lease / Maintenance / Inspections / Utilities / Tenants | Usage / Billing / Support / Integrations / Team |
| **2 — Reveal** | "More" per fuel event, per timeline entry | "More" per work order, per inspection item | "More" per usage spike, per invoice line |
| **3 — Deep Dive** | Fuel Event detail drawer | Work Order detail drawer | Invoice detail drawer |

**Adapting to a new domain**: start by defining Level 0 — what is the one-sentence verdict for this entity? If you cannot write the verdict sentence, you do not understand the domain well enough to build the drawer. The verdict sentence drives the entire depth stack: it tells the operator what to drill into and what to skip.

**Section count guidance**: 3-6 Level 1 sections is the sweet spot. Fewer than 3 means the entity is too simple for a drawer (use an inline card). More than 6 means you are cramming unrelated concerns into one surface — split into sub-entities or tabs.

---

## Anti-Patterns

### 1. NEVER collapse Level 0 (the Verdict)

```tsx
// ✗ REJECTED — verdict hidden behind a click
<Section title="Summary" defaultOpen={false}>
  <VerdictBanner level="warn" summary="..." />
</Section>

// ✓ CORRECT — verdict always visible, above all sections
<VerdictBanner level="warn" summary="..." />
<Section title="Booking" defaultOpen>...</Section>
<Section title="Timeline">...</Section>
```

**Why**: the entire pattern depends on Level 0 being zero-click. If the operator must expand a section to see the verdict, they have no signal for whether to drill deeper. The drawer becomes a wall of collapsed headers — indistinguishable from a file browser.

---

### 2. NEVER reflect raw status as the verdict

```tsx
// ✗ REJECTED — raw enum, not a synthesized sentence
<VerdictBanner level="ok" summary="Status: LOADED" />

// ✓ CORRECT — synthesized: entity + state + context
<VerdictBanner level="ok" summary="Fleet 3 — Loaded at RCM, ETA Durban 14:32" />
```

**Why**: raw status (`LOADED`, `active`, `pending`) forces the operator to mentally map the enum to meaning. A synthesized verdict does the mapping for them. "LOADED" requires context; "Loaded at RCM, ETA Durban 14:32" is actionable without context.

---

### 3. NEVER open Level 3 for content that fits in Level 2

```tsx
// ✗ REJECTED — opening a full drawer for 3 extra fields
<Button onClick={() => setDetailOpen(true)}>View fuel details</Button>
<FuelDetailDrawer open={detailOpen} /> // contains: liters, cost, station — 3 fields

// ✓ CORRECT — inline expand for small detail sets
<button onClick={() => setShowMore(!showMore)}>
  {showMore ? 'Less' : 'More'}
</button>
{showMore && (
  <div className="mt-2 space-y-1 pl-4">
    <MetricRow label="Liters" value="350" />
    <MetricRow label="Cost" value="R 8,400" />
    <MetricRow label="Station" value="Engen N4 Middelburg" />
  </div>
)}
```

**Why**: every Level 3 drawer is a context switch. The operator loses sight of the parent section while the nested drawer is open. That cost is justified for rich content (images, timelines, multiple sections) — not for 3 metric rows. The threshold: if it fits in 3-10 rows without its own header, it is Level 2.

---

### 4. NEVER destroy parent state when opening Level 3

```tsx
// ✗ REJECTED — replacing parent drawer with nested content
const [view, setView] = useState<'parent' | 'detail'>('parent');
{view === 'parent' ? <ParentDrawer /> : <DetailDrawer />}
// parent scroll position, expanded sections: LOST

// ✓ CORRECT — layered surfaces, parent preserved underneath
<Sheet open={parentOpen} onOpenChange={setParentOpen}>
  <SheetContent>
    <ParentContent />
    <Sheet open={detailOpen} onOpenChange={setDetailOpen}>
      <SheetContent>{/* detail content */}</SheetContent>
    </Sheet>
  </SheetContent>
</Sheet>
```

**Why**: replacing the parent surface is the single biggest trust violation in progressive disclosure. The operator clicked expecting to go *deeper* — not to lose their place. Layered surfaces (Radix Sheet nesting) preserve parent state by keeping both DOM trees mounted.

---

### 5. NEVER nest beyond Level 3

```tsx
// ✗ REJECTED — drawer inside drawer inside drawer
<Sheet> {/* Level 1-2 parent */}
  <Sheet> {/* Level 3 deep dive */}
    <Sheet> {/* Level 4?! */}
      {/* The operator is now 3 surfaces deep with no breadcrumb */}
    </Sheet>
  </Sheet>
</Sheet>

// ✓ CORRECT — Level 3 is terminal. For deeper data, navigate to a full page.
<Sheet> {/* parent */}
  <Sheet> {/* Level 3 — terminal depth */}
    <Link href={`/entities/${id}/raw`}>View raw audit log</Link>
  </Sheet>
</Sheet>
```

**Why**: three stacked surfaces exceed working memory. The operator cannot track where they are or how to get back. If Level 3 content needs its own deep dive, the target is complex enough to warrant a dedicated page — not a fourth drawer.

---

## Composition Notes

This pattern is orthogonal to other the agency design system references:

- **Silver signature** ([silver-signature.md](silver-signature.md)): Apply Mode D (silver section divider) between Level 1 sections inside drawers. Apply Mode A (hairline metallic border) on the Level 0 verdict banner if it is a premium surface.
- **Dark mode** ([dark-mode.md](dark-mode.md)): All four levels must render correctly in both light and dark modes. The Level 0 verdict bar uses `var(--ne-bg-subtle)` which maps to `#1A1A1B` in dark mode.
- **Color discipline** ([color-discipline.md](color-discipline.md)): The Level 0 verdict border color must map to a semantic state (critical / warning / success / neutral). Decorative color at any level is prohibited.
- **Component recipes** ([component-recipes.md](component-recipes.md)): Recipe 3 (Drawer) documents the base Sheet container. This reference extends Recipe 3 with the 4-level depth architecture.
- **Guided-tour**: Tours should NOT walk through Level 2 or Level 3 disclosures. Tour steps should point at Level 0 and Level 1 sections only — deeper levels are operator-initiated, not guided.

---

## Implementation Checklist

Use this when building a new drawer or auditing an existing one:

- [ ] Level 0 verdict is rendered unconditionally (not inside a collapsible section)
- [ ] Level 0 verdict is a synthesized sentence, not a raw status enum
- [ ] Level 1 sections have icon + title + optional count badge
- [ ] Exactly one Level 1 section defaults to open; others start collapsed
- [ ] Level 2 inline reveals use "More" / "Less" toggles, not separate surfaces
- [ ] Level 3 opens a new Sheet layered *over* the parent, not replacing it
- [ ] Parent scroll position and expanded sections survive a Level 3 open/close cycle
- [ ] No Level 4 nesting exists — Level 3 is terminal
- [ ] All levels render correctly in both light and dark mode
- [ ] Section dividers use `var(--ne-border-hairline)` or silver Mode D (see [silver-signature.md](silver-signature.md))
- [ ] Chevron rotation uses `duration-[var(--ne-duration-base)]` (300ms) with `var(--ne-ease-in-out)`
- [ ] No `rounded-2xl`, no `backdrop-blur-*`, no emoji, no gradient backgrounds in any level

---

## Optional Enhancements (Validated by Research)

These patterns were observed in competitor products (Stripe, Linear, Vercel) during the design of this reference. They are not required by the the agency depth pattern, but are validated as compatible enhancements for specific use cases.

| Enhancement | Source | When to Consider | Implementation |
|---|---|---|---|
| **Peek Preview** | Linear (Space bar to preview) | High-volume list views where operators scan 50+ items | Add a hover or keyboard-triggered tooltip-sized preview between list and drawer open |
| **Sidebar-in-Context** | Vercel (log detail sidebar) | When Level 3 content benefits from cross-item comparison in the parent list | Replace drawer-over-drawer with a right panel that preserves the parent list on the left |
| **Line-Addressable Raw Output** | Vercel (build log `#L6` anchors) | When Level 3 shows raw text logs that operators share via links | Add line numbers with click-to-copy anchor URLs |

---

*Validated against: Stripe Dashboard (4-level: list > detail > accordion > focus overlay), Linear (5-level: list > peek > issue > sidebar > collapsed activity), Vercel (5-level: dashboard > project > deployments > detail > log sidebar). the agency's 4-level pattern aligns with Stripe's depth and avoids unnecessary intermediate layers. Research conducted 2026-04-10.*

*Last updated: 2026-04-10. See [component-recipes.md](component-recipes.md) Recipe 3 for the base Drawer container this pattern extends.*
