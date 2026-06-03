---
name: code-forge
description: |
  Fresh-context non-sycophantic code reviewer via claude -p subprocess.
  Packages diff + project context into a briefing, spawns a genuinely fresh
  Claude session with anti-sycophancy identity, captures critique. Solves
  context-continuity sycophancy where in-session reviewers rationalize code
  they helped build. Use when: "code-forge", "fresh review", "non-sycophantic
  review", "forge review", or before committing significant changes.
allowed-tools: Read, Glob, Grep, Bash, Write
user-invocable: true
version: 1.0
classification: code-quality
created: 2026-04-13
parameters:
  - name: scope
    type: string
    description: Files, diff range, or "staged" — defaults to auto-detect from git diff
  - name: spec
    type: string
    description: Optional path to spec file for correctness checking
---

# /code-forge — Fresh-Context Code Review

> **Philosophy:** A reviewer that spent 40 messages helping build code is pre-primed to rationalize it. A fresh-context reviewer with no conversation history and a non-sycophantic identity cannot fall into that trap.

---

## Step 1 — Determine Scope

Parse `$ARGUMENTS` to determine what to review:

- **Explicit files**: `/code-forge src/auth.ts src/middleware.ts` → review those files
- **Diff range**: `/code-forge HEAD~3..HEAD` → review that range
- **"staged"**: `/code-forge staged` → review `git diff --staged`
- **No argument**: Auto-detect — try `git diff --staged` first, fall back to `git diff`, fall back to `git diff HEAD~1 HEAD`

```bash
# Determine diff
if [[ "$SCOPE" == "staged" ]]; then
  DIFF=$(git diff --staged)
elif [[ "$SCOPE" =~ \.\. ]]; then
  DIFF=$(git diff "$SCOPE")
elif [[ -n "$SCOPE" ]]; then
  DIFF=$(git diff -- $SCOPE)
else
  DIFF=$(git diff --staged)
  [[ -z "$DIFF" ]] && DIFF=$(git diff)
  [[ -z "$DIFF" ]] && DIFF=$(git diff HEAD~1 HEAD)
fi
```

**Empty diff guard**: If DIFF is empty after all attempts, stop and tell the user: "No changes detected. Stage changes or specify a commit range." Do NOT proceed with an empty briefing.

---

## Step 2 — Assemble Briefing

Build a single markdown document. Read these files to construct it:

1. **Identity preamble**: Read `.claude/rules/code-review-identity.md` — include verbatim as the opening section
2. **Project rules**: Read `CLAUDE.md` — extract ONLY the "Conventions" and "Critical Rules" sections (~30 lines). Do NOT include the full file.
3. **Domain-specific rules** (auto-detected): Read `.claude/rules/code-review-domain-routing.md`. Match the changed files against the routing table. For each matched domain, read the specified rules/skill files (respecting line limits) and include as a "Domain Rules" section. This gives the subprocess reviewer stack-aware knowledge (Supabase RLS patterns, n8n anti-patterns, frontend security rules, etc.) without bloating the briefing with irrelevant domains. Token budget for domain context: ≤ 2,000 tokens.
4. **Diff**: The git diff from Step 1
5. **Affected files**: For each changed file, read the full file content. Truncate each file at 500 lines. If a file exceeds 500 lines, include only the changed hunks with ±30 lines context.
6. **Spec reference** (if provided): Read the spec file, include relevant sections
7. **Task instruction**: Append at the end:
   ```
   ---
   Review this code. Report all issues with confidence >= 80%.
   Output format:
   [CRITICAL|IMPORTANT|SUGGESTION] Description (confidence: XX%) [file:line]
     Fix: concrete suggestion
   OVERALL: one-sentence assessment
   BIGGEST RISK: one-sentence or "None identified"
   ```

### Token budget & truncation

Target: **≤ 15,000 tokens** (~60KB text). If the assembled briefing exceeds this:

