#!/usr/bin/env bash
# sweep-stale-worktrees.sh — the guarded worktree janitor.
#
# Removes a git worktree ONLY if ALL FOUR independent checks pass:
#   1. CLEAN     — `git -C <wt> status --porcelain` is empty (no uncommitted work)
#   2. MERGED    — its branch is fully merged into origin's default branch
#   3. OLD       — its last commit is older than N days (default 7, --days N)
#   4. HEARTBEAT — no session has touched it in STALE_HOURS (default 48,
#                  --stale-hours N). If NO heartbeat file exists, the worktree
#                  is treated as LIVE and NEVER removed (fail safe).
#
# ARMED 2026-05-25 — CHECK 4 was rewritten from PID-liveness to heartbeat-
# freshness (council 2026-05-25). The session-start hook
# (sessionstart-context-aggregator.sh) now writes a UTC timestamp to
# `<primary>/.claude/worktrees/<basename>.heartbeat` every session start. This
# script reads that timestamp: a worktree untouched by any session for >
# STALE_HOURS is heartbeat-STALE, and — only in combination with clean+merged+
# old — eligible for removal under --apply.
#
# WHY NOT PID: a SessionStart hook is a throwaway subprocess; its $$ dies
# instantly, so PID-liveness would mark EVERY worktree dead. Timestamp-freshness
# is the correct cross-boundary signal (the pattern cross-chat-collision-
# detect.sh already chose).
#
# GRACE (council 2026-05-25, option b): a worktree with NO heartbeat file —
# i.e. one that predates the heartbeat-writer, or has never had a session — is
# treated as LIVE and never auto-removed. The heartbeat file IS the "born into
# the heartbeat era" marker, so pre-existing worktrees stay manual-only with no
# unreliable mtime guessing. The 23 worktrees that existed when this shipped are
# cleared by a one-time manual review, not by --apply.
#
# FAIL-SAFE PARSE: an empty / non-numeric / future-dated heartbeat is treated
# as LIVE (unknown), never as ancient-eligible — a corrupt file can never tip
# toward deletion.
#
# A FIFTH gate runs FIRST, before anything else: a disk-pressure pre-flight.
# At >=90% on the data volume, APFS copy-on-write degrades and `git worktree
# remove` can corrupt the shared `.git`; the script halts loudly and does
# nothing (operational-guardrails.md §Disk Pressure).
#
# Default mode is DRY-RUN: it prints what it WOULD remove and removes nothing.
# `--apply` is required to actually remove. It is NEVER a blind cron — invoke
# it manually or as an explicit post-`/ship` step.
#
# Before any real removal, the worktree's identity (path, branch, HEAD sha) is
# snapshotted so the worktree can be re-created (operational-guardrails.md
# §Snapshot Before Destructive Ops).
#
# Exit codes:
#   0 — ran successfully (dry-run, or --apply with all removals done/none needed)
#   1 — disk-pressure halt (did nothing)
#   2 — not a git repo / no repos resolvable
#   3 — --apply hit an error removing at least one worktree (others still tried)
#
# Usage:
#   bash sweep-stale-worktrees.sh                 # dry-run, current repo
#   bash sweep-stale-worktrees.sh --days 14       # change the OLD (commit-age) threshold
#   bash sweep-stale-worktrees.sh --stale-hours 72 # change the HEARTBEAT-stale threshold (default 48)
#   bash sweep-stale-worktrees.sh --all           # dry-run across known repos
#   bash sweep-stale-worktrees.sh --apply         # actually remove (current repo)
#   bash sweep-stale-worktrees.sh --all --apply   # actually remove, all repos
#
# --apply is HUMAN-INVOKE ONLY (council 2026-05-25): every automated surface
# (/daily-plan, post-/ship, /autovibe) shows the dry-run "WOULD remove" list;
# actual removal always requires a human to type --apply. NEVER a blind cron.

set -uo pipefail   # NOT -e — keep going past per-worktree failures

DAYS=7
SELF_TEST=0
STALE_HOURS=48   # heartbeat-staleness threshold (council 2026-05-25). A
                 # worktree is heartbeat-STALE only if no session touched it in
                 # this many hours. 48h comfortably exceeds any single-session
                 # run + overnight/weekend gap; the clean+merged+old gates are
                 # the primary safety, heartbeat-staleness is the "nobody's
                 # sitting in it" secondary check.
