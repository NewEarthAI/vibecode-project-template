# Entity Registry — Canonical Identity Doctrine

This folder is the **single source of truth** for who/what is who in your project.
Every partner, person, company, brand, venture, and client that shows up across
continuations, memory files, council sessions, and ROADMAP gets exactly **one card**
here.

## Why this exists

Memory + continuations are organised by topic, sprint, and date — never by entity.
Partner names get joined to arcs by prose proximity. When the conversation compacts,
the proximity is stripped first; the bare name survives without its bindings.

The failure mode this prevents (real precedent, 2026-05-12):
> A dated event got compressed without an entity tag.
> Three partner names — each with a different role + relationship — started reading
> as interchangeable in the conflated prose. They were not.

The fix is structural: every entity gets one card with an explicit `is_not:` clause.

## How to use this registry

**Reading**: when a continuation, council session, or memory file mentions a partner,
client, or person, grep this folder before assuming. The card carries canonical name +
aliases + role + relationships + active arcs + key dates + explicit `is_not:` clauses.

**Writing**: when authoring a continuation that touches an entity, link to the card
with `[[wikilinks]]` (graph-renderable) instead of repeating prose context.

**Adding a new entity**: model your file on an existing card (or use `_template.md`
when it lands). Frontmatter is non-negotiable; body is free-form prose.

## Portability invariant

This folder lives at the **repo root**, not in `.claude/`. It is intentionally
tool-agnostic — repo-rooted Markdown reads cleanly in Claude Code, Cursor,
Obsidian, Codex, or any future tool. Tools layer their own caches over it;
the registry stays portable.

## Frontmatter contract (non-negotiable — five required fields)

```yaml
---
canonical_name: {Single canonical form — used everywhere}
type: person | company | venture | client | brand | product | partnership
aliases: [list of aliases — may be empty]
role: {one-sentence description of role}
relationships:
  {relation-name}: ["[[Other Entity]]"]
active_arcs:
  - {arc-1}
  - {arc-2}
key_dates:
  {event-slug}: YYYY-MM-DD
sensitive: false  # set true if card contains PII / financial detail
is_not:
  - "[[Other Entity]] (one-line disambiguation)"
---
```

## What goes here

- **People** — anyone you work with whose name appears in operational prose
- **Companies / legal entities** — registered businesses with their own identity
- **Brands** — marketing names that may or may not be separate legal entities
- **Ventures** — internal projects you own (sub-products, sub-brands)
- **Clients** — external businesses you do work for
- **Partnerships** — explicit JV / referral / exclusive agreements (when load-bearing)

## What does NOT go here

- **Properties** (real estate addresses) — they belong in the database, not here
- **Internal codenames** (KI.1, Spec 24, Phase 4.8) — they belong in roadmap / continuations
- **Tools / vendors that aren't load-bearing** (Vercel, Supabase, GitHub) — already in CLAUDE.md
- **Ephemeral test items** (smoke fixtures, PleaseDelete records) — they don't deserve cards

## Composes with

- 📄 `.claude/rules/entity-discipline.md` — the doctrine that auto-loads on
  seven surfaces (Master-Continuation-Prompt, prime, prompt-forge, daily-plan,
  clientprojectupdate, council, reflect)
- 📄 `.claude/skills/master-continuation-prompt/SKILL.md` — continuation files
  carry an `entities:` block in frontmatter pointing at cards here
- Future graph visualiser (Obsidian native graph view + Graphify when it lands)
  — reads this folder directly; wikilinks render as a relationship graph

## Index

_(No entities yet — add cards here as your project grows. Each card lives at
`entities/<slug>.md` with the frontmatter contract above.)_

### People

- _(none yet)_

### Companies / brands / products / ventures

- _(none yet)_

### Clients

- _(none yet)_

### Partnerships

- _(none yet)_
