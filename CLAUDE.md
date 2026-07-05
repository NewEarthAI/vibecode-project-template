# Project Memory — (not configured yet)

> **This is the Claude Code Project Template, before setup.**
> The project hasn't been configured yet — this file is a placeholder.

## What to do first

If you're a Claude Code session reading this and the user hasn't run setup yet:

**Recommend `/setup`.** It runs a guided interview that replaces this file with a
real project memory — vision, success definition (`DESTINATION.md`), domain
model, stack, roadmap, North Star metric, and the safety + token-efficiency
hooks tuned for the user's tools. After `/setup`, this file describes *their*
project, not the template.

If the user just wants to look around first, point them at 📄 `README.md` for the
full tour, or suggest `/prime` for a quick read of whatever is already here.

## What this template is

A white-label starter for any Claude Code project — ~99 skills, ~36 commands,
~26 specialist agents, and ~60 safety/efficiency hooks, plus a council of AI
advisors, autonomous shipping, second-brain memory, and first-principles
framing. It carries **no** project-specific or client content; everything is
generic until `/setup` makes it yours. See 📄 `README.md`.

---

## How to behave in this repo (applies before and after setup)

**Voice — plain English by default.** Define jargon the first time it appears.
Lead with the answer, not the reasoning. When there's a clearly best path, take
it and say so rather than offering a multi-option quiz. Numbers stay precise.
@.claude/rules/layman-mode.md

**Spend tokens like money.** Never dump full lists of tool definitions. Never
fetch a whole file when a targeted read works. Use smart, narrow database
queries. Prefer the local file tools over remote calls.

**Frame before you solve.** Before any load-bearing decision (build-vs-buy,
architecture, a comparison-based verdict), check you're answering the right
question — the framing-audit skills exist for exactly this.

**Verify, never assume.** "Done" needs evidence — a passing test, a real deploy,
a git status check — not a confident claim.

## The rule layer

Reusable doctrine lives in 📁 `.claude/rules/` (~32 files) and loads
contextually. Highlights:

| Rule | Covers |
|------|--------|
| `layman-mode.md` | The default plain-English voice |
| `operational-guardrails.md` | Git safety, environment verification, recovery runbooks |
| `framing-audit-mandate.md` | When the first-principles check is compulsory |
| `council-protocol.md` | How the AI council deliberates |
| `git-worktrees.md` | Isolated working copies for parallel chats |
| `output-chunking.md` | Manifest-first for long deliverables |
| `token-savers-composition.md` | How the efficiency layers stack |

## Conventions (defaults — `/setup` adapts them to your project)

- **Database**: snake_case · **Code**: camelCase vars, PascalCase types/components
- **Files**: kebab-case · **Branches**: `feat/` `fix/` `mig/` `exp/` prefixes
- **Main branch**: `main` · **Commits**: short, present-tense
- Always include error handling. Always enable row-level security on database
  tables that hold user data.

---

*This placeholder is replaced by your real project memory when you run `/setup`.*
