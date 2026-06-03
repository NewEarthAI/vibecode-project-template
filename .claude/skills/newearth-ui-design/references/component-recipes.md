# Component Recipes — Canonical Patterns

> **Rule**: copy these patterns, don't invent new ones. Variation is the enemy of house style. When a new use case emerges that doesn't fit an existing recipe, add it here rather than improvising.

---

## Recipe 1 — Standard Card

The base unit. Neutral surface, hairline border, signature hover curve, silver ring on interaction.

```tsx
import { cn } from '@/lib/utils';
import type { HTMLAttributes } from 'react';

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  interactive?: boolean;
  premium?: boolean;
}

export function Card({ className, interactive, premium, children, ...props }: CardProps) {
  return (
    <div
      className={cn(
        'rounded-xl border border-[var(--ne-border-hairline)] bg-[var(--ne-bg-base)]',
        'shadow-[var(--ne-shadow-card)]',
        'transition-all duration-300 ease-in-out',
        interactive && [
          'cursor-pointer',
          'hover:shadow-[var(--ne-shadow-card-hover)] hover:-translate-y-0.5',
          'hover:outline hover:outline-1 hover:outline-[#C0C3C7]/40',
          'focus-visible:outline focus-visible:outline-2 focus-visible:outline-[#C0C3C7]/60',
          'active:translate-y-0 active:shadow-[var(--ne-shadow-card)]',
        ],
        premium && 'ne-silver-edge',
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}
```

**Usage**:

```tsx
// Static card — default
<Card className="p-6">
  <h3 className="text-lg font-semibold">Title</h3>
  <p className="text-sm text-[var(--ne-fg-secondary)]">Description</p>
</Card>

// Interactive card — signature hover + silver ring
<Card interactive className="p-6" onClick={handleClick}>
  {/* content */}
</Card>

// Premium card — silver edge + interactive (recommended combo)
<Card interactive premium className="p-6">
  {/* content — hero KPIs, drawer headers, etc. */}
</Card>
```

**Anti-patterns**:
- `rounded-2xl` or `rounded-3xl` (banned)
- `bg-white` (use `--ne-bg-base`)
- `shadow-lg` / `shadow-xl` / `shadow-2xl` (use the signature two-layer shadow)
- `backdrop-blur-*` (banned)
- Custom hover curves (always use the signature)

---

## Recipe 2 — KPI Hero Card

The big-number display. JetBrains Mono numeric, uppercase tracked label, responsive clamp() sizing, optional variance indicator.

```tsx
import { cn } from '@/lib/utils';
import { ArrowUp, ArrowDown } from 'lucide-react';

interface KpiCardProps {
  label: string;
  value: string | number;
  variance?: { value: number; direction: 'up' | 'down' | 'flat' };
  context?: string; // e.g., "59 drivers active"
  hero?: boolean; // uses ne-kpi-value-hero sizing
  premium?: boolean; // applies silver edge
  className?: string;
}

export function KpiCard({ label, value, variance, context, hero, premium, className }: KpiCardProps) {
  return (
    <div
      className={cn(
        'rounded-xl border border-[var(--ne-border-hairline)] bg-[var(--ne-bg-base)]',
        'shadow-[var(--ne-shadow-card)] transition-all duration-300',
        'px-6 py-5 flex flex-col gap-2',
        'hover:shadow-[var(--ne-shadow-card-hover)] hover:-translate-y-0.5',
        'hover:outline hover:outline-1 hover:outline-[#C0C3C7]/40',
        premium && 'ne-silver-edge',
        className
      )}
    >
      <span className="ne-label text-[var(--ne-fg-secondary)]">
        {label}
      </span>

      <span
        className={cn(
          'font-mono font-semibold tabular-nums leading-none text-[var(--ne-fg-primary)]',
          hero ? 'text-[var(--ne-kpi-value-hero)]' : 'text-[var(--ne-kpi-value)]'
        )}
      >
        {value}
      </span>

      {context && (
        <span className="text-xs text-[var(--ne-fg-tertiary)]">
          {context}
        </span>
      )}

      {variance && <VarianceIndicator {...variance} />}
    </div>
  );
}

function VarianceIndicator({ value, direction }: { value: number; direction: 'up' | 'down' | 'flat' }) {
  const colorClass = {
    up: 'text-[var(--ne-success)]',
    down: 'text-[var(--ne-critical)]',
    flat: 'text-[var(--ne-fg-secondary)]',
  }[direction];

  const Icon = direction === 'up' ? ArrowUp : direction === 'down' ? ArrowDown : null;

  return (
    <span className={cn('flex items-center gap-1 text-xs font-mono tabular-nums', colorClass)}>
      {Icon && <Icon className="h-3 w-3" />}
      {value > 0 ? '+' : ''}{value}% vs last period
    </span>
  );
}
```

