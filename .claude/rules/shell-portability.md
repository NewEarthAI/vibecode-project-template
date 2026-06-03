# Shell Portability & Exit-Code Hygiene

Concrete shell-scripting traps that produced real bugs during skill authoring. Applies to any `.sh` written in `.claude/skills/*/scripts/` or `.claude/hooks/`.

## 1. Pipes eat `$?`

```bash
cmd_that_can_fail 2>&1 | tail -3
echo $?      # <-- tail's exit (usually 0), NOT cmd_that_can_fail's
```

**Fix (pick one)**:
```bash
set -o pipefail              # script-wide: $? = rightmost non-zero in pipe
cmd | tail -3; rc=${PIPESTATUS[0]}   # bash: capture specific position
rc=$(cmd; echo $?)           # capture before piping
cmd > /tmp/out 2>&1; rc=$?; tail -3 /tmp/out   # run first, pipe after
```

During verification runs, prefer `bash script 2>/dev/null; echo "rc=$?"` (no pipe) when the exit code is what you're testing.

## 2. `grep -c PATTERN || echo 0` double-echoes

`grep -c` ALWAYS prints the count on stdout — including "0" on no-match — AND exits non-zero on no-match. The `||` fallback then prints another "0", giving you `"0\n0"` which breaks `[` integer comparisons downstream.

```bash
# WRONG — returns "0\n0" on no match
n=$(... | grep -c 'pat' || echo 0)
[ "$n" = "0" ]  # false, because "$n" is literally "0\n0"

# RIGHT
n=$(... | grep -c 'pat' 2>/dev/null); n=${n:-0}
# or
n=$(... | jq 'length' 2>/dev/null || echo 0)
# or bulletproof
n=$(printf '%s' "$n" | tr -dc '0-9' | head -c 3); n=${n:-0}
```

Real incident: `/ship`'s `detect-mode.sh` v1 used `gh pr list ... | grep -c '"number"' || echo 0` and every dirty tree misclassified as `ambiguous` until caught by dry-run.

## 3. macOS lacks `timeout` by default

`timeout` is GNU coreutils; macOS BSD userland doesn't ship it. Scripts that hardcode `timeout N cmd` die with `timeout: command not found` on fresh Macs.

**Portable template**:
```bash
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout $N"
elif command -v gtimeout >/dev/null 2>&1; then       # homebrew coreutils
  TIMEOUT_CMD="gtimeout $N"
else
  TIMEOUT_CMD=""                                      # fallback: no wrap
fi
$TIMEOUT_CMD cmd_here
```

For hard enforcement when no `timeout` exists, use the background-kill pattern:
```bash
( cmd_here ) & pid=$!
elapsed=0
while kill -0 "$pid" 2>/dev/null; do
  sleep 5; elapsed=$((elapsed+5))
  if [ "$elapsed" -ge "$N" ]; then
    kill -TERM "$pid" 2>/dev/null; sleep 2
    kill -KILL "$pid" 2>/dev/null
    exit 9   # distinct "timeout" code — never map to pass/fail
  fi
done
wait "$pid"
```

Canonical implementations in this repo: `.claude/skills/ship/scripts/preflight.sh` (`tsc --noEmit`) and `.claude/skills/ship/scripts/ci-watch.sh` (`gh pr checks --watch`).

## 4. `mkdir` is POSIX-atomic; JSON-write is not — use dir as lock primitive

File writes on APFS are NOT atomic across processes. Two concurrent `cat > lockfile.json` can interleave bytes. `mkdir` IS atomic (creates-or-fails, no race).

```bash
# WRONG — two sessions can both write and both think they acquired
if [ ! -f "$LOCK" ]; then cat > "$LOCK" <<EOF ... ; fi

# RIGHT — mkdir is atomic; success = acquired
if mkdir "$LOCK_DIR" 2>/dev/null; then
  # we acquired; write metadata file (not the lock itself)
  cat > "$METADATA" <<EOF ... EOF
else
  # lock held; inspect METADATA for owner info + TTL
fi
```

Also: bound the TTL on BOTH ends. Lower bound (10 min age → expire) handles crashed sessions; upper bound (60 min future-dated → treat as clock-skew corruption) handles NTP corrections that would otherwise produce permanent locks.

