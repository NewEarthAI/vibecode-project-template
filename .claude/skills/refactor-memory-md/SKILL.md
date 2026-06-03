---
name: refactor-memory-md
description: |
  Analyze and refactor MEMORY.md to stay within the 200-line system limit.
  Audit all memory files for staleness, duplication, type hygiene, frontmatter quality,
  and content that belongs in topic files rather than the index. Consolidate, archive,
  and restructure the memory system for maximum cross-session recall quality.
  Use when: "refactor memory", "clean up memory", "memory audit", "fix MEMORY.md",
  "memory is too long", "memory overflow", or when MEMORY.md exceeds 200 lines.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
user-invocable: true
version: 1.0
classification: encoded-preference
created: 2026-03-13
---

!`MEMDIR=$(find ~/.claude/projects -path "*/memory/MEMORY.md" 2>/dev/null | head -1) && wc -l "$MEMDIR" 2>/dev/null`
!`MEMDIR=$(find ~/.claude/projects -path "*/memory" -type d 2>/dev/null | head -1) && ls "$MEMDIR"/*.md 2>/dev/null | grep -v MEMORY.md | wc -l | xargs -I{} echo "Topic files: {}"`

# Refactor Memory MD v1.0

> **Philosophy:** Memory is only valuable if it's findable, current, and actionable.
> A 226-line MEMORY.md with 26 invisible lines is worse than a 120-line index
> pointing to well-organized topic files. Optimize for **recall quality**, not completeness.

---

## Why This Exists

