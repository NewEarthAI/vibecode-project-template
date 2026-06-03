---
name: context-hygiene
enabled: true
event: UserPromptSubmit
action: addContext
---

# Context Window Hygiene (Passive — Zero Action If Already Efficient)

Before processing this message, do a quick mental audit of your token efficiency:

## Don't Re-Read
- **Files already in context**: If you read a file earlier in this conversation and it hasn't been modified since, do NOT Read it again. Reference the content you already have.
- **Query results**: If you ran a SQL/API query and got results, don't re-run the same query. Reference the cached results.
- **Codebase structure**: If you've already explored routes/components/hooks, reference that knowledge instead of re-exploring.

## Right-Size Your Tools
| Need | Wrong (expensive) | Right (efficient) |
|------|-------------------|-------------------|
| Find a file by name | `Agent(Explore)` | `Glob("**/filename*")` |
| Find text in code | `Agent(Explore)` | `Grep("pattern", path="src/")` |
| Read 10 lines of a 500-line file | `Read(file)` (full) | `Read(file, offset=X, limit=10)` |
| Check if function exists | `Agent(Explore)` | `Grep("function name", type="ts")` |
| Understand one component | `Agent(Explore, "very thorough")` | `Read(component_file)` |

## Subagent Budget Rule
Before spawning any Agent, ask: "Can I get this in 1-2 direct tool calls instead?" If yes, skip the subagent. Subagents cost 5-10x more tokens than direct tool calls for simple lookups.

**This check costs ~0 tokens when you're already being efficient. It only saves tokens when you catch yourself about to be wasteful.**
