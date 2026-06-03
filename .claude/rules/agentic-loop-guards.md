# Agentic Loop Guards

## Stop-Reason Inference (Transcript-Based)

Claude Code hookify Stop hooks receive transcript context but NOT the API `stop_reason` field. Use these transcript signals to infer why a session or agent is ending:

| Inferred Reason | Transcript Signal | Required Action |
|-----------------|-------------------|-----------------|
| **Truncation** (max_tokens) | Last message is mid-sentence, incomplete code block, or explicit "reached the limit" | Generate `## CONTINUATION NEEDED` block with exact state |
| **Budget exhausted** | "max budget reached", cost-limit signal | Log incomplete state, generate continuation with remaining work |
| **Tool error** (unresolved) | 2+ consecutive errors on same operation, no successful retry | Document error, attempt alternative approach once, then escalate to user |
| **Premature completion** | Claims "done" but no verification artifact (no git status, no test, no query result) | Run verification before accepting — this is the most common failure mode |
| **Clean exit** | Completion claim WITH verification artifacts | Accept — healthy termination |

## Pre-Exit Verification Checklist

All agents and sessions must mentally execute before returning results:

1. **Objective coverage** — List each stated objective. Was each addressed with evidence?
2. **Verification artifacts** — Every completion claim needs proof: git status, query result, test output, or file diff
3. **Mid-task check** — Am I in the middle of a multi-step plan? If yes, generate continuation, don't claim completion
4. **Silent failure scan** — Did any tool call return empty, null, or unexpected results that I accepted without investigation?
5. **Parallel-session drift check** — Before claiming "all green" on anything touching shared state (production DB, `main` branch, live-deployed surfaces, shared infra), run:
   ```bash
   git fetch origin
   gh pr list --state merged --search "merged:>=<session_start_iso_time>" --limit 20
   ```
   If ANY PRs merged to main during your session window, **re-verify your work against their changes**. Don't declare success if the ground shifted under you — that's exactly how today's "all green" at 16:26 UTC became a full-page crash at 17:00 UTC after PR #167 shipped at 18:16 UTC via a parallel session. The guardrail you installed may protect against the NEXT regression but cannot retro-protect against a regression that shipped seconds after your verification.

   **Supabase extension (added 2026-04-20)**: the GitHub drift check above catches work merged via PR, but does NOT catch raw `execute_sql` mutations applied by sibling sessions without a git commit. Before claiming "all green" on any migration work (`execute_sql` OR `apply_migration` on RLS policies, views, triggers, or multi-tenant tables), ALSO run:
   ```
   mcp__supabase-<project>__list_migrations
   ```
   Diff the result against a session-start snapshot. If any migration `version` is newer than session-start, a sibling session shipped while you were working — re-verify your work against their changes before declaring success. This check is REQUIRED on any migration that touches RLS policies, views, or multi-tenant tables. Note: `list_migrations` only shows work applied via `apply_migration`, not raw `execute_sql` — supplement with `get_logs(service='postgres')` grep for DDL statements if deeper detection needed.

6. **Stated-target artefact verification** — when the work involved writing a file with a stated target (e.g., doctrine ≥600 lines, skill spec ≥200 lines, ADR ≤80 lines, continuation file with required sections, runbook with required sub-sections), run an immediate post-Write check while the authoring context is still fresh:

   ```bash
   wc -l <file>                              # line count vs stated target
   grep -c "^## " <file>                     # section count vs required list
   grep -ic "<mandatory_keyword>" <file>     # required terminology presence
   ```

   Surface gaps immediately, not at downstream verification. Gaps surfaced later (Phase 6 verification, code-council, operator review) cost 3-5× more to close — the writer has to re-acquire the context.

   **Failure precedent (2026-05-11)**: a doctrine doc landed at 544 lines vs ≥600 target. Post-Write `wc -l` caught this immediately. 56-line operational appendix added in 5 minutes while authoring context was still fresh. Without the check, gap would have surfaced at Phase 6 verification — re-acquiring the doctrine's authoring context would have cost 15-20 minutes.

7. **Compaction-aware state check (claim AND disclaim)** — If the session has been compacted (the visible conversation is a summarised slice, not the full history), do NOT assert completion state from in-context memory in EITHER direction. Before claiming "done": verify the artefact exists (`git log --oneline`, file-existence check, line count vs stated target). Before claiming "not done / never shipped / needs redo": run the SAME check first — work completed in a pre-compaction turn is invisible in-context but present in git. Git history survives compaction; conversational memory does not. A wrongly-disclaimed completion (redoing finished work, or writing a false "this never shipped" report) is the symmetric twin of premature completion and is equally a silent failure. Trigger signal: any time you are about to describe what a session did/didn't accomplish and the session shows compaction markers.

   **Failure precedent**: a self-improvement / session-summary run mid-programme was about to author a report stating that an earlier session's artefacts (a doctrine doc, a skill spec, a continuation prompt) were never created — because the compacted conversation slice ended before those artefacts were authored. A single `git log --oneline` + file-existence check showed all of them shipped, with the commits present several sessions deep. The false "never shipped" report was caught only because git was checked before the disclaim was written. Without the check, the report would have recorded work-not-done that was in fact done, and likely triggered a needless redo.

## Agent Termination Protocol

Standard block for agent definitions — append to any agent that runs autonomously or produces results consumed by other agents:

```markdown
## Termination Protocol

Before returning your final result:
1. **Verify completeness**: List each objective from your prompt and confirm it was addressed
2. **Evidence check**: Every claim must have a supporting artifact (query result, file path, test output)
3. **If incomplete**: Output a `## CONTINUATION NEEDED` section with:
   - Completed items (with evidence)
   - Remaining items (specific, actionable)
   - Current state of any in-progress work
4. **Never claim completion without verification**
```

## Broad-Goal Sub-Agent Principle

Give sub-agents BROAD GOALS and let them decompose tasks based on what they find. Micro-step instructions prevent agents from adapting to context.

### When broad goals are correct

- **Council agents** — deliberation, analysis, synthesis
- **Research agents** — exploration, discovery, evidence gathering
- **Audit agents** — investigation, pattern detection
- Any agent where the path to the answer varies by context

### When structured steps are appropriate

- **Orchestrators** coordinating other agents (sequence matters)
- **Safety-critical workflows** — remediation, migrations, deployments
- **Verification protocols** — checklists exist for safety reasons

### Anti-pattern

```
BAD:  "Step 1: Query table X. Step 2: Check column Y. Step 3: Compare with Z."
GOOD: "Verify that dashboard KPIs match database ground truth. Document discrepancies."
```

The agent decides HOW to verify based on available data.

## Integration

This rule works with:
- **completion-verifier** hookify rule (Stop event) — session-level verification
- **operational-guardrails.md** Rule 3 — "verify git status before claiming completion"
- **session-summarizer.sh** (Stop shell hook) — writes session state on exit
