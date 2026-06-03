# Eval 02 — `/ship quick` from iCloud path → exit 6 redirect

**Mode**: quick (attempted)
**Scenario**: user invokes `/ship` from `~/Documents/GitHub/<repo>` (iCloud-synced) or any OneDrive/Dropbox/tmp path.
**Expected exit code**: 1 (from preflight) OR 6 (from path-check bubbled through; current impl exits 1 on preflight fail — see failure inventory A1)

## Pre-conditions

```bash
cd ~/Documents/GitHub/<repo>  # iCloud path (or any OneDrive/Dropbox/tmp variant)
```

## Invocation

```bash
/ship quick
```

## Expected flow

1. `detect-mode.sh` → likely `quick` (git state is irrelevant at this gate)
2. `preflight.sh` calls `path-check.sh "$PWD"` → path-check emits:
   ```
   UNSAFE: /Users/justin/Documents/GitHub/<repo> is inside iCloud-synced Documents/GitHub/
   REDIRECT: git worktree add ~/code/<repo-slug> <branch>
   ```
   Exit 1.
3. preflight echoes path-check output + `preflight: path-check failed (exit 6 class)` → exit 1
4. `/ship` halts BEFORE any `lock.sh acquire` or git mutation.

## Expected output

Stderr:
```
UNSAFE: /Users/justin/Documents/GitHub/<repo> is inside iCloud-synced Documents/GitHub/
REDIRECT: git worktree add ~/code/<repo-slug> <branch>
preflight: path-check failed (exit 6 class)
```

Exit code: 1 (preflight blocker).

## Post-conditions (verify before claiming eval pass)

```bash
ls .claude/ship-state.lock/ 2>/dev/null   # should NOT exist (never acquired)
git status --porcelain                    # UNCHANGED from pre-invocation
git log -1                                # UNCHANGED from pre-invocation
```

No mutation occurred. No lock held. User has a copy-pastable redirect.

## Variants

- OneDrive: cd to any `~/OneDrive*` path → same redirect logic
- Dropbox: cd to any `~/Dropbox*` path → same redirect logic
- `/tmp/foo`: tmpfs detected → redirect to `~/code/foo`
- Unknown non-iCloud path (e.g. `~/Desktop/test-repo`): path-check emits WARN on stderr but exits 0 (proceeds with warning, not a hard block)
