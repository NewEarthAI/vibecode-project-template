#!/usr/bin/env bash
# worktree-guard.sh — PreToolUse hook (matcher: Bash)
# Three concerns, one hook, triple-gated for token + latency efficiency:
#   1. Branch-modifying git op while extra worktrees exist → single-folder reminder
#   2. `git switch -c <new> origin/main` on a dirty tree without a stash-first →
#      teach the safe single-folder stash-then-switch order (NOT a worktree)
#   3. `git worktree add` → scan for stale .git/*.lock files
#
# Doctrine: .claude/rules/worktree-discipline.md — single-folder feature-branch is
# the DEFAULT; worktrees are the parallel-only exception. As of 2026-05-18 this hook
# no longer recommends spawning a worktree as the fix for dirty-tree branch work.
#
# EFFICIENCY CONTRACT:
#   - Matcher narrows to Bash (not *) — ~40% of tool calls max
#   - FAST PATH: bash-native substring check on raw JSON (no jq) bails in <2ms
#     for ALL non-git Bash calls (ls, cat, npm, curl, etc.) — ~95% of Bash calls
#   - jq + git queries only run when "git " substring is present
#   - Zero tokens injected (echo '{}') when not firing
#   - Max ~55 tokens injected when actually relevant

set -euo pipefail

# --- self-test (per shell-portability.md rule 7: exercise as a child process) ---
if [ "${1:-}" = "--self-test" ]; then
  self="$0"; pass=0; fail=0
  check() { # <label> <json> <expect: deny|allow>
    local label="$1" json="$2" expect="$3" out got
    out=$(printf '%s' "$json" | bash "$self" 2>/dev/null)
    if printf '%s' "$out" | grep -qE '"permissionDecision":[[:space:]]*"deny"'; then got=deny; else got=allow; fi
    if [ "$got" = "$expect" ]; then pass=$((pass+1)); echo "  PASS [$label] → $got"
    else fail=$((fail+1)); echo "  FAIL [$label] → got $got, expected $expect"; fi
  }
  echo "worktree-guard self-test:"
  check "bare worktree add"        '{"tool_input":{"command":"git worktree add /tmp/x origin/main"}}' deny
  check "PREFIXED worktree add"    '{"tool_input":{"command":"cd ~/code/<repo> && git worktree add /tmp/x origin/main"}}' deny
  check "sanctioned worktree add"  '{"tool_input":{"command":"ALLOW_PARALLEL_WORKTREE=1 git worktree add /tmp/x origin/main"}}' allow
  check "non-git command"          '{"tool_input":{"command":"ls -la"}}' allow
  check "git switch (single-folder)" '{"tool_input":{"command":"git switch -c feat/x origin/main"}}' allow
  check "git worktree remove (cleanup)" '{"tool_input":{"command":"git worktree remove /tmp/x"}}' allow
  check "commit MENTIONING phrase"   '{"tool_input":{"command":"git commit -m \"flip cold-open away from git worktree add to single-folder\""}}' allow
  check "grep MENTIONING phrase"     '{"tool_input":{"command":"grep -rn \"git worktree add\" .claude/"}}' allow
  check "echo MENTIONING phrase"     '{"tool_input":{"command":"echo \"never run git worktree add here\""}}' allow
  echo "  ---- $pass passed, $fail failed ----"
  [ "$fail" -eq 0 ]; exit $?
fi

input=$(cat)

# FAST PATH: raw string check on JSON input — bash substring is ~instant,
# avoids spawning jq for the 95%+ of Bash calls that aren't git.
# Match ANY "git" substring (not '"git ' with a leading quote): a `git worktree add`
# can be prefixed (cd /x && git ..., ALLOW_PARALLEL_WORKTREE=1 git ...) so requiring
# git to be the first token would let prefixed worktree-adds bypass enforcement. The
# rare false-positive (e.g. "digit", "legit") harmlessly hits the slow path and the
# precise grep there returns {}.
case "$input" in
  *git*) ;;
  *) echo '{}'; exit 0 ;;
esac

# SLOW PATH (git command detected): extract and inspect precisely
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
msg=""

