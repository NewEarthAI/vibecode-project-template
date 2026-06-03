#!/usr/bin/env bash
# rebase-conflict-guard.sh — the unattended code-conflict HARD STOP.
#
# THE FAILURE THIS PREVENTS (council 2026-05-19, Edge Case Finder CRITICAL 4):
# `git checkout --ours/--theirs` means the OPPOSITE thing during a rebase vs a
# merge. During a REBASE, `--ours` is the branch being rebased ONTO (upstream),
# `--theirs` is your replayed commits — reversed from merge intuition. An
# unattended /ship or /autovibe that auto-resolves a code-file conflict in this
# state can silently DISCARD a worktree's real code and still pass CI green.
#
# This guard is called BEFORE any conflict side-pick in unattended mode. It:
#   - detects whether a REBASE or a MERGE is in progress (explicitly, not guessed)
#   - lists conflicted files and classifies each as CODE or DOCS
#   - HARD STOPS (exit 3) if ANY conflicted file is code, in unattended mode,
#     surfacing the reversed-semantics warning for the rebase case
#   - allows the caller to proceed (exit 0) only when there are no conflicts, or
#     only docs-class conflicts — and even then prints a log line so the
#     docs auto-resolution is never silent
#
# It NEVER resolves anything itself. It only authorises or halts.
#
# Code classes (auto-resolution forbidden): .ts .tsx .js .jsx .mjs .cjs .sql .py
# Docs classes (auto-resolution permitted WITH logging): .md .markdown .yaml .yml .txt
# Anything else is treated as CODE (fail safe — unknown extension is not docs).
#
# Exit codes:
#   0 — safe to proceed: no conflicts, OR docs-only conflicts (logged)
#   2 — no rebase/merge conflict state at all (nothing to guard; caller continues)
#   3 — HARD STOP: code-file conflict in unattended mode; a human must resolve
#
# Usage:
#   bash rebase-conflict-guard.sh                 # unattended (default), cwd repo
#   bash rebase-conflict-guard.sh --mode interactive
#   bash rebase-conflict-guard.sh --dir /path/to/worktree

set -uo pipefail

MODE="unattended"
WDIR="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-unattended}"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --dir)  WDIR="${2:-.}"; shift 2 ;;
    --dir=*) WDIR="${1#--dir=}"; shift ;;
    *) echo "rebase-conflict-guard: unknown arg '$1'" >&2; shift ;;
  esac
done

cd "$WDIR" 2>/dev/null || { echo "rebase-conflict-guard: cannot cd to $WDIR" >&2; exit 2; }

git_dir="$(git rev-parse --git-dir 2>/dev/null)"
if [ -z "$git_dir" ]; then
  echo "rebase-conflict-guard: not a git repo at $WDIR" >&2
  exit 2
fi

# --- detect operation state EXPLICITLY -----------------------------------------
op="none"
if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
  op="rebase"
elif [ -f "$git_dir/MERGE_HEAD" ]; then
  op="merge"
fi

# --- conflicted files ----------------------------------------------------------
# Capture git-diff rc WITHOUT a pipe. If `git diff` itself errors mid-rebase
# (e.g. a locked index — exactly when this guard matters most), empty output
# must NOT be read as "no conflicts, safe to proceed" — that would let the
# caller auto-resolve while real conflicts exist. Fail CLOSED (code-council
# 2026-05-19 IMPORTANT).
cdiff_tmp="$(mktemp 2>/dev/null || echo "/tmp/rcg-diff.$$.$RANDOM")"
git diff --name-only --diff-filter=U > "$cdiff_tmp" 2>/dev/null
cdiff_rc=$?
conflicts="$(cat "$cdiff_tmp" 2>/dev/null)"
rm -f "$cdiff_tmp"
if [ "$cdiff_rc" -ne 0 ] && [ "$op" != "none" ]; then
  echo "════════════════════════════════════════════════════════════"
  echo "🛑 HARD STOP — could not read conflict state during a $op (git diff rc=$cdiff_rc)."
  echo "Treating as unresolved to prevent a silent auto-resolve. Resolve by"
  echo "hand or abort (git $op --abort), then re-run."
  echo "════════════════════════════════════════════════════════════"
  exit 3
fi
if [ -z "$conflicts" ]; then
  if [ "$op" = "none" ]; then
    echo "rebase-conflict-guard: no rebase/merge in progress and no conflicts — nothing to guard."
    exit 2
  fi
  echo "rebase-conflict-guard: $op in progress but no unresolved conflicts — safe to proceed."
  exit 0
fi

code_hits=""
docs_hits=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.sql|*.py)
      code_hits="$code_hits $f" ;;
    *.md|*.markdown|*.yaml|*.yml|*.txt)
      docs_hits="$docs_hits $f" ;;
    *)
      # unknown extension → treat as CODE (fail safe)
      code_hits="$code_hits $f" ;;
  esac
done <<EOF
$conflicts
EOF

code_hits="$(printf '%s' "$code_hits" | sed 's/^ //')"
docs_hits="$(printf '%s' "$docs_hits" | sed 's/^ //')"

if [ -n "$code_hits" ]; then
  echo "════════════════════════════════════════════════════════════"
  echo "🛑 HARD STOP — code-file conflict during a $op"
  echo
  echo "Conflicted code files:"
  for f in $code_hits; do echo "    • $f"; done
  echo
  if [ "$op" = "rebase" ]; then
    echo "REVERSED SEMANTICS WARNING: during a rebase, 'git checkout --ours'"
    echo "is the branch being rebased ONTO (upstream/main), and '--theirs' is"
    echo "YOUR replayed commits — the OPPOSITE of merge. Auto-resolving in this"
    echo "state has a ~50% chance of silently dropping the intended side."
  else
    echo "A code-file conflict during a merge in unattended mode is a"
    echo "data-loss risk — auto-resolution can silently discard real code."
  fi
  echo
  if [ "$MODE" = "interactive" ]; then
    echo "(interactive mode — halting even with a human present; do NOT"
    echo " auto-resolve these. Open an editor, resolve by hand, then re-run.)"
    exit 3
  fi
  echo "Unattended mode MUST NOT auto-resolve these. Halting for human review."
  echo "Recovery: abort the operation (git rebase --abort / git merge --abort)"
  echo "or resolve each code file by hand, then re-run the ship flow."
  echo "════════════════════════════════════════════════════════════"
  exit 3
fi

# docs-only conflicts — permitted, but NEVER silent
echo "rebase-conflict-guard: $op has DOCS-ONLY conflicts (auto-resolution permitted, logged):"
for f in $docs_hits; do echo "    • $f"; done
echo "rebase-conflict-guard: caller may auto-resolve the docs files above WITH logging."
exit 0
