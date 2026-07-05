---
name: pi-migration
description: |
  Migrate a repo from Claude Code to pi with 100% parity, OR resync an existing pi mirror
  after the .claude side has moved on. Use when: "migrate to pi", "set up pi", "switch from
  claude to pi", "pi migration", "convert hooks to pi", "port extensions", "resync pi",
  "bring pi up to par", "update the pi version". Handles MCP consolidation, skill linking,
  hook→extension porting, command→prompt conversion, model config, full verification, AND
  delta resync (new/drifted/removed detection). Works on any Mac/repo.
  Implements 7-phase fresh migration + a Phase R resync path.
allowed-tools: Read, Write, Bash, Grep, Glob
user-invocable: true
version: 1.1
classification: capability-uplift
created: 2026-05-26
updated: 2026-06-24
validated_on:
  - Agency-Main (23 extensions, 37 prompts, 90 skills, 13 MCP servers)
  - NewEarth AI fleet (multi-project, multi-MCP)
parameters:
  - name: project_root
    type: string
    default: current working directory
  - name: claude_source
    type: string
    default: .claude
  - name: pi_target
    type: string
    default: .pi
  - name: mcp_config_global
    type: string
    default: ~/.config/mcp/mcp.json
  - name: mcp_config_pi
    type: string
    default: ~/.pi/agent/mcp.json
---

# Pi Migration — Claude Code → pi with 100% Parity

> **Philosophy**: Migrate incrementally, verify at each phase, never break the Claude Code setup.
> Both tools can coexist — pi reads from `.pi/`, Claude Code reads from `.claude/`.

---

## When This Applies

- Migrating an existing Claude Code project to pi
- Setting up pi on a new Mac with existing Claude Code repos
- Verifying pi migration completeness
- Porting hooks, commands, skills, and agents to pi format

## Prerequisites

| Dependency | Check | Install |
|---|---|---|
| Node.js ≥18 | `node --version` | `nvm install 24` |
| pi | `pi --version` | `npm i -g @earendil-works/pi-coding-agent` |
| pi-mcp-adapter | `pi-mcp-adapter --help` | `npm i -g pi-mcp-adapter` |
| jq | `jq --version` | `brew install jq` |
| git | `git --version` | xcode-select --install |

---

## Phase R: Resync (the recurring job) — run this when `.pi/` already exists

Fresh migration (Phases 0-8) is a **one-time** install. The **recurring** job is resync: the
`.claude/` side has moved on (new skills, new hooks, edited skills) and `.pi/` must catch up.
If `.pi/` already exists, START HERE — do NOT re-run the full migration.

> **Hook-safety note**: in repos with `bash-guardian`, `find -exec`, `rm -rf`, and some compound
> commands are BLOCKED. Every command below is the hook-safe form: `rm -r` (not `-rf`), explicit
> file lists piped to `xargs perl` (not `find -exec`), one destructive op per invocation.

### R.1 Compute the delta (directory-level, not file-count)

```bash
# New skills in .claude not yet in .pi (excludes _archived):
comm -23 <(ls -1 {{claude_source}}/skills | grep -v '^_archived$' | sort) \
         <(ls -1 {{pi_target}}/skills | sort)
# New commands not yet ported:
comm -23 <(ls -1 {{claude_source}}/commands/*.md | xargs -n1 basename | sort) \
         <(ls -1 {{pi_target}}/prompts/*.md | xargs -n1 basename | sort)
# New hooks with no matching extension (compare names by hand — porting is per-hook TS work):
ls -1 {{claude_source}}/hooks/*.sh | xargs -n1 basename | sed 's/\.sh$//' | sort
ls -1 {{pi_target}}/extensions/*.ts | xargs -n1 basename | sed 's/\.ts$//' | sort
```

### R.2 Apply per category

- **New skills** → run the Phase 2.1 loop (it `[ -e ] && continue`-guards existing entries, so it
  only touches the new ones: symlink no-MCP, copy+translate MCP).
