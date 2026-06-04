#!/usr/bin/env node
// code-emitter/scripts/extract.mjs — the Node driver for the in-repo TypeScript code emitter.
//
// Intent-Actual-Gap Mechanism Build Programme, M3 Session 4. The genuinely novel artefact:
// Sessions 2 + 3 had a Claude-session-runs-MCP-and-pipes-to-jq data-source layer; this session
// has a Claude-session-runs-Node-driver-that-imports-Understand-Anything (UA) data-source layer.
//
// What it does:
//   - Imports UA's TreeSitterPlugin from the installed plugin cache (Path A — no npm install).
//   - Walks <repo-root>/src for *.ts / *.tsx (excludes *.d.ts, *.test.ts[x], src/test/).
//   - Walks <repo-root>/supabase/functions/<name>/index.ts (one per edge function folder).
//   - Per file: byte size + UA structural analysis (functions, classes, imports, exports).
//   - Emits one JSON object per line (JSONL) to stdout, plus a trailing __diagnostics footer.
//
// READ-ONLY: imports UA's library (no writes), reads stat + content. Never writes to the repo
// or the UA cache. The transform (transform.jq) consumes the JSONL; the harness (emit.sh) writes
// the substrate.
//
// Output contract (documented in references/ua-library-integration.md):
//   {"kind":"ts_module"|"edge_function","rel_path":"<repo-relative>","byte_size":N,
//    "language":"typescript"|"typescript-react","analysis":{functions,classes,imports,exports},
//    "extractor_error":"<msg>"?}                 // extractor_error present ONLY on parse failure
//   {"__diagnostics":{walked,parsed,extractor_failed,ts_module_count,edge_function_count}}  // last line
//
// Usage:  node extract.mjs <repo-root>
// Env:    UA_PLUGIN_DIST  override the UA dist entry path (default = the installed 2.7.4 cache)
//         CODE_EMITTER_DEBUG=1  verbose stderr progress
//
// Exit codes:
//   0  ok (JSONL emitted; check __diagnostics.extractor_failed for per-file parse issues)
//   2  usage / repo-root missing src/
//   3  UA plugin not importable (the harness maps this to coverage: "degenerate")

import { readdir, readFile, stat } from "node:fs/promises";
import { join, relative, extname, sep } from "node:path";

const DEBUG = process.env.CODE_EMITTER_DEBUG === "1";
const dbg = (...a) => { if (DEBUG) console.error("[extract]", ...a); };

const DEFAULT_UA_DIST =
  "/Users/justin/.claude/plugins/cache/understand-anything/understand-anything/2.7.4/packages/core/dist/index.js";
const UA_DIST = process.env.UA_PLUGIN_DIST || DEFAULT_UA_DIST;

const repoRoot = process.argv[2];
if (!repoRoot) {
  console.error("extract.mjs: usage: node extract.mjs <repo-root>");
  process.exit(2);
}

// --- precondition: the repo has a src/ tree ---------------------------------------
let srcStat;
try {
  srcStat = await stat(join(repoRoot, "src"));
} catch {
  console.error(`extract.mjs: ${join(repoRoot, "src")} not found — refuse to proceed`);
  process.exit(2);
}
if (!srcStat.isDirectory()) {
  console.error(`extract.mjs: ${join(repoRoot, "src")} is not a directory`);
  process.exit(2);
}

// --- import UA's TreeSitterPlugin (Path A) ----------------------------------------
// Surface a loud warning when the cache path is overridden — a mis-set UA_PLUGIN_DIST
// (or a hostile env injecting it) would import-and-execute whatever it points at. For
// local dev tooling this is acceptable, but the operator should SEE the override.
if (process.env.UA_PLUGIN_DIST) {
  console.error(`[extract] WARNING: UA_PLUGIN_DIST override active — importing UA from: ${UA_DIST}`);
}

