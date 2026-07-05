# Vibe Coding Master Template — Changelog

All notable changes to the template are documented here. `/update-latest` reads
this file to show you what's new since your last sync.

---

## 2026-07-05 — Curation pass: leaner, clearer, and a working second brain

A deliberate "less is more" pass so the template is genuinely valuable to a fresh
builder rather than a maximal pile of tools. Nothing you rely on day-to-day
changed; a layer of internal-workflow governance and heavyweight infrastructure
that needed setup most people won't have was removed so the box stays clear.

**BREAKING** — none.

**REMOVED (curated out — internal governance, not tools you'd use)**
- A layer of **multi-session governance rules** and some every-session "mandate"
  banners that suited a large internal team's workflow more than a solo builder.
  The underlying *thinking tools* (first-principles, commensurability,
  feedback-loops, council) all stay — they're just offered, not forced.

**NEW / IMPROVED**
- **System map that works on any stack.** The `/topology` map + its plan-time
  alignment check now store to a single local file — **no database needed** — so
  they work whether you use Supabase, some other database, or none at all.
  `/setup` builds the first pass automatically; the database/automation map layers
  fill in only if you use those tools. Also fixed a latent crash in the alignment
  hook (it broke on a fresh repo with no ROADMAP yet).
- **Second brain that actually works end-to-end.** A standalone `knowledge_items`
  migration now ships, so the Obsidian → Supabase sync has a table to write to in
  **your** project. Full recipe in 📄 `docs/OBSIDIAN-SETUP.md`. Layer 1 (local
  vault capture) needs no database at all.
- **Platform-thinking section** in the README (why a template is itself a
  platform, and how this one is governed) — README §11.
- **Accuracy + honesty fixes**: real tool counts, a corrected upstream repo name
  (was 404-ing template pulls), a "start here day one" line in the catalogue, and
  a full de-leak so nothing internal ships in this public copy.

---

## 2026-07-03 — The big catch-up: parallel-session safety, tiered catalogue

Brings the template up to date with everything the upstream toolkit learned in
June, plus a platform-thinking pass on how the whole box is organised.

**BREAKING** — none. Nothing was renamed or removed; existing projects update cleanly.

**NEW**
- **Parallel-session safety**: collision-detection hooks and the single-folder
  worktree discipline rule, so two chats never corrupt each other's files.
- **Session-end continuation gate**: every session that ends mid-work now
  leaves a paste-ready "carry on from here" prompt automatically.
- **The council, complete**: the `/council` skill + 8 council agent
  definitions now ship in the box (the command previously pointed at a skill
  that wasn't included).
- **Production-readiness review** skill, **`/challenge`** command, and the
  full second-brain graph layer (`/vault-sync`, `/trace`, `/drift`, `/emerge`,
  `/graduate`, `cross-linker`, `tag-taxonomy`, `llm-wiki`, `vault-review`,
  `claude-history-ingest`, `skool-to-obsidian`).
- **Tiered catalogue** (`CATALOG.md`): CORE / RECOMMENDED / SPECIALIST — know
  what matters on day one vs what waits quietly.
- **Feedback path** (`FEEDBACK.md`) and **upstream watchlist**
  (`docs/UPSTREAM-WATCH.md`).

**IMPROVED**
- `/setup` now: detects pi sessions, **establishes independent version control
  automatically** (your project can never accidentally push back to the
  template), wires the new hooks, runs a first system-alignment read after your
  roadmap exists, and offers the "map of your project" tool (understand-anything)
  with a soft `/topology` pointer.
- Design suite upgraded to the June cutting-edge versions: `/design-review`
  (motion + restraint rubrics), `ui-design-system` (motion whitelist,
  restraint pre-flight, anti-AI-tell rules), `landing-page-mvp` quality gate.
- `/autovibe` (post-ship map refresh + destination wiring),
  `/Master-Continuation-Prompt` (always emits a paste-ready micro prompt),
  `dev-prod` (make-safe-baseline recipe), `pi-migration` v1.1,
  `/update-latest` (surfaces BREAKING entries before applying anything).

**FIXED**
- 33 references to `/council` and 49 to `/where` that pointed at tools not in
  the box now resolve.
- Removed leftover internal-agency defaults from example scripts (an Obsidian
  bootstrap default URL, a keychain item name, personal machine paths).

Totals: **110 skills · 38 commands · 26 hooks · 41 doctrine rules**.

---

## 2026-06-03 — Initial public release

A clean, white-label Claude Code starter: ~90 skills, ~28 commands, ~25
specialist agents, and ~60 safety/efficiency hooks. Run `/setup` to make it yours.

**Highlights**
- One-command guided setup (`/setup`) that writes your project memory,
  `DESTINATION.md`, roadmap, and North Star metric.
- First-principles framing-audit suite, the strategy + code councils, and
  autonomous shipping (`/autovibe`, `/ship`, `/verify-shipped`, `/e2e-test`).
- Token-efficiency layer (caveman + layman voice + MCP token-saver hooks).
- Memory & handoff (`/prompt-forge`, `/Master-Continuation-Prompt`), Obsidian
  second brain, and the `ki-*` knowledge pipeline.
- Team collaboration (`/collab`), Google Workspace control (`gws-*`), and
  dev/prod separation (`dev-prod`).
- Security skills, design system, deployment helpers, diagrams, and decks.
