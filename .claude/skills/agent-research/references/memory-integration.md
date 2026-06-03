# Memory Integration for Agent Research

## Gate 2: Pre-Research Memory Dedup

Before spawning any workers, check if research already exists on this topic.

### Search Patterns

```bash
# Keywords extracted from research_topic (2-3 most distinctive terms)
keywords="{{keyword1}} {{keyword2}}"

# Check all knowledge repositories
Glob: .claude/memory/*{keyword}*
Glob: council/sessions/*{keyword}*
Glob: research-outputs/*{keyword}*
Glob: specs/*{keyword}*
Glob: continuations/*{keyword}*

# Also grep inside files for topic references
Grep: "{{keyword1}}.*{{keyword2}}" in .claude/memory/
Grep: "{{keyword1}}.*{{keyword2}}" in research-outputs/
```

### Decision Matrix

| Found | Age | Action |
|-------|-----|--------|
| Nothing found | — | Proceed with full research |
| Found, <7 days old | Fresh | Surface to user: "Recent research exists: {file}. Use as baseline? (y/incorporate/fresh)" |
| Found, 7-30 days old | Recent | Surface: "Research from {date} exists. Likely still valid. Incorporate or refresh?" |
| Found, >30 days old | Stale | Surface: "Older research found ({date}). Consider as background context, focus workers on updates/deltas." |
| Council session found | Any | Surface: "Council deliberated on this ({date}). Key verdict: {1-line}. Research to extend or revisit?" |

### Incorporation Modes

**"Use as baseline"** — Load prior findings into Lead context. Workers still isolated. Lead identifies gaps in prior research and focuses new workers on those gaps only. Saves ~50% tokens.

**"Incorporate"** — Same as baseline, but also prune sub-questions already answered. Only spawn workers for genuinely new questions.

**"Fresh"** — Ignore prior research entirely. Full spawn. Use when prior research is suspected wrong or context has changed significantly.

## Phase 5: Post-Research Persistence

### Research Output File

Always save (when `persist=true`):

```
Location: research-outputs/{YYYY-MM-DD}-{slug}.md
Content: Full research output in chosen format (SCQA/bullet/narrative)
```

Create `research-outputs/` directory if it doesn't exist.

### Memory File (Optional — User Confirms)

After presenting findings, ask:
```
"Save key findings to project memory for future sessions? (y/n)"
```

If yes, write:

```markdown
---
name: Research — {{topic_short}}
description: {{1-line: what was researched, key finding, date}}
type: reference
---

Key findings from {{YYYY-MM-DD}} research ({{depth}} mode, {{count}} agents):

- {{finding 1}}
- {{finding 2}}
- {{finding 3}}

Full report: research-outputs/{{filename}}

**How to apply:** {{when this research is relevant in future sessions}}
```

### MEMORY.md Index Update

If a memory file is created, add a pointer to MEMORY.md:
```
- [Research — {{topic}}](research-{{slug}}.md) — {{date}}, {{1-line finding}}
```

### Actionable Follow-ups

If research identifies actionable work:
```
"This research suggests:
1. {{action item}}
2. {{action item}}

Create tasks or specs? (y/n)"
```

If yes → create spec stub at `specs/{{slug}}.md` or tasks via TaskCreate.

### ROADMAP Annotation

If research was tied to a ROADMAP item (from Gate 1):
```
"This research informs ROADMAP item {{item}}. Note in output for next /daily-plan? (y/n)"
```

If yes → append to research output:
```
## ROADMAP Reference
This research informs: {{item}} in {{phase}}
Key implication: {{how findings affect the ROADMAP item's approach}}
```
