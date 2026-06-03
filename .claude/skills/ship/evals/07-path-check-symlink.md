# Eval 07 — `path-check.sh` A5: `~/code/` itself a symlink into iCloud

**Mode**: any (path-check is invoked from `preflight.sh` for every mode)
**Scenario**: user has symlinked `~/code` → `~/Documents/GitHub/` (or any cloud-synced dir) for convenience, then runs `/ship` from `~/code/<repo>`. The naive `pwd -P` resolution would correctly resolve to the iCloud-poisoned real path and trigger the standard A1 redirect — but the dedicated A5 branch fires *first* with a symlink-specific recovery message.
**Expected exit code**: 1 (path-check halts; preflight bubbles up exit 1)

## Pre-conditions (test setup)

```bash
# Reproduce the wolf-in-sheep's-clothing case: ~/code is a symlink to iCloud
mv ~/code ~/code.bak 2>/dev/null || true
ln -s ~/Documents/GitHub ~/code              # ← the dangerous setup
cd ~/code/<repo>                              # appears to be in safe path
```

## Invocation

```bash
bash .claude/skills/ship/scripts/path-check.sh "$PWD"
```

## Expected flow

1. `path-check.sh` enters the A5 branch FIRST (the `[ -L "$HOME/code" ]` check at lines 18–28 runs before the per-target case statement).
2. `readlink "$HOME/code"` returns `/Users/<user>/Documents/GitHub`.
3. The case-pattern match fires on `*/Documents/GitHub/*` substring.
4. Exit 1.

## Expected output

Stderr (or stdout, depending on shell):
```
UNSAFE: ~/code is itself a symlink to /Users/<user>/Documents/GitHub (cloud-synced)
REDIRECT: remove the symlink and use a real directory: rm ~/code && mkdir ~/code
```

Exit code: **1**

## Distinguishing A5 from A1

The two branches emit DIFFERENT recovery messages, on purpose:

| Failure mode | Trigger | Recovery message |
|---|---|---|
| **A1** (`$PWD` is in iCloud) | path-check called from a cwd matching `*/Documents/GitHub/*` directly | `git worktree add ~/code/<repo>-<slug> <branch>` |
| **A5** (`~/code` is itself a symlink to iCloud) | `[ -L "$HOME/code" ]` returns true AND target matches a synced pattern | `rm ~/code && mkdir ~/code` |

Eval 07 specifically asserts the A5 message, NOT the A1 message — they serve different remediations. A1 says "use a different worktree path"; A5 says "fix your home dir setup."

## Cleanup (always run after test)

```bash
rm ~/code         # remove the test symlink
mv ~/code.bak ~/code 2>/dev/null || mkdir ~/code   # restore real ~/code
```

## Why this matters

`pwd -P` correctly resolves the cwd to the real iCloud path, which would trigger A1's "use ~/code" redirect — pointing the user at the broken symlink as the "safe" destination. Without the A5 check, the user follows A1's instructions and ends up back in iCloud under a different name, never realizing `~/code` itself is the problem. Eval 07 ensures the dedicated detection-and-distinct-message survives any future refactor of `path-check.sh`.

## Variants (counter-scenarios)

### 7a. `~/code` is a symlink to a NON-synced location (e.g., `/Volumes/dev`)
```bash
ln -s /Volumes/dev ~/code
cd ~/code/<repo>
bash path-check.sh "$PWD"
# Expected: exit 0 (not synced; case statement falls through to the safe ~/code path)
```

### 7b. `~/code` is a regular directory (control case)
```bash
# Default state — no symlink
bash path-check.sh ~/code/<repo>
# Expected: exit 0; A5 branch is skipped because `[ -L "$HOME/code" ]` is false
```

### 7c. `~/code` is a broken symlink (target deleted)
```bash
ln -s /nonexistent ~/code
bash path-check.sh "$PWD"
# Expected: readlink succeeds (returns /nonexistent), case statement falls through,
# exit 0 with WARN on stderr about non-~/code/ path. Acceptable — user will see the
# WARN and the next git op will fail, surfacing the broken setup naturally.
```
