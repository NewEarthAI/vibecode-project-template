---
description: Set up pi for this repo — wire MCP, verify extensions, configure skills
argument-hint: "[quick|full]"
---

# Pi Setup

Configures pi to work with this repo with 100% parity from Claude Code.

## What This Does

The template ships `.pi/` with 25 extensions pre-installed. This command:
1. Verifies pi is installed and working
2. Wires MCP servers (copy from Claude Code or configure manually)
3. Verifies all 25 extensions load correctly
4. Tests Supabase connectivity (if applicable)
5. Configures project-specific paths in extensions
6. Links skills from `.claude/skills/` to `.pi/skills/`

## Arguments

- `$ARGUMENTS` — Optional: "quick" for MCP+verify only, "full" for everything (default: full)

---

## Step 0: Environment Detection

Determine what we're working with:

```bash
pi --version 2>/dev/null || echo "PI_NOT_INSTALLED"
node --version
```

IF pi is NOT installed:
  - INFORM: "pi is not installed. Install with: npm install -g @earendil-works/pi-coding-agent"
  - ASK: "Install now? (Y/n)"
  - IF yes: `npm install -g @earendil-works/pi-coding-agent`
  - IF no: ABORT with "pi required for this command"

CONTINUE once pi is available.

---

## Step 1: Verify Template Scaffolding

Check that `.pi/` was cloned from the template:

```bash
ls .pi/extensions/*.ts | wc -l    # Should be 25
ls .pi/settings.json               # Should exist
cat .pi/mcp.json                   # Should be valid JSON
```

IF `.pi/` is missing:
  - INFORM: "Template scaffolding missing. Clone the template first, or run the full migration."
  - ABORT

IF extensions count < 20:
  - INFORM: "Only {N} extensions found — expected 25. Template may be outdated."
  - ASK: "Run `/update-latest` to pull latest template? (Y/n)"

---

## Step 2: Wire MCP Servers

pi needs MCP server config in `.pi/mcp.json` (project-local) or `~/.pi/mcp.json` (global).

### 2.1 Check for existing Claude Code MCP config

```bash
# Claude Code stores MCP config in settings.local.json
cat .claude/settings.local.json 2>/dev/null | jq '.mcpServers // empty'
```

IF Claude Code has MCP servers configured:
  - SHOW the server list
  - ASK: "Copy these MCP servers to pi's `.pi/mcp.json`? (Y/n)"
  - IF yes:
    - Read `.claude/settings.local.json` → extract `mcpServers`
    - Transform to pi format:
      ```json
      {
        "mcpServers": {
          "server-name": {
            "command": "...",
            "args": ["..."],
            "env": { "KEY": "value" }
          }
        }
      }
      ```
    - Write to `.pi/mcp.json`
    - INFORM: "MCP servers copied. Start a pi session to connect."

IF no Claude Code MCP config:
  - INFORM: "No MCP servers found. Configure manually in `.pi/mcp.json`."
  - SHOW template:
    ```json
    {
      "mcpServers": {
        "supabase-projectname": {
          "command": "npx",
          "args": ["-y", "@supabase/mcp-server-supabase@latest", "--project-ref", "YOUR_REF"],
          "env": { "SUPABASE_ACCESS_TOKEN": "YOUR_TOKEN" }
        }
      }
    }
    ```

### 2.2 Verify Supabase MCP (if applicable)

```bash
# Check for Supabase config
grep -r "supabase" .pi/mcp.json 2>/dev/null
```

IF Supabase is configured:
  - TEST: Run a simple query via MCP
  - IF fails: Check access token, project ref, network

---

## Step 3: Verify Extensions

Test that all critical extensions load without errors:

```bash
pi -e .pi/extensions/tool-guards.ts -e .pi/extensions/hookify-loader.ts -e .pi/extensions/prose-mode.ts -p "What extensions did you load?" 2>&1
```

### 3.1 Check hookify rules load

```bash
ls .claude/hookify.*.local.md | wc -l
```

Expected: 33+ rules (all loaded automatically by hookify-loader.ts)

### 3.2 Verify condition-aware SELECT * block

Test that `SELECT id FROM table` passes but `SELECT * FROM table` is blocked:

```bash
# This should work (via MCP):
pi -p "Run this SQL via supabase MCP: SELECT id FROM information_schema.tables LIMIT 1"

# This should be blocked by hookify-loader:
# (Will show "[supabase-select-star] BLOCKED" message)
```

---

## Step 4: Link Skills

pi reads skills from `.pi/skills/` and `.agents/skills/` (per `.pi/settings.json`).

### 4.1 Check if skills are already linked

```bash
ls .pi/skills/ | wc -l
```

IF skills exist:
  - INFORM: "Skills already present ({N} skills). Skipping link step."
  - CONTINUE

IF `.pi/skills/` is empty:
  - Copy skills from `.claude/skills/`:
    ```bash
    cp -r .claude/skills/* .pi/skills/ 2>/dev/null
    ```
  - INFORM: "Copied {N} skills from .claude/skills/"

### 4.2 Verify key skills load

```bash
ls .pi/skills/*/SKILL.md | head -10
```

Critical skills to verify:
- `council/SKILL.md`
- `autovibe/SKILL.md`
- `ship/SKILL.md`
- `daily-plan-generator/SKILL.md`
- `code-council/SKILL.md`
- `agent-research/SKILL.md`

---

## Step 5: Configure Project-Specific Paths

Some extensions use project-specific paths that need updating per-repo.

### 5.1 sessionstart-context-aggregator.ts