1. Trim CLAUDE.md to "Critical Rules" only (~15 lines)
2. Truncate file content to changed hunks ± 20 lines context (not full files)
3. If still over: split review into multiple `claude -p` invocations, one per file

**CRITICAL — Truncation warning**: If ANY content was truncated, prepend this to the briefing:
```
⚠ TRUNCATION NOTICE: This review covers a partial diff. X files / Y lines
were excluded due to context limits. Critical issues in unreviewed sections
are possible. Run /code-forge on specific files for full coverage.
```

Never produce a truncated review without this warning. A confident-looking review of an incomplete diff is worse than no review.

---

## Step 3 — Write Briefing to Temp File

**CRITICAL — Shell safety**: NEVER interpolate the briefing as a shell string. Always write to a file first.

```bash
# Write briefing to temp file — safe from shell injection
FORGE_FILE=".claude/forges/$(date +%Y-%m-%d)-${SLUG}.md"
```

Use the Write tool to create the briefing file. This file becomes the audit trail.

Ensure `.claude/forges/` is in `.gitignore` (briefings may contain sensitive diff content).

---

## Step 4 — Execute Subprocess

Spawn the fresh-context review via `claude -p`:

```bash
REVIEW=$(claude -p "$(cat "$FORGE_FILE")" --output-format text 2>&1)
EXIT_CODE=$?
```

**Timeout**: Use a 300-second (5-minute) timeout on the Bash tool call. If the subprocess times out, report: "Review timed out. Try a smaller diff or run on specific files."

**Error handling**:
- `EXIT_CODE != 0` → Show raw error output. Common causes: auth expired (`claude auth login`), rate limit, malformed input.
- Empty `$REVIEW` → Report: "Subprocess returned empty output. Check `claude` CLI auth status."
- Non-empty `$REVIEW` → Proceed to Step 5.

---

## Step 5 — Present Results

Display the subprocess critique to the user with clear framing:

```
CODE FORGE — Fresh-Context Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scope: {files reviewed}
Mechanism: claude -p subprocess (fresh context, no session history)

{subprocess output}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Forge briefing saved: {FORGE_FILE}
```

Optionally save the critique alongside the briefing:
```bash
# Save critique for audit trail
CRITIQUE_FILE=".claude/forges/$(date +%Y-%m-%d)-${SLUG}.critique.md"
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Empty diff | Stop: "No changes detected. Stage changes or specify a commit range." |
| `claude` CLI not found | Stop: "Requires claude CLI. Install: npm install -g @anthropic-ai/claude-code" |
| Auth failure | Show error, suggest: `claude auth login` |
| Timeout (>300s) | Report timeout, suggest smaller scope |
| Truncation occurred | Prepend truncation warning to briefing (mandatory) |
| `.claude/forges/` missing | Create it automatically |

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `claude -p "$BRIEFING"` with BRIEFING as shell var built from git diff | Shell expansion of backticks/`$()` in diff content | Write to file first, read with `$(cat "$FILE")` |
| Truncating without warning | User acts on incomplete review with false confidence | Always prepend truncation notice |
| Including full 300-line CLAUDE.md | Wastes token budget, dilutes signal | Extract "Conventions" + "Critical Rules" only |
| Running on empty diff | May hallucinate findings on phantom code | Check diff is non-empty before proceeding |
| Committing forge files | May contain sensitive diff content (API keys, PII) | `.gitignore` the `.claude/forges/` directory |

---

## Relationship to Other Tools

| Tool | Purpose | When to use |
|------|---------|-------------|
| `/code-forge` | Fresh-context single reviewer, fast, focused | Before committing, for targeted review |
| `/code-council` | Multi-lens 6-9 agent deliberation with verdict | For comprehensive review of large changes |
| auto-review-on-execute hookify | Automatic 2-agent dispatch on Stop events | Runs automatically, no invocation needed |
| `/council` | Strategic multi-perspective deliberation | Architecture/venture decisions, not code review |
