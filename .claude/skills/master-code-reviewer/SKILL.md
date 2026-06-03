---
name: master-code-reviewer
description: |
  Comprehensive code review for all languages and frameworks with quantitative scoring,
  LLM code smell detection, and stack awareness (Supabase, n8n, Next.js, Edge Functions).
  For deep PostgreSQL/Supabase schema analysis, also invoke postgresql-code-review.
  For review dispatch process, see requesting-code-review.
  For handling received feedback, see receiving-code-review.
version: 1.0
classification: capability-uplift
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
triggers:
  - "code review"
  - "review this PR"
  - "review my changes"
  - "review this code"
  - "check this diff"
do-not-trigger:
  - "review this SQL migration" → use postgresql-code-review
  - "when should I request a review?" → use requesting-code-review
  - "how do I handle this feedback?" → use receiving-code-review
  - "security review" → use master-security-review
---

# Master Code Reviewer

> Quantitative, stack-aware code review with LLM smell detection and impact analysis.

---

## Companion Skills — Invoke When Conditions Met

Before generating review output, evaluate these conditions:

- **SQL/migrations/RPCs/RLS in diff** → invoke `postgresql-code-review` for deep Supabase/PG analysis. Do not attempt PostgreSQL-specific review without it.
- **Review complete, feedback received** → invoke `receiving-code-review` for feedback evaluation protocol (anti-sycophancy, YAGNI checks).
- **Dispatching review to subagents** → invoke `requesting-code-review` for dispatch scoping (Git SHA ranges, cadence guidance).
- **Security concerns dominate the diff** → invoke `master-security-review` for confidence-calibrated security audit with data flow tracing.

These are NOT mutually exclusive — invoke all that match the current task.

---

## Severity System

| Level | Label | Deduction | Action |
|-------|-------|-----------|--------|
| **P0** | Critical | -3 | Must block merge |
| **P1** | High | -2 | Should fix before merge |
| **P2** | Medium | -1 | Fix in PR or create follow-up |
| **P3** | Low | -0.5 | Optional improvement |
| — | Praise | +0 | Acknowledge good patterns |

**Priority ordering**: Security > Performance > Correctness > Maintainability

---

## Scoring Algorithm

Start at **10**. Deduct per finding. Score determines verdict:

| Verdict | Condition |
|---------|-----------|
| **Reject** | Any P0, OR 3+ P1s, OR score < 5 |
| **Conditional Approve** | No P0, 1-2 P1, score >= 5 |
| **Approve** | No P0/P1, score >= 8 |

---

## Review Phases

### Phase 0: Intent Gate

1. Summarize the PR/change intent in **ONE sentence**
2. If you cannot summarize → ask for clarification before proceeding
3. Read: PR description, linked issues, existing review comments
4. Self-check: Am I about to bike-shed? Is the scope clear?

### Phase 1: Scope Assessment

```bash
git diff --stat  # Understand change shape
```

- **>400 lines**: Suggest splitting the PR
- **>500 lines**: Summarize by file first, review in batches
- **Detect domain** from file paths:

| Path Pattern | Domain Module |
|---|---|
| `workflows/`, `*.workflow.json` | n8n review (see references/n8n-review.md) |
| `*.sql`, `migrations/`, `supabase/` | PostgreSQL → **invoke postgresql-code-review** |
| `src/`, `app/`, `components/`, `*.tsx` | Frontend (React/Next.js) |
| `supabase/functions/` | Edge Functions (Deno) |

### Phase 2: Architecture & SOLID Analysis

Detect violations — propose minimal, safe splits:

- **SRP**: Overloaded modules with unrelated responsibilities
- **OCP**: Frequent edits to add behavior instead of extension points
- **LSP**: Subclasses that break expectations or require type checks
- **ISP**: Wide interfaces with unused methods
- **DIP**: High-level logic tied to low-level implementations

**Removal candidates**: Identify dead code. Distinguish:
- **Safe delete now** — no callers, no consumers
- **Defer with plan** — has callers but scheduled for deprecation

### Phase 3: Security Scan

