# Memory-Layer Best Practices

> **Origin**: NewEarth AI Agency, W1 + W1.5 of the Q2 2026 Memory Architecture initiative (2026-04-26). This doc captures the portable patterns for adoption in any Claude Code project.

This is the operating manual for an agentic-AI project's memory layer — the disciplines that keep MEMORY.md findable, current, and actually loaded.

## Why this exists (the problem)

Claude Code auto-loads `MEMORY.md` at conversation start, but **truncates at 200 lines**. Content past line 200 is silently dropped — the agent doesn't know it exists. Combined with three adjacent failure modes, this produces a quiet, compounding regression:

| Failure mode | What happens | How it hides |
|---|---|---|
| **Truncation past 200 lines** | Lower-half index entries become invisible | No error message; agent just doesn't know the entry exists |
| **Inline content blocks** | Detail belongs in topic files, but bloats MEMORY.md instead | Topic files exist as orphans; index becomes 67% inline content |
| **Stale snapshot drift** | Memory captures DB state at write time; reality moves on | Index says "126 rows"; DB has 654; nobody notices until refactor |
| **Local-only memory state** | Important facts captured in markdown only; siblings can't see them | Cross-session / cross-worktree work breaks silently |

The compounding move: rotation requires user judgment (curatorial taxonomy choices), so it doesn't auto-trigger; users forget to invoke it; MEMORY.md grows past 200; truncation begins; new entries written into invisible territory. By the time someone notices, weeks of memory writes are partially-loaded into every session.

## The four-piece pattern

The discipline that closes this loop is four artifacts working as a unit. Adopting any one without the others is cargo-cult.

### 1. Detection-and-prompt rotation hookify
- File: `.claude/hookify.memory-rotation-warn.local.md` (in this template)
- Event: `Stop` (session-end)
- Action: `wc -l` on `MEMORY.md`; inject WARN at ≥180 / CRITICAL at ≥200
- **Detection-only — does NOT auto-rotate.** Rotation is user-curated.

**Why detection-only**: full auto-rotation is a 3-session trap. Rotation taxonomy decisions (which entries demote to topic files, what to merge, what to archive) cannot be safely automated without the user's curatorial judgment.

### 2. Substrate doctrine
- File: `.claude/rules/memory-layer-substrate-doctrine.md` (in this template)
- Auto-loaded via `code-review-domain-routing.md` on relevant diffs
- **Rule**: new memory-layer cherry-picks MUST persist state to a Supabase (or equivalent) table with stable named schema — never local-only files

**Why structured-substrate primary**: cross-session, cross-worktree, cross-account recall requires shared state. Local files break the moment a sibling session, different worktree, or different machine touches the same workflow.

**MUST include the honesty clause**: `"Enforcement: context-injection only — no automated audit. This is doctrine, not a hard gate."` Without it, the rule becomes compliance theatre that the user BELIEVES is enforced when it's not. Doctrine compounds via repeated context injection, not runtime enforcement.

**Scope carve-out** (built into the template doctrine): existing hookify rules, skills, MEMORY.md / topic files, per-session ephemera are EXEMPT. Doctrine applies to NEW patterns post-adoption-date.

### 3. Code-review domain routing entry
- File: `.claude/rules/code-review-domain-routing.md` (already includes the Memory-Layer Substrate row in this template)
- Effect: doctrine auto-loads on relevant diffs (closes the auto-load promise the doctrine makes)

### 4. Rotation skill with user-curated workflow
- File: `.claude/skills/refactor-memory-md/SKILL.md` (already in this template)
- 7-step workflow with user-approval gate at Step 4 (between audit and execution)
- Output: ≤150 lines target, ≤180 warn buffer, ≤200 hard limit; archive subdir; semantic sections

## Anti-patterns (do not adopt)

| Anti-pattern | Why it fails |
|---|---|
| Full auto-rotation hook | Loses user-curated taxonomy decisions; demotes wrong entries; compounds chaos |
| Inline content blocks in MEMORY.md | Each block is a 5-50 line bloat; pushes other entries past line 200 |
| Doctrine without honesty clause | Compliance theatre — user believes it's enforced when it's a markdown nudge |
| Doctrine with unscoped "NEVER local-only" | Retroactively invalidates existing hookify + skills + memory infrastructure |
| Stale "shipped status" reports kept inline | One-time milestones bloat the index forever; archive instead |
| Skipping the routing entry | Doctrine becomes invisible — exists in `.claude/rules/` but never loaded into context |

## Adoption recipe

### For new projects (via `/setup`)
All four artifacts ship in this template. Initializing a new project pulls them automatically. No additional setup — the rotation hook fires once MEMORY.md crosses 180 lines.

### For existing projects (run `/update-latest` or equivalent)
Pull these specific files from the template:
1. `.claude/hookify.memory-rotation-warn.local.md`
2. `.claude/rules/memory-layer-substrate-doctrine.md`
3. The Memory-Layer Substrate row in `.claude/rules/code-review-domain-routing.md`

Optional but recommended after pulling: invoke the rotation skill on the project's MEMORY.md to clean up any existing inline-content drift.

### Project-specific customization

The doctrine file uses generic placeholders for:
- The project's parent invariant / binding constraint reference (replace with your council session OR mark as "to be defined")
- The project's memory-layer table names (replace `knowledge_items`, `knowledge_atoms`, etc. with your equivalents)
- KAIROS-style decommission trigger date (optional — keep if you want a calendared re-evaluation against Anthropic's potential KAIROS daemon release)

The hookify rule and routing entry are designed to work as-is with no customization needed.

## Stale-snapshot defense

The rotation skill performs an audit on each invocation, but the highest-leverage check is during extraction of any inline content block: **re-query the source-of-truth before writing the topic file.** NewEarth's W1.5 rotation surfaced two regressions this way (action backlog had grown 2.5x, active monitor sources had dropped 67%) that the original snapshot had hidden for ~6 weeks.

**Discipline**: when extracting an inline block that contains numerical claims, re-query before writing.

## Provenance

This pattern originated in the NewEarth AI Agency hub during the W1 + W1.5 sessions of the Q2 2026 Memory Architecture initiative. The four-piece pattern is the portable extract; agency-specific adoption details (FTS migrations, Karpathy Wiki cherry-pick, ClawMem decay calibration) are NOT propagated to this template.
