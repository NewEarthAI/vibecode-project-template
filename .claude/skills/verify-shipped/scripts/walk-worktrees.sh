#!/usr/bin/env bash
# walk-worktrees.sh — Layer 1 of /verify-shipped
#
# Walks every git worktree registered in this repo's git config and reports:
# - [CLEAN] <path>             — no uncommitted changes, push-up-to-date
# - [DIRTY] <path> <N>         — N uncommitted (staged + unstaged) changes
# - [STALE] <path> <branch>    — pushed-up-to-date but local commits ahead of origin
# - [STASH] <path> <N>         — N stashes present
# - [DETACHED] <path>          — HEAD detached (manual checkout, not on a branch)
# - [ERROR] <path> <reason>    — couldn't probe (lock file, missing dir, etc.)
#
# Pure bash. No MCP, no network calls (uses cached origin refs via git for-each-ref).
# To get fresh origin state, run `git fetch --all --prune` BEFORE invoking this script.
#
# Exit code:
#   0 — all worktrees clean (no DIRTY / STALE / STASH / DETACHED / ERROR lines)
#   1 — at least one issue found
#
# Usage: bash .claude/skills/verify-shipped/scripts/walk-worktrees.sh

set -uo pipefail   # NOT -e — we want to keep walking past per-worktree failures

# Verify we're inside a git tree
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERROR] cwd not a git repo: $(pwd)" >&2
  exit 1
fi

exit_code=0
issue_count=0
clean_count=0  # hoisted to top per shell-portability.md (declare-before-use under set -u)

# Detect timeout binary ONCE at script start (avoids 150 command -v probes on a 50-worktree fleet)
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi

# Portable timeout wrapper — only used on git status (the high-risk operation that can
# hang on stuck index locks per shell-portability.md §3). Fast local reads (rev-parse,
# rev-list) are NOT wrapped — they read local cache and rarely hang; wrapping every
# git call with a background-kill fallback was 150× overhead on Justin's 50-worktree fleet.
# Returns: 0 + stdout on success, 124 + empty on timeout, other rc on git failure.
run_with_timeout() {
  local seconds="$1"; shift
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$seconds" "$@"
    return $?
  fi
  # Background-kill fallback (macOS BSD without coreutils) — sub-second poll for snappy completion
  "$@" &
  local pid=$!
  local i=0
  local max_iters=$((seconds * 5))   # 0.2s poll interval × 5 = 1s
  while kill -0 "$pid" 2>/dev/null; do
    sleep 0.2
    i=$((i + 1))
    if [ "$i" -ge "$max_iters" ]; then
      kill -TERM "$pid" 2>/dev/null
      sleep 0.5
      kill -KILL "$pid" 2>/dev/null
      return 124
    fi
  done
  wait "$pid"
}

# Numeric normaliser — bulletproof against multiline / non-numeric input per shell-portability.md §6
to_int() {
  local raw="${1:-0}"
  raw=$(printf '%s' "$raw" | tr -dc '0-9' | head -c 6)
  printf '%s' "${raw:-0}"
}

# Read worktree list into an array (porcelain output) — portable across bash 3.2 (macOS) + bash 4+
worktree_lines=()
while IFS= read -r line; do
  worktree_lines+=("$line")
done < <(git worktree list --porcelain 2>/dev/null)

# Add a final empty line to ensure last block flushes (porcelain may not emit trailing blank)
worktree_lines+=("")

# Parse porcelain blocks: each block starts with "worktree <path>" and may have "HEAD <sha>" + "branch <ref>" + "detached"
current_path=""
current_branch=""
current_detached=0

