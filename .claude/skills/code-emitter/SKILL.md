---
name: code-emitter
description: |
  The in-repo code topology emitter — the third M3 mapper. Reads a NewEarth entity's
  in-repo TypeScript / TSX source + Supabase edge functions READ-ONLY (via the
  Understand-Anything plugin's TreeSitterPlugin imported as a Node library — Path A,
  no npm install), transforms each file's structural analysis into Doctrine 05 §6.1
  canonical-shape ts_module + edge_function nodes + within-repo `imports` edges, and
  writes them via ONE bulk-write to the topology substrate (the Session-1 contract).
  Emits 2 node kinds — ts_module, edge_function — with the §6.5.1 typed attributes per
  kind plus honest extensions. Import paths are resolved (tsconfig `@/` alias + relative
  + extension order) to substrate ids; unresolved imports surface loud as synthetic
  `unresolved:<source>` targets, never silent-dropped. Marks `code` coverage covered
  (heartbeat) after a successful write; degenerate when UA is uninstalled.
  Use when: an operator wants to populate (or refresh) a project's in-repo code topology
  in the substrate; "/code-emit", "emit the code topology", "run the dependency mapper",
  "what TS files import module X", "what edge functions exist" (after a run); AND/OR
  after a code change / new file / refactor landed in the repo (P3 regenerate-not-edit).
  Do NOT use for: writing to the repo or the UA cache (read-only); computing
  reconciliation / drift (M4 scope); the in-repo n8n JSON walker / vercel.json /
  package.json (Session 5 scope); cross-substrate edges (ts_module → table / workflow;
  v1.1 / M4 scope); edge_function.deployed_commit (M4 vercel-deploy-state emitter);
  editing the substrate code (Session-1 contract is FROZEN — compose, do not
  reimplement); editing the supabase-live / n8n-cloud emitters (frozen reference patterns).
allowed-tools: Bash, Read
user-invocable: true
version: 1.0
classification: capability-uplift
created: 2026-05-26
programme: intent-actual-gap-mechanism
programme_session: M3-session-4-code-emitter-part-1
schema_authority: ../topology-substrate/references/canonical-shape.md
---

# Code Emitter — Part 1 (in-repo TypeScript + edge functions → topology substrate)

> **Programme**: Intent-Actual-Gap Mechanism Build Programme, M3 Session 4 of ~6.
> **The third M3 emitter**: opens the in-repo code half of v1. Pairs with Session-5's
> in-repo n8n JSON walker + `vercel.json` + `package.json` reader (the rest of the
> in-repo class). Doctrine 05 (topology-from-source) is the schema authority; §6.2 names
> this emitter; §6.5.1 fixes the per-kind attributes; Appendix C catalogues it as
> `dependency_cruiser`; A.13 names within-corpus dependency edges; A.15 names the
> deploy-drift signal (deferred to M4). The substrate's frozen contract lives in
> 📄 `../topology-substrate/references/canonical-shape.md` — read it before extending
> the shape.

## What this is

A Claude Code skill that reads a NewEarth entity's **in-repo TypeScript / TSX source
files + Supabase edge functions** and writes the application's actual code structure —
the modules, the edge functions, and the import dependency edges between them — into the
topology substrate as canonical-shape nodes. **READ-ONLY**: it imports the
Understand-Anything (UA) library to parse each file, reads file content + size, and never
writes to the repo or the UA cache.

One sentence: **the codebase describes its own import structure; this emitter translates
that into the substrate's canonical shape.**

## When to invoke

- A fresh repo / entity needs its in-repo code topology populated (first run).
- A code change, new file, deleted file, or refactor landed → re-run to refresh
  (P3 regenerate-not-edit; the emitter is idempotent and re-runnable).
- The health-check skill (M3 Session 6) sees `code` stale → operator re-runs.
- An operator asks "what imports module X" / "what edge functions exist" — the answer
  lives in the substrate; this emitter ensures it is current.

## What it emits (the §6.5.1 contract + honest extensions)

