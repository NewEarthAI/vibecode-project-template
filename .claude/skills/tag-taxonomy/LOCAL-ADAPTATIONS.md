# Local Adaptations — tag-taxonomy

> **First-install note**: this file is a template. When you install this skill, replace the per-project values (vault root / quarantine subpath, sensitive-info patterns, compose-with skill names) and remove this preamble. `SKILL.md` + any `references/` are verbatim upstream — keep them byte-identical so you can `diff` against future upstream pulls. For the two write-heavy skills (cross-linker, tag-taxonomy) the quarantine write-boundary is UNENFORCED prose until you pin the vault root + add a path-guard hook — read the override below before any run.

**Upstream source**: `https://github.com/ar9av/obsidian-wiki/tree/main/.skills/tag-taxonomy`
**Imported**: 2026-05-22 (Phase 3 of the obsidian-wiki skill-audit queue — see `continuations/OBSIDIAN-INGEST-PROD-RUN-AND-SKILL-AUDIT-QUEUE-MASTER-CONTINUATION-2026-05-21.md` §12)
**Upstream version pin**: commit `6f20faaa0f3b53fa8917816baf5ccbb36f93da72` (`main` HEAD at import). Re-pull via `gh api repos/ar9av/obsidian-wiki/contents/.skills/tag-taxonomy/SKILL.md?ref=6f20faaa0f3b53fa8917816baf5ccbb36f93da72 -H "Accept: application/vnd.github.raw+json" > SKILL.md`. Move the pin forward deliberately + `git diff` the delta as a code review — never auto-fetch bare `main`.
**Audit grade**: B+ (fills a real gap — controlled-vocabulary tag enforcement — with no equivalent in our stack).
**Import verification (2026-05-22)**: `validate.sh` → PASS (10 passed, 5 warnings). No hardcoded IDs, no secrets. Skill registers + loads correctly (confirmed).

`SKILL.md` is kept verbatim from upstream. All project-specific overrides live HERE.

## ⚠️ UNENFORCED CONTROL — INSTALL-ONLY UNTIL GATED (read before any run)

This skill is **WRITE-HEAVY** (it rewrites page frontmatter to normalise tags) and is **INSTALLED, NOT YET CLEARED FOR PRODUCTION**. The quarantine write-boundary (Override 3) is **advisory prose in this sidecar file** — the verbatim `SKILL.md` never references it and instructs the upstream config walk-up. No PreToolUse hook enforces the boundary. Until the invoker explicitly pins `OBSIDIAN_VAULT_PATH` to the quarantine + completes the First-Run Verification below, OR a path-guard hook exists, treat as install-only and DO NOT run. (Code-council 2026-05-22, 4-agent consensus.)

## What this skill is to us

`tag-taxonomy` enforces a controlled tag vocabulary across the wiki, normalising free-form tags to a canonical list. We have PARA folders + frontmatter conventions but NO controlled-vocabulary tag-enforcement skill — this is the gap it fills. It depends on `llm-wiki/SKILL.md` (absorbed in the same PR) for the **Config Resolution Protocol** only (its `SKILL.md` references that protocol but NOT the Retrieval Primitives table — tag-taxonomy works on frontmatter tag fields, not page-content navigation; corrected per code-council 2026-05-22 spec finding).

It **composes with**, does not replace:
- PARA structure — PARA is the FOLDER taxonomy; tags are the CROSS-CUTTING taxonomy. Orthogonal, complementary.
- `vault-optimizer` — structural discoverability, not tag hygiene.

## Override 1 — Vault root is FIXED to the PARA Fleeting quarantine

Same as `llm-wiki/LOCAL-ADAPTATIONS.md` Override 1: `OBSIDIAN_VAULT_PATH = <repo>/agency/vault/05 - Fleeting/wiki-ingest/`. We do NOT use `.env` / `~/.obsidian-wiki/config`.

**Path note**: quote the space — `"agency/vault/05 - Fleeting/wiki-ingest/"`.

## Override 2 — Taxonomy file location + first-run creation

**Upstream behaviour**: reads/writes the canonical tag list at `$OBSIDIAN_VAULT_PATH/_meta/taxonomy.md`.

**Our override**: with the vault root pinned to the quarantine, the taxonomy file lives at `agency/vault/05 - Fleeting/wiki-ingest/_meta/taxonomy.md`. It does NOT exist yet — on first invocation, create it (the skill's own bootstrap path handles an absent taxonomy by proposing an initial vocabulary). Seed it from the entity/concept categories `claude-history-ingest` already produces (projects / concepts / entities / skills / synthesis) rather than inventing a generic taxonomy.

## Override 3 — Scope: quarantine-only, never curated PARA

tag-taxonomy is write-heavy (it rewrites page frontmatter to normalise tags). It MUST restrict writes to the quarantine and NEVER rewrite tags on curated PARA notes (`00`–`07`, `99`). Curated notes carry human-chosen tags; auto-normalising them would corrupt the human layer.

## Override 4 — Sensitive-info skip per Agency-Main guardrails

Composes with upstream — never emit secrets (`sk-…`, `ghp_…`, `AKIA…`, `AIza…`, `xoxb-…`, `xoxp-…`) or `.env*` content into the taxonomy file or any page frontmatter. (Low risk for a tag list, but stated for consistency across the absorbed set.)

## Override 5 — QMD integration is DISABLED (not in our stack)

The verbatim `SKILL.md` runs `${QMD_CLI:-qmd}` shell commands. QMD is NOT installed; an unset/wrong `QMD_CLI` is an arbitrary-binary surface in the Bash tool. **Skip the QMD block unconditionally**; treat `QMD_WIKI_COLLECTION` as permanently unset so the skill's own "skip if empty" guard fires. (Code-council 2026-05-22 security finding.)

## Override 6 — First-run verification (MANDATORY before first real run)

Before trusting this skill on the quarantine: dry-run on a throwaway copy. (1) Copy 2-3 pages + an empty `_meta/` to `/tmp/tag-taxonomy-smoke/`, point the resolved `OBSIDIAN_VAULT_PATH` there. (2) Confirm (a) resolved root = smoke dir (not PARA, not `agency/vault/` root), (b) the absent-taxonomy bootstrap (Override 2) creates `_meta/taxonomy.md` seeded from the claude-history-ingest categories — NOT a silent skip or an ad-hoc vocabulary, (c) ZERO frontmatter rewrites land outside the smoke dir. (3) Only then run against the real quarantine with the path explicitly pinned. Mirrors PR #49 smoke-before-batch.