# Concern 1: branch-modifying git op while extra worktrees are present.
# Under the single-folder default, >1 worktree means either the agent-team
# exception is running or stale worktrees were left behind — surface it either way.
if echo "$cmd" | grep -qE 'git (checkout|rebase|merge|cherry-pick|reset --hard|branch -[dD]|switch -c)'; then
  wt_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  if [ "${wt_count:-0}" -gt 1 ]; then
    msg="Branch-modifying git op with ${wt_count} worktrees present. Single-folder is the default — run new branch work as 'git switch -c <branch> origin/main' inside ~/code/<repo>; worktrees are the parallel-only exception. NEVER use ~/Documents/GitHub/ (iCloud corrupts .git metadata). Leftover worktrees from old jobs? 'git worktree list' then 'git worktree remove' + 'git worktree prune'. See .claude/rules/worktree-discipline.md."
  fi
fi

# Concern 2: `git switch -c <new> origin/main|main` on a dirty tree (≥5 files).
# The single-folder safe order is stash-FIRST so the tree is clean at switch time.
# If the command already stashes before switching, that IS the safe pattern — stay silent.
if echo "$cmd" | grep -qE 'git switch -c .*(origin/|main|master)'; then
  if ! echo "$cmd" | grep -q 'git stash'; then
    dirty_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "${dirty_count:-0}" -ge 5 ]; then
      msg="Dirty tree (${dirty_count} files) + branch-off-main. Single-folder safe order: 'git stash push -u' FIRST (clean tree), THEN 'git switch -c <branch> origin/main', then work + commit + push, then 'git switch <original-branch> && git stash pop'. Do NOT stash-apply onto the new branch then 'git checkout HEAD -- .' to clean conflicts — that reverts agent edits. See .claude/rules/worktree-discipline.md § stash-and-switch pitfall."
    fi
  fi
fi

# Concern 3: git worktree add → BLOCK fail-closed unless explicitly sanctioned.
# Single-folder is the ENFORCED default. A worktree is the rare parallel-work
# exception (/build-with-agent-team's Agent isolation creates worktrees via the
# harness, NOT a Bash `git worktree add`, so it bypasses this hook entirely).
# A genuine raw `git worktree add` (e.g. a clean base when the primary clone is
# occupied) opts in PER-COMMAND with an inline env prefix:
#     ALLOW_PARALLEL_WORKTREE=1 git worktree add <path> <ref>
# The flag must be in the command STRING — the hook subprocess runs before the
# Bash command and cannot see env exported inside that not-yet-run command.
#
# Match `git worktree add` only at a COMMAND BOUNDARY (start, or after ; & | ( )
# optionally preceded by env-var prefixes (the escape hatch). This avoids a
# false-positive when the phrase merely APPEARS as an argument — a commit
# message (git commit -m "... git worktree add ..."), a search (grep "git
# worktree add"), or an echo — none of which actually run the command.
if echo "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*git[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)'; then
  if echo "$cmd" | grep -q 'ALLOW_PARALLEL_WORKTREE=1'; then
    # Sanctioned — never block. Courtesy stale-lock scan only.
    stale=$(find .git -name "*.lock" -type f -mmin +10 2>/dev/null | head -3 | tr '\n' ' ')
    if [ -n "$stale" ]; then
      msg="Sanctioned worktree (ALLOW_PARALLEL_WORKTREE=1). Heads-up: stale git locks (>10min): $stale — remove before add to avoid a silent hang. Clean up the worktree when done: git worktree remove <path> && git worktree prune."
    else
      msg="Sanctioned worktree (ALLOW_PARALLEL_WORKTREE=1). Remember to clean up when done: git worktree remove <path> && git worktree prune."
    fi
  else
    # Fail-closed BLOCK — single-folder doctrine forbids ad-hoc worktrees.
    reason="🚫 Blocked: 'git worktree add' is disabled by single-folder doctrine (.claude/rules/worktree-discipline.md). The default is ONE folder with feature branches inside it — 'git worktree list' stays at 1. To start a job: git switch -c feat/<slug> origin/main (stash unrelated WIP first). If you GENUINELY need a parallel worktree (clean base when the primary clone is occupied, or /build-with-agent-team via Agent isolation), opt in per-command with the inline prefix:  ALLOW_PARALLEL_WORKTREE=1 git worktree add <path> <ref>  — and remove it when done (git worktree remove + git worktree prune)."
    jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    exit 0
  fi
fi

if [ -z "$msg" ]; then
  echo '{}'
else
  jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
fi

# --- self-test: exercise as a child process (per shell-portability.md rule 7) ---
# Usage: bash worktree-guard.sh --self-test
# (handled at top via re-exec so the normal stdin path stays clean)
