---
name: skill-auditor-merger
description: |
  Ingest external skills from any source (local path, GitHub URL, npx package, skills.sh link,
  user-pointed path), audit bidirectionally against our quality standards and for superior
  patterns worth absorbing, then produce a merged version better than both. Supports batch mode.
  Use when: "audit this skill", "merge this skill", "evaluate external skill", "compare skills",
  "skill quality check", "ingest skill from", "absorb patterns from", or after installing
  a community skill.
version: 1.0
classification: capability-uplift
created: 2026-03-26
updated: 2026-03-26
requires:
  - skill-creator
validated_on:
  - audit_skill_from_github_url
  - audit_messy_single_file_no_frontmatter
  - merge_well_structured_skill_with_our_standards
  - batch_audit_multiple_skills_from_repo
triggers:
  - "audit this skill"
  - "merge this skill"
  - "evaluate external skill"
  - "skill quality check"
  - "ingest skill from"
  - "absorb patterns from"
  - "compare skills"
parameters:
  - name: source
    type: string
    description: "Path, URL, or package name of external skill to audit"
  - name: mode
    type: enum
    values: [audit-only, merge, batch]
    default: merge
    description: "audit-only = report only; merge = audit + merged output; batch = process multiple skills"
  - name: target_project
    type: string
    default: current
    description: "Project context to align against (reads CLAUDE.md, stack, MCP servers)"
  - name: output_dir
    type: string
    default: ".claude/skills/{{skill-name}}"
    description: "Where to write the merged skill output"
  - name: auto_push
    type: boolean
    default: false
    description: "If true and skill is project-agnostic, invoke /template-push after merge"
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion, WebFetch]
user-invocable: true
---

# Skill Auditor & Merger

> **Purpose**: Ingest, audit, and merge external skills to our ecosystem standards.
> **Core innovation**: Dual-direction audit — score AGAINST our checklist AND mine FOR superior patterns worth absorbing.
> **Level**: 4 (Orchestration) — composes ingestion, quality auditing, merging, and post-completion actions.

---

## Quick Reference

### Tool Differentiation

| Need | Tool | Why |
|------|------|-----|
| Create a skill from scratch | `/skill-creator` | Starts from conversation pattern extraction |
| Audit and merge an external skill | `/skill-auditor-merger` | Starts from existing skill file |
| Push finalized skill to template repo | `/template-push` | After skill is ready for cross-project use |
| Quick format validation only | `validate.sh` / `quick_validate.py` | Binary pass/fail checks, no content analysis |

### Input Source Resolution

| Source Type | Detection Pattern | Resolution Method |
|-------------|-------------------|-------------------|
| Local path | Starts with `/`, `./`, `~` | `Read` the SKILL.md directly; `Glob` for companion files |
| GitHub URL | Contains `github.com` or `raw.githubusercontent.com` | `WebFetch` raw content URL (convert `/blob/` → `/raw/`); for repo URLs, fetch tree first |
| npx package | Starts with `npx ` or `@scope/package` | `Bash`: `npx --yes <pkg>` in temp dir, then `Glob` for `**/SKILL.md` in `node_modules/` and `.claude/skills/` |
| skills.sh link | Contains `skills.sh` | `WebFetch` the URL; follow redirect to GitHub raw content |
| User-pointed | User says "the skill at..." | `Read` the exact path provided |

---

## Execution: Three Phases

### Phase 1: Ingest & Normalize

**Step 1.0 — Preflight Dependency Check**

Before any work, verify skill-creator infrastructure exists:
- Check: `.claude/skills/skill-creator/scripts/validate.sh` exists
- Check: `.claude/skills/skill-creator/ABSTRACTION_RULES.md` exists
- If missing: HALT with error: "skill-auditor-merger requires skill-creator. Install it first, or run with `mode=audit-only` (skips validation gates)."
- `mode=audit-only` can proceed without skill-creator — Phase 2 scoring is self-contained.

**Step 1.1 — Resolve Source**

Parse the `source` parameter against the detection patterns above. Resolve to file content. If resolution fails, report the error and ask the user to provide the content directly or point to the installed path.