APPLY=0
ALL=0
# Proper shift-based parser — the old `for arg` loop set DAYS from ANY bare
# number anywhere on the line (e.g. `--apply 14`), and `--days 0` silently
# weakened the OLD gate (code-council 2026-05-19, 3-agent consensus).
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --all)   ALL=1; shift ;;
    --days)  DAYS="${2:-7}"; shift; [ "$#" -gt 0 ] && shift ;;
    --days=*) DAYS="${1#--days=}"; shift ;;
    --stale-hours)   STALE_HOURS="${2:-48}"; shift; [ "$#" -gt 0 ] && shift ;;
    --stale-hours=*) STALE_HOURS="${1#--stale-hours=}"; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    *) echo "sweep: unknown arg '$1' (ignored)" >&2; shift ;;
  esac
done
# normalise DAYS and enforce a hard floor of 1 — DAYS=0 would let a worktree
# whose last commit is one second old pass the OLD gate.
DAYS=$(printf '%s' "$DAYS" | tr -dc '0-9' | head -c 4); DAYS=${DAYS:-7}
if [ "$DAYS" -lt 1 ]; then
  echo "sweep: --days must be >= 1 (got 0); using 7." >&2
  DAYS=7
fi
# normalise STALE_HOURS, hard floor of 6 — anything shorter risks flagging an
# actively-running long session (a session writes a heartbeat only at START,
# so a multi-hour unattended run writes none mid-flight; 6h is the absolute
# minimum that survives a realistic run window).
STALE_HOURS=$(printf '%s' "$STALE_HOURS" | tr -dc '0-9' | head -c 4); STALE_HOURS=${STALE_HOURS:-48}
if [ "$STALE_HOURS" -lt 6 ]; then
  echo "sweep: --stale-hours must be >= 6 (got <6); using 48." >&2
  STALE_HOURS=48
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"

