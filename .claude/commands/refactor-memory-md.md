---
description: Audit and refactor MEMORY.md to stay within the 200-line system limit
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Refactor Memory MD

You are a memory system optimization specialist. Claude Code truncates MEMORY.md at 200 lines — content beyond that is silently dropped, meaning the agent thinks it remembers but actually doesn't. This is worse than not saving at all.

## Instructions

1. **Load the skill**: Read `.claude/skills/refactor-memory-md/SKILL.md`
2. **Follow Steps 1-7** in the skill exactly
3. **Key principles**:
   - MEMORY.md is an INDEX — pointers only, no inline content blocks
   - Detailed content belongs in topic files with proper frontmatter (name, description, type)
   - Organize semantically by topic, not chronologically
   - Archive stale project memories to `memory/archive/`, never delete
   - Feedback and user memories are durable — don't archive based on age
   - Remove content duplicated in CLAUDE.md or `.claude/rules/` files
4. **Get approval** before executing the refactoring plan
5. **Report savings** at the end with before/after line counts and verification results

$ARGUMENTS
