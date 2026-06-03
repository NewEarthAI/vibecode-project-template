---
name: vault-optimizer
description: |
  Audit a markdown vault for broken discoverability — the structural failures that make
  notes invisible to an AI agent: routing tables that lie about what a folder contains,
  notes unreachable from the root, folders with stale or missing index files, files in the
  wrong place. Walks the discovery chain an agent actually follows: root CLAUDE.md → routing
  entry → folder index → file. Discovers folder roles by reading content — never by assuming
  names — so it works on any vault. Delegates CLAUDE.md and memory-index hygiene to
  refactor-claude-md and refactor-memory-md rather than re-implementing them. Produces a
  before/after report. Use when: "optimise vault", "vault audit", "discoverability check",
  "is my vault findable", "are my notes reachable", "vault architecture", "audit vault
  structure". Run from the vault root. Not for contradiction or theme detection (use
  /challenge, /drift, /emerge), CLAUDE.md-only cleanup (use refactor-claude-md), or cadence
  orchestration (use vault-review).
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Skill, AskUserQuestion, TodoWrite
user-invocable: true
version: 1.0
classification: encoded-preference
created: 2026-05-17
updated: 2026-05-17
template_managed: false
---

!`test -f CLAUDE.md && wc -l CLAUDE.md 2>/dev/null || test -f claude.md && wc -l claude.md 2>/dev/null || echo "no root CLAUDE.md"`
!`find . -maxdepth 3 -name '*.md' -not -path '*/.git/*' -not -path '*/.obsidian/*' 2>/dev/null | wc -l | xargs -I{} echo "markdown files (≤3 deep): {}"`

# Vault Optimizer v1.0

> Audits one thing no other skill covers: **discoverability** — can an AI agent reach every
> note by following the vault's own signposts, and do those signposts tell the truth. Built
> for any vault — folder roles are discovered, never assumed.

## When to use
- A markdown vault (a team vault, a project vault, a personal second brain) has grown and you suspect notes are no longer findable
- Routing has drifted from reality — the index says one thing, the folders hold another
- Periodic structural maintenance — run monthly while a vault grows, quarterly once stable

## When NOT to use
- Finding contradictions, themes, or duplicate notes → `/challenge`, `/drift`, `/emerge`
- Refactoring a single CLAUDE.md to its line ceiling → `refactor-claude-md`
- Refactoring MEMORY.md / memory topic files → `refactor-memory-md`
- Running overdue vault cadence commands → `vault-review`
- A folder with no `.md` files → there is nothing to audit

## What it audits

| Dimension | How | Reference |
|---|---|---|
| **Discoverability** | Native pass — routing-table truthfulness, folder-index presence, reachability in ≤3 hops, misplaced files, reorg proposals, holistic orientation | `references/discoverability-pass.md` |
| CLAUDE.md hygiene | **Delegated** — invokes `refactor-claude-md` per CLAUDE.md found | (sibling skill) |
| Memory-index hygiene | **Delegated** — invokes `refactor-memory-md` if a memory index is present | (sibling skill) |

The discoverability pass is the reason this skill exists — nothing else in the toolkit walks the navigation graph. The delegated dimensions are surfaced but never re-implemented.

---

## Phase 0 — Verify the vault, create the task list

**0.1 — Confirm the cwd is a vault.** Either check below passing confirms it:

```bash
test -f CLAUDE.md || test -f claude.md
[ "$(find . -maxdepth 1 -name '*.md' | wc -l)" -gt 0 ]
```

If neither holds → stop: "No `.md` files or root CLAUDE.md here. `cd` into the vault root and re-run."

**0.2 — Create the visible task list** with `TodoWrite` — one item per phase. The user watches the run unfold; a silent long audit is unacceptable. Mark each `in_progress` on entry, `completed` on exit.

```
[ ] Discover & classify files; role discovery (Phase 1)
[ ] Delegated dimensions — CLAUDE.md + memory hygiene (Phase 2a)
[ ] Discoverability pass (Phase 2b)
[ ] Aggregate + architectural read (Phase 3)
[ ] Walk + apply fixes (Phase 4)
[ ] Render report (Phase 5)
```

---

## Phase 1 — Discover, classify, role-map

**1.1 — Glob every `.md`** outside the technical skip list:

```bash
find . -name '*.md' \
  -not -path '*/.git/*' -not -path '*/.obsidian/*' -not -path '*/.trash/*' \
  -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*'
```

**1.2 — Build the supporting indexes** the discoverability pass needs:
- `filename_index` — every basename, lowercased, with and without extension
- `inbound_link_index` — `grep` across the vault for `\[\[name(\||\]|#)` wikilink targets
- `routing_table` — the routing / knowledge-routing section of the root CLAUDE.md, if present

