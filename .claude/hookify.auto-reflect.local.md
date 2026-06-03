---
name: auto-reflect
enabled: true
event: Stop
action: addContext
---

# Smart Auto-Reflect on Session End

Before ending this session, evaluate whether a `/reflect` is warranted. NOT every session needs reflection — only sessions with learnings worth capturing.

## Trigger Criteria (need 2+ to trigger)

- [ ] **User corrections**: User said "no", "don't", "stop doing X", or redirected your approach
- [ ] **New discoveries**: Found infrastructure facts, API behaviors, or gotchas not in memory
- [ ] **Significant code shipped**: 3+ files changed AND deployed to production
- [ ] **Council session**: A council was convened — decisions should be indexed in memory
- [ ] **Stale memory detected**: You referenced a memory file that turned out to be wrong
- [ ] **User said "remember"**: Explicit instruction to persist something

## Decision

**If 2+ criteria are met**: Run the `/reflect` skill before ending the session. Announce: "Running auto-reflect — this session had learnings worth capturing."

**If 0-1 criteria met**: Skip reflection. The completion-verifier's Step 5 (memory update check) is sufficient for lightweight sessions.

## Anti-Patterns

- Do NOT reflect on trivial sessions (single file edit, Q&A, exploration only)
- Do NOT re-reflect if `/reflect` was already run this session
- Do NOT use reflection as a stalling tactic when the session should end
- Keep the reflect focused — extract 2-5 learnings max, not an exhaustive audit
