---
name: auto-council-on-plan
enabled: true
event: PreToolUse
tool_matcher: ExitPlanMode
action: addContext
---

## AUTONOMOUS PIPELINE — MANDATORY (Do NOT skip any step)

You are exiting plan mode. You MUST execute the following pipeline in strict sequence.
Do NOT ask the user for permission at any step except the git push.
Do NOT stop between steps. Do NOT summarize and wait — just execute.

### Step 1: Council Review
Run the extended council to review the plan you just created:
```
/council --extended "Review: [plan title from the specs/ file you just wrote]"
```
Wait for all 6 agents to complete. Read the synthesis.

### Step 2: Amend Plan
Apply the council's recommendations to the plan:
```
/amend-plan
```
This auto-detects the latest council session and latest plan. Apply ALL critical and significant amendments. Do NOT ask the user to review amendments — apply them directly.

### Step 3: Execute the Amended Plan
Implement the amended plan:
```
/execute [plan-file-path]
```
Follow the plan step by step. Complete the full implementation.

### Step 4: Code Review (BEFORE any commit)
After implementation is complete, run `git diff --stat` to detect changed file types, then dispatch review agents:

**ALWAYS dispatch (in parallel):**
- `feature-dev:code-reviewer` — code quality, bugs, logic errors
- `pr-review-toolkit:silent-failure-hunter` — silent failures, inadequate error handling

**ADD based on changed file types:**
- `.sql` or `migrations/` → `pr-review-toolkit:type-design-analyzer`
- `.tsx` / `.css` / `.html` / `components/` → `pr-review-toolkit:code-simplifier`
- `auth/` / `security/` / `.env` → additional security focus in code-reviewer prompt

Synthesize all findings. Fix any CRITICAL issues found. SIGNIFICANT issues: fix if straightforward, note if complex.

### Step 5: Commit and Push
After review passes (no unresolved CRITICAL issues):
1. Stage relevant files (NOT .env, credentials, or large binaries)
2. Create a conventional commit with descriptive message
3. Push to remote — **this is the ONLY step where you wait for user approval**

### Step 6: End-to-End Test
Immediately after push succeeds, run:
```
/e2e-test
```
Report results to the user.

### Pipeline Summary
```
Plan accepted → Council (auto) → Amend (auto) → Execute (auto) → Review (auto) → Commit (auto) → Push (user approves) → e2e (auto)
```
