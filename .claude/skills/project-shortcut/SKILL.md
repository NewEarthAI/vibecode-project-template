---
name: project-shortcut
description: |
  Programmatically add shell aliases for fast project launching. Creates callable shortcuts (like `bb`, `nf`, `cpt`)
  that cd into a project directory, pull the latest code from GitHub with `git pull --ff-only`, start a tmux session
  via `tx-claude`, and launch Claude Code automatically. Supports both bash and zsh. Use when: "add project shortcut",
  "create quick launch", "setup project alias", "add alias to shell", or when setting up a new development workflow
  that needs fast project switching. Validates directory existence, alias naming conventions, and handles shell
  config detection automatically.
version: 1.0
classification: encoded-preference
created: 2026-03-14
updated: 2026-03-14
parameters:
  - name: alias
    type: string
    description: Short alias name (e.g., bb, nf, myapp) - must start with letter/underscore
    required: true
  - name: directory
    type: string
    description: Full path to project directory (expands ~)
    required: true
  - name: description
    type: string
    description: Human-readable project name (optional, defaults to alias)
    required: false
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
user-invocable: true
---

# Project Shortcut Skill

**Pattern:** Programmatically add executable shell aliases for fast project launching with integrated git pull + tmux + Claude.

**Classification:** Encoded Preference (Model can add aliases, but requires specific sequence and shell config handling)

---

## Problem Solved

Without this skill: Manually editing `~/.zshrc` or `~/.bashrc`, remembering exact alias syntax, managing duplicates, reloading shell config.

With this skill: One command adds an alias, detects shell type, validates inputs, handles conflicts, and documents the change.

---

## Usage

```bash
/project-shortcut <alias> <directory> [description]
```

### Examples

```bash
# Basic: add alias 'client' for a client project
/project-shortcut client ~/projects/client-project

# With description
/project-shortcut myapp ~/Documents/projects/my-app "My Application"

# Expand home directory
/project-shortcut work ~/Documents/work-project "Work"
```

After adding, use anywhere in shell:
```bash
client  # cd ~/projects/client-project && git pull && tx-claude .
myapp   # cd ~/Documents/projects/my-app && git pull && tx-claude .
```

---

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `alias` | string | Yes | Shorthand name (alphanumeric, underscore). Examples: `bb`, `nf`, `client_work` |
| `directory` | string | Yes | Full project path. Expands `~` to home. Must exist. |
| `description` | string | No | Human-readable label for shell comments. Defaults to `alias` if omitted. |

---

## What It Does

1. **Validates inputs**
   - Alias format (must start with letter/underscore, alphanumeric only)
   - Directory exists and is readable

2. **Detects shell**
   - Checks for `~/.zshrc` (zsh, preferred on macOS)
   - Falls back to `~/.bashrc` (bash, Linux/older systems)

3. **Handles conflicts**
   - If alias exists, prompts to replace or skip
   - Removes old alias before adding new one

4. **Adds alias to shell config**
   - Appends comment with description
   - Full command: `cd <dir> && git pull --ff-only 2>/dev/null; tx-claude .`

5. **Instructs reload**
   - Shows exact source command or "close/reopen terminal"

---

## How to Reload

After skill executes:

```bash
# Option 1: Source the config file
source ~/.zshrc
# or
source ~/.bashrc

# Option 2: Close and reopen terminal
# New shell session loads config automatically
```

---

## Current Shortcuts (BuyBox AI)

| Alias | Project | Path |
|-------|---------|------|
| `bb` | BuyBox AI | `~/Documents/GitHub/BuyBox-AI` |
| `nf` | Nirvana Freight | `~/Documents/GitHub/nirvana-freight-fleet-insights-automation` |
| `ne` | NewEarth AI Agency | `~/Documents/GitHub/NewEarth AI Agency - Main` |
| `cpt` | Claude Code Project Template | `~/Documents/GitHub/claude-code-project-template` |

---

## Implementation Details

### Shell Alias Format

```bash
alias myalias='cd "/full/path/to/project" && git pull --ff-only 2>/dev/null; tx-claude .'
```

- **`cd`** — Changes to project directory
- **`git pull --ff-only`** — Pulls latest from remote (fast-forward only, safe)
- **`2>/dev/null`** — Suppresses git error messages (e.g., if not a git repo)
- **`tx-claude .`** — Launches or attaches tmux session and starts Claude

### Abstraction Checks (Held-Out Tasks)

✓ Works for any project path (different repos, different directories)
✓ Works with different alias names (single-letter, multi-word, underscores)
✓ Works across bash and zsh (shell-agnostic)
✓ Handles paths with spaces (quoted properly)

---

## Anti-Patterns to Avoid

❌ **Hardcoding project names**
→ Use `{{directory}}` placeholder, not `/Users/justin/...`

❌ **No validation**
→ Always check: alias format, directory exists, shell config exists

❌ **Silent failures**
→ Always report: what was added, where, and how to reload

---

## Testing

Run evals:
```bash
python .claude/skills/skill-creator/scripts/run_eval.py \
  --skill-path .claude/skills/project-shortcut \
  --eval-path .claude/skills/project-shortcut/evals/evals.json \
  --output-dir .claude/skills/project-shortcut/eval_results/
```

---

## Related

- [tx-claude](https://github.com/NewEarthAI/BuyBox-AI) — Tmux session helper that launches Claude
- `.zshrc` / `.bashrc` — Shell configuration files
- Shell aliases — Bash/zsh built-in mechanism
