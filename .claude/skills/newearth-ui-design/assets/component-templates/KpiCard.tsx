/**
 * NewEarth UI — KPI Card Template
 * --------------------------------
 * The hero big-number display. JetBrains Mono numeric, DM Sans label, responsive
 * clamp() sizing, optional variance indicator with semantic color.
 *
 * Drop into src/components/ui/kpi-card.tsx or src/components/KpiCard.tsx.
 *
 * Usage:
 *   <KpiCard
 *     label="Total Loads"
 *     value="321"
 *     context="59 drivers active"
 *     variance={{ value: 2, direction: 'up' }}
 *   />
 *
 *   <KpiCard label="Revenue" value="R1 151 700" hero premium />
 */

import * as React from 'react';
import { cn } from '@/lib/utils';
import { ArrowUp, ArrowDown, Minus } from 'lucide-react';
import { Card } from './Card';

interface VarianceProps {
  value: number;
  direction: 'up' | 'down' | 'flat';
  suffix?: string; // e.g., "vs last period"
}

interface KpiCardProps extends Omit<React.HTMLAttributes<HTMLDivElement>, 'onClick'> {
  /** Uppercase tracked label shown above the value. */
  label: string;

  /** The big number. String to allow formatted values ("R1 151 700", "5.4", "92%"). */
  value: string | number;

  /** Optional descriptive context line below the value. */
  context?: string;

  /** Optional variance indicator with semantic coloring. */
  variance?: VarianceProps;

  /** Use the larger `--ne-kpi-value-hero` sizing. Reserve for top-of-page KPIs. */
  hero?: boolean;

  /** Apply the silver metallic edge (premium signature). */
  premium?: boolean;

  /** Make the card interactive with the signature hover curve. */
  interactive?: boolean;

  /** Click handler — if provided, interactive defaults to true. */
  onClick?: () => void;
}

export function KpiCard({
  label,
  value,
  context,
  variance,
  hero,
  premium,
  interactive,
  onClick,
  className,
  ...props
}: KpiCardProps) {
  const isInteractive = interactive ?? Boolean(onClick);

  return (
    <Card
      interactive={isInteractive}
      premium={premium}
      onClick={onClick}
      className={cn('flex flex-col gap-2 px-6 py-5', className)}
      {...props}
    >
      {/* Label — uppercase, tracked, muted */}
      <span
        className={cn(
          'text-[var(--ne-kpi-label)]',
          'uppercase tracking-wider font-medium',
          'text-[var(--ne-fg-secondary)]'
        )}
      >
        {label}
      </span>

      {/* Value — JetBrains Mono, tabular, responsive clamp() */}
      <span
        className={cn(
          'font-mono font-semibold tabular-nums leading-none',
          'text-[var(--ne-fg-primary)]',
          hero
            ? 'text-[clamp(40px,6vw,72px)]'
            : 'text-[clamp(32px,5vw,56px)]'
        )}
      >
        {value}
      </span>

      {/* Optional context line */}
      {context && (
        <span className="text-xs text-[var(--ne-fg-tertiary)]">
          {context}
        </span>
      )}

      {/* Variance indicator — the only place color appears */}
      {variance && <VarianceIndicator {...variance} />}
    </Card>
  );
}

function VarianceIndicator({ value, direction, suffix = 'vs last period' }: VarianceProps) {
  const config = {
    up:   { color: 'var(--ne-success)',       Icon: ArrowUp },
    down: { color: 'var(--ne-critical)',      Icon: ArrowDown },
    flat: { color: 'var(--ne-fg-secondary)',  Icon: Minus },
  }[direction];

  const { color, Icon } = config;
  const displayValue = value > 0 ? `+${value}` : `${value}`;

  return (
    <span
      className="flex items-center gap-1 text-xs font-mono tabular-nums"
      style={{ color }}
    >
      <Icon className="h-3 w-3" aria-hidden="true" />
      <span>{displayValue}% {suffix}</span>
    </span>
  );
}
