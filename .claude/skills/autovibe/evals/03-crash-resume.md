# Eval 03 — Crash Resume

**Scenario:** Autovibe is killed mid-`/execute`. Re-running it should detect the existing state file and resume from the last completed phase, NOT restart from scratch.

## Setup

```bash
cd ~/code/the app-autovibe
rm -rf .claude/autovibe-state.json .claude/autovibe-state.lock 2>/dev/null
```

## Run (Phase 1)

```
/autovibe "add a Supabase migration for buyer_preferences"
```

While the conversation is mid-`/execute` step (after plan + council + amend, during file writes):

```bash
# In another terminal — simulate crash
cat .claude/autovibe-state.json
# Expect: phase != "complete", current_step in {execute_pending, ...}

# Send SIGTERM to the orchestrator
pkill -TERM -f "autovibe/scripts/orchestrate"
# Expect: trap fires, lock released, state file LEFT IN PLACE
ls .claude/autovibe-state.lock 2>&1  # expect: directory NOT to exist
test -f .claude/autovibe-state.json && echo "state survived"
```

## Run (Phase 2 — resume)

```
/autovibe "add a Supabase migration for buyer_preferences"
```

## Expected Resume Behavior

| Step | Expected |
|---|---|
| `preflight.sh` | Exit 0 |
| `state.sh acquire` | Exit 0 (lock dir was released; state file survived) |
| `prime-lite/brief.sh` | Runs |
| Conversation reads state | Detects `phase != "initialized"`, `current_step == "execute_pending"` (or wherever crash hit) |
| Conversation logs | "Resuming autovibe from current_step=execute_pending" |
| Skip preceding phases | Forge, triage, plan, council, amend already done — DO NOT re-run |
| Resume from execute | Re-invoke `/execute` (idempotent — execute reads the existing plan) |
| Continue normally | code-council → ship → post-ship |

## Pass Criteria

- [ ] After SIGTERM: `.claude/autovibe-state.lock/` does NOT exist
- [ ] After SIGTERM: `.claude/autovibe-state.json` DOES exist with `phase != "complete"`
- [ ] On resume: NO duplicate plan file (same path as Phase 1)
- [ ] On resume: NO duplicate council session file
- [ ] On resume: skipped phases logged as "skipped (resume)"
- [ ] Final autovibe exit code: 0
- [ ] One PR merged at end (not two from a re-do)

## Failure Modes to Watch For

| Symptom | Likely cause |
|---|---|
| Lock dir survives SIGTERM | Trap not registered — check `trap 'cleanup' INT TERM EXIT` in orchestrate.sh |
| State file deleted | Another script `rm -rf`'d it; only `state.sh release` should touch state — and it preserves the file |
| Resume re-creates plan file | Conversation didn't read state before invoking writing-plans; modes/planned.md crash-resume section needs review |
| Resume opens duplicate PR | `/ship` invoked again from fresh context — should detect existing PR via `detect-mode.sh` |
