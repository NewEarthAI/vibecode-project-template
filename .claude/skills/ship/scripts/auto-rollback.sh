#!/usr/bin/env bash
# auto-rollback.sh — `git revert <sha>` + push on post-deploy smoke failure.
# Handles the Edge-Case-Finder D4 scenario: squash-merge revert conflicts when
# a concurrent hotfix landed on main after this PR but before the rollback fires.
#
# Usage: auto-rollback.sh <merged_sha> [--branch main] [--no-push]
#
# Exit codes:
#   0 — revert landed; main is back to pre-merge state
#   3 — revert failed (conflict OR push failed); caller halts and surfaces recovery
#
# Design:
#   1. Fetch origin to get latest refs (detects post-merge commits on main)
#   2. Snapshot current state BEFORE revert (failure-inventory: always snapshot
#      before destructive)
#   3. Enumerate commits on main AFTER the merged SHA and warn if any exist
#   4. `git revert --no-edit <merged_sha>` — fails on conflict with nonzero exit
#   5. On conflict: enumerate files, surface `git revert --abort` + full recovery
#   6. On success: plain `git push` (revert is fast-forward; --force is never needed
#   7. Update .claude/ship-state.json with exit_code: 4 (smoke-failed-reverted)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

merged_sha="${1:-}"
branch="main"
do_push=1

shift 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) branch="$2"; shift 2 ;;
    --no-push) do_push=0; shift ;;
    *) shift ;;
  esac
done

if [ -z "$merged_sha" ]; then
  echo "auto-rollback: merged_sha required" >&2
  exit 3
fi

# --- 1. Fetch origin ---
git fetch origin "$branch" >&2 2>&1 || {
  echo "auto-rollback: git fetch failed; cannot safely revert" >&2
  exit 3
}

# --- 2. Snapshot ---
snap_dir=$(bash "$SCRIPT_DIR/snapshot.sh" --tag "pre-rollback-${merged_sha:0:8}" 2>/dev/null || echo "")

# --- 3. Enumerate post-merge commits on main ---
post_merge=$(git log "${merged_sha}..origin/${branch}" --oneline 2>/dev/null || true)
if [ -n "$post_merge" ]; then
  echo "auto-rollback: WARNING — commits landed on $branch after $merged_sha:" >&2
  echo "$post_merge" | sed 's/^/    /' >&2
  echo "  Revert MAY conflict with these. If conflict occurs, manual resolution required." >&2
fi

# --- 4. Checkout branch + revert ---
current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "__detached__")
if [ "$current_branch" != "$branch" ]; then
  echo "auto-rollback: checking out $branch (was on $current_branch)" >&2
  git checkout "$branch" >&2 2>&1 || { echo "auto-rollback: checkout $branch failed" >&2; exit 3; }
  git pull --ff-only origin "$branch" >&2 2>&1 || true
fi

if git revert --no-edit "$merged_sha" 2>/tmp/rollback-revert.$$ >&2; then
  rm -f /tmp/rollback-revert.$$
  revert_sha=$(git rev-parse HEAD)
  echo "auto-rollback: revert committed as $revert_sha" >&2
else
  # --- 5. Conflict path: enumerate + surface recovery ---
  conflicted=$(git diff --name-only --diff-filter=U 2>/dev/null || true)
  echo "" >&2
  echo "auto-rollback: REVERT CONFLICT — production is still broken AND auto-revert failed" >&2
  echo "" >&2
  echo "Conflicted files:" >&2
  echo "$conflicted" | sed 's/^/    /' >&2
  echo "" >&2
  echo "Snapshot: $snap_dir" >&2
  echo "" >&2
  echo "Recovery options (manual — choose ONE):" >&2
  echo "  A) Abort revert, resolve by hand:" >&2
  echo "       git revert --abort" >&2
  echo "       git checkout -b hotfix/rollback-${merged_sha:0:8}" >&2
  echo "       # manually edit main to match pre-merge behavior, then open PR" >&2
  echo "" >&2
  echo "  B) Nuclear option (ONLY if no post-merge commits matter):" >&2
  echo "       git reset --hard ${merged_sha}^" >&2
  echo "       git push --force-with-lease origin $branch" >&2
  echo "" >&2
  echo "  C) Restore from snapshot:" >&2
  echo "       cp -r $snap_dir/* ." >&2
  rm -f /tmp/rollback-revert.$$
  exit 3
fi

# --- 6. Push (plain push — revert is always fast-forward; --force is not needed AND
# would violate the NEVER force-push-main rule in operational-guardrails.md) ---
if [ "$do_push" = "1" ]; then
  if git push origin "$branch" >&2 2>&1; then
    echo "auto-rollback: push succeeded" >&2
  else
    echo "auto-rollback: push failed — branch protection or remote moved" >&2
    echo "  If branch is protected, open a revert PR instead:" >&2
    echo "    gh pr create --base $branch --head revert-${merged_sha:0:8} --title 'Revert <merged PR>'" >&2
    echo "  If remote moved (sibling worktree pushed), fetch + retry:" >&2
    echo "    git fetch origin $branch && git rebase origin/$branch && git push origin $branch" >&2
    exit 3
  fi
fi

# --- 7. State file update — via env vars + heredoc to avoid shell-to-Python injection ---
state_file="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}/.claude/ship-state.json"
if [ -f "$state_file" ]; then
  SHIP_STATE_FILE="$state_file" SHIP_REVERT_SHA="$revert_sha" python3 - <<'PYEOF' 2>/tmp/ship-state-update.$$ || {
import json, os, datetime
p = os.environ['SHIP_STATE_FILE']
try:
    with open(p) as f: d = json.load(f)
except Exception: d = {}
d['exit_code'] = 4
d['completed_at'] = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
d['current_step'] = 'complete'
d['rollback_sha'] = os.environ['SHIP_REVERT_SHA']
d['rollback_reason'] = 'smoke_failed'
with open(p, 'w') as f: json.dump(d, f, indent=2)
PYEOF
    # Never fail loud here — audit trail is best-effort. Log warning so state-drift
    # is debuggable but don't overwrite the rc of the revert (which already shipped).
    echo "auto-rollback: WARN state file update failed — manual audit needed at $state_file" >&2
    cat /tmp/ship-state-update.$$ >&2
  }
  rm -f /tmp/ship-state-update.$$
fi

echo "auto-rollback: complete. Production reverted to pre-${merged_sha:0:8} state." >&2
echo "  Revert commit: $revert_sha" >&2
echo "  Snapshot: $snap_dir" >&2
exit 0