For GitHub repo URLs (not direct file links): fetch the repo tree, locate `**/SKILL.md` files. If multiple found, switch to `batch` mode automatically.

**Step 1.2 — Extract Anatomy**

From the resolved source, extract:
- **Frontmatter**: YAML between `---` delimiters (may be absent)
- **Body sections**: Ordered list of H2/H3 headings with content
- **Companion files**: evals/, references/, scripts/, AGENTS.md, README.md
- **Directory structure**: Full tree of the skill directory
- **Source metadata**: type, URI, content hash (sha256), fetch timestamp

**Step 1.3 — Parse Frontmatter**

Handle three cases:
1. **Standard** (`---` YAML delimiters): Parse normally
2. **Non-standard** (JSON, TOML, other): Convert to YAML equivalent
3. **Missing entirely**: Create empty scaffold, flag `missing_frontmatter: true`

Map fields to our schema. Unknown fields are preserved but flagged. Reference fields:
- Anthropic standard: `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`
- Our extended: `version`, `created`, `updated`, `supersedes`, `validated_on`, `parameters`, `user-invocable`, `triggers`, `classification`

**Step 1.4 — Detect Companion Ecosystem**

Check for companion files and classify each as `standard` (we use this pattern) or `novel` (new pattern):
- `evals/evals.json` — test cases
- `AGENTS.md` — subagent definitions
- `references/*.md` — deep reference files
- `scripts/*.sh`, `scripts/*.py` — automation
- `README.md` — separate documentation

**Step 1.5 — Normalize**

Produce a structured internal representation summarizing: identity, description stats, frontmatter field coverage, section inventory, companion files, and quality indicators (has anti-patterns, has defaults, parameterization count, hardcoded ID count, vague term count).

---

### Phase 2: Dual-Direction Audit

#### Step 2.1 — Audit AGAINST Our Standards

Score the external skill on 7 dimensions. Each dimension 0–10.

| # | Dimension | Weight | 0 (Fail) | 5 (Adequate) | 10 (Exemplary) |
|---|-----------|--------|----------|--------------|-----------------|
| 1 | **Structure & Metadata** | 15% | No frontmatter or missing name/description | Has name + description, missing version/classification/parameters | Full schema: all fields, correct types, defaults documented |
| 2 | **Description & Triggers** | 20% | Missing, >1024 chars, or generic | Present and relevant but missing trigger phrases or too vague | ~100 words, outcome-focused, trigger phrases, distinctive |
| 3 | **Content Architecture** | 15% | Wall of text, no headings | Has headings but flat hierarchy | Clear progressive disclosure: summary → quick ref → phases → deep ref |
| 4 | **Parameterization & Reusability** | 20% | Hardcoded IDs, URLs, table names | Some `{{params}}` but inconsistent | All instance-specific values parameterized, passes held-out test |
| 5 | **Safety Documentation** | 15% | No anti-patterns or error handling | 1-2 anti-patterns, some error cases | ≥3 anti-patterns (Wrong/Why/Right), comprehensive error table |
| 6 | **Token Efficiency** | 5% | >500 lines, redundant content | 300-500 lines, minor redundancy | ≤300 lines, no redundancy, progressive disclosure |
| 7 | **Eval Coverage** | 10% | No evals | Has evals but weak expectations | ≥3 evals with discriminating expectations + should_trigger=false |

**Grade thresholds** (weighted aggregate):

| Grade | Range | Meaning |
|-------|-------|---------|
| A | 85-100 | Exemplary — minimal changes needed |
| B | 70-84 | Good — solid foundation, upgrade specific dimensions |
| C | 55-69 | Adequate — useful patterns, needs restructuring |
| D | 40-54 | Below standard — extract patterns only, rebuild |
| F | 0-39 | Poor — useful only as domain knowledge reference |

