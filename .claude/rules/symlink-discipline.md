# Symlink Discipline — Convenience Layer, Not Source of Truth

**Origin**: 2026-05-05 — explicit doctrine following user request to make NewClaw / NewMem / Agency OS aware of how symlinks are used and where they could clash.
**Pairs with**: `kairos-readiness.md` (substrate doctrine: structured memory writes to Supabase, not local files), `git-worktrees.md` (per-worktree node_modules symlinks), `continuation-collision-safety.md` (parallel-session collision protocol).
**Health check**: `bin/memory-health-check.sh` — runs in daily-plan Phase 0D.3.

---

## The principle

Symlinks are a **local convenience layer**, not a source of truth. They bridge the gap between "where Claude expects something" and "where the canonical artifact actually lives in git." When two systems disagree on where data should be, a symlink resolves the disagreement at the filesystem layer without forcing either system to change.

The substrate (Supabase / Neo4j / git-tracked folders) is the source of truth. Symlinks are the per-machine adapters that point at it.

---

## Active symlink uses (current state)

| Use | Link location | Target | Created by | Lifetime |
|---|---|---|---|---|
| **Cross-machine memory** | `~/.claude/projects/<encoded-cwd>/memory` | `<repo>/agency/memory/` | SessionStart hook (`sessionstart-context-aggregator.sh`, `ensure_memory_symlink`) | Per-machine, idempotent, recreated on every session start |
| **Worktree dependencies** | `<worktree>/node_modules` | `<primary-clone>/node_modules` | Manual `ln -sfn` per `git-worktrees.md` | Per-worktree, removed before `git worktree remove` |

No other symlinks are load-bearing in this codebase as of 2026-05-05.

---

## Why symlinks here, not something else

### For cross-machine memory
- Claude Code expects per-project memory at a fixed path (`~/.claude/projects/<encoded-cwd>/memory/`). That path is encoded from the absolute working directory and cannot be overridden.
- We want the canonical memory folder in git so it (a) survives reinstalls, (b) syncs across machines via push/pull, (c) is visible to code review and council deliberations.
- Symlink bridges those: each machine's encoded path symlinks to its local clone's `agency/memory/` folder.
- Alternatives considered: bind-mounts (Linux only, requires root), git submodule (heavyweight, fragile), running Claude with a project-dir override (not supported by the CLI today).

### For worktree dependencies
- A `git worktree` is a sibling working tree on a different branch but shares the same `.git/` storage. It does NOT share `node_modules/`.
- Re-running `npm install` per worktree wastes ~1.2 GB of disk and ~30 seconds of wall-clock per worktree. With 12 worktrees, that's 14 GB and several minutes per re-install.
- Symlink to the primary clone's `node_modules/` solves this for branches whose `package-lock.json` matches the primary tip.
- Tradeoff: when deps diverge (rebased onto an older main, added/removed a package), the worktree must `npm install` fresh.

---

## Cross-host design — Mac, VPS (Hetzner), shared sessions

The cross-machine memory pattern is **path-encoding aware**. Each host generates its own symlink at its own encoded path, but all symlinks resolve to the same git-tracked target.

**Example — same git repo, two hosts:**

| Host | Repo cloned at | Encoded memory path | Symlink target (relative to repo) |
|---|---|---|---|
| Justin's Mac | `/Users/justin/Documents/GitHub/NewEarth AI Agency - Main` | `~/.claude/projects/-Users-justin-Documents-...-Main/memory` | `agency/memory/` |
| Hetzner VPS (when NewClaw lands) | `/opt/newearthai/main` | `~/.claude/projects/-opt-newearthai-main/memory` | `agency/memory/` |
| Justin's Linux laptop | `/home/justin/repos/newearth/main` | `~/.claude/projects/-home-justin-repos-...-main/memory` | `agency/memory/` |

The encoded paths differ. The targets converge. Both machines read and write to the same git-tracked folder.

### Where conflicts can happen

1. **Concurrent writes between Mac and VPS on the same memory file** → resolved at `git pull/push` time as a normal merge conflict. Risk: small, because most memory writes are append-style to topic files, and `MEMORY.md` (the only frequently-rewritten file) is small enough that conflicts are easy to resolve.
2. **Stale local clone on one host** → if VPS hasn't pulled in 3 days and Mac has rewritten 4 topic files, VPS's local memory folder serves stale state until next `git pull`.
3. **Per-host session transcripts** (NOT in agency/memory/) — these stay local-only on each host. That's intentional; they're ephemeral and host-specific.

### The mitigations

- **For 1**: Per-host topic-file convention when concurrent writes are likely. Mac writes `feedback_X.md`, VPS writes `feedback_X_vps.md`. Index entries in `MEMORY.md` are the only file at risk of frequent collision; keep edits there small and atomic.
- **For 2**: VPS pulls before any meaningful work (already standard via `prime-lite` skill on session start).
- **For 3**: Session artifacts that NEED to be cross-host go through the kairos-readiness substrate (Supabase), not local files.

---

## Composition with `kairos-readiness.md` (the substrate doctrine)

`kairos-readiness.md` says: every new memory-layer pattern writes its persistent state to a Supabase table with stable, queryable schema. Never local-only state for substrate work.

The symlink layer is **NOT** substrate. It is the local-file convenience cache that Justin's Mac uses for personal session-level memory (MEMORY.md, topic files, continuation prompts). New patterns post-2026-04-26 write to Supabase regardless of whether the symlink exists.

