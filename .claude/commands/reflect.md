---
description: Trigger self-improvement reflection. Analyzes the current session for patterns that should become skills, memory entries, or hooks.
---

# /reflect — Self-Improvement Reflection

Analyze this session for learnings that should be captured as skills, memory, or hooks.

## Instructions

You are now in **reflection mode**. Your goal is to extract learnings from the current session and propose updates to the skill/memory/hook system.

### Step 1: Scan Session

Review the conversation history and extract:

1. **Corrections** — Where the user said "no, do X instead"
2. **Approvals** — Where the user confirmed your approach worked (validated judgment calls)
3. **Repeated Patterns** — Approaches used 3+ times
4. **New Discoveries** — Things learned that weren't in existing skills or memory

### Step 2: Categorize

Assign confidence levels:

| Level | Criteria |
|-------|----------|
| **HIGH** | Explicit user correction, 5+ occurrences, or incident-driven learning |
| **MEDIUM** | Pattern worked 3+ times, or user confirmed a non-obvious approach |
| **LOW** | First observation, needs validation |

### Step 3: Apply A.U.D.N.

For each learning, determine action:

| Action | When |
|--------|------|
| **ADD** | No similar skill/memory/hook exists |
| **UPDATE** | Similar exists, needs enhancement |
| **DELETE** | New learning contradicts old — remove stale entry |
| **NOOP** | Already fully captured |

### Step 3.5: Hook-Worthiness Gate

For each HIGH-confidence pattern, evaluate whether it should become a **hook** (active enforcement at tool-call time) rather than just documentation.

**Score each pattern against this matrix:**

| Criterion | Question | Weight |
|-----------|----------|--------|
| Irreversible | Does the failure cause data loss, pipeline breakage, or security exposure? | 3 |
| Pre-execution | Must intervention happen BEFORE the tool executes (not just documented after)? | 3 |
| Detectable | Can you identify the danger from the tool name + arguments alone (no domain context needed)? | 2 |
| Time-critical | Does correctness depend on WHEN it runs (business hours, parallel sessions, etc.)? | 1 |
| Not already covered | Is there an existing hook in `.claude/hookify.*.local.md` that already enforces this? | 1 |

**Scoring**: Sum the weights for criteria that score YES.

| Total | Verdict |
|-------|---------|
| **7-10** | **MUST be a hook** — propose hookify alongside memory/skill entry |
| **4-6** | **Consider hook** — propose if not already partially covered by existing hooks |
| **0-3** | **Documentation only** — memory or skill entry is sufficient |

**Before proposing a new hook**: search `.claude/hookify.*.local.md` and `.claude/settings.local.json` shell hooks for existing coverage. If existing hooks partially cover the pattern, propose an UPDATE to the existing hook rather than a new one.

**Hook proposal format** (append to the Step 5 output for patterns that score 7+):

```markdown
### HOOKIFY: [pattern_name]
**Hook Score**: [N]/10
**Matrix**: Irreversible=[Y/N] Pre-exec=[Y/N] Detectable=[Y/N] Time-critical=[Y/N] Not-covered=[Y/N]
**Type**: PreToolUse warn | PreToolUse block | PostToolUse addContext | Stop addContext
**Tool Matcher**: [tool pattern, e.g. mcp__supabase-{{project}}__apply_migration]
**Existing Coverage**: [None | Partial: hookify.X.local.md covers Y but not Z]
**Content Summary**: [1-2 sentence description of what the hook injects/blocks]
```

### Step 4: Check Existing

Before proposing changes, search the following locations to avoid duplication:

```
.claude/skills/**/*.md           # Skill library
.claude/rules/*.md               # CLAUDE.md-linked reference rules
.claude/hookify.*.local.md       # Active hookify rules
.claude/hooks/*.sh               # Shell hooks
memory/MEMORY.md                 # Auto-memory index
memory/*.md                      # Individual memory files
```

### Step 5: Propose Changes

Present proposed changes in this format:

```markdown
## Proposed Updates

### ADD: [pattern_name]
**Confidence**: HIGH/MEDIUM/LOW
**Reason**: [why this should be added]
**Destination**: [memory/ | .claude/skills/ | .claude/rules/ | .claude/hookify.*.local.md]
**Content**:
[the actual content to write]

### UPDATE: [existing_file]
**Reason**: [what's being enhanced]
**Change**: [description of modification]

### DELETE: [stale_memory_file]
**Reason**: [what is now contradicted or obsolete]

---

**Approve these changes?**
- Enter 'y' to apply all
- Enter 'n' to cancel
- Enter 'edit' to modify specific items
```

### Step 6: Apply After Approval

If approved:
1. Write changes to appropriate files
2. Update `memory/MEMORY.md` index if new memory files were added
3. Propose git commit message (only if user asks to commit):
   ```
   chore(reflect): [description of updates]

   - Added: [list]
   - Updated: [list]
   - Deleted: [list of stale files removed]
   ```

## Abstraction Rules

When creating new patterns:

1. **Extract MECHANISM, not INSTANCE**
   - BAD: "KI action 4472 failed because webhook timed out"
   - GOOD: "KI action-execute workflow drops items silently if webhook exceeds 10min timeout"

2. **Use Placeholders**
   - `{{workflow_id}}`, `{{project_slug}}`, `{{action_type}}`, `{{event_id}}`

3. **Generalize**
   - Error types, not specific error messages
   - Patterns, not specific IDs
   - Reference the AFFECTED SYSTEM, not the specific instance

## Destination Guide

| Learning Type | Destination |
|---------------|-------------|
| User preference, feedback, working style | `memory/` as feedback type |
| Infrastructure fact, API quirk, gotcha | `memory/` as user/reference type OR `.claude/rules/` if durable |
| Repeatable procedure with 3+ steps | `.claude/skills/{name}/SKILL.md` |
| Active enforcement pattern (score 7+) | `.claude/hookify.{name}.local.md` + optional shell hook |
| Incident root cause + fix | `.claude/memory/fix-audit-trail.md` entry |
| Project-specific state, ongoing work | `memory/` as project type |

## Example Output

```markdown
## Reflection Summary

### Session Signals
- 2 corrections extracted (user said "don't bulk-apply template updates")
- 1 repeated pattern (checking git log before investigating from scratch)
- 1 new discovery (n8n HTTP Request nodes replace $json downstream)

### Proposed Changes

#### ADD: template-update-review-by-default
**Confidence**: HIGH
**Reason**: User explicitly corrected bulk-apply behavior; incident-driven
**Destination**: memory/feedback_template-updates.md
**Content**:
---
name: Template updates must default to review-by-default
type: feedback
---
When running /update-latest, always default to reviewing files one-by-one.
**Why:** Past incident where bulk-apply clobbered local modifications to
.claude/rules/n8n-patterns.md.
**How to apply:** Never switch to bulk-apply without explicit user (a).

#### UPDATE: .claude/commands/update-latest.md
**Reason**: Codify review-by-default as the command's contract
**Change**: Added "Default behavior: ALWAYS review one-by-one" section

---

**Approve these changes? (y/n/edit)**
```

## When NOT to Reflect

Skip reflection entirely if:
- The session was a single Q&A or file read
- Nothing was shipped and no corrections occurred
- `/reflect` was already run earlier this session
- The user has explicitly ended the session

The `auto-reflect` hookify rule (fires on Stop event) gates reflection behind a 2+ criteria trigger — trust its gating and don't force a reflect on trivial sessions.
