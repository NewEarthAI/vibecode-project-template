# Hooks, Rules & Permissions — Standardization Guide

> **Purpose**: Ensure every Claude Code project has production-grade safety, token efficiency, and behavioral enforcement. This guide covers all three enforcement layers and how they interact.

---

## The Three Enforcement Layers

Claude Code has three distinct layers for controlling agent behavior. Each serves a different purpose:

```
Layer 1: HOOKIFY RULES     (.claude/hookify.*.local.md)
         → Behavioral guidance injected into Claude's context
         → Can: warn, block (tool_matcher), inject context (addContext)
         → Managed by: hookify plugin
         → Fires on: SessionStart, PreToolUse, PostToolUse, Stop, UserPromptSubmit

Layer 2: SHELL HOOKS        (.claude/hooks/*.sh)
         → External scripts executed by Claude Code runtime
         → Can: hard-block (exit 2), permit (exit 0), inject feedback
         → Managed by: settings.local.json "hooks" section
         → Fires on: PreToolUse, PostToolUse, Stop (registered per-event)

Layer 3: PERMISSIONS         (.claude/settings.local.json "permissions")
         → Pre-approve or deny tool calls silently
         → Can: auto-allow (skip permission prompt), deny (never allow)
         → Managed by: settings.local.json "permissions" section
         → Fires on: every tool call (before hooks)
```

### How They Interact (Order of Execution)

```
Tool Call Initiated
  ↓
1. PERMISSIONS CHECK (settings.local.json → permissions.allow/deny)
   → If denied: tool blocked silently
   → If allowed: skip user prompt, proceed to hooks
   → If not listed: prompt user for approval

2. HOOKIFY RULES (hookify.*.local.md with matching tool_matcher)
   → action: block → inject block message, tool NOT executed
   → action: warn  → inject warning, tool still executes
   → action: addContext → inject context, tool still executes

3. SHELL HOOKS (settings.local.json → hooks.PreToolUse)
   → exit 0 → permit (tool executes)
   → exit 2 → hard block (tool NOT executed, Claude sees error)

4. TOOL EXECUTES

5. POST-HOOKS (hookify PostToolUse + shell hooks.PostToolUse)
```

**Key insight**: Hookify `block` and shell hook `exit 2` are DIFFERENT mechanisms:
- Hookify block: injects a message telling Claude not to proceed (behavioral)
- Shell hook exit 2: runtime hard-blocks the tool call (mechanical)
- Defense-in-depth: use BOTH for critical safety (e.g., destructive SQL)

---

## Standard Rule Categories

Every project should have rules covering these categories:

### Category 1: Critical Safety (HARD BLOCKS)

| Rule | Type | Purpose | Generic? |
|------|------|---------|----------|
| `sql-guardian.sh` | Shell hook | Block DELETE without WHERE, TRUNCATE, DROP TABLE/FUNCTION/VIEW | Yes |
| `supabase-destructive-sql` | Hookify warn | Pre-flight checklist for destructive SQL | Yes |
| `filesystem-safety` | Hookify warn | Scan Bash for rm -rf, force push, reset --hard | Yes |
| `n8n-workflow-delete-block` | Hookify block | Block workflow deletion | Yes (if using n8n) |

### Category 2: Token Optimization (CONTEXT INJECTION)

| Rule | Type | Purpose | Generic? |
|------|------|---------|----------|
| `supabase-auto-load` | Hookify addContext | Query optimization patterns (90-98% savings) | Yes |
| `n8n-auto-load` | Hookify addContext | Mode reference + data flow integrity | Yes (if using n8n) |
| `supabase-select-star` | Hookify block | Block SELECT * (wastes tokens on JSONB) | Yes |
| `supabase-list-tables-warn` | Hookify block | Block list_tables (480KB response) | Yes |
| `n8n-fetch-blocker` | Hookify block | Block mode='full' (150KB+) | Yes (if using n8n) |
| `n8n-executions-full` | Hookify block | Block executions mode='full' (500KB+) | Yes (if using n8n) |
| `n8n-use-essentials` | Hookify block | Use get_node_essentials over get_node_info | Yes (if using n8n) |
| `github-file-contents` | Hookify warn | Suggest Tree API for file discovery | Yes |

