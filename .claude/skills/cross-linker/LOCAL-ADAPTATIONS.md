# Local Adaptations — cross-linker

> **First-install note**: this file is a template. When you install this skill, replace the per-project values (vault root / quarantine subpath, sensitive-info patterns, compose-with skill names) and remove this preamble. `SKILL.md` + any `references/` are verbatim upstream — keep them byte-identical so you can `diff` against future upstream pulls. For the two write-heavy skills (cross-linker, tag-taxonomy) the quarantine write-boundary is UNENFORCED prose until you pin the vault root + add a path-guard hook — read the override below before any run.

**Upstream source**: `https://github.com/ar9av/obsidian-wiki/tree/main/.skills/cross-linker`
**Imported**: 2026-05-22 (Phase 3 of the obsidian-wiki skill-audit queue — see `continuations/OBSIDIAN-INGEST-PROD-RUN-AND-SKILL-AUDIT-QUEUE-MASTER-CONTINUATION-2026-05-21.md` §12)
**Upstream version pin**: commit `6f20faaa0f3b53fa8917816baf5ccbb36f93da72` (`main` HEAD at import). Re-pull via `gh api repos/ar9av/obsidian-wiki/contents/.skills/cross-linker/SKILL.md?ref=6f20faaa0f3b53fa8917816baf5ccbb36f93da72 -H "Accept: application/vnd.github.raw+json" > SKILL.md`. To move the pin forward, bump to a NEW SHA deliberately and `git diff` the SKILL.md delta as a code review — never auto-fetch bare `main`.
**Audit grade**: A− (fills a real gap — automated `[[wikilink]]` weaving — with no equivalent in our stack).
**Import verification (2026-05-22)**: `validate.sh` → FAIL (1 vague-term match in upstream prose) — accepted as upstream property, not introduced by us. No hardcoded IDs, no secrets. Skill registers + loads correctly (confirmed).

`SKILL.md` is kept verbatim from upstream. All project-specific overrides live HERE.

## ⚠️ UNENFORCED CONTROL — INSTALL-ONLY UNTIL GATED (read before any run)

This skill is **WRITE-HEAVY** and is **INSTALLED, NOT YET CLEARED FOR PRODUCTION**. The quarantine write-boundary below (Override 3) is **advisory prose in this sidecar file** — the verbatim `SKILL.md` never references it and instead instructs the upstream config walk-up (`.env` → `~/.obsidian-wiki/config` → prompt setup). No PreToolUse hook currently enforces the boundary. Therefore, until ONE of these is true, treat the skill as install-only and DO NOT run it:

1. The invoker explicitly sets `OBSIDIAN_VAULT_PATH="<repo>/agency/vault/05 - Fleeting/wiki-ingest/"` AND confirms the resolved root is the quarantine BEFORE the first write, AND completes the First-Run Verification below; OR
2. A PreToolUse Write/Edit path-guard hook exists that hard-blocks any write resolving under `agency/vault/0[0-7]` or `agency/vault/99` for this skill (build it before unattended/auto-triggered use).

Surfaced by code-council 2026-05-22 (4-agent consensus): the default verbatim path could misroute a write-heavy skill onto curated PARA. The current machine is verified-safe today (no conflicting `.env`, no global config), but that is environmental luck, not a mechanism.

## What this skill is to us

`cross-linker` scans the wiki and inserts missing `[[wikilinks]]` between pages that should reference each other. This directly serves the `CLAUDE.md` doctrine that **Obsidian wikilinks ARE part of the agent retrieval path** (`vault-sync.sh` → `knowledge_items`). It is a write-heavy skill — it modifies pages. It depends on `llm-wiki/SKILL.md` (absorbed in the same PR) for the Config Resolution Protocol + Retrieval Primitives table.

It **composes with**, does not replace:
- `vault-optimizer` — discoverability audit (routing tables, reachability). `cross-linker` adds links; `vault-optimizer` checks structure. Different jobs.
- `/emerge` `/drift` `/trace` — theme/connection surfacing for humans. `cross-linker` actually writes the links.

