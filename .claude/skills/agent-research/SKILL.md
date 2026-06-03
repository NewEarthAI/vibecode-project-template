---
name: agent-research
description: |
  Spawn coordinated research agent teams for deep investigation. Memory-aware,
  MCP-aware, token-efficient. Implements context isolation (workers never see each other),
  independent verification, and SCQA output. Pre-flight gates check ROADMAP alignment
  and existing research before spawning. Three depth levels: quick (1-2 agents),
  standard (3-5), deep (5-8 + independent verifier).
allowed-tools: Read, Write, Bash, Glob, Grep, Agent, WebFetch, WebSearch, TaskCreate, TaskUpdate
user-invocable: true
version: 2.1
created: 2025-01-16
updated: 2026-03-28
classification: capability-uplift
triggers:
  - /agentresearch
  - /agent-research
  - research team
  - deep dive
  - investigate
  - competitive analysis
  - multi-source research
  - synthesize findings
  - research this thoroughly
parameters:
  - name: research_topic
    type: string
    description: Primary research question or topic
  - name: depth
    type: enum
    values: [quick, standard, deep]
    default: standard
    description: "quick (1-2 agents, inline verify), standard (3-5, independent verify), deep (5-8 + council-grade synthesis)"
  - name: output_format
    type: enum
    values: [SCQA, bullet, narrative]
    default: SCQA
  - name: max_agents
    type: integer
    default: 5
  - name: persist
    type: boolean
    default: true
    description: "Save research output to research-outputs/ and optionally to memory"
validated_on:
  - different_research_domain
  - different_project_type
  - different_mcp_tool_availability
  - new_project_without_prior_context
---

# Agent Research v2.0

> **Philosophy:** Lead strategizes, workers execute in isolation, verifier validates independently. Context pollution is the enemy of truth. Memory-awareness prevents redundant research. Every spawn has a cost gate.

---

## When This Applies

**Activate:** `/agentresearch`, multi-source research, competitive analysis, technical deep-dives, synthesis across 3+ sources, "research this thoroughly"

**Do NOT Use:** Simple lookups (use WebSearch), single-file exploration (use Read/Grep), tasks requiring <1K tokens of research

---

## Team Architecture

```
┌──────────────────────────────────────────────────────────┐
│              LEAD AGENT (orchestrator model)               │
│  Strategy, coordination, synthesis, gap detection          │
│  Has: project context + ROADMAP wrapper + all results      │
└────────────────────────┬─────────────────────────────────┘
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   ┌────────────┐ ┌────────────┐ ┌────────────┐
   │  Worker 1  │ │  Worker 2  │ │  Worker N  │
   │  ISOLATED  │ │  ISOLATED  │ │  ISOLATED  │
   │ ≤2K tokens │ │ ≤2K tokens │ │ ≤2K tokens │
   └──────┬─────┘ └──────┬─────┘ └──────┬─────┘
          └──────────────┼──────────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│           VERIFIER (fresh context, sees ONLY output)      │
│  Independent validation, citation check, factual accuracy │
└──────────────────────────────────────────────────────────┘
```

**Depth scaling:**

| Depth | Workers | Verifier | Model Mix | Est. Tokens |
|-------|---------|----------|-----------|-------------|
| `quick` | 1-2 | Inline (Lead verifies) | All sonnet | ~15K |
| `standard` | 3-5 | Independent (sonnet) | Lead=opus, workers=sonnet | ~35K |
| `deep` | 5-8 | Independent (opus) | Lead=opus, workers=sonnet, verifier=opus | ~50K |

---

## Pre-Flight Gates (MANDATORY — before spawning ANY agent)

### Gate 1: ROADMAP Alignment
```
Read ROADMAP.md. Does this research serve a NOW or NEXT item?
- NOW/NEXT → proceed silently
- LATER/unlinked → advisory: "This research isn't tied to active work. Proceed? (y/n)"
- No ROADMAP → proceed (not all projects use one)
```

