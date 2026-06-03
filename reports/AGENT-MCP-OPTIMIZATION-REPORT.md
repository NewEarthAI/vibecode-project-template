# Agent Systems MCP Optimization Report

**Date**: 2025-01-16
**Scope**: agent-research, ralph-wiggum, n8n debug pipelines
**Objective**: Apply MCP token optimization without compromising agent quality

---

## Executive Summary

### Systems Analyzed

| System | Purpose | Loop Type | MCP Usage | Risk Profile |
|--------|---------|-----------|-----------|--------------|
| **agent-research** | Multi-agent deep research | Single execution | HIGH (WebSearch, GitHub, n8n, Supabase) | Medium |
| **ralph-wiggum** | Perpetual iteration loops | CONTINUOUS | VARIABLE (per-task) | HIGH (cumulative) |
| **n8n-mcp-skills** | n8n workflow management | Per-invocation | HIGH | Already optimized |

### Recommendations Overview

| Recommendation | Impact | Risk | Priority |
|----------------|--------|------|----------|
| Add optimization directives to agent prompts | HIGH savings | LOW risk | **P0** |
| Reference existing skills (don't duplicate) | Maintainability | NONE | **P0** |
| Create `loop-efficiency` skill for ralph | HIGH savings | LOW risk | **P1** |
| Add hookify rules to ralph-loop setup | AUTO-warnings | NONE | **P1** |
| Update agent-research worker prompts | MEDIUM savings | LOW risk | **P2** |

---

## Part 1: Agent-Research Analysis

### Current Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LEAD AGENT (Opus 4.5)                        │
│  MCP Calls: CLAUDE.md, .mcp.json, WebSearch, Supabase, n8n         │
│  Context: Full project + all worker results                         │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            ┌───────────┐   ┌───────────┐   ┌───────────┐
            │ Worker 1  │   │ Worker 2  │   │ Worker N  │
            │ (Sonnet)  │   │ (Sonnet)  │   │ (Sonnet)  │
            │ ISOLATED  │   │ ISOLATED  │   │ ISOLATED  │
            │ MCP: 1-3  │   │ MCP: 1-3  │   │ MCP: 1-3  │
            │ tools     │   │ tools     │   │ tools     │
            └───────────┘   └───────────┘   └───────────┘
```

### MCP Call Sites (Current)

| Phase | Agent | MCP Tools Used | Current Token Usage |
|-------|-------|----------------|---------------------|
| Phase 0 | Lead | Read, Glob | ~5K (acceptable) |
| Phase 3 | Workers | WebSearch, execute_sql, n8n_*, GitHub | **VARIABLE** |
| Phase 5 | Verifier | WebFetch (source validation) | ~2K (acceptable) |

### Token Waste Risk: MEDIUM

**Where waste CAN occur:**
- Workers calling `n8n_get_workflow({ mode: "full" })` when structure suffices
- Workers calling `execute_sql("SELECT * FROM ...")` without LIMIT
- Workers calling `get_file_contents` without tree check

**Where waste does NOT occur:**
- WebSearch is already efficient (returns summaries)
- Context isolation already limits total worker output to 2K tokens
- Verifier only validates sources (minimal MCP)

### Recommended Changes

#### 1. Update Worker Prompt Template (LOW RISK)

**Location**: `agent-research/SKILL.md` Phase 3 prompt

```markdown
# ADD to worker prompt template (line ~200):

<mcp_efficiency>
When using MCP tools, follow these rules:
- n8n: Use mode="structure" unless editing (saves 95%)
- SQL: Select specific columns + LIMIT 20 (saves 60-80%)
- GitHub: Use tree API before get_file_contents (saves 90%)
- Never use mode="full" unless explicitly required for editing
</mcp_efficiency>
```

**Why this is safe:**
- Workers don't edit data - they research
- Structure/summary modes provide all info needed for research
- Does NOT change worker behavior, only tool parameter defaults

#### 2. Reference Skills in Lead Agent Context (NO RISK)

**Current Phase 0 reads:**
- CLAUDE.md
- .mcp.json
- .claude/skills/

**Recommendation**: Ensure Lead Agent extracts optimization rules from CLAUDE.md's "Mandatory Skills" section and passes relevant constraints to workers.

**No code change needed** - The CLAUDE.md template already includes MCP token optimizer rules. Lead agent reads this in Phase 0.

### What NOT to Change

| Component | Why Leave Alone |
|-----------|-----------------|
| Worker context isolation | Critical for research integrity |
| 2K token output limit | Already optimal |
| Opus for Lead/Verifier | Strategy requires highest capability |
| Sonnet for workers | Cost-efficiency already optimized |
| WebSearch usage | Already returns summaries |

---

## Part 2: Ralph-Wiggum Analysis

### Current Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RALPH LOOP (PERPETUAL)                            │
│                                                                      │
│   Iteration 1 → Iteration 2 → Iteration 3 → ... → Iteration N       │
│       ↓             ↓             ↓                    ↓             │
│   [MCP calls]   [MCP calls]   [MCP calls]         [MCP calls]       │
│                                                                      │
│   CUMULATIVE COST = N × (MCP tokens per iteration)                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Token Waste Risk: **CRITICAL**

**Why ralph-wiggum is highest risk:**
- Runs in **perpetual loops** (50+ iterations typical)
- Same inefficient call pattern repeats N times
- No feedback mechanism to detect waste mid-loop
- User "walks away" so no intervention possible

**Example waste scenario:**
```
Per iteration: 50K tokens (using full mode)
Iterations: 50
Total waste: 2.5M tokens (vs 250K with structure mode)
```

### Critical Optimization Points

#### 1. Create `loop-efficiency` Skill (HIGH PRIORITY)

**Purpose**: Teach Claude to use minimal MCP modes during loops because:
- Loop reads its own file outputs (not MCP responses)
- Most MCP calls are for status checks, not data extraction
- Full mode is RARELY needed in loop context

**Proposed skill** (`loop-efficiency/SKILL.md`):

```markdown
---
name: loop-efficiency
description: |
  MCP optimization for perpetual loops (ralph-wiggum, iterative builds).
  Use when running /ralph-loop or any multi-iteration autonomous task.
  Critical: Cumulative token usage = iterations × per-call cost.
---

# Loop Efficiency Skill

## Why This Matters

In perpetual loops:
- 50 iterations × 50K tokens/iteration = 2.5M tokens wasted
- 50 iterations × 2K tokens/iteration = 100K tokens (96% savings)

## Loop-Specific Rules

### 1. Status Checks (MOST COMMON)

| Need | Wrong | Right |
|------|-------|-------|
| "Is workflow active?" | `n8n_get_workflow(mode="full")` | `n8n_list_workflows()` |
| "Did build succeed?" | `Read entire log file` | `tail -20 build.log` |
| "What tables exist?" | `execute_sql("SELECT * FROM...")` | `list_tables()` |

### 2. Progress Verification

Use **file-based** verification over MCP when possible:

```bash
# Check test results from file (0 tokens)
cat test-results.json | jq '.failed'

# vs MCP call (variable tokens)
execute_sql("SELECT COUNT(*) FROM test_runs...")
```

### 3. Mode Selection During Loops

| Iteration Purpose | Mode |
|-------------------|------|
| Check status | minimal |
| Verify structure | structure |
| Debug failure | error |
| Export final | full (LAST iteration only) |

### 4. Caching Strategy

If you need the same data multiple iterations:
1. Fetch once with appropriate mode
2. Write to local file
3. Read from file in subsequent iterations

## Anti-Patterns in Loops

### ❌ Repeating full fetches

```javascript
// EVERY iteration:
n8n_get_workflow({ id: "abc", mode: "full" })  // 50K × N
```

### ✅ Fetch once, cache locally

```javascript
// Iteration 1:
n8n_get_workflow({ id: "abc", mode: "full" })
Write("workflow-cache.json", result)

// Iterations 2-N:
Read("workflow-cache.json")  // 0 MCP tokens
```
```

#### 2. Modify ralph-loop Setup to Enable Hookify (MEDIUM PRIORITY)

**Location**: `ralph-wiggum/scripts/setup-ralph-loop.sh`

**Current**: Sets up loop with prompt file
**Proposed**: Also copy hookify rules to project if not present

```bash
# Add to setup-ralph-loop.sh:

# Copy MCP optimization hookify rules if not present
for rule in supabase-select-star n8n-executions-full github-file-contents playwright-full-page; do
  if [ ! -f ".claude/hookify.${rule}.local.md" ]; then
    cp "${CLAUDE_PLUGIN_ROOT}/hookify-rules/hookify.${rule}.local.md" ".claude/" 2>/dev/null || true
  fi
done
```

**Why this helps:**
- PreToolUse warnings fire BEFORE inefficient calls
- User doesn't need to remember optimization rules
- Works even during unattended loops (warnings still fire)

#### 3. Add Optimization Guidance to ralph-loop Prompt (LOW RISK)

**Location**: `ralph-wiggum/commands/ralph-loop.md`

**Add to command output:**

```markdown
## MCP Efficiency Reminders

During this loop, optimize MCP calls:
- n8n: mode="structure" (not "full") unless editing
- SQL: Specific columns + LIMIT (not SELECT *)
- Files: Check size before fetching large files
- Status: Use list/count operations over full fetches

For iteration-specific data, write to files and read locally
to avoid repeated MCP calls.
```

### What NOT to Change

| Component | Why Leave Alone |
|-----------|-----------------|
| Stop hook mechanism | Core loop functionality |
| Completion promise logic | Correctness over speed |
| Max iterations limit | Safety mechanism |
| Prompt persistence | Loop identity depends on it |

---

## Part 3: Pipeline Debug Swarm Analysis (CRITICAL)

### System Overview

The **Nirvana Pipeline Debug Swarm** is a sophisticated multi-agent orchestration system for debugging the WhatsApp → n8n → Supabase → Dashboard pipeline. It runs autonomously, often in perpetual ralph-wiggum loops.

**Location**: `my-project/.claude/agents/`

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│              PIPELINE DEBUG MANAGER (Opus)                         │
│  MCP: Supabase, n8n (full access including workflow modifications)  │
│  Spawns agents, maintains state, coordinates investigation          │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
    ┌───────────────────┐  ┌───────────────┐  ┌────────────────────┐
    │ LIFECYCLE TRACKER │  │ SECONDARY     │  │ REMEDIATION        │
    │ (Opus - Primary)  │  │ AGENTS        │  │ ORCHESTRATOR       │
    │ Always first!     │  │ (Haiku)       │  │ (for fixes)        │
    │ MCP: SQL, n8n     │  │ MCP: SQL, n8n │  │ MCP: Full          │
    └───────────────────┘  └───────────────┘  └────────────────────┘
                                  │
            ┌─────────────┬───────┴────────┬─────────────┐
            ▼             ▼                ▼             ▼
    ┌─────────────┐ ┌───────────┐ ┌──────────────┐ ┌──────────┐
    │ ingestion   │ │ batching  │ │ enrichment   │ │ correlation│
    │ debug       │ │ debug     │ │ debug        │ │ debug      │
    └─────────────┘ └───────────┘ └──────────────┘ └──────────────┘
    ┌─────────────┐ ┌───────────┐ ┌──────────────┐ ┌──────────┐
    │ persistence │ │ fuel      │ │ supabase     │ │ dashboard │
    │ debug       │ │ debug     │ │ expert       │ │ verifier  │
    └─────────────┘ └───────────┘ └──────────────┘ └──────────────┘
```

### Agent Inventory (10+ agents)

| Agent | Model | MCP Usage | Token Risk |
|-------|-------|-----------|------------|
| `pipeline-debug-manager` | Opus | HIGH (orchestrates all) | CRITICAL |
| `message-lifecycle-tracker-agent` | Opus | HIGH (20+ SQL queries) | HIGH |
| `correlation-debug-agent` | Haiku | MEDIUM (5+ SQL, n8n calls) | MEDIUM |
| `enrichment-debug-agent` | Haiku | MEDIUM (SQL, workflow checks) | MEDIUM |
| `persistence-debug-agent` | Haiku | MEDIUM | MEDIUM |
| `batching-debug-agent` | Haiku | LOW-MEDIUM | LOW |
| `ingestion-debug-agent` | Haiku | LOW | LOW |
| `fuel-debug-agent` | Haiku | MEDIUM | MEDIUM |
| `supabase-expert` | Haiku | HIGH (schema queries) | MEDIUM |
| `dashboard-verifier` | Haiku | MEDIUM | LOW |
| `remediation-orchestrator-agent` | Opus | HIGH (applies fixes) | HIGH |

### Token Waste Risk: **CRITICAL** (In Perpetual Loops)

**Why this swarm is highest risk:**

1. **Multi-agent multiplication**: Each investigation spawns 2-5 agents
2. **Query-heavy**: Lifecycle tracker alone has 20+ SQL templates
3. **n8n execution checks**: Multiple workflow execution queries per investigation
4. **Perpetual loop compound**: In ralph mode, waste multiplies across iterations
5. **Opus for strategy agents**: High per-token cost for manager + lifecycle tracker

**Example waste scenario (single investigation):**
```
Pipeline Debug Manager: ~10K tokens (orchestration + SQL)
Lifecycle Tracker: ~15K tokens (20+ queries)
Secondary Agent (e.g., correlation): ~8K tokens
─────────────────────────────────────────────────
Single investigation: ~33K tokens

In ralph loop (50 iterations):
50 × 33K = 1.65M tokens!
```

### Current MCP Patterns (Issues Found)

#### Issue 1: n8n_executions Without Mode

**Current code in agent prompts:**
```javascript
n8n_executions({
  action: 'list',
  workflowId: 'RJiJl1UaoQYDw5AG',
  limit: 10
})
```

**Problem**: No mode specified → defaults to expensive full execution data

**Should be:**
```javascript
n8n_executions({
  action: 'list',
  workflowId: 'RJiJl1UaoQYDw5AG',
  limit: 10,
  mode: 'summary'  // or 'error' if debugging failures
})
```

**Token savings**: 80-90% per call

#### Issue 2: n8n_get_workflow Inconsistency

**Some calls correctly use mode:**
```javascript
n8n_get_workflow({ id: "dYS2icacoLzqml5Y", mode: "structure" })  // ✓ Good
```

**Others don't:**
```javascript
n8n_get_workflow({ id: "RJiJl1UaoQYDw5AG" })  // ✗ Defaults to full
```

**Should always specify mode.**

#### Issue 3: SQL Queries (MOSTLY GOOD)

**Good patterns already in use:**
```sql
-- Specific columns + LIMIT (lifecycle tracker)
SELECT id, message_id, current_stage, completeness_score,
       enrichment_fleet_number, correlation_event_id,
       last_error_stage, last_error_message, error_count
FROM message_lifecycle
WHERE enrichment_fleet_number = '[target_fleet]'
  AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC LIMIT 10;
```

✅ The SQL patterns are mostly well-optimized already!

### What's Already Good

| Pattern | Status | Why It's Good |
|---------|--------|---------------|
| Model selection | ✅ Excellent | Opus for strategy, Haiku for execution |
| File-based checkpointing | ✅ Excellent | Zero MCP tokens for state |
| SQL query patterns | ✅ Good | Specific columns + LIMIT in most queries |
| Agent specialization | ✅ Good | Focused MCP tool access per agent |
| Lifecycle-first investigation | ✅ Excellent | Query message_lifecycle before spawning agents |

### Recommended Changes

#### 1. Add MCP Efficiency Block to Manager Prompt (P0 - HIGH PRIORITY)

**Location**: `pipeline-debug-manager.md` (after SYSTEM CONTEXT section)

```markdown
## MCP EFFICIENCY PROTOCOL

**CRITICAL for perpetual loop execution.** Token savings compound across iterations.

### n8n Tool Modes (MANDATORY)
| Tool | Default | For Debugging | For Editing |
|------|---------|---------------|-------------|
| `n8n_get_workflow` | mode="structure" | mode="structure" | mode="full" |
| `n8n_executions` | mode="summary" | mode="error" | mode="full" |
| `get_node` | detail="minimal" | detail="standard" | detail="full" |

### SQL Patterns (ENFORCE)
Always use: Specific columns + LIMIT (already in query templates)

### Sub-Agent Efficiency
When spawning secondary agents, include in prompt:
- "Use mode='error' for n8n_executions unless debugging full data flow"
- "SQL queries should select specific columns, never SELECT *"

### Why This Matters
50 iterations × 33K tokens = 1.65M tokens wasted
50 iterations × 8K tokens (optimized) = 400K tokens
SAVINGS: 75%+ per loop session
```

#### 2. Update n8n_executions Examples in All Agents (P1)

**Files to update:**
- `message-lifecycle-tracker-agent.md` (line ~155-160)
- `correlation-debug-agent.md` (line ~100-108)
- `enrichment-debug-agent.md` (line ~76-90)
- All other agents with n8n_executions calls

**Change pattern:**
```javascript
// BEFORE
n8n_executions({
  action: 'list',
  workflowId: 'nxhvndSUKhKRFTPK',
  limit: 20
})

// AFTER
n8n_executions({
  action: 'list',
  workflowId: 'nxhvndSUKhKRFTPK',
  limit: 20,
  mode: 'summary'  // Use 'error' for failure debugging
})
```

#### 3. Reference CLAUDE.md Mandatory Skills Section (P1)

**Add to pipeline-debug-manager.md initialization:**

```markdown
### Step 2: Prime Context
1. Confirm MCPs available: supabase-nirvana, n8n-mcp-newearthai
2. READ my-project/.claude/skills/fleet-ops-debugger/SKILL.md
3. **READ CLAUDE.md "Mandatory Skills" section for MCP efficiency rules**
4. Note test fleet = 998
```

### What NOT to Change

| Component | Why Leave Alone |
|-----------|-----------------|
| Opus for manager/lifecycle | Strategy requires capability |
| Haiku for secondary agents | Already cost-optimized |
| File-based checkpointing | Perfect pattern (0 MCP tokens) |
| SQL query column selection | Already well-optimized |
| Lifecycle-first protocol | Excellent efficiency pattern |
| Agent specialization | Appropriate tool scoping |

### Integration with Existing Optimizations

**Don't create custom skills for this swarm.**

The agents should:
1. **Read CLAUDE.md** (already in initialization) → Gets MCP efficiency rules
2. **Follow query templates** (already optimized for SQL)
3. **Add mode parameters** to n8n calls (simple prompt update)

**Hookify rules complement this:**
- `hookify.n8n-executions-full.local.md` → Warns if mode="full" used
- `hookify.supabase-select-star.local.md` → Warns on SELECT * (rare in this swarm)

---

## Part 4: n8n-mcp-skills Analysis

### Current State: ALREADY OPTIMIZED

The `n8n-mcp-tools-expert` skill already includes:

| Pattern | Recommendation | Already Implemented? |
|---------|----------------|---------------------|
| Use `get_node_essentials` over `get_node_info` | ✅ Yes | Line 148-168 |
| Validation profiles | ✅ Yes | Line 170-189 |
| nodeType format guidance | ✅ Yes | Line 91-132 |
| Iterative workflow building | ✅ Yes | Line 299-323 |

### Recommendation: NO CHANGES NEEDED

The n8n-mcp-skills plugin is already aligned with MCP token optimization principles. The skills were designed with efficiency in mind.

**Integration point**: The `mcp-token-optimizer` skill references patterns from n8n-mcp-skills:

```markdown
# In mcp-token-optimizer/references/n8n-patterns.md:
See the n8n-mcp-tools-expert skill for detailed tool guidance.
```

---

## Part 4: Integration Strategy

### Question: Custom Skills vs. References?

| Approach | Pros | Cons |
|----------|------|------|
| **Custom skills per agent** | Agent-specific tuning | Maintenance burden, duplication |
| **Reference existing skills** | Single source of truth, auto-updates | Requires agent to read CLAUDE.md |
| **Hybrid** | Best of both | Slight complexity |

### Recommendation: HYBRID APPROACH

1. **Core optimization skills** remain in `mcp-token-optimizer` plugin (single source of truth)
2. **Agent-specific guidance** added to agent prompts (minimal, targeted)
3. **Loop-efficiency skill** created as specialized extension for perpetual loops
4. **Hookify rules** provide automatic warnings regardless of skill knowledge

### Implementation Plan

#### Phase 1: Zero-Risk Updates (Do Now)

| Change | Location | Risk |
|--------|----------|------|
| Add MCP efficiency section to agent-research worker prompt | `agent-research/SKILL.md` | None |
| Verify CLAUDE.md template includes MCP skills | Already done | None |

#### Phase 2: Low-Risk Enhancements (This Week)

| Change | Location | Risk |
|--------|----------|------|
| Create `loop-efficiency` skill | New skill file | Low |
| Add hookify rule copy to ralph-loop setup | Script modification | Low |
| Add optimization reminder to ralph-loop output | Command file | Low |

#### Phase 3: Monitoring (Ongoing)

| Metric | Tool | Target |
|--------|------|--------|
| Tokens per ralph iteration | Claude usage stats | <5K average |
| Research agent total tokens | Claude usage stats | <50K per research |
| Hookify warning frequency | Manual review | Decreasing over time |

---

## Part 5: Specific File Changes

### 1. Update agent-research SKILL.md

**File**: `.claude/skills/agent-research/SKILL.md`
**Lines**: ~200 (Phase 3 worker prompt)

```markdown
# ADD after <rules> section in worker prompt:

<mcp_efficiency>
MCP Tool Optimization (MANDATORY):
- n8n_get_workflow: Use mode="structure" (not "full")
- execute_sql: Select specific columns + LIMIT 20
- get_file_contents: Check file size via tree API first
- n8n_executions: Use mode="error" for debugging

Rationale: Your output is limited to 2K tokens anyway.
Full MCP responses waste context without adding value.
</mcp_efficiency>
```

### 2. Create loop-efficiency Skill

**File**: `~/.claude/plugins/local/mcp-optimizer/skills/loop-efficiency/SKILL.md`

(See full content in Part 2 above)

### 3. Update ralph-loop Setup Script

**File**: `ralph-wiggum/scripts/setup-ralph-loop.sh`

```bash
# Add after prompt file creation:

# Enable MCP optimization hookify rules for the loop
echo "Enabling MCP optimization rules for loop efficiency..."
for rule in supabase-select-star n8n-executions-full github-file-contents playwright-full-page; do
  src="${HOME}/.claude/hookify.${rule}.local.md"
  dst=".claude/hookify.${rule}.local.md"
  if [ -f "$src" ] && [ ! -f "$dst" ]; then
    mkdir -p .claude
    cp "$src" "$dst"
    echo "  ✓ Enabled: $rule"
  fi
done
```

### 4. Update ralph-loop Command Output

**File**: `ralph-wiggum/commands/ralph-loop.md`

```markdown
# ADD to command output (after critical rule):

## Efficiency Notes

This loop may run many iterations. To minimize token costs:
- Use minimal MCP modes (structure, error, summary)
- Cache frequently-accessed data to local files
- Prefer file-based checks over repeated MCP calls
- Full mode only when editing (typically final iteration)

Hookify rules will warn you about inefficient MCP calls.
```

---

## Part 6: What NOT to Do (Negative Impact Risks)

### ❌ Do NOT restrict Lead Agent MCP access

**Why**: Lead needs full context for strategy. Optimization is WORKER-level.

### ❌ Do NOT add mode parameters to WebSearch

**Why**: WebSearch already returns summaries. No mode parameter exists.

### ❌ Do NOT cache verification agent results

**Why**: Verification MUST be fresh to catch hallucinations.

### ❌ Do NOT reduce worker output limits below 2K

**Why**: Research quality depends on evidence. 2K is already optimal.

### ❌ Do NOT auto-cancel ralph loops based on token usage

**Why**: Completion depends on task, not tokens. Would cause premature exits.

### ❌ Do NOT add optimization checks to Stop hook

**Why**: Stop hook handles completion promise only. Adding complexity risks loop failure.

---

## Part 7: Success Metrics

### Before Optimization (Baseline)

| Metric | Current | Source |
|--------|---------|--------|
| Ralph loop tokens/iteration | ~15-50K | Variable (uncontrolled) |
| Agent-research worker MCP usage | ~5-20K per worker | Variable |
| Hookify warning rate | N/A | Not tracked |

### After Optimization (Targets)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Ralph loop tokens/iteration | <5K average | Claude usage stats |
| Agent-research worker MCP usage | <3K per worker | Claude usage stats |
| Hookify warning rate | Decreasing trend | Manual review weekly |

### ROI Calculation

```
Conservative scenario:
- Ralph loops: 5 loops/day × 50 iterations × 45K tokens saved = 11.25M tokens/day saved
- Research agents: 2 runs/day × 5 workers × 10K saved = 100K tokens/day saved

Total: ~11.35M tokens/day = ~340M tokens/month
At $0.003/1K tokens: ~$1,000/month savings
```

---

## Appendix A: Skill Reference Map

```
mcp-token-optimizer/
├── SKILL.md                     ← Core optimization patterns
├── references/
│   ├── n8n-patterns.md         ← n8n-specific (all agents)
│   ├── supabase-patterns.md    ← SQL optimization
│   ├── playwright-patterns.md  ← Browser automation
│   └── github-patterns.md      ← GitHub API patterns
└── examples/
    └── decision-tree.md        ← Visual flowchart

progressive-disclosure/
├── SKILL.md                    ← 3-tier loading strategy
└── examples/
    ├── n8n-workflow-exploration.md
    └── codebase-exploration.md

loop-efficiency/ (NEW)
├── SKILL.md                    ← Ralph-specific patterns
└── examples/
    └── iteration-caching.md    ← Local caching patterns
```

---

## Appendix B: Integration Checklist

### Pre-Implementation
- [ ] Review current agent-research token usage baseline
- [ ] Review current ralph-wiggum token usage baseline
- [ ] Confirm hookify plugin installed

### Implementation
- [ ] Update agent-research SKILL.md worker prompt
- [ ] Create loop-efficiency skill
- [ ] Update ralph-loop setup script
- [ ] Update ralph-loop command output
- [ ] Test with sample research task
- [ ] Test with sample ralph loop

### Post-Implementation
- [ ] Monitor token usage for 1 week
- [ ] Review hookify warning frequency
- [ ] Adjust thresholds if needed
- [ ] Document any issues encountered

---

*Report generated: 2025-01-16*
*Next review: After 1 week of usage*