### Category 3: Session Management

| Rule | Type | Purpose | Generic? |
|------|------|---------|----------|
| `session-summarizer.sh` | Shell hook | Session summary + ROADMAP health check | Yes |
| `auto-rules` | Hookify addContext | Universal token rules + hook table | Yes |
| `confident-mode` | Hookify addContext | Smart permission model | Yes |
| `progress-logger` | Hookify addContext | PostToolUse mutation logger | Yes |
| `roadmap-freshness` | Hookify addContext | Stop event: remind to update ROADMAP.md | Yes |

### Category 4: Planning Protocol

| Rule | Type | Purpose | Generic? |
|------|------|---------|----------|
| `plan-mode-enforcer` | Hookify addContext | Enforce planning protocol in plan mode | Yes |
| `plan-mode-exit-gate` | Hookify addContext | 5-phase checklist before exiting plan mode | Yes |

### Category 5: MCP Server Guards

| Rule | Type | Purpose | Generic? |
|------|------|---------|----------|
| `mcp-server-guard` | Hookify block | Block disabled/wrong-project MCP servers | **Project-specific** |

### Category 6: Workflow Safety (n8n-specific)

| Rule | Type | Purpose | Generic? |
|------|------|---------|----------|
| `n8n-update-safety` | Hookify warn | Field passthrough + AI node parameter checks | Yes (if using n8n) |

### Category 7: Browser/UI

| Rule | Type | Purpose | Generic? |
|------|------|---------|----------|
| `playwright-full-page` | Hookify block | Block fullPage screenshots (3-10x larger) | Yes |

---

## Setting Up a New Project (Checklist)

### Step 1: Install Hookify Plugin

Ensure the hookify plugin is enabled globally:

```bash
# Check: should see hookify@claude-code-plugins in enabledPlugins
cat ~/.claude/settings.json | jq '.enabledPlugins'
```

If not enabled, add it via Claude Code settings or run:
```
/hookify help
```

### Step 2: Pull Template Rules

Run `/update-latest` to pull all template-managed hookify rules and shell hooks.

### Step 3: Register Shell Hooks (CRITICAL — Often Missed)

Shell hooks MUST be registered in `.claude/settings.local.json` to fire. This is the most common gap.