### Gate 2: Memory Dedup
```
Search for existing research on this topic:
- Glob: .claude/memory/*{keywords}*
- Glob: council/sessions/*{keywords}*
- Glob: research-outputs/*{keywords}*
- Glob: specs/*{keywords}*

If prior research found:
  → Surface: "Found prior research: {file}. Created {date}. Incorporate or start fresh?"
  → If incorporate: Load as context for Lead, skip already-answered sub-questions
```

### Gate 3: Cost Estimate
```
Depth: {{depth}} → {{N}} workers × ~2K tokens each + Lead + Verifier
Estimated: ~{{total}}K tokens
Proceed? (y/n/adjust depth)
```

---

## Protocol: 6-Phase Execution

### Phase 0: Project Context (Lead only)

Lead reads project infrastructure — workers do NOT get this:
```
1. CLAUDE.md → stack, conventions, MCP servers, rules
2. .mcp.json → available data sources
3. Available tools → which research tools exist (Firecrawl, WebSearch, MCP servers)
```

Output: tool assignment map for workers.

### Phase 1: Strategy Development

Lead decomposes topic into independent sub-questions:
```
For each sub-question:
  - Specific question (not vague)
  - Assigned tools (based on Phase 0 tool detection)
  - Success criteria (what counts as "answered")
  - "Not Found" is an acceptable answer
```

**Source Accessibility Pre-Flight** (v1.1): Before spawning web research workers, assess key source domains:
- Paywalled (Bloomberg, WSJ, FT)? → Route worker to open-access alternatives
- API-gated? → Check if MCP tools provide access
- Likely blocked? → Assign Firecrawl (if available) instead of WebFetch

ROADMAP context wrapper (injected into Lead only, per Invariant 10B):
```
ROADMAP CONTEXT:
- Research serves: {ROADMAP item/milestone}
- NSM impact: {which metric, estimated delta}
- Constraint: {what the research must account for}
- Existing approach: {what already exists at {file:line}}
```

Save strategy to `research-outputs/{date}-{slug}-plan.md` if `persist=true`.

### Phase 2: Parallel Research (Isolated Workers)

Spawn workers using Agent tool. **CRITICAL: all workers in a SINGLE message for parallelism.**

Each worker receives ONLY their sub-question. See `references/worker-prompts.md` for templates.

#### Worker Types (v1.1)

Assign each sub-question to the correct type — different types have different tools and output expectations:

| Worker Type | Tools | Use When | Output Focus |
|-------------|-------|----------|--------------|
| **Web Research** | WebSearch, WebFetch, Firecrawl | External information, industry patterns, competitive analysis | URLs, quotes, source quality assessment |
| **Codebase Analysis** | Read, Grep, Glob | Internal code audit, pattern detection, infrastructure mapping | File paths, code snippets, architectural findings |
| **Document Audit** | Read (specific files) | Spec/plan gap analysis, structural review, consistency checks | Gaps organized by severity, missing considerations |

#### SOURCED vs SYNTHESIS Labeling (v1.1)

Workers MUST label each finding:
- `[SOURCED]` — direct citation from a specific URL/file with exact quote
- `[SYNTHESIS]` — inference drawn from multiple inputs, with reasoning and source list

This distinction is critical for verification — the Verifier validates SOURCED claims against URLs and evaluates SYNTHESIS claims for logical soundness.

#### Confidence Calibration Rubric (v1.1)

Shared across ALL workers to prevent uncalibrated confidence:
- **HIGH**: 3+ independent sources agree, OR 1 authoritative primary source (official docs, peer-reviewed)
- **MEDIUM**: 1-2 sources with no contradiction, OR authoritative source with caveats
- **LOW**: Inference from indirect evidence, single weak source, or extrapolation from adjacent domain

**Context Isolation Rules:**

| Agent | Project Context | Other Workers | Strategy | Prior Research |
|-------|----------------|---------------|----------|----------------|
| Lead | YES | YES (synthesizes) | YES (creates) | YES (from Gate 2) |
| Worker | NO | NO | NO | NO |
| Verifier | NO | NO | NO | NO |

