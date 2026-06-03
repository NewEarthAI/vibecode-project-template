# Code Review Domain Routing

When `/code-forge` or `/code-council` runs, the orchestrator detects file types in the diff
and loads domain-specific rules. This ensures reviewers have stack-aware context without
injecting irrelevant domains.

## Routing Table

Match files in the diff against patterns. Load ALL matched domains (a diff can trigger multiple).

**BASELINE row** loads on EVERY review invocation regardless of file pattern. It is not pattern-gated, not skippable, and not subject to compositional reference. Identity preamble fires first; domain-specific rules layer on top.

| Pattern | Domain | Rules to Read | Inject Into |
|---------|--------|--------------|-------------|
| **`*` (BASELINE — always loads, every review)** | **Reviewer Identity** | `.claude/rules/code-review-identity.md` (full — anti-sycophancy preamble, 7 principles, Self-Check Razors) | **all agents (orchestrator + every parallel subagent)** |
| `*.sql`, `migrations/`, `supabase/` | **Supabase/Postgres** | `.claude/rules/operational-guardrails.md` §3-4, `supabase-postgres-best-practices` skill (first 80 lines), `postgresql-code-review` skill (first 60 lines) | security-auditor, performance-reviewer |
| `supabase/functions/`, `edge-function` | **Edge Functions** | `.claude/rules/dashboard-security.md` (if present), `better-auth-security` skill (first 50 lines) | security-auditor |
| `*.json` + contains `"nodes"` | **n8n Workflows** | `.claude/rules/n8n-patterns.md` (full — critical, 150 lines) | all agents |
| `clients/*/workflows/` | **n8n Workflows** | `.claude/rules/n8n-patterns.md` (full) | all agents |
| `*.ts`, `*.tsx`, `*.jsx` | **Frontend/React** | `.claude/rules/dashboard-security.md` (if present), `tailwind-shadcn-system` skill (first 40 lines) | security-auditor, code-reviewer |
| `*.sh`, `scripts/` | **Shell/Bash** | `.claude/rules/operational-guardrails.md` §6-9 | security-auditor |
| `vercel.json`, `vite.config.*`, `src/App.{ts,tsx}`, `src/hooks/use*.ts`, `supabase/migrations/*pg_cron*`, any new `v_*` view migration, any RPC migration with `SETOF` return type | **Loading-State / Perf** | `.claude/rules/loading-state-invariants.md` (full — critical, 100 lines, 6 invariants + diagnostic order) | all agents |
| `CLAUDE.md`, `.claude/rules/` | **Meta/Config** | `.claude/rules/file-editing.md` | spec-validator |
| `.claude/skills/`, `.claude/agents/` | **Skill/Agent Authoring** | Invoke `skill-creator` conventions (description quality, frontmatter) | spec-validator |
| `ROADMAP.md`, `specs/` | **Documentation** | No extra rules — standard review | code-reviewer |

## How the Orchestrator Uses This

### Step 1 — Detect domains
```
FILES=$(git diff --name-only $RANGE)
# Match against patterns above
# Build DOMAINS list (e.g., ["supabase", "frontend"])
```

### Step 2 — Load matched rules
For each matched domain, read the specified rules files. Use the line limits in the table
to avoid loading full 400-line skills. Read ONLY the sections that contain reviewable rules
(usually the first section with the patterns/anti-patterns tables).

### Step 3 — Inject as DOMAIN CONTEXT
Append to each targeted agent's prompt:
```
DOMAIN CONTEXT (auto-detected from diff):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Domain: {{domain_name}}
Source: {{rules_file_path}}

{{rules_content}}
```

### Step 4 — Flag unmatched files
If any file in the diff doesn't match a routing pattern, note it:
"No domain-specific rules matched for: {{file}}. Reviewed with baseline rules only."

## Key Skills Reference (for routing awareness)

These skills contain code-review-relevant domain knowledge:

| Skill | Domain Knowledge | When to Load |
|-------|-----------------|--------------|
| `supabase-postgres-best-practices` | 8 PG rule categories with SQL examples | Any SQL/Supabase code |
| `postgresql-code-review` | RPC, view, migration review patterns | SQL migrations, RPCs |
| `master-security-review` | General security review (RLS, edge fn, MCP) | Any security-sensitive code |
| `master-code-reviewer` | Stack-aware code quality (10-point, P0-P3) | Large reviews, PR-level |
| `tailwind-shadcn-system` | Component patterns, Tailwind v4 conventions | TSX/JSX with Tailwind |
| `better-auth-security` | Auth patterns, session management, JWT | Auth code, middleware |
| `n8nspace` | n8n workspace patterns, workflow naming | n8n workflow management |
| `safe-bash` | Shell safety, injection prevention, audit trails | Bash scripts, CLI tools |
| `receiving-code-review` | Anti-sycophancy reception rules, YAGNI | Applied by USER after review |
