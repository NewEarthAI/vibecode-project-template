# Discoverability Pass

**Why it matters.** A note that exists but no agent can reach from the root is invisible.
A routing table that claims a folder holds X when it actually holds Y misdirects every
session that trusts it. This pass walks the discovery chain a co-worker Claude actually
takes — root `CLAUDE.md` → routing entry → folder index → file — and verifies it tells the
truth and reaches everything.

**Applies to:** the whole vault — root `CLAUDE.md`, every folder regardless of layer, every
folder-index file (under the discovered convention), every `.md` reachable from the routing
chain. Reads the `identity` and `context` roles to understand the user's world.

**Out of scope (never edited without per-item user approval):** any `CLAUDE.md`, any
`SKILL.md`, any `.claude/rules/` file. These can be *targeted* by a fix (D.1 rewrites
routing, D.8 adds an orientation section) but only via walk-and-confirm — never automated.
Routing/orientation edits to a CLAUDE.md are the one legitimate path, and they go through
`refactor-claude-md` or per-item confirmation.

## The folder-index convention is discovered, never imposed

Role discovery detects what file name the vault uses for folder indexes — `README.md`,
`index.md`, `Plot.md`, or a folder-level `CLAUDE.md`. This pass enforces *that* convention.
If none exists, D.0 surfaces the gap and proposes adopting one (default suggestion
`README.md` — universally understood). A folder is **non-trivial** if it has ≥2 `.md` files
or ≥1 subfolder; trivial folders need no index.

The drafted folder-index format:

```markdown
---
status: active
type: folder-index
tags: [folder-index]
date: 2026-05-17
---

# {Folder name}

**Purpose:** {one line — what this folder holds and why}

## Children

- [[file-name]] — {one-line description}
- [[subfolder/{index-name}]] — {one-line subfolder purpose}
```

Constraints: ≤8KB, no em dashes, complete frontmatter, markdown only.

## Setup (run once, cache)

1. **Read the `identity` and `context` roles** — who the user is, the org, current strategy,
   voice. D.8 uses this to build orientation questions; D.1/D.5 use it to judge whether a
   folder description matches the user's actual world. Both missing → D.8 still runs with
   generic questions, and the absence is itself a D.0 finding.
2. **Parse the root CLAUDE.md routing table** into `{path → description}` pairs.
3. **Build the navigation graph:** node = file or folder; edge = "reachable from"
   (root CLAUDE.md → routing entry → folder index → child file). Compute hop distance from
   the root for every `.md`.
4. **Build the folder inventory:** per folder — `.md` children, subfolders, presence and
   mtime of the index file.
5. **Sample contents:** for each folder with ≥3 files, cache the first 1500 chars + headers
   of 3-5 files (newest, oldest, median size).

---

## D.0 — Structural-role gaps

**Rule:** surface structural needs identified in *this specific vault*. Three tiers.

**Tier 1 — functional gaps (the pass cannot do its job).** Severity fail.
- No first-person identity context anywhere (no folder, file, frontmatter section, or inline
  mention) → discoverability judgments (D.4 path allocation, D.7 orientation) cannot be grounded.
- No routing of any shape on the root CLAUDE.md (no table, no prose pointers, no wikilinks)
  → the discoverability walk has nowhere to start.
- A custom role with `confidence: low` or `unknown` → downstream checks need its layer.
Tier 1 is form-agnostic: identity in root-CLAUDE.md frontmatter is fine; routing as prose is fine.

**Tier 2 — functional improvements (judged to concretely help this vault).** Severity warn.
A convention worth adopting *because current vault state shows it would resolve a real
problem* — with reasoning specific to the case. Example: "23 of 31 folders have no index;
the discoverability walk failed for 47 files; adopting an index convention fixes all 47."
**Never** justify a Tier 2 finding with "another vault does this." If a custom folder already
serves the function, no Tier 2 finding fires — function over name.

**Tier 3 — inspiration.** Severity info. A single finding listing standard roles the vault
lacks, framed openly as optional. Default decline.

Every tier is walk-only and fixable. Declines persist to `.claude/vault-roles.json` so they
do not re-prompt.

## D.1 — Routing-table truthfulness

**Rule:** every routing entry must point to an existing path, and its description must match
what is actually inside.
**Trigger:** for each `{path → description}` pair — does `path` resolve? Do the sampled
files match the description? Does any top-level folder *not* appear in the table? Does a
description reference a focus the `context` role shows the user has moved away from?
**Judgment / fix (walk-only, drafted replacement line):** nonexistent path → rewrite to the
real location or remove the entry; misaligned description → rewrite to folder reality;
uncovered folder → add an entry; stale entry → rewrite to current strategy.
**Severity:** fail for a broken path (it breaks the chain); warn otherwise.

## D.2 — Folder-index presence and freshness