**Why isolation matters:** Without it, Worker 2 sees Worker 1's answer and "confirms" it — amplifying a single source as consensus. With isolation, independent workers finding the same answer IS real consensus.

#### File-output worker pattern (when N ≥ 8 OR worker output expected > 2K tokens)

For high-N swarms, modify the worker prompt to add a file-output destination instead of returning the full output inline:

> Write your FULL output (3000+ words OK) to:
> `{output_path}/w{N}-{topic_slug}.md`
>
> After writing the file, return ONLY a 200-word summary in your reply:
> top 3-5 findings, biggest gap, file confirmation.

Lead reads files lazily during Phase 3 synthesis (one Read call per worker file in parallel). Cuts main-context token consumption ~10× vs returning full worker output inline. Standard for 8+ worker swarms; optional for ≤5 workers.

### Phase 3: Synthesis

Lead aggregates all worker results:
1. Collect outputs
2. Identify cross-worker themes
3. Flag contradictions (different workers, different answers)
4. Note single-source claims (lower confidence)
5. Detect coverage gaps → spawn additional workers if needed (max 1 iteration)

### Phase 4: Verification

**Skip in `quick` mode** (Lead self-verifies inline).

For `standard` and `deep`: spawn independent Verifier with fresh context.
Verifier sees ONLY the synthesized findings + source list. Never the research process.
See `references/worker-prompts.md` for verifier prompt template.

**Verifier HAS WebSearch + WebFetch** (v1.1): If a cited URL is inaccessible (paywalled, blocked, 403), the Verifier searches independently for the claim to corroborate or refute. "Cannot verify" is acceptable — but only after attempting alternative source discovery. Verifier also validates `[SYNTHESIS]` claims for logical soundness (not sourcing, since they are inferences by design).

#### When Verifier Returns PASS-WITH-CAVEATS

DO NOT silently edit the synthesis to apply corrections. Audit trail matters more than visual cleanliness — downstream challenge rounds and council deliberations need to see what the verifier caught.

Discipline:
1. Apply targeted inline edits for each verifier finding (correction, caveat, downgrade)
2. APPEND a "VERIFIER FINDINGS INTEGRATED" section at the bottom of the synthesis with:
   - Overall verdict (PASS / PASS-WITH-CAVEATS / NEEDS-REVISION)
   - List of corrections applied inline (with one-sentence reason each)
   - Top 3 strengths the verifier flagged (validate what worked)
   - Top 3 risks for downstream quotation (claims most likely to embarrass us)
   - Pointer to full verifier report file

### Phase 5: Output + Persistence

Generate final output in requested format. See `references/output-formats.md`.

**Persistence actions (when `persist=true`):**
1. Save report to `research-outputs/{date}-{slug}.md`
2. Ask: "Save key findings to memory? (y/n)" → write to `.claude/memory/`
3. If research identified actionable items → suggest task creation
4. If research informed a ROADMAP item → note in output for next `/daily-plan`

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Workers see each other's results | Collective delusion — single source amplified as consensus | Strict isolation per worker |
| Skip verification | Hallucinations and misrepresentations pass through | Independent verification mandatory (standard/deep) |
| Spawn 8 agents for a simple question | Token waste, coordination overhead | Use `depth` parameter — quick for simple, deep for complex |
| Workers speculate beyond evidence | Speculation becomes "fact" after synthesis | Explicit "NOT FOUND" reporting required |
| Skip memory dedup check | Redundant research wastes tokens and produces stale findings | Always check Gate 2 before spawning |
| Research without ROADMAP context | Generic advice disconnected from project priorities | Lead gets ROADMAP wrapper (Invariant 10B) |
| Verifier sees research process | Cannot independently validate — biased by process | Fresh context for Verifier, ONLY sees output |
| Share Firecrawl/web results between workers | Cross-contamination of source interpretation | Each worker fetches independently |
| Skip Phase 0 tool detection | Workers assigned tools that don't exist | Always detect available MCP/tools first |
| Inline all prompts in SKILL.md | 450+ lines, token-heavy on every load | Extract to references/, load on demand |
| Verifier has no WebSearch | Cannot verify paywalled/blocked sources | Verifier MUST have WebSearch fallback for independent corroboration |
| Workers don't label SOURCED vs SYNTHESIS | Verification can't distinguish citation from inference | Workers MUST label each finding as [SOURCED] or [SYNTHESIS] |
| No confidence rubric | "HIGH" means different things to different workers | Use calibrated rubric: HIGH=3+ sources, MEDIUM=1-2 sources, LOW=inference |

