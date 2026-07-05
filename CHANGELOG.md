# Vibe Coding Master Template — Changelog

All notable changes to the template are documented here. `/update-latest` reads
this file to show you what's new since your last sync.

---

## 2026-07-03 — The big catch-up: system map, parallel-session safety, tiered catalogue

Brings the template up to date with everything the upstream toolkit learned in
June, plus a platform-thinking pass on how the whole box is organised.

**BREAKING** — none. Nothing was renamed or removed; existing projects update cleanly.

**NEW**
- **The system map (`/topology`)**: a live map of your whole system — code,
  database, automations, settings — with gentle drift flags when what's built
  wanders from what you planned. 11 new skills, a viewer app
  (`topology-viewer/`), 3 new doctrine chapters, and a plan-time alignment
  hook. Overview: `docs/TOPOLOGY-SYSTEM-OVERVIEW.md`.
- **Parallel-session safety**: `/where` (plain-English map of every running
  chat + working copy), collision-detection hooks, and the single-folder
  worktree discipline rule.
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
