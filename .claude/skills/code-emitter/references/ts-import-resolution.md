# TS Import Resolution — how the transform maps `imports[].source` to substrate ids

> M3 Session 4. The transform (`scripts/transform.jq`) consumes each file's
> `analysis.imports[].source` string and decides: emit an `imports` edge to an in-repo
> substrate id, OR skip-and-count (external / asset / Deno URL), OR surface-loud as an
> `unresolved:<source>` synthetic edge. This document is the algorithm.

## The five classes of import source

UA returns `imports[].source` as a raw string from the source file. Each is classified:

| Class | Detection | Action |
|---|---|---|
| **alias** | starts with `<alias>/` where `<alias>` is a key in `alias_map` (my-project: `@`) AND the char after the alias is `/` | resolve `<alias>` → its dir, extension-resolve, emit `imports` edge |
| **relative** | starts with `./` or `../` | resolve against the importing file's directory, extension-resolve, emit `imports` edge |
| **asset** | the source ends in any of `.css`, `.scss`, `.sass`, `.less`, `.svg`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.json`, `.md`, `.txt`, `.woff`, `.woff2`, `.ttf`, `.eot`, `.ico` (this list is the authority — matches `transform.jq` `is_asset`) | skip; count `asset_imports_skipped` |
| **external URL** | starts with `http://` or `https://` (Deno-style) | skip; count `external_url_imports_skipped` |
| **external npm** | anything else (bare package `react`, scoped `@scope/pkg`) | skip; count `external_imports_skipped` |

### The `@` ambiguity (load-bearing)

The `@` character is BOTH the tsconfig path alias prefix (`@/hooks/x` → `src/hooks/x`) AND
the npm scoped-package marker (`@tanstack/react-query`, `@supabase/supabase-js`). They are
distinguished by the character immediately after `@`:

- `@/...` — slash right after `@` → the alias (internal).
- `@<name>/...` — a name after `@` → an npm scope (external).

The transform's alias check is: for each `<alias>` key in `alias_map`, test whether
`source == <alias>` (bare) OR `source` starts with `<alias> + "/"`. For my-project's
`{"@":"src"}`, only `@/...` matches; `@tanstack/...` does NOT (the alias key is `@`, and
`@tanstack` does not start with `@/`). Correct by construction.

## Alias resolution

Given `alias_map = {"@": "src"}` and an import source `@/hooks/useAuth`:

1. Strip the alias prefix: `@/hooks/useAuth` → the alias is `@`, the remainder is
   `hooks/useAuth`.
2. Prepend the alias's mapped dir: `src` + `/` + `hooks/useAuth` = `src/hooks/useAuth`.
3. This is the **base path** (no extension yet) — pass to extension resolution.

For a multi-alias repo (some entities), `alias_map` carries multiple keys; the transform
tries each, longest-key-first, to avoid a short alias shadowing a longer one.

## Relative resolution

Given an importing file `src/main.tsx` and an import source `./App`:

1. Take the importing file's directory: `dirname("src/main.tsx")` = `src`.
2. Join with the relative source: normalise `src` + `/` + `./App` = `src/App`.
3. For `../`, pop one directory level per `../` segment. e.g. importing
   `src/components/pipeline/X.tsx` with `../../lib/y` → `src/lib/y`.
4. This is the **base path** — pass to extension resolution.

The transform implements path normalisation in jq (split on `/`, fold `.`/`..` segments).

## Extension resolution (matches the TS bundler order)

Given a **base path** (no guaranteed extension), try in order against the walked-file
universe (`path_to_id` — the set of every emitted node's `source_file_relpath`):

1. `<base>` verbatim — handles sources that already carry an extension (`./App.tsx`).
2. `<base>.ts`
3. `<base>.tsx`
4. `<base>/index.ts`
5. `<base>/index.tsx`

The FIRST that exists in `path_to_id` wins → its substrate id (`repo:<that-path>`) is the
edge target. If NONE exist → the import is **unresolved**.

> Note: an import that already ends in an asset extension was classified `asset` and never
> reaches extension resolution. An import ending in `.ts`/`.tsx` (e.g. a Deno
> `../_shared/x.ts`) is tried verbatim first (step 1).

## Unresolved imports — surface loud, never silent-drop

If an **alias** or **relative** import (something that SHOULD resolve to an in-repo file)
does not match any walked file, the transform emits a synthetic edge:

```json
{ "source": "repo:<importing-file>", "target": "unresolved:<original-source>",
  "type": "imports", "direction": "forward", "weight": 1 }
```

The substrate's `bulk-write` integrity check would reject this edge (the `unresolved:...`
target is not a node) — so the transform's idset filter DROPS it before the write, but
COUNTS it in `unresolved_imports`. This mirrors Session 3's connection-name discipline:
the count is the operator-actionable signal. A non-zero `unresolved_imports` means a real
import the resolver could not place — usually:

- a non-`@/` tsconfig alias the `alias_map` doesn't know (fix: add it to `alias_map`),
- a file extension the resolver doesn't try (e.g. `.mts` / `.cts` — rare),
- a genuinely broken import in the source (a real catalogue bug worth fixing).

External (npm / Deno URL / asset) imports are NOT counted as unresolved — they are
expected-to-be-external and counted separately. Only alias/relative misses are
"unresolved".

## Why edge endpoints always resolve to walked files

Every `imports` edge target is an in-repo file that the driver walked → it has a node in
the same `bulk-write`. The substrate rejects dangling edges (rc 6); the transform's idset
filter guarantees both endpoints exist before the write. An import to a file OUTSIDE the
walked scope (e.g. a `.d.ts` that was excluded, or a config file outside `src/`) resolves
to nothing in `path_to_id` and is therefore counted `unresolved` — honestly surfaced, not
silently emitted as a dangling edge.

## Worked examples (from the live my-project smoke test)

| Importing file | `imports[].source` | Class | Resolved target id |
|---|---|---|---|
| `src/App.tsx` | `@/hooks/useAuth` | alias | `repo:src/hooks/useAuth.ts` (or `.tsx`) |
| `src/App.tsx` | `./pages/Index` | relative | `repo:src/pages/Index.tsx` (extension-resolved) |
| `src/App.tsx` | `react` | external npm | (skipped, counted) |
| `src/App.tsx` | `@tanstack/react-query` | external npm | (skipped — `@tanstack` ≠ `@/`) |
| `src/App.tsx` | `@/styles/GuidedTourStyles.css` | asset | (skipped, counted) |
| `src/main.tsx` | `./App.tsx` | relative | `repo:src/App.tsx` (verbatim, step 1) |
| `supabase/functions/X/index.ts` | `https://esm.sh/@supabase/supabase-js@2` | external URL | (skipped, counted) |
| `supabase/functions/X/index.ts` | `../_shared/api-configs.ts` | relative | `repo:supabase/functions/_shared/api-configs.ts` (the `_shared` helpers ARE walked as ts_module nodes; verbatim `.ts` match, step 1) |