This extension loads MEMORY.md and ROADMAP.md at session start. Paths are auto-detected:
- `agency/memory/MEMORY.md` → if exists, loads
- `ROADMAP.md` → if exists, loads
- No config needed — it discovers these at runtime

### 5.2 roadmap-writeback-verifier.ts

Override roadmap paths via env var:
```bash
export PI_ROADMAP_PATHS="ROADMAP.md,agency/business-foundations/ROADMAP.md"
```

Or set in `.env` file. Default: auto-discovers `ROADMAP.md` + subdirectories.

### 5.3 vault-capture.ts

If project has an Obsidian vault:
```bash
ls agency/vault/ 2>/dev/null || echo "No vault configured"
```

IF vault exists: extension auto-detects and captures on session end.
IF no vault: extension silently skips.

---

## Step 6: Smoke Tests

Run these to verify everything works:

### 6.1 Extensions load
```bash
pi -p "List all extensions you can see" --no-input
```
Expected: 25 extensions loaded

### 6.2 Supabase connectivity (via MCP)
```bash
pi -p "Use supabase_newearthai_execute_sql to run: SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" --no-input
```
Expected: returns a count

### 6.3 Skills visible
```bash
pi -p "How many skills can you see?" --no-input
```
Expected: lists available skills

### 6.4 Hookify rules active
```bash
pi -p "What hookify rules are loaded?" --no-input
```
Expected: lists rules from .claude/hookify.*.local.md

### 6.5 Prose mode active
```bash
pi -p "Hello! How are you today?" --no-input
```
Expected: response follows caveman rules (no pleasantries, compressed)

---

## Step 7: Post-Setup

After successful verification:

1. INFORM user: "pi is configured for this repo with {N} extensions and {M} skills."
2. SHOW summary:
   ```
   ✅ Extensions: 25 loaded (tool-guards, hookify-loader, prose-mode, session-summarizer, etc.)
   ✅ Skills: {N} linked
   ✅ Hookify rules: {M} active (toggle with enabled: true/false in .claude/hookify.*.local.md)
   ✅ MCP: {servers} configured
   ✅ Session summaries: ~/.pi/agent/sessions/
   ```

3. RECOMMEND:
   - Start a pi session: `pi`
   - Run `/prime` to load project context
   - Run `/daily-plan` to verify the full planning flow

---

## Notes

- Both Claude Code and pi coexist — `.claude/` is untouched by pi setup
- Token efficiency is BETTER in pi: prose-mode, tool guards, hookify-loader with conditions
- Extensions load at session start — restart pi after changing `.pi/extensions/`
- Hookify rules hot-reload — edit `.claude/hookify.*.local.md` and they take effect next tool call
- Toggle any hook: set `enabled: true` or `enabled: false` in the hookify file
- Session summaries written to `~/.pi/agent/sessions/SESSION-{date}-{hash}.md`

---

## Extension Inventory

| Extension | Purpose | Ported From |
|-----------|---------|-------------|
| tool-guards.ts | Supabase SELECT * block, n8n mode inject, bash safety, subagent cost gate | bash-guardian.sh + sql-guardian.sh |
| hookify-loader.ts | Loads all 33+ hookify rules, condition-aware | hookify-context-injector.sh |
| prose-mode.ts | Caveman + layman prose rules | hookify.caveman-auto.local.md |
| session-summarizer.ts | Writes session summary on agent_end | session-summarizer.sh |
| sessionstart-context-aggregator.ts | Loads MEMORY.md, ROADMAP, git state at start | sessionstart-context-aggregator.sh |
| commit-guardian.ts | Blocks commits with debug artifacts, .env, large files | commit-guardian.sh |
| worktree-guard.ts | Git worktree safety, dirty-tree protection | worktree-guard.sh |
| ts-typecheck.ts | Runs tsc --noEmit after TS edits | ts-typecheck.sh |
| pocock-implicit-activation.ts | Detects work signals, suggests skills | pocock-implicit-activation.sh |
| cmux-notify.ts | tmux notifications on session end/errors | cmux-notify.sh |
| vault-capture.ts | Captures session notes to Obsidian vault | vault-capture.sh |
| load-claude-md.ts | Loads CLAUDE.md into system prompt | N/A (pi-specific bridge) |
| pi-relay.ts | Cross-session messaging | N/A (pi-specific) |
| auto-sync-artifacts.ts | Syncs session artifacts | auto-sync-artifacts.sh |
| code-council-verification.ts | Code council result verification | code-council-verification.sh |
| dashboard-review-gate.ts | Dashboard review enforcement | dashboard-review-gate.sh |
| framing-audit-activation.ts | Framing audit trigger | framing-audit-activation.sh |
| newvibe-autofire-stop.ts | NewVibe autofire stop guard | newvibe-autofire-stop.sh |
| newvibe-precompact.ts | NewVibe pre-compact handoff | newvibe-precompact-handoff.sh |
| parallel-chat-conflict-canary.ts | Detects parallel session conflicts | parallel-chat-conflict-canary.sh |
| pre-push-branch-verify.ts | Pre-push branch verification | pre-push-branch-verify.sh |
| roadmap-writeback-verifier.ts | Warns if roadmap not updated | roadmap-writeback-verifier.sh |
| sql-migration-linter.ts | SQL migration quality checks | sql-migration-linter.sh |
| supabase-migration-guard.ts | Supabase migration safety | supabase-migration-guard.sh |
| supabase-migration-release.ts | Supabase migration release flow | supabase-migration-release.sh |