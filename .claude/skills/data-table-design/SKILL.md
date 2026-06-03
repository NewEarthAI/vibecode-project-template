---
name: data-table-design
description: |
  Use when designing or fixing data tables for any the agency / a SaaS app / agency
  project — pipeline tables, dashboards, lists, KPI grids, anything rendering
  rows × columns of business data. Codifies the seven non-negotiable rules:
  (1) headers ALWAYS centred, (2) cells centred by default, (3) long-text streams
  left-aligned, (4) right-alignment banned, (5) inline-flex for cell wrappers,
  (6) subtle vertical dividers in body rows only, (7) USPS Pub 28 address
  formatting + ordinal-aware title-casing. Trigger phrases: "table looks messy",
  "fix table alignment", "build a data table", "neaten this table",
  "right-aligned looks terrible", "headers don't line up with cells",
  "address column is ugly". Skip this skill for non-tabular layouts (cards,
  forms, charts) — only fires on row-column data displays.
version: 1.0
classification: encoded-preference
user-invocable: false
note: L3 library — auto-loaded by /design-review and /ui-design-system when a tabular surface is detected. Not a human entry point.
created: 2026-05-03
updated: 2026-05-03
validated_on:
  - a SaaS app seller pipeline table (10 column sections, 80+ columns)
  - Header-cell centroid stack-up across all financial / count / badge / address columns
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
companion_skills:
  - brand-visual-identity (brand tokens — colour, typography)
  - tailwind-shadcn-system (CSS architecture for Tailwind v4 + shadcn)
  - design-review (visual audit of running UI)
  - frontend-design (general production-grade UI)
---

# Data Table Design — the agency Standard

> Every table in every agency project should obey these rules by default. The
> patterns below shipped on a SaaS app's pipeline (2026-05-03) after three rounds
> of UX feedback distilled the rule set down to what actually reads cleanly.

---

## The Seven Rules

### Rule 1 — Headers ALWAYS centred

Every column header sits on the column's vertical midline. No left-aligned,
no right-aligned, no exceptions.

**Why**: gives the eye a single anchor point per column. When some headers
are left and others right (financial-print convention), the eye has to
re-orient at every column boundary. Centred-everywhere kills the cognitive tax.

```tsx
<th className="h-9 px-2.5 align-middle text-[10.5px] font-semibold uppercase
               tracking-[0.08em] text-muted-foreground whitespace-nowrap
               overflow-hidden text-center">
  {flexRender(header.column.columnDef.header, header.getContext())}
</th>
```

### Rule 2 — Cells centred by default

Numbers, currency, percentages, badges, icons, counts, codes, status pills,
short numerics — all centre. The cell content sits directly beneath the
column header on the same vertical centroid.

**This means right-alignment is BANNED.** The print-finance convention of
right-aligning numerics for decimal-point alignment doesn't translate to
modern dashboards — it creates a visible header-left + value-right gap that
non-finance users read as "messed up". Modern enterprise tables (Vercel
newer surfaces, Stripe newer dashboards, Linear) have moved to centre-default.

### Rule 3 — Long-text streams stay LEFT

These specific cell types stay left-aligned regardless of any other rule:

- Addresses (full street + locale)
- Names (owner name, assigned-to, submitter, contact name)
- Notes / descriptions (deal notes, match notes, inspection details)
- AI summaries (risk factors, opportunity flags, analysis summary)
- Dates rendered as text (submitted at, matched at, closing date)
- Free-text properties (creative terms type, seller motivation, condition)

**Why**: text wraps or truncates from the LEFT in most reading contexts. A
long string centred in a narrow cell creates ambiguous edge alignment when
truncation kicks in. Left-align matches reading order; truncation is honest.

The header on these columns still centres (Rule 1) — the visual disconnect
between centred header and left-aligned long content is preferable to the
ugly half-truncation a centred long string produces.

### Rule 4 — Right-alignment is forbidden

Even for currency, ARV, MAO, yield, ROI, NOI — all the financial columns where
print-tables right-align. Centre instead. This is the single rule that's
counter-conventional but ships cleaner UIs.

If you find yourself wanting to right-align "for decimal alignment", use
`tabular-nums` Tailwind class instead — that locks digit widths so the
numbers visually stack even when centred.