**Usage**:

```tsx
<div className="grid grid-cols-2 md:grid-cols-4 gap-4">
  <KpiCard
    label="Total Loads"
    value="321"
    context="59 drivers active"
    variance={{ value: 2, direction: 'up' }}
  />
  <KpiCard
    label="Avg Loads / Driver"
    value="5.4"
    context="This pay period"
  />
  <KpiCard
    label="Top Performer"
    value="16"
    context="Fleet 27"
  />
  <KpiCard
    label="Total Earnings Liability"
    value="R1 151 700"
    context="Bonus: R160 500"
    variance={{ value: -8, direction: 'down' }}
  />
</div>
```

**Design notes**:
- All four cards are neutral backgrounds. Only the variance arrow carries color.
- Positive variance = success green (`#067647`). Negative = critical red (`#B42318`). Flat = neutral gray.
- The value uses `tabular-nums` + `font-mono` so digits never jitter if the number updates live.
- Label is uppercase, tracked wide, muted gray. Never competes with the value for attention.

---

## Recipe 3 — Drawer / Sheet

> For multi-depth drawer patterns (Level 0-3), see [progressive-disclosure.md](progressive-disclosure.md).

Based on shadcn-ui's Sheet component. Locked structure: header (subtle background) → scrollable content with section groupings → footer actions.

```tsx
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from '@/components/ui/sheet';
import { ChevronDown } from 'lucide-react';
import { useState } from 'react';

interface DrawerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
}

export function Drawer({ open, onOpenChange, title, subtitle, children, footer }: DrawerProps) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="flex flex-col p-0 bg-[var(--ne-bg-base)]">
        {/* Header — always uses subtle background for separation */}
        <SheetHeader className="px-6 py-4 border-b border-[var(--ne-border-hairline)] bg-[var(--ne-bg-subtle)] flex-shrink-0">
          <SheetTitle className="text-lg font-semibold text-[var(--ne-fg-primary)]">
            {title}
          </SheetTitle>
          {subtitle && (
            <SheetDescription className="text-sm text-[var(--ne-fg-secondary)]">
              {subtitle}
            </SheetDescription>
          )}
        </SheetHeader>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto">
          {children}
        </div>

        {/* Footer actions */}
        {footer && (
          <div className="px-6 py-4 border-t border-[var(--ne-border-hairline)] bg-[var(--ne-bg-subtle)] flex-shrink-0">
            {footer}
          </div>
        )}
      </SheetContent>
    </Sheet>
  );
}

// Collapsible section inside a drawer
export function DrawerSection({
  title,
  count,
  defaultOpen = true,
  children
}: {
  title: string;
  count?: number;
  defaultOpen?: boolean;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className="border-b border-[var(--ne-border-hairline)] last:border-b-0">
      <button
        onClick={() => setOpen(!open)}
        className="w-full px-6 py-3 bg-[var(--ne-bg-subtle)] flex items-center justify-between hover:bg-[var(--ne-bg-muted)] transition-colors"
      >
        <span className="ne-label flex items-center gap-2">
          {title}
          {count !== undefined && (
            <span className="px-1.5 py-0.5 rounded bg-[var(--ne-bg-base)] border border-[var(--ne-border-hairline)] text-[var(--ne-fg-secondary)] font-mono text-[10px]">
              {count}
            </span>
          )}
        </span>
        <ChevronDown
          className={cn(
            'h-4 w-4 text-[var(--ne-fg-tertiary)] transition-transform duration-300',
            open && 'rotate-180'
          )}
        />
      </button>
      {open && (
        <div className="px-6 py-4">
          {children}
        </div>
      )}
    </div>
  );
}
```