| kind | source | typed `attributes` (§6.5.1 base + honest extensions) | edges produced |
|---|---|---|---|
| `ts_module` | `src/**/*.{ts,tsx}` (excl. `*.d.ts`, `*.test.*`, `src/test/`) AND `supabase/functions/**/*.{ts,tsx}` that are NOT a `<name>/index.ts` (the `_shared/` helpers + per-function sub-modules — plain library code, not deployed functions) via UA | **§6.5.1 base**: `is_entry`, `export_count`. **Extensions**: `language`, `file_size_bytes`, `function_count`, `class_count`, `import_count`, `source_file_relpath` | `imports` (→ each resolved in-repo import target) |
| `edge_function` | `supabase/functions/<name>/index.ts` via UA (the deployed function entry) | **§6.5.1 base**: `runtime`, `deployed_commit`. **Extensions**: `function_name`, `source_file_relpath`, `function_count`, `import_count` | `imports` (→ each resolved in-repo import target) |

There are NO `contains` edges — TS modules are flat (not hierarchical like n8n workflows).
The only edge class this emitter produces is `imports`.

### Honest extensions — documented, not amendments

The §6.5.1 BASE contract is `{is_entry, export_count}` for ts_module and
`{runtime, deployed_commit}` for edge_function. This emitter ships **additive
extensions** — same discipline as Sessions 2 and 3. The extensions are optional,
downstream consumers can ignore them, and they pass the "honest extension" test:

| Extension | Why it earns its keep |
|---|---|
| `ts_module.language` | Distinguishes `.ts` (`"typescript"`) from `.tsx` (`"typescript-react"`) — downstream UI-vs-logic queries. UA collapses both to one extractor, so this label is OUR distinction derived from the file extension |
| `ts_module.file_size_bytes` | O(1) freshness signal the health-check skill reads without traversing the substrate |
| `ts_module.function_count` / `class_count` / `import_count` | Coarse complexity signals from UA's structural analysis |
| `ts_module.source_file_relpath` | Operator-readability — the substrate id is `repo:src/...`; humans read the path |
| `edge_function.function_name` | Operator-readability — the substrate id is `repo:supabase/functions/<name>` |
| `edge_function.source_file_relpath` | Mirrors ts_module discipline |
| `edge_function.function_count` / `import_count` | Coarse complexity signals |

### The base attributes — what `is_entry` and `deployed_commit` mean in v1

- **`ts_module.is_entry`**: `true` ONLY for `repo:src/main.tsx` (BuyBox-AI's known Vite
  entry, hard-coded as a v1 shortcut); `false` for every other module. Accurate
  entry-point inference needs `package.json` + `vite.config.ts` reading — that lands in
  Session 5; until then the single hard-coded entry is the honest v1 value (documented in
  "Known limitations").
- **`edge_function.deployed_commit`**: `null` in v1. The deploy state (which git commit is
  live on the Supabase Functions runtime) is NOT available from the filesystem — it needs a
  Vercel / Supabase Functions API integration, which is the M4 `vercel-deploy-state` emitter
  (one of the 5 declared-missing emitters). The A.15 Cedar-Hurst deploy-drift signal is
  therefore NOT closed by this session — it is closed at M4, which reads these
  `edge_function` nodes and populates `deployed_commit`. Shipped `null`, not silently
  dropped.

## How a run works (the orchestration)

A run is **driven by the invoking Claude session**: the session runs the Node extractor
driver (📄 `scripts/extract.mjs`) via `Bash`, captures its JSONL stdout, runs the frozen
jq transform (📄 `scripts/transform.jq`) to assemble canonical nodes + edges, writes the
two arrays to temp files, then shells the harness (📄 `scripts/emit.sh`). The harness is
the **finishing step** — it takes pre-collected JSON inputs and does the validate +
bulk-write + mark-ran + verify sequence in order. (Each individual `substrate.sh` call is
atomic via the substrate's per-call lock, but a large payload is written as a sequence of
chunked `bulk-write` calls — see "Scale ceiling" — so the multi-chunk emit as a whole is
NOT transactional; the heartbeat fires only after all chunks succeed.)

1. **Verify UA is installed** (Phase 0 — session-driven):
   ```bash
   test -f /Users/justin/.claude/plugins/cache/understand-anything/understand-anything/2.7.4/packages/core/dist/index.js
   ```
   If absent, do NOT run emit.sh; instead the **invoking session** marks the emitter
   degenerate directly:
   ```bash
   bash .claude/skills/topology-substrate/scripts/substrate.sh mark-emitter-ran code degenerate
   ```
   per Doctrine 05 P6 / §8.4 (source exists at the entity — the TS files — but the read
   library is unavailable). The harness emit.sh never writes `degenerate` — it is the
   session's responsibility when the source is unreadable. The extractor driver also
   exits `3` when it cannot import UA, so the session can detect this from the driver's
   exit code too.

