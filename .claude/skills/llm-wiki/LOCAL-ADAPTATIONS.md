# Local Adaptations — llm-wiki

> **First-install note**: this file is a template. When you install this skill, replace the per-project values (vault root / quarantine subpath, sensitive-info patterns, compose-with skill names) and remove this preamble. `SKILL.md` + any `references/` are verbatim upstream — keep them byte-identical so you can `diff` against future upstream pulls. For the two write-heavy skills (cross-linker, tag-taxonomy) the quarantine write-boundary is UNENFORCED prose until you pin the vault root + add a path-guard hook — read the override below before any run.

**Upstream source**: `https://github.com/ar9av/obsidian-wiki/tree/main/.skills/llm-wiki`
**Imported**: 2026-05-22 (Phase 3 of the obsidian-wiki skill-audit queue — see `continuations/OBSIDIAN-INGEST-PROD-RUN-AND-SKILL-AUDIT-QUEUE-MASTER-CONTINUATION-2026-05-21.md` §12 + `agency/memory/project_ecc-and-obsidian-wiki-evaluation-2026-05-21.md`)
**Upstream version pin**: commit `6f20faaa0f3b53fa8917816baf5ccbb36f93da72` (`main` HEAD at import). Re-pull via `gh api repos/ar9av/obsidian-wiki/contents/.skills/llm-wiki/SKILL.md?ref=6f20faaa0f3b53fa8917816baf5ccbb36f93da72 -H "Accept: application/vnd.github.raw+json" > SKILL.md`. Move the pin forward deliberately + `git diff` the delta as a code review — never auto-fetch bare `main`.
**Audit grade**: A (keystone pattern + shared protocols). Absorbed alongside `cross-linker` (which references this skill's Config Resolution Protocol **and** Retrieval Primitives) + `tag-taxonomy` (which references the Config Resolution Protocol **only**) as a coherent set.
**Import verification (2026-05-22)**: `validate.sh` → FAIL (526 lines > 500 soft cap) — accepted as upstream property; this is the keystone theory doc, not trimmed per the verbatim contract. No hardcoded IDs, no secrets. Skill registers + loads correctly (confirmed).

This file documents the **Agency-Main-specific overrides**. `SKILL.md` and `references/` are kept verbatim from upstream so we can `diff` against future updates without losing context. All project-specific overrides live HERE.

## What this skill is to us

`llm-wiki` is the **theory / keystone** layer — Andrej Karpathy's LLM Wiki three-layer pattern (raw sources → wiki → schema) plus the shared protocols (Config Resolution, Retrieval Primitives, Link Format) that the other obsidian-wiki operational skills reference. It is NOT a write-heavy operation; it is the doctrine other skills compose against.

It **composes with**, does not replace:
- `obsidian-second-brain` — our operational vault doctrine (PARA structure, sync discipline). `llm-wiki` is the "why the wiki is a compiled artefact" pattern layer beneath it.
- `obsidian-vault-autopilot` — the real-time capture/sync layer.
- `claude-history-ingest` (PR #49) — the ingest skill that produces obsidian-wiki-format pages in our quarantine; `llm-wiki` is its theory.
- `vault-optimizer` / `vault-review` / `/trace` `/drift` `/emerge` — our retrieval + cadence skills.

## Override 1 — Vault root is FIXED to the PARA Fleeting quarantine (no obsidian-wiki config system)

**Upstream behaviour**: resolves `OBSIDIAN_VAULT_PATH` via the Config Resolution Protocol — walk up CWD for a `.env` containing `OBSIDIAN_VAULT_PATH`, then fall back to `~/.obsidian-wiki/config`, else prompt setup.

**Our override**: we do NOT install the obsidian-wiki config system (`.env` / `~/.obsidian-wiki/config`). The wiki root is FIXED to `agency/vault/05 - Fleeting/wiki-ingest/` — the same quarantine `claude-history-ingest` writes to (its `LOCAL-ADAPTATIONS.md` Override 1). When any obsidian-wiki skill resolves config, treat `OBSIDIAN_VAULT_PATH = <repo>/agency/vault/05 - Fleeting/wiki-ingest/`.

**Reason**: our vault is the PARA-structured `agency/vault/`. A loose `.env` walk-up could resolve to the wrong root, and `~/.obsidian-wiki/config` does not exist on our machines. Pinning the root to the quarantine keeps obsidian-wiki-format machinery isolated from curated PARA folders, exactly as `claude-history-ingest` already does.

**Path note**: the quarantine path contains a space (`05 - Fleeting`). Always quote in bash: `"agency/vault/05 - Fleeting/wiki-ingest/"`.

## Override 2 — Link format is `wikilink` (locked, not configurable)

**Upstream behaviour**: `OBSIDIAN_LINK_FORMAT` defaults to `wikilink`, configurable to `markdown`.

**Our override**: locked to `wikilink`. Per `CLAUDE.md`, Obsidian wikilinks ARE part of the agent retrieval path (via `vault-sync.sh` → `knowledge_items`). Markdown-style links would break that retrieval contract. Do not switch to `markdown`.

## Override 3 — Sensitive-info skip per Agency-Main guardrails

Composes with upstream's secret skip — also honour `.claude/rules/operational-guardrails.md`: never emit any value matching `sk-…`, `ghp_…`, `AKIA…`, `AIza…`, `xoxb-…`, `xoxp-…`; never emit text from `.env*`; never emit raw n8n webhook URLs or Supabase service-role keys. When uncertain, default to `^[ambiguous]` provenance + redact.

## Override 4 — Sources directory

**Upstream**: `OBSIDIAN_SOURCES_DIR` (where raw documents live).
**Our override**: our raw sources are the Claude Code session history at `~/.claude/projects/<encoded-cwd>/` (read by `claude-history-ingest`) and the agency memory + vault. There is no separate sources-dir to configure; treat the ingest skills' inputs as the source layer.

## Override 5 — QMD integration is DISABLED (not in our stack)

The verbatim `SKILL.md` references QMD (`${QMD_CLI:-qmd}`) for embedding/retrieval. QMD is NOT installed in our environment. Skip any QMD command; treat `QMD_WIKI_COLLECTION` as permanently unset. This skill is the theory layer (not write-heavy), so the surface is lower than for `cross-linker`/`tag-taxonomy`, but the override is stated for consistency across the absorbed set. (Code-council 2026-05-22 security finding.)
