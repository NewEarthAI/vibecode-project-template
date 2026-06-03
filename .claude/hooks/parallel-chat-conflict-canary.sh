#!/usr/bin/env bash
# parallel-chat-conflict-canary.sh — SessionStart proactive collision warner.
#
# WHY THIS EXISTS: this script was registered as a SessionStart hook in both
# .claude/settings.json and .claude/settings.local.json but the file never
# existed — so a repo could register this SessionStart hook but ship without the script,
# starting every session with NO parallel-collision
# protection (Neutral Analyst live-bug finding, council 2026-05-19). This is
# the missing implementation, restored with the session-coordination layer's
# file-overlap logic in proactive, warn-only form.
#
# WHAT IT DOES: at session start, looks across this repo's git worktrees and
# warns — in plain English, on stdout (SessionStart injects stdout as context)
# — if the SAME file is being changed in two worktrees at once. That is the
# silent-corruption case: whichever session commits second shadows the other.
#
# CONTRACT: SessionStart hook, timeout 5s. It is WARN-ONLY. It never blocks,
# never mutates, and always exits 0 — a canary that fails the session start is
# worse than no canary. Self-contained (no dependency on /where being installed).
# Tool-blind: reads git only; identical from terminal, Cursor ext, or cmux.

set -uo pipefail

# Always succeed — a broken canary must not break session start.
# Clean the temp file on EVERY exit path (the trap fires on errors too, so a
# bare `rm -f` after the loop would leak on any mid-script failure — and a
# leaked predictable-name temp could cross-contaminate a later session's
# collision data; code-council 2026-05-19 IMPORTANT).
trap 'rm -f "${pairs_tmp:-}"; exit 0' EXIT

repo="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$repo" ] || exit 0
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Enumerate worktree paths + branches (porcelain). 1-command list, fast.
paths=(); branches=(); cp=""; cb=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) [ -n "$cp" ] && { paths+=("$cp"); branches+=("$cb"); }
                  cp="${line#worktree }"; cb="(detached)" ;;
    "branch refs/heads/"*) cb="${line#branch refs/heads/}" ;;
    "") [ -n "$cp" ] && { paths+=("$cp"); branches+=("$cb"); }; cp=""; cb="" ;;
  esac
done < <(git -C "$repo" worktree list --porcelain 2>/dev/null)
[ -n "$cp" ] && { paths+=("$cp"); branches+=("$cb"); }

n="${#paths[@]}"
[ "$n" -ge 2 ] || exit 0   # no parallel worktrees → nothing to warn about

pairs_tmp="$(mktemp 2>/dev/null || echo "/tmp/canary-pairs.$$.$RANDOM")"
: > "$pairs_tmp"
i=0
while [ "$i" -lt "$n" ]; do
  w="${paths[$i]}"; wb="${branches[$i]}"; i=$((i + 1))
  [ -d "$w" ] || continue
  while IFS= read -r f; do
    # file<TAB>worktree-path<TAB>branch — count on the unique worktree path so
    # two *detached* worktrees touching the same file are still caught
    # (branch-keyed counting deduped them; code-council 2026-05-19 R2).
    [ -n "$f" ] && printf '%s\t%s\t%s\n' "$f" "$w" "$wb" >> "$pairs_tmp"
  done < <(git -C "$w" diff --name-only HEAD 2>/dev/null)
done

# SINGLE awk pass — O(P), one process. (Was an O(F·P) per-file grep loop that
# could exceed the 5s SessionStart timeout on a large fleet, get killed, and
# via `trap exit 0` start the session with NO warning — silent protection
# loss, code-council 2026-05-19 CRITICAL C8.) Collides if >=2 distinct worktrees.
collisions=""
while IFS="$(printf '\t')" read -r f wlist; do
  [ -n "$f" ] || continue
  collisions="$collisions
   • $f — being changed in $(printf '%s' "$wlist" | sed 's/, / and /g')"
done < <(awk -F'\t' '
  { wk=$1 SUBSEP $2
    if (!(wk in seenwt)) { seenwt[wk]=1; cnt[$1]++ }
    bk=$1 SUBSEP $3
    if (!(bk in seenbr)) { seenbr[bk]=1
      if (brs[$1]=="") brs[$1]=$3; else brs[$1]=brs[$1] ", " $3 } }
  END { for (ff in cnt) if (cnt[ff]>=2) print ff "\t" brs[ff] }
' "$pairs_tmp" 2>/dev/null)
rm -f "$pairs_tmp"

if [ -n "$collisions" ]; then
  echo "⚠️  PARALLEL-SESSION COLLISION WARNING (this repo)"
  echo "The same file is being edited in two worktrees at once. Whichever session"
  echo "commits second will silently overwrite the other's changes:"
  echo "$collisions"
  echo
  echo "Reconcile before doing code work here — finish or stash one side, or"
  echo "consolidate the change into a single worktree. Run /where for the full picture."
fi
exit 0
