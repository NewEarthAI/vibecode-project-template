# Upstream Watch — what native Claude Code may absorb

This template is itself a complement built on top of Anthropic's platform.
Platform owners routinely absorb popular complements into the core product —
when that happens, the right move is to **retire our version gracefully**, not
defend it. This page is the honest watchlist.

| Template feature | Native feature that could absorb it | Decommission trigger |
|---|---|---|
| `deep-research` skill | Built-in `/deep-research` | Native version matches quality at lower token cost in a side-by-side run |
| `/plan` + `specs/` discipline | Native plan mode | Native plans persist across sessions AND support amendment history |
| Memory scripts (`bin/*memory*`) | Native persistent memory directory | Native memory covers cross-machine sync and topic files |
| `/build-with-agent-team` | Native agent teams / Dynamic Workflows | Native orchestration supports contract-first parallel builds with worktree isolation |
| hookify context-injection rules | Richer native hook events | Native hooks can inject doctrine per tool-event without a runtime shim |
| `session-summarizer` + continuation prompts | Native session resume / compaction | Native handoff carries goals + verification state, not just transcript |

**Review cadence**: skim the Claude Code release notes whenever `/update-latest`
runs; if a trigger above fires, open an issue titled "decommission candidate:
<feature>" rather than silently keeping both.

**Why this file exists**: a feature we maintain after the platform ships a
better native version isn't an asset, it's drag. Naming the triggers up front
keeps the template lean and honest.
