# /autovibe Invocation Contract

## Inputs

| Form | Example | Notes |
|---|---|---|
| Required positional | `"<intent string>"` | One sentence describing what to ship |
| Env var `AUTOVIBE_DRYRUN` | `1` | Print every command, execute none, exit 0 |
| Env var `AUTOVIBE_FORMAT` | `json\|prose` | Stdout serializer (default: prose to stderr) |

## Output Shapes

### Prose (default)

To stderr, one line per phase:
```
[autovibe:preflight] running — checking path/disk/locks/auth
[autovibe:preflight] pass —
[autovibe:lock] acquired —
[autovibe:prime] done — briefing at /tmp/autovibe-prime-12345.md
[autovibe:forge] skipped — intent is specific enough
[autovibe:triage] plan — diff touches Supabase migration/function/SQL
[autovibe:mode] dispatch — branch=plan, ship-mode=pr, doc=...modes/planned.md
[autovibe:handoff] ready — calling session must compose: see modes/planned.md
```

Stdout: empty (all output goes to stderr in prose mode for clean piping).

### JSON (`AUTOVIBE_FORMAT=json`)

To stdout, one JSON object per line:
```json
{"phase":"preflight","status":"running","detail":"checking path/disk/locks/auth","ts":"2026-04-19T..."}
{"phase":"preflight","status":"pass","detail":"","ts":"..."}
{"phase":"lock","status":"acquired","detail":"","ts":"..."}
{"phase":"triage","status":"plan","detail":"diff touches Supabase migration/function/SQL","ts":"..."}
```

Each line is independently parseable JSON. Consumer streams `stdout` line-by-line.

## Exit Codes

See `SKILL.md §Exit Codes` for the table. Stable contract.

## State File (`.claude/autovibe-state.json`)

Schema in `SKILL.md §Lock Contract`. Programmatic callers read fields between turns:

```bash
# Get current phase
phase=$(bash .claude/skills/autovibe/scripts/state.sh read phase)

# Get artifacts (PR number, merged sha)
pr=$(bash .claude/skills/autovibe/scripts/state.sh read pr_number)
sha=$(bash .claude/skills/autovibe/scripts/state.sh read merged_sha)
```

## Lock Contract

- Acquired via atomic `mkdir .claude/autovibe-state.lock/`
- Released via `rmdir` (state.sh release) — fired by trap on INT/TERM/EXIT
- TTL: 30 min — past TTL, next invocation reclaims
- Future-tolerance: 60 min — past that = clock skew = exit 6
- One autovibe per repo at a time. Two autovibes = second exits 5

## Composed-Skill Contract

The `orchestrate.sh` shell script handles preflight + triage + state. The CONVERSATION (this skill running in a Claude Code session) handles composed-skill invocations because skills require conversation context.

After `orchestrate.sh` returns 0 with mode dispatched, the calling session reads the appropriate `modes/*.md` and invokes:

| Trigger | Skill / Command | Notes |
|---|---|---|
| `state.current_step == "forge_needed"` | `Skill prompt-forge` | Refines intent |
| Always (planned mode) | `EnterPlanMode` (system) | Plan mode active |
| Always (planned mode) | `Skill superpowers:writing-plans` | Produces plan file |
| Always (planned mode) | `/council --extended` | Full deliberation |
| Always (planned mode) | `/amend-plan` | Apply council |
| Always (planned mode) | `ExitPlanMode` (system) | Auto-accept amended |
| Always (both modes) | `/execute` | Implements |
| Planned mode only | `/code-council` | Pre-push diff review |
| Always | `Skill ship` (mode=quick or pr) | The actual ship |
| Always (after ship 0) | post-push doc step | Per SKILL.md §4 |

## Guarantees

- **Preflight always runs** — no "trust caller" shortcut
- **Lock always trapped** — no zombie locks from ^C
- **Hotfix never auto-invoked** — exit 9 if conditions detected
- **Composed-skill output passes through unchanged** — autovibe doesn't mask /ship's failure messages

## Anti-Guarantees (NOT promised)

- Resume from arbitrary phase boundaries — only the phase boundaries listed in `modes/planned.md` §Crash-Resume
- Multi-repo orchestration — autovibe is single-repo per invocation
- Memory of past autovibe runs informing future decisions — that's a v2 feature
