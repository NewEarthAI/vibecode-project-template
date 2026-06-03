#!/usr/bin/env bash
# pre-push-branch-verify.sh — PreToolUse hook (matcher: Bash)
# Warns when `git push origin <branch>` targets a different branch than
# `git rev-parse --abbrev-ref HEAD`. Catches silent branch-switch failure
# mode where a parallel session swaps the worktree branch out from under you.
#
# EFFICIENCY CONTRACT (per .claude/rules/hook-efficiency.md):
#   - Gate 1 — matcher: Bash (~40% of tool calls)
#   - Gate 2 — bash substring check for "git push" in raw JSON (no jq)
#             bails in <2ms for ALL non-push Bash calls (~99% of Bash calls)
#   - Gate 3 — only invokes git + injects context when target branch differs
#             from current HEAD. No-arg pushes (no mismatch possible) early-exit.
#   - Zero tokens injected (echo '{}') when not firing
#   - Max ~80 tokens injected when actual mismatch detected
#   - WARN only — never blocks (refspec push from off-branch is sometimes legit)

set -uo pipefail

input=$(cat)

# Gate 2: fast-path — bail unless "git push" appears in raw JSON
case "$input" in
  *'"git push'*) ;;
  *) echo '{}'; exit 0 ;;
esac

# Gate 3: extract command + parse target
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && { echo '{}'; exit 0; }

# Isolate the first `git push ...` segment (handle ; | && chains)
push_seg=$(printf '%s' "$cmd" | grep -oE 'git push[^;|&]*' | head -1)
[ -z "$push_seg" ] && { echo '{}'; exit 0; }

# Parse: skip flags (start with -), take 1st non-flag positional after "push"
# as remote, 2nd as branch. Handles: `git push origin foo`, `git push -u origin foo`,
# `git push --force-with-lease origin foo:bar`. Strips `:remote-side` from refspec.
target=$(printf '%s' "$push_seg" | awk '
  {
    seen_push=0; n_pos=0
    for(i=1;i<=NF;i++) {
      if($i=="push") { seen_push=1; continue }
      if(!seen_push) continue
      if($i ~ /^-/) continue          # skip flags
      if($i ~ /=/) continue           # skip --opt=val
      n_pos++
      if(n_pos==2) { sub(/:.*/, "", $i); print $i; exit }
    }
  }
')

# No explicit branch arg → user pushing current branch tracking → no mismatch possible
[ -z "$target" ] && { echo '{}'; exit 0; }

# Cheap local query — git rev-parse is microseconds
current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$current" ] || [ "$current" = "HEAD" ] && { echo '{}'; exit 0; }

# Mismatch → inject one-line warning context
if [ "$current" != "$target" ]; then
  msg="git push branch mismatch: current branch is '$current' but pushing to '$target'. Sometimes legitimate (refspec relay, hotfix push) but often signals a silent branch switch by a parallel session. Verify with: git rev-parse --abbrev-ref HEAD && git log origin/$target..$current --oneline"
  jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
else
  echo '{}'
fi
