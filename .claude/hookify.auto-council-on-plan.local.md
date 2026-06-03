---
name: auto-council-on-plan
enabled: true
event: PreToolUse
tool_matcher: ExitPlanMode
action: addContext
---

## Plan Complete — Council Review Available

You just exited plan mode. Before implementing, consider running:

```
/council --extended "Review: [plan title from specs/]"
```

**Why**: Council catches strategic blind spots, over-engineering, and missing constraints that save hours during implementation. Use `/amend-plan` afterward to apply council recommendations.

**Skip if**: Trivial change, single-file edit, or plan was already council-reviewed.
