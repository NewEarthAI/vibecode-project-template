---
description: Create comprehensive implementation plan with codebase analysis and research
argument-hint: <task description>
---

# Plan: $ARGUMENTS

## Mission
Transform a task description into a **comprehensive implementation plan** through systematic codebase analysis, external research, and strategic planning. Output to `specs/`.

**Core Principle**: We do NOT write code in this phase. The goal is a context-rich plan that enables one-pass implementation success via `/execute`.

## Planning Process

### Phase 1: Task Understanding
- Extract the core problem being solved
- Identify user value and business impact
- Classify type: New Feature | Enhancement | Refactor | Bug Fix
- Assess complexity: Low | Medium | High
- Map affected systems and components

### Phase 1.5: Framing Audit (mandatory — `.claude/rules/framing-audit-mandate.md`)

Before gathering codebase intelligence around the task, audit the task's *framing* —
confirm it is the **right question** before planning an answer to it. This is a named,
non-skippable step for load-bearing work. Skip ONLY for trivia (typo fixes, single-line
edits, factual lookups) per the mandate rule's not-for-trivia scope.

1. Pick the matching framing-audit primitive:
   - `/reduce-to-first-principles` — default; the task is framed as a proposal, claim, or protocol gate
   - `/check-commensurability` — a comparison underpins the task ("X vs Y", "build vs buy")
   - `/map-feedback-loops` (DECISION mode) — the task's consequences play out over time
2. Run it on the task framing. Record the structured verdict — it goes in `## Context References` of the plan.
3. If the verdict flags the frame — `SMUGGLES_CONCLUSIONS`, a rung-1/2 comparison with the
   Hands-On Calibration Gate firing, or a `frame-criticism` classification — do NOT proceed
   to Phase 2. Reframe the task first, then re-run this step. If the operator reviews the
   reframe and declines it, record the disagreement and their stated reason in the verdict,
   then proceed under their frame — a stated, recorded gap is allowed; only a silent skip
   is forbidden.
4. If the primitive returns no usable verdict (`INSUFFICIENT_INPUT`, `SCOPE_REFUSAL`, an
   error, or it is not registered), the audit did NOT run — treat that as a HALT, not a
   pass. Surface the unmet input and restate the task, or escalate to the operator. Never
   record a clean verdict for an audit that did not complete.
5. A clean verdict (`SOUND`, or `ADDS_CONSTRAINTS` with the additions noted) becomes part of the plan record.

Cite the primitive — do not reproduce its procedure here. See
`.claude/rules/framing-audit-mandate.md` for the full trigger table and the five primitives.

### Phase 2: Codebase Intelligence Gathering
Use the Task tool with `subagent_type: "Explore"` to spawn parallel research agents:
1. **Structure & Patterns** — File organization, naming conventions, error handling patterns
2. **Dependencies & Integration** — External libraries, existing utilities to reuse, integration points
3. **Testing Patterns** — Framework, structure, coverage approach

Read key files identified by the agents. Look for existing functions and utilities that can be reused — avoid proposing new code when suitable implementations already exist.

### Phase 3: External Research
If the task involves external libraries or unfamiliar APIs:
- Use Context7 MCP (`resolve-library-id` → `query-docs`) to fetch current documentation
- Research best practices and common gotchas
- Verify version compatibility with the project's existing dependencies

### Phase 4: Strategic Questions
Before writing the plan, consider and document:
- How does this fit into the existing architecture?
- What are the critical dependencies and order of operations?
- What could go wrong? (Edge cases, race conditions, error scenarios)
- Performance, security, and maintainability implications?
- What testing strategy is appropriate?
- Does this affect any existing commands, hooks, or automation?

### Phase 5: Write Plan
Save to `specs/{kebab-case-task-name}.md` using the template below.

## Plan Template

```markdown
# Implementation Plan: {Task Name}

## Overview
{Brief description of what will be built and why}

## Problem / Solution Statement
{What problem this solves and the chosen approach}

## Context References
- **Mandatory reads**: {files the implementer must read first}
- **Files to create**: {new files needed}
- **Files to modify**: {existing files that change}
- **External docs**: {documentation links or Context7 references}
- **Reusable patterns**: {existing utilities/functions to leverage}
- **Framing audit verdict**: {Phase 1.5 — primitive run + structured verdict, or "trivia — skipped" with reason}

## Implementation Steps

### Step 1: {Description}
- **Action**: CREATE | UPDATE | ADD | REMOVE
- **Files**: {specific file paths}
- **Details**: {implementation notes with enough context for one-pass execution}
- **Validate**: {command or check to verify this step}

### Step 2: {Description}
...

## Testing Strategy
- Unit tests: {what to test, where to put tests}
- Integration tests: {cross-component verification}
- Edge cases: {specific scenarios to cover}

## Validation Commands
{Ordered list of commands to run after implementation to verify everything works}

## Acceptance Criteria
{Checkboxes — what "done" looks like}

## Failure Conditions
{Explicit conditions that mean this implementation is NOT done or is WRONG. Define what failure looks like so "done" is unambiguous from both directions.}

- [ ] FAILS IF: {specific condition that would make this implementation wrong}
- [ ] FAILS IF: {specific edge case or scenario that must not occur}
- [ ] FAILS IF: {regression or side effect that would indicate broken implementation}
- [ ] FAILS IF: a load-bearing task was planned with no framing-audit verdict recorded (Phase 1.5)

## Confidence Score: N/10
{How likely is first-attempt implementation success? What would increase confidence?}
```

## Report
Confirm the spec file was created. Print:
- File path
- Summary of steps
- Confidence score
- Any unresolved questions that need user input before `/execute`
