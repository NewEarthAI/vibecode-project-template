# Surface Map — diff → user-facing-surface registry  (TEMPLATE SKELETON — customise per project)

This is the **static fallback** the `production-readiness-review` skill uses to answer *"which
logged-in screens does this change touch?"* when a topology map is absent or stale (absent by
default, so the registry is the normal path, not the exception).

> **This is a generic skeleton.** Replace the example `MAP` rules below with your project's real
> surfaces + journeys (defined in `JOURNEYS.md`). The `EXEMPT` block is already project-agnostic —
> keep it. When you change the `MAP` rules, update the matching fixture in
> `scripts/map-diff-to-surfaces.sh` `run_selftest()` so `--self-test` stays green.

`scripts/map-diff-to-surfaces.sh` parses the fenced `RULES` block below. Each changed file is
classified into exactly one bucket, **EXEMPT checked first** so a test/doc under a mapped directory
is correctly exempt rather than counted as a gap:

- **MAP** `<glob> <journey[,journey...]>` — drive these journeys.
- **EXEMPT** `<glob>` — non-UI by nature; no browser surface expected (not a coverage gap).
- anything matching neither → **UNMAPPED** → a genuine coverage gap → the verdict goes **AMBER**.

Rule syntax (whitespace-separated, one per line, `#` starts a trailing comment):
- glob `**` = recursive (any depth), `*` = one path segment.
- journeys are comma-separated **with no spaces** (`a,b,c`). Journey step definitions live in
  `JOURNEYS.md`.

**Honest-degradation contract:** a backend file with no browser surface (token minter, webhook
handler, extractor) is deliberately left UNMAPPED → AMBER, NOT faked green. A browser smoke genuinely
cannot verify those; AMBER tells the operator "this change needs non-browser verification." Migrations
are EXEMPT because the **DB-storm check** (skill Phase 4), not the browser, is their witness.

To extend: add a `MAP` row when a new surface ships, or an `EXEMPT` row for a new non-UI file class.
Keep journeys the skill can actually drive — over-claiming a journey it can't reach produces a false
RED, which erodes trust faster than an honest AMBER.

<!-- RULES:START -->
# --- MAP rules: EXAMPLES — replace with your project's real surfaces + journeys ---
MAP    src/pages/**                  home          # every top-level page -> the 'home' smoke (example)
MAP    src/components/auth/**         login         # auth UI -> the 'login' journey (example)
MAP    src/App.tsx                    home          # app-wide routing/config -> broad smoke (example)

# --- EXEMPT: non-UI by nature, no browser surface (checked FIRST) — project-agnostic, keep as-is ---
EXEMPT **/*.test.ts
EXEMPT **/*.test.tsx
EXEMPT **/*.spec.ts
EXEMPT **/*.spec.tsx
EXEMPT **/__tests__/**
EXEMPT **/*.stories.tsx
EXEMPT tests/**
EXEMPT playwright/**
EXEMPT docs/**
EXEMPT *.md
EXEMPT **/*.md
EXEMPT .claude/**
EXEMPT .github/**
EXEMPT migrations/**                   # DB-layer -> DB-storm check (skill Phase 4) is the witness
EXEMPT supabase/migrations/**
EXEMPT specs/**
EXEMPT continuations/**
<!-- RULES:END -->
