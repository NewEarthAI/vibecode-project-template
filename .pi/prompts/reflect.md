---
description: Trigger self-improvement reflection. Analyzes the current session for patterns that should become skills or expertise updates.
---

# /reflect — Self-Improvement Reflection

Analyze this session for learnings that should be captured as skills or expertise.

## Instructions

You are now in **reflection mode**. Your goal is to extract learnings from the current session and propose updates to the skill/expertise system.

### Step 1: Scan Session

Review the conversation history and extract:

1. **Corrections** — Where the user said "no, do X instead"
2. **Approvals** — Where the user confirmed your approach worked
3. **Repeated Patterns** — Approaches used 3+ times
4. **New Discoveries** — Things learned that weren't in existing skills

### Step 2: Categorize

Assign confidence levels:

| Level | Criteria |
|-------|----------|
| **HIGH** | Explicit user correction, 5+ occurrences |
| **MEDIUM** | Pattern worked 3+ times |
| **LOW** | First observation, needs validation |

### Step 3: Apply A.U.D.N.

For each learning, determine action:

| Action | When |
|--------|------|
| **ADD** | No similar skill/pattern exists |
| **UPDATE** | Similar exists, needs enhancement |
| **DELETE** | New learning contradicts old |
| **NOOP** | Already fully captured |

### Step 3.5: Hook-Worthiness Gate

For each HIGH-confidence pattern, evaluate whether it should become a **hook** (active enforcement at tool-call time) rather than just an expertise YAML entry (passive documentation).

**Token-efficiency mandate (non-negotiable)**: Per `.claude/rules/hook-efficiency.md`, every proposed hook MUST use the triple-gate pattern so it enters context ONLY when truly applicable. A hook that fires context on 10%+ of tool calls is cost bloat, not signal. Default to expertise unless the hook genuinely saves from irreversible damage.

Before proposing ANY hook, the proposed rule body MUST contain:
- **Gate 1 — Matcher scope**: specific tool name, NEVER `*`
- **Gate 2 — Bash-native fast-path** (for Bash matcher): raw-string substring check on stdin BEFORE `jq`/subprocess invocation. Exit `echo '{}'; exit 0` in <2ms for non-matching cases.
- **Gate 3 — Conditional early-exit**: after parsing, if the specific condition doesn't apply, inject NOTHING. Only inject context when the hook can produce value.

Propose `<5ms on 95%+ of invocations` as the budget. If the hook fires meaningful context on more than ~5% of calls, reconsider whether expertise suffices.

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
| **8-10** | **MUST be a hook** — propose hookify alongside expertise YAML (threshold raised from 7 after token-bloat concern 2026-04-23) |
| **5-7** | **Consider hook** — only propose if existing hooks don't partially cover AND the triple-gate fast-path is explicit |
| **0-4** | **Expertise only** — passive documentation is sufficient. Default path. |

**Before proposing a new hook**: search `.claude/hookify.*.local.md` and `settings.local.json` shell hooks for existing coverage. If existing hooks partially cover the pattern, propose an UPDATE to the existing hook rather than a new one. A bloated hook list is worse than a missing hook — the user's tokens pay for each non-firing hook's matcher evaluation on every tool call.

**Hook proposal format** (append to the Step 5 output for patterns that score 7+):

```markdown
### HOOKIFY: [pattern_name]
**Hook Score**: [N]/10
**Matrix**: Irreversible=[Y/N] Pre-exec=[Y/N] Detectable=[Y/N] Time-critical=[Y/N] Not-covered=[Y/N]
**Type**: PreToolUse warn | PreToolUse block | PostToolUse addContext | Stop addContext
**Tool Matcher**: [tool pattern, e.g. supabase-yourproject_apply_migration]
**Existing Coverage**: [None | Partial: hookify.X.local.md covers Y but not Z]
**Content Summary**: [1-2 sentence description of what the hook injects/blocks]
```

### Step 4: Check Existing

Before proposing changes, search:

