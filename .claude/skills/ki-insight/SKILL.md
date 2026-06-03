---
name: ki-insight
description: |
  KI Pipeline insight generation skill. Invoked via SSH-Execute when a CROSSREF action
  of type insight is approved. Cross-references KI content against project state to
  identify strategic implications and actionable observations.
  Use when: KI action_type is "insight".
version: 1.0
classification: encoded-preference
template_managed: true
---

# ki-insight — Project-Specific Insight Generation

## Context

You are being invoked by the **KI (Knowledge Intelligence) pipeline**. A human approved an insight action — meaning the CROSSREF system identified something strategically interesting for THIS project. Your job is to generate a deep, project-specific insight that connects the KI content to the project's current state and future direction.

## Input Format

The prompt contains structured KI context:

```
[KI Job: KI-YYYYMMDD-XXXXXX] {title}

KI Context:
- Job: KI-YYYYMMDD-XXXXXX
- Source: {url}
- Crossref Score: {0-100}
- Action Type: insight
- Target: {profile_slug}

{description — the insight that CROSSREF identified}
```

## Instructions

1. **Read project context** — `CLAUDE.md`, `ROADMAP.md`, and memory to understand the full picture
2. **Deepen the insight** — The CROSSREF insight was generated from a PROFILE.yaml summary. You have access to the FULL project. Go deeper:
   - What specific codebase patterns does this insight relate to?
   - How does this connect to active sprint work?
   - Are there implications the surface-level CROSSREF couldn't see?
3. **Identify strategic implications** — Think beyond the immediate:
   - Does this change any roadmap priorities?
   - Does this validate or challenge current architectural decisions?
   - Are there cross-project implications?
4. **Make it actionable** — An insight without action is just trivia

## Output Format

Output a fenced JSON block:

```json
{
  "insight_title": "Concise title for the insight",
  "insight_body": "2-4 paragraph deep analysis connecting the KI content to project reality",
  "strategic_implications": [
    "Implication 1 — with specific project reference",
    "Implication 2"
  ],
  "roadmap_impact": "none|minor_adjustment|reprioritize|new_item",
  "confidence": "high|medium|low",
  "actionable_next_steps": [
    "Concrete step 1",
    "Concrete step 2"
  ],
  "related_project_files": ["paths to relevant files in this repo"]
}
```

## Guidelines

- Insights should be specific to THIS project — generic industry observations aren't valuable
- Reference actual ROADMAP items, pain points, and sprint goals by name
- If the insight reveals a blind spot or risk the team hasn't considered, flag it clearly
- Quality over quantity — one deep insight is better than five shallow ones
- If the CROSSREF insight was already obvious from the PROFILE.yaml, say so and add what the full context reveals
