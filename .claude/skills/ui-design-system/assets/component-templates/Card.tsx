/**
 * NewEarth UI — Card Component Template
 * --------------------------------------
 * Drop into src/components/ui/card.tsx (replaces shadcn-ui default Card).
 *
 * Features:
 * - Neutral warm off-white base
 * - Hairline border
 * - Signature two-layer shadow
 * - 300ms hover curve with translate-y lift (when `interactive`)
 * - Silver hover ring on interaction (when `interactive`)
 * - Silver metallic edge (when `premium`)
 *
 * Usage:
 *   <Card className="p-6">Static card</Card>
 *   <Card interactive onClick={...}>Clickable</Card>
 *   <Card interactive premium>Hero KPI with silver edge</Card>
 */

import * as React from 'react';
import { cn } from '@/lib/utils';

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /**
   * Apply the signature hover curve + silver hover ring.
   * Use on any card that responds to user interaction.
   */
  interactive?: boolean;

  /**
   * Apply the hairline metallic silver border (Mode A).
   * Reserve for hero surfaces: KPI heroes, drawer headers, premium panels.
   */
  premium?: boolean;

  /**
   * Apply the silver top-edge stripe (Mode B).
   * Reserve for proposal heroes and report cover panels.
   * Do NOT combine with `premium`.
   */
  topStripe?: boolean;
}

export const Card = React.forwardRef<HTMLDivElement, CardProps>(
  ({ className, interactive, premium, topStripe, children, ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={cn(
          // Base
          'rounded-xl bg-[var(--ne-bg-base)]',
          'shadow-[0_1px_2px_0_rgb(0_0_0/0.04),0_1px_3px_0_rgb(0_0_0/0.06)]',
          'transition-all duration-300 ease-in-out',

          // Border — hairline unless premium (which uses gradient via pseudo-element)
          !premium && 'border border-[var(--ne-border-hairline)]',

          // Interactive: signature hover curve + silver ring
          interactive && [
            'cursor-pointer',
            'hover:shadow-[0_4px_6px_-1px_rgb(0_0_0/0.08),0_2px_4px_-1px_rgb(0_0_0/0.04)]',
            'hover:-translate-y-0.5',
            'outline outline-1 outline-transparent outline-offset-[-1px]',
            'hover:outline-[rgb(192_195_199/0.4)]',
            'focus-visible:outline-2 focus-visible:outline-[rgb(192_195_199/0.6)]',
            'active:translate-y-0',
          ],

          // Premium: silver metallic border (Mode A)
          premium && 'ne-silver-edge',

          // Top stripe (Mode B)
          topStripe && !premium && 'ne-silver-top',

          className
        )}
        tabIndex={interactive ? 0 : undefined}
        role={interactive ? 'button' : undefined}
        {...props}
      >
        {children}
      </div>
    );
  }
);
Card.displayName = 'Card';

/**
 * CardHeader — standard card header section.
 * Padding: px-6 py-4 (24h / 16v) — the NewEarth drawer-header standard.
 */
export const CardHeader = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn('flex flex-col space-y-1.5 px-6 py-4', className)}
      {...props}
    />
  )
);
CardHeader.displayName = 'CardHeader';

/**
 * CardTitle — uses locked type scale.
 */
export const CardTitle = React.forwardRef<HTMLHeadingElement, React.HTMLAttributes<HTMLHeadingElement>>(
  ({ className, ...props }, ref) => (
    <h3
      ref={ref}
      className={cn(
        'text-lg font-semibold leading-tight tracking-tight text-[var(--ne-fg-primary)]',
        className
      )}
      {...props}
    />
  )
);
CardTitle.displayName = 'CardTitle';

/**
 * CardDescription — muted secondary text.
 */
export const CardDescription = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLParagraphElement>>(
  ({ className, ...props }, ref) => (
    <p
      ref={ref}
      className={cn('text-sm text-[var(--ne-fg-secondary)]', className)}
      {...props}
    />
  )
);
CardDescription.displayName = 'CardDescription';

/**
 * CardContent — standard card content section.
 * Padding: px-6 py-4 by default. Override for vertical-heavy content (e.g., px-4 py-6).
 */
export const CardContent = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('px-6 py-4', className)} {...props} />
  )
);
CardContent.displayName = 'CardContent';

/**
 * CardFooter — action row at the bottom of a card.
 */
export const CardFooter = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn(
        'flex items-center px-6 py-4 border-t border-[var(--ne-border-hairline)] bg-[var(--ne-bg-subtle)]',
        className
      )}
      {...props}
    />
  )
);
CardFooter.displayName = 'CardFooter';
