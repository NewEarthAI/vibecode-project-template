---
name: skill-creator
description: |
  Autonomously create, test, and refine Claude Code skills using abstraction-first patterns and rigorous evaluation. Use when: "create a skill", "save this as a skill", "skill this", "make reusable", "test this skill", "benchmark skill", "optimize description", or when a pattern repeats 3+ times. Implements A.U.D.N. lifecycle (Add/Update/Delete/Noop), dual-skill classification (Capability Uplift vs Encoded Preference), parameterized templates, multi-agent evaluation with blind comparison, benchmark tracking, and iterative description optimization.
allowed-tools: Read, Write, Bash, Grep, Agent
user-invocable: true
version: 4.0
classification: encoded-preference
created: 2026-02-15
updated: 2026-03-26
triggers:
  - "create a skill" / "save this as a skill" / "skill this" / "make reusable"
  - "test this skill" / "benchmark skill" / "run evals" / "optimize description"
  - pattern repeats 3+ times or same error corrected 2+ times
validated_on:
  - Fleet operations domain skills (60+ created via this workflow)
  - Cross-project template skills (pushed to claude-code-project-template)
  - Skill-auditor-merger (created with this skill, passes its own audit)
parameters:
  - name: skill-name
    type: string
    default: inferred from pattern
  - name: classification
    type: enum
    default: encoded-preference
    values: [capability-uplift, encoded-preference]
---

# Unified Skill Creator v4.0

> **Philosophy:** Extract patterns, not instances. Test rigorously. Refine iteratively. Skills improve themselves.

---

## Core Principles

| Principle | Implementation |
|-----------|----------------|
| **Code as policy** | Skills are executable, not just documentation |
| **Max 3-4 compositions** | Complex skills combine ≤4 atomic patterns |
| **Semantic deduplication** | Compare before creating; merge if similar exists |
| **Parameterize, don't hardcode** | `{{table_name}}` not literal table names |
| **Test on held-out tasks** | "Would this work on a DIFFERENT similar task?" |
| **Measure with evals** | Write evals, run benchmarks, track pass rates |
| **Classify to future-proof** | Capability Uplift vs Encoded Preference |
| **Progressive disclosure** | ~100 words for discovery, full content on activation |

---

## Trigger Conditions

**User says:**
- "create a skill for this" / "save this as a skill" / "skill this" / "make this reusable"
- "test this skill" / "benchmark skill" / "run evals" / "optimize description"

**Auto-detect:**
- Same pattern 3+ times
- Same error corrected 2+ times
- Multi-step orchestration repeated

---

## Naming Pre-Flight (do this BEFORE the workflow's first commit)

Every new skill creates files in a named directory. Pick the name BEFORE the first commit — renaming after commit triggers amend / cherry-pick / reset gymnastics that bash-guardian blocks the destructive parts of, and produces a noisy PR history at minimum.

Three checks before naming is final:

1. **Cross-client namespace check** — if you maintain multiple client projects, grep all sibling project trees for the proposed name. Domain words like "fleet" (logistics clients), "deals" (real-estate), "trips" (mobility), "loads" (freight), "patients" (medical), "members" (associations) collide and confuse cross-session memory recall.

   ```bash
   find ~/code ~/Documents/GitHub -maxdepth 4 -type d -iname "*<name>*" 2>/dev/null | head
   ```

   If sibling projects surface, pick a different name. Stay in the same verb family if possible (e.g. `/verify-pipeline` + `/verify-shipped`).

2. **Sister-skill family check** — does `/verify-*`, `/debug-*`, `/refactor-*`, `/check-*` already exist? Names that compose with an existing family are easier to remember + read in tab-completion + cohere in skill listings.

3. **Mental-model check** — does the verb match what the user actually says when invoking? "/verify-shipped" matches "is everything actually shipped?" The naming should pass this lay-test BEFORE files are written. If you can't paraphrase what the skill does in 5 words containing the skill name's verb, the name is wrong.

### If you discover the name is wrong AFTER the first commit