**NON-COMMENSURABILITY NOTE — the weighted aggregate is a within-skill summary, NOT a cross-skill ranking.** The 7 dimensions sum quantities of different kinds: a Token Efficiency score (weight 5%) and a Description & Triggers score (weight 20%) measure structurally unlike properties, and folding them onto one 0–100 ladder is a convenience, not a measurement. The weighted total is valid ONLY as a one-skill summary shorthand, read alongside that skill's own detailed audit report. It MUST NOT be used to rank one skill against another as if the numbers were precise or comparable — a skill scoring 78 is not "better than" a skill scoring 74; the gap is inside the noise of an incommensurable sum. Cross-skill decisions use the detailed audit reports and the binary `validate.sh` / `quick_validate.py` pass/fail checks, never the aggregate. Scores are directional within one skill; they are not a leaderboard across skills.

#### Step 2.2 — Audit FOR Superior Patterns

Even a grade-F skill may contain novel techniques. Evaluate each category:

| Category | What to Look For |
|----------|-----------------|
| **Novel techniques** | Domain expertise, unique algorithms, creative solutions not in our ecosystem |
| **Superior prompting** | Better instruction structure, clearer guardrails, more effective agent prompts |
| **Better error handling** | Recovery patterns, graceful degradation, retry strategies we lack |
| **Smarter defaults** | Better default values, more thoughtful configuration choices |
| **Novel companion patterns** | File types we don't use (AGENTS.md, CONNECTORS.md, etc.) |
| **Domain knowledge** | Specialized knowledge that would take significant research to reproduce |

For each discovered pattern, document:
```
SUPERIOR PATTERN: {{category}}
Source: {{section/file in external skill}}
What: {{1-line description}}
Why superior: {{comparison to our current approach}}
Recommendation: adopt as-is | adapt to our format | reference only
```

#### Step 2.3 — Produce Audit Report

Output structured report:
```
SKILL AUDIT REPORT
==================
Source: {{source_uri}}
Skill: {{name}} v{{version}}
Date: {{YYYY-MM-DD}}
Mode: {{mode}}

STANDARDS AUDIT
| Dimension | Score | Notes |
|-----------|-------|-------|
| ... | .../10 | ... |
| **Weighted Total** | **{{score}}/100 ({{grade}})** | |

PASS/FAIL CHECKLIST (from validate.sh)
[PASS/FAIL/WARN] each binary check

SUPERIOR PATTERNS
1. {{pattern with recommendation}}
...

MERGE RECOMMENDATION: Proceed | Extract-patterns-only | Skip | Incompatible
```

If `mode=audit-only`, present the report and stop.

---

### Phase 3: Merge & Elevate

#### Step 3.1 — A.U.D.N. Decision

Before merging, check for existing skills with concept overlap:
```bash
grep -r "{{skill_keywords}}" .claude/skills/ 2>/dev/null
```

- **ADD**: No similar skill exists → create new merged skill
- **UPDATE**: >70% concept overlap → merge patterns into existing skill
- **DELETE**: External contradicts established patterns → document why, skip
- **NOOP**: Already 100% captured → report, skip

#### Step 3.2 — Build Merge Map

For each section of the external skill, apply this decision tree:

```
1. Does section rely on tools/infra we don't have?
   → YES: INCOMPATIBLE (extract portable patterns only)
2. Do we have an equivalent section?
   → NO: KEEP (if well-structured) or UPGRADE (if poorly structured)
3. Is the external version better than ours?
   → YES: ABSORB (extract into our structure)
4. Is our version better?
   → YES: REWRITE (our template + external content as reference)
5. Both have unique value?
   → YES: SUPPLEMENT (combine, deduplicate)
6. External is harmful/redundant?
   → YES: DROP (document rationale)
```

| Action | When | Result |
|--------|------|--------|
| **KEEP** | External is superior, no local equivalent | Use external version as-is or minimally adapted |
| **UPGRADE** | Valuable content, poor structure | Restructure to our format, preserve content |
| **ABSORB** | Domain expertise we lack, equivalent exists | Extract pattern, merge into our structure |
| **REWRITE** | Inferior to our templates | Build fresh using our standards + extracted patterns |
| **SUPPLEMENT** | Both have unique value | Union of both sources, deduplicated |
| **DROP** | Wrong, harmful, or fully redundant | Exclude entirely, document why |
| **INCOMPATIBLE** | Requires tools/infra we don't have | Flag in report, extract only portable patterns |