## Override 1 — Vault root is FIXED to the PARA Fleeting quarantine

Same as `llm-wiki/LOCAL-ADAPTATIONS.md` Override 1: `OBSIDIAN_VAULT_PATH = <repo>/agency/vault/05 - Fleeting/wiki-ingest/`. We do NOT use the `.env` / `~/.obsidian-wiki/config` resolution. cross-linker operates ONLY on the quarantine — never on curated PARA folders (`01 - Projects`, `03 - Resources`, etc.), which are human-curated and must not be auto-rewritten.

**Path note**: quote the space — `"agency/vault/05 - Fleeting/wiki-ingest/"`.

## Override 2 — Link format locked to `wikilink`

Per `CLAUDE.md` retrieval contract. Do not emit `markdown`-style links.

## Override 3 — Write-safety: quarantine-only, never curated PARA

This is the binding safety override. cross-linker is write-heavy. It MUST restrict its writes to the quarantine. It must NEVER add links into `00 - MOCs`, `01 - Projects`, `02 - Areas`, `03 - Resources`, `04 - Permanent`, `07 - Archives`, or `99 - Meta` — those are human-curated. Auto-linking curated notes would corrupt the human layer. If a future promotion path moves a page out of the quarantine into PARA, cross-linking of that page becomes a human/curated decision, out of this skill's scope.

## Override 4 — Token discipline: registry-build is efficient, link-detection is NOT (corrected 2026-05-22)

Upstream Step 1 (build the registry) greps frontmatter only — efficient, matches `.claude/rules/` token discipline. **But Step 2 (`SKILL.md` line 50, "Read the full content") issues an UNCONDITIONAL full read of every page** — there is no plausibility filter enforced in the procedure (the filter exists only as guidance in `llm-wiki/SKILL.md`'s Retrieval Primitives table). On a large quarantine (200+ pages) this is an O(n) full-vault read — ~40-80k tokens of I/O per invocation, scaling linearly. (Earlier drafts of this override overstated upstream as "only full-reads plausible targets" — that is the INTENT, not what Step 2 enforces. Corrected per code-council 2026-05-22 performance finding.)

**Our guidance**: at current near-empty quarantine scale this is trivial. Before the quarantine grows large, insert a candidate filter between Step 1 and Step 2 — only full-read pages whose title/summary/tags share vocabulary with another page — converting the O(n) read into O(k). Do NOT trust the "token-disciplined" framing for large vaults.

## Override 5 — QMD integration is DISABLED (not in our stack)

The verbatim `SKILL.md` "QMD Refresh" block runs `${QMD_CLI:-qmd} update/embed/ls/get` shell commands. QMD is NOT installed in our environment, and an unset/wrong `QMD_CLI` (or a `qmd` earlier on `$PATH`) is an arbitrary-binary-execution surface in the Bash tool. **Skip the QMD block unconditionally** — do not run any `qmd` command. Treat `QMD_WIKI_COLLECTION` as permanently unset so the skill's own "skip if empty" guard fires every time. (Per code-council 2026-05-22 security finding.)

## Override 6 — First-run verification (MANDATORY before first real run)

Before trusting this skill on the quarantine for the first time, dry-run on a throwaway copy:
1. Copy 2-3 quarantine pages to `/tmp/cross-linker-smoke/` and point the resolved `OBSIDIAN_VAULT_PATH` there.
2. Run the skill; confirm (a) the resolved root equals the smoke dir (NOT a PARA folder, NOT `agency/vault/` root), (b) ZERO writes land outside the smoke dir, (c) the inserted links are well-formed `[[wikilinks]]`.
3. Only after a clean dry-run, run against the real quarantine with `OBSIDIAN_VAULT_PATH` explicitly pinned. Mirrors the `claude-history-ingest` PR #49 smoke-before-batch precedent.
