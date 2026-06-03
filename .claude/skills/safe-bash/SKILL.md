---
name: safe-bash
description: |
  Privileged workflow enforcement for shell operations. Use when running n8n API calls,
  git commit workflows, or any task requiring audit trails and injection prevention.
  Provides task scripts with argv execution, metacharacter rejection, and audit logging.
version: 1.2
parameters:
  - name: n8n_base_url
    default: "{{N8N_BASE_URL}}"
  - name: n8n_api_key
    default: "{{N8N_API_KEY}}"
  - name: repo_root
    default: "{{REPO_ROOT}}"
  - name: max_retries
    default: 3
  - name: backoff_base_ms
    default: 1000
validated_on:
  - n8n workflow export/import on different instance
  - git commit operations on different repository
  - supabase query on different project
---

# safe-bash — Privileged Workflow Enforcement

## Policy Hierarchy

This project uses a three-layer security model. Each layer has a distinct job:

| Layer | Mechanism | Scope | What It Does |
|-------|-----------|-------|--------------|
| **1. MCP Server Gate** | `settings.local.json` | All MCP tools | Blocks non-project servers outright |
| **2. Safe-bash Tasks** | Task scripts in `scripts/` | Privileged workflows | Enforces argv execution, metachar rejection, audit logging |
| **3. Regex Safety Net** | `hookify.safe-bash-enforcer` | All Bash commands | Catches catastrophic patterns (`rm -rf /`, fork bombs, etc.) |

**Layer 1** is the primary gate — it prevents tool calls to wrong servers before they happen.
**Layer 2** (this skill) enforces discipline on operations that touch external APIs or make commits.
**Layer 3** is a blast-radius limiter — a narrow regex that catches commands that should never run anywhere.

## When This Applies

- n8n workflow export, import, or verification (always use task scripts)
- Git commits that need hash-gated determinism
- Any operation requiring an audit trail

## When This Does NOT Apply

Routine development commands run normally — no safe-bash overhead:

```bash
# These are fine as-is, no task script needed:
git status / git diff / git log / git branch
npm run dev / npm run build / npm run lint
ls / wc / head / tail / mkdir / cp / mv
npx tsc / npx supabase
```

The hook (Layer 3) only intervenes on catastrophic patterns like `rm -rf /` or `eval`.

## Privileged Task Scripts

| Task | Script | Purpose | Risk |
|------|--------|---------|------|
| `n8n_export_workflow` | `scripts/n8n_export_workflow.sh` | Export workflow JSON + normalize + sha256 | READ |
| `n8n_import_workflow` | `scripts/n8n_import_workflow.sh` | Import workflow JSON via REST PUT | WRITE |
| `n8n_verify_workflow_updated` | `scripts/n8n_verify_workflow.sh` | Verify hash matches with bounded retries | READ |
| `git_commit_if_changed` | `scripts/git_commit_if_changed.sh` | Commit only if normalized hash differs | WRITE |
| `git_status` | inline: `git status --porcelain` | Check working tree | SAFE |
| `git_diff` | inline: `git diff --stat` | Show changes | SAFE |
| `npm_run` | inline: `npm run {{script}}` | Run allowlisted npm script | SAFE |
| `selfcheck` | `scripts/selfcheck-safe-bash.sh` | Validate safe-bash installation | SAFE |

## Command Allowlist

| Category | Allowed Commands |
|----------|-----------------|
| **git** | `git status`, `git diff`, `git add`, `git commit`, `git log`, `git branch`, `git fetch`, `git pull`, `git push`, `git stash` |
| **npm** | `npm run dev`, `npm run build`, `npm run lint`, `npm run preview`, `npm install` |
| **node** | `npx tsc`, `npx supabase` (with SUPABASE_ACCESS_TOKEN) |
| **system** | `ls`, `wc`, `head`, `tail`, `mkdir`, `cp`, `mv` (non-destructive targets only) |
| **n8n** | Via task scripts only (never raw curl to n8n API) |

## Dangerous Command Denylist