Concrete split:
- **Local-file via symlink** = personal memory layer (MEMORY.md index, feedback files, project files, continuations) — Mac convenience, syncs via git
- **Supabase substrate** = NewClaw / NewMem / KI / Agent Suite state — cross-host shared, queryable, durable independent of any filesystem

When NewClaw runs on Hetzner VPS:
- VPS Claude Code agents read **session context** from Supabase (kairos-readiness substrate), not from the local symlink-backed folder
- VPS sessions may still create local artifacts in their own encoded memory path; those sync to git the same way Mac's do
- The VPS does NOT need the local-file memory layer to function — it's an extra resilience layer, not a dependency

This is what insulates NewClaw on Hetzner from any silent failure of the symlink layer: the SOT lives in the database.

---

## When to AVOID symlinks

- **Across iCloud-synced folders**: `~/Documents/GitHub/...` is iCloud-poisoned territory. Symlinks themselves are fine, but writing to symlink targets in iCloud-synced paths can produce half-synced files. The repo is in iCloud out of historical accident; the operational guardrails already specify a `~/code/<repo>` non-iCloud secondary clone for branch-modifying git ops. The symlink target stays in iCloud — read-mostly access pattern is fine.
- **For credentials or secrets**: never symlink `.env` files across machines. Each host has its own credentials.
- **Across user accounts**: symlinks store target paths verbatim. A symlink in Justin's home that points into Cassandra's home will fail with permission denied. Each user creates their own symlinks.
- **For files you want git to copy, not pointer-track**: git stores symlinks as symlinks (the target string), not as the pointed-at content. If you want the content checked in, use a real file or a hardlink (rare).

---

## Is there a superior approach?

**For cross-machine memory portability**: today's symlink approach is genuinely good. The alternatives all introduce more complexity:
- Standardised absolute clone path (e.g., `/opt/newearthai` on every host) requires root permissions on laptops, breaks for multi-user setups, painful when Justin works on a borrowed Mac.
- Memory-as-database-only removes the local-file convenience that lets Justin grep memory files, edit them in Cursor, and have them in git diffs.
- Project-dir override flag for Claude Code does not exist as of 2026-05-05.

**Where the symlink approach is genuinely inferior to alternatives**: cross-host shared state for NewClaw / agent fleets / portal data. That's where Supabase substrate wins. Already the codified doctrine via `kairos-readiness.md`.

**Net**: symlinks for personal cache, database for shared truth. Don't try to make symlinks do shared-truth work — they aren't designed for it and the failure modes (silent dangling, target drift, ownership conflicts) are nasty.

---

## Health check

Run `bash bin/memory-health-check.sh` to verify:
1. Memory dir is a symlink, not a real folder
2. Symlink target is the git-tracked `agency/memory/` folder and exists
3. `MEMORY.md` is under the 200-line system limit

The daily-plan generator (Phase 0D.3) calls this on every `/daily-plan` invocation. Failures get queued as remediation tasks at scores 88-95 depending on severity.

Manual run:
```bash
bash bin/memory-health-check.sh --verbose
```

Expected output on a healthy machine: `✓ memory-health: PASS`.

---

## NewClaw / NewMem / Agency OS awareness

When designing or extending these systems, the rule is:

| System | Where memory lives | Symlink relevance |
|---|---|---|
| **NewClaw kernel** (agent_sessions, agent_queue, coding_sessions on Supabase) | Supabase substrate | None — DB is SOT |
| **NewMem 5-level stack** (Obsidian → KI → Second Brain → RAG → NewClaw) | Layer 1 = local files via symlink; layers 2-5 = Supabase + Neo4j | Layer 1 only — symlink is the bridge for Justin's local Obsidian vault and topic files |
| **Agency OS Portal** (live at ops.newearthai.agency) | Supabase + edge functions | None — production reads SOT from DB |
| **KI pipeline** (knowledge_items, action backlog, FTS) | Supabase | None — DB is SOT |
| **Daily plan generator + continuation prompts** | Local files in `.claude/daily-plans/` and `continuations/` (git-tracked, NOT under symlink) | None — already in repo, no symlink needed |
| **MEMORY.md + topic files** | `agency/memory/` via symlink | Yes — this IS the symlink use case |

If a new feature needs cross-host shared state, default to Supabase substrate. If a new feature is a personal note for Justin, default to a topic file under `agency/memory/`.

---

## Failure precedents (for future-me)

- **None yet** as of 2026-05-05. The symlink layer has been live since 2026-04-27 and has not failed. This rule documents the design BEFORE a failure forces it.
- The closest near-miss: 2026-04-26 W18 sprint continuation file's Phase 1 rating asserted "schema ready" without verification (caught by extended council). That was a different layer (Supabase substrate), not the symlink layer, but the same lesson applies — assertions about state need verification artifacts, captured in `continuation-precondition-discipline.md` (GP1).

---

## References

- `bin/memory-health-check.sh` — the standalone health verifier
- `bin/enable-cross-machine-memory.sh` — one-time first-Mac activator
- `bin/setup-claude-memory.sh` — manual symlink creator (fallback when SessionStart hook unavailable)
- `.claude/hooks/sessionstart-context-aggregator.sh` — `ensure_memory_symlink` function (auto-creator)
- `.claude/rules/kairos-readiness.md` — substrate doctrine (DB = SOT for new memory patterns)
- `.claude/rules/git-worktrees.md` — node_modules symlink pattern for parallel worktrees
- `.claude/rules/continuation-collision-safety.md` — parallel-session collision protocol
- `agency/memory/project_memory-architecture-q2-2026.md` — NewMem 5-level stack roadmap
