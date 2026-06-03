---
name: ki-evaluate
description: |
  KI Pipeline deep evaluation skill. Invoked via SSH-Execute when a CROSSREF action
  of type evaluate_for_project is approved. Reads project CLAUDE.md, ROADMAP.md,
  and memory to score content relevance against current project priorities.
  Use when: KI action_type is "evaluate_for_project".
version: 1.0
classification: encoded-preference
template_managed: true
---

# ki-evaluate — Deep Relevance Evaluation

## Context

You are being invoked by the **KI (Knowledge Intelligence) pipeline** — an automated system that discovers content (YouTube videos, articles, RSS feeds, GitHub releases), researches it via Gemini, cross-references it against project profiles, and proposes actions. A human approved this evaluation action via WhatsApp.

Your job: **deeply evaluate whether this content is relevant to THIS specific project**, using full repo context that the pipeline's lightweight CROSSREF scoring couldn't access.

## Input Format

The prompt contains structured KI context:

```
[KI Job: KI-YYYYMMDD-XXXXXX] {title}

KI Context:
- Job: KI-YYYYMMDD-XXXXXX
- Source: {url}
- Crossref Score: {0-100}
- Action Type: evaluate_for_project
- Target: {profile_slug}

{description from CROSSREF — why this was flagged as relevant}
```

## Instructions

1. **Read project context** — `CLAUDE.md`, `ROADMAP.md`, and any `memory/` files to understand current priorities, tech stack, pain points, and active sprint
2. **Analyze the KI content** against the project's actual state:
   - Does this solve a current pain point listed in ROADMAP?
   - Does it align with the active sprint focus?
   - Is the technology compatible with the current stack?
   - Would adopting this require significant rework or is it a drop-in?
3. **Score relevance** (0-100) based on:
   - **Direct applicability** (40 points) — Can this be used in the project as-is or with minor adaptation?
   - **Strategic alignment** (30 points) — Does this advance roadmap goals?
   - **Timing** (20 points) — Is now the right time, given current sprint and priorities?
   - **Cost/effort** (10 points) — Is the adoption cost justified by the benefit?
4. **Recommend next steps** — What specific actions should be taken if relevant?

## Output Format

After your analysis, output a fenced JSON block that SSH-Execute can parse:

```json
{
  "verdict": "relevant|marginal|irrelevant",
  "score": 75,
  "reasoning": "2-3 sentence explanation of the verdict",
  "project_alignment": {
    "roadmap_items": ["Item 1 this relates to"],
    "pain_points_addressed": ["Pain point it solves"],
    "stack_compatibility": "high|medium|low"
  },
  "recommended_actions": [
    "Specific action 1",
    "Specific action 2"
  ],
  "risks": ["Any risks of adopting this"]
}
```

## Guidelines

- Be honest — a low score is better than false enthusiasm
- Reference specific ROADMAP items and pain points by name
- If the CROSSREF score seems inflated, say so and explain why
- Consider the project's budget and team size constraints
- If you can't find ROADMAP.md or CLAUDE.md, note that in your reasoning and score conservatively
