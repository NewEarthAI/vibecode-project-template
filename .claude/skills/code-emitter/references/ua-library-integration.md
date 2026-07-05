# UA Library Integration — the data-source layer contract

> M3 Session 4. This document is the contract between the extractor driver
> (`scripts/extract.mjs`) and the transform (`scripts/transform.jq`). It is the
> code-emitter analogue of the n8n-cloud emitter's `references/n8n-workflow-shape.md`.

## License attribution + dependency provenance (spec 14 §6 line 167 gate)

> Added M3 Session 6 to satisfy the integration gate "confirm UA's MIT license attribution is present;
> confirm no Python dependency leaks into the code emitter" (spec 14 §6 line 167). The check is honest:
> it records the ACTUAL license status, not an assumed one.

- **UA license status (verified 2026-06-01)**: the Understand-Anything plugin's own
  `package.json` (`@understand-anything/skill@2.7.4`) declares `license: null` — UA does **NOT** declare
  an MIT licence at its package root. The spec's "MIT" assumption is therefore **not confirmed**; UA is
  used as an **in-place library import from the operator's own installed plugin cache** (Path A — no
  redistribution, no npm publish, no copy into this skill). The code-emitter does not vendor, fork, or
  re-license UA; it imports the operator's already-installed copy at runtime. If UA's licence is later
  clarified upstream, update this note.
- **No Python dependency**: the extractor (`scripts/extract.mjs`) imports ONLY Node built-ins
  (`node:fs/promises`, `node:path`) plus UA's own `web-tree-sitter` (WASM, bundled by UA). There is **zero
  Python** in the code-emitter's runtime path — confirmed by the extractor's import list (Node-only) and
  the skill's `allowed-tools: Bash, Read` (no Python interpreter invoked).

## The library — Understand-Anything, imported as a Node library (Path A)

The emitter imports the Understand-Anything (UA) plugin's core package **in-place** from
the operator's installed plugin cache. No npm install; no copy into the skill.

- **UA dist entry** (env-overridable via `UA_PLUGIN_DIST`):
  `/Users/justin/.claude/plugins/cache/understand-anything/understand-anything/2.7.4/packages/core/dist/index.js`
- **Exported symbol used**: `TreeSitterPlugin` (the high-level config-driven plugin).
- **Bundled grammars**: UA ships its own `web-tree-sitter` (WASM) + the
  `tree-sitter-typescript` / `tree-sitter-tsx` / `tree-sitter-javascript` WASM grammars
  inside its own `node_modules/`. No external tree-sitter install is required.

### The call sequence (what `extract.mjs` does)

```js
const { TreeSitterPlugin } = await import(UA_DIST);
const plugin = new TreeSitterPlugin();   // default config -> TS + TSX + JS auto-loaded
await plugin.init();                      // loads the WASM grammars (async, once)
const analysis = plugin.analyzeFile(absPath, content);  // sync; returns StructuralAnalysis
```

`new TreeSitterPlugin()` with NO config args takes UA's legacy-fallback branch, which
loads the TypeScript + TSX + JavaScript grammars directly — exactly the set this emitter
needs. `init()` is async and must be awaited once before any `analyzeFile` call.

### `StructuralAnalysis` — UA's actual return shape (verified live 2026-05-26)

```ts
interface StructuralAnalysis {
  functions: Array<{ name: string; lineRange: [number, number]; params: string[]; returnType?: string }>;
  classes:   Array<{ name: string; lineRange: [number, number]; methods: string[]; properties: string[] }>;
  imports:   Array<{ source: string; specifiers: string[]; lineNumber: number }>;
  exports:   Array<{ name: string; lineNumber: number; isDefault?: boolean }>;
  // ...optional non-code fields (sections/definitions/services/...) — unused here
}
```

**Field-name gotchas** (the continuation hinted different names — these are the live truth):
- imports use **`source`** (the module string), NOT `module`. There is no `kind` field.
- exports use **`name`** + `lineNumber` + optional `isDefault`. There is no `kind` field.
- `.tsx` and `.ts` both go through the same extractor; UA returns no language label —
  the driver derives `language` from the file extension itself.

`analyzeFile` never throws on a parse miss — it returns empty arrays. The driver still
wraps it in try/catch in case a future UA version throws, and on any read/parse error
emits the record with an `extractor_error` field set.