**Usage**:

```tsx
<Drawer
  open={open}
  onOpenChange={setOpen}
  title="FL 3"
  subtitle="Loaded — On route, no issues, last update 0m ago"
>
  <DrawerSection title="Booking" count={1}>
    <BookingLifecycle />
  </DrawerSection>

  <DrawerSection title="Today's Activity" count={1}>
    <ActivityTimeline />
  </DrawerSection>

  <DrawerSection title="Evidence" defaultOpen={false}>
    <EvidenceList />
  </DrawerSection>
</Drawer>
```

**Design notes**:
- Section headers (subtle background `#F7F6F3`) create rhythm without visual noise.
- Count badges are monospace and tiny — information-dense, not decorative.
- Dividers are horizontal hairlines only. Never vertical. Never thick.
- For proposals or hero drawers, replace standard dividers with `.ne-divider-silver` (Mode D).

---

## Recipe 4 — Badge / Status Pill

Four variants: neutral (default), critical, warning, success. Text-only, no decorative icons.

```tsx
import { cn } from '@/lib/utils';
import { cva, type VariantProps } from 'class-variance-authority';

const badgeVariants = cva(
  'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors',
  {
    variants: {
      variant: {
        neutral: 'bg-[var(--ne-bg-muted)] text-[var(--ne-fg-secondary)] border border-[var(--ne-border-hairline)]',
        critical: 'bg-[var(--ne-critical-bg)] text-[var(--ne-critical)] border border-[var(--ne-critical)]/20',
        warning: 'bg-[var(--ne-warning-bg)] text-[var(--ne-warning)] border border-[var(--ne-warning)]/20',
        success: 'bg-[var(--ne-success-bg)] text-[var(--ne-success)] border border-[var(--ne-success)]/20',
        info: 'bg-[var(--ne-info-bg)] text-[var(--ne-info)] border border-[var(--ne-info)]/20',
        outline: 'bg-transparent text-[var(--ne-fg-secondary)] border border-[var(--ne-border-hairline)]',
      },
      size: {
        sm: 'text-[10px] px-1.5 py-0',
        default: 'text-xs px-2.5 py-0.5',
      },
    },
    defaultVariants: {
      variant: 'neutral',
      size: 'default',
    },
  }
);

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement>, VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, size, ...props }: BadgeProps) {
  return <span className={cn(badgeVariants({ variant, size }), className)} {...props} />;
}
```

**Usage — semantic slot map**:

| State | Variant |
|-------|---------|
| Critical severity, destructive, negative variance | `critical` |
| Warning severity, caution, confidence 45-84% | `warning` |
| Success state, positive variance, resolved | `success` |
| Informational, neutral action | `info` |
| Default label, non-state tag | `neutral` (default) |
| Minimalist label where even the neutral fill is too loud | `outline` |

**Rule**: if you are choosing a variant, you must be able to justify *which operational state* it represents. If it's just "this label should stand out", use `neutral` and rely on typography/position for hierarchy.

---

## Recipe 5 — Button

Four variants: primary (brand color), secondary (outline), ghost (text only), destructive (semantic critical).

