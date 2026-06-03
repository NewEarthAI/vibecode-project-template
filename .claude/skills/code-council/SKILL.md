---
name: code-council
description: |
  Multi-lens code review deliberation engine. Launches 6 agents in parallel (standard)
  or 9 agents (--thorough) to evaluate code changes from specialized perspectives:
  general quality, silent failures, security, spec alignment, test coverage, performance.
  Every CRITICAL/IMPORTANT finding is validated by an independent subagent to kill false
  positives. Consensus across agents amplifies confidence. Produces a unified VERDICT
  (PASS/ADVISORY/BLOCKING) with confidence spread. Optional --pr mode posts validated
  findings as inline GitHub comments. Mirrors /council architecture but specialized for
  code, not strategy.
  Use when: "code-council", "review council", "multi-lens review", or before merging
  significant changes.
allowed-tools: Read, Glob, Grep, Bash, Agent, Write
user-invocable: true
version: 2.0
classification: code-quality
created: 2026-04-14
updated: 2026-04-18
parameters:
  - name: scope
    type: string
    description: Files, diff range, or auto-detect from git diff
  - name: thorough
    type: boolean
    default: false
    description: Run 9 agents instead of 6 (adds type, comment, simplifier analysis)
  - name: spec
    type: string
    description: Optional spec file path for correctness checking
  - name: save
    type: boolean
    default: true
    description: Persist session to council/code-reviews/
  - name: pr
    type: number
    description: GitHub PR number — if provided, post validated CRITICAL/IMPORTANT findings as inline PR comments via gh CLI
---

# /code-council — Multi-Lens Code Review Deliberation

> **Philosophy:** One reviewer finds bugs. Six reviewers find categories of bugs. A council finds the blind spots between categories.

---

## Step 1 — Parse Input

Parse `$ARGUMENTS` to detect mode and scope:
- Contains `--thorough` → 9-agent thorough mode
- Contains `--no-save` → Skip session persistence
- Contains `--spec <path>` → Include spec for correctness checking
- Contains `--pr <number>` → GitHub posting mode: after synthesis, post validated CRITICAL/IMPORTANT findings as inline comments on that PR via `gh` (see Step 5.5)
- Remaining text → scope (files, diff range, or auto-detect)

**Auto-detect scope** (no explicit scope): try `git diff --staged`, then `git diff`, then `git diff HEAD~1 HEAD`.

**Empty diff guard**: If no changes found, stop: "No changes to review. Stage changes or specify a diff range."

**Upfront cost signal** (print before launching agents): "Launching {{N}} agents + up to 15 validators on {{X}} files / {{Y}} lines. Session will save to council/code-reviews/. Press Ctrl-C to abort."

---

## Step 2 — Gather Context

Context is **diff-hunk-first**, not full-file. This cuts tokens and — more importantly — prevents agents from flagging pre-existing code as if it were new.

1. **Diff hunks with context** (primary reviewable artifact):
   - `git diff -U50 $RANGE` — produces hunks with 50 lines of surrounding context
   - For each hunk, record `file:start_line-end_line` of the CHANGED lines (new side) so agents can cite precisely and validators can verify
   - Pass the hunks verbatim to agents — this is what they review

