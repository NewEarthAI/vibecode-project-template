# Entity Discipline — Canonical Identity Layer

**Scoped**: every continuation file authoring, every memory file authoring, every
council session synthesis, every chat reply that names a partner / person / company /
brand / product whose identity could be confused with another.

**Auto-loads on** (per `code-review-domain-routing.md` extension queued separately,
and per the seven commands referenced below): `/Master-Continuation-Prompt`,
`/prime`, `/prompt-forge`, `/daily-plan`, `/clientprojectupdate`, `/council`,
`/reflect`.

**Origin**: 2026-05-12 — session-close pointer at
`continuations/2026-05-12-SESSION-CLOSE-POINTER-CONTINUATION.md` §6.5 flagged the
failure mode where partner names get joined to arcs by prose proximity, and
compaction strips the proximity. The fix is structural: a repo-rooted entity
registry at 📁 `entities/` with one Markdown card per entity.

---

## The Principle

**Memory + continuations are organised by topic, sprint, and date — never by entity.**
Without an entity layer, partner names join to arcs by prose proximity. When the
conversation compacts, the proximity is stripped first; the bare name survives
without its bindings. Then a downstream session reads "the 2026-05-14 webinar"
and binds it to the wrong partner.

The entity registry at 📁 `entities/` is the canonical source of truth for who/what
is who. Every continuation, memory file, council session, and ROADMAP item that
names a partner / person / company / brand / product **MUST** either:

- Link to the entity card with `[[wikilink]]` syntax in prose, OR
- Resolve the name against the registry before authoring (and disambiguate if confused)

---

## The Six Rules

### Rule 1 — Repo-rooted, never tool-rooted

The registry lives at 📁 `entities/` at the **repo root**, not in `.claude/` or any
other tool-specific path. This is **non-negotiable**.

Why: portability. The registry must read cleanly in Claude Code today, Cursor
tomorrow, Obsidian / Codex / Cline / any future tool. Tools may layer their own
caches over it; the registry stays portable.

Anti-pattern: moving cards into `.claude/entities/` or `~/.claude/projects/<slug>/memory/entities/`.
Doing so breaks portability and re-introduces the failure mode this layer prevents.

### Rule 2 — One card per entity; one canonical name per card

Every entity gets **exactly one card** at `entities/<slug>.md`. The frontmatter
`canonical_name:` field is the **single canonical form**. Aliases live in the
`aliases:` array.

If you find two cards for the same entity: merge. If you find one card that
should be two (e.g., a brand was masquerading as the parent company): split,
and add explicit `is_not:` clauses in both.

### Rule 3 — Frontmatter is the machine-parseable contract

Every card carries this frontmatter shape (deviations allowed only when explicitly
not applicable):

```yaml
---
canonical_name: <Name>
type: person | company | brand | product | partnership
aliases: []
role: <one-sentence>
relationships: {}
active_arcs: []
key_dates: {}
sensitive: false  # true = card body intentionally minimal; sensitive specifics live elsewhere
is_not: []        # explicit confusion-risk disambiguations
---
```

The `is_not:` field is **load-bearing**. It is the explicit anti-confusion clause
that prevents downstream sessions from binding a name to the wrong card. Use it
liberally for any entity whose name resembles another entity's name.

### Rule 4 — Wikilinks in prose, every time

Inside card body prose AND in continuation files / memory files / council sessions,
reference other entities via `[[wikilink]]` syntax:

```markdown
[[Trevor]] coordinates with [[Chris]] via WhatsApp for the [[HomePros]] arc.
```

NOT:

```markdown
Trevor coordinates with Chris via WhatsApp for the HomePros arc.
```

The wikilinks render as a relationship graph in Obsidian / Graphify / any
graph-aware tool. They also make the entity layer greppable: `grep -r '\[\[Trevor\]\]'`
surfaces every place Trevor appears.

### Rule 5 — Continuation frontmatter declares entities

