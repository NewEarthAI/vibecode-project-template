# Eval 04 — Lock Collision

**Scenario:** Two `/autovibe` invocations on the same repo. The second must halt cleanly with exit 5, NOT corrupt state, NOT proceed.

## Setup

```bash
cd ~/code/buybox-autovibe
rm -rf .claude/autovibe-state.json .claude/autovibe-state.lock 2>/dev/null
```

## Run

```bash
# Terminal 1: start a long-running autovibe
/autovibe "add a Supabase migration for buyer_preferences"
# (let this reach plan / council step — it'll run for several minutes)

# Terminal 2: try a second autovibe immediately
/autovibe "fix typo in README"
```

## Expected Behavior — Terminal 2 (second autovibe)

| Step | Expected |
|---|---|
| `preflight.sh` | Exit 0 (preflight is per-cwd, not lock-aware) |
| `state.sh acquire` | Exit 5 — lock held by terminal 1 |
| Stderr message | "state: another /autovibe session (uuid: <T1-uuid>, phase: <T1-phase>) is active (started <ts>, age <N>min)" |
| Stderr message includes | "Wait or: rm -rf $LOCK_DIR $STATE_FILE  (only if you're sure the other session crashed)" |
| Final exit code | 5 |
| Side effects | NONE — no state mutation, no commit, no push, no PR |

## Pass Criteria

- [ ] Terminal 2 exits with code 5 within 1 second of invocation
- [ ] Terminal 2's stderr explicitly identifies terminal 1's session_uuid + phase
- [ ] Terminal 2's stderr suggests both wait + override commands
- [ ] `.claude/autovibe-state.json` after collision matches terminal 1's session UUID (not overwritten)
- [ ] Terminal 1 continues normally — collision didn't disturb it
- [ ] After terminal 1 completes (exit 0), terminal 3 with `/autovibe ...` succeeds (lock released)

## Failure Modes to Watch For

| Symptom | Likely cause |
|---|---|
| Terminal 2 proceeds | `state.sh acquire` not called; check orchestrate.sh order |
| Terminal 2 corrupts state file | Acquire wrote to file before checking lock — should NEVER happen because mkdir is the lock primitive |
| Terminal 2 hangs | Acquire is retrying forever — should fail-fast with exit 5 |
| Terminal 1 affected | mkdir collision shouldn't touch terminal 1's state — check for accidental shared lock dir name |

## Note on TTL

If a stale lock is >30 minutes old, terminal 2 will automatically reclaim it (via TTL takeover in `state.sh acquire`). For this eval, ensure terminal 1's state is fresh (<30 min) when terminal 2 starts.