2. **Full file content** (fallback for small files only):
   - If a changed file is ≤200 lines total, include the full file (useful when a small file changes heavily and hunk context isn't enough)
   - Otherwise, rely on hunks + context

3. **File list + change stats**: `git diff --stat $RANGE` — gives agents a lightweight map of the diff's shape

4. **Project rules**: CLAUDE.md "Conventions" + "Critical Rules" sections (~30 lines)

5. **Spec** (if provided or auto-detected): Read the referenced spec file

6. **Identity**: Read `.claude/rules/code-review-identity.md` for the anti-sycophancy preamble

7. **Domain context** (auto-detected): Follow Step 2.5 below

**Why hunks-first matters**: The #1 false-positive source in multi-agent review is agents flagging pre-existing code they mistake for new. Giving them the diff (not the file) makes "what changed" structurally unambiguous. The validator (Step 3.5) then double-checks with a hard touched-by-diff gate.

### Step 2.5 — Domain-Aware Context Injection

Read `.claude/rules/code-review-domain-routing.md` for the routing table.

**Detect domains** from the file list in the diff:
- List all changed files: `git diff --name-only $RANGE`
- Match against the routing table's patterns
- For EACH matched domain, read the specified rules files (respecting line limits in the table)

**Inject per-agent**: Each agent receives ONLY the domain context relevant to their focus:
- security-auditor → Supabase RLS rules, auth patterns, edge function security
- performance-reviewer → Postgres query patterns, n8n execution modes, frontend re-render rules
- spec-validator → skill authoring conventions (if reviewing .claude/ files)
- code-reviewer → frontend patterns, naming conventions
- All agents → n8n patterns (if diff contains workflow JSON)

**Format** — append to each targeted agent's prompt:
```
DOMAIN CONTEXT (auto-detected from diff file types):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{{domain_name}} — from {{source_file}}:

{{relevant_rules_excerpt}}
```

If no domain matches any file, note: "No domain-specific rules matched. Reviewed with baseline project rules only."

**Token budget for domain context**: ≤ 3,000 tokens total across all domains. If multiple domains match, prioritize by: (1) security-relevant, (2) database/query, (3) framework-specific, (4) general.

---

## Step 3 — Launch Agents (Parallel)

**CRITICAL**: Launch ALL agents in a SINGLE message with multiple Agent tool calls.

### Standard Mode — 6 Agents

| # | Agent | subagent_type | Focus | Model |
|---|-------|---------------|-------|-------|
| 1 | Code Reviewer | `pr-review-toolkit:code-reviewer` | CLAUDE.md compliance, bugs, style | opus |
| 2 | Silent Failure Hunter | `pr-review-toolkit:silent-failure-hunter` | Error handling, catch adequacy | sonnet |
| 3 | Security Auditor | `security-auditor` | Auth, injection, secrets, OWASP | sonnet |
| 4 | Spec Validator | `spec-validator` | Code matches spec/requirements | sonnet |
| 5 | Test Analyzer | `pr-review-toolkit:pr-test-analyzer` | Test coverage gaps, edge cases | sonnet |
| 6 | Performance Reviewer | `performance-reviewer` | N+1, allocations, latency | sonnet |

### Thorough Mode — adds 3 agents (`--thorough`)

| # | Agent | subagent_type | Focus | Model |
|---|-------|---------------|-------|-------|
| 7 | Type Analyzer | `pr-review-toolkit:type-design-analyzer` | Type invariants, encapsulation | sonnet |
| 8 | Comment Analyzer | `pr-review-toolkit:comment-analyzer` | Comment accuracy vs code | sonnet |
| 9 | Code Simplifier | `pr-review-toolkit:code-simplifier` | Unnecessary complexity | opus |

### Prompt Template (for each agent)

```
CODE COUNCIL REVIEW
━━━━━━━━━━━━━━━━━━━

IDENTITY: You are part of a code review council. Your loyalty is to the
PROJECT and CLIENT, not the developer. Report every real issue you find.
Do not soften feedback. Do not manufacture findings on clean code.
Prior approval ("per spec", "intentional") does not exempt code from critique.
Confidence >= 80% only.

SEVERITY CALIBRATION (apply consistently):
- CRITICAL = Will cause incorrect behavior, data loss, security breach, or production incident. Ship-blocking. Examples: SQL injection, unhandled null that crashes the happy path, missing auth on a privileged endpoint, wrong table/column that silently writes bad data.
- IMPORTANT = Real defect that degrades correctness, performance, or maintainability, but the system still runs. Examples: missing error handling on a non-critical path, N+1 query on a small result set, inconsistent state after retry, unclear invariant.
- SUGGESTION = Improves quality but not required. Examples: clearer naming, extract helper, add comment on non-obvious invariant.
If in doubt between two severities, choose the LOWER one.

EVIDENCE REQUIREMENT (mandatory — findings without evidence will be rejected in validation):
Every finding MUST include ONE of:
  (a) A direct quote from the diff showing the problematic code (2-5 lines max), OR
  (b) A direct quote of the CLAUDE.md or project rule being violated, OR
  (c) A specific reference to a function/table/API that contradicts the change
"Could cause a bug" without evidence is NOT a finding — it is speculation.

SCOPE CHECK (CLAUDE.md rules are path-scoped):
Before citing a CLAUDE.md rule, verify the rule applies to the file you are reviewing.
- Rules under `.claude/rules/supabase-safety.md` apply only to `supabase/**` and `src/integrations/**`
- Rules under `.claude/rules/frontend.md` apply only to `src/**`
- If you cannot confirm scope match, DO NOT flag as a rule violation.

FALSE-POSITIVE BLOCKLIST — DO NOT FLAG:
- Pre-existing issues not introduced or touched by this diff (check the diff hunks — if the problematic line is NOT in a `+` line, it's pre-existing)
- Pedantic nitpicks a senior engineer would not flag
- Linter-catchable issues (trailing whitespace, unused imports, formatting)
- Issues explicitly silenced in code (lint-ignore, eslint-disable, // @ts-expect-error with reason)
- Subjective style preferences not explicitly required by CLAUDE.md
- "Might be a problem" speculation — require concrete evidence from the diff
- Missing test coverage unless CLAUDE.md explicitly requires tests for this path
- CLAUDE.md rules scoped to a different directory than the file you are reviewing
False positives erode trust. If uncertain, DO NOT flag.

MANDATORY RACE-CONDITION CHECKS (failure-precedent from prior reviews — actively scan for these patterns):

**R1. Write-before-user-decision race (PR #134, 2026-04-19 — council missed it)**:
When the code opens a user-decision UI (modal/dialog/confirm) AND has an effect that WRITES to the same persistent state the dialog is supposed to let the user resolve, check whether the write can fire BEFORE the user's decision is read.
- **Red-flag pattern**: `useEffect` or `subscribe` that persists state (`localStorage.setItem`, Supabase write, debounced save) whose gating condition (`draftChecked`, `ready`, `mounted`) flips to `true` at roughly the same time a dialog becomes visible.
- **Specific test**: trace the sequence "dialog opens" → "user action pending" → "effect fires" → "user clicks Resume/Confirm/Apply". Does the effect run before the user's click? If yes, does the user's click read state the effect just overwrote?
- **Fix pattern**: gate the write-effect on `!dialogVisible` (or equivalent "user hasn't decided yet" flag).
- **Evidence requirement for this finding**: quote the effect's deps AND the dialog state variable AND the user-action handler that reads persistent state.

**R2. Effect dependency object-identity instability (PR #132, 2026-04-19 — council caught it via 3-agent consensus)**:
When a `useEffect` depends on an object (not a primitive) returned from a custom hook, and that hook produces a fresh object literal on every render (no `useMemo` around the return), the effect re-fires on every parent render. This causes: repeated localStorage writes, subscription churn, timer thrash.
- **Red-flag pattern**: `}, [foo, bar, someHook])` where `someHook` returns `{a, b, c}` without `useMemo`.
- **Fix pattern**: destructure stable callbacks (`useCallback`-backed) and primitives from the hook into separate variables; use those in deps.

**R3. Silent state-machine guard fallthrough**:
When a guard fires (`if (!ready) return`) inside a useEffect that gets retriggered when `ready` flips from false→true, check whether OTHER relevant state (e.g., `hasDraft`, `userId`) might have stale values from a prior render that the effect captured. Stale closures in async timers are a common sub-case.
- **Red-flag pattern**: async function inside `setTimeout` or `.then()` referencing state that's a dep of the outer effect — the value at schedule-time is captured, not the latest.
- **Fix pattern**: read fresh state via refs, or restructure so the async work runs inside the effect body (not deferred).

If you see any of R1/R2/R3 in the diff, flag at **IMPORTANT** minimum (CRITICAL if the racing state affects user-visible data correctness like draft restore or form submission).

DIFF HUNKS (+/- lines with 50 lines of surrounding context; `+` is new, `-` is removed):
{{diff_hunks}}

FILE STATS:
{{diff_stat}}

FULL FILES (only for files ≤200 lines):
{{small_file_contents_or_"(none — all changed files are >200 lines; rely on hunks)"}}

PROJECT RULES (from CLAUDE.md):
{{claude_md_excerpt}}

SPEC REFERENCE:
{{spec_excerpt_or_"No spec referenced — infer intent from code and comments"}}

YOUR FOCUS: {{agent-specific focus description}}

OUTPUT FORMAT (every finding must have evidence):
[CRITICAL|IMPORTANT|SUGGESTION] <description> (confidence: XX%) [file:line]
  Evidence: <quoted diff lines OR quoted rule OR specific reference>
  Fix: <concrete suggestion>

End with:
1. OVERALL ASSESSMENT: one sentence
2. BIGGEST RISK in your focus area: one sentence, or "None identified"
3. CONFIDENCE: your overall confidence in this review (0-100%)
```

---

## Step 3.5 — Validation Pass (False-Positive Guard)

**Purpose**: The 6-9 agents produce findings independently. Before synthesis, every CRITICAL and IMPORTANT finding is re-verified by a fresh validator subagent that only sees the finding + the actual code — never the original agent's reasoning. This kills ~30-40% of false positives that slip past self-reported confidence.

**Skip condition**: If ALL agents returned zero CRITICAL and IMPORTANT findings, skip this step and proceed to Step 4 with a clean PASS verdict.

### Launch validators in parallel

For EACH CRITICAL and IMPORTANT finding, launch a validator in a SINGLE message (all in parallel). SUGGESTIONS are NOT validated — they pass through to synthesis as-is.

**Validator routing:**
- Bug / logic / security findings → `general-purpose` with Opus
- CLAUDE.md compliance / spec findings → `general-purpose` with Sonnet
- Performance findings → `performance-reviewer` (already Opus-capable)

### Validator prompt template

```
VALIDATION PASS — confirm or reject a code review finding.

You have NOT seen the original reviewer's reasoning. Read the code yourself.

ORIGINAL FINDING (from {{agent_name}}):
Severity: {{CRITICAL|IMPORTANT}}
Description: {{finding_description}}
Location: {{file}}:{{line}}
Evidence cited by reviewer: {{evidence_quote_or_"NONE — auto-reject"}}
Proposed fix: {{fix}}
Reviewer confidence: {{XX}}%

DIFF HUNK CONTAINING THIS FINDING:
{{specific_hunk_for_this_file_and_line}}

PROJECT CONTEXT:
{{claude_md_excerpt_≤20_lines}}

HARD GATES (any one fails → REJECTED):

GATE 1 — Evidence must exist. If the reviewer cited no concrete evidence (no diff quote, no rule quote, no specific reference), REJECT immediately.

GATE 2 — The problematic line must be IN the diff. Run:
  `git blame -L {{line}},{{line}} -- {{file}}` and check the hash
  OR inspect the hunk above — is {{line}} on a `+` line (newly added or modified)?
If the line was NOT added or modified by this diff (i.e., no `+` marker in the hunk at that line), REJECT as pre-existing.

GATE 3 — CLAUDE.md rule scope. If the finding cites a CLAUDE.md rule, verify the rule's scope matches {{file}}'s path. If scope mismatch, REJECT.

If all three gates pass, determine verdict:
- CONFIRMED: Issue is real AND caused by this diff. Re-score confidence 80-100%.
- REJECTED: Failed a hard gate OR matches the FP blocklist below.
- NUANCED: Partially real, but the fix is wrong OR applies only to an edge case the reviewer did not constrain. Demote one severity.

FALSE-POSITIVE BLOCKLIST (reject if matched):
- Linter-catchable or explicitly lint-silenced
- Pedantic nitpick a senior engineer would not flag
- Style preference not required by CLAUDE.md
- Speculation without evidence ("might be slow", "could cause issues")
- Missing test coverage unless CLAUDE.md explicitly requires tests for this path

RETURN EXACTLY:
VERDICT: [CONFIRMED | REJECTED | NUANCED]
REVISED_CONFIDENCE: XX%
REASON: <one sentence citing code or rule>
GATE_CHECK: <which gate(s) passed/failed, one line>
```

### Apply validator output

| Verdict | Action |
|---------|--------|
| CONFIRMED | Keep finding. Replace agent's confidence with REVISED_CONFIDENCE. |
| REJECTED | Drop finding entirely. Log in session file under "Rejected by validation". |
| NUANCED | Demote one severity: CRITICAL → IMPORTANT → SUGGESTION. Keep REVISED_CONFIDENCE. |

Only the filtered, post-validation list enters Step 3.75 (consensus) and then Step 4 (synthesis).

### Token budget

- Validators run in ONE parallel batch — no serial chain.
- Hard cap: 15 validators per run. If more than 15 CRITICAL+IMPORTANT findings exist, the council is either catastrophically noisy (rerun with higher confidence threshold) or the diff is too large (split the review).
- Each validator reads ≤100 lines of code context. Enforce via the prompt.

---

## Step 3.75 — Consensus Amplification

**Purpose**: When 2+ independent agents flag the same underlying issue, that convergence is far stronger evidence than any single agent's confidence score. Amplify it.

### Group findings by issue, not by text

Two findings are the "same issue" if they target the same `file:line_range` AND describe the same failure mode. Do NOT require identical wording — an SQL injection flagged by security-auditor and the same injection flagged by code-reviewer under "input validation" are ONE consensus finding.

Use this matching heuristic:
- Same file
- Line ranges overlap (±3 lines tolerance)
- Failure mode is semantically equivalent (null handling / auth bypass / injection / race / wrong table / etc.)

### Apply consensus boost

For each consensus group of CONFIRMED findings (post-validation):

| Agents agreeing | Confidence adjustment | Severity adjustment |
|-----------------|----------------------|---------------------|
| 1 agent | No change | No change |
| 2 agents | +5% (capped at 95%) | No change |
| 3+ agents | +10% (capped at 98%) | If 3+ agree AND any original was CRITICAL → promote group to CRITICAL |

In the synthesis output, consensus findings are listed ONCE with a `[CONSENSUS: X agents]` tag and the list of agreeing agents.

### Cross-severity consensus

If 3+ agents flagged the same `file:line_range` but at DIFFERENT severities (e.g., 2× CRITICAL + 1× IMPORTANT), the consensus severity is the MODE (most common) — if tied, use the HIGHER severity. Never dilute severity by averaging.

### Output

Post-consensus findings list feeds Step 4. The session file records both the raw per-agent findings AND the consensus-boosted merged list.

---

## Step 4 — Synthesize

After all agents return, produce the unified synthesis:

```
CODE COUNCIL VERDICT
━━━━━━━━━━━━━━━━━━━
Verdict: PASS | ADVISORY | BLOCKING
Date: {{YYYY-MM-DD}}
Scope: {{X files, Y lines changed}}
Mode: Standard (6 agents) | Thorough (9 agents)

━━━ CRITICAL — Must fix before commit ━━━
- [{{agent}}] {{description}} [{{file}}:{{line}}] (confidence: {{XX}}%)

━━━ IMPORTANT — Should fix ━━━
- [{{agent}}] {{description}} [{{file}}:{{line}}] (confidence: {{XX}}%)

━━━ SUGGESTIONS — Consider ━━━
- [{{agent}}] {{description}}

━━━ CONFIDENCE SPREAD ━━━
| Agent | Overall | Highest Issue | Key Concern |
|-------|---------|---------------|-------------|
| Code Reviewer | XX% | ... | ... |
| Silent Failure | XX% | ... | ... |
| Security | XX% | ... | ... |
| Spec Validator | XX% | ... | ... |
| Test Analyzer | XX% | ... | ... |
| Performance | XX% | ... | ... |

━━━ VALIDATION PASS ━━━
Findings validated: {{N}} | Confirmed: {{X}} | Rejected: {{Y}} | Nuanced (demoted): {{Z}}

━━━ VERDICT LOGIC ━━━
(operates on POST-VALIDATION findings only)
BLOCKING = any CONFIRMED CRITICAL issue with revised confidence >= 90%
ADVISORY = CONFIRMED IMPORTANT issues exist, none reach blocking threshold
PASS = no CONFIRMED findings at revised confidence >= 80%

━━━ CONSENSUS ━━━
- {{points where 3+ agents agree AND validator confirmed}}

━━━ STRENGTHS ━━━
- {{what's well-done, brief}}
```

### Verdict rules (post-validation)
- **BLOCKING**: ≥1 CONFIRMED CRITICAL finding with revised confidence ≥ 90%
- **ADVISORY**: ≥1 CONFIRMED IMPORTANT finding, none reach blocking threshold
- **PASS**: No CONFIRMED findings at revised confidence ≥ 80%
- Raw agent findings that were REJECTED by validation never enter the verdict calculation.

---

## Step 5 — Persist Session

**Default**: Write full session to `council/code-reviews/YYYY-MM-DD-{{slug}}.md`.

**Session file structure:**
```markdown
# Code Council: {{topic}}
**Date**: {{YYYY-MM-DD}}
**Mode**: Standard | Thorough
**Agents**: 6 | 9
**Scope**: {{files reviewed}}
**Verdict**: PASS | ADVISORY | BLOCKING

---

## Code Reviewer
{{full report}}

## Silent Failure Hunter
{{full report}}

## Security Auditor
{{full report}}

## Spec Validator
{{full report}}

## Test Analyzer
{{full report}}

## Performance Reviewer
{{full report}}

## Type Analyzer (Thorough only)
{{full report}}

## Comment Analyzer (Thorough only)
{{full report}}

## Code Simplifier (Thorough only)
{{full report}}

## Validation Pass
**Findings validated**: {{N}} | **Confirmed**: {{X}} | **Rejected**: {{Y}} | **Nuanced**: {{Z}}

### Rejected by validation (would have been false positives)
- [{{agent}}] {{finding}} [{{file}}:{{line}}] — REJECTED: {{validator reason}}

### Nuanced (demoted one severity)
- [{{agent}}] {{finding}} [{{file}}:{{line}}] — {{was}} → {{now}}: {{validator reason}}

## Synthesis
{{verdict output from Step 4}}
```

Skip if `--no-save` was specified.

---

## Step 5.5 — Post to GitHub PR (only if `--pr <number>` was given)

Behaves like `/code-review:code-review` but feeds VALIDATED + CONSENSUS findings (higher signal).

### Preconditions

1. `gh auth status` must succeed. If not, stop and surface the error — do not retry MCP.
2. `gh pr view <number> --json state,isDraft,author,comments` — skip if:
   - PR state is `CLOSED` or `MERGED`
   - `isDraft` is `true` AND user did not pass `--force`
   - A prior code-council comment is already present (check comment bodies for `"## Code Council Review"` marker)

### What to post

Only post CRITICAL and IMPORTANT findings that are CONFIRMED post-validation. SUGGESTIONS and REJECTED findings stay in the session file, not the PR.

For each finding, emit an inline comment via `gh api`:

```bash
gh api \
  repos/{{owner}}/{{repo}}/pulls/{{number}}/comments \
  -X POST \
  -f body="$COMMENT_BODY" \
  -f commit_id="$HEAD_SHA" \
  -f path="{{file}}" \
  -F line={{line}} \
  -f side="RIGHT"
```

### Comment body format

```
**[{{severity}}]** {{description}}

**Evidence**: {{agent's evidence quote}}
**Flagged by**: {{agent_name}}{{ + consensus_agents if any}}
**Validator**: {{CONFIRMED | NUANCED from X→Y}} ({{revised_confidence}}%)

**Fix**:
<FIX_CONTENT_HERE>

---
_Code Council v2.0 • {{N_agents}} agents • {{validation_stats}}_
```

**Suggestion blocks**: If the fix is ≤5 lines and self-contained (no other files affected), wrap the fix in a GitHub suggestion block:

```suggestion
{{corrected code}}
```

For larger fixes, describe the fix and include a copy-paste prompt:
```
Fix {{file}}:{{line}}: {{brief description}}
```

### Summary comment

After all inline comments, post ONE summary comment via `gh pr comment`:

```
## Code Council Review

**Verdict**: {{PASS|ADVISORY|BLOCKING}}
**Agents**: {{N}} ({{mode}})
**Validated findings**: {{confirmed}}/{{total}} posted inline ({{rejected}} false positives filtered)
**Consensus findings**: {{consensus_count}} ({{2+ agent agreement}})

Full session: `council/code-reviews/{{session-file}}.md`
```

### Failure handling

- If a single inline comment fails (e.g., file renamed, line not in diff), SKIP that one comment and continue — do not abort the whole posting
- Track posted vs skipped comments; include skipped ones in the summary
- If `gh api` returns 401/403, stop entirely and tell the user to `gh auth login` — never retry with MCP

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Empty diff | Stop: "No changes to review." |
| Agent fails to return | Synthesize from remaining agents, note reduced confidence |
| Session directory missing | Create `council/code-reviews/` automatically |
| No spec provided | Agents infer intent from code and comments |
| All agents return PASS | Verdict: PASS with high confidence |

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Launching agents sequentially | Later agents see earlier outputs, destroying independence | ALL agents in ONE parallel message |
| Skipping the validation pass (Step 3.5) | Self-reported confidence is optimistic; ~30% false positives slip through | Always validate CRITICAL/IMPORTANT |
| Giving agents full files instead of hunks | Agents flag pre-existing code they mistake for new | Hunks + 50 surrounding lines; full file only if ≤200 lines |
| Skipping consensus (Step 3.75) | Multi-agent agreement is the strongest signal; independence wastes it | Group by file:line range, amplify confidence |
| Running /code-council AND /code-forge on same diff | Redundant — different tools for different scales | Pick one per review |
| Using /code-council for strategy decisions | This is for code, not business decisions | Use /council for strategy |
| Skipping synthesis | Raw reports leave user to reconcile 6-9 views | Always produce VERDICT + CONSENSUS |
| Running --thorough on every diff | 9 agents is expensive; reserve for large changes | Standard (6) is the default |
| Posting to PR without validation | Unvalidated findings erode trust faster than no review | `--pr` only posts CONFIRMED findings |
| Retrying GitHub MCP on auth failure | Will never succeed — auth is stale | Fall through to `gh` CLI immediately |

---

## Relationship to Other Tools

| Tool | Scale | Trigger | Agents | Validation | Posts to PR |
|------|-------|---------|--------|------------|-------------|
| auto-review-on-execute | Small | Automatic (Stop hook) | 2 | No | No |
| `/code-forge` | Focused | Manual | 1 (subprocess) | No | No |
| **`/code-council`** | **Comprehensive** | **Manual** | **6-9** | **Step 3.5 + consensus** | **With `--pr`** |
| `/code-review:code-review` | PR-level | Manual | 4 | Per-finding | Always |
| `/council` | Strategic | Manual | 5-8 | N/A (debate) | No |

**When to pick `/code-council` over `/code-review:code-review`**:
- You want more lenses (security + performance + test coverage + spec + silent failures, not just CLAUDE.md + bugs)
- You're reviewing local changes before a PR exists
- You want consensus amplification across multiple agents
- You want the full session file saved for audit

**When to pick `/code-review:code-review`**:
- PR already exists and you want minimal ceremony
- You trust the 4-agent + validator configuration
- You don't need the session file
