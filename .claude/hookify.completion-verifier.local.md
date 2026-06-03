---
name: completion-verifier
enabled: true
event: Stop
action: addContext
---

# Session Exit Checklist

**Git**: `git status` + `git log --oneline -3` — uncommitted work? Commits match claims? Workflow JSONs/migrations committed?

**Deployments**: Verify each deployment succeeded (n8n active? migration applied? edge function exists?). Never mark complete without verification.

**Continuation**: Significant work → offer continuation prompt. Reflect what SUCCEEDED vs ATTEMPTED. No optimistic summaries.

**Memory**: New gotchas/credentials/infra facts? → Update MEMORY.md. Mutation completed? → fix-audit-trail.md.

**If verification fails**: Tell user explicitly, update ROADMAP to TRUE status, generate accurate continuation.
