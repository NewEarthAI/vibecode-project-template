---
name: requesting-code-review
description: |
  Process skill for WHEN and HOW to dispatch code reviews. Git SHA scoping, subagent dispatch,
  review cadence per workflow type. This is NOT a review skill — it dispatches master-code-reviewer.
  For conducting the actual review, use master-code-reviewer.
  For handling received feedback, use receiving-code-review.
version: 1.1
source: obra/superpowers (enhanced for the project)
classification: encoded-preference
triggers:
  - "when should I request review?"
  - "how do I dispatch a reviewer?"
  - "request a code review"
do-not-trigger:
  - "review this code" → use master-code-reviewer
  - "handle this feedback" → use receiving-code-review
---

# Requesting Code Review

> Process orchestration — WHEN and HOW to dispatch reviews, not how to conduct them.
> The actual review is performed by `master-code-reviewer` (the master review skill).
> After review is received, use `receiving-code-review` to evaluate and implement feedback.

Dispatch a code-reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code-reviewer subagent with placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each batch (3 tasks)
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Dispatch Template

When dispatching a reviewer subagent, instruct it to use `master-code-reviewer` (the master review skill). The master defines the review format, severity system (P0-P3), scoring algorithm (10-point scale), and output template.

```markdown
# Review Task

Use the master-code-reviewer skill to review:
- **What**: {WHAT_WAS_IMPLEMENTED}
- **Requirements**: {PLAN_OR_REQUIREMENTS}
- **Git range**: {BASE_SHA}..{HEAD_SHA}

If the diff contains SQL/migrations, also invoke postgresql-code-review.
If security is a concern, also invoke master-security-review.
```
