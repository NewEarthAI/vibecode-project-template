# Eval 02 — Planned Mode (Medium Feature)

**Scenario:** Substantive feature work — autovibe routes through plan + council + amend + execute + code-council + `/ship pr`.

## Setup

```bash
# Fresh worktree off main, no uncommitted changes
cd ~/code/buybox-autovibe
git status --porcelain  # should be empty
```

## Run

```
/autovibe "add a Supabase migration for new buyer_preferences table with RLS"
```

## Expected Behavior

| Step | Expected |
|---|---|
| `preflight.sh` | Exit 0 |
| `state.sh acquire` | Exit 0 |
| `prime-lite/brief.sh` | Runs |
| Forge gate | Skipped (intent has verb "add" + object "table" + prep "for", >8 words) |
| `triage.sh "add a Supabase migration..."` | stdout `plan`, stderr "intent mentions database migration or RLS" |
| Mode dispatch | `modes/planned.md` |
| Conversation enters plan mode | EnterPlanMode invoked |
| `superpowers:writing-plans` | Plan written to `/Users/justin/.claude/plans/<slug>.md` |
| `/council --extended` | Council session at `council/sessions/<date>-<slug>.md` |
| `/amend-plan` | Plan updated with council verdicts |
| ExitPlanMode | Auto-accept (cascade authorization) |
| `/execute` | Migration SQL written, types regenerated |
| `/code-council` | Verdict PASS or ADVISORY (not BLOCKING) |
| `Skill ship` mode=pr | `/ship pr` runs |
| `/ship pr` | Exit 0, PR opened + merged + smoke pass |
| `post-ship.sh 0 clean` | Session log + (likely) NO memory entry on clean ship |

## Pass Criteria

- [ ] Final autovibe exit code: 0
- [ ] Plan file exists at `~/.claude/plans/<slug>.md`
- [ ] Council session file exists at `council/sessions/<date>-<slug>.md`
- [ ] PR was opened, merged, and `gh pr view <num>` shows status: MERGED
- [ ] `.claude/ship-state.json` shows `exit_code: 0`, `current_step: "complete"`
- [ ] `.claude/autovibe-sessions/<ts>-<uuid>.md` references the PR number
- [ ] If smoke triggered rollback or admin-merge: memory entry written

## Failure Modes to Watch For

| Symptom | Likely cause |
|---|---|
| Triage returns `direct` | Intent keyword "migration" or "rls" missed by triage regex — check `triage.sh` |
| Council verdict BLOCKING | Reframer suggested reframing — surface to user, do not auto-proceed |
| Code-council verdict BLOCKING | Real issue with implementation — halt, surface, exit 3 |
| `/ship pr` exit 4 (smoke fail) | Auto-rollback fired — captured in memory; review `memory/feedback_autovibe_*.md` |