### Rule 5 — `inline-flex`, NOT `flex`, for cell content wrappers

Cell renderers that wrap content in a flex container (icon + value, badge +
chevron, count + indicator) MUST use `inline-flex` not `flex`.

**Why**: a block-level `flex` div takes up the full cell width, so its
children sit at `justify-content: flex-start` (left-aligned) regardless of
the parent cell's `text-align: center`. Switching to `inline-flex` makes
the wrapper itself an inline element, which then participates in the
parent's `text-align` and centres correctly.

```tsx
// ❌ Wrong — block-flex, content stays left-aligned
<div className="flex items-center gap-1.5">
  <Icon /> <span>{count}</span>
</div>

// ✅ Right — inline-flex, content centres under header
<div className="inline-flex items-center gap-1.5">
  <Icon /> <span>{count}</span>
</div>
```

This applies to BOTH cell renderers AND multi-child header wrappers (header
with title + info-tooltip icon).

### Rule 6 — Subtle vertical dividers, body rows ONLY

Body cells get a 15%-opacity right-border that drops on the last cell of each
row. Headers get NO dividers — the header row reads cleaner without them.

```tsx
// Body cell
<td className="px-2.5 py-2 ... border-r border-border/15 last:border-r-0 ...">

// Header cell — NO border-r class
<th className="h-9 px-2.5 ...">
```

**Why 15% opacity**: strong enough to give the eye a vertical track between
columns, faint enough to read as premium-quiet rather than data-dense.
Strict cell borders (full opacity) make tables feel like spreadsheet exports.

### Rule 7 — USPS Pub 28 address formatting + ordinal-aware title-casing

Any cell rendering an address (or a column with addresses inside a wider
display) runs the value through `formatStreetAddress()` which:

1. **Title-cases** the input with ALL-CAPS preserved only for state codes
   (AZ, GA, TX) + cardinal directions (N, S, E, W, NE, NW, SE, SW)
2. **Lowercases ordinal suffixes**: "42ND" → "42nd", "21ST" → "21st",
   "3RD" → "3rd", "100TH" → "100th"
3. **Re-capitalises Mc-names**: "MCCLELLAN" → "McClellan"
4. **Abbreviates verbose suffixes** to USPS Pub 28 standard:
   Street→St, Road→Rd, Avenue→Ave, Boulevard→Blvd, Drive→Dr, Lane→Ln,
   Court→Ct, Place→Pl, Circle→Cir, Trail→Trl, Highway→Hwy, Parkway→Pkwy,
   Terrace→Ter, Square→Sq, Plaza→Plz, Heights→Hts, Junction→Jct,
   Apartment→Apt, Suite→Ste, Building→Bldg, Floor→Fl

City and county also get title-cased (no abbreviation pass — they're
proper nouns).

Reference implementation: `src/lib/formatters.ts` in a SaaS app. Copy
verbatim into other agency projects — it's project-agnostic.

---

## Implementation Recipe

### Step 1 — Drop in the formatter helpers

Copy `src/lib/formatters.ts` from a SaaS app to the target project. The file
exports:

- `toTitleCase(str)` — title-case with state/direction preservation + ordinals
- `abbreviateStreetSuffix(str)` — USPS Pub 28 abbreviations
- `formatStreetAddress(str)` — composition of both (canonical street formatter)
- `formatAddress(street, city, state, zip)` — full address composition
- `getStreetLine({street_address, full_address})` — primary display
- `getLocaleLine({city, state, zip})` — secondary "City, ST 12345" line

Add the test file `formatters.test.ts` alongside — 29 lock-in tests cover the
canonical failure cases (ordinals, McNames, all-caps inputs, suffix mappings).

### Step 2 — Add the alignment helper to the table component

```typescript
type CellAlign = 'left' | 'center';

function getCellAlignment(
  columnId: string,
  meta: { align?: CellAlign } | undefined,
): CellAlign {
  if (meta?.align) return meta.align;

  // Long-text streams stay left
  if (
    /^(full_address|owner_name|assigned_to_name|submitter_name|deal_notes|match_notes|buyer_notes|notes)$/.test(columnId) ||
    /^(ai_(risk_factors|opportunity_flags|analysis_summary|risk_factor_summary)|creative_terms_type)$/.test(columnId) ||
    /^(seller_motivation|property_condition|access_instructions|inspection_details|additional_notes|response_text)$/.test(columnId) ||
    /^(submitted_at|matched_at|last_offer_at|email_sent_at|sent_at|viewed_at|responded_at)$/.test(columnId)
  ) {
    return 'left';
  }

  // Default centre
  return 'center';
}

const CELL_ALIGN_CLASS: Record<CellAlign, string> = {
  left: 'text-left',
  center: 'text-center',
};
```

