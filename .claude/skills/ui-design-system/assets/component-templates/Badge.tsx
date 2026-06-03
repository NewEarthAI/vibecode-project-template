/**
 * NewEarth UI — Badge Component Template
 * ----------------------------------------
 * Status pill with locked semantic variants. No pastel backgrounds, no decorative
 * icons, no emoji. Text-only by default.
 *
 * Drop into src/components/ui/badge.tsx (replaces shadcn-ui default Badge).
 *
 * Usage:
 *   <Badge>Neutral default</Badge>
 *   <Badge variant="critical">3 critical</Badge>
 *   <Badge variant="warning">Pending</Badge>
 *   <Badge variant="success">Resolved</Badge>
 *   <Badge variant="outline" size="sm">F23</Badge>
 */

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const badgeVariants = cva(
  [
    'inline-flex items-center gap-1',
    'rounded-full font-semibold',
    'transition-colors duration-150',
    'whitespace-nowrap',
  ],
  {
    variants: {
      variant: {
        /**
         * Default — muted neutral. Use for non-state labels.
         * Example: a tag, a count, a category that doesn't map to an operational state.
         */
        neutral: [
          'bg-[var(--ne-bg-muted)] text-[var(--ne-fg-secondary)]',
          'border border-[var(--ne-border-hairline)]',
        ],

        /**
         * Critical — severity=critical, destructive action, negative variance, confidence <45%.
         */
        critical: [
          'bg-[var(--ne-critical-bg)] text-[var(--ne-critical)]',
          'border border-[color:var(--ne-critical)]/20',
        ],

        /**
         * Warning — severity=medium, caution, confidence 45-84%.
         */
        warning: [
          'bg-[var(--ne-warning-bg)] text-[var(--ne-warning)]',
          'border border-[color:var(--ne-warning)]/20',
        ],

        /**
         * Success — state=resolved, positive variance, confidence ≥85%.
         */
        success: [
          'bg-[var(--ne-success-bg)] text-[var(--ne-success)]',
          'border border-[color:var(--ne-success)]/20',
        ],

        /**
         * Info — neutral action, announcement, non-critical highlight.
         */
        info: [
          'bg-[var(--ne-info-bg)] text-[var(--ne-info)]',
          'border border-[color:var(--ne-info)]/20',
        ],

        /**
         * Outline — even more minimal than neutral. Text only, border only, no fill.
         * Use when even the neutral fill is too loud.
         */
        outline: [
          'bg-transparent text-[var(--ne-fg-secondary)]',
          'border border-[var(--ne-border-hairline)]',
        ],
      },
      size: {
        /** Micro badge — for inline counts and tiny tags. */
        sm: 'text-[10px] px-1.5 py-0',
        /** Default size — the standard badge. */
        default: 'text-xs px-2.5 py-0.5',
        /** Large — for hero counters or standalone status indicators. */
        lg: 'text-sm px-3 py-1',
      },
    },
    defaultVariants: {
      variant: 'neutral',
      size: 'default',
    },
  }
);

interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, size, ...props }: BadgeProps) {
  return (
    <span
      className={cn(badgeVariants({ variant, size }), className)}
      {...props}
    />
  );
}

export { badgeVariants };