**1.3 — Run role discovery.** Read `references/role-discovery.md` and follow it. This classifies every folder by *reading content*, never by assuming names — the reason this skill is portable across team vaults, project vaults, and personal vaults. Output: a role registry, persisted to `.claude/vault-roles.json`. Show the user the one-block discovery summary the reference file specifies.

**Hard rule:** the discoverability pass references roles by *layer* (`curated` / `session` / `archive` / `meta`), never by folder name. Examples in the reference file (`Context/`, `Daily/`) are illustrative; the runtime resolves through the registry.

---

## Phase 2 — Run the audit

### Phase 2a — Delegated dimensions (compose, don't re-implement)

**CLAUDE.md hygiene.** For every `CLAUDE.md` / `claude.md` found in Phase 1:
- Measure line count. Anthropic's ceiling is 80-100 lines for a root CLAUDE.md.
- If any exceed it, surface them as a delegated finding: "`{path}` is {N} lines — `refactor-claude-md` is the fix."
- In apply mode (Phase 4) and only with the user's go-ahead, invoke `refactor-claude-md` via the `Skill` tool, one file at a time. This skill never edits a CLAUDE.md itself.

**Memory-index hygiene.** If the vault contains a memory index (a `MEMORY.md`, or an index file the role registry tagged `meta`):
- Surface it as a delegated finding pointing at `refactor-memory-md`.
- Invoke `refactor-memory-md` via the `Skill` tool only on the user's go-ahead.

Delegated findings are reported in the final report under a "Delegated" group — counted, never auto-fixed by this skill.

### Phase 2b — Discoverability pass

Read `references/discoverability-pass.md` and apply every check. Scope: the whole vault — the routing chain end to end.

**This is not a regex pass.** Triggers (does a path exist, does a folder index list a file) only *surface candidates*. For each candidate, read the folder contents and judge alignment with stated intent before logging a finding. A trigger is a candidate, not a verdict.

**Every finding carries a `reasoning` field** — 1-2 sentences specific to that case, never a paraphrase of the rule. After the pass, sample 5 findings; if more than 40% of their `reasoning` fields are rule-restatements rather than case-specific judgment, re-run with deeper reads. This is a hard gate — judgment is the skill's value.

**Finding schema:**

```json
{
  "pass": "discoverability",
  "check_id": "D.3",
  "path": "./Projects/research/competitor-X.md",
  "severity": "fail",
  "excerpt": "verbatim slice of the offending content or a one-line state description",
  "reasoning": "case-specific judgment — the exact break in the navigation chain, not a rule restatement",
  "action": "the concrete fix",
  "proposed_edit": "literal text a fix would write (D.1/D.2/D.3/D.7)",
  "fix_status": null
}
```

`fix_status` stays `null` until Phase 4 sets it to `applied`, `declined`, or `failed`.

---

## Phase 3 — Aggregate + architectural read

**3.1 — Score.** Count discoverability findings by severity:

```
deduction = (fail_count × 5) + (warn_count × 1)
score     = max(0, 100 - min(deduction, 80))
```

| Score | Reading |
|---|---|
| 90-100 | Well-mapped — every note reachable, routing honest |
| 70-89 | Visible drift — address the broken routing entries and orphans |
| 50-69 | Navigation is failing — agents cannot reliably find notes |
| <50 | Structurally lost — major re-mapping needed |

`D.6` reorg proposals are *opportunities*, not lint failures — report them in their own group, do not score them.

**3.2 — Architectural read.** Before walking fixes, write 1-3 short paragraphs: the top structural problems, why each matters *for this vault* (cite the identity/context role), the finding(s) that surfaced it, the proposed direction. Under 250 words — synthesis, not a recap. If the vault is well-mapped, say so in one sentence citing the metric that justifies it. Don't pad.

---

## Phase 4 — Walk + apply fixes

**4.1 — One opening `AskUserQuestion`** — the apply gate:

> "Audit complete: {N} findings ({fail} fail · {warn} warn). Pick a mode:"
> - **Walk every fix** — per-finding apply / decline. Best for a first run on a vault.
> - **Apply all safe fixes** — mechanical fixes (generate a missing index) apply without prompting; semantic fixes (routing rewrites, file moves, reorgs) still walk per item.
> - **Report only** — no edits; the saved report carries every proposed fix.

**4.2 — Walk loop.** Smallest blast radius first (routing edits and index generation before file moves before reorgs). For each finding: show it compactly (path, severity, excerpt, proposed fix), then resolve it to a terminal `fix_status`. There is no "skip" — a finding ends `applied`, `declined`, or `failed`.