Per-column override: `meta: { align: 'left' }` on a column def forces left.
Headers ignore the helper — they always centre.

### Step 3 — Apply in the cell + header render

```tsx
// Body cell
{row.getVisibleCells().map((cell) => {
  const align = getCellAlignment(cell.column.id, cell.column.columnDef.meta);
  return (
    <td className={cn(
      "px-2.5 py-2 text-[13px] text-foreground align-middle",
      "border-r border-border/15 last:border-r-0 overflow-hidden",
      CELL_ALIGN_CLASS[align],
      cell.column.id === 'full_address' ? 'whitespace-normal' : 'whitespace-nowrap truncate',
    )}>
      {flexRender(cell.column.columnDef.cell, cell.getContext())}
    </td>
  );
})}

// Header cell — always centred
{headerGroup.headers.map((header) => (
  <th className="h-9 px-2.5 align-middle text-[10.5px] font-semibold uppercase
                 tracking-[0.08em] text-muted-foreground whitespace-nowrap
                 overflow-hidden text-center">
    {flexRender(header.column.columnDef.header, header.getContext())}
  </th>
))}
```

### Step 4 — Sweep cell renderers for `flex` → `inline-flex`

Any column renderer that wraps content like:

```tsx
<div className="flex items-center gap-X">
  <Icon />
  <span>{value}</span>
</div>
```

Must become `inline-flex`. Without this, cells visibly left-align even
though the parent cell has `text-center`.

Same for header renderers with `<SortableHeader>` + `<InfoTip>` siblings.

### Step 5 — Apply formatters to address-bearing cell renderers

```tsx
// Address column
cell: ({ row }) => {
  const street = getStreetLine({
    street_address: row.original.street_address,
    full_address: row.original.full_address,
  });
  const locale = getLocaleLine({
    city: row.original.city,
    state: row.original.state,
    zip: row.original.zip,
  });
  return <div>{street}<div className="text-muted-foreground">{locale}</div></div>;
},

// City / County columns (title-case if data is mixed)
cell: ({ row }) => {
  const city = row.getValue('city') as string | null;
  return city ? <span>{toTitleCase(city)}</span> : <Dash />;
},
```

### Step 6 — Tighten column widths to content max-width

Don't size to header-label width. Size to the longest realistic cell content.
Examples from a SaaS app:

| Column | Old size | New size | Reasoning |
|---|---|---|---|
| State | 60-140 | 68 | "AZ" + sort arrow + filter chevron |
| ZIP | 70 | 64 | 5-digit numeric, tabular-nums |
| County | 120 | 108 | Longest county name ≈ 12 chars at 13px |
| City | 140 | 128 | Worst case "Lake Havasu City" / "Sahuarita" |

Width too narrow = header chrome (sort arrow, filter dropdown chevron) clips.
Width too wide = whitespace gap between header and cell content. Match
content to header-chrome — usually 60-130px for badges/codes/numbers,
100-160px for short text, 320px for full address.

---

## FEMA-Style Code-to-Label Pattern (for any classification field)

Many real-estate / business tables surface technical codes (FEMA flood zones,
property types, status codes, etc.) that are unreadable to non-experts.
Always map code → plain-English label + colour severity, with the technical
code in a tooltip for the user who needs it.

Reference: a SaaS app flood-zone column maps `X / B / C` → "Low Risk" green,
`A*` → "High Risk · AE" orange, `V*` → "Coastal · VE" red, `D` → "Pending"
grey, anything else → raw code with neutral pill. Tooltip carries the FEMA
zone description in plain English.