- **Drifted copies** → run the Phase 2.3 drift check, then refresh each (R.3).
- **New commands** → run the Phase 5.1 conversion (idempotent; re-copies + re-fixes shell-expansion).
- **New hooks** → port each to a TypeScript extension per Phase 4 (this is genuine authoring, not a
  copy — read the source hook, map the event, preserve fail-closed/never-block semantics).
- **Agents** → run the Phase 3.1 loop (guarded; only new agents get copied).

### R.3 Refresh a drifted copy (hook-safe remove-then-copy)

```bash
rm -r {{pi_target}}/skills/<name>          # NOT `rm -rf` (bash-guardian blocks -f); one per call
cp -r {{claude_source}}/skills/<name> {{pi_target}}/skills/<name>
files=$(grep -rl 'mcp__' {{pi_target}}/skills/<name> 2>/dev/null)
[ -n "$files" ] && printf '%s\n' "$files" | xargs perl -i -pe \
  's/mcp__([A-Za-z0-9_*-]+)/($x=$1)=~s|-|_|g; $x=~s|__|_|g; $x/ge'
```

### R.4 Verify

```bash
# zero broken symlinks
for e in {{pi_target}}/skills/*; do [ -L "$e" ] && [ ! -e "$e" ] && echo "BROKEN: $e"; done
# zero residual untranslated tool-names in copies
grep -rl 'mcp__' {{pi_target}}/skills 2>/dev/null
# new extensions parse (Node 24 type-strip — offline, fast)
for x in {{pi_target}}/extensions/*.ts; do node --experimental-strip-types --check "$x" || echo "ERR $x"; done
```

`.pi/settings.json` registers `.pi/{skills,prompts,extensions}` as DIRECTORIES — pi auto-loads
everything inside, so no manifest/registration step is needed for new items.

---

## Phase 0: Discovery (5 min)

**Goal**: Understand the source setup before touching anything.

### 0.1 Inventory Claude Code Setup

```bash
CLAUDE="{{project_root}}/.claude"
for d in skills commands hooks agents rules; do
  count=$(find "$CLAUDE/$d" -type f 2>/dev/null | wc -l)
  echo "$d: $count files"
done
ls $CLAUDE/hookify.*.local.md 2>/dev/null | wc -l
```

### 0.2 Inventory MCP Servers

```bash
for f in {{project_root}}/.mcp.json ~/.claude.json ~/Library/Application\ Support/Claude/claude_desktop_config.json ~/.config/mcp/mcp.json; do
  [ -f "$f" ] && echo "=== $f ===" && jq '.mcpServers | keys[]' "$f" 2>/dev/null
done
```

### 0.3 Check Existing pi Setup

```bash
for d in extensions prompts skills agents; do
  count=$(find "{{project_root}}/.pi/$d" -type f 2>/dev/null | wc -l)
  echo "$d: $count files"
done
```

---

## Phase 1: MCP Consolidation (15 min)

**Goal**: Single source of truth for all MCP servers.

### 1.1 Create Consolidated Config

```bash
mkdir -p ~/.config/mcp
# Merge all MCP configs: .mcp.json + ~/.claude.json + desktop config → ~/.config/mcp/mcp.json
# Use python3 to read all sources, merge mcpServers keys, write consolidated JSON
```

### 1.2 Create pi MCP Override

```bash
# ~/.pi/agent/mcp.json — full definitions + directTools for key servers
# Read ~/.config/mcp/mcp.json, add directTools array for supabase/github servers
# Set lifecycle: 'lazy' for direct-tools servers
```

### 1.3 Verify MCP Connectivity

```bash
# Test one MCP call per server type
pi --no-skills --no-context-files -p \
  "Call mcp({ action: 'describe', server: 'supabase-yourproject' }). List tool count."
```

---

## Phase 2: Skills (10 min)

**Goal**: All skills discoverable by pi.