Every master continuation file's YAML frontmatter MUST carry an `entities:` block
listing the partners / people / arcs the file touches. Each line is a wikilink
to the canonical registry card.

```yaml
---
title: HomePros Podio V1 — Visible-Value Completion
type: master-continuation
entities:
  - "[[Trevor]]"
  - "[[HomePros]]"
  - "[[BuyBox]]"
  - "[[Chris]]"  # business-side relationship lead
---
```

This is **write-time discipline**. The author lists entities before the body is
composed, which forces them to look up the canonical cards first. The frontmatter
survives compaction because it's machine-parseable, not prose.

### Rule 6 — Sensitive specifics stay out of cards

Some entity details are sensitive (co-owner names, profit-attribution specifics,
private partnership terms). These do **NOT** belong on the card body. Mark the
card `sensitive: true` if applicable and write minimal prose; specifics live in
chat history or a sensitive-context file outside the repo.

Example (per `project_buybox_llc_corporate_structure_queued.md` precedent):
> Sensitive specifics (co-owner names on Chris's side, fairness concerns,
> profit-attribution anxieties) live in 2026-05-09 chat history only — NOT
> persisted to memory.

---

## How to use the registry

### Before authoring any continuation / memory / council file

1. **Grep first**: `grep -r '\[\[<Name>\]\]' entities/` to verify the canonical card exists
2. **Read the card**: read the frontmatter (especially `is_not:`) to ensure you're
   binding the right entity
3. **Link in prose**: use `[[wikilinks]]` to reference the entity throughout
4. **Update the card** if you learn something new about the entity (key dates,
   active arcs, new aliases, new confusion risks)

### When you discover an unbound entity

If a continuation / memory file names a partner / person / company that doesn't
yet have a card:

1. Create the card at `entities/<slug>.md` following the frontmatter contract
2. Update `entities/README.md`'s index section
3. Link the new card from the file that surfaced the gap

### When you discover a confusion risk

If two entities have similar names (e.g., two people both named "Chris") OR a
brand is being conflated with its parent company:

1. Add an explicit `is_not:` clause to BOTH cards
2. Write a body section under "Confusion-risk pairs" naming the other entity
3. Update any continuation / memory file currently using the ambiguous name

---

## What this rule is NOT

- **Not a list of every property / fixture / test record** — entities are
  partners, people, companies, brands, products. Real-estate addresses live in
  the database. Test fixtures don't deserve cards.
- **Not a substitute for ROADMAP / continuations / memory** — the registry is
  the IDENTITY layer; the arc-state layer lives in those other files
- **Not retroactive on shipped continuations** — the rule applies forward-only
  from 2026-05-12. Existing continuations don't need rewriting; they can be
  updated lazily as they're touched

---

## Composes with

- 📄 `entities/README.md` — the registry index + how-to
- 📄 `.claude/skills/master-continuation-prompt/SKILL.md` — every continuation
  carries an `entities:` frontmatter block (Rule 5)
- Memory feedback files in `~/.claude/projects/<slug>/memory/` — when a memory
  entry names an entity, link to its card
- Future Obsidian Graphify integration — reads `entities/` directly; wikilinks
  render as the relationship graph
- Future entity-registry CI check (queued separately) — greps continuations for
  named entities that don't have cards, fails the build until added

---

## Failure precedent

**2026-05-12 (this rule's birthday)**: tonight's HomePros Podio V1 ship arc
nearly conflated "HomePros / Trevor" with "Killer Bee / iSpeed2Lead / Yuri"
because the 2026-05-14 webinar date was discussed without an entity tag.
Both partnerships are active, both have webinar-adjacent dates, both use
BuyBox. Without an entity layer, the names floated free of their bindings
and a downstream session could have routed HomePros work into Killer Bee's
deadline window (or vice versa). The session-close pointer §6.5 flagged the
gap; this rule + the 14 starter entity cards close it structurally.