```tsx
const code = (raw ?? '').trim().toUpperCase();
let label, className, tooltip;
if (code === 'X' || code === 'B' || code === 'C') {
  label = 'Low Risk';
  className = 'border-emerald-500/40 text-emerald-600';
  tooltip = `Zone ${code} — minimal flood risk...`;
} else if (code.startsWith('V')) {
  label = `Coastal · ${code}`;
  className = 'border-red-500 text-red-500 font-semibold';
  tooltip = `Zone ${code} — coastal high risk...`;
}
// etc.
```

Filter out junk values (boolean leaks, "false", "null", "n/a", empty
strings) at the top — render `<Dash />` for those.

---

## Anti-Patterns

| Wrong | Why | Right |
|---|---|---|
| Right-aligning currency / percentages | Header-cell visual disconnect; reads "messed up" to non-finance users | Centre everything except long-text |
| Pattern-matching header alignment to cell alignment | Different alignments per column means the eye re-orients per column | All headers centred regardless |
| Using `flex` (block) for cell content wrappers | Block-level wrapper takes full cell width; children pin to flex-start | Use `inline-flex` so wrapper inherits text-align |
| Dividing header row with vertical lines | Header reads as caged / spreadsheet-export | Body rows only, 15% opacity |
| Sizing columns to header label width | Wastes space on short-content columns; clips on chrome-heavy ones | Size to content + chrome, not to label |
| Rendering "false" / "true" / "null" / "n/a" as cell text | Data-quality leak from upstream; shouldn't reach users | Filter junk values at top of cell renderer; render `<Dash />` |
| Using `border-border` (full opacity) for dividers | Reads as data-dense spreadsheet, not premium dashboard | `border-border/15` (15% opacity) |
| Letting "42ND" / "MCCLELLAN" / "TRAIL" reach the DOM | All-caps + verbose suffixes feel unprofessional | Run every address through `formatStreetAddress()` |
| One-off cell renderer per address column | Drift in formatting across columns | Centralised formatters in `src/lib/formatters.ts` |

---

## Validation Checklist

Before claiming a new table is "neat":

- [ ] Every header centred under its column midline
- [ ] No column right-aligned (zero exceptions)
- [ ] Long-text columns (addresses, names, notes) left-aligned in cells
- [ ] All cell content visually stacks under the header (header centroid =
      cell centroid)
- [ ] No `flex items-center` (block) inside cell renderers — all
      `inline-flex items-center`
- [ ] Subtle vertical dividers visible in body rows, NOT in header row
- [ ] Address strings use abbreviated USPS suffixes (Trl, St, Rd, Ave...)
- [ ] City + county names title-cased (no "PHOENIX" / "MIAMI-DADE")
- [ ] Numeric columns use `tabular-nums` for digit alignment
- [ ] Junk values (boolean leaks, empty strings, "n/a") render as `<Dash />`
- [ ] Technical codes (flood zone, property type, status) use plain-English
      labels with code in tooltip
- [ ] Column widths sized to content max + chrome (sort arrow, info icon),
      not to header label

---

## Related Files (a SaaS app reference implementation)

| File | Purpose |
|---|---|
| `src/lib/formatters.ts` | `toTitleCase`, `abbreviateStreetSuffix`, `formatStreetAddress`, `getStreetLine`, `getLocaleLine` |
| `src/lib/formatters.test.ts` | 29 lock-in tests for the formatter behaviour |
| `src/components/pipeline/DataTable.tsx` | `getCellAlignment` helper + cell/header render pattern |
| `src/components/pipeline/columns/columnDefs.tsx` | All column definitions using the patterns; flood-zone code-to-label example |

When porting to a new agency project, start with `formatters.ts` (drop-in,
zero changes) then adapt the alignment helper to the target project's
column-id naming.

---

## Companion Skills

- **brand-visual-identity** — palette tokens (orange / blue / teal), typography
  (Poppins headings, Lora body), size rules. Apply tokens to your table's
  colours and text sizes.
- **tailwind-shadcn-system** — CSS architecture, Tailwind v4 conventions,
  shadcn primitives. Use `<Badge>`, `<Tooltip>` from shadcn/ui.
- **design-review** — visual audit of running UI. Run after applying this
  skill to spot edge cases.
- **frontend-design** — production-grade UI principles. Composes with this
  skill for non-table surfaces.

---

*Skill version: 1.0 | Created 2026-05-03 from a SaaS app pipeline-table redesign.
Encoded preference — the model can write tables, but agency-quality tables
require these specific opinions.*