2. **Verify the repo path** (Phase 0):
   ```bash
   test -d "$REPO_ROOT/src"
   ```
   If absent → halt with an operator message (wrong path).

3. **Run the extractor driver** (the data-source layer — the novel part):
   ```bash
   mkdir -p /tmp/code-emit
   node .claude/skills/code-emitter/scripts/extract.mjs "$REPO_ROOT" \
       > /tmp/code-emit/extracted.jsonl 2>/tmp/code-emit/extract.err
   ```
   One JSON record per file + a trailing `__diagnostics` footer line. See
   📄 `references/ua-library-integration.md` for the output contract.

4. **Compute provenance** (one git call, applied to all nodes):
   ```bash
   SRC_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
   [ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ] && SRC_COMMIT="${SRC_COMMIT}+dirty"
   ```
   In-repo files DO have a git commit (unlike the live MCP emitters) — honest by default.

5. **Assemble canonical-shape nodes + edges via the frozen jq transform**:
   ```bash
   jq -s '.' /tmp/code-emit/extracted.jsonl > /tmp/code-emit/records.json
   jq -n \
     --slurpfile records /tmp/code-emit/records.json \
     --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg src_commit "$SRC_COMMIT" \
     --argjson alias_map '{"@":"src"}' \
     -f .claude/skills/code-emitter/scripts/transform.jq \
     > /tmp/code-emit/combined.json
   jq '.nodes' /tmp/code-emit/combined.json > /tmp/code-emit/nodes.json
   jq '.edges' /tmp/code-emit/combined.json > /tmp/code-emit/edges.json
   ```
   `alias_map` is the tsconfig `paths` aliases as `{"<alias-prefix>": "<dir>"}`. For
   BuyBox-AI it is `{"@":"src"}` (the `@/*` → `./src/*` mapping). See
   📄 `references/ts-import-resolution.md` for the resolution algorithm.

