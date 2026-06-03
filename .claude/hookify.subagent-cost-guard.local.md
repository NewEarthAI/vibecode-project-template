---
name: subagent-cost-guard
enabled: true
event: PreToolUse
tool_matcher: Agent
action: addContext
---

**[subagent-cost-guard]** Before spawning, verify: (1) Could a direct Glob/Grep/Read achieve this? (2) Is the task complex enough to justify subagent token cost? (3) If multiple agents, are they truly independent?
