# Eval 01 — Direct Mode (Typo)

**Scenario:** Trivial typo fix — autovibe should route through direct mode + `/ship quick`, no PR ceremony.

## Setup

```bash
# In a healthy worktree off main, single-line fix in a *.md file
cd ~/code/buybox-autovibe
echo "fix" >> README.md  # synthetic 1-line change
git add README.md
```

## Run

```
/autovibe "fix typo in README"
```

## Expected Behavior

| Step | Expected |
|---|---|
| `preflight.sh` | Exit 0, all gates pass |
| `state.sh acquire` | Exit 0, lock acquired |
| `prime-lite/brief.sh` | Runs, briefing written to /tmp |
| `forge` gate | Skipped (clear short intent: verb "fix" + object "typo" + prep "in") |
| `triage.sh "fix typo in README"` | stdout `direct`, stderr "trivial typo/comment/console.log change" |
| Mode dispatch | `modes/direct.md` |
| Conversation invokes | `Skill ship` mode=quick → `/ship quick --format=json --caller=autovibe` |
| `/ship quick` | Exit 0, commit + push to feature branch |
| `post-ship.sh 0 clean` | Session log written, NO memory entry |

## Pass Criteria

- [ ] Final autovibe exit code: 0
- [ ] `.claude/autovibe-sessions/<ts>-<uuid>.md` exists with single session entry
- [ ] `find memory -name "feedback_autovibe_*.md"` returns nothing (clean ship → no memory)
- [ ] `git log --oneline -1` shows the typo commit pushed
- [ ] No PR opened (quick mode, no pr_number in state)
- [ ] `.claude/autovibe-state.lock/` cleaned up (trap fired)

## Failure Modes to Watch For

| Symptom | Likely cause |
|---|---|
| Triage returns `plan` instead of `direct` | Diff in working tree includes >1 file or non-`*.md` file |
| Forge fires unexpectedly | Intent regex changed; check `orchestrate.sh` forge gate |
| `/ship quick` opens a PR | `detect-mode.sh` saw an open PR for the branch — should not happen on a fresh feature branch |