**Create or update** `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__supabase-*__execute_sql",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/sql-guardian.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/session-summarizer.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

**Make executable:**
```bash
chmod +x .claude/hooks/*.sh
```

### Step 4: Configure Permissions (Confident Mode)

Add a `permissions` section to `.claude/settings.local.json` that pre-approves safe operations. This eliminates constant permission prompts while keeping destructive ops gated.

**Always Allow** (customize tool prefixes for your MCP servers):
```json
{
  "permissions": {
    "allow": [
      "Bash(ls:*)", "Bash(git status:*)", "Bash(git log:*)", "Bash(git diff:*)",
      "Bash(git add:*)", "Bash(git commit:*)", "Bash(git stash:*)",
      "Bash(curl:*)", "Bash(python3:*)", "Bash(node:*)", "Bash(npm:*)",
      "Skill(*)",
      "mcp__supabase-YOUR_PROJECT__execute_sql",
      "mcp__supabase-YOUR_PROJECT__apply_migration",
      "mcp__supabase-YOUR_PROJECT__list_tables",
      "mcp__supabase-YOUR_PROJECT__list_extensions",
      "mcp__supabase-YOUR_PROJECT__list_migrations",
      "mcp__supabase-YOUR_PROJECT__list_edge_functions",
      "mcp__supabase-YOUR_PROJECT__get_logs",
      "mcp__supabase-YOUR_PROJECT__get_advisors",
      "mcp__supabase-YOUR_PROJECT__list_storage_buckets",
      "mcp__supabase-YOUR_PROJECT__get_storage_config",
      "mcp__supabase-YOUR_PROJECT__get_project_url",
      "mcp__supabase-YOUR_PROJECT__get_publishable_keys",
      "mcp__supabase-YOUR_PROJECT__search_docs",
      "mcp__supabase-YOUR_PROJECT__generate_typescript_types",
      "mcp__github__*",
      "mcp__Context7__*",
      "mcp__redis-*__*"
    ],
    "deny": []
  }
}
```

**NEVER auto-allow** (keep these gated):
- `git push` (any variant)
- `git reset --hard`, `git clean -f`
- `rm -rf`
- `deploy_edge_function`
- `send_whatsapp_message` or any external messaging
- `create_branch`, `merge_branch`, `delete_branch`
- `DROP TABLE`, `TRUNCATE` (handled by sql-guardian.sh anyway)

### Step 5: Verify Everything Works

Run this verification checklist:

```
1. Hookify rules loaded?
   → Start a new session. Check for "auto-rules" and "confident-mode" context in first response.
   → Run: /hookify list — should show all rules with correct enabled/disabled states.

2. Shell hooks registered?
   → Read .claude/settings.local.json — "hooks" section must exist with both PreToolUse and Stop entries.
   → Test sql-guardian: try running a DELETE without WHERE — should be BLOCKED.
   → Test session-summarizer: end a session — should produce a summary file in .claude/sessions/.

3. Permissions working?
   → Run a Supabase SELECT query — should NOT prompt for permission.
   → Run git push — SHOULD prompt for permission (not auto-allowed).

4. Defense-in-depth verified?
   → Destructive SQL is caught by BOTH hookify warn AND sql-guardian.sh hard-block.
   → Filesystem dangers caught by BOTH hookify warn AND permission denial.
```

---

## Promoting Project-Specific Rules to Template

When you create a hookify rule that would benefit ALL projects:

1. **Generalize**: Replace project-specific tool matchers with wildcards
   - `mcp__supabase-nirvana__execute_sql` → `mcp__supabase-*__execute_sql`
   - `mcp__n8n-mcp-newearthai__*` → `mcp__n8n-mcp-*__*`

2. **Test**: Verify the wildcard matcher works correctly

3. **Push**: Run `/template-push` to push to the template repo

4. **Track**: Add the file to `template-source.md` TEMPLATE-MANAGED Files table

---

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Shell hooks not registered | sql-guardian.sh exists but destructive SQL passes through | Add `hooks` section to `settings.local.json` |
| Hookify plugin not enabled | No `hookify.*.local.md` files are processed | Enable in `~/.claude/settings.json` → `enabledPlugins` |
| Wrong matcher syntax | Rule fires on wrong tools or doesn't fire at all | Check: hookify uses regex-style matching, settings.json uses glob-style |
| Timeout too short | Shell hook killed before completing | Default: 10-15s. Complex hooks may need 30s |
| `.local.md` not gitignored | Hookify rules committed to repo (they should stay local) | Add `*.local.md` to `.gitignore` (hookify files are local config) |
| `settings.local.json` not gitignored | Permissions/hooks config committed | Add to `.gitignore` — this file is machine-specific |
| Confident-mode conflicts with hooks | Auto-allow in permissions but hookify blocks | Hookify blocks happen AFTER permission check — this is correct defense-in-depth |

---

## File Locations Reference

```
.claude/
├── settings.local.json          ← Permissions + shell hook registration (gitignored)
├── hookify.*.local.md           ← Hookify rules (gitignored, managed by plugin)
├── hooks/
│   ├── sql-guardian.sh          ← Hard-block destructive SQL (PreToolUse)
│   └── session-summarizer.sh   ← Session summary + health check (Stop)
├── template-source.md           ← Template sync config
├── planning-protocol.md         ← Planning rules (referenced by hookify)
└── sessions/                    ← Session logs (created by hooks)

~/.claude/
├── settings.json                ← Global settings (enabledPlugins, model)
├── settings.local.json          ← Global permissions (enabledMcpjsonServers)
└── projects/{project-hash}/
    └── memory/MEMORY.md         ← Per-project memory
```
