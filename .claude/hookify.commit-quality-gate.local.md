---
name: commit-quality-gate
enabled: true
event: PreToolUse
tool_matcher: Bash
action: addContext
---

# Pre-Commit Quality Gate (Fires on Bash — Skip If Not git commit)

**Quick check**: Does this Bash command contain `git commit`? If NO → ignore this entirely.

**If YES** → Before committing, verify:

1. **Build passes**: Has `npm run build` (or equivalent) run successfully since the last code change? If not, run it now. A broken build should never be committed.
2. **Debug artifacts removed**: `commit-guardian.sh` hard-blocks `console.log`/`debugger`/`TODO-REMOVE` in staged files, but also check for:
   - Commented-out code blocks that should be deleted (not just commented)
   - Hardcoded test values (localhost URLs, test API keys, placeholder strings)
3. **Commit message quality**: Does the message describe the WHY, not just the WHAT? "Fix bug" is insufficient. "Fix disposition select portal conflict in nested sheet" is useful.
4. **Scope check**: Are ONLY the intended files staged? Run `git diff --cached --stat` mentally. No accidental inclusions?

**If any check fails**: Fix before committing. Do not use `--no-verify`.