# ---- SELF-TEST: heartbeat-staleness decision + fail-safe parse -----------------
# Proves the armed Check 4 logic in isolation (the part most likely to regress):
# fresh heartbeat → LIVE; stale heartbeat → eligible; empty/garbage/future →
# LIVE (fail safe). Runs entirely on temp files, touches no real worktree.
#   bash sweep-stale-worktrees.sh --self-test
if [ "$SELF_TEST" -eq 1 ]; then
  pass=0; fail=0
  echo "sweep-stale-worktrees self-test (heartbeat Check 4)"
  echo "==================================================="
  st_check() { if [ "$2" = "true" ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }

  # The decision fn mirrors Check 4's heartbeat branch EXACTLY. Returns:
  #   "STALE" | "LIVE" — given a heartbeat file path + now + threshold-hours.
  hb_decide() {
    local f="$1" now="$2" hrs="$3"
    [ -f "$f" ] || { echo "LIVE"; return; }              # no file → grace, LIVE
    local ts; ts="$(tr -dc '0-9' < "$f" 2>/dev/null | head -c 12)"
    [ -n "$ts" ] || { echo "LIVE"; return; }             # empty/garbage → LIVE
    local age=$(( now - ts )); local cut=$(( hrs * 3600 ))
    if [ "$age" -lt 0 ]; then echo "LIVE"; return; fi     # future-dated → LIVE
    if [ "$age" -lt "$cut" ]; then echo "LIVE"; else echo "STALE"; fi
  }

  st_now=$(date -u +%s)
  st_tmp="$(mktemp -d 2>/dev/null || echo /tmp/sweep-st.$$)"; mkdir -p "$st_tmp"

  # 1. fresh heartbeat (1h ago) at 48h threshold → LIVE
  printf '%s\n' "$((st_now - 3600))" > "$st_tmp/fresh.hb"
  st_check "fresh heartbeat (1h) → LIVE" "$([ "$(hb_decide "$st_tmp/fresh.hb" "$st_now" 48)" = LIVE ] && echo true || echo false)"

  # 2. stale heartbeat (50h ago) at 48h threshold → STALE
  printf '%s\n' "$((st_now - 50*3600))" > "$st_tmp/stale.hb"
  st_check "stale heartbeat (50h) → STALE" "$([ "$(hb_decide "$st_tmp/stale.hb" "$st_now" 48)" = STALE ] && echo true || echo false)"

  # 3. boundary: 47h < 48h → LIVE; 49h > 48h → STALE
  printf '%s\n' "$((st_now - 47*3600))" > "$st_tmp/b47.hb"
  st_check "47h < 48h threshold → LIVE" "$([ "$(hb_decide "$st_tmp/b47.hb" "$st_now" 48)" = LIVE ] && echo true || echo false)"
  printf '%s\n' "$((st_now - 49*3600))" > "$st_tmp/b49.hb"
  st_check "49h > 48h threshold → STALE" "$([ "$(hb_decide "$st_tmp/b49.hb" "$st_now" 48)" = STALE ] && echo true || echo false)"

  # 4. FAIL-SAFE: no file → LIVE (grace option b)
  st_check "no heartbeat file → LIVE (grace)" "$([ "$(hb_decide "$st_tmp/nope.hb" "$st_now" 48)" = LIVE ] && echo true || echo false)"

  # 5. FAIL-SAFE: empty file → LIVE (NOT ancient-eligible)
  : > "$st_tmp/empty.hb"
  st_check "empty heartbeat → LIVE (fail safe)" "$([ "$(hb_decide "$st_tmp/empty.hb" "$st_now" 48)" = LIVE ] && echo true || echo false)"

  # 6. FAIL-SAFE: garbage content → LIVE
  printf 'not-a-timestamp\n' > "$st_tmp/garbage.hb"
  st_check "garbage heartbeat → LIVE (fail safe)" "$([ "$(hb_decide "$st_tmp/garbage.hb" "$st_now" 48)" = LIVE ] && echo true || echo false)"

  # 7. FAIL-SAFE: future-dated (clock skew) → LIVE
  printf '%s\n' "$((st_now + 10*3600))" > "$st_tmp/future.hb"
  st_check "future-dated heartbeat → LIVE (clock skew)" "$([ "$(hb_decide "$st_tmp/future.hb" "$st_now" 48)" = LIVE ] && echo true || echo false)"

  # 8. STALE_HOURS floor: a parsed value < 6 must be rejected (already enforced
  #    above at parse time; assert the live value is >= 6).
  st_check "STALE_HOURS >= 6 floor enforced (value: $STALE_HOURS)" "$([ "$STALE_HOURS" -ge 6 ] && echo true || echo false)"

  rm -rf "$st_tmp"
  echo "==================================================="
  if [ "$fail" -eq 0 ]; then
    echo "sweep-stale-worktrees self-test: ALL PASS ($pass/$((pass+fail)))"
    exit 0
  else
    echo "sweep-stale-worktrees self-test: $fail FAILURES ($pass/$((pass+fail)))" >&2
    exit 1
  fi
fi

# ---- GATE 0 (FIRST): disk-pressure pre-flight ---------------------------------
# Capture rc WITHOUT a pipe — a pipe would eat awk's exit (shell-portability §1).
df_tmp="$(mktemp 2>/dev/null || echo "/tmp/sweep-df.$$.$RANDOM")"
df /System/Volumes/Data > "$df_tmp" 2>/dev/null || df / > "$df_tmp" 2>/dev/null
awk 'NR==2 {gsub(/%/,"",$5); if ($5+0 >= 90) exit 1}' "$df_tmp"
disk_rc=$?
use_pct=$(awk 'NR==2 {gsub(/%/,"",$5); print $5+0}' "$df_tmp" 2>/dev/null)
rm -f "$df_tmp"
if [ "$disk_rc" -ne 0 ]; then
  echo "🛑 sweep HALTED — disk is ${use_pct:-?}% full (>=90%)."
  echo "   At this level APFS copy-on-write degrades and 'git worktree remove'"
  echo "   can corrupt the shared .git. Doing NOTHING. Free 5GB+ first, then re-run."
  exit 1
fi

# ---- repo set -----------------------------------------------------------------
# Template default: NONE hard-coded. `--all` reads `.claude/where-repos.txt`
# (one absolute repo path per line); fill DEFAULT_REPOS below in a project if
# you prefer (project-local, never templatised). With neither, `--all` falls
# back to the current repo — exactly like a plain invocation.
DEFAULT_REPOS=()
repos=()
repo_list_file="$SCRIPT_DIR/../../../where-repos.txt"
if [ "$ALL" -eq 1 ]; then
  if [ "${#DEFAULT_REPOS[@]}" -gt 0 ]; then
    for r in "${DEFAULT_REPOS[@]}"; do
      git -C "$r" rev-parse --is-inside-work-tree >/dev/null 2>&1 && repos+=("$r")
    done
  elif [ -f "$repo_list_file" ]; then
    while IFS= read -r line; do
      case "$line" in ""|\#*) continue ;; esac
      git -C "$line" rev-parse --is-inside-work-tree >/dev/null 2>&1 && repos+=("$line")
    done < "$repo_list_file"
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repos+=("$(git rev-parse --show-toplevel 2>/dev/null)")
  fi
else
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repos+=("$(git rev-parse --show-toplevel 2>/dev/null)")
  fi
fi
if [ "${#repos[@]}" -eq 0 ]; then
  echo "sweep: not inside a git repo and --all resolved nothing." >&2
  exit 2
fi

now_epoch=$(date +%s)
cutoff=$(( DAYS * 86400 ))
mode_label="DRY-RUN (nothing will be removed; pass --apply to act)"
[ "$APPLY" -eq 1 ] && mode_label="APPLY (worktrees that pass all 4 checks WILL be removed)"
echo "🧹 sweep-stale-worktrees — $mode_label"
echo "   OLD threshold: $DAYS days   ·   heartbeat-stale threshold: $STALE_HOURS h"
echo

any_remove_error=0
would_remove_total=0

for repo in "${repos[@]}"; do
  primary="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"
  echo "📁 $(basename "$repo")"

  # default branch (origin/HEAD → main → master)
  defref=$(git -C "$repo" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)
  if [ -n "$defref" ]; then defbr="${defref##*/}"; else defbr="main"; fi

  # enumerate worktrees (porcelain)
  paths=(); branches=()
  cp=""; cb=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) [ -n "$cp" ] && { paths+=("$cp"); branches+=("$cb"); }
                    cp="${line#worktree }"; cb="(detached)" ;;
      "branch refs/heads/"*) cb="${line#branch refs/heads/}" ;;
      "") [ -n "$cp" ] && { paths+=("$cp"); branches+=("$cb"); }; cp=""; cb="" ;;
    esac
  done < <(git -C "$repo" worktree list --porcelain 2>/dev/null)
  [ -n "$cp" ] && { paths+=("$cp"); branches+=("$cb"); }

  i=0
  n="${#paths[@]}"
  while [ "$i" -lt "$n" ]; do
    wt="${paths[$i]}"; br="${branches[$i]}"; i=$((i + 1))

    if [ ! -d "$wt" ]; then
      echo "   • $br — folder already gone on disk; run 'git -C \"$repo\" worktree prune' to tidy metadata"
      continue
    fi
    # never the primary checkout — compare PHYSICAL paths (pwd -P resolves
    # symlinks), so a symlinked repo root cannot make the guard fall through
    # and target the main worktree (code-council 2026-05-19 C4).
    primary_real="$(cd "$primary" 2>/dev/null && pwd -P)"
    wt_real="$(cd "$wt" 2>/dev/null && pwd -P)"
    if [ -n "$wt_real" ] && [ "$wt_real" = "$primary_real" ]; then continue; fi
    if [ "$wt" = "$primary" ]; then continue; fi

    reasons=""

    # CHECK 1 — CLEAN. Capture git-status rc WITHOUT a pipe (a pipe eats $?,
    # and a git failure would yield count 0 = false CLEAN = one gate closer
    # to removal; code-council 2026-05-19 CRITICAL C2). Unreadable → DIRTY.
    st_tmp="$(mktemp 2>/dev/null || echo "/tmp/sweep-st.$$.$RANDOM")"
    git -C "$wt" status --porcelain > "$st_tmp" 2>/dev/null
    st_rc=$?
    if [ "$st_rc" -ne 0 ]; then
      reasons="$reasons working tree unreadable (git status rc=$st_rc — treated as dirty, fail safe);"
    else
      dirty=$(grep -c '^.\{1,\}' "$st_tmp" 2>/dev/null)
      dirty=$(printf '%s' "$dirty" | tr -dc '0-9' | head -c 6); dirty=${dirty:-0}
      [ "$dirty" -gt 0 ] && reasons="$reasons has $dirty uncommitted change(s);"
    fi
    rm -f "$st_tmp"

    # CHECK 2 — MERGED into origin default
    merged_ok=0
    if [ "$br" != "(detached)" ]; then
      # commits on this branch not yet on origin/<default>. Capture rc: if
      # origin/$defbr is absent (no fetch ever ran) rev-list errors — the
      # SAFE default is "keep", but it must NOT be silent (code-council
      # 2026-05-19 IMPORTANT).
      rl_tmp="$(mktemp 2>/dev/null || echo "/tmp/sweep-rl.$$.$RANDOM")"
      git -C "$repo" rev-list --count "origin/$defbr..$br" > "$rl_tmp" 2>/dev/null
      rl_rc=$?
      if [ "$rl_rc" -ne 0 ]; then
        reasons="$reasons cannot verify merge — origin/$defbr unreachable (run 'git fetch'); treated as unmerged;"
      else
        unmerged=$(tr -dc '0-9' < "$rl_tmp" 2>/dev/null | head -c 6); unmerged=${unmerged:-1}
        [ "$unmerged" -eq 0 ] && merged_ok=1
      fi
      rm -f "$rl_tmp"
    fi
    [ "$merged_ok" -ne 1 ] && case "$reasons" in *"cannot verify merge"*) : ;; *) reasons="$reasons not fully merged into origin/$defbr;" ;; esac

    # CHECK 3 — OLD
    last_ct=$(git -C "$wt" log -1 --format=%ct 2>/dev/null)
    last_ct=$(printf '%s' "$last_ct" | tr -dc '0-9' | head -c 12); last_ct=${last_ct:-$now_epoch}
    age=$(( now_epoch - last_ct ))
    [ "$age" -lt "$cutoff" ] && reasons="$reasons last commit younger than $DAYS days;"

    # CHECK 4 — HEARTBEAT-STALE (armed 2026-05-25; replaces the PID check).
    #
    # The session-start hook (sessionstart-context-aggregator.sh) writes a UTC
    # epoch timestamp to `<primary>/.claude/worktrees/<basename>.heartbeat`
    # every session start. This check reads that file and asks: "has any session
    # touched this worktree in the last STALE_HOURS?" PID was the WRONG signal —
    # a SessionStart hook is a throwaway subprocess whose $$ dies instantly;
    # timestamp-freshness is the correct cross-boundary signal (mirrors
    # cross-chat-collision-detect.sh's timestamp-marker choice).
    #
    # PATH AGREEMENT (the critical wiring invariant): writer and reader MUST use
    # the SAME dir. The writer resolves the primary root via
    # `git rev-parse --git-common-dir` (the shared .git, identical for every
    # worktree) → its parent. The janitor runs from the primary `$repo`, so
    # `$repo/.claude/worktrees/` IS that same dir — but we re-resolve via
    # common-dir defensively so a symlinked/relative `$repo` cannot diverge.
    #
    # GRACE (council 2026-05-25, option b): a worktree with NO heartbeat file is
    # treated as LIVE and NEVER auto-removed. The heartbeat file itself is the
    # "born into the heartbeat era" marker — a pre-existing worktree has none
    # and only ever gets one if a session opens it (at which point it is
    # genuinely live). So pre-existing folders stay manual-only with zero
    # unreliable mtime guessing; only worktrees that HAVE had a session AND
    # gone STALE_HOURS-stale become eligible.
    #
    # FAIL-SAFE PARSE: an empty/garbage/future-dated heartbeat is treated as
    # LIVE (unknown), NEVER as ancient-eligible — a corrupt file must never tip
    # toward deletion.
    wt_gitdir="$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null)"
    # Resolve the shared heartbeat dir from the WORKTREE's own common-dir so it
    # always matches the writer, regardless of how $repo was passed.
    hb_common="$(git -C "$wt" rev-parse --git-common-dir 2>/dev/null)"
    hb_root=""
    if [ -n "$hb_common" ]; then
      case "$hb_common" in
        /*) hb_root="$(cd "$(dirname "$hb_common")" 2>/dev/null && pwd)" ;;
        *)  hb_root="$(cd "$wt/$(dirname "$hb_common")" 2>/dev/null && pwd)" ;;
      esac
    fi
    [ -n "$hb_root" ] || hb_root="$repo"
    hbfile="$hb_root/.claude/worktrees/$(basename "$wt").heartbeat"

    hb_stale=0
    if [ -n "$wt_gitdir" ] && [ -f "$wt_gitdir/index.lock" ]; then
      reasons="$reasons git index is locked (an operation is in progress);"
    elif [ -f "$hbfile" ]; then
      # Defensive parse: digits only; a non-numeric/empty file yields "" →
      # treated as LIVE (fail safe), NOT 0 (which would read as 1970 = ancient).
      hb_ts="$(tr -dc '0-9' < "$hbfile" 2>/dev/null | head -c 12)"
      if [ -z "$hb_ts" ]; then
        reasons="$reasons heartbeat file unreadable/empty (treated as LIVE — fail safe);"
      else
        hb_age=$(( now_epoch - hb_ts ))
        hb_cutoff=$(( STALE_HOURS * 3600 ))
        if [ "$hb_age" -lt 0 ]; then
          # Future-dated (clock skew) — cannot be stale; treat as LIVE.
          reasons="$reasons heartbeat is future-dated (clock skew — treated as LIVE);"
        elif [ "$hb_age" -lt "$hb_cutoff" ]; then
          reasons="$reasons a session touched it within the last $STALE_HOURS h;"
        else
          hb_stale=1
        fi
      fi
    else
      # No heartbeat file — pre-existing / never-session'd worktree. Grace
      # option b: treat as LIVE, never auto-remove (clear these manually).
      reasons="$reasons no session heartbeat recorded (pre-existing — treated as LIVE, fail safe);"
    fi

    if [ -z "$reasons" ] && [ "$hb_stale" -eq 1 ]; then
      would_remove_total=$((would_remove_total + 1))
      if [ "$APPLY" -eq 1 ]; then
        # Snapshot identity for recoverability — and VERIFY it actually wrote
        # BEFORE the irreversible remove. A silently-failed snapshot (disk
        # full / $HOME unwritable) must abort the removal, not proceed without
        # a recovery record (code-council 2026-05-19 CRITICAL C5).
        snap_dir="$HOME/$(basename "$repo")-snapshots/$(date +%Y%m%d-%H%M%S)-sweep-$(basename "$wt")"
        mkdir -p "$snap_dir" 2>/dev/null
        {
          echo "# Sweep removal snapshot"
          echo "removed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
          echo "repo: $repo"
          echo "worktree_path: $wt"
          echo "branch: $br"
          echo "head_sha: $(git -C "$wt" rev-parse HEAD 2>/dev/null)"
          echo "recreate: git -C \"$repo\" worktree add \"$wt\" \"$br\""
        } > "$snap_dir/MANIFEST.md" 2>/dev/null
        rm_err="$(mktemp 2>/dev/null || echo "/tmp/sweep-rm.$$.$RANDOM")"
        if [ ! -s "$snap_dir/MANIFEST.md" ]; then
          echo "   ⛔ keeping $br — could NOT write the recovery snapshot ($snap_dir); refusing to remove without it"
          any_remove_error=1
        elif git -C "$repo" worktree remove "$wt" 2>"$rm_err"; then
          echo "   ✅ removed: $br  (clean ∧ merged ∧ >$DAYS days ∧ heartbeat stale >$STALE_HOURS h) — identity saved for re-create"
        else
          echo "   ⚠️ tried to remove $br but git refused: $(head -1 "$rm_err" 2>/dev/null)"
          any_remove_error=1
        fi
        rm -f "$rm_err"
      else
        echo "   🗑️  WOULD remove: $br  (clean ∧ merged ∧ >$DAYS days ∧ heartbeat stale >$STALE_HOURS h)"
      fi
    else
      # trim leading space, present the keep-reason in plain English
      keep="$(printf '%s' "$reasons" | sed 's/^ //; s/;$//; s/;/, /g')"
      [ -z "$keep" ] && keep="held back (no stale heartbeat — treated as live)"
      echo "   • keeping $br — $keep"
    fi
  done
  echo
done

echo "────────────────────────────────────────────"
if [ "$APPLY" -eq 1 ]; then
  if [ "$any_remove_error" -eq 1 ]; then
    echo "Done with errors — at least one removal was refused by git. See lines above."
    exit 3
  fi
  echo "Done. Removed $would_remove_total worktree(s). Every removal has a re-create snapshot."
else
  echo "Dry-run complete. $would_remove_total worktree(s) WOULD be removed."
  echo "Nothing was touched. Re-run with --apply to act."
fi
exit 0
