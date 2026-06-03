#!/usr/bin/env bash
# where.sh — the live fleet state surface for parallel Claude Code sessions.
#
# Answers, in plain English, "where is all my work right now?" across every known
# NewEarth repo. Every line is derived from a FRESH git read at invocation time:
# no written registry, no daemon, no cache. Git is the only source of truth that
# cannot lie (council 2026-05-19).
#
# COMPOSE, DON'T REBUILD: per-worktree CLEAN/DIRTY/STALE/DETACHED classification is
# delegated to verify-shipped/scripts/walk-worktrees.sh (the battle-tested walker,
# this repo's confirmed "where is everything" core). The ONLY net-new git read this
# script performs itself is `git diff --name-only HEAD` per worktree, for the
# file-level overlap intersection — a datum walk-worktrees deliberately does not
# emit and which branch-level state misses (Edge Case Finder, council 2026-05-19).
#
# TOOL-BLIND: reads git only. Output is identical whether this session was launched
# by the Cursor Claude Code extension, cmux, or a plain terminal. There is NO tool
# or session detection anywhere in this script, by design.
#
# READ-ONLY: never writes, never removes, never mutates. The guarded janitor is the
# sibling sweep-stale-worktrees.sh.
#
# Exit codes:
#   0 — ran; no file-level collision detected
#   1 — ran; at least one file-level COLLISION detected (operator must reconcile)
#   2 — could not run (no repos resolvable)
#
# Usage:
#   bash .claude/skills/where/scripts/where.sh
#   WHERE_REPOS="/path/a:/path/b" bash .claude/skills/where/scripts/where.sh
# A .claude/where-repos.txt (one absolute repo path per line) overrides the default
# set if present. That file is plain config — it drives no automated decision.

set -uo pipefail   # NOT -e — keep walking past per-repo failures

# --- resolve our own dir so the composed walker is found regardless of cwd -------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
WALKER="$SCRIPT_DIR/../../verify-shipped/scripts/walk-worktrees.sh"

# --- numeric normaliser (shell-portability.md §6) -------------------------------
to_int() {
  local raw="${1:-0}"
  raw=$(printf '%s' "$raw" | tr -dc '0-9' | head -c 6)
  printf '%s' "${raw:-0}"
}

# --- repo set resolution --------------------------------------------------------
# Template default: NONE hard-coded. Add the repos you run in parallel by EITHER
# creating `.claude/where-repos.txt` (one absolute repo path per line) OR
# exporting `WHERE_REPOS=/path/a:/path/b`. With neither set, /where reports the
# current repo only. (In a project you may also fill DEFAULT_REPOS below with
# your fleet's absolute paths — that file is project-local, never templatised.)
DEFAULT_REPOS=()
repos=()
repo_list_file="$SCRIPT_DIR/../../../where-repos.txt"   # .claude/where-repos.txt
if [ -n "${WHERE_REPOS:-}" ]; then
  # colon-separated override. `set -f` disables globbing so a path containing
  # `*` or `?` is NOT expanded against the filesystem during the split
  # (code-council 2026-05-19 IMPORTANT).
  OLD_IFS="$IFS"; IFS=':'; set -f
  for r in $WHERE_REPOS; do [ -n "$r" ] && repos+=("$r"); done
  set +f; IFS="$OLD_IFS"
elif [ -f "$repo_list_file" ]; then
  while IFS= read -r line; do
    case "$line" in ""|\#*) continue ;; esac
    repos+=("$line")
  done < "$repo_list_file"
elif [ "${#DEFAULT_REPOS[@]}" -gt 0 ]; then
  repos=("${DEFAULT_REPOS[@]}")
else
  # Generic fallback: just this repo.
  here="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$here" ] && repos+=("$here")
fi

# Keep only existing git repos
valid_repos=()
for r in "${repos[@]:-}"; do
  [ -n "$r" ] || continue
  if [ -d "$r/.git" ] || git -C "$r" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    valid_repos+=("$r")
  fi
