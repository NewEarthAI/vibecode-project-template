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
//    "supabase_calls":[{call,op,dynamic,literal,line}], "fetch_calls":[{url,method,dynamic,line}],
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
// src/test/ is my-project's test-helpers folder; excluded wholesale.
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
// `export interface` / `export enum` / `declare` as "exports". my-project's `src/types/*.ts`
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

// --- cross-system call scan (visual-layer cross-system edges) ----------------------------
// One tree-sitter walk per file extracts TWO call families so the transform can emit cross-system edges:
//   (Phase 1a) supabase `X.from('<table>')` / `X.functions.invoke('<name>')` MEMBER calls
//              -> frontend / edge-fn -> Supabase table / function
//   (follow-up #1) bare global `fetch('<url>', {method})` calls
//              -> edge-fn / frontend -> external API (or resolved Supabase REST/fn) / blind-spot
// Honesty guards (council 2026-06-05, R3/R4/R13) apply to the SUPABASE scan:
//   R13 — AST, NOT regex: we walk UA's tree-sitter parse (getParser), so a commented-out
//         `// supabase.from('x')` or a string literal lookalike is NEVER matched (verified by probe).
//   R4  — provenance gate: only scan files importing a Supabase client, and only count calls whose
//         receiver ROOT identifier is a name bound to that import (kills RxJS `from()`, Drizzle
//         `db.from()`, any same-named `.from()` on a non-Supabase object). A bare `from(...)` (not a
//         member call) is never matched — only `X.from(...)`.
//   R3  — a non-string-literal argument (identifier / `${}` template / computed) is emitted with
//         dynamic:true so the transform routes it to a blind-spot (never a silent drop, never green).
// The FETCH scan needs no provenance gate (`fetch` is a global); R13 (AST) + R3 (dynamic url ->
// blind-spot) still hold — a dynamic / unparseable URL is flagged for the transform, never dropped.
// Only the bare global `fetch` identifier is matched: a member `x.fetch()` or an import-aliased client
// (node-fetch / undici / axios) is NOT a v1 target (documented out-of-scope).
const SUPABASE_IMPORT_RE =
  /(@supabase\/supabase-js|supabase[-/]js|integrations\/supabase|lib\/supabase|utils\/supabase|supabase\/client|supabaseClient)/i;
const WRITE_METHODS = /^(insert|update|upsert|delete)$/;
// Follow-up #2 (DI scanner): the TIGHT convention set for a dependency-injected Supabase client held as a
// `this` property (`this.supabase.from(...)`). Membership here is the ONLY thing that licenses a DI edge —
// a `this.<prop>` whose prop is NOT in this set is treated as not-a-Supabase-client and yields ZERO edges
// (the false-POSITIVE guard for the never-false-green core). Convention is a WEAKER proof of binding than
// the import-bound singleton path (which proves the receiver was imported), so DI edges are capped at
// declared-medium in transform.jq regardless of from/invoke. Keep this set tight; widening it trades the
// false-positive guarantee for marginal coverage on a pattern no live target currently uses.
const DI_CLIENT_PROPS = new Set(["supabase", "supabaseClient", "_supabase", "sb", "supa"]);

// Local identifier names bound to a Supabase client import — the R4 receiver allow-set.
function supabaseClientNames(imports) {
  const names = new Set();
  for (const imp of imports || []) {
    const src = imp && typeof imp.source === "string" ? imp.source : "";
    if (SUPABASE_IMPORT_RE.test(src)) {
      for (const spec of (imp.specifiers || [])) if (typeof spec === "string" && spec) names.add(spec);
    }
  }
  return names;
}

