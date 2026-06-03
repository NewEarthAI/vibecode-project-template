---
name: ki-apply
description: |
  KI Pipeline implementation planning skill. Invoked via SSH-Execute when a CROSSREF
  action of type apply_to_project or apply_to_template is approved. Reads codebase,
  creates an implementation spec, and outputs a structured plan with files to modify.
  Use when: KI action_type is "apply_to_project" or "apply_to_template".
version: 1.0
classification: encoded-preference
template_managed: true
---

# ki-apply — Implementation Planning

## Context

You are being invoked by the **KI (Knowledge Intelligence) pipeline**. A human approved an action to apply insights from discovered content to THIS project. Your job is to create a concrete, actionable implementation plan — NOT to execute it yet.

## Input Format

The prompt contains structured KI context:

```
Create an implementation plan (do NOT execute yet) for: {title}

KI Context:
- Job: KI-YYYYMMDD-XXXXXX
- Source: {url}
- Crossref Score: {0-100}
- Action Type: apply_to_project
- Target: {profile_slug}

{description — what to apply and why}
```

## Instructions

1. **Read project context** — `CLAUDE.md`, `ROADMAP.md`, and relevant source files to understand current architecture, conventions, and patterns
2. **Analyze what needs to change** — Map the KI insight to specific project modifications:
   - Which files need to be created or modified?
   - What existing patterns should be followed?
   - Are there dependencies or prerequisites?
3. **Create an implementation spec** — Write a spec file to `specs/` with:
   - Problem statement (what the KI content addresses)
   - Proposed changes (file-by-file breakdown)
   - Implementation steps (ordered, with dependencies)
   - Testing strategy
   - Rollback plan
4. **Estimate scope** — Categorize as small (< 1 hour), medium (1-4 hours), or large (4+ hours)

## Output Format

After creating the spec file, output a fenced JSON block:

```json
{
  "status": "plan_created",
  "spec_file": "specs/ki-{job_id}-{slug}.md",
  "scope": "small|medium|large",
  "summary": "1-2 sentence summary of what the plan proposes",
  "files_to_modify": [
    {"path": "src/file.ts", "action": "modify", "description": "What changes"},
    {"path": "src/new-file.ts", "action": "create", "description": "What it does"}
  ],
  "prerequisites": ["Any prerequisites"],
  "estimated_impact": "Description of what improves after implementation"
}
```

## Guidelines

- **Do NOT execute the plan** — only create it. The human will review and approve execution separately.
- Follow existing project conventions (check CLAUDE.md for coding standards)
- Reference existing utilities and patterns — don't propose reinventing what already exists
- Keep the spec concise but complete enough for another Claude session to execute it
- If the KI content doesn't have enough detail to create a concrete plan, say so and list what's missing
- Consider the project's tech stack constraints (check CLAUDE.md)
