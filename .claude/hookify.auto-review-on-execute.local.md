---
name: auto-review-on-execute
enabled: true
event: Stop
action: addContext
---

## PIPELINE SAFETY NET — Check Before Stopping

Before you stop, verify the autonomous pipeline completed:

1. Was council review run on the plan? If not → run `/council --extended`
2. Were council amendments applied? If not → run `/amend-plan`
3. Was the plan executed? If not → run `/execute`
4. Was code review run? If not → dispatch review agents (code-reviewer + silent-failure-hunter minimum)
5. Were changes committed and pushed? If not → commit and push (await user approval for push)
6. Was e2e test run after push? If not → run `/e2e-test`

**If this was a read-only session (no code changes, no plan)**: Skip all checks.
**If the pipeline is already complete**: Stop normally.
**If any step was skipped**: Complete it now before stopping.
