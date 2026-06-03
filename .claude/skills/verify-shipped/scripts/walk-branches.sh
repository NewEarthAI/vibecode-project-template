#!/usr/bin/env bash
# walk-branches.sh — Layer 2 of /verify-shipped
#
# Walks every local branch (excluding main/master) and reports relative-to-origin state:
#  - [CLEAN] <branch>                    — pushed, up-to-date with upstream (suppressed in high-fleet repos)
#  - [AHEAD] <branch> <count>            — N local commits not pushed (fix: git push origin <branch>)
#  - [BEHIND] <branch> <count>           — informational; remote has N commits the local branch doesn't
#  - [DIVERGED] <branch> <ahead>/<behind> — both ahead AND behind (fix: git fetch && git pull --rebase)
#  - [NO_UPSTREAM] <branch>              — no tracking remote; either push -u or delete
#  - [STALE_LOCAL] <branch>              — upstream gone (deleted on origin); investigate or git branch -D
#  - [ERROR] <branch> <reason>           — couldn't probe
#
# Pure bash. Reads cached origin refs (no `git fetch` — caller's responsibility).
# Bash 3.2 portable per shell-portability.md (no mapfile; while-read; to_int normaliser).
#
# Exit code:
#   0 — all branches clean (no AHEAD / DIVERGED / NO_UPSTREAM / STALE_LOCAL / ERROR)
#   1 — at least one issue found
#
# Usage: bash .claude/skills/verify-shipped/scripts/walk-branches.sh

set -uo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERROR] cwd not a git repo: $(pwd)" >&2
  exit 1
fi

issue_count=0
clean_count=0
behind_count=0  # informational only — not counted as issues

# Numeric normaliser per shell-portability.md §6 (mirrors walk-worktrees.sh)
to_int() {
  local raw="${1:-0}"
  raw=$(printf '%s' "$raw" | tr -dc '0-9' | head -c 6)
  printf '%s' "${raw:-0}"
}

# Read all local branches into an array — exclude main/master
# `git for-each-ref` is local-cache-only (no network); fast on any fleet size.
branch_list=()
while IFS= read -r line; do
  # Skip empty lines + main/master
  case "$line" in
    ""|"main"|"master") continue ;;
  esac
  branch_list+=("$line")
done < <(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)

if [ ${#branch_list[@]} -eq 0 ]; then
  echo "" >&2
  echo "Layer 2 summary: no non-main/master branches found." >&2
  exit 0
fi

# Total branch count drives CLEAN suppression — high-fleet repos (>10) emit summary only
total_branches=${#branch_list[@]}
suppress_clean_lines=0
if [ "$total_branches" -gt 10 ]; then
  suppress_clean_lines=1
fi

# Bash 3.2 safe expansion
for branch in "${branch_list[@]:-}"; do
  [ -z "$branch" ] && continue

  # Resolve upstream — non-fatal if absent
  upstream=""
  if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>/dev/null); then
    : # has upstream
  else
    echo "[NO_UPSTREAM] $branch (fix: git push -u origin $branch  OR  git branch -D $branch if abandoned)"
    issue_count=$((issue_count + 1))
    continue
  fi

  # Verify the upstream still exists (deleted-on-origin = STALE_LOCAL)
  if ! git rev-parse --verify "$upstream" >/dev/null 2>&1; then
    echo "[STALE_LOCAL] $branch (upstream $upstream gone from origin; verify work merged then: git branch -D $branch)"
    issue_count=$((issue_count + 1))
    continue
  fi

  # Compute ahead/behind via rev-list — local-cache only
  # Format: "<ahead> <behind>" via --left-right --count
  ahead_behind=$(git rev-list --left-right --count "$branch...$upstream" 2>/dev/null)
  if [ -z "$ahead_behind" ]; then
    echo "[ERROR] $branch could not compute ahead/behind vs $upstream"
    issue_count=$((issue_count + 1))
    continue
  fi

  # Parse — split on whitespace into ahead + behind
  ahead=$(printf '%s' "$ahead_behind" | awk '{print $1}')
  behind=$(printf '%s' "$ahead_behind" | awk '{print $2}')
  ahead=$(to_int "$ahead")
  behind=$(to_int "$behind")

  if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    echo "[DIVERGED] $branch $ahead/$behind (fix: git fetch && git checkout $branch && git pull --rebase)"
    issue_count=$((issue_count + 1))
  elif [ "$ahead" -gt 0 ]; then
    echo "[AHEAD] $branch $ahead commits not pushed (fix: git push origin $branch)"
    issue_count=$((issue_count + 1))
  elif [ "$behind" -gt 0 ]; then
    # Informational only — remote is ahead, local hasn't pulled yet. Not an issue.
    echo "[BEHIND] $branch $behind (remote ahead; informational, no action required)"
    behind_count=$((behind_count + 1))
  else
    # Truly clean
    if [ "$suppress_clean_lines" = "0" ]; then
      echo "[CLEAN] $branch"
    fi
    clean_count=$((clean_count + 1))
  fi
done

# Summary on stderr (matches walk-worktrees.sh pattern)
echo "" >&2
if [ "$issue_count" -gt 0 ]; then
  echo "Layer 2 summary: $issue_count issue(s), $clean_count clean, $behind_count behind, $total_branches total." >&2
  exit 1
fi
echo "Layer 2 summary: all $clean_count branches clean ($behind_count behind, $total_branches total)." >&2
exit 0