Canonical implementation: `.claude/skills/ship/scripts/lock.sh`.

## 5. Reserved variable names in zsh

Some names are read-only in zsh and will fail assignment with `read-only variable`:
- `status` (zsh builtin — exit status of last foreground command)
- `argv`, `pipestatus`, `histchars`, `LC_ALL` (in some contexts)

**Rule**: namespace your locals. Prefer `s_status`, `rc`, `count`, `n_lines` over bare `status`, `exit`, `count`, `lines`.

## 6. `set -e` + `[` + integer-expression errors

`[ "$var" -gt 0 ]` where `$var` is a non-integer (empty, whitespace, multi-line) doesn't FAIL loudly under `set -uo pipefail` — it evaluates to non-zero and control passes to the next branch. The error goes to stderr but the script continues silently.

**Defense**: normalize numerics BEFORE `[`:
```bash
n=$(printf '%s' "$n" | tr -dc '0-9' | head -c 10); n=${n:-0}
[ "$n" -gt 0 ] && ...
```

Or use arithmetic evaluation which is more forgiving:
```bash
(( n > 0 )) && ...   # still fails on non-numeric but noisily
```

## 7. Interactive-shell `grep` shim does NOT reach scripts and hooks

Claude Code's interactive Bash tool shell defines `grep` as a **shell function** that shims to a bundled `ugrep` binary (via `CLAUDE_CODE_EXECPATH`). Shell functions are NOT exported to child processes — a script invoked as `bash script.sh`, and every hook, runs the REAL system binary (`/usr/bin/grep` — BSD grep on macOS).

Consequence: a command tested interactively can behave differently when the same line runs inside a script or hook. The self-test you run by hand uses `ugrep`; the hook that depends on it uses BSD grep. Not the same program.

```bash
type grep              # interactive: "grep is a function ... exec -a ugrep"
bash -c 'type grep'    # child shell:  "grep is /usr/bin/grep"
```

**Rule for `--self-test` harnesses**: exercise the code path as a child `bash` process, never by pasting the script's internal command into an interactive shell. A test that passes interactively and fails in-script is a false positive, not a pass. To see what a script will actually see, prefix with `command grep` or run inside `bash -c`.

**Failure precedent (2026-05-19)**: the NewVibe continuation-verifier self-test reported `ALL PASS (10/10)` across multiple sessions while the verifier was broken — interactive runs hit `ugrep` (correct), the autofire hooks hit BSD grep (wrong). It surfaced only when the self-test ran as a child process.

## 8. Non-ASCII literals in regexes break under a non-UTF-8 locale

A raw multibyte character in a grep/sed pattern (e.g. `§`, bytes `0xC2 0xA7`) is locale-fragile. Under a UTF-8 locale BSD grep treats it as one character; under `C`/POSIX it treats each byte separately, so `§?` parses as "byte 0xC2, then optional byte 0xA7" — the 0xC2 becomes mandatory and the pattern matches nothing in plain ASCII text.

Claude Code's non-interactive shells inherit no `LANG`/`LC_*` and default to `C` — so any hook or script with a non-ASCII regex literal is exposed.

```bash
printf '## 1. x\n' > /tmp/t
/usr/bin/grep -cE '^## §?[0-9]+\. ' /tmp/t                    # → 0  (C locale)
LC_ALL=en_US.UTF-8 /usr/bin/grep -cE '^## §?[0-9]+\. ' /tmp/t # → 1
```

**Fix**: never put a raw non-ASCII char in a pattern. Use an ASCII-only equivalent — a byte-count-bounded bracket expression works in any locale:

```
WRONG — locale-fragile:  ^## §?[0-9]+\.
RIGHT — byte-safe:       ^## [^0-9 ]{0,2}[0-9]+\.
```

`[^0-9 ]{0,2}` accepts 0-2 non-digit non-space bytes before the number — covering both `## 8.` and `## §8.` regardless of locale.

**Failure precedent (2026-05-19)**: the NewVibe verifier's `§?` literal counted zero sections in every continuation under `C`, so every autofire dispatch silently skipped with `verifier-exit-4`. Fixed with the byte-safe bracket form.
