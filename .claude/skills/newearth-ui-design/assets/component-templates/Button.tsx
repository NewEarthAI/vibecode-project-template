/**
 * NewEarth UI — Button Component Template
 * ----------------------------------------
 * Drop into src/components/ui/button.tsx (replaces shadcn-ui default Button).
 *
 * Default variants use the brand `--ne-primary` color. Silver variants are
 * OPT-IN and reserved for premium contexts: proposal CTAs, hero actions,
 * report cover panels, landing page primary actions. Do not use silver
 * buttons in dense operational dashboards — at scale they read as decorative.
 *
 * Three silver tiers (lightest → heaviest):
 *   silverOutline  — solid 1px silver line, transparent fill (utility silver)
 *   silverEdge     — 1px metallic-gradient ring, neutral fill (Mode G — quieter premium)
 *   silver         — brushed-silver fill (Mode E — heaviest premium, max 1/viewport)
 *
 * Usage:
 *   <Button>Default primary</Button>
 *   <Button variant="ghost">Ghost</Button>
 *   <Button variant="outline">Outline</Button>
 *
 *   // Silver variants — premium-context only
 *   <Button variant="silver">Brushed silver primary</Button>
 *   <Button variant="silverEdge">Silver-edge premium</Button>
 *   <Button variant="silverOutline">Silver outline</Button>
 */

import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  [
    'inline-flex items-center justify-center gap-2 whitespace-nowrap',
    'rounded-md font-medium',
    'transition-all duration-300 ease-in-out',
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
    'focus-visible:ring-[var(--ne-silver-ring)] focus-visible:ring-offset-[var(--ne-bg-base)]',
    'disabled:pointer-events-none disabled:opacity-50',
    "[&_svg]:size-4 [&_svg]:shrink-0",
  ],
  {
    variants: {
      variant: {
        /** Brand-colored primary CTA. Uses `--ne-primary`. */
        default: [
          'bg-[var(--ne-primary)] text-[var(--ne-primary-foreground)]',
          'hover:brightness-105 hover:-translate-y-0.5',
          'hover:shadow-[0_4px_6px_-1px_rgb(0_0_0/0.08),0_2px_4px_-1px_rgb(0_0_0/0.04)]',
          'active:translate-y-0',
        ],

        /** Hairline border, neutral fill on hover. Secondary CTA. */
        outline: [
          'bg-transparent text-[var(--ne-fg-primary)]',
          'border border-[var(--ne-border-hairline)]',
          'hover:bg-[var(--ne-bg-subtle)] hover:border-[var(--ne-silver-ring)]',
        ],

        /** No border, no fill. Tertiary action. */
        ghost: [
          'bg-transparent text-[var(--ne-fg-primary)]',
          'hover:bg-[var(--ne-bg-subtle)]',
        ],

        /**
         * Brushed-silver primary — opt-in premium variant.
         * Reserved for: proposal hero CTAs, landing page primary action,
         * report cover "Download" buttons. Do not stack multiple per view.
         */
        silver: [
          'text-[var(--ne-fg-primary)]',
          'bg-[var(--ne-silver-gradient)]',
          'border border-[var(--ne-silver-mid)]',
          'shadow-[inset_0_1px_0_0_rgba(255,255,255,0.45),0_1px_2px_0_rgba(0,0,0,0.06)]',
          'hover:brightness-[1.04] hover:-translate-y-0.5',
          'hover:shadow-[inset_0_1px_0_0_rgba(255,255,255,0.55),0_4px_8px_-2px_rgba(0,0,0,0.10)]',
          'active:translate-y-0 active:brightness-100',
        ],

        /**
         * Silver outline — opt-in premium secondary variant.
         * Pairs with `variant="silver"` as a "Learn more" beside the primary CTA.
         */
        silverOutline: [
          'bg-transparent text-[var(--ne-fg-primary)]',
          'border border-[var(--ne-silver-mid)]',
          'hover:bg-[var(--ne-bg-subtle)]',
          'hover:border-[var(--ne-silver-ring)]',
          'hover:-translate-y-0.5',
          'active:translate-y-0',
        ],

        /**
         * Silver edge — opt-in premium variant with a 1px metallic-gradient ring.
         * Mode G: sits between brand-default (heavy color) and silver fill
         * (Mode E heaviest). The button fill stays neutral; the silver lives
         * in the edge ring only. Static — no continuous animation. The ring
         * starts at 65% opacity and fades to 100% on hover/focus (transition,
         * not animation).
         *
         * Reserved for: premium secondary CTAs, presentation toolbars, brand-
         * anchor surfaces where Mode E silver fill would over-signal. Up to
         * 2 per viewport (looser budget than Mode E).
         *
         * Not for Atelier Dark — Atelier's signature is bronze, not silver.
         * See references/silver-signature.md Mode G.
         */
        silverEdge: [
          'ne-button-silver-edge',
          'text-[var(--ne-fg-primary)]',
          'hover:-translate-y-0.5',
          'hover:shadow-[0_4px_8px_-2px_rgb(0_0_0/0.08)]',
          'active:translate-y-0 active:shadow-none',
        ],
      },
      size: {
        sm: 'h-8 px-3 text-xs',
        default: 'h-10 px-4 text-sm',
        lg: 'h-11 px-6 text-base',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        ref={ref}
        className={cn(buttonVariants({ variant, size }), className)}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export { buttonVariants };
