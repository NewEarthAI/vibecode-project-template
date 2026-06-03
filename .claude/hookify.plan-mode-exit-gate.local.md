---
name: plan-mode-exit-gate
enabled: true
event: PreToolUse
tool_matcher: ExitPlanMode
action: addContext
---

# Plan Exit Gate — STOP and verify before ExitPlanMode

**Context**: Read ROADMAP + CLAUDE.md + relevant specs/continuations?

**Impact**: DB (tables/RPCs/views) · Workflows · Edge functions · Frontend · Agents/skills · Cross-workstream dependencies?

**Interop**: Naming conventions · Integrates with existing views/SOT · No duplicates · Follows existing patterns?

**Alignment**: User value chain traced · Simplest solution · Architecture quality maintained?

**Document has**: Context · Files table · DB changes · Impact summary · Risks · Failure conditions ("FAILS IF") · Verification steps · ROADMAP update?

**Post-impl planned**: ROADMAP update · Continuation/spec update · Project docs?

If ANY item missing → do NOT exit plan mode. Complete first.