6. **Run the harness**:
   ```bash
   TOPOLOGY_SUBSTRATE_PATH="$REPO_ROOT/.understand-anything/topology-graph.json" \
     bash .claude/skills/code-emitter/scripts/emit.sh \
       /tmp/code-emit/nodes.json /tmp/code-emit/edges.json "<entity>"
   ```
   The harness: validates the inputs are JSON arrays, calls `substrate.sh bulk-write` (ONE
   call below the chunk budget; chunked nodes-first-then-edges above it — see "Scale
   ceiling"), calls `substrate.sh mark-emitter-ran code covered`, then `substrate.sh
   validate-schema` (must return `PASS` as a complete line — anchored `^PASS$` match).

7. **Print the completeness diagnostic** (the operator's safety net): the transform
   writes a `.diagnostics` field to `combined.json` with the counters below. The harness
   (`emit.sh`) does NOT read combined.json — it is the **invoking session's
   responsibility** to print this block AFTER emit.sh exits 0:
   ```bash
   jq '.diagnostics' /tmp/code-emit/combined.json
   ```
   The counters: `ts_module_count`, `edge_function_count`, `ts_files_extractor_failed`,
   `imports_total`, `within_repo_edges_kept`, `external_imports_skipped`,
   `asset_imports_skipped`, `external_url_imports_skipped`, `unresolved_imports`,
   `entry_points_marked`. A non-zero `unresolved_imports` is an operator-actionable signal
   (a real import whose target file the resolver could not locate — usually a missing
   extension case or a non-`@/` alias). A non-zero `ts_files_extractor_failed` means a
   file UA could not parse (emitted as a §6.6 `manual` node). Silent omission of this step
   is a Doctrine 05 P6 ("declared coverage") breach.

> **One `bulk-write`, not a `write-node` loop.** At BuyBox-AI v1 scale (~831 ts_module +
> 82 edge_function nodes + several thousand imports edges) a `write-node` loop is O(N²);
> `bulk-write` is one lock + one map-derivation. The substrate SKILL.md mandates this.

## The schema gotcha — import resolution is the hard part

UA's structural analysis returns `imports[].source` (NOT `module`) — a string like
`"@/hooks/useAuth"`, `"./pages/Index"`, `"react"`, `"https://esm.sh/..."`, or
`"@/styles/x.css"`. The transform classifies each:

| Import source shape | Classification | Action |
|---|---|---|
| `@/<path>` (the tsconfig alias) | internal | alias-resolve `@` → `src`, then extension-resolve → emit `imports` edge |
| `./<path>` or `../<path>` (relative) | internal | resolve against the importing file's directory, then extension-resolve → emit `imports` edge |
| asset extension (`.css`/`.scss`/`.sass`/`.less`/`.svg`/`.png`/`.jpg`/`.jpeg`/`.gif`/`.webp`/`.json`/`.md`/`.txt`/`.woff`/`.woff2`/`.ttf`/`.eot`/`.ico`) | asset | skip; count `asset_imports_skipped` |
| `https://...` (Deno URL import) | external URL | skip; count `external_url_imports_skipped` |
| bare package (`react`, `@scope/pkg`, no `@/` prefix) | external npm | skip; count `external_imports_skipped` |
| resolves to nothing in the walked corpus | unresolved | emit synthetic `unresolved:<source>` target; count `unresolved_imports` |

**Extension resolution order** (matches TypeScript bundler resolution): for an internal
target `<base>`, try in order — `<base>` verbatim FIRST (handles sources that already carry
an extension, e.g. `./App.tsx`), then `<base>.ts`, `<base>.tsx`, `<base>/index.ts`,
`<base>/index.tsx`. The first that exists in the walked-file universe wins. (This matches
`transform.jq`'s `resolve_ext` array order and `references/ts-import-resolution.md`.)

**`@/` alias caveat**: the `@` prefix is BOTH the tsconfig alias (`@/...` → `src/...`) AND
the npm scoped-package marker (`@scope/pkg`). The classifier distinguishes them: `@/`
(slash immediately after) is the alias; `@scope/` (a name after the `@`) is an npm scope.
See 📄 `references/ts-import-resolution.md`.

If a resolvable-looking import (alias or relative) fails to resolve to a walked file, the
transform emits a synthetic `unresolved:<source>` target so the substrate's bulk-write
integrity check surfaces it loud, NOT silent-drop. The diagnostic counts these. Investigate
any non-zero count — usually a missing extension case or a non-`@/` alias the resolver
doesn't know.

## Provenance for in-repo rows (the easiest of any M3 emitter)

In-repo files DO have a git commit — unlike the live MCP emitters (Sessions 2 + 3) which
had to use declared live-provenance markers. So:

```
source_file:   "<repo-relative-path>"              (e.g. "src/hooks/useAuth.ts")
source_commit: "<git short SHA>"                   ("+dirty" appended if uncommitted changes)
source_line:   null                                 (file-level node; not usefully line-addressable)
emitter:       "dependency_cruiser"                 (the Appendix C catalogue name for this emitter)
timestamp:     "<ISO 8601 UTC of this run>"
```

This satisfies D05 P2 (every node traces to source) with the actual git commit — no
fabrication needed. The `+dirty` suffix is honest-by-default: an operator reading the
substrate sees the working tree had uncommitted changes at emit time.

## The repo: prefix discipline

This emitter writes ids prefixed `repo:`:
- `repo:<repo-relative-path>` for ts_module (e.g. `repo:src/hooks/useAuth.ts`)
- `repo:supabase/functions/<name>` for edge_function (e.g. `repo:supabase/functions/underwrite`)

Session-2's pg_depend emitter writes `public.<name>` (database objects); Session-3's n8n
cloud emitter writes `cloud:<id>` (live workflows); Session-5's in-repo n8n JSON walker
will write `repo:<workflow-path>` (the in-repo counterpart to Session 3's `cloud:`). The
distinct prefixes let all emitters' nodes coexist in the SAME substrate without id
collision, and let M4 reconciliation compare the `cloud:` vs `repo:` views of the same
workflow.

## Filtering decisions (LOCKED for v1 — documented per F4 anti-anchoring)

| Filter | Rule | Reason |
|---|---|---|
| TS scope | `src/**/*.ts` + `src/**/*.tsx` | The application source tree |
| Declaration files | `*.d.ts` excluded | Types-only; no runtime imports; no dependency signal |
| Test files | `*.test.ts` / `*.test.tsx` + `src/test/**` excluded | Not application code; if the operator wants tests later, a separate emitter run |
| Edge functions | `supabase/functions/<name>/index.ts` (one `edge_function` node per folder) | The Supabase Functions deployment convention; the `index.ts` IS the function |
| Edge-function helper modules | `supabase/functions/**/*.{ts,tsx}` that are NOT a `<name>/index.ts` → emitted as `ts_module` (incl. `supabase/functions/_shared/*.ts`) | They are plain TS library code (cors, logging, cost-rates, calculator helpers), not deployed functions. Modelling them as `ts_module` lets the functions' `../_shared/x.ts` imports resolve instead of surfacing as unresolved — empirically dropped unresolved imports from 112 to 0 on BuyBox-AI |
| External npm imports | NOT emitted as nodes; counted | We map in-repo code, not the dependency tree. Session 5 reads `package.json` if external deps are wanted as nodes |
| Asset imports (style/image/font/data extensions — see the full list in `references/ts-import-resolution.md`, the authority) | NOT emitted; counted | Assets are not code; the substrate kind enum has no asset kind |
| Deno URL imports (`https://...`) | NOT emitted; counted | External HTTP modules; out of in-repo scope |
| Cross-substrate edges (`ts_module → table` / `workflow` / `edge_function`) | NOT emitted v1 | The substrate CAN hold them; the inference logic is v1.1 / M4. The enablement exists; only the inference is deferred |
| Call-graph edges (function → function) | NOT emitted v1 | Would need a new `ts_function` kind in Doctrine 05; v1.1 if M4 reconciliation needs it |
| Multi-language (Python edge functions etc.) | NOT emitted v1 | UA supports 9 languages; BuyBox-AI edge functions are Deno TS only; v1.1 if entities adopt others |

## Propagation — how to rebind to a non-BuyBox-AI entity

When `/push-to-template` propagates this skill and another entity (Agency-Main, Nirvana)
runs `/update-latest`, the operator must:

1. **Confirm UA is installed** at the receiving entity (the cache path in
   📄 `references/ua-library-integration.md`). If UA is NOT installed, the emitter exits `3`
   and coverage stays `degenerate` — the operator installs the UA plugin first.
2. **Confirm the tsconfig alias map**. The `--argjson alias_map` passed to the transform
   must match the receiving repo's `tsconfig.json` `paths`. BuyBox-AI is `{"@":"src"}`;
   another repo may use a different alias prefix or a different source root. Read the
   receiving repo's `tsconfig.json` `compilerOptions.paths` at first run and build the map.
3. **Confirm the entity name** passed to `emit.sh` (third arg) matches the substrate's
   `entity` field.
4. If the receiving entity has NO TypeScript code (hypothetical for a non-TS entity), the
   emitter should NOT be run — the substrate's `code` slot stays `coverage: "absent"`
   (D05 §8.4 — the source type does not exist at this entity).

## Scale ceiling — SOLVED via harness chunking (v1)

The harness passes the assembled nodes + edges JSON via shell argv to `substrate.sh
bulk-write`. macOS `ARG_MAX` is ~1,048,576 bytes **total** across argv + environment — not
per-argument. At BuyBox-AI v1 scale the substrate's re-derived `depends_on` /
`depended_on_by` adjacency lists fatten the node array to ~1 MB on its own, and the edges
array adds ~700 KB, so a single `bulk-write "$(cat nodes)" "$(cat edges)"` call fails with
"Argument list too long".

`emit.sh` handles this automatically: it measures the combined payload, and when it exceeds
a 600 KB chunk budget it writes in **multiple `bulk-write` calls** — ALL node chunks first
(edges `[]`), THEN edge chunks (nodes `[]`). This is correct because `substrate.sh
bulk-write` is idempotent (nodes upsert by id; edges dedupe by `(source,target,type)`), so a
sequence of sub-cap calls reaches the identical end state as one big call. The node chunks
land first so that every node referenced by an edge exists before the edge-endpoint
integrity check runs. Below the budget, the single-call fast-path is used (smaller repos,
the eval fixtures).

This was the forcing function Sessions 2 and 3 flagged as a future ceiling. The fix lives
entirely in `emit.sh` — the frozen `substrate.sh` is NOT modified (a `bulk-write-stdin`
substrate variant would be a cleaner long-term answer, but chunking through the existing
helper keeps the Session-1 contract frozen). See "Known limitations" #7.

## Known limitations (v1, documented honestly)

1. **`is_entry` is a single hard-coded value.** Only `repo:src/main.tsx` is marked
   `is_entry: true`; everything else is `false`. Accurate entry-point inference needs
   `package.json` + `vite.config.ts` reading (Session 5). The hard-code is the honest v1
   shortcut for BuyBox-AI's known Vite entry. A non-BuyBox entity with a different entry
   filename gets NO entry marked until the propagation step updates the hard-code or
   Session 5 lands.
2. **`edge_function.deployed_commit` is always `null` in v1.** The deploy state is an M4
   `vercel-deploy-state` integration. The A.15 deploy-drift signal is enabled (the node
   exists with the field) but not populated until M4.
3. **No cross-substrate edges.** `ts_module → table` (a hook querying a Supabase view),
   `ts_module → workflow` (a file calling an n8n webhook), `ts_module → edge_function` (a
   `supabase.functions.invoke()` call) are NOT inferred in v1. The substrate can hold
   them; the string-pattern inference is v1.1 / M4. Deferred, not dropped.
4. **No call-graph below `ts_module`.** UA produces per-file `functions`; cross-file call
   edges between functions are not emitted. Would need a `ts_function` kind (Doctrine 05
   amendment). v1.1 if M4 needs it.
5. **Import resolution is path-only.** A barrel re-export (`export * from './x'`) is
   recorded as an import edge to `./x` but the transitive re-exported symbols are not
   traced. The dependency edge is correct; the symbol-level granularity is not modelled.
6. **`function_count` / `class_count` are UA's counts.** They reflect UA's parser's view
   (top-level functions + classes); nested / arrow / anonymous functions may not all be
   counted. Coarse complexity signal, not an exact AST census.
7. **Chunked write is sequential, not transactional.** When the payload exceeds the chunk
   budget, `emit.sh` issues several `bulk-write` calls. If a later chunk fails (e.g. a
   transient lock-contention), earlier chunks have already landed — the substrate is in a
   partial state, NOT rolled back. The harness exits nonzero so the operator knows; a re-run
   is idempotent (nodes upsert, edges dedupe) and converges to the complete state. The
   heartbeat (`mark-emitter-ran code covered`) only fires after ALL chunks succeed, so a
   partial write never falsely shows `covered`. A fully-transactional multi-chunk write would
   need a substrate-level `bulk-write-stdin` (deferred — the Session-1 contract is frozen).

## Composition map

| Composes with | How |
|---|---|
| `topology-substrate` skill (Session 1) | Calls `init` / `bulk-write` / `mark-emitter-ran` / `validate-schema` / `read-topology` via `substrate.sh`. **NEVER** edits substrate code. If a substrate bug surfaces, file it — do not patch here. |
| `supabase-live-emitter` skill (Session 2) | NEVER edits it. References it as a worked pattern. Both write to the SAME substrate; nodes coexist via prefix discipline (`public.X` vs `repo:src/Y.ts`). |
| `n8n-cloud-emitter` skill (Session 3) | NEVER edits it. References it as the MOST RECENT worked pattern (the driver → transform → harness shape this skill mirrors). |
| Understand-Anything plugin (cache path) | Imports `dist/index.js` → `TreeSitterPlugin` as a Node library (Path A). Reads UA's pre-built `dist/` + bundled `web-tree-sitter` WASM grammars. **NEVER** patches the UA cache. |
| The receiving repo's `tsconfig.json` | Read once (by the operator) for the `paths` aliases → the `alias_map` passed to the transform. |
| Goal-ledger (`.claude/goals/`) | OPTIONAL v1.1: an emit run could append a "code topology emitted for entity X at T" row via `goals.sh`. Out of scope for v1 unless trivial. |

## What this skill must NOT do (the no-go list)

- Author intent (Doctrine 04) or compute drift (Doctrine 06) — emits the actual side only.
- Edit `substrate.sh` / the substrate schema / Doctrines 04/05/06 — frozen contracts.
- Edit the Session-2 / Session-3 emitter skills — frozen reference patterns.
- Add Doctrine 06's 17 reconciliation fields per node — the load-bearing finding
  (collapses three-way separability).
- Write to the repo. Write to the UA plugin cache. (Both read-only.)
- Loop `write-node` (use `bulk-write`).
- Leave the provenance envelope empty (validate-schema requires it).
- Defend a schema choice on "industry does this" (F4 — M1 falsifier proved no precedent).
- Silent-drop an import that looks resolvable — surface it loud with the synthetic
  `unresolved:<source>` target so the substrate's integrity check catches it.
- Emit external npm / Deno-URL / asset imports as substrate nodes.
- Populate `edge_function.deployed_commit` (M4 scope) or emit cross-substrate edges (v1.1).

## Attribution

This emitter imports the **Understand-Anything** library as a Node dependency (Path A —
the spec 14 §4.1 decision: "import as Node library; keep UA's strongest contribution — the
tested multi-language deep AST extractor — and drop UA's failing graph assembler + the
Python dependency").

- **Library**: `@understand-anything/core` (the core package inside the
  `understand-anything` Claude Code plugin, plugin version 2.7.4, core package version
  0.1.0).
- **Used surface**: `TreeSitterPlugin` (default config auto-loads TypeScript + TSX +
  JavaScript `web-tree-sitter` WASM grammars) → `analyzeFile(path, content)` →
  `StructuralAnalysis` (`{functions, classes, imports, exports}`).
- **License**: MIT (per spec 14 §4.1). The library is imported in-place from the operator's
  installed plugin cache; it is NOT copied into this skill, so the upstream license remains
  the authority.
- **Cache path** (env-overridable via `UA_PLUGIN_DIST`): the dist entry inside the
  installed `understand-anything` plugin's `2.7.4` core package — see
  📄 `references/ua-library-integration.md` for the exact path.

## Concurrency model

This emitter inherits the substrate's atomic write discipline — the substrate's whole-file
`mkdir` lock guarantees a parallel session running a different emitter never corrupts the
substrate. The emitter itself takes no additional lock; all atomicity is in `substrate.sh`.

## Exit codes (the harness)

`emit.sh` returns:
- `0` ok — `bulk-write` + `mark-emitter-ran` + `validate-schema` PASS
- `2` usage / bad-arg / inputs not JSON arrays
- `4` substrate not initialised AND init failed
- `6` `bulk-write` / `mark-emitter-ran` / `validate-schema` failed (inner stderr explains)

The extractor driver (`extract.mjs`) returns:
- `0` ok — JSONL emitted (check `__diagnostics.extractor_failed` for per-file parse issues)
- `2` usage / repo-root missing `src/`
- `3` UA plugin not importable → the session marks coverage `degenerate`

## References

- 📄 `../topology-substrate/references/canonical-shape.md` — the frozen schema (read first)
- 📄 `../topology-substrate/SKILL.md` — the helper API + bulk-write mandate
- 📄 `../n8n-cloud-emitter/` — Session 3 worked pattern (the shape this skill mirrors)
- 📄 `../supabase-live-emitter/` — Session 2 worked pattern (a second reference shape)
- 📄 `references/ua-library-integration.md` — the UA cache path + TreeSitterPlugin contract
  + the extractor driver's JSONL output shape
- 📄 `references/ts-import-resolution.md` — alias + relative + extension-order resolution
- 📄 `scripts/extract.mjs` — the Node driver (the data-source layer; the novel part)
- 📄 `scripts/transform.jq` — the frozen one-pass jq transform from JSONL → canonical nodes/edges
- 📄 `scripts/emit.sh` — the finishing harness (validate + bulk-write + mark-ran + verify)
- `docs/operational-doctrine/05_topology-from-source.md` — §6.2 (this emitter), §6.5.1
  (per-kind contract), §6.6 (source-orphan rule), Appendix C (the `dependency_cruiser`
  catalogue row), A.13 (within-corpus edges), A.15 (deploy-drift signal — deferred to M4)
- `specs/14_NEWEARTH_MASTER_BLUEPRINT_BUILD_PLAN.md` — §4.1 (UA as library), §4.5 (UA status
  after M3), §5 (sequence)
- `.claude/rules/intent-actual-gap-mechanism-alignment.md` — the programme contract
