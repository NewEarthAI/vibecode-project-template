---
name: github-local-first
enabled: true
event: PreToolUse
tool_matcher: mcp__github__get_file_contents|mcp__github__search_code|mcp__github__list_commits
action: warn
---

**[github-local-first] CHECK: Is this repo cloned locally?**

GitHub MCP is slower, costs more tokens, and fails on auth issues. If the repo exists locally, use local tools instead.

**Locally cloned repos** (use Read/Glob/Grep/Bash `git log` instead):

Replace this block per machine with your own list. Each entry maps a repo nickname (as the operator types it in chat) to the local clone path:

- `{{repo-1}}` → `{{user_home}}/{{path-to-clone-1}}`
- `{{repo-2}}` → `{{user_home}}/{{path-to-clone-2}}`
- `claude-code-project-template` → `{{user_home}}/{{path-to-template-clone}}`

**Local alternatives by GitHub MCP tool:**
| Instead of | Use |
|---|---|
| `get_file_contents` | `Read` tool with local path |
| `search_code` | `Grep` tool on local clone |
| `list_commits` | `git log` via Bash on local clone |

**Only use GitHub MCP when:**
- The repo is NOT cloned locally
- You need cross-repo search across the org
- You need PR/issue data (no local equivalent)
