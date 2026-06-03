/**
 * NewEarth UI — Drawer Component Template
 * -----------------------------------------
 * Wrapper around shadcn-ui's Sheet component with NewEarth theming and the
 * locked drawer structure: header (subtle bg) → scrollable content with
 * collapsible sections → footer (subtle bg).
 *
 * PREREQUISITE: shadcn-ui Sheet primitive must be installed in your project
 * before copying this file. Run:
 *   npx shadcn-ui@latest add sheet
 *
 * This imports from '@/components/ui/sheet' which assumes the shadcn-ui
 * Sheet component has been scaffolded. If that file doesn't exist, this
 * component will fail to compile.
 *
 * Drop into src/components/ui/drawer.tsx.
 *
 * Usage:
 *   <Drawer open={open} onOpenChange={setOpen} title="Fleet 3" subtitle="Loaded">
 *     <DrawerSection title="Details" count={1}>
 *       ...
 *     </DrawerSection>
 *     <DrawerSection title="Activity" count={3}>
 *       ...
 *     </DrawerSection>
 *   </Drawer>
 */

import * as React from 'react';
import { useState } from 'react';
import { ChevronDown } from 'lucide-react';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';
import { cn } from '@/lib/utils';

// ============================================================================
// Drawer — the container
// ============================================================================

interface DrawerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  subtitle?: string;
  /** 'right' (default) or 'left' */
  side?: 'right' | 'left';
  /** Tailwind width class, e.g., 'w-96' (default) or 'w-[500px]' */
  width?: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
}

export function Drawer({
  open,
  onOpenChange,
  title,
  subtitle,
  side = 'right',
  width = 'w-full sm:max-w-md',
  children,
  footer,
}: DrawerProps) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side={side}
        className={cn(
          'flex flex-col p-0',
          'bg-[var(--ne-bg-base)]',
          'border-l border-[var(--ne-border-hairline)]',
          width
        )}
      >
        {/* Header — subtle background, hairline border below */}
        <SheetHeader
          className={cn(
            'px-6 py-4 flex-shrink-0',
            'border-b border-[var(--ne-border-hairline)]',
            'bg-[var(--ne-bg-subtle)]',
            'space-y-1'
          )}
        >
          <SheetTitle
            className={cn(
              'text-lg font-semibold leading-tight tracking-tight',
              'text-[var(--ne-fg-primary)]'
            )}
          >
            {title}
          </SheetTitle>
          {subtitle && (
            <SheetDescription className="text-sm text-[var(--ne-fg-secondary)]">
              {subtitle}
            </SheetDescription>
          )}
        </SheetHeader>

        {/* Scrollable content area */}
        <div className="flex-1 overflow-y-auto">
          {children}
        </div>

        {/* Optional footer with actions */}
        {footer && (
          <div
            className={cn(
              'px-6 py-4 flex-shrink-0',
              'border-t border-[var(--ne-border-hairline)]',
              'bg-[var(--ne-bg-subtle)]'
            )}
          >
            {footer}
          </div>
        )}
      </SheetContent>
    </Sheet>
  );
}

// ============================================================================
// DrawerSection — collapsible section inside a drawer
// ============================================================================

interface DrawerSectionProps {
  title: string;
  /** Optional count displayed next to the title as a mono tag. */
  count?: number;
  /** Whether the section starts expanded. Default: true. */
  defaultOpen?: boolean;
  /** Optional trailing action shown on the right side of the section header. */
  action?: React.ReactNode;
  children: React.ReactNode;
}

export function DrawerSection({
  title,
  count,
  defaultOpen = true,
  action,
  children,
}: DrawerSectionProps) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className="border-b border-[var(--ne-border-hairline)] last:border-b-0">
      {/* Section header — subtle bg, uppercase label, optional count tag */}
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className={cn(
          'w-full px-6 py-3',
          'bg-[var(--ne-bg-subtle)]',
          'flex items-center justify-between',
          'hover:bg-[var(--ne-bg-muted)]',
          'transition-colors duration-150',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ne-silver-ring)] focus-visible:ring-inset'
        )}
        aria-expanded={open}
      >
        <span className="flex items-center gap-2">
          <span
            className={cn(
              'text-xs font-semibold uppercase tracking-wider',
              'text-[var(--ne-fg-secondary)]'
            )}
          >
            {title}
          </span>
          {count !== undefined && (
            <span
              className={cn(
                'px-1.5 py-0.5 rounded',
                'bg-[var(--ne-bg-base)]',
                'border border-[var(--ne-border-hairline)]',
                'text-[var(--ne-fg-secondary)]',
                'font-mono text-[10px] tabular-nums'
              )}
            >
              {count}
            </span>
          )}
        </span>

        <div className="flex items-center gap-2">
          {action}
          <ChevronDown
            className={cn(
              'h-4 w-4 text-[var(--ne-fg-tertiary)]',
              'transition-transform duration-300',
              open && 'rotate-180'
            )}
            aria-hidden="true"
          />
        </div>
      </button>

      {/* Section content — standard px-6 py-4 */}
      {open && (
        <div className="px-6 py-4">
          {children}
        </div>
      )}
    </div>
  );
}

// ============================================================================
// DrawerDivider — silver structural divider (Mode D)
// ============================================================================

/**
 * Use between major drawer sections when the divider is conveying structural
 * importance. For normal section breaks, use the standard border-b instead.
 */
export function DrawerSilverDivider({ className }: { className?: string }) {
  return (
    <hr
      className={cn('ne-divider-silver', className)}
      aria-hidden="true"
    />
  );
}
