# Eval 01 — Budget Compliance

**Skill:** `prime-lite`
**What this eval verifies:** the briefing script stays within its declared budget (≤1500 words AND ≤3 seconds wall clock).

## Setup

Run from a healthy git repo with `specs/`, `council/sessions/`, and a non-trivial git history.

## Run

```bash
cd /Users/justin/code/buybox-autovibe
START=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
WORDS=$(bash .claude/skills/prime-lite/scripts/brief.sh | wc -w | tr -d ' ')
END=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
ELAPSED_MS=$((END - START))
echo "words=$WORDS elapsed_ms=$ELAPSED_MS"
```

## Expected

- `WORDS` ≤ 1500
- `ELAPSED_MS` ≤ 3000

## Pass Criteria

Both conditions true. If either fails:

| Failure | Likely cause | Fix |
|---|---|---|
| Words > 1500 | ROADMAP NOW section grew past 30 lines, or git log/status is huge | Tighten `TRUNC_LIMIT` in `brief.sh`, or add second-pass `head` to ROADMAP block |
| Elapsed > 3000ms | Slow `git status` (large worktree), slow disk, or hot-cache miss | Profile each section with `time`; consider parallel `&` then `wait` |

## Status

Last verified: 2026-04-19 — seed run on this worktree.
