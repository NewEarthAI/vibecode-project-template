# Eval 06 — Lock parallel-safety

**Mode**: any (lock behavior is cross-mode)
**Scenarios**: validate that the mkdir-atomic lock correctly serializes same-commit/same-PR ships while allowing different-commit ships to proceed in parallel.
**Expected exit codes**: 0 for first acquirer, 5 for contending same-commit, 0 for different-commit in parallel

## Scenario 6a: Same-commit collision (expect exit 5)

Terminal A:
```bash
cd ~/code/<repo>-wt-a
bash .claude/skills/ship/scripts/lock.sh acquire abc1234567890 42
echo "A exit=$?"           # 0
```

Terminal B (within 10 minutes):
```bash
cd ~/code/<repo>-wt-b
bash .claude/skills/ship/scripts/lock.sh acquire abc1234567890 42 2>&1
echo "B exit=$?"           # 5
# stderr message enumerates the holding session's uuid + step + started_at
# + copy-pastable `rm -rf` recovery command
```

Terminal A:
```bash
bash .claude/skills/ship/scripts/lock.sh release
echo "A exit=$?"           # 0
```

Terminal B (re-attempt after A releases):
```bash
bash .claude/skills/ship/scripts/lock.sh acquire abc1234567890 42
echo "B exit=$?"           # 0 (now acquires)
bash .claude/skills/ship/scripts/lock.sh release
```

## Scenario 6b: Different-commit parallel (expect both exit 0)

Terminal A:
```bash
bash .claude/skills/ship/scripts/lock.sh acquire aaaaaaaaaaaa
echo "A exit=$?"           # 0  → creates .claude/ship-state.lock/ + ship-state.json
```

Terminal B:
```bash
bash .claude/skills/ship/scripts/lock.sh acquire bbbbbbbbbbbb
echo "B exit=$?"           # 0  → creates .claude/ship-state.lock-bbbbbbbb/ + ship-state-bbbbbbbb.json
```

Both succeed; state is segregated. Verify:
```bash
ls .claude/ship-state*.json .claude/ship-state.lock* 2>/dev/null
# Expected:
#   .claude/ship-state.json
#   .claude/ship-state.lock/
#   .claude/ship-state-bbbbbbbb.json
#   .claude/ship-state.lock-bbbbbbbb/
```

Cleanup:
```bash
bash .claude/skills/ship/scripts/lock.sh release
# Primary + all sha-suffixed sidecars cleaned if >15min old (this eval tests them fresh,
# so manual cleanup for next run)
rm -f .claude/ship-state*.json
rm -rf .claude/ship-state.lock*
```

## Scenario 6c: Corrupt state file (expect exit 6)

```bash
mkdir -p .claude/ship-state.lock
echo "not valid json {{" > .claude/ship-state.json
bash .claude/skills/ship/scripts/lock.sh acquire abc 2>&1
echo "exit=$?"             # 6
# stderr: "state file missing required fields — corrupt; inspect $STATE_FILE before removing"
# cleanup:
rm -rf .claude/ship-state.lock .claude/ship-state.json
```

## Scenario 6d: Future-dated started_at (expect exit 6)

```bash
# Fabricate a lock with a started_at 2 hours in the future
mkdir -p .claude/ship-state.lock
future_ts=$(python3 -c "import datetime; print((datetime.datetime.utcnow() + datetime.timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
cat > .claude/ship-state.json <<EOF
{"pr_number": null, "session_uuid": "fake", "caller": "human", "started_at": "$future_ts", "current_step": "prechecks", "commit_sha": "abc", "completed_at": null, "exit_code": null}
EOF
bash .claude/skills/ship/scripts/lock.sh acquire abc 2>&1
echo "exit=$?"             # 6
# stderr: "started_at ... is more than 60min in the future — likely clock skew"
#         + "run: rm -rf .claude/ship-state.lock .claude/ship-state.json"
rm -rf .claude/ship-state.lock .claude/ship-state.json
```

## Scenario 6e: Expired TTL (expect exit 0, with auto-takeover)

```bash
# Fabricate a lock 15 minutes old
mkdir -p .claude/ship-state.lock
old_ts=$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(minutes=15)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
cat > .claude/ship-state.json <<EOF
{"pr_number": null, "session_uuid": "fake", "caller": "human", "started_at": "$old_ts", "current_step": "push", "commit_sha": "old", "completed_at": null, "exit_code": null}
EOF
bash .claude/skills/ship/scripts/lock.sh acquire newsha 2>&1
echo "exit=$?"             # 0 — TTL expired, auto-taken-over, new state file written
cat .claude/ship-state.json | jq '.commit_sha'  # "newsha"
bash .claude/skills/ship/scripts/lock.sh release
```

## Why these scenarios

- **6a** proves the atomic mkdir primitive works (council DevAdvocate 92% concern)
- **6b** proves different-commit parallelism works (Pragmatist concern: lock must not serialize all 12 worktrees)
- **6c** proves corrupt JSON doesn't silently bypass (EdgeCaseFinder A6 / C3)
- **6d** proves future-clock-skew doesn't permanent-lock (EdgeCaseFinder C1)
- **6e** proves 10-min TTL correctly auto-clears crashed sessions