// Walk a member_expression's leftmost-object chain to its root identifier name (or null).
// A `this.supabase.from()` (class/DI pattern — the client is a PROPERTY of `this`, not the imported
// identifier) roots at a `this`/`this_expression` node and returns null here, so it is invisible to the
// import-bound (R4) singleton path. DI calls are handled separately by diClientProp + the DI fallback in
// the `from`/`invoke` branches below — NOT by this function.
//
// FOLLOW-UP #2 — BUILT 2026-06-07 (operator override of the recorded deferral; SPECULATIVE, FIXTURE-ONLY).
// The deferral condition ("a target entity adopts the DI pattern") is STILL UNMET — every known target entity is imported-
// singleton and no live target uses DI — so this coverage is validated against SYNTHETIC FIXTURES ONLY and
// claims NO live coverage. The operator chose to build it now with that caveat acknowledged. The SAFE-NARROW
// shape (implemented exactly): gate on (a) the file imports a Supabase client (clientNames non-empty — the
// outer `hasClient` gate) AND (b) the `this` property name is in the TIGHT convention set DI_CLIENT_PROPS
// (supabase / supabaseClient / _supabase / sb / supa) AND (c) the exact Supabase method surface
// (from / functions.invoke); the dynamic-arg -> blind-spot guard is shared with the singleton path; the
// convention-inferred binding is capped at declared-medium and marked in the edge derivation (transform.jq).
// A non-convention `this.<other>.from()` yields ZERO edges (the false-POSITIVE guard).
function memberRootName(node) {
  let n = node;
  while (n && n.type === "member_expression") n = n.childForFieldName("object");
  return n && n.type === "identifier" ? n.text : null;
}

// Follow-up #2 (DI scanner): detect a dependency-injected client receiver `this.<prop>` where <prop> is a
// conventional Supabase-client name. Returns the matched property name, or null. The `this` receiver roots
// at a `this`/`this_expression` node (memberRootName returns null for it — see the memberRootName note above),
// so DI calls are invisible to the import-bound (R4) singleton path and need this dedicated matcher. It is
// deliberately convention-gated (not binding-proven): the property name is the only signal, so a non-
// convention prop returns null and the call is SKIPPED (no false edge). `obj` is the member_expression that
// is the call's receiver (`this.supabase`) for from, or the `this.supabase` inside `this.supabase.functions`
// for invoke.
function diClientProp(obj) {
  if (!obj || obj.type !== "member_expression") return null;
  const inner = obj.childForFieldName("object");
  if (!inner || (inner.type !== "this" && inner.type !== "this_expression")) return null;
  const prop = (obj.childForFieldName("property") || {}).text;
  return prop && DI_CLIENT_PROPS.has(prop) ? prop : null;
}