```tsx
import { cn } from '@/lib/utils';
import { cva, type VariantProps } from 'class-variance-authority';
import { Slot } from '@radix-ui/react-slot';

const buttonVariants = cva(
  [
    'inline-flex items-center justify-center gap-2 whitespace-nowrap',
    'rounded-md text-sm font-medium',
    'transition-all duration-150',
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ne-silver-ring)] focus-visible:ring-offset-2',
    'disabled:pointer-events-none disabled:opacity-50',
  ],
  {
    variants: {
      variant: {
        primary: [
          'bg-[var(--ne-primary)] text-[var(--ne-primary-fg)]',
          'hover:bg-[var(--ne-primary-hover)]',
          'shadow-[var(--ne-shadow-card)]',
        ],
        secondary: [
          'bg-[var(--ne-bg-base)] text-[var(--ne-fg-primary)]',
          'border border-[var(--ne-border-hairline)]',
          'hover:bg-[var(--ne-bg-subtle)]',
          'shadow-[var(--ne-shadow-card)]',
        ],
        ghost: [
          'bg-transparent text-[var(--ne-fg-primary)]',
          'hover:bg-[var(--ne-bg-subtle)]',
        ],
        destructive: [
          'bg-[var(--ne-critical)] text-white',
          'hover:opacity-90',
          'shadow-[var(--ne-shadow-card)]',
        ],
        link: [
          'bg-transparent text-[var(--ne-primary)]',
          'underline-offset-4 hover:underline',
          'p-0 h-auto',
        ],
      },
      size: {
        sm: 'h-8 px-3 text-xs',
        default: 'h-10 px-4 py-2',
        lg: 'h-12 px-6 py-3 text-base',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'primary',
      size: 'default',
    },
  }
);

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export function Button({ className, variant, size, asChild, ...props }: ButtonProps) {
  const Comp = asChild ? Slot : 'button';
  return <Comp className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
```

**Primary button rules**:
- **One primary button per view maximum.** If you need two CTAs, one is primary and one is secondary.
- Primary uses `{{primary_color}}` — the client brand color.
- Focus ring is always silver (`--ne-silver-ring`), not brand color. Silver is the universal interaction marker.

---

## Recipe 6 — Table Row

Data tables are where color discipline matters most. Rows are neutral. Color only appears in cells where a cell value represents an operational state.

```tsx
import { cn } from '@/lib/utils';

interface TableRowProps extends React.HTMLAttributes<HTMLTableRowElement> {
  interactive?: boolean;
}

export function TableRow({ className, interactive, ...props }: TableRowProps) {
  return (
    <tr
      className={cn(
        'border-b border-[var(--ne-border-hairline)]',
        'transition-colors duration-150',
        interactive && [
          'cursor-pointer',
          'hover:bg-[var(--ne-bg-subtle)]',
        ],
        className
      )}
      {...props}
    />
  );
}

export function TableHead({ className, ...props }: React.ThHTMLAttributes<HTMLTableCellElement>) {
  return (
    <th
      className={cn(
        'px-4 py-3 text-left',
        'ne-label text-[var(--ne-fg-secondary)]',
        'bg-[var(--ne-bg-subtle)] border-b border-[var(--ne-border-hairline)]',
        className
      )}
      {...props}
    />
  );
}

export function TableCell({ className, ...props }: React.TdHTMLAttributes<HTMLTableCellElement>) {
  return (
    <td
      className={cn(
        'px-4 py-3 text-sm text-[var(--ne-fg-primary)]',
        className
      )}
      {...props}
    />
  );
}
```

**Design notes**:
- No zebra striping. Zebra striping is 2005. Hairline borders between rows are enough.
- Row hover uses `--ne-bg-subtle` — subtle warmth, no color.
- Numeric cells should add `font-mono tabular-nums` via className.
- Status cells should use the `Badge` component with the correct semantic variant.

---

## Recipe 7 — Empty State