let TreeSitterPlugin;
try {
  ({ TreeSitterPlugin } = await import(UA_DIST));
} catch (e) {
  console.error(
    `extract.mjs: could not import Understand-Anything from ${UA_DIST}\n` +
    `  The UA plugin is not installed or its dist/ is missing. The harness should mark\n` +
    `  the 'code' emitter coverage as "degenerate" (source exists at the entity but the\n` +
    `  read library is unavailable). Underlying error: ${e && e.message}`
  );
  process.exit(3);
}

let plugin;
try {
  plugin = new TreeSitterPlugin(); // default config -> auto-loads TS + TSX + JS grammars
  await plugin.init();              // loads the web-tree-sitter WASM grammars
} catch (e) {
  console.error(
    `extract.mjs: UA TreeSitterPlugin.init() failed (web-tree-sitter WASM load).\n` +
    `  Underlying error: ${e && e.message}`
  );
  process.exit(3);
}

// --- grammar canary (CRITICAL guard) ----------------------------------------------
// UA's init() SWALLOWS a per-grammar load failure (its loadGrammar catches and continues)
// and still sets _initialized = true. If the TS or TSX grammar WASM fails to resolve
// (version drift, corrupted cache, ABI mismatch), init() returns clean, getParser() then
// returns null for every file, and analyzeFile() returns EMPTY arrays without throwing —
// producing a full repo of import_count:0 nodes that pass validate-schema and read as
// "covered" with extractor_failed:0. A silently-empty topology indistinguishable from a
// correct one. We refuse to emit on that: parse a known-good snippet for BOTH the TS and
// the TSX grammar (.tsx uses a separately-loaded synthetic "tsx" grammar that can fail
// independently of the base TS grammar) and confirm the expected structure comes back.
function canaryOk(path, code, wantImports, wantFns) {
  try {
    const a = plugin.analyzeFile(path, code);
    return a && (a.imports || []).length >= wantImports && (a.functions || []).length >= wantFns;
  } catch { return false; }
}
const TS_CANARY = 'import {x} from "./y"; export function f(){ return x; }';
const TSX_CANARY = 'import {x} from "./y"; export function C(){ return (<div>{x}</div>); }';
if (!canaryOk("__canary__.ts", TS_CANARY, 1, 1)) {
  console.error(
    `extract.mjs: UA grammar canary FAILED for TypeScript — the .ts grammar did not load\n` +
    `  (UA init() swallows grammar-load errors). Refusing to emit a false-empty topology.\n` +
    `  The harness should mark the 'code' emitter coverage "degenerate".`
  );
  process.exit(3);
}
if (!canaryOk("__canary__.tsx", TSX_CANARY, 1, 1)) {
  console.error(
    `extract.mjs: UA grammar canary FAILED for TSX — the .tsx grammar did not load\n` +
    `  (UA init() swallows grammar-load errors). Refusing to emit a topology that would\n` +
    `  silently under-report every .tsx component. The harness should mark coverage "degenerate".`
  );
  process.exit(3);
}

// --- file classification helpers ---------------------------------------------------
// We exclude declaration files (types-only, no runtime imports) and test files (not app code).
// src/test/ is BuyBox-AI's test-helpers folder; excluded wholesale.
function isExcludedTsFile(relPath) {
  if (relPath.endsWith(".d.ts")) return true;
  if (/\.test\.tsx?$/.test(relPath)) return true;
  // path-segment match for a top-level test dir under src (avoids matching e.g. "src/contest/")
  const segs = relPath.split("/");
  if (segs[0] === "src" && segs[1] === "test") return true;
  return false;
}

// language label is OUR distinction (UA collapses .ts and .tsx to one extractor):
//   .ts  -> "typescript"        .tsx -> "typescript-react"
function languageLabel(relPath) {
  return extname(relPath) === ".tsx" ? "typescript-react" : "typescript";
}

