# Session Environment Policy — Desktop vs Terminal

**Origin**: Council `council/sessions/2026-05-19-session-coordination-layer.md` —
RECOMMENDATION #1 + Operator's Auto-Resolution Table row "Desktop vs terminal divergence".
Auto-resolved under the autonomous-mode signal; **operator-reversible by editing this file**.

**Scope**: every Claude Code session, regardless of project. This is a workflow policy, not
an enforced gate — nothing blocks if it is violated. It exists so the parallel-session
coordination layer (`/where`, `sweep-stale-worktrees.sh`, the `/ship` rebase + push
hardenings) has a single load-bearing assumption it can rely on.

---

## The policy

| Surface | Allowed work | NOT for |
|---|---|---|
| **Desktop app** (claude.ai/code, Mac/Windows app) | Chat, planning, research, `/council`, reading code, reviewing | Any agentic code work — no worktree creation, no `/ship`, no `/autovibe`, no `/execute`, no edits to tracked code |
| **Terminal / CLI** (Claude Code in a terminal, Cursor extension, cmux) | ALL agentic code work — worktrees, `/ship`, `/autovibe`, `/execute`, migrations, deploys | — |

One sentence: **think in the desktop app, build in the terminal.**

## Why this exists (the load-bearing reason)

The session-coordination layer derives all state live from git (`git worktree list` +
`git status` + `git rev-list`) and never trusts a written registry. That design has exactly
one assumption: **code work happens where git worktrees and `/ship` live — the terminal.**

Holding this policy collapses two otherwise-expensive problems to zero cost:

1. **The desktop-hook empirical unknown.** It was never established whether the desktop app
   fires `SessionStart` hooks or exposes a stable session id when it auto-creates a worktree.
   Under this policy that question stops being load-bearing — the desktop app does no code
   work, so its hook behaviour cannot cause silent corruption.
2. **The desktop/terminal two-environment bridge.** No bridge needs to be built or operated.
   Policy replaces code; zero new surface to maintain.

## If you need to reverse it

If a genuine desktop-app code-work scenario emerges (e.g. a future desktop feature you trust
for agentic edits), reverse the policy by editing the table above. Then the deferred
desktop-hook empirical check (does the desktop app fire `SessionStart` / expose
`$CLAUDE_SESSION_ID`?) becomes load-bearing again and must be answered before relying on the
coordination layer from desktop sessions.

## What this policy is NOT

- **Not a gate.** No hook enforces it. A violated policy degrades the coordination layer's
  guarantees; it does not halt work.
- **Not a restriction on reading.** The desktop app may freely read code, run `/council`,
  and plan — it simply must not be the surface that creates worktrees or runs `/ship`.
- **Not project-specific.** It applies fleet-wide and propagates to every NewEarth entity.

## References

- Council: `council/sessions/2026-05-19-session-coordination-layer.md` (Pragmatist E-resolution; the elegant double-resolution in DIVERGENCE)
- `/where` command — the live state surface this policy keeps trustworthy
- `.claude/skills/ship/scripts/rebase-conflict-guard.sh` + `verify-push-landed.sh` — the unattended-safety hardenings that assume terminal-only code work
- **Armed coordination layer (2026-05-25)** — `sessionstart-context-aggregator.sh` (writes the per-worktree session heartbeat + auto-surfaces `/where` at every session start) + `sweep-stale-worktrees.sh` Check 4 (heartbeat-stale 48h, human-invoke-only `--apply`, grace option b for pre-existing worktrees). This terminal-only policy is the assumption that makes the heartbeat trustworthy: heartbeats are written by the terminal SessionStart hook, so a worktree that never sees a terminal session never gets a heartbeat and is correctly held LIVE-by-grace rather than mistakenly reclaimed.