done

if [ "${#valid_repos[@]}" -eq 0 ]; then
  echo "📊 Where everything is right now"
  echo
  echo "Couldn't find any of the known repos on this machine. Nothing to report."
  exit 2
fi

# --- friendly repo label (a name, not a raw path — layman voice) ----------------
friendly_name() {
  local p="$1" base
  base="$(basename "$p")"
  case "$base" in
    *)                             echo "$base" ;;
  esac
}

# --- default (production) branch of a repo --------------------------------------
default_branch() {
  local repo="$1" ref
  ref=$(git -C "$repo" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)
  if [ -n "$ref" ]; then
    echo "${ref##*/}"; return 0
  fi
  for cand in main master; do
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$cand" 2>/dev/null; then
      echo "$cand"; return 0
    fi
  done
  echo "main"
}

# --- continuation lookup per worktree branch -----------------------------------
# Per .claude/rules/decide-dont-menu-extended.md + the bring-this-all-together
# plan Layer 2. Reads the most recent continuation file in continuations/ whose
# filename contains the branch-slug. Surfaces impl_status + the first 80 chars
# of next_session_mandate. Cheap, fail-safe — never errors.
#
# Args: $1 = worktree path, $2 = branch name
# Prints a single indented line if a continuation matches, OR nothing.
continuation_for_worktree() {
  local wt="$1" br="$2"
  local cont_dir="$wt/continuations"
  [ -d "$cont_dir" ] || return 0

  # Derive a search slug from branch: lowercase, last 2 path-segments, replace
  # /-_ with space so we can grep liberally
  local slug
  slug=$(printf '%s' "$br" | tr 'A-Z' 'a-z' | sed 's|.*/||' | tr '-_' ' ' | head -c 80)
  [ -z "$slug" ] && return 0

  # park/<reason> branches: surface the parked state and exit early
  case "$br" in
    park/*)
      local reason="${br#park/}"
      echo "      🅿️ Parked: ${reason}"
      return 0
      ;;
  esac

  # Find most recently modified continuation in this worktree's continuations/
  # whose filename contains any token from the slug
  local best_file=""
  local best_mtime=0
  local first_token
  first_token=$(printf '%s' "$slug" | awk '{print $1}')
  [ -z "$first_token" ] && first_token="$slug"

  # Use a fixed-string grep against filenames; iterate top 20 most-recent files
  while IFS= read -r cand; do
    [ -z "$cand" ] && continue
    local base
    base=$(basename "$cand" | tr 'A-Z' 'a-z')
    case "$base" in
      *"$first_token"*)
        local mt
        mt=$(stat -f %m "$cand" 2>/dev/null || stat -c %Y "$cand" 2>/dev/null || echo 0)
        if [ "$mt" -gt "$best_mtime" ]; then
          best_mtime="$mt"
          best_file="$cand"
        fi
        ;;
    esac
  done < <(ls -t "$cont_dir"/*.md 2>/dev/null | head -50)

  if [ -z "$best_file" ]; then
    # No matching continuation; let the caller decide whether to flag.
    return 0
  fi

  # Extract impl_status from YAML frontmatter (the canonical convention)
  local status
  status=$(awk '
    /^---[[:space:]]*$/ { in_fm = !in_fm; next }
    in_fm && /^impl_status:/ { sub(/^impl_status:[[:space:]]*/,""); gsub(/"/,""); print; exit }
  ' "$best_file" 2>/dev/null)
  [ -z "$status" ] && status="unknown"

  # Extract next_session_mandate (or fall back to title)
  local intent
  intent=$(awk '
    /^---[[:space:]]*$/ { in_fm = !in_fm; next }
    in_fm && /^next_session_mandate:/ {
      sub(/^next_session_mandate:[[:space:]]*/,"")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$best_file" 2>/dev/null)
  if [ -z "$intent" ]; then
    intent=$(grep -m1 -E '^# ' "$best_file" 2>/dev/null | sed 's/^# //')
  fi
  intent=$(printf '%s' "$intent" | head -c 100)
  [ -z "$intent" ] && intent="(no intent captured)"

  # Surface the auto_generated flag if present
  local auto_flag=""
  if grep -q '^auto_generated:[[:space:]]*true' "$best_file" 2>/dev/null; then
    auto_flag=" [auto]"
  fi

  local fname
  fname=$(basename "$best_file")
  echo "      📓 Intent${auto_flag}: ${intent} · status: ${status}"
  echo "         (from continuations/${fname})"
  return 0
}

# --- forgotten-flag for branches without a continuation + with uncovered work --
# Args: $1 = worktree path, $2 = branch name, $3 = "dirty" or "clean" or
#       "ahead" indicating uncovered state.
# Prints a single indented warning line if applicable, OR nothing.
forgotten_flag() {
  local wt="$1" br="$2" state="$3"
  [ "$state" = "clean" ] && return 0  # clean trees aren't forgotten

  case "$br" in
    park/*|wip/*) return 0 ;;  # deliberately parked or in-flight; no flag
  esac

  local cont_dir="$wt/continuations"
  [ -d "$cont_dir" ] || return 0

  local first_token
  first_token=$(printf '%s' "$br" | tr 'A-Z' 'a-z' | sed 's|.*/||' | tr '-_' ' ' | awk '{print $1}')
  [ -z "$first_token" ] && first_token="$br"

  # Did any continuation match? (cheap check — fail-open if no match)
  local match
  match=$(ls "$cont_dir"/*.md 2>/dev/null | tr 'A-Z' 'a-z' | grep -F -- "$first_token" | head -1)

  if [ -z "$match" ]; then
    echo "      ⚠️  No continuation written for this branch — risk of forgotten intent"
  fi
  return 0
}

echo "📊 Where everything is right now"
echo "   (read live from git this second — nothing cached, nothing that can lie)"
echo

overall_collision=0
# parallel arrays for the cross-worktree, per-repo overlap pass
declare -a COLLISION_LINES
COLLISION_LINES=()

for repo in "${valid_repos[@]}"; do
  name="$(friendly_name "$repo")"
  defbr="$(default_branch "$repo")"
  echo "📁 $name"

  # ---- composed authoritative walk (verify-shipped) --------------------------
  # Capture rc WITHOUT a pipe (shell-portability.md §1: a pipe would eat $?).
  walk_out=""
  walk_rc=0
  walker_crashed=0
  if [ -f "$WALKER" ]; then
    walk_tmp="$(mktemp 2>/dev/null || echo "/tmp/where-walk.$$.$RANDOM")"
    ( cd "$repo" 2>/dev/null && bash "$WALKER" ) > "$walk_tmp" 2>/dev/null
    walk_rc=$?
    walk_out="$(cat "$walk_tmp" 2>/dev/null)"
    rm -f "$walk_tmp"
    # walk-worktrees.sh exits 0 (all clean) or 1 (issues found) — BOTH normal.
    # Any other rc is a crash. A crashed walker with empty output would make
    # every worktree default to clean (dirty=0, ahead=0) — the exact
    # false-confidence this surface exists to prevent (code-council 2026-05-19
    # CRITICAL C1). Mark it so every worktree is surfaced as UNVERIFIED.
    if [ "$walk_rc" -ne 0 ] && [ "$walk_rc" -ne 1 ]; then
      walker_crashed=1
      echo "   ⚠️ The detailed walker exited abnormally (rc=$walk_rc) — worktree state below is UNVERIFIED, not assumed clean." >&2
    fi
  else
    echo "   ⚠️ The detailed walker isn't installed in this repo — showing a basic view."
  fi

  # ---- enumerate worktree paths + branches (1-command list, not a re-walk) ----
  # Used for: layman labelling + the net-new file-overlap pass.
  wt_paths=()
  wt_branches=()
  cur_path=""
  cur_branch=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        if [ -n "$cur_path" ]; then wt_paths+=("$cur_path"); wt_branches+=("$cur_branch"); fi
        cur_path="${line#worktree }"; cur_branch="(detached)"
        ;;
      "branch refs/heads/"*) cur_branch="${line#branch refs/heads/}" ;;
      "") if [ -n "$cur_path" ]; then wt_paths+=("$cur_path"); wt_branches+=("$cur_branch"); fi
          cur_path=""; cur_branch="" ;;
    esac
  done < <(git -C "$repo" worktree list --porcelain 2>/dev/null)
  if [ -n "$cur_path" ]; then wt_paths+=("$cur_path"); wt_branches+=("$cur_branch"); fi

  wt_count="${#wt_paths[@]}"
  if [ "$wt_count" -le 1 ]; then
    echo "   One working copy. No parallel worktrees here."
  fi

  # ---- per-worktree layman lines ---------------------------------------------
  # State is read FROM the composed walker output (walk_out) — the single source
  # of truth. where.sh does NOT run its own status/rev-list (that would be a
  # second reader that could disagree, and a reimplementation of the walk the
  # continuation says to compose). The walker emits, per path:
  #   [DIRTY]  <path> <N> uncommitted ...
  #   [STALE]  <path> on <branch>, <N> commits ahead ...
  #   [DETACHED] <path> ...
  #   [ERROR]  <path> <reason>
  # A path with NO walker line is CLEAN (the walker suppresses per-clean lines).
  walker_ok=1
  [ -f "$WALKER" ] || walker_ok=0

  idx=0
  while [ "$idx" -lt "$wt_count" ]; do
    wt="${wt_paths[$idx]}"
    br="${wt_branches[$idx]}"
    idx=$((idx + 1))
    [ -d "$wt" ] || { echo "   📄 $br — folder missing on disk (git still has a record of it; safe to ignore or sweep)"; continue; }

    # destination label
    if [ "$br" = "$defbr" ]; then
      dest="heading for live (production)"
    elif [ "$br" = "(detached)" ]; then
      dest="not on a branch (detached) — needs a human eyeball"
    else
      dest="work-in-progress branch"
    fi

    if [ "$walker_ok" -eq 1 ] && [ "$walker_crashed" -eq 1 ]; then
      # C1: composed walker crashed — DO NOT default to clean. Surface every
      # worktree as unverified so the operator eyeballs it.
      state="UNVERIFIED — the detailed walker errored; run git status here"
      echo "   📄 $br — $dest: $state"
      continue
    fi

    if [ "$walker_ok" -eq 1 ]; then
      # Match this exact path in the composed walker output (fixed-string).
      wlines="$(printf '%s\n' "$walk_out" | grep -F "$wt " 2>/dev/null)"
      dirty=0; ahead=0; detached=0; errored=0
      case "$wlines" in *"[ERROR] $wt "*) errored=1 ;; esac
      case "$wlines" in *"[DETACHED] $wt "*) detached=1 ;; esac
      d="$(printf '%s\n' "$wlines" | grep -F "[DIRTY] $wt " | head -1)"
      if [ -n "$d" ]; then
        # Extract the count via literal substring index (awk index() is NOT a
        # regex) — never embed $wt in a sed/grep regex (a path with regex
        # metacharacters would mis-extract; code-council 2026-05-19 IMPORTANT).
        dirty="$(printf '%s\n' "$d" | awk -v p="[DIRTY] $wt " '{i=index($0,p); if(i){r=substr($0,i+length(p)); print r+0; exit}}')"
        dirty=$(to_int "$dirty")
      fi
      s="$(printf '%s\n' "$wlines" | grep -F "[STALE] $wt " | head -1)"
      if [ -n "$s" ]; then
        # STALE pattern does not embed $wt — fixed " commits ahead" anchor.
        ahead="$(printf '%s' "$s" | sed -n 's/.*, \([0-9][0-9]*\) commits ahead.*/\1/p')"
        ahead=$(to_int "$ahead")
      fi

      if [ "$errored" -eq 1 ]; then
        state="couldn't read this worktree — needs a human eyeball"
      else
        state=""
        [ "$dirty" -gt 0 ] && state="$dirty unsaved change(s)"
        if [ "$ahead" -gt 0 ]; then
          [ -n "$state" ] && state="$state, "
          state="${state}${ahead} commit(s) not yet on GitHub"
        fi
        [ "$detached" -eq 1 ] && { [ -n "$state" ] && state="$state, "; state="${state}detached HEAD"; }
        # NET-NEW honesty datum: the composed walker counts STAGED changes only
        # (its dirty test is `^[^space]`), so a worktree with purely UNSTAGED or
        # untracked edits is reported clean. For the "could I lose work / am I
        # colliding" question that is a false "clean" — the exact false-confidence
        # the council forbade. We do NOT reimplement the walk; we add one
        # presence bit the walker structurally cannot see (same justification as
        # the file-overlap pass below), and only to UPGRADE an otherwise-clean
        # verdict — never to override the walker's dirty/stale counts.
        if [ -z "$state" ]; then
          # C2: capture git-status rc WITHOUT a pipe — a git failure must NOT
          # read as clean. Unreadable → surface for a human, never "clean".
          st_tmp="$(mktemp 2>/dev/null || echo "/tmp/where-st.$$.$RANDOM")"
          git -C "$wt" status --porcelain > "$st_tmp" 2>/dev/null
          st_rc=$?
          if [ "$st_rc" -ne 0 ]; then
            state="couldn't read this worktree — needs a human eyeball"
          elif [ -n "$(head -1 "$st_tmp" 2>/dev/null)" ]; then
            state="has unsaved changes not yet committed (run git status here)"
          else
            state="clean and in sync"
          fi
          rm -f "$st_tmp"
        fi
      fi
    else
      # Graceful degradation ONLY when the composed walker is genuinely absent
      # (repo without verify-shipped). Minimal irreducible read, flagged.
      # C2: capture rc WITHOUT a pipe — git failure must NOT read as clean.
      st_tmp="$(mktemp 2>/dev/null || echo "/tmp/where-stb.$$.$RANDOM")"
      git -C "$wt" status --porcelain > "$st_tmp" 2>/dev/null
      st_rc=$?
      if [ "$st_rc" -ne 0 ]; then
        state="basic view: couldn't read this worktree — needs a human eyeball"
      else
        dirty=$(grep -c '^.\{1,\}' "$st_tmp" 2>/dev/null); dirty=$(to_int "$dirty")
        state="basic view (detailed walker not installed): "
        [ "$dirty" -gt 0 ] && state="${state}${dirty} unsaved change(s)" || state="${state}no uncommitted changes"
      fi
      rm -f "$st_tmp"
    fi

    echo "   📄 $br — $dest: $state"
    # NET-NEW: surface continuation intent + forgotten flag (Layer 2 of the
    # bring-this-all-together plan). Both helpers are read-only and fail-safe.
    continuation_for_worktree "$wt" "$br" 2>/dev/null
    # Determine "dirty-or-ahead" for forgotten_flag without re-running git:
    fg_state="clean"
    case "$state" in
      *"unsaved change"*|*"not yet on GitHub"*) fg_state="dirty" ;;
    esac
    forgotten_flag "$wt" "$br" "$fg_state" 2>/dev/null
  done

  # ---- open PRs (graceful if gh unauthenticated) -----------------------------
  if command -v gh >/dev/null 2>&1; then
    pr_tmp="$(mktemp 2>/dev/null || echo "/tmp/where-pr.$$.$RANDOM")"
    ( cd "$repo" 2>/dev/null && gh pr list --state open --limit 30 ) > "$pr_tmp" 2>/dev/null
    pr_rc=$?
    if [ "$pr_rc" -eq 0 ]; then
      pr_n=$(grep -c . "$pr_tmp" 2>/dev/null); pr_n=$(to_int "$pr_n")
      if [ "$pr_n" -gt 0 ]; then
        echo "   🌐 $pr_n open pull request(s) on GitHub"
      else
        echo "   🌐 No open pull requests"
      fi
    else
      echo "   🌐 GitHub CLI not signed in here — pull-request list skipped (the worktree truth above is unaffected)"
    fi
    rm -f "$pr_tmp"
  else
    echo "   🌐 GitHub CLI not installed — pull-request list skipped (worktree truth unaffected)"
  fi

  # ---- NET-NEW: file-level overlap intersection across this repo's worktrees --
  # The silent-corruption case branch-level state misses: the SAME file being
  # changed in two worktrees at once. One commit silently shadows the other.
  if [ "$wt_count" -ge 2 ]; then
    # Build "file<TAB>branch" lines for every changed tracked file in every worktree.
    pairs_tmp="$(mktemp 2>/dev/null || echo "/tmp/where-pairs.$$.$RANDOM")"
    : > "$pairs_tmp"
    j=0
    while [ "$j" -lt "$wt_count" ]; do
      w="${wt_paths[$j]}"; wb="${wt_branches[$j]}"
      j=$((j + 1))
      [ -d "$w" ] || continue
      while IFS= read -r f; do
        # Emit file<TAB>worktree-path<TAB>branch. Keying the collision count on
        # the WORKTREE PATH (always unique) — NOT the branch — catches two
        # *detached* worktrees (both branch="(detached)") editing the same
        # file, which a branch-keyed count would dedupe and miss (code-council
        # 2026-05-19 R2 IMPORTANT).
        [ -n "$f" ] && printf '%s\t%s\t%s\n' "$f" "$w" "$wb" >> "$pairs_tmp"
      done < <(git -C "$w" diff --name-only HEAD 2>/dev/null)
    done
    # A file collides if >=2 DISTINCT WORKTREES change it. SINGLE awk pass —
    # O(P), one process. (Was an O(F·P) per-file grep loop that spawned F
    # greps and blew the canary's 5s SessionStart timeout at fleet scale —
    # code-council 2026-05-19 CRITICAL C8.) Emits "<file>\t<branch>, <branch>".
    while IFS="$(printf '\t')" read -r f wlist; do
      [ -n "$f" ] || continue
      COLLISION_LINES+=("$name → 📄 $f is being changed in 2 places at once: $(printf '%s' "$wlist" | sed 's/, / and /g')")
      overall_collision=1
    done < <(awk -F'\t' '
      { wk=$1 SUBSEP $2
        if (!(wk in seenwt)) { seenwt[wk]=1; cnt[$1]++ }
        bk=$1 SUBSEP $3
        if (!(bk in seenbr)) { seenbr[bk]=1
          if (brs[$1]=="") brs[$1]=$3; else brs[$1]=brs[$1] ", " $3 } }
      END { for (ff in cnt) if (cnt[ff]>=2) print ff "\t" brs[ff] }
    ' "$pairs_tmp" 2>/dev/null)
    rm -f "$pairs_tmp"
  fi

  echo
done

# --- the collision verdict — the single most important thing on screen ---------
echo "────────────────────────────────────────────"
if [ "$overall_collision" -eq 1 ]; then
  echo "⚠️  COLLISION — two sessions are editing the same file"
  echo
  for c in "${COLLISION_LINES[@]:-}"; do
    echo "   • $c"
  done
  echo
  echo "   Whichever session commits second will silently overwrite the other's"
  echo "   changes to that file. STOP and reconcile before continuing — finish or"
  echo "   stash one side, or move the change to a single worktree."
  exit 1
else
  echo "✅ No file is being edited in two places at once — safe to run parallel sessions."
  exit 0
fi
