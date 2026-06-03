---
description: "Gather the AI Council for multi-perspective deliberation on a proposal, decision, or idea"
argument-hint: <proposal> | debate <topic> | premortem <project> [--no-save]
---

# /council — Multi-Perspective Deliberation

Gather three council agents (Optimist Strategist, Devil's Advocate, Neutral Analyst) to evaluate a proposal from opposing philosophical lenses. Produces a synthesis with consensus, divergence, and confidence spread.

**Invokes**: `council` skill (v1.0)

---

## Modes

| Mode | Trigger | What It Does |
|------|---------|-------------|
| **Standard** | `/council "Should we build X?"` | 3 parallel analyses + synthesis |
| **Debate** | `/council debate "topic"` | Agents challenge each other's positions |
| **Pre-Mortem** | `/council premortem "project"` | Assume failure, work backward to prevent it |

Add `--no-save` to skip session persistence.

---

## How It Works

1. Parses the proposal and mode from `$ARGUMENTS`
2. Launches all 3 council agents in parallel (each in fresh context)
3. Collects their reports
4. Synthesizes: consensus, divergence, confidence spread, recommendation
5. Persists full session to `council/sessions/` (default ON)

---

## When to Use /council vs. Other Commands

| Need | Use |
|------|-----|
| Test one specific belief against vault/ROADMAP evidence | `/challenge` |
| Research a topic from multiple external sources | `/agentresearch` |
| Evaluate a proposal from multiple perspectives before deciding | **`/council`** |
| Build something with parallel coding agents | `/build-with-agent-team` |

---

## Examples

```
/council "Should we prioritize Feature A or start Feature B?"
/council "Is this new product worth pursuing with a $50K budget?"
/council debate "The data pipeline should use Gemini instead of OpenAI"
/council premortem "Product MVP launch"
/council "Should we migrate from platform A to platform B?" --no-save
```