### 2.1 Link Skills

Three dispositions per skill dir:
- `_archived` → **skip** (do not mirror archived skills).
- No `mcp__` refs anywhere → **symlink** (auto-tracks future `.claude` edits, incl. `_shared`).
- Has `mcp__` refs → **copy + translate** tool-names (a copy does NOT auto-track — see drift check 2.3).

```bash
mkdir -p {{pi_target}}/skills

# Verified MCP-name translation (hook-safe — NO `find -exec`, NO `rm -rf`).
# mcp__supabase-yourproject__execute_sql  ->  supabase_yourproject_execute_sql
#   strip `mcp__`, hyphens -> `_`, collapse `__` -> `_`
TRANSLATE='s/mcp__([A-Za-z0-9_*-]+)/($x=$1)=~s|-|_|g; $x=~s|__|_|g; $x/ge'

for skill_dir in {{claude_source}}/skills/*/; do
  name=$(basename "$skill_dir")
  case "$name" in _archived) continue ;; esac          # skip archived
  target="{{pi_target}}/skills/$name"
  [ -e "$target" ] && continue
  if grep -rq 'mcp__' "$skill_dir" 2>/dev/null; then     # grep -r: catch refs in ANY file, not just SKILL.md
    cp -r "$skill_dir" "$target"
    # Pass the file LIST to perl (find -exec is blocked by bash-guardian in some repos)
    files=$(grep -rl 'mcp__' "$target" 2>/dev/null)
    [ -n "$files" ] && printf '%s\n' "$files" | xargs perl -i -pe "$TRANSLATE"
  else
    ln -s "../../{{claude_source}}/skills/$name" "$target"   # symlink (incl. _shared)
  fi
done
```

Sanity-test the translator before trusting a batch:
```bash
printf 'mcp__supabase-yourproject__execute_sql\nmcp__n8n-mcp-yourinstance__*\n' \
 | perl -pe 's/mcp__([A-Za-z0-9_*-]+)/($x=$1)=~s|-|_|g; $x=~s|__|_|g; $x/ge'
# expect: supabase_yourproject_execute_sql   and   n8n_mcp_yourinstance_*
```

### 2.2 Verify Skills

```bash
pi --no-skills --no-context-files -p \
  "How many skills can you see? Just the count."
```

### 2.3 Drift check (copies only — symlinks auto-track)

Symlinked skills always reflect `.claude`. **Copied** skills (the `mcp__`-bearing ones) do NOT —
a later edit on the `.claude` side silently leaves the pi copy stale. List the drifted copies:

```bash
for e in {{pi_target}}/skills/*; do
  [ -L "$e" ] && continue                                # skip symlinks (auto-track)
  name=$(basename "$e")
  src="{{claude_source}}/skills/$name/SKILL.md"
  dst="$e/SKILL.md"
  [ -f "$src" ] && [ -f "$dst" ] && [ "$src" -nt "$dst" ] && echo "DRIFTED: $name"
done
```

Refresh each drifted copy by re-copying + re-translating (see Phase R.3 for the hook-safe
remove-then-copy sequence — `rm -r`, never `rm -rf`).

---

## Phase 3: Agents (5 min)

**Goal**: All agent definitions available to pi subagent extension.

### 3.1 Port Agents

```bash
mkdir -p {{pi_target}}/agents
for f in {{claude_source}}/agents/*.md {{claude_source}}/agents/*/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  # Flatten subdirectory agents: subdir/name.md → subdir__name.md
  [ "$(dirname "$f")" != "{{claude_source}}/agents" ] && name="$(basename $(dirname $f))__$name"
  target="{{pi_target}}/agents/$name"
  [ -f "$target" ] && continue
  cp "$f" "$target"
  # Add name: to frontmatter if missing
  head -5 "$target" | grep -q '^name:' || sed -i '' "1s/^/---\nname: ${name%.md}\n/" "$target"
done
```

---

## Phase 4: Extensions (30 min)