Claude Code's memory system auto-loads MEMORY.md at conversation start, but **truncates at 200 lines**.
Content beyond line 200 is silently dropped — the agent doesn't know it exists.
This means:
- **Overflowed content = lost memory** (worse than not saving it at all — you think you remember but don't)
- **Bloated index = wasted context** (every line of MEMORY.md competes with the user's actual prompt)
- **Stale memories = wrong decisions** (outdated project state causes incorrect assumptions)
- **Duplicate content = noise** (same info in MEMORY.md + a topic file + CLAUDE.md = 3× the tokens, 0× the value)

The refactor-claude-md skill handles the instruction document. This skill handles the **knowledge store**.

---

## Trigger Conditions

**User says:**
- "refactor memory" / "clean up memory" / "memory audit"
- "MEMORY.md is too long" / "fix memory overflow"
- "organize my memories" / "memory housekeeping"

**Auto-detect:**
- MEMORY.md exceeds 180 lines (proactive warning)
- MEMORY.md exceeds 200 lines (critical — content is being dropped)
- Memory file has no frontmatter or wrong type classification
- Duplicate content detected between memory files and CLAUDE.md/rules

---

## Unified Workflow (7 Steps)

### Step 1: Measure Current State

```bash
# Line count
wc -l "${MEMORY_DIR}/MEMORY.md"

# File inventory
ls -la "${MEMORY_DIR}/"

# Check for frontmatter in each file
for f in "${MEMORY_DIR}"/*.md; do
  [ "$(basename "$f")" = "MEMORY.md" ] && continue
  head -1 "$f"
done
```

**Capture:**
- Total MEMORY.md lines (target: ≤150 ideal, ≤180 safe, ≤200 hard limit)
- Number of topic files
- Files missing frontmatter
- Total memory system size (lines across all files)

### Step 2: Audit Every Memory File (5 Dimensions)

Read each `.md` file in the memory directory (excluding MEMORY.md) and score on:

#### A. Frontmatter Quality
```
□ Has valid frontmatter (--- delimiters, name, description, type)
□ Type is one of: user, feedback, project, reference
□ Description is specific enough for relevance-matching (not generic)
□ Name matches filename convention
```

#### B. Content Freshness
```
□ Contains dates → check if most recent date is within 30 days
□ Project-type memories: are the facts still current?
□ Reference-type memories: do the referenced systems still exist?
□ Feedback-type memories: still applicable to current workflow?
```

**Staleness tiers:**
| Age | Action |
|-----|--------|
| <30 days | Current — keep |
| 30-60 days | Review — verify still relevant |
| 60-90 days | Likely stale — consolidate or archive |
| >90 days | Archive unless explicitly durable (user profiles, feedback rules) |

**Exempt from staleness:** `user` type memories and `feedback` type memories (these are durable by nature).

#### C. Duplication Check
Cross-reference each memory against:
1. **Other memory files** — semantic overlap >70% = merge candidate
2. **CLAUDE.md** — if content exists in CLAUDE.md, it should NOT be in memory
3. **`.claude/rules/` files** — if content is a rule, it belongs in rules, not memory
4. **`.claude/expertise/` files** — patterns belong in expertise, not memory

#### D. Type Correctness
Verify the `type` field matches the content:
| Type | Content Should Be | Red Flags |
|------|-------------------|-----------|
| `user` | About the user's role, preferences, knowledge | Contains project-specific facts |
| `feedback` | Behavioral correction from user | Contains project status updates |
| `project` | Active work, goals, bugs, decisions | Contains user preferences |
| `reference` | Pointers to external systems | Contains implementation details |

#### E. Actionability
```
□ Would a future session actually use this information?
□ Is this derivable from code, git history, or existing docs?
□ Does this contain ephemeral task details that are now irrelevant?
```

**Content that should NOT be in memory (per system rules):**
- Code patterns, conventions, architecture, file paths → derivable from code
- Git history, recent changes → `git log` / `git blame`
- Debugging solutions → fix is in code; commit message has context
- Anything in CLAUDE.md or rules files → already auto-loaded
- Ephemeral task details → only useful within one session

### Step 3: Audit MEMORY.md Index

The index file has its own quality criteria:

#### A. Index Density
Each line in MEMORY.md should be a **pointer** (link + brief description), not content.
Flag any section in MEMORY.md that:
- Contains >5 lines of inline detail (should be in a topic file)
- Contains schema gotchas, RPC lists, or technical reference (belongs in topic file or rules)
- Contains deployment details (should be in a topic file)
- Duplicates content from a topic file it links to

#### B. Section Organization
MEMORY.md should be organized **semantically by topic**, not chronologically.
Ideal structure:
```markdown
# Memory Index

## Infrastructure
- [Server A](server-a.md) — Role, cost, key details
- [Server B](server-b.md) — Role, monitoring status

## Active Work
- [Current Sprint](current-sprint.md) — What's in progress

## Partnerships & Strategy
- [Partner A](partner-a.md) — Relationship, status

## User Profiles
- [Primary User](user_primary.md) — Role, preferences

## Behavioral Rules (Feedback)
- [Rule Name](feedback_rule.md) — One-line summary
- ...

## Schema & Data Reference
- [Schema Gotchas](schema-gotchas.md) — Column name traps
- Common gotchas → `.claude/rules/data-layer.md`

## Expertise
- See `.claude/expertise/*.yaml` files
```

#### C. Completeness
- Every topic file in the memory directory MUST have a corresponding entry in MEMORY.md
- Every entry in MEMORY.md MUST point to an existing file
- No orphaned files, no broken links

### Step 4: Generate Refactoring Plan

Based on the audit, generate a concrete action plan:

```markdown
## Refactoring Plan

### Extract to Topic Files (from MEMORY.md inline content)
- [ ] "Section Name" (lines X-Y) → `topic-file.md`

### Consolidate / Merge
- [ ] Merge `file_a.md` + `file_b.md` → `combined.md` (>70% overlap)

### Archive (Stale)
- [ ] `old-project.md` — completed 60+ days ago, no ongoing relevance

### Fix Frontmatter
- [ ] `missing-frontmatter.md` — add type, name, description

### Fix Type Classification
- [ ] `wrong-type.md` — change from project → reference

### Slim MEMORY.md Index
- [ ] Replace inline content with pointers (estimated savings: N lines)
- [ ] Reorganize into semantic sections
- [ ] Remove duplicated content

### Projected Result
- MEMORY.md: X lines → Y lines (Z% reduction)
- Topic files: A → B (net change: +C created, -D archived)
```

**Present this plan to the user for approval before executing.**

### Step 5: Execute Refactoring

After user approval, execute in this order:

1. **Create new topic files** (extractions from MEMORY.md)
   - Each gets proper frontmatter
   - Content structured with **Why:** and **How to apply:** lines for project/feedback types
2. **Update existing topic files** (consolidations/merges)
3. **Archive stale files** (move to `memory/archive/` subdirectory, NOT delete)
4. **Fix frontmatter** on files that need it
5. **Rewrite MEMORY.md** as a clean semantic index
   - Pointers only — no inline content blocks
   - Organized by topic, not chronologically
   - Each entry: `- [Human-readable name](filename.md) — one-line description`
   - Target: ≤150 lines (leaves 50-line buffer for organic growth)

### Step 6: Verify

```bash
# Line count check
wc -l "${MEMORY_DIR}/MEMORY.md"
# Must be ≤200 (hard limit), ideally ≤150

# Orphan check — files not referenced in MEMORY.md
for f in "${MEMORY_DIR}"/*.md; do
  fname=$(basename "$f")
  [ "$fname" = "MEMORY.md" ] && continue
  grep -q "$fname" "${MEMORY_DIR}/MEMORY.md" || echo "ORPHAN: $fname"
done

# Broken link check — MEMORY.md references to missing files
grep -oP '\(([^)]+\.md)\)' "${MEMORY_DIR}/MEMORY.md" | tr -d '()' | while read fname; do
  [ -f "${MEMORY_DIR}/$fname" ] || echo "BROKEN: $fname"
done

# Frontmatter check
for f in "${MEMORY_DIR}"/*.md; do
  [ "$(basename "$f")" = "MEMORY.md" ] && continue
  head -1 "$f" | grep -q '^---' || echo "NO FRONTMATTER: $(basename "$f")"
done
```

### Step 7: Report

Output a summary:

```
## Memory Refactoring Complete

### Before
- MEMORY.md: X lines (Y over limit)
- Topic files: N
- Files with issues: M

### After
- MEMORY.md: X lines (Y% reduction, Z-line buffer remaining)
- Topic files: N (A new, B merged, C archived)
- All frontmatter valid: ✓
- All links verified: ✓
- No orphans: ✓

### Changes Made
1. Extracted "Section Name" → `new-topic-file.md`
2. Merged `file_a.md` + `file_b.md` → `combined.md`
3. Archived `stale-file.md` → `archive/stale-file.md`
4. Fixed frontmatter on N files
5. Reorganized MEMORY.md into semantic sections

### Growth Forecast
At current rate (~X lines/week), next refactoring needed: ~DATE
```

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Delete stale memories | Loses historical context permanently | Archive to `memory/archive/` |
| Put all detail in MEMORY.md | Exceeds 200-line limit, content silently dropped | Topic files with index pointers |
| Organize chronologically | Hard to find related topics; grows linearly | Semantic sections (Infrastructure, Feedback, etc.) |
| Duplicate CLAUDE.md content | Wastes context window tokens; risks contradictions | Reference CLAUDE.md, don't copy |
| Skip frontmatter | Breaks memory system's relevance-matching | Always include name, description, type |
| One mega topic file | Same problem as bloated MEMORY.md | Focused files: one concern per file |
| Archive feedback memories | Feedback is durable; archiving loses learned behavior | Only archive project/reference types |
| Generic descriptions | "Project stuff" doesn't help relevance matching | "VPS agent service phases, cron jobs, infrastructure costs" |

---

## Memory File Naming Convention

```
{type}_{topic}.md           — for typed memories (e.g., feedback_mcp_fallback.md)
{topic-slug}.md             — for descriptive names (e.g., strategic-partnerships.md)
```

Both are acceptable. The frontmatter `type` field is authoritative, not the filename prefix.

---

## Archive Policy

Archived memories go to `memory/archive/` with an added frontmatter field:

```yaml
archived: {{date}}
archive_reason: "Completed project, no ongoing relevance"
```

Archives are NOT loaded into context but remain searchable if a future session needs historical context.

---

## Quality Standards

### MEMORY.md Index
- **Hard limit**: 200 lines (system truncation)
- **Target**: ≤150 lines (50-line growth buffer)
- **Warning threshold**: 180 lines (trigger proactive refactoring)
- **Format**: Semantic sections with pointer entries only
- **No inline content blocks** — every detail belongs in a topic file

### Topic Files
- **Frontmatter**: Required (name, description, type)
- **Size**: ≤80 lines per file (split if larger)
- **Freshness**: Project types reviewed monthly; feedback/user types are durable
- **No duplication**: Content exists in exactly one place

### System Coherence
- Every topic file referenced in MEMORY.md
- Every MEMORY.md entry points to an existing file
- No content duplicated between memory, CLAUDE.md, and rules files
- Type classifications match actual content
