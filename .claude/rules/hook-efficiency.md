# Hook Efficiency Standards

## When Adding or Modifying Hooks

Every hook in this project must justify its existence against these criteria:

### 1. Minimal Token Footprint
- **Command hooks** (`jq`, shell): Preferred for simple conditionals. Zero LLM tokens consumed.
- **Prompt hooks**: Only when semantic judgment is required (e.g., "is this safe?"). Never for pattern matching that `jq` or `grep` can handle.
- **Agent hooks**: Last resort — only when the hook needs tool access (Read, Grep, Bash).
- **Rule**: If a `jq` one-liner can do it, don't use a prompt hook. If a prompt hook can do it, don't use an agent hook.

### 2. Fire Only When Relevant
- Every hook MUST have a narrow `matcher` — never match all tools when you only need one.
- Use conditional logic inside the hook to exit early (return `{}`) when the event isn't actionable.
- Example: The compact-reminder hook checks `status == "completed"` and returns `{}` for all other TaskUpdate calls.

### 3. Context Injection Over Blocking
- Prefer `hookSpecificOutput.additionalContext` (guidance injected into model context) over `decision: "block"`.
- Blocking hooks disrupt flow. Context injection steers behavior without stopping work.
- Only block for genuine safety concerns (destructive SQL, rm -rf, force push).

### 4. Timeout Discipline
- Command hooks: 5s max (they're doing jq/grep, not network calls)
- Prompt hooks: 10s max
- Agent hooks: 30s max (60s only for verification that requires multiple tool calls)
- A hook that times out is worse than no hook — it blocks the entire tool pipeline.

### 5. Optimal Timing
- **PostToolUse** on TaskUpdate (status=completed): Best time for housekeeping reminders (compact, commit, verify)
- **PreToolUse** on destructive tools: Best for safety gates
- **Stop**: Best for session-exit verification and summaries
- **SessionStart**: Best for context loading and mode setting
- **Never duplicate**: If hookify already covers a pattern with a prompt rule, don't add a command hook for the same thing.

### 6. Composability
- Hooks should be independent — no hook should depend on another hook having run first.
- If two hooks fire on the same event+matcher, they must not conflict.
- Template hooks (settings.json) and project hooks (settings.local.json) merge — design for coexistence.

## Anti-Patterns

| Pattern | Why It's Wrong | Fix |
|---------|---------------|-----|
| Prompt hook for `status == "completed"` check | Wastes LLM call on a string comparison | Use `jq` command hook |
| `matcher: "*"` (match everything) | Fires on every tool call, burns tokens | Narrow the matcher |
| Hook that `curl`s an external API | Network latency blocks tool pipeline | Use `async: true` or move to background |
| Duplicate hookify rule + command hook | Double-fires, conflicting guidance | Pick one mechanism |
| Hook without `timeout` | Defaults to 60s — can hang the session | Always set explicit timeout |
| Blocking hook for style preferences | Stops work for non-safety issues | Use additionalContext instead |
