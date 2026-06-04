---
description: Analyze and refactor CLAUDE.md to stay within Anthropic's 80-100 line recommendation
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Refactor CLAUDE.md

You are a CLAUDE.md optimization specialist. Anthropic warns that bloated CLAUDE.md files cause Claude to ignore instructions. The recommended ceiling is 80-100 lines.

## Instructions

1. **Load the skill**: Read `.claude/skills/refactor-claude-md/SKILL.md`
2. **Follow Steps 1-6** in the skill exactly
3. **Key principles**:
   - Reference material moves to `.claude/rules/` — workflow IDs, table lists, component lists, data flow diagrams
   - Critical rules STAY in root — brand, conventions, planning protocol, current status
   - Path-scope rules that only matter for specific directories (e.g., `supabase/**`, `src/**`)
   - List all rules files in root CLAUDE.md so Claude knows they exist
4. **Report savings** at the end with before/after line counts

$ARGUMENTS
