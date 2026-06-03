---
name: prime-lite
description: Lightweight context briefing for Autovibe and other top-of-stack orchestrators. Outputs <2000 tokens of repo state (git status, log, worktrees, ROADMAP NOW, recent specs/sessions) in <3 seconds. Use when a skill needs current-state awareness without burning a full /prime context load.
---

# prime-lite — Context Briefing Primitive

## Purpose

Give an orchestrator (Autovibe, future build-with-agent-team variants) just enough situational awareness to make routing decisions, **without** consuming the reasoning budget that a full `/prime` (or full conversation context) would.

Designed budget:
- **Output**: <1500 words (≈2000 tokens)
- **Wall clock**: <3 seconds
- **Side effects**: none (read-only git + filesystem)

## When to Use

- Autovibe's first step after `preflight.sh` succeeds
- Any orchestrator that needs to know "what's currently in flight" before deciding plan-vs-direct
- A subagent prompt that says "based on current repo state, recommend X" — feed `brief.sh` output as context

## When NOT to Use

- Long-running interactive sessions — use `/prime` for full architecture context
- Code-modification tasks — use `Read`, `Glob`, `Grep` directly
- Tasks where you already have full context — `prime-lite` is for cold orchestrators

## Invocation

```bash
bash .claude/skills/prime-lite/scripts/brief.sh
```

Or from a Claude Code session, invoke this skill via the Skill tool, then run the script in Bash.

## Output Shape

The script prints sections in this order:

1. **CWD + worktree root** — confirms which clone you're in
2. **Branch + ahead-of-main count** — how far this branch has diverged
3. **Working-tree status** — `git status --porcelain | head -20`
4. **Recent commits** — `git log --oneline -10`
5. **Worktree list** — `git worktree list` (catches sibling-tree work)
6. **Recent council sessions** — `ls council/sessions/ | tail -5`
7. **ROADMAP NOW section** — first 30 lines of `specs/ROADMAP.md`
8. **Recent specs** — `ls -t specs/ | head -5`

If the cwd looks unhealthy (iCloud path, /tmp), the script prints a `WARNING:` line on stderr but does NOT exit non-zero — that's `preflight.sh`'s job. `prime-lite` only briefs.

## Budget Guarantee

See `evals/01-budget.md` — the eval asserts <1500 words and <3s. If a future repo grows past these bounds (lots of council sessions, huge ROADMAP), the script truncates rather than blowing the budget.

## Composition

`prime-lite` is a primitive. Other skills compose it:

```
Autovibe orchestrate.sh:
  preflight.sh → prime-lite/brief.sh → triage.sh → ...
```

The compose-don't-rebuild rule applies: any skill that needs a context briefing should invoke `prime-lite`, NOT reimplement git status + log scraping.
