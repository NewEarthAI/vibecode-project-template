---
description: Execute an implementation plan from specs/
argument-hint: [path-to-plan]
---

# Execute: Implement from Plan

## Plan to Execute
Read plan file: `$ARGUMENTS`

If no path provided, find the most recently modified file in `specs/` and use that.

## Execution Instructions

### 1. Read and Understand
- Read the ENTIRE plan carefully
- Understand all steps and their dependencies
- Note the validation commands to run
- Review the testing strategy
- Create a TodoWrite checklist from the plan's implementation steps

### 2. Execute Steps in Order
For EACH step in the implementation plan:

a. **Mark the step as in_progress** in the todo list
b. **Read the target files** before making changes (never edit from memory)
c. **Implement the step** — follow the plan's specs exactly, maintain existing patterns
d. **Verify as you go** — check syntax, imports, types, run the step's validation command if provided
e. **Mark the step as completed** in the todo list

If a step fails validation:
- Fix the issue before moving on
- Document what went wrong and how it was fixed
- Re-run the validation command to confirm the fix

### 3. Run Testing Strategy
After completing all implementation steps:
- Create any test files specified in the plan
- Implement all test cases mentioned
- Follow the testing approach outlined
- Ensure tests cover the edge cases listed

### 4. Run Validation Commands
Execute ALL validation commands from the plan in order.
If any command fails: fix the issue, re-run, continue only when it passes.

### 5. Final Verification
- All steps from the plan completed
- All tests created and passing
- All validation commands pass
- Code follows project conventions (check CLAUDE.md)
- No hookify rules bypassed (no SELECT *, no missing LIMIT, etc.)

### 6. ROADMAP Update
Check if any NOW items in `ROADMAP.md` were completed by this implementation.
If so, move them to the completed section or mark them done.

## Output Report
Provide a summary:
- **Completed Steps**: List with file paths modified/created
- **Tests Added**: Test files and results
- **Validation Results**: Pass/fail for each validation command
- **ROADMAP Changes**: Any items moved or marked complete
- **Ready for Commit**: Yes/No — if yes, suggest running `/commit`