| Category | Blocked Pattern | Why |
|----------|----------------|-----|
| **Destructive** | `rm -rf /`, `rm -rf ~`, `rm -rf .` | Data loss |
| **Disk** | `dd`, `mkfs`, `fdisk` | Hardware damage |
| **Fork bomb** | `:(){ :\|:& };:` | System crash |
| **Permissions** | `chmod 777`, `chmod -R 777` | Security hole |
| **Shell bypass** | `eval`, `exec`, `source` (with untrusted input) | Injection |
| **Network** | `nc -l`, `ncat`, `socat` (listeners) | Exfiltration |
| **Credential** | `curl` with inline secrets (use env vars) | Secret leak |

## Metacharacter Rejection

These characters are **rejected in arguments** unless the task explicitly validates them:

| Char | Name | Why Dangerous |
|------|------|---------------|
| `` ` `` | Backtick | Command substitution |
| `$(` | Dollar-paren | Command substitution |
| `${` | Dollar-brace | Variable expansion |
| `\|` | Pipe | Output redirection |
| `>` / `>>` | Redirect | File overwrite/append |
| `<` / `<<` | Input redirect | Heredoc injection |
| `;` | Semicolon | Command chaining |
| `&&` / `\|\|` | Logic operators | Conditional execution |
| `\n` | Newline | Command injection |

**Exception**: Tasks that need specific metacharacters (e.g., `git commit -m` needs spaces and quotes) validate those tokens explicitly.

## Audit Log Format

Every task execution produces a JSON audit entry:

```json
{
  "timestamp": "{{ISO8601}}",
  "task": "{{task_name}}",
  "args": ["{{validated_arg1}}", "{{validated_arg2}}"],
  "cwd": "{{working_directory}}",
  "env_keys": ["N8N_API_KEY", "SUPABASE_ACCESS_TOKEN"],
  "exit_code": 0,
  "stdout_lines": 42,
  "stderr_lines": 0,
  "modified_files": [{"path": "{{file}}", "sha256": "{{hash}}"}],
  "duration_ms": 1234
}
```

Audit entries go to `{{repo_root}}/.claude/safe-bash-audit.jsonl`.
Secrets in env values are redacted — only key names logged.

## Deterministic Artifacts

### JSON Normalization (for workflow export)
```bash
# Canonical normalization: sorted keys, 2-space indent, no trailing whitespace
jq -S '.' input.json > normalized.json
sha256sum normalized.json | cut -d' ' -f1
```

### Hash-Based Git Commit
```bash
# Only commit if content hash actually changed
NEW_HASH=$(jq -S '.' file.json | sha256sum | cut -d' ' -f1)
OLD_HASH=$(git show HEAD:file.json 2>/dev/null | jq -S '.' | sha256sum | cut -d' ' -f1)
if [ "$NEW_HASH" != "$OLD_HASH" ]; then
  git add file.json && git commit -m "{{message}}"
fi
```

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `bash -c "curl ... $VARIABLE"` | Shell injection via variable expansion | Use argv: `curl "$URL"` with validated URL |
| Inline API keys in commands | Secret leak in audit/history | Set env var, reference by name |
| `rm -rf` for cleanup | Accidental data loss | Use `git clean -n` (dry run) first |
| Raw `curl` to n8n API | No normalization, no audit | Use `n8n_export_workflow` task |
| `git commit -a` | Commits unintended files | `git add {{specific_files}}` then commit |
| `eval "$untrusted_var"` | Arbitrary code execution | Validate against allowlist |
| Unbounded retry loops | Infinite hang | Bounded retries with exponential backoff |

## Defaults

| Parameter | Default | Adjust When |
|-----------|---------|-------------|
| `max_retries` | 3 | Flaky network — increase to 5 |
| `backoff_base_ms` | 1000 | Rate limiting — increase to 2000 |
| `n8n_base_url` | `$N8N_BASE_URL` | Different n8n instance |
| `repo_root` | Git root auto-detected | Monorepo subfolder |

## Validation

This skill works for:
- Different n8n instances (any base URL + API key)
- Different Supabase projects (any project ref)
- Different git repositories (any repo root)
- New projects without prior configuration (fails deterministically with "env not set")
