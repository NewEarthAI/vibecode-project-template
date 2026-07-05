#!/usr/bin/env node
// intent-capture-emitter/scripts/extract.mjs — the carrier parsers (M6 S2b).
//
// Reads ONE intent carrier (a destination / ADR / roadmap_item markdown file) and emits a RAW
// extraction object on stdout. It does NOT resolve git provenance (emit.sh does) and it does NOT
// map to the final 14-field record (transform.jq does). It is a pure text-to-structure parser.
//
// CRITICAL (Doctrine 04 D2 / council G1): this parser NEVER guesses a wired_to link from prose.
// If a carrier states no machine-addressable wiring, wired_to is left for transform.jq to set to
// "pending". A name-match guess would fabricate a left_view -- banned.
//
// Reads the carrier file with readFileSync only. No shell, no child process, no network.
//
// Usage:  extract.mjs <destination|adr|roadmap_item> <carrier-file-path>
// Output: a JSON object (raw extraction) on stdout; a non-zero exit + stderr message on failure.

import { readFileSync } from "node:fs";

function fail(msg) { process.stderr.write("extract.mjs: " + msg + "\n"); process.exit(2); }

const kind = process.argv[2];
const file = process.argv[3];
if (!kind || !file) fail("usage: extract.mjs <destination|adr|roadmap_item> <carrier-file-path>");
if (!["destination", "adr", "roadmap_item"].includes(kind)) fail("unknown kind '" + kind + "'");

let text;
try { text = readFileSync(file, "utf8"); } catch (e) { fail("cannot read " + file + ": " + e.message); }

// --- frontmatter (simple key: value YAML between the first two --- fences) -------
function parseFrontmatter(src) {
  const m = src.match(/^---\n([\s\S]*?)\n---\n?/);
  if (!m) return { frontmatter: {}, body: src };
  const fm = {};
  for (const line of m[1].split("\n")) {
    const kv = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (kv) fm[kv[1]] = kv[2].trim();
  }
  return { frontmatter: fm, body: src.slice(m[0].length) };
}

// --- section split by "## Heading" ----------------------------------------------
function splitSections(body) {
  const out = [];
  const re = /^##\s+(.*)$/gm;
  let m, last = null;
  while ((m = re.exec(body)) !== null) {
    if (last) last.end = m.index;
    last = { heading: m[1].trim(), start: re.lastIndex, end: body.length };
    out.push(last);
  }
  return out.map(s => ({ heading: s.heading, text: body.slice(s.start, s.end).trim() }));
}
function findSection(sections, needle) {
  const n = needle.toLowerCase();
  const hit = sections.find(s => s.heading.toLowerCase().includes(n));
  return hit ? hit.text : null;
}
function firstH1(body) {
  const m = body.match(/^#\s+(.*)$/m);
  return m ? m[1].trim() : null;
}

const parsed = parseFrontmatter(text);
const frontmatter = parsed.frontmatter;
const body = parsed.body;
const sections = splitSections(body);

let raw;
if (kind === "destination") {
  raw = {
    kind,
    source_file: file,
    title: firstH1(body) || frontmatter.title || "(untitled destination)",
    status_raw: frontmatter.status || null,
    conditions: findSection(sections, "element 1") || findSection(sections, "end-state") || null,
    binary_test: findSection(sections, "element 2") || findSection(sections, "binary success") || null,
    // Element 4 ("could the test lie?") is a PROSE falsifier candidate. Surfaced for an operator
    // to convert into a machine-executable falsifier -- NOT auto-promoted into the falsifier field
    // (NSF-2 would reject prose; D2 forbids guessing). transform.jq sets falsifier:null.
    falsifier_candidate: findSection(sections, "element 4") || findSection(sections, "could the test lie") || null,
    owner_raw: frontmatter.owner || null,
    frontmatter,
  };
} else if (kind === "adr") {
  raw = {
    kind,
    source_file: file,
    title: firstH1(body) || frontmatter.title || "(untitled adr)",
    status_raw: (findSection(sections, "status") || frontmatter.status || "").split(/\s|\n/)[0] || null,
    conditions: findSection(sections, "decision") || null,
    binary_test: findSection(sections, "consequences") || null,
    falsifier_candidate: null,
    owner_raw: frontmatter.owner || null,
    frontmatter,
  };
} else { // roadmap_item
  raw = {
    kind,
    source_file: file,
    title: firstH1(body) || "(roadmap item)",
    status_raw: frontmatter.status || null,
    conditions: null,
    binary_test: findSection(sections, "done when") || null,
    falsifier_candidate: null,
    owner_raw: frontmatter.owner || null,
    frontmatter,
  };
}

process.stdout.write(JSON.stringify(raw, null, 2) + "\n");