**4.3 — Safety rails (non-negotiable):**
- **Never edit a CLAUDE.md, SKILL.md, or `.claude/rules/` file** from the native pass. Routing edits are walk-only with explicit per-item confirmation; CLAUDE.md changes route through `refactor-claude-md`.
- **Never delete a file** before grepping the vault for inbound references to it.
- **Never bulk-apply semantic fixes** — routing rewrites, file moves, reorgs all walk per item with the user confirming target/destination.
- **Protected zones are untouchable** — code fences, inline code, URLs, file paths, frontmatter keys, wikilinks, table delimiters, headings, dates. After any edit, re-check none were modified outside the intended change; if one was, roll back that file and set `fix_status: failed`.
- A move that would create a dead wikilink rolls back and sets `fix_status: failed`.

---

## Phase 5 — Render the report

**5.1 — Capture before/after.** Snapshot finding counts, count of unreachable notes, and folder-index coverage before fixes; re-measure after. The report's value is showing what *changed*.

**5.2 — Write the report** to the vault. Resolve the path via the role registry: a `decisions`-layer folder if one exists, else an `archive` folder, else create `audits/` at the vault root. Save as `{folder}/{YYYY-MM-DD}-vault-audit.md` — markdown, with the architectural read at the top, a before/after table, then findings with severity, path, reasoning, and final `fix_status`.

**5.3 — Optional HTML.** If the user asked for a visual dashboard, generate a single self-contained HTML file alongside the markdown, or compose the `build-dashboard` skill. Do not bundle template files into this skill.

**5.4 — Summary** (chat, after the report is saved):

```
✅ Vault discoverability audit complete.
Report: {path}
Score: {before} → {after}
{N} files audited · {applied} fixes applied · {declined} declined · {failed} failed
Unreachable notes: {orphans_before} → {orphans_after} · folder-index coverage {before}% → {after}%
Delegated: {n} CLAUDE.md / memory findings → refactor-claude-md / refactor-memory-md
```

Stop. Do not propose follow-ups.

---

## Anti-patterns

| Wrong | Why | Right |
|---|---|---|
| Assume `Context/`, `Daily/`, `Plot.md` by name | Vaults vary — name-matching misclassifies and skips folders | Run role discovery; resolve every folder through the registry by content |
| Turn a regex match straight into a finding | The skill's value is judgment — a trigger is a candidate, not a verdict | Read the folder contents, apply the reference file's criteria, then log |
| Auto-edit a CLAUDE.md to fix routing | CLAUDE.md edits need per-item human review; that is `refactor-claude-md`'s job | Surface as delegated or walk-only with per-item confirmation |
| Bulk-apply a file move or reorg | One wrong destination silently breaks inbound wikilinks | Walk every semantic fix per item; confirm destination |
| Delete a note found "obsolete" | Inbound wikilinks break silently; the note may be load-bearing | Grep for references first; archive, never delete |
| Score reorg proposals into the health number | A proposal is an opportunity, not a failure — conflating them distorts the score | Score fails and warns only; report `D.6` proposals separately |
| Re-run contradiction or theme detection here | `/challenge`, `/drift`, `/emerge` already own that — duplicating dilutes trust in both | This skill audits structure only; cross-file content checks stay with their commands |

## Error handling

| Condition | Behaviour |
|---|---|
| cwd is not a vault | Stop in Phase 0 with the `cd` instruction — never audit an arbitrary folder |
| Role discovery cannot classify a folder (low confidence) | Log it; ask the user to clarify its purpose during the walk; persist the answer |
| `refactor-claude-md` / `refactor-memory-md` not installed | Report the delegated finding as text with the sibling-skill name; do not fail the run |
| A fix touches a protected zone | Roll back that file; set `fix_status: failed` with a reason; never silently skip |
| `.claude/vault-roles.json` exists from a prior run | Load it as the baseline; only re-classify new or flagged folders — don't re-prompt |
| Vault has zero `CLAUDE.md` and zero routing table | The pass still runs; the missing routing IS the headline discoverability finding |

## Why this skill exists

A note that exists but no agent can reach from the root is invisible. A routing index that claims a folder holds X when it holds Y misdirects every session that trusts it. Those are structural problems, and no other skill in the toolkit looks for them — `/challenge` and `/drift` read note *content*, `vault-review` orchestrates *cadence*, `refactor-claude-md` fixes *one file*. This skill walks the navigation graph end to end and audits exactly one thing: can an agent find everything, and do the signposts tell the truth. Focused by design — it adds the check the toolkit lacked, and re-implements nothing it already had.

<!-- AUDIT METADATA
source: BenAI Obsidian OS plugin (os-optimizer, v3.8.0)
source_hash: a9b3bc46a93b070165ec43d67006e80880e55adc43c18501a4037a56139a52ac
audit_date: 2026-05-17
audit_grade: C (64/100) — strong patterns, weak packaging
merge_actions: extract-only — kept 1 of 9 frameworks (F9 discoverability) + role discovery; context-rot + reflection passes dropped 2026-05-17 after a first-principles ROE review found them substantially redundant with refactor-claude-md, /challenge, /drift, /emerge
superior_patterns_absorbed: 2 (discoverability walk, content-based role discovery)
-->