**Standard**: XSS, injection, SSRF, path traversal, secrets leakage, IDOR
**Supabase**: RLS bypass, `service_role` key in frontend, missing `auth.uid()` checks
**n8n**: Credentials in Code nodes, HTTP Request nodes exposing tokens, webhook auth
**Edge Functions**: Missing auth header validation, CORS misconfiguration
**Next.js**: Server Actions accepting raw input without Zod, secrets in `NEXT_PUBLIC_*`

### Phase 4: Code Quality + LLM Smell Detection

**Standard checks**:
- N+1 queries, error handling, boundary conditions, race conditions
- Empty catch blocks, swallowed exceptions, resource leaks

**LLM Code Smells** (AI-generated code artifacts):
- Placeholder implementations (`TODO`, `NotImplemented`, `return []`)
- Overly generic abstractions (`GenericHandler`, `BaseManager` without reuse)
- Hallucinated imports (modules that don't exist in the project)
- Over-engineering from iterative AI generation
- Duplicate logic with minor variations (copy-paste from AI suggestions)

**The Question Approach** — frame issues as questions when the intent is unclear:
- "What happens if `items` is an empty array?"
- "How should this behave when the API call times out?"

### Phase 5: Impact Analysis

For every changed export, interface, or shared utility:

1. **Search for callers** using Grep — changed exports → find consumers
2. **Check API contract** — modified signatures → verify all callers updated
3. **n8n-specific** (CRITICAL): Changed node names → search for `$('NodeName')` references. Node rename = silent breakage.
4. **Supabase-specific**: Changed RPC signatures → search frontend callers. Changed table columns → check views and policies.
5. **Shared utilities**: Find all dependents before approving changes

### Phase 6: Generate Output

```markdown
## Code Review: [PR title or description]

### Intent
[One-sentence summary of what this change does and why]

### Score: X/10

### Critical Issues (P0)
| # | File | Line | Issue | Impact | Fix |
|---|------|------|-------|--------|-----|

### High Priority (P1)
| # | File | Line | Issue | Impact | Fix |
|---|------|------|-------|--------|-----|

### Medium Priority (P2)
| # | File | Line | Issue | Recommendation |
|---|------|------|-------|----------------|

### Low Priority (P3)
| # | File | Line | Suggestion | Category |
|---|------|------|------------|----------|

### Quick Wins
[High impact, low effort changes — <5 lines each]

### Strengths
[Specific good patterns worth keeping — acknowledge good work]

### Questions for Author
[Clarifications needed before full assessment]

### Verdict
- **Result**: [Approve / Conditional Approve / Reject]
- **Score**: X/10 (P0: N, P1: N, P2: N, P3: N)
- **Reason**: [One sentence]
```

Cap output at **10 issues** with summary if more found. Offer to show the rest.

### Phase 7: Next Steps

Present options — do NOT implement changes until user confirms:

1. **Fix all** — Implement all suggested fixes
2. **Fix P0-P1 only** — Address critical and high priority
3. **Fix specific items** — User selects which issues to fix
4. **No changes** — Review complete, no implementation

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Reviewing without understanding intent | Produces irrelevant findings | Phase 0 intent gate first |
| Flagging issues outside the diff | Noise — review the change, not the codebase | Scope to changed lines, use full file for context |
| `$("Node").first()` for current item in n8n | Always returns item 1, not paired item | Use `.item` for paired items |
| Implementing fixes without confirmation | May change code the author intentionally wrote | Phase 7: always ask first |
| Generic "be constructive" tone advice | AI doesn't need emotional coaching | Specific techniques: Question Approach, praise labels |
| Version numbers in n8n node names | Rename = silent `$('OldName')` breakage | Version in code comments inside node |
| Reviewing SQL without postgresql-code-review | Misses JSONB indexing, RLS, CITEXT patterns | Invoke companion skill for SQL/migration diffs |

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| No diff available | Ask user for `git diff`, PR URL, or file paths |
| Diff >500 lines | Batch by file, summarize first |
| Mixed concerns (frontend + SQL + n8n) | Apply all relevant domain modules, invoke companions |
| Companion skill unavailable | Proceed with master skill, note reduced PostgreSQL/security depth |
| No issues found | Explicitly state "No issues found" with score 10/10, list Strengths |
