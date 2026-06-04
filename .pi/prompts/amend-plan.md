---
description: "Amend a plan with council recommendations — bridges /council output to plan edits"
argument-hint: [council-session-path] [plan-path]
---

# /amend-plan — Apply Council Recommendations to Plan

## Inputs

1. **Council session file**: `$ARGUMENTS` first arg, or auto-detect latest from `council/sessions/`
2. **Plan file**: `$ARGUMENTS` second arg, or auto-detect latest from `specs/`

If no arguments provided, find the most recently modified file in each directory.

## Process

### Step 1: Read Council Synthesis (targeted — not full file)

Read the council session file. Extract ONLY:
- The **Synthesis** section (consensus, divergence, recommendation)
- Any items marked **CRITICAL** or **SIGNIFICANT**
- The confidence spread

Do NOT re-read full agent reports — the synthesis already distills them.

### Step 2: Read Current Plan

Read the plan file from `specs/`. Note its structure and existing sections.

### Step 3: Classify Recommendations

For each council recommendation, classify:

| Priority | Action | Example |
|----------|--------|---------|
| CRITICAL | Must amend — plan would fail without this | Missing error handling, wrong architecture |
| SIGNIFICANT | Should amend — meaningfully improves plan | Better approach, missed edge case |
| MINOR | Note only — add as comment, don't restructure | Style preference, future consideration |

### Step 4: Apply Amendments

For each CRITICAL and SIGNIFICANT recommendation:

1. Find the relevant section in the plan
2. Insert the amendment with a clear marker:
   ```
   > [COUNCIL AMENDMENT — CRITICAL] Description of change
   > Rationale: Why this was flagged
   > Original: What the plan said before (if changed)
   ```
3. Update any affected verification steps, risk tables, or file lists

For MINOR recommendations:
- Add a `## Council Notes` section at the bottom with bullet points
- Do not modify the plan body

### Step 5: Update Plan Metadata

Add to the plan's header or metadata:
```
**Council reviewed**: [date] | Session: [filename]
**Amendments**: X critical, Y significant, Z minor notes
```

### Step 6: Save

Save the amended plan in place (same path). Do NOT create a new file.

## Output

Report to the user:
- Number of amendments by priority (CRITICAL / SIGNIFICANT / MINOR)
- Summary of each CRITICAL amendment (one line each)
- Whether any recommendations were REJECTED and why
- Confirm the plan path was updated

## Constraints

- Never fabricate council recommendations — only use what's in the session file
- Never remove existing plan content — only add amendments and notes
- Keep amendment markers machine-readable for future tooling
- If council and plan disagree on approach, flag the conflict — don't silently override