#### Step 3.3 — Apply Generalization Rules

Strip project-specific content using the same rules as `/template-push`:
- Replace hardcoded MCP prefixes with `mcp__{{service}}-.*__`
- Replace record/workflow/table/user/project IDs with `{{parameters}}`
- Remove specific URLs, timestamps, credentials
- Flag domain-specific terms that reduce portability

Reference: `ABSTRACTION_RULES.md` (skill-creator) for the full stripping/parameterization rules.

#### Step 3.4 — Align with Target Project

Read the target project's CLAUDE.md to match:
- Tech stack references
- MCP server names (so `allowed-tools` aligns)
- Naming conventions
- Existing skill ecosystem (avoid duplication)

If the merged skill references tools not in the target project, note in a compatibility section.

#### Step 3.5 — Generate Merged SKILL.md

**OVERWRITE GUARD**: If `output_dir` already exists, show the user what is currently at that path (skill name, version, line count) and require explicit confirmation before writing. Never silently overwrite an existing skill.

Produce the merged output following our standard structure:
1. Full frontmatter (all fields from our extended schema)
2. Executive summary (Tier 1)
3. Quick reference tables (Tier 2)
4. Phased execution or pattern documentation (Tier 3)
5. Anti-patterns table — combined from both sources (Tier 4)
6. Error handling table (Tier 4)
7. Defaults table with parameterized values (Tier 5)

Append audit metadata as HTML comment at the bottom:
```html
<!-- AUDIT METADATA
source: {{original_source_uri}}
source_hash: {{sha256}}
audit_date: {{YYYY-MM-DD}}
audit_grade: {{letter_grade}}
merge_actions: keep={{n}} upgrade={{n}} absorb={{n}} rewrite={{n}} supplement={{n}} drop={{n}} incompatible={{n}}
superior_patterns_absorbed: {{count}}
-->
```

#### Step 3.6 — Generate Evals

- If external had evals: validate format against our schema, keep valid ones, regenerate invalid
- If external lacked evals: generate 3-5 per our eval template
- Always include ≥1 `should_trigger=false` case
- Expectations must be hard to pass without the skill active

Reference: `references/schemas.md` (skill-creator) for eval JSON schema.

#### Step 3.7 — Mid-Build Validation Gate

Run validation immediately after generating SKILL.md (before evals):
```bash
bash .claude/skills/skill-creator/scripts/validate.sh .claude/skills/{{merged-name}}/
python3 .claude/skills/skill-creator/scripts/quick_validate.py .claude/skills/{{merged-name}}/
```
Auto-fix **structural issues in frontmatter only** (missing fields, incorrect types). For content issues flagged in prose or tables (e.g., regex false positives on words like `recommendation`, `user_id` in documentation), flag for manual review — do NOT auto-replace content in prose sections.

---

### Post-Completion

#### Step 4.1 — Final Validation

Re-run validation after evals are added. Same scoped auto-fix rule as Step 3.7: fix frontmatter only, flag prose content issues for manual review.
```bash
bash .claude/skills/skill-creator/scripts/validate.sh .claude/skills/{{merged-name}}/
python3 .claude/skills/skill-creator/scripts/quick_validate.py .claude/skills/{{merged-name}}/
```

#### Step 4.2 — Template Decision

| Condition | Action |
|-----------|--------|
| Project-agnostic AND no skill-creator dependency | Eligible for standalone `/template-push` |
| Project-agnostic BUT references skill-creator infra | Eligible only when skill-creator also present; add `requires: [skill-creator]` |
| Project-specific | Flag for manual `/update-latest` |

`auto_push` defaults to `false`. User explicitly opts in.

#### Step 4.3 — Output Diff Summary