// --- recursive walk that yields {absPath, relPath} for files matching a predicate --
async function* walk(absDir, predicate) {
  let entries;
  try {
    entries = await readdir(absDir, { withFileTypes: true });
  } catch (e) {
    dbg(`readdir failed for ${absDir}: ${e && e.message}`);
    return;
  }
  for (const ent of entries) {
    const abs = join(absDir, ent.name);
    if (ent.isDirectory()) {
      // skip node_modules / .git / dist defensively (shouldn't be under src but be safe)
      if (ent.name === "node_modules" || ent.name === ".git" || ent.name === "dist") continue;
      yield* walk(abs, predicate);
    } else if (ent.isFile()) {
      const rel = relative(repoRoot, abs).split(sep).join("/");
      if (predicate(rel, ent.name)) yield { absPath: abs, relPath: rel };
    }
  }
}

// A non-empty source file that yields ZERO of everything COULD be a parse miss (UA's
// analyzeFile returns empty arrays on an ERROR-node tree rather than throwing — see the
// canary above). But a TYPE-ONLY module is a common, legitimate TS pattern that ALSO yields
// zero functions/classes/imports/exports — UA's extractor does not enumerate `export type` /
// `export interface` / `export enum` / `declare` as "exports". BuyBox-AI's `src/types/*.ts`
// and `_shared/calculator/types.ts` are exactly this. Flagging them as parse misses would
// wrongly route 6 legitimate files to the §6.6 manual path.
//
// So the heuristic fires ONLY when a non-trivial file yields zero structure AND shows no
// type-declaration text — i.e. it is neither a type module nor a runtime module, which is the
// genuine "parse produced nothing usable" signal. This is a content-substring check, not a
// parse-error signal (UA exposes none), so it is deliberately conservative: it accepts that a
// per-file silent miss on a type-only file is indistinguishable from a real type module, and
// chooses NOT to false-flag the common case. The canary above already covers the SYSTEMIC
// grammar-failure case (every file empty); this heuristic only catches a lone anomalous file.
const PARSE_MISS_BYTE_THRESHOLD = 220;
const TYPE_DECL_RE = /\b(export\s+(type|interface|enum|namespace)|declare\s+(module|global|const|function|namespace)|^\s*(type|interface|enum)\s)/m;
function looksLikeParseMiss(byteSize, a, content) {
  if (byteSize <= PARSE_MISS_BYTE_THRESHOLD) return false;
  if ((a.functions || []).length > 0) return false;
  if ((a.classes || []).length > 0) return false;
  if ((a.imports || []).length > 0) return false;
  if ((a.exports || []).length > 0) return false;
  // Zero structure AND a non-trivial file. If it carries type-declaration text it's a
  // legitimate type-only module (UA just doesn't enumerate type exports) — NOT a parse miss.
  if (TYPE_DECL_RE.test(content)) return false;
  return true;
}

// --- per-file extraction -----------------------------------------------------------
async function extractOne(kind, absPath, relPath) {
  let content, byteSize;
  try {
    // One read, not stat+read: for a UTF-8 file the byte length of the decoded string
    // equals the on-disk byte count, so we derive byte_size from the content (saves one
    // syscall per file).
    content = await readFile(absPath, "utf-8");
    byteSize = Buffer.byteLength(content, "utf-8");
  } catch (e) {
    return { kind, rel_path: relPath, byte_size: 0, language: languageLabel(relPath),
             analysis: { functions: [], classes: [], imports: [], exports: [] },
             extractor_error: `read failed: ${e && e.message}` };
  }
  try {
    const analysis = plugin.analyzeFile(absPath, content);
    // analyzeFile returns {functions,classes,imports,exports} — it NEVER throws on a parse
    // miss, it returns empty arrays (an ERROR-node tree yields empty). So the catch below
    // only fires on a hypothetical future throw; the real parse-miss signal is the
    // suspicious all-zero-on-a-non-trivial-file case, which we route to the §6.6 manual path
    // so it is COUNTED (ts_files_extractor_failed) rather than silently looking like a clean
    // import-free module.
    const norm = {
      functions: analysis.functions || [],
      classes: analysis.classes || [],
      imports: analysis.imports || [],
      exports: analysis.exports || []
    };
    if (looksLikeParseMiss(byteSize, norm, content)) {
      return { kind, rel_path: relPath, byte_size: byteSize, language: languageLabel(relPath),
               analysis: norm,
               extractor_error: `suspected parse miss: ${byteSize}B file yielded zero functions/classes/imports/exports and no type declarations` };
    }
    return { kind, rel_path: relPath, byte_size: byteSize, language: languageLabel(relPath), analysis: norm };
  } catch (e) {
    return { kind, rel_path: relPath, byte_size: byteSize, language: languageLabel(relPath),
             analysis: { functions: [], classes: [], imports: [], exports: [] },
             extractor_error: `analyzeFile failed: ${e && e.message}` };
  }
}