```
.claude/skills/**/*.md
.claude/expertise/*.yaml
```

### Step 5: Propose Changes

Present proposed changes in this format:

```markdown
## Proposed Skill/Expertise Updates

### ADD: [pattern_name]
**Confidence**: HIGH/MEDIUM/LOW
**Reason**: [why this should be added]
**Location**: .claude/expertise/[file].yaml
**Content**:
```yaml
- name: pattern_name
  detection: |
    [how to identify]
  resolution: |
    [how to fix]
```

### UPDATE: [existing_skill]
**Reason**: [what's being enhanced]
**Change**: [description of modification]

---

**Approve these changes?**
**Always offer these five options — do not collapse to a simple y/n:**

- **`y all`** — Apply every proposed change AND every proposed hook
- **`y hooks 8+`** — Apply only hooks with Hook Score ≥ 8/10; skip every non-hook change
- **`y 8+ both`** — Apply only hooks with Hook Score ≥ 8/10 AND only changes labeled HIGH confidence (≥ 8/10 equivalent); skip everything else
- **`y changes 8+`** — Apply only HIGH-confidence changes (≥ 8/10 equivalent); skip all hooks and all MEDIUM/LOW changes
- **`y changes only`** — Apply every proposed change but NO hooks (for when user trusts the documentation path but wants to manually review hooks separately)
- **`n`** — Cancel all
- **`edit`** — User enumerates specific items (e.g., "y for 1, 3, 5; skip 2, 4")

**Confidence-to-score mapping for filtering**:
- HIGH confidence → treat as ≥ 8/10 for filter purposes
- MEDIUM confidence → treat as 5-7/10
- LOW confidence → treat as < 5/10

Hook scores come directly from the Step 3.5 matrix (0-10 scale).

When the user picks a filtered option (`y hooks 8+`, `y 8+ both`, `y changes 8+`), echo back the exact list of items being applied and the list being skipped, so they can intervene before writes happen.
```

### Step 6: Apply After Approval

If approved:
1. Write changes to appropriate files
2. Propose git commit message:
   ```
   chore(skills): [description of updates]

   - Added: [list]
   - Updated: [list]
   - Hooks added: [list — or "none"]
   ```

### Step 7: Propagate to Template (universal learnings only)

After the project-local changes commit, evaluate each applied change for **universal applicability**:

**Universal** = benefits ANY Claude Code / Cursor / Supabase / n8n / Vercel / GitHub / PostHog / Sentry / API-integration / React / TypeScript project, not just this codebase's specific domain.

- **Council patterns, git workflows, hook infrastructure, shell portability, MCP usage patterns, code-review discipline, planning protocols, tool fallback rules** → UNIVERSAL, push to template.
- **Project-specific data models, pipeline references, the app schemas, client-specific business logic, specific table/column names** → NEVER push (respect `.claude/template-source.md` PROJECT-SPECIFIC list).

For each universal change:
1. Read `.claude/template-source.md` to confirm the file is in the TEMPLATE-MANAGED table (or propose adding it)
2. Invoke `/push-to-template` to handle the actual copy + generalization + CHANGELOG entry
3. If the change affects a file NOT currently template-managed but IS universal, update `.claude/template-source.md` first to add the mapping, THEN push

**Why this matters**: patterns that caught a bug in this project (e.g., "URL-param schemes are per-page, grep target before reusing") are free wins for every future project. Letting them stay local is a cross-project tax.

**Propose push at the same approval gate**: "Apply + push to template" as one of the `y` options in Step 5. Default assumes user wants universal learnings propagated unless they explicitly skip.

## Abstraction Rules

When creating new patterns:

1. **Extract MECHANISM, not INSTANCE**
   - BAD: "Fleet 998 batch stuck"
   - GOOD: "Batches timeout after 10 min if workflow fails"

2. **Use Placeholders**
   - `{{fleet}}`, `{{batch_id}}`, `{{event_id}}`

3. **Generalize**
   - Error types, not specific error messages
   - Patterns, not specific IDs