```
MERGE DIFF SUMMARY
==================
Skill: {{merged_name}} (from {{original_name}})
Grade: {{before_grade}} → {{after_grade}}

KEPT FROM ORIGINAL:
  - [Section] {{name}} — {{why kept}}

UPGRADED TO OUR STANDARDS:
  - [Frontmatter] Added version, classification, parameters, validated_on
  - [Description] Rewritten: {{old_words}} words → {{new_words}} words
  - [Anti-Patterns] Restructured to Wrong/Why/Right table
  ...

NOVEL PATTERNS ABSORBED:
  - [{{category}}] {{pattern_name}} — {{description}}

DROPPED:
  - [Section] {{name}} — {{why dropped}}

INCOMPATIBLE (extracted portable patterns only):
  - [Section] {{name}} — requires {{missing_tool/infra}}

FILES PRODUCED:
  - .claude/skills/{{name}}/SKILL.md ({{lines}} lines)
  - .claude/skills/{{name}}/evals/evals.json ({{count}} evals)

POST-MERGE ACTIONS:
  - [ ] Run evals: python3 .claude/skills/skill-creator/scripts/run_eval.py --skill-path .claude/skills/{{name}}
  - [ ] Template push: {{eligible | not eligible (reason)}}
```

---

## Batch Mode

When `mode=batch`:

1. **Resolve**: Parse source to discover multiple skills (GitHub repo tree, directory glob)
2. **Audit all**: Run Phase 1 + Phase 2 for each skill sequentially
3. **Present summary**:
```
BATCH AUDIT SUMMARY
| # | Skill | Grade | Superior Patterns | Merge? |
|---|-------|-------|-------------------|--------|
| 1 | {{name}} | {{grade}} | {{count}} | Yes/Extract-only/Skip |
```
4. **Await approval**: Ask user which skills to merge
5. **Merge approved**: Run Phase 3 for each approved skill
6. **Batch limit**: If >10 skills discovered, process first 10, ask to continue

---

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| Merge without auditing first | May absorb harmful patterns blindly | Always complete Phase 2 before Phase 3 |
| Auto-merge batch without approval | User loses control over ecosystem | Present batch summary, wait for approval |
| Drop content because format is wrong | Format is fixable; content may be irreplaceable | Distinguish FORMAT deficiency (fix) vs CONTENT deficiency (drop) |
| Skip A.U.D.N. check before merging | Could overwrite established patterns | Always check for >70% concept overlap first |
| Push project-specific skill to template | Pollutes template with domain content | Check generalization flags before push |
| Score domain knowledge low because of format | Domain knowledge is valuable in any format | Score FOR-superior-patterns independently of format grade |
| Rewrite everything to our format | Destroys novel organizational patterns worth keeping | Use KEEP action where external structure is superior |
| Run validation only at the end | Structural issues compound through later phases | Mid-build validation gate at Step 3.7 |

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Source URL unreachable | Report error with details, suggest local clone or direct paste |
| No SKILL.md found at source | Look for README.md or any .md file; treat as raw content input |
| Frontmatter parse failure | Proceed with empty frontmatter scaffold, flag in audit report |
| External skill >500 lines | Audit but flag token-efficiency warning; recommend splitting in merge |
| validate.sh fails on merged output | Auto-fix common issues (hardcoded IDs, missing fields), re-run |
| Target project has no CLAUDE.md | Proceed without project alignment (Step 3.4), note in compatibility |
| Batch discovers >10 skills | Process first 10, report remainder, ask user to continue |
| External skill requires unavailable tools | Classify as INCOMPATIBLE, extract only portable patterns |

---

## Tests — Required Before Skill Ships

Behavioural acceptance tests for `skill-auditor-merger` itself. The skill prescribes eval generation for the skills it audits (Step 3.6); this block applies the same discipline to the skill that does the auditing. There is no automated harness for these — before any change to this skill ships, the editing agent MUST walk all seven tests below and state, in the change summary, which were re-verified and the observed result. A change that ships without that walk-and-state has skipped the gate.

### Test 1 — Happy path (ingest + dual-direction audit of a well-formed external skill)

**Input**: a readable, well-formed external `SKILL.md` supplied as a local path or pasted content (full frontmatter, ~300 lines, ≥3 evals); `mode` default (`merge`).

**Expected behaviour**: Phase 1 normalises the skill; Phase 2 produces a structured audit report with a 7-dimension standards score + weighted grade AND a separate FOR-superior-patterns list; Phase 3 pauses for explicit merge approval and is not auto-run.

