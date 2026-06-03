/**
 * NewEarth UI — PageHeader Component Template
 * --------------------------------------------
 * Page-level header / app bar with optional silver bottom-edge accent.
 *
 * Default variant = hairline bottom border, monochrome — daily-driver pages.
 * `variant="silver"` adds the brushed silver bottom-edge stripe — opt-in for
 * proposal pages, landing page heroes, report covers, dashboard zone anchors.
 *
 * Pairs with the page-shell pattern (see references/page-shell.md). Render
 * inside a sticky container at the top of the page. Compose with Button
 * (silver variant) for matched-pair premium hero treatments.
 *
 * Usage:
 *   <PageHeader title="Pipeline" />
 *
 *   <PageHeader
 *     variant="silver"
 *     title="Q2 Investment Proposal"
 *     subtitle="Prepared for Acme Capital"
 *     actions={<Button variant="silver">Download PDF</Button>}
 *   />
 */

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const headerVariants = cva(
  [
    'relative w-full',
    'bg-[var(--ne-bg-base)]',
    'px-6 py-4 md:px-8 md:py-5',
  ],
  {
    variants: {
      variant: {
        /** Default: hairline bottom border. Daily-driver pages. */
        default: 'border-b border-[var(--ne-border-hairline)]',

        /**
         * Silver: hairline border PLUS a 2px brushed silver bottom-edge stripe.
         * Reserved for proposal/report/landing-hero contexts. One per page.
         * Stripe rendered via `::after` so it overlays the hairline cleanly.
         */
        silver: [
          'border-b border-[var(--ne-border-hairline)]',
          "after:content-[''] after:absolute after:inset-x-0 after:bottom-0",
          'after:h-[2px] after:bg-[var(--ne-silver-edge-strip)]',
          'after:pointer-events-none',
        ],
      },
      density: {
        compact: 'py-3 md:py-3',
        default: '',
        spacious: 'py-6 md:py-8',
      },
    },
    defaultVariants: {
      variant: 'default',
      density: 'default',
    },
  }
);

export interface PageHeaderProps
  extends React.HTMLAttributes<HTMLElement>,
    VariantProps<typeof headerVariants> {
  /** Page title. Renders as h1. */
  title: React.ReactNode;
  /** Optional subtitle / context line below the title. */
  subtitle?: React.ReactNode;
  /** Optional eyebrow label above the title (breadcrumb context, section name). */
  eyebrow?: React.ReactNode;
  /** Right-side action slot (Button group, settings menu, etc.). */
  actions?: React.ReactNode;
  /**
   * Apply the brushed-silver text gradient to the title.
   * Opt-in further on top of `variant="silver"` for ultra-premium contexts.
   * Use sparingly — at most one silver-titled header per project.
   */
  silverTitle?: boolean;
}

export const PageHeader = React.forwardRef<HTMLElement, PageHeaderProps>(
  (
    {
      className,
      variant,
      density,
      title,
      subtitle,
      eyebrow,
      actions,
      silverTitle,
      ...props
    },
    ref
  ) => {
    return (
      <header
        ref={ref}
        className={cn(headerVariants({ variant, density }), className)}
        {...props}
      >
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0 flex-1">
            {eyebrow && (
              <div className="mb-1 text-xs font-medium uppercase tracking-wide text-[var(--ne-fg-secondary)]">
                {eyebrow}
              </div>
            )}
            <h1
              className={cn(
                'truncate text-xl font-semibold leading-tight tracking-tight md:text-2xl',
                silverTitle
                  ? 'bg-[var(--ne-silver-gradient)] bg-clip-text text-transparent'
                  : 'text-[var(--ne-fg-primary)]'
              )}
            >
              {title}
            </h1>
            {subtitle && (
              <p className="mt-1 text-sm text-[var(--ne-fg-secondary)]">
                {subtitle}
              </p>
            )}
          </div>
          {actions && (
            <div className="flex shrink-0 items-center gap-2">{actions}</div>
          )}
        </div>
      </header>
    );
  }
);
PageHeader.displayName = 'PageHeader';

export { headerVariants };
