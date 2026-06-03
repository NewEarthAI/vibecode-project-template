#!/usr/bin/env bash
# self-test.sh — verifies is-enabled.sh toggle behaviour (code-council 2026-05-22 item I)
#
# Covers 7 base cases (V1.0 toggle contract) + extended cases (V1.1 refactor:
# whitespace trim, case-insensitivity, precedence, exit-2-vs-exit-3 split, audit log,
# jq false-trap, empty-string env, null/empty settings).
#
# CRITICAL (shell-portability.md rule 7): every case runs is-enabled.sh as a CHILD
# bash process with a controlled HOME and CWD. The script under test is exercised
# exactly as the SKILL.md case block invokes it — never by sourcing it into this shell.
# The child runs under `env -i` (clean environment) so the operator's own exported
# NEWEARTH_SECURITY_ENABLED cannot contaminate the "no signal" cases — i.e. the suite
# is reliable even when run while the toggle is disabled in the caller's shell.
#
# Exit: 0 = all pass, 1 = one or more fail.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/is-enabled.sh"
PASS=0
FAIL=0

# Disposable sandbox: a real git repo (so `git rev-parse --show-toplevel` resolves to
# it) + a fake HOME holding settings.local.json. Cleaned up on exit.
SANDBOX="$(mktemp -d)"
FAKE_HOME="$SANDBOX/home"
REPO="$SANDBOX/repo"
mkdir -p "$FAKE_HOME/.claude" "$REPO/.claude"
git -C "$REPO" init -q
trap 'rm -rf "$SANDBOX"' EXIT

# run <expected_rc> <description> -- runs SCRIPT in REPO with env from the caller.
# Resets per-case state (FS flag + settings file) before the caller sets it up.
run() {
  local expected="$1"; shift
  local desc="$1"; shift
  local actual
  # env -i = clean slate (no inherited NEWEARTH_SECURITY_ENABLED); re-inject PATH so bash
  # + jq + git remain findable, plus the per-case assignments in "$@".
  ( cd "$REPO" && env -i HOME="$FAKE_HOME" PATH="$PATH" "$@" bash "$SCRIPT" ) >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS+1)); printf '  [PASS] %s (exit %s)\n' "$desc" "$actual"
  else
    FAIL=$((FAIL+1)); printf '  [FAIL] %s — expected %s, got %s\n' "$desc" "$expected" "$actual"
  fi
}

reset_state() {
  rm -f "$REPO/.claude/newearth-security.disabled"
  rm -f "$FAKE_HOME/.claude/settings.local.json"
}

echo "── base cases (V1.0 contract) ──"
reset_state
run 0 "1. no signal anywhere → ENABLED"
run 1 "2. env=0 → DISABLED" NEWEARTH_SECURITY_ENABLED=0
run 0 "3. env=1 → ENABLED" NEWEARTH_SECURITY_ENABLED=1
run 2 "4. env=garbage → INDETERMINATE" NEWEARTH_SECURITY_ENABLED=maybe

reset_state; touch "$REPO/.claude/newearth-security.disabled"
run 1 "5. FS flag present → DISABLED"

reset_state; printf '{"newearth_security_enabled": false}\n' > "$FAKE_HOME/.claude/settings.local.json"
run 1 "6. settings false → DISABLED"

reset_state; printf '{"newearth_security_enabled": true}\n' > "$FAKE_HOME/.claude/settings.local.json"
run 0 "7. settings true → ENABLED"

echo "── extended cases (V1.1 refactor) ──"
reset_state
run 1 "8. env=false (word) → DISABLED" NEWEARTH_SECURITY_ENABLED=false
run 1 "9. env=disabled → DISABLED" NEWEARTH_SECURITY_ENABLED=disabled
run 1 "10. env=' 0 ' (whitespace-padded) → DISABLED" NEWEARTH_SECURITY_ENABLED=' 0 '
run 0 "11. env=ON (uppercase) → ENABLED" NEWEARTH_SECURITY_ENABLED=ON

# Set-but-empty env var must be treated as ABSENT (fall through), NOT indeterminate.
# Guards the load-bearing empty-check in check_env against a future "simplification".
run 0 "11b. env='' (set but empty) → absent → ENABLED" NEWEARTH_SECURITY_ENABLED=""

# Precedence: env enable beats FS disable flag.
reset_state; touch "$REPO/.claude/newearth-security.disabled"
run 0 "12. env=1 overrides FS flag → ENABLED" NEWEARTH_SECURITY_ENABLED=1

# jq false-trap: key absent → enabled default (NOT mistaken for false).
reset_state; printf '{"some_other_key": 5}\n' > "$FAKE_HOME/.claude/settings.local.json"
run 0 "13. settings key absent → ENABLED"

# JSON null → no Layer-3 opinion → absent → ENABLED (not a disable signal, must not HALT).
reset_state; printf '{"newearth_security_enabled": null}\n' > "$FAKE_HOME/.claude/settings.local.json"
run 0 "13b. settings null → absent → ENABLED"

# Empty settings file → jq emits nothing → absent → ENABLED (must not HALT at exit 2).
reset_state; : > "$FAKE_HOME/.claude/settings.local.json"
run 0 "13c. settings empty file → absent → ENABLED"

# Quoted string "false" disables — Layer 3 shares Layer 1's grammar, so an operator's
# disable intent is honoured regardless of quoting (V1.1 unification).
reset_state; printf '{"newearth_security_enabled": "false"}\n' > "$FAKE_HOME/.claude/settings.local.json"
run 1 "14. settings string \"false\" (quoted) → DISABLED (grammar shared with env layer)"

# Settings value set but unrecognised → indeterminate (exit 2), mirroring env layer.
reset_state; printf '{"newearth_security_enabled": "maybe"}\n' > "$FAKE_HOME/.claude/settings.local.json"
run 2 "14b. settings unrecognised value → INDETERMINATE (exit 2)"

# Invalid JSON → installation broken (exit 3), distinct from indeterminate value (exit 2).
reset_state; printf '{ this is not json\n' > "$FAKE_HOME/.claude/settings.local.json"
run 3 "15. settings invalid JSON → BROKEN (exit 3, distinct from 2)"

# Audit log written on disable (item M). env -i for the same isolation reason as run().
reset_state
( cd "$REPO" && env -i HOME="$FAKE_HOME" PATH="$PATH" NEWEARTH_SECURITY_ENABLED=0 bash "$SCRIPT" ) >/dev/null 2>&1 || true
if [ -f "$REPO/.claude/security-toggle-audit.log" ] && grep -q 'layer=env' "$REPO/.claude/security-toggle-audit.log"; then
  PASS=$((PASS+1)); printf '  [PASS] 16. disable writes audit log with layer=env\n'
else
  FAIL=$((FAIL+1)); printf '  [FAIL] 16. disable did NOT write audit log\n'
fi

echo "─────────────────────────────"
printf 'RESULT: %s passed, %s failed (of %s)\n' "$PASS" "$FAIL" "$((PASS+FAIL))"
[ "$FAIL" -eq 0 ]