**Verification**: the `STANDARDS AUDIT` table carries all 7 named dimensions, each with a numeric 0–10 score and a non-placeholder Weighted Total; the `SUPERIOR PATTERNS` section either lists ≥1 pattern or explicitly states none found; the report emits a `MERGE RECOMMENDATION` line and an explicit approval request; NO file is written under `output_dir` until the user approves.

### Test 2 — Audit-only mode stops before merge

**Input**: any external skill; `mode=audit-only`.

**Expected behaviour**: Phase 1 + Phase 2 run; the report is presented; Phase 3 (merge) does NOT run.

**Verification**: no merged artefact is written; the skill halts after Step 2.3 with the report as its terminal output.

### Test 3 — A.U.D.N. overlap is flagged, not silently overwritten

**Input**: an external skill whose keywords overlap >70% with an existing skill in `.claude/skills/`.

**Expected behaviour**: Phase 3 Step 3.1's A.U.D.N. check detects the overlap and surfaces it for an **ADD / UPDATE / DELETE / NOOP** decision (the four A.U.D.N. actions defined in Step 3.1); a >70% overlap routes to UPDATE — merge patterns into the existing skill — never a blind overwrite.

**Verification**: the overlap is named with the colliding existing skill; an explicit A.U.D.N. decision (one of ADD/UPDATE/DELETE/NOOP) is requested before any merge write; if `output_dir` already holds a skill, the Step 3.5 OVERWRITE GUARD fires and requires explicit confirmation before writing.

### Test 4 — Superior patterns surface from a low-grade skill

**Input**: an external skill that scores grade D or F on the standards audit but contains genuine novel domain knowledge.

**Expected behaviour**: Step 2.2 runs independently of the grade — the FOR-superior-patterns audit still documents the novel knowledge with an adopt / adapt / reference recommendation; the low grade does not suppress it.

**Verification**: the `SUPERIOR PATTERNS` section is non-empty despite the D/F grade; the grade and the superior-pattern list are reported as independent results.

### Test 5 — Batch limit holds

**Input**: `mode=batch` with a source that resolves to more than 10 skills.

**Expected behaviour**: the first 10 are audited; the remainder is reported; the skill asks the user before continuing — it does not silently process all of them or silently drop the overflow.

**Verification**: exactly 10 skills appear in the first batch summary; the remaining count is named; an explicit continue prompt is issued.

### Test 6 — A project-specific skill is not auto-pushed to the template

**Input**: an external skill that, after Step 3.3 generalization, still carries project-specific content (hardcoded MCP prefixes, table names, or domain terms that did not parameterise); `auto_push: true`.

**Expected behaviour**: Step 4.2's Template Decision classifies the merged skill `Project-specific` and routes it to a manual `/update-latest`. `auto_push: true` does NOT trigger a `/template-push` for a project-specific skill — this is the anti-pattern "Push project-specific skill to template" (highest-blast-radius behaviour: a wrong classification propagates domain pollution to every receiving repo).

**Verification**: no `/template-push` is invoked; the Step 4.3 diff summary's template line reads "not eligible — project-specific"; the surviving project-specific content that blocked eligibility is named.

### Test 7 — An unreadable source fails loud

**Input**: a source that cannot be resolved — a GitHub URL that returns 404, or a local path that does not exist.

**Expected behaviour**: per the Error Handling table, the skill reports the error with details and suggests a local clone or direct paste. It does NOT proceed into Phase 2 with empty or partial content, and does NOT emit an audit report built on nothing.

**Verification**: the terminal output is an explicit error naming the unreachable source; no `STANDARDS AUDIT` table and no merged artefact are produced.

---

*Skill Auditor & Merger v1.0 — Capability Uplift — requires: skill-creator*
*Session 10 refactor (2026-05-18, Synthesis Programme): added this Tests block (axis-6 self-verification fix) and the Step 2.1 non-commensurability note (axis-4 fix), per the Session 9 audit-the-skills loop finding (`council/audits/2026-05-18-audit-the-skills-loop.md` §2).*
