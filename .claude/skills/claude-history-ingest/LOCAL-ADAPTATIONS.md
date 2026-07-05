# Local Adaptations — claude-history-ingest

> **First-install note**: this file is a template. When you install this skill in a project, replace the per-project values (vault root, quarantine subpath, sensitive-info patterns) and remove this preamble.

**Upstream source**: `https://github.com/ar9av/obsidian-wiki/tree/main/.skills/claude-history-ingest`
**Upstream pin**: HEAD of `main` at template-pull time. Refresh upstream verbatim files via:
```bash
gh api repos/ar9av/obsidian-wiki/contents/.skills/claude-history-ingest/SKILL.md \
  --jq '.content' | base64 -d > .claude/skills/claude-history-ingest/SKILL.md
gh api repos/ar9av/obsidian-wiki/contents/.skills/claude-history-ingest/references/claude-data-format.md \
  --jq '.content' | base64 -d > .claude/skills/claude-history-ingest/references/claude-data-format.md
```

This file documents the **per-project overrides** to the upstream skill. `SKILL.md` and `references/` are kept verbatim from upstream so you can `diff` against future updates without losing context.

## When to install this skill

Install when your project has either:
- An Obsidian vault (or a vault-like markdown knowledge base) where session insights should land as structured wiki pages.
- A standing need to distil prior Claude Code conversations into searchable, linkable knowledge instead of letting them rot in `~/.claude/projects/<encoded-cwd>/`.

The skill is a **pure file transform** — it reads JSONL session transcripts + markdown memory files from disk and writes distilled wiki pages. No LLM API call required; the in-session Claude IS the execution engine.

## Override 1 — Vault destination MUST be quarantined per project

**Upstream behaviour**: writes to vault root with directory schema `projects/<name>/`, `concepts/`, `entities/`, `skills/`, `synthesis/`.

**Why override**: most projects use a structured vault layout (PARA, Johnny Decimal, custom) that the upstream schema would collide with. Quarantining keeps the skill's output in a designated zone where humans can review and promote into the curated structure later.

**How to override**: edit the SKILL.md's Phase 1 (Configuration & Survey) destination — OR set the runtime config — to write under:

```
{{your_vault_root}}/{{quarantine_subpath}}/
```

Recommended `{{quarantine_subpath}}` values by vault style:
- **PARA**: `05 - Fleeting/wiki-ingest/` (Fleeting = the right home for raw distillation)
- **Johnny Decimal**: a dedicated `90-99 Ingest/91 wiki-ingest/` zone
- **Custom**: any folder named `_ingest/` or `inbox/wiki/` — the principle is: NOT a curated knowledge zone

Under the quarantine path, retain the upstream schema (`projects/<name>/<name>.md`, `concepts/`, `entities/`, `skills/`, `synthesis/`). The schema itself is sound; only the root path needs adapting.

**Promotion path** (out of scope for V1): a separate `vault-promote` skill or manual review pass moves wiki pages from the quarantine into curated folders once they've been validated.

## Override 2 — Sensitive-info skip extends to your project's rules

**Upstream behaviour**: skip secrets / API keys / passwords / tokens.

**Compose with your project's operational rules**. If your project has a `.claude/rules/operational-guardrails.md` (this template ships one), extend the upstream skip with:

- Never emit any value matching `sk-…`, `ghp_…`, `AKIA…`, `AIza…`, `xoxb-…`, `xoxp-…`
- Never emit any text from `.env*` files
- Never emit raw webhook URLs, raw service role keys, or raw API tokens of any kind
- When uncertain, default to `^[ambiguous]` provenance + redact the specific value

Add any project-specific sensitive patterns (internal client identifiers, partner names, raw production URLs) to this list during install.

## Override 3 — Composition with existing context-load hooks

This template ships several SessionStart / Stop hooks that touch the vault and memory:

- `.claude/hooks/sessionstart-context-aggregator.sh` — loads vault + memory context INTO each new session
- `.claude/hooks/vault-capture.sh` — captures session artifacts to the vault in real time
- `.claude/hooks/session-summarizer.sh` — writes session-end summaries

`claude-history-ingest` runs **on-demand**, NOT on every session. Wire it in via either:

- **Manual invocation** when you want to mine prior sessions ("ingest my last week of Claude history")
- **Scheduled cron / batch** — weekly job that processes the prior N days of session JSONLs into the quarantine
- **Composing with autovibe** — a future Phase X step that runs ingestion after every ship-complete

It is **idempotent** (append mode default — checks `.manifest.json` modification timestamps and skips files already ingested unless newer). Safe to run repeatedly.

## What this skill does NOT do (clarifying scope)

- Does NOT replace `vault-capture.sh` (real-time artifact capture is a different layer).
- Does NOT replace `sessionstart-context-aggregator.sh` (loading context INTO sessions is the reverse direction).
- Does NOT modify `~/.claude/projects/<encoded-cwd>/memory/` — that's the curated personal memory layer; this skill writes only to the vault quarantine.
- Does NOT call any external LLM API — pure file transform; runs in the in-session Claude.

## Per-project install checklist

When you bring this skill into a project, verify each:

1. [ ] Vault root path identified and quarantine subpath chosen (per Override 1)
2. [ ] SKILL.md's Phase 1 destination edited OR a runtime config flag exists to point at the quarantine
3. [ ] Sensitive-info skip list extended with your project's specific patterns (per Override 2)
4. [ ] Existing Obsidian / vault hooks reviewed for composition (per Override 3) — no double-write conflicts
5. [ ] First smoke run against ONE memory file (or one small session JSONL) to verify schema conformance before any batch run
6. [ ] Quarantine folder created in the vault with a `.gitkeep` so the directory commits even when empty

## See Also

- `.claude/rules/operational-guardrails.md` — extends Override 2's sensitive-info skip
- `.claude/hooks/sessionstart-context-aggregator.sh` — the reverse-direction context loader
- `.claude/skills/obsidian-second-brain/` (if installed) — vault operations primitives
- `references/claude-data-format.md` — upstream's detailed format spec for `~/.claude/projects/` data
