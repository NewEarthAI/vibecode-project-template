---
name: github-local-first
enabled: true
event: PreToolUse
tool_matcher: mcp__github__get_file_contents
action: warn
---

**[github-local-first] Prefer local tools over GitHub API!**

This repo is cloned locally. Use local tools instead of the GitHub MCP for file reads:

| Need | Tool | Example |
|------|------|---------|
| Read file | `Read` | `Read("src/components/MyComponent.tsx")` |
| Find files | `Glob` | `Glob("src/**/*.tsx")` |
| Search code | `Grep` | `Grep("functionName", path="src/")` |

GitHub API calls consume rate limits and are slower than local reads.
**Only use GitHub MCP** for: PR creation, issue tracking, cross-repo search, remote branch contents.
