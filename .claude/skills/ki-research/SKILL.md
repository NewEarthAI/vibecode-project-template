---
name: ki-research
description: |
  KI Pipeline deep research skill. Invoked via SSH-Execute when a CROSSREF action
  of type followup_research or tool_evaluation is approved. Searches codebase,
  memory, and docs to synthesize findings into a structured research brief.
  Use when: KI action_type is "followup_research" or "tool_evaluation".
version: 1.0
classification: encoded-preference
template_managed: true
---

# ki-research — Deep Project Research

## Context

You are being invoked by the **KI (Knowledge Intelligence) pipeline**. A human approved a research action to investigate how discovered content relates to THIS project. Your job is to conduct deep research within the project context and produce a structured brief.

## Input Format

The prompt contains structured KI context:

```
[KI Job: KI-YYYYMMDD-XXXXXX] {title}

KI Context:
- Job: KI-YYYYMMDD-XXXXXX
- Source: {url}
- Crossref Score: {0-100}
- Action Type: followup_research|tool_evaluation
- Target: {profile_slug}

{description — what to research and why}
```

## Instructions

1. **Read project context** — `CLAUDE.md`, `ROADMAP.md`, memory files, and relevant source code
2. **Investigate the research question** within the project:
   - Search codebase for related implementations, patterns, or prior art
   - Check memory for past decisions or evaluations on this topic
   - Look for existing specs or docs that address similar concerns
   - If `tool_evaluation`: compare the tool against current stack, check compatibility, estimate migration effort
3. **Synthesize findings** — Connect what you found in the project to the KI content:
   - What does the project already have that relates to this?
   - What gaps does this content fill?
   - What would need to change to adopt the insights?
4. **Assess implications** — Strategic, technical, and operational impact

## Output Format

Output a fenced JSON block:

```json
{
  "research_type": "followup_research|tool_evaluation",
  "summary": "2-3 sentence research summary",
  "findings": [
    {
      "finding": "What was discovered",
      "evidence": "File path, code reference, or memory entry",
      "relevance": "high|medium|low"
    }
  ],
  "project_current_state": "Brief description of how the project currently handles this area",
  "gap_analysis": "What the project is missing that this content addresses",
  "recommendation": "adopt|evaluate_further|defer|skip",
  "reasoning": "Why this recommendation",
  "next_steps": ["Specific next steps if recommendation is adopt/evaluate"]
}
```

## Guidelines

- Ground all findings in actual project files — cite specific paths and line numbers
- If evaluating a tool, check version compatibility with the project's stack
- Don't speculate about code you haven't read — if you can't find relevant files, say so
- For tool evaluations, consider: learning curve, maintenance burden, lock-in risk, and community health
- Keep the research focused on THIS project's context, not general industry opinion