Quiet, clear, actionable. No illustrations, no mascots, no emoji.

```tsx
interface EmptyStateProps {
  title: string;
  description?: string;
  action?: { label: string; onClick: () => void };
  icon?: React.ReactNode; // optional single lucide-react icon at 24-32px
}

export function EmptyState({ title, description, action, icon }: EmptyStateProps) {
  return (
    <div className="text-center py-12 px-6">
      {icon && (
        <div className="mx-auto mb-4 h-8 w-8 text-[var(--ne-fg-tertiary)]">
          {icon}
        </div>
      )}
      <h3 className="text-base font-semibold text-[var(--ne-fg-primary)]">
        {title}
      </h3>
      {description && (
        <p className="mt-1 text-sm text-[var(--ne-fg-secondary)] max-w-sm mx-auto">
          {description}
        </p>
      )}
      {action && (
        <Button variant="secondary" size="sm" onClick={action.onClick} className="mt-4">
          {action.label}
        </Button>
      )}
    </div>
  );
}
```

**Usage**:

```tsx
<EmptyState
  title="No active issues"
  description="All fleets are operating normally."
  icon={<CheckCircle />}
/>

<EmptyState
  title="No data available"
  action={{ label: 'Add first entry', onClick: handleAdd }}
/>
```

**Never**:
- "Oops! Nothing to see here 😢"
- Illustrations / SVG mascots
- "Let's get started!"
- Cheerful exclamation marks

---

## Recipe 8 — Loading Skeleton

Flat neutral pulse. No shimmer, no gradient, no color.

```tsx
interface SkeletonProps extends React.HTMLAttributes<HTMLDivElement> {}

export function Skeleton({ className, ...props }: SkeletonProps) {
  return (
    <div
      className={cn(
        'animate-pulse rounded-md bg-[var(--ne-bg-muted)]',
        className
      )}
      {...props}
    />
  );
}
```

**Usage**:

```tsx
<Card className="p-6 space-y-3">
  <Skeleton className="h-4 w-1/3" />
  <Skeleton className="h-8 w-2/3" />
  <Skeleton className="h-3 w-1/4" />
</Card>
```

**Never** use `bg-gradient-to-r from-X via-Y to-Z` shimmer effects — they draw attention to the waiting state instead of minimizing it.

---

## Recipe 9 — Form Input

Hairline border, subtle focus ring in silver (brand color ring reads as "attention"), no decorative icons.

```tsx
import { cn } from '@/lib/utils';

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {}

export function Input({ className, ...props }: InputProps) {
  return (
    <input
      className={cn(
        'flex h-10 w-full rounded-md px-3 py-2 text-sm',
        'bg-[var(--ne-bg-base)] border border-[var(--ne-border-hairline)]',
        'text-[var(--ne-fg-primary)] placeholder:text-[var(--ne-fg-tertiary)]',
        'transition-colors duration-150',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ne-silver-ring)] focus-visible:border-[var(--ne-border-strong)]',
        'disabled:cursor-not-allowed disabled:opacity-50 disabled:bg-[var(--ne-bg-muted)]',
        className
      )}
      {...props}
    />
  );
}
```

**Label pattern**:

```tsx
<label className="block space-y-1">
  <span className="text-sm font-medium text-[var(--ne-fg-primary)]">Email</span>
  <Input type="email" placeholder="you@example.com" />
</label>
```

---

## Recipe 10 — Section Header (Inside a Drawer or Dashboard)

Uppercase tracked label on subtle background. The section heading pattern that creates the "neat drawer" feel.

