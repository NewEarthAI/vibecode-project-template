#!/usr/bin/env bash
# preflight.sh — /ship pre-write gates. Exit 0 clean; exit 1 blocker.
#
# Gates (in order):
#   1. path-check.sh of $PWD         (iCloud/OneDrive/Dropbox/tmp → exit 6, then we exit 1)
#   2. self-test.sh                  (canary: typecheck guard is actually checking files)
#   3. disk free ≥5GB on /System/Volumes/Data  (APFS CoW degrades >90%)
#   4. stale git locks >10min        (.git/index.lock, .git/index 2.lock)
#   5. snapshot dir TTL cleanup      (>7 days old, non-blocking)
#   6. npm run typecheck             (only if .ts/.tsx staged/unstaged; skip generated types)
#
# Gate 2 ordering: runs after path-check (confirms safe location) but BEFORE
# any real typecheck. If the guard infrastructure is broken, halt immediately —
# a silent-passing typecheck is worse than no typecheck.
#
# All gates emit one-line diagnostic on stderr when they fire. stdout is reserved
# for structured output (future JSON mode).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAIL=0

# --- 1. path-check ---
if ! bash "$SCRIPT_DIR/path-check.sh" "$PWD" >/tmp/ship-path-check.$$ 2>&1; then
  cat /tmp/ship-path-check.$$ >&2
  rm -f /tmp/ship-path-check.$$
  echo "preflight: path-check failed (exit 6 class)" >&2
  exit 1
fi
rm -f /tmp/ship-path-check.$$

# --- 2. self-test (typecheck guard canary) ---
# Proves the typecheck guard is actually checking files, not silently passing.
# Exit code 2 = bootstrap skip (non-fatal, e.g. fresh worktree without node_modules);
# exit code 1 = guard broken, must halt. See .claude/rules/typecheck-and-review-gates.md.
if [ -x "$SCRIPT_DIR/self-test.sh" ]; then
  self_test_out=$(bash "$SCRIPT_DIR/self-test.sh" 2>&1)
  self_test_rc=$?
  if [ "$self_test_rc" = 1 ]; then
    printf '%s\n' "$self_test_out" >&2
    echo "preflight: self-test failed — typecheck guard is broken. Halting /ship." >&2
    exit 1
  fi
  # rc=0 (healthy) or rc=2 (skip due to missing env) both continue
fi

# --- 3. disk-free ---
data_vol="/System/Volumes/Data"
[ -d "$data_vol" ] || data_vol="/"
pct_used=$(df "$data_vol" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if [ -n "${pct_used:-}" ] && [ "$pct_used" -ge 90 ]; then
  echo "preflight: disk $pct_used% full on $data_vol. APFS CoW can corrupt .git/index >90%." >&2
  echo "  Safe purges: ~/.cache, ~/Library/Caches, npm cache, Playwright cache." >&2
  FAIL=1
fi

# --- 4. stale git locks ---
if [ -d ".git" ]; then
  stale=$(find .git -maxdepth 2 -name "*.lock" -type f -mmin +10 2>/dev/null | head -3 | tr '\n' ' ')
  if [ -n "$stale" ]; then
    echo "preflight: stale git locks (>10min): $stale" >&2
    echo "  Remove before continuing. Common on iCloud-poisoned repos or crashed sessions." >&2
    FAIL=1
  fi
fi

# --- 5. snapshot TTL cleanup (non-blocking) ---
snap_dir="$HOME/.claude-ship-snapshots"
if [ -d "$snap_dir" ]; then
  find "$snap_dir" -maxdepth 1 -type d -mtime +7 -not -path "$snap_dir" -exec rm -rf {} + 2>/dev/null || true
fi

# --- 6. typecheck gate (conditional) ---
# Check if .ts/.tsx files are staged OR unstaged-but-tracked-modified.
# Skip auto-generated Supabase types (src/integrations/supabase/types.ts).
# Prefers `npm run typecheck` (usually `tsc -p tsconfig.app.json`) over bare
# `npx tsc --noEmit` — the bare form is a silent no-op against any root tsconfig
# with project references + `"files": []`. See .claude/rules/typecheck-and-review-gates.md.
ts_changed=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx)$' | grep -v 'integrations/supabase/types\.ts' | head -1)
if [ -n "$ts_changed" ] && [ -f "tsconfig.json" ]; then
  # Portable timeout: prefer GNU `timeout`, fall back to `gtimeout` (homebrew coreutils),
  # or unwrapped (macOS default lacks timeout). tsc typically completes in <90s.
  if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout 180"
  elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout 180"
  else
    TIMEOUT_CMD=""
  fi
  # Prefer `npm run typecheck` if defined; fall back to bare tsc for older projects.
  if [ -f "package.json" ] && grep -q '"typecheck"' package.json 2>/dev/null; then
    echo "preflight: running npm run typecheck (TS/TSX in diff)..." >&2
    TYPECHECK_CMD="npm run typecheck"
  else
    echo "preflight: running npx tsc --noEmit (TS/TSX in diff; consider adding 'typecheck' npm script)..." >&2
    TYPECHECK_CMD="npx tsc --noEmit"
  fi
  if ! $TIMEOUT_CMD $TYPECHECK_CMD >/tmp/ship-tsc.$$ 2>&1; then
    tail -20 /tmp/ship-tsc.$$ >&2
    rm -f /tmp/ship-tsc.$$
    echo "preflight: typecheck failed — fix type errors before shipping" >&2
    echo "  See .claude/rules/typecheck-and-review-gates.md for the admin-merge policy." >&2
    FAIL=1
  fi
  rm -f /tmp/ship-tsc.$$
fi

exit $FAIL
