# Eval 05 — /ship Failure Passthrough

**Scenario:** `/ship pr` returns a non-zero exit code (e.g., exit 4 — smoke fail with auto-rollback). Autovibe must surface the remediation guidance from `failure-inventory.md` AND exit with the same exit code class — NOT mask the failure.

## Setup

To synthetically trigger a smoke failure, the simplest method is to:
- Open a PR via autovibe with a deliberate prod-breaking change (e.g., a frontend edit that kills the homepage)
- Let `/ship pr` deploy + run smoke
- Smoke detects the regression
- `/ship pr` fires `auto-rollback.sh` automatically (Phase C contract)
- `/ship pr` exits 4

For testing without real prod impact, run with `SHIP_DRYRUN=1` and mock the smoke result:
```bash
SHIP_DRYRUN=1 SHIP_MOCK_SMOKE_RESULT=fail bash .claude/skills/ship/modes/pr.md ...
```

(SHIP_MOCK_SMOKE_RESULT is a hypothetical test hook — verify it exists in the ship skill before running.)

## Expected Behavior

| Step | Expected |
|---|---|
| All prior phases | Run normally (preflight, plan, council, amend, execute, code-council pass) |
| `Skill ship` mode=pr | `/ship pr` invoked, runs through PR + CI + deploy + smoke |
| Smoke detects regression | `auto-rollback.sh` fires automatically (per ship Phase C confident cascade) |
| `/ship pr` exit code | 4 |
| Conversation reads `.claude/ship-state.json` | `exit_code: 4`, `current_step: "smoke_fail_rollback"`, `rollback_cmd: "git revert <sha>"` |
| Conversation surfaces | "Ship exit 4: smoke detected regression on <PR-url>; auto-rollback fired (commit: <revert-sha>)" |
| Conversation reads | `.claude/skills/ship/references/failure-inventory.md` for additional remediation steps |
| Conversation passes through | Exit autovibe with code 4 — DO NOT continue to post-ship doc step |
| `post-ship.sh 4 rollback` | Conversation MAY invoke this AFTER surfacing the failure (so the rollback is captured in audit trail) |
| Memory entry | YES — `memory/feedback_autovibe_<ts>-<slug>.md` with `MEMORY_REASON="auto-rollback fired"` |

## Pass Criteria

- [ ] Final autovibe exit code: 4 (matches `/ship pr` exit)
- [ ] Stderr surfaces "Ship exit 4" line + remediation excerpt from failure-inventory.md
- [ ] `.claude/autovibe-state.json` shows `exit_code: 4`, `phase: "failed"` or `"complete"` (depending on whether post-ship doc ran)
- [ ] `memory/feedback_autovibe_<ts>-<slug>.md` exists with rollback context
- [ ] PR on GitHub: status=MERGED (revert merged), with both the original commit AND the revert commit visible
- [ ] `git log --oneline -3` shows revert commit on top

## Failure Modes to Watch For

| Symptom | Likely cause |
|---|---|
| Autovibe exits 0 despite ship exit 4 | Conversation masked the failure — review modes/planned.md step 10 |
| No memory entry | post-ship.sh not invoked, OR `SHIP_SIGNAL=clean` passed instead of `rollback` |
| Remediation guidance missing | failure-inventory.md not read; modes/planned.md should reference it |
| Multiple rollback commits | autovibe re-invoked `/ship pr` after first failure — should NOT retry; halt and surface |

## Critical Distinction: Exit 4 vs Exit 9

`/ship` Phase C distinguishes between:
- **Exit 4**: Smoke detected real regression → auto-rollback fired (action taken)
- **Exit 9**: Smoke UNVERIFIABLE (no `x-vercel-git-commit-sha` header) → DO NOT rollback (no proof)

Autovibe must respect this distinction:
- Exit 4 → memory entry with rollback context
- Exit 9 → memory entry with "smoke unverifiable" context, PR may still be live, manual investigation required