- Fix it in a SECOND commit, NOT via `git commit --amend`. Amend on a multi-commit branch with staging drift pulls in unintended files (verified 2026-05-07: a recent PR's amend pulled 3 unrelated component files via misordered `git add -A`).
- Update memory index, continuation files, and frontmatter in lockstep with the directory rename — a stale reference in memory keeps the old name alive in cross-session recall.
- The recovery path when this goes wrong is documented in 📄 the operational-guardrails rule under "Recovery from a bad commit on a just-pushed feature branch."

**Failure precedent (2026-05-07)**: a skill's foundation commit was authored as `verify-fleet`, then renamed mid-session to `verify-shipped` after the operator flagged a naming clash with their logistics client (where "fleet" means trucks). The post-commit rename burned roughly 10 minutes on sed-replace + amend + recovery. Pre-flight check would have caught it in under 30 seconds.

---

## Unified Workflow (8 Steps)

### Step 1: Extract Pattern (Not Instance)

From conversation, extract the MECHANISM (why) not the INSTANCE (what):

```
PATTERN (Keep)                    INSTANCE (Strip)
─────────────────────────────────────────────────────
"webhook returns empty object"    "{{record_id}} failed"
"access nested body property"     "workflow {{workflow_id}}"
"timeout after N ms"              "{{table_name}}"
```

**See:** `ABSTRACTION_RULES.md` for detailed extraction rules.

### Step 2: A.U.D.N. Decision (Check Existing Skills First)

```
┌─────────────────────────────────────────────────────────────┐
│                    A.U.D.N. DECISION                        │
├─────────────────────────────────────────────────────────────┤
│  ADD    → No similar skill exists → Create new              │
│  UPDATE → >70% concept overlap → Merge new patterns in      │
│  DELETE → Contradiction found → Invalidate old              │
│  NOOP   → 100% captured → Don't duplicate                  │
└─────────────────────────────────────────────────────────────┘
```

**MANDATORY — Scan BOTH local repo AND template repo before deciding ADD:**

```bash
# 1. Local repo scan (project-specific skills)
grep -rEn "keyword" .claude/skills/ 2>/dev/null

# 2. Template repo scan (agency-wide skills the current project inherits from)
#    The template path is defined in .claude/template-source.md
TEMPLATE_PATH=$(grep -A1 "^local_path:" .claude/template-source.md | head -1 | awk '{print $2}')
if [ -d "$TEMPLATE_PATH/.claude/skills/" ]; then
  ls "$TEMPLATE_PATH/.claude/skills/" | head -50  # enumerate existing skills
  grep -rEn "keyword" "$TEMPLATE_PATH/.claude/skills/" 2>/dev/null  # content scan
fi

# 3. Read adjacent skill descriptions — check frontmatter for any skill whose
#    name, description, or trigger phrases overlap with the proposed scope
```

**The template scan is non-negotiable.** A skill that looks novel locally may overlap with a skill already in the template repo that bootstraps every future client project. Adding a duplicate in the local repo creates a trigger collision in any project that inherits from the template. This rule was added in response to a real incident where a skill was built locally without scanning the template and turned out to overlap with three existing template skills (`tailwind-shadcn-system`, `brand-visual-identity`, `design-review`), requiring council review to resolve. The cost of one minute of template scanning before writing prevents hours of refactoring afterward.

**Decision thresholds**:
- >70% concept overlap with an existing skill (local OR template) → **UPDATE** that skill, do not ADD a new one
- 30-70% overlap → consider ADD with explicit `do-not-trigger` entries pointing at the overlapping skills
- <30% overlap → ADD is safe

### Step 3: Classify Skill

**Every skill gets classified.** This determines its eval strategy and lifecycle.

| Classification | When | Eval Strategy | Lifecycle |
|---------------|------|---------------|-----------|
| **Capability Uplift** | Base model can't do this consistently | Measure if future models match skill output natively | Flag for decommissioning when model catches up |
| **Encoded Preference** | Model can do it, but needs specific workflow fidelity | Verify exact sequence (Steps A→B→C) without deviation | Durable — check workflow still matches team process |

**Logic gate:**
- IF the task involves a capability the base model cannot perform consistently → **Capability Uplift**
- IF the task involves a sequence the model can already perform but requires specific fidelity → **Encoded Preference**

Add to frontmatter: `classification: capability-uplift` or `classification: encoded-preference`

### Step 4: Generate Parameterized Skill

Use templates from `TEMPLATES.md`. Every value that could change across projects becomes a `{{parameter}}`.

**See:** `TEMPLATES.md` for Standard Pattern, MCP Wrapper, and Orchestration templates.

### Step 5: Write Evals

Create `evals/evals.json` alongside the skill with 2-3 realistic test prompts.

```json
{
  "evals": [
    {
      "id": "eval-001",
      "prompt": "A realistic prompt that SHOULD trigger the skill",
      "should_trigger": true,
      "expectations": ["Output should contain X", "Should handle Y"]
    },
    {
      "id": "eval-002",
      "prompt": "A similar-sounding prompt that should NOT trigger",
      "should_trigger": false,
      "expectations": []
    }
  ]
}
```

**Guidelines:**
- Include both "should trigger" AND "should NOT trigger" cases
- Expectations should be **hard to pass without actually doing the work** (not trivial)
- Test realistic user prompts, not artificial test strings
- For **Capability Uplift**: focus on output quality assertions
- For **Encoded Preference**: focus on workflow fidelity assertions (did it follow Steps A→B→C?)

**When to skip evals:** Level 1 atomic patterns that are trivially verifiable (e.g., a single syntax pattern). Level 2+ composite skills should always have evals.

### Step 6: Test & Benchmark

**Quick test (single run):**
```bash
python .claude/skills/skill-creator/scripts/run_eval.py \
  --skill-path .claude/skills/{{skill-name}} \
  --eval-path .claude/skills/{{skill-name}}/evals/evals.json \
  --output-dir .claude/skills/{{skill-name}}/eval_results/
```

**Benchmark mode (multiple runs with stats):**
Run evaluations multiple times, then aggregate:
```bash
python .claude/skills/skill-creator/scripts/aggregate_benchmark.py \
  --benchmark-dir .claude/skills/{{skill-name}}/benchmarks/ \
  --skill-name "{{skill-name}}" \
  --markdown .claude/skills/{{skill-name}}/benchmarks/report.md
```

**Blind comparison (A/B testing):**
Spawn comparator agent to judge outputs blind:
- Run the eval WITH the skill active (Output A)
- Run the eval WITHOUT the skill (Output B)
- Comparator judges purely on output quality
- Analyzer explains WHY one approach won

**Agents available:**
- `skill-eval-grader` — Grades outputs against expectations
- `skill-eval-comparator` — Blind A/B comparison
- `skill-eval-analyzer` — Post-hoc analysis and improvement suggestions

**Benchmark metrics tracked:**

| Metric | Description |
|--------|-------------|
| Pass Rate | % of expectations meeting success criteria |
| Elapsed Time | Total execution time per run |
| Token Usage | Computational cost per run |

### Step 7: Validate & Confirm

**A. Held-out abstraction test (from v3.0):**
```
"Would this skill help with a DIFFERENT but similar task?"
- Different table name? → Should still work
- Different workflow ID? → Should still work
- Different project? → Core pattern applies
```

**B. Eval pass rate check:**
- Target: ≥80% pass rate on evals
- If below threshold, either fix the skill or improve evals

**C. Description optimization (if trigger accuracy < 80%):**
```bash
python .claude/skills/skill-creator/scripts/run_loop.py \
  --skill-path .claude/skills/{{skill-name}} \
  --eval-path .claude/skills/{{skill-name}}/evals/evals.json \
  --max-iterations 5 \
  --holdout 0.3 \
  --output-dir .claude/skills/{{skill-name}}/optimization/
```

This iteratively: runs evals → identifies failures → improves description → re-runs evals. Uses train/test split to prevent overfitting.

**D. User confirmation:**
```
I'll {{ADD/UPDATE}} skill `{{name}}` ({{classification}}):

Pattern: {{one-line mechanism}}
Classification: {{capability-uplift / encoded-preference}}
Eval pass rate: {{rate}}%
Parameters: {{list placeholders}}

This will work for any {{abstracted_domain}}, not just {{specific_instance}}.
Create it?
```

### Step 8: Store with Metadata

```yaml
---
name: {{name}}
description: |
  {{~100 word summary optimized for trigger accuracy}}
version: 1.0
classification: {{capability-uplift / encoded-preference}}
created: {{date}}
updated: {{date}}
supersedes: {{old_skill if UPDATE}}
validated_on:
  - {{held_out_task_1}}
  - {{held_out_task_2}}
parameters:
  - name: {{param}}
    type: {{type}}
    default: {{value}}
allowed-tools: {{tools}}
---
```

---

## Abstraction Hierarchy (4 Levels)

```
Level 1: ATOMIC PATTERN       → Single mechanism (skip evals if trivial)
Level 2: COMPOSITE SKILL      → 2-4 atomic patterns (evals recommended)
Level 3: DOMAIN SKILL         → All patterns for a domain (evals required)
Level 4: ORCHESTRATION SKILL  → Cross-domain coordination (evals + benchmarks required)
```

**Rule: Never exceed 4 atomic patterns per composite skill.**

---

## Quality Checklist

### Must Pass (Auto-Validated)

```
□ No hardcoded IDs (record, workflow, table, user)
□ No project-specific URLs or endpoints
□ Error patterns use mechanism, not exact message
□ Parameters have defaults where applicable
□ ≤4 atomic patterns per composite skill
□ Description ≤1024 chars / ~100 words
□ SKILL.md ≤500 lines (body)
□ ≥3 anti-patterns documented
□ Classification assigned (capability-uplift / encoded-preference)
```

### Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Creating a skill from a single instance | Overfits to one case; fails on the next similar task | Extract the mechanism, parameterize the instance — needs 3+ occurrences |
| Hardcoding IDs/URLs/table names in skill content | Breaks when used in a different project or context | Use `{{parameter}}` placeholders with documented defaults |
| Skipping A.U.D.N. check before creating | Produces duplicate or contradictory skills | Always search existing skills first; merge if >70% overlap |
| Creating Level 3+ composite skill without evals | No way to verify the skill works or detect regression | Evals are mandatory for composite skills — test both trigger and output |
| Putting version numbers in skill file names | Rename breaks all `$('OldName')` references downstream | Version goes in frontmatter metadata, not file names |

### Error Handling

| Condition | Behavior |
|-----------|----------|
| No existing skills directory found | Create `.claude/skills/` and proceed with ADD |
| A.U.D.N. search finds >70% overlap | Switch to UPDATE mode; merge new patterns into existing skill |
| Eval pass rate <80% | Do NOT store skill — fix content or improve evals first |
| `validate.sh` reports FAILED | Block storage; show failures and prompt for fix |
| Description optimization loop exceeds 5 iterations | Stop iterating; use best result so far and warn about trigger accuracy |
| User declines skill creation at confirmation step | NOOP — do not create; preserve any eval results for future reference |

### Validation Scripts

```bash
# Abstraction quality check (existing)
bash .claude/skills/skill-creator/scripts/validate.sh .claude/skills/{{name}}/

# Schema validation (new)
python .claude/skills/skill-creator/scripts/quick_validate.py .claude/skills/{{name}}/
```

---

## Description Optimization

The description is the **primary trigger mechanism**. It must be:
- **100-200 words** (imperative phrasing: "Use this skill when...")
- **Distinctive** enough to avoid confusion with other skills
- Focused on **user intent**, not implementation details
- Tested against both "should trigger" and "should NOT trigger" prompts

**Automated optimization:**
```bash
python .claude/skills/skill-creator/scripts/run_loop.py \
  --skill-path .claude/skills/{{name}} \
  --eval-path .claude/skills/{{name}}/evals/evals.json \
  --max-iterations 5
```

---

## Viewing Results

```bash
# Open eval viewer in browser (drag-and-drop JSON files)
open .claude/skills/skill-creator/eval-viewer/viewer.html

# Generate review HTML from results directory
python .claude/skills/skill-creator/eval-viewer/generate_review.py \
  --grading-dir .claude/skills/{{name}}/eval_results/ \
  --output review.html --open
```

---

## Quick Commands

| Action | Command |
|--------|---------|
| Create skill | "skill this" / "save as skill" / "create skill" |
| Update skill | "add this to the webhook skill" / "update skill" |
| Search skills | "do we have a skill for this?" |
| Run evals | "test this skill" / "run evals for X" |
| Benchmark | "benchmark skill X" |
| Optimize description | "optimize description for X" |
| Validate | `bash scripts/validate.sh [path]` |

---

*Protocol Version: 4.0 — Unified: A.U.D.N. + Evals + Benchmarks + Classification*