emit_block() {
  local path="$1"
  local branch="$2"
  local detached="$3"

  [ -z "$path" ] && return 0

  # Verify the path still exists on disk
  if [ ! -d "$path" ]; then
    echo "[ERROR] $path missing on disk (stale worktree metadata)"
    issue_count=$((issue_count + 1))
    return 0
  fi

  # Run git status from inside the worktree with a 10s timeout to avoid hangs
  # on iCloud-poisoned paths or stuck index locks per shell-portability.md §3
  local status_output
  status_output=$(run_with_timeout 10 bash -c "cd \"$path\" 2>/dev/null && git -c core.fsmonitor=false status --porcelain=v1 -uno 2>&1")
  local status_rc=$?
  if [ "$status_rc" = "124" ]; then
    # Likely stuck index lock — surface diagnostic per operational-guardrails.md §11
    local lock_files
    lock_files=$(ls "$path/.git/" 2>/dev/null | grep -E '\.lock$|index 2' | tr '\n' ' ')
    echo "[ERROR] $path git status timed out after 10s (suspicious files: ${lock_files:-none}; cd $path && find .git -name '*.lock')"
    issue_count=$((issue_count + 1))
    return 0
  elif [ "$status_rc" != "0" ]; then
    echo "[ERROR] $path could not run git status (rc=$status_rc)"
    issue_count=$((issue_count + 1))
    return 0
  fi

  # Count uncommitted changes (excluding untracked due to -uno)
  # Bulletproof numeric extraction per shell-portability.md §6
  local uncommitted_count
  uncommitted_count=$(printf '%s\n' "$status_output" | grep -c '^[^[:space:]]' 2>/dev/null || true)
  uncommitted_count=$(to_int "$uncommitted_count")

  # NOTE: stash count is intentionally NOT computed per-worktree.
  # Git stashes live in the SHARED refs/stash store, not per-worktree.
  # `git stash list` returns the same N from every worktree. Reporting per-worktree
  # would inflate issue count by N×worktrees. Single global stash count is emitted at end.

  # Branch + ahead/behind probe — local cache reads, no timeout wrapper (fast path)
  local ahead=0
  local has_remote=0
  if [ "$detached" = "1" ]; then
    echo "[DETACHED] $path (HEAD detached, no branch tracked)"
    issue_count=$((issue_count + 1))
  elif [ -n "$branch" ]; then
    # Check if branch has an upstream
    if (cd "$path" 2>/dev/null && git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1); then
      has_remote=1
      ahead=$(cd "$path" 2>/dev/null && git rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)
      ahead=$(to_int "$ahead")
    fi
  fi

  # Emit per-condition lines — drop 2>/dev/null on test guards (silent-mask anti-pattern)
  local emitted=0
  if [ "$uncommitted_count" -gt 0 ]; then
    echo "[DIRTY] $path $uncommitted_count uncommitted (cd $path && git status)"
    issue_count=$((issue_count + 1))
    emitted=1
  fi
  if [ "$ahead" -gt 0 ]; then
    echo "[STALE] $path on $branch, $ahead commits ahead of origin (cd $path && git push)"
    issue_count=$((issue_count + 1))
    emitted=1
  fi

  if [ "$emitted" = "0" ] && [ "$detached" != "1" ]; then
    # Suppress per-worktree CLEAN lines for high-fleet repos (>10 worktrees) to reduce noise.
    # Single summary line at end shows total clean count.
    clean_count=$((clean_count + 1))
  fi
}

# Bash 3.2 safe expansion — guard the array reference
for line in "${worktree_lines[@]:-}"; do
  case "$line" in
    "worktree "*)
      # Flush previous block
      emit_block "$current_path" "$current_branch" "$current_detached"
      current_path="${line#worktree }"
      current_branch=""
      current_detached=0
      ;;
    "branch refs/heads/"*)
      current_branch="${line#branch refs/heads/}"
      ;;
    "detached")
      current_detached=1
      ;;
    "")
      # Block separator — flush
      emit_block "$current_path" "$current_branch" "$current_detached"
      current_path=""
      current_branch=""
      current_detached=0
      ;;
  esac
done

# Final flush (last block may not have trailing blank line)
emit_block "$current_path" "$current_branch" "$current_detached"

# Global stash count — refs/stash is shared across worktrees in the same repo.
# Per code-council: don't gate on `[ -f refs/stash ]` (packed-refs makes that fragile).
# Trust `git stash list` directly — empty output → 0 stashes.
global_stash_count=$(git stash list 2>/dev/null | grep -c '^stash@' 2>/dev/null || true)
global_stash_count=$(to_int "$global_stash_count")
if [ "$global_stash_count" -gt 0 ]; then
  echo "[INFO] $global_stash_count stashes in shared repo store (informational; cd <repo> && git stash list)"
fi

# Summary line on stderr (so it doesn't pollute machine-parseable stdout)
if [ "$issue_count" -gt 0 ]; then
  echo "" >&2
  echo "Layer 1 summary: $issue_count issue(s), $clean_count clean, $global_stash_count stashes." >&2
  exit 1
fi

echo "" >&2
echo "Layer 1 summary: all $clean_count worktrees clean, $global_stash_count stashes." >&2
exit 0