**Rule:** every non-trivial folder has a current index file under the discovered convention.
**Pre-condition:** if no convention exists, D.0 establishes one first.
**Trigger:** per non-trivial folder — index missing; index present but its Children list
does not match `ls`; index older than the newest file in the folder; index not in the
required format.
**Judgment / fix (walk-only):** generate from scratch (missing), regenerate the Children
list (stale), or repair the format — drafted content ready to write, user confirms the
Purpose line and child descriptions per folder.
**Severity:** warn.

## D.3 — Discoverability walk

**Rule:** every `.md` (excluding technical skips and meta files) is reachable from the root
CLAUDE.md in ≤3 hops via the navigation chain.
**Trigger:** from the navigation graph — hop distance > 3 (deep-buried) or ∞ (orphan).
Excluded: `CLAUDE.md` itself, index files (navigation nodes, not destinations), `MEMORY.md`,
`.claude/` contents, anything in an `archive`-layer folder.
**Judgment / fix (walk-only):** per orphan, pick the most likely repair as the default —
add the file to its folder's index; add a routing entry for an unrouted folder; move a
misplaced file to a discoverable folder; archive a genuinely dead file.
**Severity:** fail — discoverability is the load-bearing property.

## D.4 — Semantic path allocation

**Rule:** every file lives in a folder whose stated purpose matches its content.
**Trigger:** per file, compare its H1 + first 1500 chars against its folder's registry
`purpose` and index Purpose line. Keyword overlap < 0.2 → candidate.
**Judgment / fix (walk-only):** misplaced → propose relocation; folder purpose too narrow →
propose broadening the index Purpose (route to D.2); false positive (incidental vocabulary) → drop.
**Severity:** warn.

## D.5 — Folder-purpose duplication

**Rule:** no two folders should have substantially overlapping stated purposes.
**Trigger:** per folder pair (any layer except archive/meta), Purpose-line similarity > 0.5,
or children-set overlap > 30%.
**Judgment / fix (walk-only):** true duplication → propose a merge (route to D.6); adjacent
but distinct → propose Purpose-line clarification on both (route to D.2); false positive → drop.
**Severity:** warn.

## D.6 — Reorganisation proposals

**Rule:** after D.1-D.5 run, surface the 1-3 highest-impact structural changes.
**Trigger:** aggregate D.1 stale routing + D.4 misplacements + D.5 duplications; cluster
proposals touching the same folders; rank by (files affected) × severity; take the top 3.
**Judgment:** draft a migration plan per cluster — what moves, what is renamed, what merges,
which indexes need rewriting. **Reasoning must cite the user's own stated folder purposes** —
never an external taxonomy. If clarifying purposes resolves the problem without moving
files, propose that first (smaller blast radius).
**Fix (walk-only):** apply now (walk each migration step, confirm per step) **or** save the
plan to a dated file in the `decisions`-layer folder for later execution. Not "skip" — a
saved plan is committed to disk.
**Severity:** info.

## D.7 — Holistic orientation

**Rule:** the root `CLAUDE.md` must orient a fresh co-worker Claude toward the user's actual
world in under 60 seconds.
**Trigger:** from the `identity`/`context` roles, build 5 vault-specific orientation
questions ("If the user mentions {project}, can I find its authoritative file?" "Where is
the voice/brand reference?" "Where do prior decisions live?"). Read the root CLAUDE.md cold
and answer each using only what it says. Score: answerable directly / via routing-then-index
/ not answerable.
**Judgment / fix (walk-only):** per unanswerable question — add a CLAUDE.md section
(drafted), improve a routing entry, or strengthen a folder index. CLAUDE.md edits require
explicit per-item approval and route through `refactor-claude-md`.
**Severity:** fail — orientation is foundational.

---

## Cross-pass constraints

| Constraint | Resolution |
|---|---|
| Never auto-rewrite a CLAUDE.md | D.1 / D.7 CLAUDE.md edits are walk-only with per-item approval, routed through `refactor-claude-md` |
| Wikilink-orphan ≠ navigation-orphan | A file can have no inbound wikilink yet be navigation-reachable, or vice versa — distinct concerns; report separately |
| Memory budget vs index size | The index format stays ≤8KB by construction; a folder with too many children to fit → route to D.6 (split the folder) before generating the index |
| Index is a navigation node, not a destination | D.3 excludes index files from orphan checks |

## Finding schema

Per the SKILL.md schema. `pass: "discoverability"`, `check_id: "D.x"`. Add `proposed_edit`
(the literal text a fix would write) for D.1/D.2/D.3/D.7, and `fix_modes`
(`["apply_now", "save_to_plan"]` for D.6, `["apply_now"]` elsewhere). `reasoning` must
explain the specific break in the navigation chain. Discoverability findings do **not** feed
the health score; they are opportunities, reported in their own dashboard group.