// --- main --------------------------------------------------------------------------
const diag = { walked: 0, parsed: 0, extractor_failed: 0, ts_module_count: 0, edge_function_count: 0 };

// 1. src/**/*.{ts,tsx} as ts_module
const srcAbs = join(repoRoot, "src");
for await (const f of walk(srcAbs, (rel, name) =>
  /\.tsx?$/.test(name) && !isExcludedTsFile(rel))) {
  diag.walked++;
  const rec = await extractOne("ts_module", f.absPath, f.relPath);
  if (rec.extractor_error) diag.extractor_failed++; else diag.parsed++;
  diag.ts_module_count++;
  process.stdout.write(JSON.stringify(rec) + "\n");
  dbg(`ts_module ${f.relPath} (${rec.analysis.imports.length} imports)`);
}

// 2. supabase/functions/** TypeScript:
//    - <name>/index.ts                      -> edge_function (the deployed function entry)
//    - everything else (.ts/.tsx)           -> ts_module    (shared helpers + per-fn sub-modules)
// The supabase/functions/_shared/ folder holds plain TS helper modules (cors.ts,
// api-usage-log.ts, cost-rates.ts, ...) that the edge functions import heavily. They are NOT
// deployed functions — they are library code — so they are ts_module nodes, which also lets the
// functions' `../_shared/x.ts` imports resolve to real substrate ids instead of surfacing as
// unresolved. Test/declaration files are excluded the same way as src.
const fnAbs = join(repoRoot, "supabase", "functions");
let hasFns = true;
try { await stat(fnAbs); } catch { hasFns = false; }
if (hasFns) {
  for await (const f of walk(fnAbs, (rel, name) =>
    /\.tsx?$/.test(name) && !rel.endsWith(".d.ts") && !/\.test\.tsx?$/.test(rel))) {
    // An edge_function is EXACTLY supabase/functions/<name>/index.ts — a single name segment
    // directly under functions/, where <name> is a real function folder (not _shared). The
    // anchored regex prevents three mis-classifications a loose /index.ts$/ would cause:
    //   - supabase/functions/index.ts (stray top-level) -> would yield an empty function_name
    //   - supabase/functions/_shared/index.ts           -> _shared is library code, not a fn
    //   - supabase/functions/a/b/index.ts (nested)       -> would yield a slash-bearing name
    // Anything else under functions/ (helpers, _shared, nested modules) is a ts_module.
    const isEntry = /^supabase\/functions\/(?!_shared\/)[^/]+\/index\.ts$/.test(f.relPath);
    const kind = isEntry ? "edge_function" : "ts_module";
    diag.walked++;
    const rec = await extractOne(kind, f.absPath, f.relPath);
    if (rec.extractor_error) diag.extractor_failed++; else diag.parsed++;
    if (kind === "edge_function") diag.edge_function_count++; else diag.ts_module_count++;
    process.stdout.write(JSON.stringify(rec) + "\n");
    dbg(`${kind} ${f.relPath} (${rec.analysis.imports.length} imports)`);
  }
}

// 3. footer
process.stdout.write(JSON.stringify({ __diagnostics: diag }) + "\n");
dbg(`done — ${diag.ts_module_count} ts_module + ${diag.edge_function_count} edge_function (${diag.extractor_failed} failed)`);
