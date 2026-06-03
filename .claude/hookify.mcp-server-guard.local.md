---
name: mcp-server-guard
enabled: false
event: PreToolUse
tool_matcher: PLACEHOLDER_REPLACE_WITH_BLOCKED_SERVERS
action: block
---

**[mcp-server-guard] BLOCKED — Wrong Project Server!**

This MCP server is NOT configured for this project.

**Active Servers:** {{ACTIVE_MCP_SERVERS}}
**Blocked Servers:** {{BLOCKED_MCP_SERVERS}}

Use the correct project server instead.

---

**Setup**: This hook starts DISABLED. Run `/setup` to detect your MCP servers and configure:
1. The `tool_matcher` regex with blocked server patterns
2. The active/blocked server lists above
3. Set `enabled: true`
