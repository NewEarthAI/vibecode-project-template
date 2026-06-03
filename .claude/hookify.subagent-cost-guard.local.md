---
name: subagent-cost-guard
enabled: true
event: PreToolUse
tool_matcher: Agent
action: addContext
---

# Subagent Cost Guard — Is This Agent Necessary?

**STOP.** Before spawning this subagent, answer honestly:

## The 3-Query Test

Could you get the same information with **3 or fewer** direct tool calls?

| What you need | Direct approach (10-50 tokens) | Agent approach (500-2000 tokens) |
|---------------|-------------------------------|----------------------------------|
| Find a file | `Glob("**/filename*")` | Agent(Explore) — 10-50x more expensive |
| Find text in code | `Grep("pattern", type="ts")` | Agent(Explore) — wastes tokens on setup |
| Read a specific file | `Read("path/to/file")` | Agent(Explore) — adds tool-calling overhead |
| Check if something exists | `Grep("className", path="src/")` | Agent(Explore) — overkill |
| Understand a module | `Read` the 2-3 key files | Agent(Explore, "very thorough") — reads 20+ files |

**If YES to the 3-query test** → Cancel the Agent. Use direct tools instead.

## When Agents ARE Justified

- **Broad codebase exploration**: "How does authentication work across the app?" (touches 10+ files)
- **Multi-step research**: "Find all consumers of this RPC and their error handling" (requires chaining queries)
- **Parallel independence**: Multiple unrelated research questions that can run simultaneously
- **Deep analysis**: Architecture review, security audit, test coverage analysis

## Throughput Check

- **Explore agents**: Use `"quick"` for known paths, `"medium"` for moderate search, `"very thorough"` only for genuinely complex analysis
- **Plan agents**: Only when you need architectural analysis, not for "should I use X or Y?"
- **general-purpose agents**: Only for multi-step tasks that genuinely need tool access

## Cost Reality

| Agent Type | Typical Token Cost | Direct Tool Equivalent |
|------------|-------------------|----------------------|
| Explore (quick) | 500-1500 tokens | 2-3 Grep/Glob calls: 50-150 tokens |
| Explore (thorough) | 2000-5000 tokens | 5-10 Read calls: 200-500 tokens |
| Plan | 3000-8000 tokens | Manual Read + analysis: 500-1000 tokens |
| general-purpose | 5000-15000 tokens | Depends on task complexity |

**Rule of thumb**: If you can describe what you need in one sentence, you don't need a subagent.