**Goal**: Port all hooks to TypeScript extensions.

### 4.1 Extension Architecture

| Location | Scope | Purpose |
|---|---|---|
| `~/.pi/agent/extensions/` | Global | Safety guards (all projects) |
| `.pi/extensions/` | Project | Lifecycle hooks (project-specific) |

### 4.2 Event Mapping

| Claude Code Hook | pi Event | Return |
|---|---|---|
| PreToolUse (block) | `tool_call` | `{ block: true, reason }` |
| PreToolUse (warn) | `tool_call` | `ctx.ui.notify(msg, "warning")` |
| PostToolUse | `tool_result` | `ctx.ui.notify(msg, ...)` |
| SessionStart | `session_start` | context injection |
| Stop | `agent_end` | cleanup, summary |
| PreCompact | `session_before_compact` | handoff |
| UserPromptSubmit | `before_agent_start` | `{ systemPrompt: ... }` |

### 4.3 Extension Template

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
export default function (pi: ExtensionAPI) {
  pi.on("{{event}}", async (event, ctx) => {
    try {
      if (/* condition */) return { block: true, reason: "{{reason}}" };
    } catch (err) { /* never block */ }
  });
}
```

### 4.4 Port Priority

**High** (port first): session-summarizer, vault-capture, ts-typecheck, commit-guardian, worktree-guard, supabase-migration-guard
**Medium**: sql-migration-linter, supabase-migration-release, pre-push-branch-verify, dashboard-review-gate, roadmap-writeback-verifier, auto-sync-artifacts
**Low**: framing-audit-activation, parallel-chat-conflict-canary, newvibe-autofire-stop, newvibe-precompact, code-council-verification
**Skip**: cmux-notify (unless using cmux)

### 4.5 Hookify Loader

Single extension that reads all `.claude/hookify.*.local.md` files:
- Parse YAML frontmatter (name, enabled, event, tool_matcher, action)
- Translate tool matchers: `mcp__server__tool` → `server_tool`
- Route by event type, apply action (block/warn/addContext)

---

## Phase 5: Prompts (10 min)

**Goal**: All commands callable as `/command` in pi.

### 5.1 Convert Commands

```bash
mkdir -p {{pi_target}}/prompts
cp {{claude_source}}/commands/*.md {{pi_target}}/prompts/
# Fix !`command` → Run: command (pi doesn't support shell expansion)
for f in {{pi_target}}/prompts/*.md; do
  sed -i '' 's/^!`\([^`]*\)`/Run: \1/' "$f"
done
```

### 5.2 Verify Prompts

```bash
pi --no-skills --no-context-files -p \
  "List every prompt template you can see. Just the names."
```

---

## Phase 6: Models & Credentials (10 min)

**Goal**: Multi-model support with Keychain-backed credentials.

### 6.1 Store Credentials in Keychain

```bash
# Store API keys in macOS Keychain (one-time per machine)
security add-generic-password -a "$USER" -s "anthropic-pi" \
  -w "sk-ant-..." -U  # Replace with actual key

security add-generic-password -a "$USER" -s "openai-pi" \
  -w "sk-..." -U

security add-generic-password -a "$USER" -s "openrouter-pi" \
  -w "sk-or-..." -U
```

### 6.2 Configure Models

```bash
mkdir -p ~/.pi/agent

cat > ~/.pi/agent/models.json << 'EOF'
{
  "providers": {
    "anthropic": {
      "apiKey": "!security find-generic-password -ws 'anthropic-pi'"
    },
    "openrouter": {
      "baseUrl": "https://openrouter.ai/api/v1",
      "apiKey": "!security find-generic-password -ws 'openrouter-pi'"
    }
  },
  "models": [
    {
      "id": "anthropic/claude-sonnet-4-5",
      "provider": "anthropic",
      "name": "Claude Sonnet 4.5",
      "contextWindow": 200000,
      "maxTokens": 8192
    },
    {
      "id": "openai/gpt-4o",
      "provider": "openrouter",
      "name": "GPT-4o",
      "contextWindow": 128000,
      "maxTokens": 4096
    },
    {
      "id": "google/gemini-2.5-pro",
      "provider": "openrouter",
      "name": "Gemini 2.5 Pro",
      "contextWindow": 1000000,
      "maxTokens": 8192
    }
  ]
}
EOF
```

### 6.3 Configure Settings

```bash
cat > ~/.pi/agent/settings.json << 'EOF'
{
  "defaultModel": "anthropic/claude-sonnet-4-5",
  "thinking": "high"
}
EOF
```

---

## Phase 7: Verification (15 min)

**Goal**: Prove 100% parity.

### 7.1 Smoke Tests

```bash
# Test 1: Skills load
pi --no-skills --no-context-files -p "How many skills can you see?"

# Test 2: MCP connectivity
pi --no-skills --no-context-files -p \
  "Use supabase_yourproject_execute_sql to run: SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"

# Test 3: Prompt templates
pi --no-skills --no-context-files -p "List every prompt template."

# Test 4: Multi-model
pi --model openrouter/openai/gpt-4o --no-skills --no-context-files -p \
  "What model are you? One sentence."

# Test 5: Extensions load
pi --no-skills --no-context-files -p \
  "List every active extension and what it does."
```

### 7.2 Hook Integration Test

```bash
# Make a real edit + commit, verify hooks fire
echo "// test marker" >> .pi/extensions/session-summarizer.ts
pi --no-skills --no-context-files -p \
  "Add a comment at line 1 of .pi/extensions/session-summarizer.ts. Then commit."

# Verify session summary created
ls -lt ~/.pi/agent/sessions/SESSION-*.md | head -3
```

### 7.3 Autovibe Smoke Test

```bash
# Run autovibe on a trivial intent
pi -p 'Run the autovibe skill with intent: "add a one-line comment to README.md"'
```

### 7.4 Validation Checklist

```
□ pi installed and authenticated
□ pi-mcp-adapter installed
□ MCP servers consolidated (~/.config/mcp/mcp.json)
□ pi MCP override with directTools (~/.pi/agent/mcp.json)
□ All skills linked/copied to .pi/skills/
□ All agents ported to .pi/agents/ with frontmatter fixes
□ All hooks ported to .pi/extensions/ (TypeScript)
□ All commands converted to .pi/prompts/
□ Models configured with Keychain creds
□ Settings configured (defaultModel, thinking)
□ CLAUDE.md auto-loads
□ Prose/caveman rules active
□ Tool guards active (SELECT *, list_tables, n8n)
□ Session lifecycle hooks fire (summarizer, vault-capture)
□ MCP connectivity verified (live SQL query)
□ Multi-model verified (GPT-4o, Gemini)
□ Autovibe end-to-end works
```

---

## Phase 8: Token Efficiency & Memory Layer (10 min)

**Goal**: Not just parity — BETTER than Claude Code. Obsidian-backed memory, token guards, context adherence.

### 8.1 Obsidian Vault Config

If the project uses Obsidian for notes/memory:

```bash
cat > {{project_root}}/.claude/obsidian-second-brain.local.md << 'EOF'
---
vault_path: "/path/to/obsidian/vault"
---
session summaries auto-capture to vault daily notes.
EOF
```

`vault-capture` extension: reads config on `agent_end`, atomically appends to `vault/Daily Notes/YYYY-MM-DD.md`, tags `#session #auto-capture #project/<name>`, mkdir-based file locking for parallel safety.

### 8.2 Token Efficiency Extensions (port FIRST)

| Extension | Event | Savings |
|---|---|---|
| `prose-mode.ts` | `before_agent_start` | Caveman + layman rules — terse, no pleasantries |
| `tool-guards.ts` | `tool_call` | SELECT * block (~60-80%), list_tables block (~480KB), n8n get_node_info block (~100KB) |
| `session-summarizer.ts` | `agent_end` | Compact session summary — prevents context bloat |
| `vault-capture.ts` | `agent_end` | Offloads memory to Obsidian — reduces in-context recall |
| `hookify-loader.ts` | `tool_call` + `before_agent_start` | Pre-loads 28+ rules — no re-read needed |

### 8.3 Context Adherence Extensions

| Extension | Event | Purpose |
|---|---|---|
| `load-claude-md.ts` | `before_agent_start` | Injects CLAUDE.md every session |
| `framing-audit-activation.ts` | `session_start` | Framing-audit mandate — RIGHT question check |
| `parallel-chat-conflict-canary.ts` | `session_start` | Warns on parallel file conflicts |
| `newvibe-precompact.ts` | `session_before_compact` | Context-budget handoff before compaction |

### 8.4 Memory & Continuity

| Extension | Event | Purpose |
|---|---|---|
| `session-summarizer.ts` | `agent_end` | SESSION-{date}-{hash}.md (git state, commits, ROADMAP) |
| `session-state.env` | summarizer output | Cross-session flags (CLIENTUPDATE_PENDING) |
| `auto-sync-artifacts.ts` | `agent_end` | Auto-commits metadata to git |
| `vault-capture.ts` | `agent_end` | Obsidian vault daily notes |
| `newvibe-autofire-stop.ts` | `agent_end` | Autovibe continuation dispatch |

### 8.5 Speed Optimizations

- **hookify-loader**: Pre-loads all rules at session start — no file re-reads
- **Fast-path guards**: worktree-guard raw JSON substring check (~2ms bail)
- **Tool matcher translation**: done once at load, not per-call
- **Lazy MCP servers**: `lifecycle: 'lazy'` — connect on first call only
- **Session-before-compact handoff**: preserves context before compaction

### 8.6 Verification

```bash
# Token efficiency: terse output, no pleasantries
pi -p "Explain what a JOIN is."
# Tool guards: SELECT * blocked or reformulated
pi -p "Run SELECT * FROM agent_sessions LIMIT 1"
# Memory: session summary with git hash, commits, ROADMAP
cat ~/.pi/agent/sessions/SESSION-*.md | head -20
# Vault: session block with #auto-capture tag
cat "/path/to/vault/Daily Notes/$(date +%Y-%m-%d).md" | tail -20
```

---

## Anti-Patterns

| Wrong | Why | Right |
|---|---|---|
| Overwriting `.claude/` during migration | Breaks Claude Code — both tools must coexist | Write to `.pi/`, symlink where possible |
| Hardcoding MCP server names in extensions | Breaks on different project | Use `tool.includes("supabase")` pattern matching |
| Skipping MCP tool-name translation | `mcp__server__tool` won't match pi naming | Always translate: `mcp__server__tool` → `server_tool` |
| Porting hooks as bash scripts in pi | pi extensions are TypeScript, not bash | Write TypeScript extensions using pi's event API |
| Not testing non-Anthropic models | "any model" goal unverified | Test GPT-4o and Gemini at least |
| Skipping session-summarizer port | Loses session continuity | Port first — it's the foundation for all lifecycle hooks |

---

## Rollback

Both tools coexist. To revert:
1. Delete `.pi/` directory
2. Delete `~/.pi/agent/extensions/*.ts` (custom extensions only)
3. Claude Code continues working from `.claude/` unchanged

---

## References

- pi docs: `~/.nvm/versions/node/v24.12.0/lib/node_modules/@earendil-works/pi-coding-agent/docs/`
- pi extensions: `docs/extensions.md`
- pi prompt templates: `docs/prompt-templates.md`
- pi MCP adapter: `npm:pi-mcp-adapter`
- Migration state: `.pi/PI-MIGRATION-STATE.md`
- Day-by-day progress: `.pi/PI-DAY{1,2,3,5}-STATE.md`