// Classify a call's first argument: a static string literal, or dynamic (runtime-constructed).
// An EMPTY string literal (from('')) is treated as dynamic — an empty table/function name is never a
// valid call, so it routes to a blind-spot rather than producing a degenerate "public." target id.
function argLiteral(argNode) {
  if (!argNode) return { dynamic: true, literal: null };               // .from() with no arg
  let lit = null;
  if (argNode.type === "string") {
    const frag = argNode.namedChildren && argNode.namedChildren.find((c) => c.type === "string_fragment");
    lit = frag ? frag.text : argNode.text.replace(/^['"`]|['"`]$/g, "");
  } else if (argNode.type === "template_string") {
    const hasSub = argNode.namedChildren && argNode.namedChildren.some((c) => c.type === "template_substitution");
    if (!hasSub) lit = argNode.text.replace(/^`|`$/g, "");
  }
  if (lit === null || lit === "") return { dynamic: true, literal: null }; // identifier / interpolated / empty
  return { dynamic: false, literal: lit };
}

// Extract the HTTP method from a fetch() options-object argument: find a `method:` pair whose value is
// a static string literal; default "GET" (the fetch default — and the honest default when the method is
// dynamic/absent, since the URL, not the method, governs cross-system visibility).
function methodFromOpts(optsNode) {
  if (!optsNode || optsNode.type !== "object") return "GET";
  for (let i = 0; i < optsNode.namedChildCount; i++) {
    const pair = optsNode.namedChild(i);
    if (!pair || pair.type !== "pair") continue;
    const key = pair.childForFieldName("key");
    const val = pair.childForFieldName("value");
    if (!key || !val) continue;
    const keyName = (key.type === "property_identifier" || key.type === "identifier") ? key.text
                  : key.type === "string" ? key.text.replace(/^['"`]|['"`]$/g, "") : null;
    if (keyName === "method") {
      if (val.type === "string") {
        const frag = val.namedChildren && val.namedChildren.find((c) => c.type === "string_fragment");
        const m = frag ? frag.text : val.text.replace(/^['"`]|['"`]$/g, "");
        return (m || "GET").toUpperCase();
      }
      if (val.type === "template_string") {
        // a static backtick literal (no ${} substitution) is a real method value — e.g. method: `DELETE`.
        // Without this branch a backtick write-method silently defaults to GET -> a wrong reads_from edge.
        const hasSub = val.namedChildren && val.namedChildren.some((c) => c.type === "template_substitution");
        if (!hasSub) return (val.text.replace(/^`|`$/g, "") || "GET").toUpperCase();
      }
      return "GET";   // dynamic / non-literal method value -> the default
    }
  }
  return "GET";
}

// Extract cross-system calls from one file via UA's tree-sitter parser, in a SINGLE walk:
//   - supabase `X.from(...)` / `X.functions.invoke(...)` MEMBER calls (R4-gated to a bound client)
//   - bare global `fetch(<url>, <opts>?)` calls (the edge-function / frontend external-API surface)
// Returns { supabase_calls, fetch_calls } ([] each on ANY parse problem — fail-safe: a scan failure must
// never abort the emit). ONE parse + ONE walk for both scans (no extra parse over the supabase-only path
// it replaces). NOTE: a file whose tree-sitter parse fails here is indistinguishable from a genuinely
// call-free file (both yield []); acceptable because UA's analyzeFile (which parses first) already routes
// a hard parse failure to the §6.6 manual/extractor_error path upstream, so it is COUNTED there.
function extractCrossSystemCalls(relPath, content, clientNames) {
  const empty = { supabase_calls: [], fetch_calls: [] };
  let parser, tree;
  try { parser = plugin.getParser(relPath); } catch { return empty; }
  if (!parser || typeof parser.parse !== "function") return empty;
  try { tree = parser.parse(content); } catch { return empty; }
  if (!tree || !tree.rootNode) return empty;
  const supabase_calls = [];
  const fetch_calls = [];
  const hasClient = clientNames.size > 0;            // R4 gate 1 — supabase scan only; fetch is a global
  const visit = (n) => {
    if (n.type === "call_expression") {
      const fn = n.childForFieldName("function");
      if (fn && fn.type === "identifier" && fn.text === "fetch") {
        // bare global fetch(<url>, <opts>?) — NOT a member call (x.fetch()), NOT an import-aliased client
        // (node-fetch / undici / axios are a documented v1 out-of-scope). The URL classification
        // (transform.jq classify_fetch_url), not the receiver, decides external / supabase / blind-spot.
        const args = n.childForFieldName("arguments");
        const urlArg  = args && args.namedChildCount > 0 ? args.namedChild(0) : null;
        const optsArg = args && args.namedChildCount > 1 ? args.namedChild(1) : null;
        const a = argLiteral(urlArg);
        fetch_calls.push({ url: a.literal, method: methodFromOpts(optsArg), dynamic: a.dynamic, line: n.startPosition.row + 1 });
      } else if (hasClient && fn && fn.type === "member_expression") {
        const propName = (fn.childForFieldName("property") || {}).text;
        const obj = fn.childForFieldName("object");
        const args = n.childForFieldName("arguments");
        const firstArg = args && args.namedChildCount > 0 ? args.namedChild(0) : null;
        if (propName === "from") {                        // R4 gate 2: must be X.from(...), X bound to supabase
          // Singleton (import-bound) takes precedence; DI (this.<conv>) is the fallback. The DI branch is
          // gated by diClientProp (convention set) and only reached when the singleton match fails, so the
          // imported-singleton output is byte-identical (no `di` key emitted on that path).
          const root = memberRootName(obj);
          const singleton = !!(root && clientNames.has(root));
          const diProp = singleton ? null : diClientProp(obj);
          if (singleton || diProp) {
            const a = argLiteral(firstArg);
            let op = "read";
            const parent = n.parent;                      // chained write-method: <this-call>.<method>
            if (parent && parent.type === "member_expression") {
              const cp = (parent.childForFieldName("property") || {}).text;
              if (cp && WRITE_METHODS.test(cp)) op = "write";
            }
            const rec = { call: "from", op, dynamic: a.dynamic, literal: a.literal, line: n.startPosition.row + 1 };
            if (diProp) rec.di = true;                     // convention-inferred binding -> capped at declared-medium downstream
            supabase_calls.push(rec);
          }
        } else if (propName === "invoke" && obj && obj.type === "member_expression") {
          // X.functions.invoke(...) — obj is `X.functions`; its root must be the supabase client (singleton)
          // OR the `this.functions` chain whose `this.<conv>` is a DI client (fallback).
          if ((obj.childForFieldName("property") || {}).text === "functions") {
            const fnObj = obj.childForFieldName("object");   // `X` (singleton) or `this.supabase` (DI)
            const root = memberRootName(fnObj);
            const singleton = !!(root && clientNames.has(root));
            const diProp = singleton ? null : diClientProp(fnObj);
            if (singleton || diProp) {
              const a = argLiteral(firstArg);
              const rec = { call: "invoke", dynamic: a.dynamic, literal: a.literal, line: n.startPosition.row + 1 };
              if (diProp) rec.di = true;                     // even invoke is capped at declared-medium when DI
              supabase_calls.push(rec);
            }
          }
        }
      }
    }
    for (let i = 0; i < n.namedChildCount; i++) visit(n.namedChild(i));
  };
  try { visit(tree.rootNode); } catch { /* partial scan still useful */ }
  return { supabase_calls, fetch_calls };
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
               analysis: norm, supabase_calls: [], fetch_calls: [],
               extractor_error: `suspected parse miss: ${byteSize}B file yielded zero functions/classes/imports/exports and no type declarations` };
    }
    // Cross-system scan: supabase calls (R4-gated to a bound client) + bare global fetch() calls, one walk.
    //
    // PERF skip-gate (follow-up #3): the scan re-parses the file with tree-sitter. UA's analyzeFile (above)
    // already parses, but does NOT expose its tree, so a single shared parse would require forking the UA
    // library — out of scope (compose, don't fork). Instead we skip the SECOND parse for files that PROVABLY
    // contain neither call family:
    //   - no Supabase client import  -> clientNames is empty, so the R4-gated supabase branch can never fire
    //   - no bare `fetch` identifier  -> the fetch branch (bare global `fetch`) can never fire
    // The gate tests for the bare WORD `fetch` (`\bfetch\b`), NOT `fetch(`. This is deliberate: the AST scan
    // matches a call whose callee identifier is `fetch`, and EVERY such call — `fetch(`, `fetch (`, `fetch\n(`,
    // AND the optional-call `fetch?.(` (which the AST DOES catch) — contains the identifier token `fetch`, so
    // gating on the word has NO false-NEGATIVE. (The earlier `\bfetch\s*\(` form silently SKIPPED a file whose
    // only call was `fetch?.(` and which imported no Supabase client -> a real silent edge drop; code-council
    // 2026-06-06 CRITICAL.) A false-POSITIVE (the word in a comment / string / member `x.fetch` / prose) merely
    // does the parse anyway — no harm, the AST walk then correctly ignores non-call / non-bare-global uses (R13).
    // The trade is a few extra parses on files that merely mention "fetch" for a provably drop-free gate.
    // Net: the majority of files (neither Supabase-importing nor fetch-mentioning) skip the redundant parse.
    const clientNames = supabaseClientNames(norm.imports);
    const mayHaveCrossSystemCall = clientNames.size > 0 || /\bfetch\b/.test(content);
    const { supabase_calls, fetch_calls } = mayHaveCrossSystemCall
      ? extractCrossSystemCalls(relPath, content, clientNames)
      : { supabase_calls: [], fetch_calls: [] };
    return { kind, rel_path: relPath, byte_size: byteSize, language: languageLabel(relPath),
             analysis: norm, supabase_calls, fetch_calls };
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
