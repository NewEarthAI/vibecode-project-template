#!/usr/bin/env bash
# verify-push-landed.sh — "pushed" is only true when the remote SHA matches.
#
# THE FAILURE THIS PREVENTS (council 2026-05-19, operator's explicit CRITICAL):
# `git push` exiting 0 does NOT prove the commit landed on the remote branch.
# A protected branch, a rejected non-fast-forward, a hook that swallowed the
# error, or a network blip can all leave exit 0 with nothing actually pushed —
# and the ship flow then reports "pushed" when nothing was.
#
# This script asks the remote directly: `git ls-remote origin <branch>` and
# compares that SHA to the local commit. It reports "pushed" ONLY on an exact
# SHA match. Claim-with-evidence (agentic-loop-guards.md).
#
# Exit codes:
#   0 — VERIFIED: remote branch SHA == local SHA (the push genuinely landed)
#   1 — NOT LANDED: remote SHA differs from local (push did NOT take effect)
#   2 — could not verify (no remote ref, ls-remote failed, not a git repo)
#
# Usage:
#   bash verify-push-landed.sh <branch> [--dir /path/to/worktree] [--remote origin]
#   bash verify-push-landed.sh                # branch defaults to current HEAD branch

set -uo pipefail

BRANCH=""
WDIR="."
REMOTE="origin"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir) WDIR="${2:-.}"; shift 2 ;;
    --dir=*) WDIR="${1#--dir=}"; shift ;;
    --remote) REMOTE="${2:-origin}"; shift 2 ;;
    --remote=*) REMOTE="${1#--remote=}"; shift ;;
    -*) echo "verify-push-landed: unknown flag '$1'" >&2; shift ;;
    *) BRANCH="$1"; shift ;;
  esac
done

cd "$WDIR" 2>/dev/null || { echo "verify-push-landed: cannot cd to $WDIR" >&2; exit 2; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "verify-push-landed: not a git repo at $WDIR" >&2
  exit 2
fi

if [ -z "$BRANCH" ]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
fi
if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
  echo "verify-push-landed: cannot determine branch (detached HEAD?) — pass it explicitly" >&2
  exit 2
fi
# Reject a branch beginning with '-' — ls-remote would read it as a flag, not
# a ref (code-council 2026-05-19 IMPORTANT). UNVERIFIED, never a false "pushed".
case "$BRANCH" in
  -*) echo "verify-push-landed: branch '$BRANCH' starts with '-' — refusing (would be read as a git flag). UNVERIFIED." >&2
      exit 2 ;;
esac

local_sha="$(git rev-parse HEAD 2>/dev/null)"
if [ -z "$local_sha" ]; then
  echo "verify-push-landed: cannot read local HEAD sha" >&2
  exit 2
fi

# Ask the remote directly. Capture rc WITHOUT a pipe (shell-portability.md §1):
# a pipe to awk/head would mask ls-remote's own exit code.
lsr_tmp="$(mktemp 2>/dev/null || echo "/tmp/verify-push.$$.$RANDOM")"
git ls-remote "$REMOTE" "refs/heads/$BRANCH" > "$lsr_tmp" 2>/dev/null
lsr_rc=$?
remote_sha="$(awk 'NR==1{print $1}' "$lsr_tmp" 2>/dev/null)"
rm -f "$lsr_tmp"

if [ "$lsr_rc" -ne 0 ]; then
  echo "verify-push-landed: could not reach $REMOTE to verify (ls-remote rc=$lsr_rc)."
  echo "  Treat the push as UNVERIFIED — do NOT report 'pushed'."
  exit 2
fi

if [ -z "$remote_sha" ]; then
  echo "verify-push-landed: $REMOTE has no branch '$BRANCH' — the push did NOT land."
  echo "  local HEAD:  $local_sha"
  echo "  remote:      (branch absent)"
  exit 1
fi

if [ "$remote_sha" = "$local_sha" ]; then
  echo "verify-push-landed: ✅ VERIFIED — $REMOTE/$BRANCH is at $local_sha (push landed)."
  exit 0
fi

echo "verify-push-landed: ❌ NOT LANDED — remote SHA does not match local."
echo "  local HEAD:  $local_sha"
echo "  $REMOTE/$BRANCH: $remote_sha"
echo "  Do NOT report 'pushed'. The local commit is not on the remote branch."
exit 1
