---
name: ki-vault
description: |
  KI Pipeline vault deposit skill. Invoked via SSH-Execute when a CROSSREF action
  of type vault_deposit is approved. Creates a properly structured Obsidian vault note
  from KI content, following the Second Brain layer conventions.
  Use when: KI action_type is "vault_deposit".
version: 1.0
classification: encoded-preference
template_managed: true
---

# ki-vault — Obsidian Vault Deposit

## Context

You are being invoked by the **KI (Knowledge Intelligence) pipeline**. A human approved a vault deposit action — meaning content should be saved into the Obsidian Second Brain vault for long-term knowledge retention and pattern emergence.

## Input Format

The prompt contains structured KI context:

```
Deposit to Obsidian vault: {title}

KI Context:
- Job: KI-YYYYMMDD-XXXXXX
- Source: {url}
- Crossref Score: {0-100}
- Action Type: vault_deposit
- Target: {profile_slug}

{description — content to deposit}
```

## Instructions

1. **Locate the vault** — Check for `.claude/obsidian-second-brain.local.md` to find the vault path. If not found, check common paths: `~/Documents/Obsidian Vault/`, `~/obsidian/`
2. **Determine the right folder** based on content type:
   - `research/` — Technical research, tool evaluations, industry analysis
   - `ideas/` — New ideas, opportunities, speculative thinking
   - `ventures/{slug}/` — Content specific to a venture (the app-ai, golden-pocket, etc.)
   - `strategy/` — Strategic insights, market analysis, competitive intelligence
3. **Create the vault note** with proper frontmatter:

```markdown
---
title: "{title}"
date: {YYYY-MM-DD}
tags:
  - ki-deposit
  - {profile_slug}
  - {relevant topic tags}
source: "{url}"
ki_job: "{job_id}"
status: seedling
---

# {Title}

## Source
[{source title}]({url})

## Key Takeaways
{Distilled key points from the KI content}

## Relevance to {Project Name}
{Why this was flagged, how it connects to the project}

## Open Questions
- {Questions this raises for further exploration}

## Connections
- [[Related vault note if identifiable]]
```

4. **Update MOC if applicable** — If there's a relevant Map of Contents file, add a link

## Output Format

Output a fenced JSON block:

```json
{
  "status": "deposited",
  "vault_path": "/path/to/vault/folder/note-name.md",
  "folder": "research|ideas|ventures/{slug}|strategy",
  "tags": ["ki-deposit", "tag1", "tag2"],
  "connections": ["Any existing vault notes this connects to"],
  "moc_updated": true
}
```

## Guidelines

- Note filenames: `YYYY-MM-DD-kebab-case-title.md`
- Use `status: seedling` for new deposits (they'll be reviewed during /drift cycles)
- Keep the note concise — distill, don't dump raw content
- Add meaningful tags that help with future /drift and /emerge analysis
- If the vault path can't be found, output an error status instead of guessing
- Don't create duplicate notes — search for existing notes with similar titles first