```tsx
interface SectionHeaderProps {
  title: string;
  count?: number;
  action?: React.ReactNode; // optional trailing button/link
}

export function SectionHeader({ title, count, action }: SectionHeaderProps) {
  return (
    <div className="px-6 py-3 bg-[var(--ne-bg-subtle)] border-b border-[var(--ne-border-hairline)] flex items-center justify-between">
      <div className="flex items-center gap-2">
        <span className="ne-label">{title}</span>
        {count !== undefined && (
          <span className="px-1.5 py-0.5 rounded bg-[var(--ne-bg-base)] border border-[var(--ne-border-hairline)] text-[var(--ne-fg-secondary)] font-mono text-[10px]">
            {count}
          </span>
        )}
      </div>
      {action}
    </div>
  );
}
```

---

## Composition Patterns

### Dashboard Page Layout

```tsx
<div className="min-h-screen bg-[var(--ne-bg-base)]">
  {/* Header with tour button — composes with guided-tour skill */}
  <header className="border-b border-[var(--ne-border-hairline)] bg-[var(--ne-bg-subtle)] px-6 py-4">
    <div className="flex items-center justify-between">
      <h1 className="text-2xl font-semibold">Fleet Dashboard</h1>
      <TourButton variant="primary" data-tour-header-btn>Take a Tour</TourButton>
    </div>
  </header>

  <main className="px-6 py-8 space-y-8">
    {/* Hero KPIs — premium cards with silver edge */}
    <section>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Loads" value="321" premium />
        <KpiCard label="Avg / Driver" value="5.4" premium />
        <KpiCard label="Top Performer" value="16" premium />
        <KpiCard label="Revenue" value="R1.15M" premium />
      </div>
    </section>

    {/* Silver divider for structural section break */}
    <hr className="ne-divider-silver" />

    {/* Standard section — regular cards */}
    <section>
      <h2 className="text-lg font-semibold mb-4">Operations</h2>
      <div className="grid grid-cols-3 gap-4">
        <Card interactive className="p-6">...</Card>
        <Card interactive className="p-6">...</Card>
        <Card interactive className="p-6">...</Card>
      </div>
    </section>
  </main>
</div>
```

**Key pattern**:
- Hero KPIs get `premium` (silver edge)
- Standard cards get `interactive` (silver hover ring only)
- Sections separated by `ne-divider-silver` when structural, flat `border-b` when inline
- Brand color only on the tour button and any primary CTA

---

---

## Recipe 11 — Client Brand Hero Slot (Placeholder / Future Work)

> **Status**: concept reserved, not yet fully specified. Placeholder so the idea isn't lost.

### Concept

A dedicated hero slot at the top of client dashboards for an upscaled, cinematic, AI-enhanced version of the client's logo — a visual stamp that communicates "your AI transformation is underway". Small "Powered by NewEarth AI" subtitle beside it.

### Characteristics (to refine)

- **Client logo treatment**: upscaled to 32k equivalent via AI tools (Nano Banana 2, Magnific, Topaz, or similar), cinematic lighting, hyper-realistic, futuristic framing
- **Placement**: top of dashboard, inside the main header or as a premium card directly below it
- **Attribution**: "Powered by NewEarth AI" in small tracked label beside or beneath the hero logo — never dominant
- **Container**: uses the `premium` Card variant (silver metallic edge — Mode A) — the one case where silver signature and client brand meet
- **Frequency**: appears once per dashboard session, on the primary landing view only. Not on every page.

### Design questions to resolve

- Does the cinematic logo animate on page load (subtle reveal) or stay static?
- How is the "Powered by NewEarth AI" attribution styled — wordmark, icon, both?
- Does the hero slot reserve a fixed height across clients, or size to fit each client's logo proportions?
- What happens in dark mode — does the cinematic logo have a dark variant or is it processed to work on both?
- Integration with tour button — does the tour button sit inside the hero slot or separately?

### When To Add This Recipe Fully

When at least three production clients have been through the "AI transformation stamp" treatment, canonicalize the pattern here with specific CSS + component code. Until then, treat as a high-touch custom element per client, not a templated component.

---

*Every recipe here has been reverse-engineered from patterns that survived production. If a new recipe is needed, add it here — don't invent at call sites.*
