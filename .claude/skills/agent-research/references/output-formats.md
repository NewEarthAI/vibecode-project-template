# Research Output Formats

## SCQA (Default — Best for Decision-Driving Research)

```markdown
# Research Report: {{research_topic}}
**Date**: {{YYYY-MM-DD}} | **Depth**: {{depth}} | **Workers**: {{count}} | **Verified**: {{yes/no}}

## Situation
{{Current state — established facts, what exists today, context the reader needs}}

## Complication
{{The problem, challenge, or change that prompted this research}}

## Question
{{The specific question(s) this research answers}}

## Answer

### Key Findings
1. **{{finding}}** [Confidence: {{HIGH/MED/LOW}}]
   Source: [{{title}}]({{url}})
   {{1-line context}}

2. **{{finding}}** [Confidence: {{HIGH/MED/LOW}}]
   Source: [{{title}}]({{url}})
   {{1-line context}}

### Synthesis
{{Integrated analysis connecting findings — what the data means as a whole}}

### Recommendations
1. {{Actionable next step with specificity}}
2. {{Actionable next step}}
3. {{Actionable next step}}

### Limitations & Gaps
- {{What couldn't be determined and why}}
- {{What requires follow-up research}}
- {{Time-sensitivity of findings (will this be stale in N weeks?)}}

### Contradictions Found
| Claim | Source A Says | Source B Says | Assessment |
|-------|-------------|-------------|------------|
| {{topic}} | {{position}} | {{position}} | {{which is more credible and why}} |

### Sources
1. [{{title}}]({{url}}) — {{how used in this research}}

---
*Research agents: {{count}} | Verification: {{independent/inline/none}}*
*Tokens: ~{{estimate}} | Duration: ~{{minutes}}min*
```

## Bullet (Best for Status Updates and Quick Summaries)

```markdown
# Research: {{topic}}
**{{YYYY-MM-DD}}** | {{depth}} mode | {{count}} agents

**Key findings:**
- {{finding}} — {{confidence}} confidence [Source]({{url}})
- {{finding}} — {{confidence}} confidence [Source]({{url}})
- {{finding}} — {{confidence}} confidence [Source]({{url}})

**Contradictions:** {{summary or "None found"}}

**Gaps:** {{what couldn't be answered}}

**Recommended action:** {{1-2 sentences}}
```

## Narrative (Best for Reports Shared with Non-Technical Stakeholders)

```markdown
# {{Research Topic}}

## Executive Summary

{{2-3 paragraph narrative summarizing findings in plain language. Lead with the answer, then the evidence. Write for someone who will read this once and make a decision.}}

## Detailed Findings

### {{Theme 1}}
{{Narrative explanation with inline source references. Written as prose, not bullet points. Each paragraph builds on the previous.}}

### {{Theme 2}}
{{Continue the narrative...}}

## What We Don't Know
{{Honest assessment of gaps, written as narrative. Frame as "here's what would need to happen to answer this."}}

## Recommendation
{{Clear, specific recommendation in 1-3 paragraphs. Include alternatives considered and why the primary recommendation wins.}}

---
**Methodology:** {{count}} independent research agents with {{verification type}} verification. Sources from: {{source types used}}.
```

## Post-Output Persistence Protocol

After generating the output in any format:

```
1. SAVE to research-outputs/{YYYY-MM-DD}-{slug}.md
   (Create directory if needed)

2. ASK: "Save key findings to project memory? (y/n)"
   If yes → write to .claude/memory/research-{slug}.md with frontmatter:
   ---
   name: Research — {{topic}}
   description: {{1-line summary of key finding}}
   type: reference
   ---

3. If findings suggest actionable work:
   → "This research suggests {{action}}. Create a task/spec? (y/n)"

4. If research served a ROADMAP item:
   → Note in output: "Informs ROADMAP item {{item}} — reference when planning."
```
