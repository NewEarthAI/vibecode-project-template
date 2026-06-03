# Continuation Collision Safety — Pause Gates for Parallel Sessions

**Scoped to**: any continuation file authored when parallel Claude sessions (autovibe in another chat, `/build-with-agent-team` runs, concurrent human work) may modify the same files this continuation targets.

**Purpose**: Prevent guaranteed merge conflicts + rolled-back deploys when multiple sessions attempt overlapping work on the same files.

---

## The Rule

Before finalizing any continuation file that targets files potentially modified by parallel work, the continuation MUST include a **PAUSE banner with resume-gate verification queries** at the very top of the file — above any STOP headers, above any bootstrap checklists.

## Detection protocol

Before writing/finalizing a continuation:

1. **Scan MEMORY.md "In-Flight Work" section** for active parallel continuations
2. **Grep `continuations/*MASTER-CONTINUATION*.md`** for overlapping file paths to your target files
3. **Check for `/autovibe Resume` commands** in recent chat context — user-signaled parallel runs
4. **If ANY overlap detected** → pause banner REQUIRED

---

## Pause banner structure

```markdown
> ## ⛔ PAUSED — WAIT FOR {{PARALLEL_WORK_NAME}} TO MERGE TO MAIN
>
> **Status ({{timestamp UTC}})**: {{who is running what — e.g., "user running /autovibe Resume {{program_name}} from {{continuation-path}} in parallel chat"}}
>
> **Collision risk** — this continuation's work overlaps these files/lines with {{parallel_work}}:
> - `{{file}}` — lines {{range}} (our target) vs lines {{range}} (their target)
> - {{enumerate all overlapping files}}
>
> Running in parallel = guaranteed merge hell. Do not proceed.
>
> ### Resume gate — ALL 3 must pass before executing bootstrap checklist
>
> ```bash
> # Check 1: Parallel work merged to main
> git fetch origin main
> git log origin/main --oneline | grep -iE "{{specific signal pattern, e.g. '{{program}}.*(Phase 5|Phase 7|Phase 12)'}}"
> # Expect: ≥N matching commits
>
> # Check 2: Parallel feature branches cleaned up (signals completion)
> git ls-remote origin | grep -iE "{{branch pattern}}"
> # Expect: nothing (or only archived refs)
>
> # Check 3: PRs merged on GitHub
> gh pr list --state merged --search "{{search pattern}}" --limit 10
> # Expect: parallel work's phases visible as merged
> ```
>
> ### When gate passes
>
> Post-parallel-work codebase will DIFFER from what this continuation describes:
> - {{specific file}} may have been refactored — re-read before editing
> - Scope may need adjustment if parallel work absorbed some responsibilities
> - {{other re-scope notes}}
>
> ### Files SAFE to reference without re-reading post-parallel-work
>
> These are NOT modified by the parallel work — reference them directly:
> - {{list research files, audit files, council sessions unaffected}}
>
> ### If you load this continuation BEFORE the gate passes
>
> Do nothing with this work. Pick a different task (check MEMORY.md NEXT SPRINT bundle or other ROADMAP NOW items). Come back when all 3 gate queries pass.
>
> ---
```

---

## Why three queries, not one

Single-query gates fail silently (commit not yet merged, branch still exists on remote, PR still open). Three independent signals (commit log, remote branches, merged PRs) give strong triangulation with near-zero false-positives.

Ordering matters: start with cheapest (`git log` local) → medium (`git ls-remote`) → heaviest (`gh pr list`). Short-circuit on first failure.

---

## Additional protections

### Memory index update

When pausing a continuation, update `MEMORY.md` "In-Flight Work" section to reflect PAUSED state. Fresh chat loading memory sees the pause FIRST, before loading the continuation itself.

### Project memory file update

The associated `.claude/projects/{{project}}/memory/project_{{slug}}_in_flight.md` file must reflect the pause with resume-gate pointer. Description field in frontmatter should lead with "PAUSED".

### Commit with docs-only scope

The pause commit should be DOCS-ONLY (continuation file + memory files). No code changes. Commit message explicitly: "PAUSE continuation — collision gate for {{parallel_work}}".

---

## When to REMOVE the pause gate

When all 3 resume-gate queries pass:
1. Re-read target files (post-parallel-work state may differ)
2. Re-scope the continuation if parallel work absorbed responsibilities
3. Remove the PAUSED banner (NOT the underlying STOP header if one exists)
4. Commit removal as its own docs-only commit: "RESUME continuation — {{parallel_work}} merged to main"

---

## Anti-patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Proceeding to implement when user says "I'm running autovibe in another chat" | Guaranteed merge conflict on overlapping files | Stop, write pause gate, commit docs-only |
| Single-query resume gate (e.g., just PR list) | Fails silently if phase merged but branch still exists | Three independent signals |
| Pause banner buried below STOP header or bootstrap checklist | Fresh chat might run bootstrap before seeing pause | Pause banner AT THE TOP, above everything |
| Skipping MEMORY.md update | Memory loads first; pause should be visible from index | Update In-Flight line to PAUSED with resume-gate pointer |
| Leaving pause banner after parallel work merges | Stale warning confuses future sessions | Remove pause + re-scope after gate passes |

---

## Illustrative failure scenario

A session is mid-authoring a continuation targeting `src/hooks/useSharedHook.ts` (hypothetical). The user announces they're about to run `/autovibe Resume {{major-refactor}}` in a parallel chat. The parallel autovibe will refactor 28 consumer files including `useSharedHook.ts`.

Without a pause gate: both sessions edit the hook. Merge conflict guaranteed. Depending on which commits first, either the autovibe's work is blocked at rebase, or the session's work is blocked, or (worst case) one session's changes silently overwrite the other's after a clumsy conflict resolution.

With a pause gate: the session stops implementation. Writes a PAUSED banner with the 3-query resume gate at top of its continuation. Commits docs-only ("PAUSE continuation — collision gate for {{major-refactor}}"). The parallel autovibe runs uncontested. When the autovibe's phases merge to main, the 3-query gate passes and the original session can resume — with the knowledge that the codebase has shifted and target files must be re-read before editing.

Net outcome: zero collision, zero merge hell, zero rolled-back deploys. Cost: ~5 minutes of pause-gate authoring. Benefit: avoids ~1-2 hours of conflict resolution and potential data loss from a clumsy merge.