---

## Defaults Table

| Parameter | Default | Adjust When |
|-----------|---------|-------------|
| Lead model | opus | Never — strategy needs highest capability |
| Worker model | sonnet | haiku for simple factual lookups |
| Verifier model | opus (deep), sonnet (standard) | Match to stakes of the research |
| `max_agents` | 5 | Reduce for narrow topics, increase for deep |
| `depth` | standard | quick for <3 sources, deep for competitive analysis |
| `output_format` | SCQA | `GAP_TABLE` for plan verification, `BRIEF` for quick lookups, `bullet` for status updates, `narrative` for reports |
| `persist` | true | false for throwaway exploratory research |
| Max tokens/worker | 2000 | Reduce to 1000 for focused lookups |
| Max synthesis iterations | 2 | 1 for quick, 2 for standard/deep |

---

## Tool Assignment Heuristic

Detected at Phase 0, assigned per sub-question type:

| Sub-Question Type | Preferred Tool | Fallback |
|-------------------|---------------|----------|
| Web research, docs, articles | Firecrawl (if available) | WebSearch + WebFetch |
| Library/API documentation | Context7 (if available) | WebFetch on docs URL |
| Database schema/data | Supabase MCP / execute_sql | Grep migrations + types |
| Code patterns | Grep, Glob, Read | GitHub MCP search_code |
| Workflow analysis | n8n MCP tools | curl n8n API |
| Competitor analysis | Firecrawl deep_research | WebSearch + WebFetch |

---

## Reference Files (loaded on demand)

| File | Contents | Load When |
|------|----------|-----------|
| `references/worker-prompts.md` | Worker + Verifier prompt templates | Phase 2 + Phase 4 |
| `references/output-formats.md` | SCQA, bullet, narrative templates | Phase 5 |
| `references/memory-integration.md` | Memory check patterns, persistence rules | Gate 2 + Phase 5 |

---

## Error Recovery

| Error | Recovery |
|-------|----------|
| Worker timeout | Decompose sub-question further, retry narrower |
| All workers fail | Fallback to Lead-only with available tools |
| Verification finds major inaccuracies | Flag for human review, re-research specific claims |
| Sources contradict | Document both, confidence weighted by source quality/recency |
| Coverage gap after synthesis | Spawn 1-2 additional workers (max 1 gap-fill iteration) |
| MCP tool unavailable | Degrade to web-only research, note limitation |
| Prior research found but outdated | Incorporate as baseline, focus workers on delta/updates |

---

*Skill Version: 2.1 — Merged v1.1 field-tested fixes into v2.0*
*v2.1: Typed workers, calibrated confidence, SOURCED/SYNTHESIS labeling, verifier WebSearch fallback, source pre-flight, output format variants*
*v2.0: Pre-flight gates, memory-awareness, cost gate, ROADMAP wrapping, reference extraction, tool detection*
*v1.0: Original — context isolation, SCQA, independent verification*

<!-- AUDIT METADATA
source: /Users/justin/Documents/GitHub/claude-code-project-template/.claude/skills/agent-research/SKILL.md
audit_date: 2026-03-28
audit_grade: C+ (63/100) → target A (85+)
merge_actions: keep=3 upgrade=4 absorb=5 rewrite=2 supplement=1 drop=0
superior_patterns_absorbed: 5 (pre-flight, ROADMAP wrap, memory dedup, cost gate, post-research)
-->
