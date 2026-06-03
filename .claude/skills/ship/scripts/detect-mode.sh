#!/usr/bin/env bash
# detect-mode.sh — classify git state → quick|pr|hotfix|ambiguous|detached|hotfix-guard
# stdout: mode string
# stderr: one-sentence reason
# exit:   0 always (ambiguity is data; caller decides how to respond)
#
# Design: council 2026-04-19 flagged that idealized cases miss the real worktree
# state. Detached HEAD and `current branch == main` are distinct exit paths,
# not buried in "ambiguous." See references/failure-inventory.md.

set -uo pipefail

# --- branch ---
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "__DETACHED__")

if [ "$branch" = "__DETACHED__" ]; then
  echo "detached"
  echo "HEAD is detached; checkout a branch before shipping" >&2
  exit 0
fi

if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "hotfix-guard"
  echo "Current branch is $branch; hotfix must be explicit (/ship hotfix — Phase C)" >&2
  exit 0
fi

# --- dirty tree check ---
dirty=0
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  dirty=1
fi

# --- upstream / ahead ---
upstream=$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null || echo "")
ahead=0
if [ -n "$upstream" ]; then
  ahead=$(git rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)
fi

# --- open PR for this branch ---
# Pre-check gh auth: matches sibling scripts (ci-watch.sh, smoke.sh). Silent
# degradation on gh-auth-expired would misclassify dirty-branches-with-open-PRs
# as `quick`, bypassing the PR amend flow. If auth is missing, route to
# `ambiguous` so the caller surfaces the gh-login recovery instead of
# silently routing to `quick`.
pr_count=0
if command -v gh >/dev/null 2>&1; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "ambiguous"
    echo "gh not authenticated — cannot determine PR state for $branch; run: gh auth login" >&2
    exit 0
  fi
  # Capture exit code separately — keying on stderr presence would mis-classify
  # gh's deprecation/rate-limit warnings (which write to stderr while exiting 0)
  # as fatal errors. Only treat nonzero exit as a real failure.
  pr_json=$(gh pr list --state open --head "$branch" --json number 2>/tmp/detect-mode-gh.$$)
  gh_rc=$?
  if [ "$gh_rc" -ne 0 ]; then
    echo "ambiguous"
    echo "gh pr list failed (rc=$gh_rc) for $branch: $(head -1 /tmp/detect-mode-gh.$$ 2>/dev/null)" >&2
    rm -f /tmp/detect-mode-gh.$$
    exit 0
  fi
  rm -f /tmp/detect-mode-gh.$$
  # Validate that gh returned a JSON array. If not, the response is malformed
  # and downstream `jq 'length'` would silently return 0 — same wrong-mode bug
  # the original C4 fix was meant to close.
  if ! printf '%s' "$pr_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "ambiguous"
    echo "gh pr list returned non-array payload for $branch: $(printf '%s' "$pr_json" | head -c 80)" >&2
    exit 0
  fi
  pr_count=$(printf '%s' "$pr_json" | jq 'length')
fi

if [ "$pr_count" -gt 1 ]; then
  echo "ambiguous"
  echo "Multiple open PRs ($pr_count) for branch $branch; inspect with: gh pr list --head $branch" >&2
  exit 0
fi

# --- dispatch ---
if [ "$dirty" = "1" ] && [ "$pr_count" = "0" ]; then
  echo "quick"
  echo "dirty tree, no open PR on $branch" >&2
  exit 0
fi

if [ "$dirty" = "1" ] && [ "$pr_count" = "1" ]; then
  echo "pr"
  echo "dirty tree + open PR on $branch; amend flow (Phase B)" >&2
  exit 0
fi

if [ "$dirty" = "0" ] && [ "$ahead" -gt 0 ]; then
  echo "pr"
  echo "clean tree, $ahead commit(s) ahead of $upstream; push-existing flow (Phase B)" >&2
  exit 0
fi

if [ "$dirty" = "0" ] && [ "$pr_count" = "1" ]; then
  echo "pr"
  echo "clean tree + open PR on $branch; ci-watch/merge flow (Phase B)" >&2
  exit 0
fi

echo "ambiguous"
echo "clean tree, no ahead, no open PR on $branch; nothing to ship" >&2
exit 0
