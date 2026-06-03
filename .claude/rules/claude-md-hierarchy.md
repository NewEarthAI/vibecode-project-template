# CLAUDE.md Hierarchy Standard (3 Layers)

## Layer 1: Root `CLAUDE.md`

Project identity loaded into EVERY conversation. Keep under 100 lines.

**Contains**:
- What this project is (1-2 paragraphs)
- Conventions (naming, database, code style)
- Critical rules (never do X, always do Y)
- Pointers to Layer 2 files (table of `.claude/rules/*.md`)
- Quick start (how to get oriented)
- Command/skill reference table

**Does NOT contain**: Detailed reference material, full API docs, architecture deep-dives.

## Layer 2: `.claude/rules/*.md`

Domain-specific reference material. Loaded contextually by Claude when relevant.

**Contains**:
- Architecture patterns, deployment flows
- Platform-specific rules (n8n, Supabase, MCP)
- Operational guardrails and safety protocols
- Business domain model and entity registry
- Tool fallback tables

**Naming**: `{domain}.md` — e.g., `n8n-patterns.md`, `mcp-servers.md`, `architecture.md`

## Layer 3: `specs/*.md`, `continuations/*.md`, session context

Task-specific, disposable after completion.

**Contains**:
- Implementation specs for specific features
- Continuation prompts for multi-session work
- Research briefs and audit documents

**Lifecycle**: Created per-task, archived or deleted when done.

## Anti-Patterns

- **Bloated CLAUDE.md** — putting everything in Layer 1 wastes tokens every conversation and causes Claude to ignore critical instructions (confirmed by Anthropic)
- **Layer 2 referencing Layer 3** — creates stale pointers when specs are completed/deleted
- **Duplicating content across layers** — single source of truth per topic
- **Layer 3 content in Layer 2** — temporary task context does not belong in permanent rules
