#!/usr/bin/env bash
# snapshot.sh — capture tracked-modified + untracked-not-ignored files to
# ~/.claude-ship-snapshots/<ts>/ with a MANIFEST.md before any destructive sub-op.
#
# Invoke BEFORE: git reset --hard, git worktree remove --force, git branch -D,
# git rebase with conflicts, or any rm -rf on a path with uncommitted content.
#
# Usage: snapshot.sh [--tag <label>]  → prints snapshot dir on stdout; exit 0.
# Cost: ~1–5s, typically <1MB. Payoff: full recoverability.
#
# Design (council 2026-04-19): snapshot directory is TTL-cleaned in preflight.sh
# (>7 days → rm -rf) to prevent the disk-full trap that self-defeats the skill.

set -uo pipefail

tag="pre-destructive"
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) tag="$2"; shift 2 ;;
    *) shift ;;
  esac
done

ts=$(date -u +%Y%m%d-%H%M%SZ)
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
snap_dir="$HOME/.claude-ship-snapshots/${ts}-${repo}-${tag}"
mkdir -p "$snap_dir"

# Collect tracked-modified + untracked-not-ignored files via NULL-delimited output.
# `git status --porcelain=v1 -z` emits NUL-separated records: each record is
# "XY <path>\0" for normal entries, or "XY <new>\0<old>\0" for rename/copy.
# Null-delimited iteration correctly handles paths with spaces, newlines, or quotes.
expected=0
n=0
fail=0
captured_paths=""
while IFS= read -r -d '' entry; do
  [ -z "$entry" ] && continue
  # Skip the "old-name" record that follows an R/C entry (we already captured the new name)
  case "$entry" in
    R*|C*) : ;;   # first record is "Rxx <new>"; path starts at offset 3
    *) ;;
  esac
  path="${entry:3}"
  [ -z "$path" ] && continue
  expected=$((expected + 1))
  if [ ! -f "$path" ]; then
    # Directory or removed — note but don't count as failure
    captured_paths+="- (skip non-file) $path"$'\n'
    continue
  fi
  dest="$snap_dir/$path"
  mkdir -p "$(dirname "$dest")" 2>/dev/null
  if cp "$path" "$dest" 2>/dev/null; then
    n=$((n + 1))
    captured_paths+="- $path"$'\n'
  else
    echo "snapshot: FAILED to copy $path" >&2
    fail=1
    captured_paths+="- (COPY FAILED) $path"$'\n'
  fi
  # Eat the companion "old-name" record after rename/copy
  case "$entry" in
    R*|C*) IFS= read -r -d '' _discard || true ;;
  esac
done < <(git status --porcelain=v1 -z 2>/dev/null)

# MANIFEST
{
  echo "# Snapshot: $tag"
  echo "timestamp: $ts"
  echo "repo: $repo"
  echo "branch: $(git branch --show-current 2>/dev/null || echo DETACHED)"
  echo "head: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "files_captured: $n / $expected"
  if [ "$fail" = "1" ]; then
    echo "status: PARTIAL — some files failed to copy; see stderr above"
  elif [ "$n" -lt "$expected" ]; then
    echo "status: partial-by-design — $((expected - n)) entries skipped (non-files/directories)"
  else
    echo "status: complete"
  fi
  echo ""
  echo "## Files"
  printf '%s' "$captured_paths"
  echo ""
  echo "## Recovery"
  echo '```bash'
  echo "cp -r '$snap_dir'/* ."
  echo '```'
} > "$snap_dir/MANIFEST.md"

echo "$snap_dir"
exit 0