## The driver's output — JSONL (the transform's input contract)

`extract.mjs` writes one JSON object per line to stdout, then a trailing diagnostics line.

### Per-file record

```json
{
  "kind": "ts_module" | "edge_function",
  "rel_path": "<repo-relative path, forward-slashed>",
  "byte_size": 4231,
  "language": "typescript" | "typescript-react",
  "analysis": {
    "functions": [ { "name": "...", "lineRange": [a,b], "params": [...] }, ... ],
    "classes":   [ ... ],
    "imports":   [ { "source": "@/hooks/useAuth", "specifiers": ["AuthProvider"], "lineNumber": 15 }, ... ],
    "exports":   [ { "name": "useFoo", "lineNumber": 23, "isDefault": false }, ... ]
  },
  "supabase_calls": [ { "call": "from"|"invoke", "op": "read"|"write", "dynamic": false, "literal": "deals", "line": 12 }, ... ],
  "fetch_calls":    [ { "url": "https://api.openai.com/v1/...", "method": "GET", "dynamic": false, "line": 18 }, ... ],
  "extractor_error": "<message>"      // PRESENT ONLY on read/parse failure; absent otherwise
}
```

- `kind` is `ts_module` for files under `src/`, `edge_function` for
  `supabase/functions/<name>/index.ts`.
- `supabase_calls` / `fetch_calls` are the cross-system call scans (visual layer): supabase client
  `.from` / `.functions.invoke` member calls (R4-gated to a bound client) and bare global `fetch()` calls.
  The transform routes them to cross-system edges + `external_endpoint` nodes; a dynamic / unparseable
  target → a `blind-spot` (never dropped, never green). Both default to `[]` when absent.
- `rel_path` is relative to the repo root, always forward-slashed (works on macOS + Linux).
- `language` is the driver's own label: `.tsx` → `"typescript-react"`, `.ts` →
  `"typescript"`.
- `extractor_error` is present ONLY when the file could not be read or UA threw. The
  transform converts any record with `extractor_error` into a §6.6 source-orphan node
  (`emitter: "manual"` + `manual_justification`).

### Trailing diagnostics footer (the LAST line)

```json
{ "__diagnostics": { "walked": 913, "parsed": 911, "extractor_failed": 2,
                     "ts_module_count": 831, "edge_function_count": 82 } }
```

The transform DROPS any record carrying `__diagnostics` (it is the driver's own count, not
a file record). The transform recomputes its own richer diagnostics block.

## Scope (what the driver walks)

- **ts_module**:
  - `<repo>/src/**/*.ts` + `<repo>/src/**/*.tsx`, EXCLUDING `*.d.ts`, `*.test.ts`,
    `*.test.tsx`, and anything under `src/test/`.
  - `<repo>/supabase/functions/**/*.{ts,tsx}` that are NOT a `<name>/index.ts` — the
    `_shared/` helpers + per-function sub-modules. These are plain TS library code, not
    deployed functions, so they are `ts_module` (which also lets the functions'
    `../_shared/x.ts` imports resolve to real ids). Same `*.d.ts` / `*.test.*` exclusion.
  - `node_modules`, `.git`, `dist` dirs are skipped defensively.
- **edge_function**: `<repo>/supabase/functions/**/index.ts` (one record per `index.ts` —
  the deployed function entry).

## Read-only guarantee

The driver imports UA (no writes), and reads `stat` + file content. It writes ONLY to its
own stdout. It never writes to the repo or the UA cache. The skill's `allowed-tools` is
`Bash, Read` — no Write, no MCP.

## Exit codes

- `0` ok — JSONL emitted. Inspect `__diagnostics.extractor_failed` for per-file issues.
- `2` usage / `<repo-root>/src` missing.
- `3` UA plugin not importable (missing dist or WASM init failure). The invoking session
  maps this to `mark-emitter-ran code degenerate` per Doctrine 05 P6.

## Env knobs

- `UA_PLUGIN_DIST` — override the UA dist entry path (default = the installed 2.7.4 cache).
  Used by the eval to point at the same installed UA, and by propagation if a receiving
  entity has UA at a different cache version.
- `CODE_EMITTER_DEBUG=1` — verbose per-file progress to stderr.
