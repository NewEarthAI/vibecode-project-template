# MCP Tool Fallback Rules

## If MCP returns auth error, immediately fall back to CLI — do not retry MCP.

## Server → CLI Fallback Table

| Server | MCP Tool | CLI Fallback | When to Use |
|--------|----------|-------------|-------------|
| `github` | `get_file_contents` | `gh api repos/{owner}/{repo}/contents/{path}` | MCP auth error |
| `github` | `create_pull_request` | `gh pr create --title "..." --body "..."` | MCP auth error |
| `github` | `search_code` | `gh api search/code?q=...` | MCP auth error |
| `github` | Any | `gh api ...` | Any MCP auth failure |
| `supabase-*` | `execute_sql` | `supabase db execute --project-ref ...` | MCP timeout/error |
| `supabase-*` | `deploy_edge_function` | `supabase functions deploy <name> --project-ref ...` | MCP timeout |
| `n8n-*` | Any | `curl -H "X-N8N-API-KEY: $N8N_KEY" "https://<instance>.app.n8n.cloud/api/v1/..."` | MCP unavailable |

## GitHub Auth Recovery

If GitHub MCP auth fails:
```bash
gh auth status       # Check current auth
gh auth login        # Re-authenticate if needed
gh api repos/{owner}/{repo}/contents/CLAUDE.md  # Direct fallback
```

## General Rules

- **NEVER dump full MCP tool registries** — use mcp-patterns skill instead
- Risk levels: **SAFE** (proceed) → **READ** (proceed) → **WRITE** (confirm) → **ADMIN** (always confirm)
- Prefer local tools (Read, Glob, Grep) over MCP for file operations
- Prefer `browser_snapshot` over screenshots for element interaction
- Use `search_code` for codebase exploration, not `get_file_contents` recursively
