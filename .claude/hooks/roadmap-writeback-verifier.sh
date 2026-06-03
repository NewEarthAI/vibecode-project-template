#!/bin/bash
# .claude/hooks/roadmap-writeback-verifier.sh
#
# Stop hook — WARN-ONLY backstop for the canonical Roadmap Write-Back phase.
# Origin: council/sessions/2026-05-16-roadmap-writeback-enforcement-extended-council.md
# Item 2 + AR2. Mirrors the code-council-verification.sh *pattern* (downgrade/warn,
# never block). It is NOT the hookify completion-verifier markdown rule.
#
# ───────────────────────────────────────────────────────────────────────────
# HONESTY CLAUSE (verbatim — AR2; also embedded in the roadmap doctrine):
#   This hook WARNS; it does not BLOCK. A session can still exit with
#   roadmap-relevant work unticked — the warning names the suspect items but
#   cannot force the write-back. Enforcement is loud-visibility, not a hard
#   gate. Registration lives in .claude/settings.local.json, which is TRACKED
#   in this repo — so on merge/pull the registration propagates fleet-wide
#   automatically (no separate human commit of a shared snippet needed here;
#   that caveat applies only to projects that gitignore settings.local.json).
#   The self-check below is defence-in-depth for any machine that somehow
#   lacks it. Treat a green exit as "no warning fired on THIS machine", not
#   "roadmap is provably current".
# ───────────────────────────────────────────────────────────────────────────
#
# Trigger predicate (ALL must hold — deliberately conservative to avoid the
# alarm-fatigue death the Edge Case Finder flagged):
#   (1) a BF-roadmap-relevant surface changed THIS session, AND
#   (2) a completion-class signal exists (completion-language in transcript
#       OR a commit landed in the session window), AND
#   (3) NEITHER ROADMAP.md NOR agency/business-foundations/ROADMAP.md was
#       modified this session.
# Pure read/investigation sessions (no commit, no completion words) stay silent.
#
# Fail-open: ANY error → exit 0 silently. ALWAYS exit 0 (warn-only, never block).

set -u
trap 'exit 0' ERR EXIT INT TERM   # warn-only: nothing this hook does may block Stop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || exit 0
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd 2>/dev/null)" || exit 0
cd "$ROOT" 2>/dev/null || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0   # not a git repo → nothing to check

MAIN_ROADMAP="ROADMAP.md"
BF_ROADMAP="agency/business-foundations/ROADMAP.md"

# ── Self-check (C3): asymmetry must fail loud ──────────────────────────────
# The hook script is in git; the *registration* is per-machine. If the repo
# ships this hook but THIS machine's settings.local.json doesn't reference it,
# the enforcement asymmetry the whole plan exists to kill is reborn invisibly.
SLOCAL="$ROOT/.claude/settings.local.json"
self_registered=0
if [ -f "$SLOCAL" ] && grep -q "roadmap-writeback-verifier.sh" "$SLOCAL" 2>/dev/null; then
  self_registered=1
fi

# ── Detect this branch's change set (time-window-free) ─────────────────────
# The defect unit is a CHANGE SET that completed BF work without a roadmap
# tick — not a time window. Signal = uncommitted working tree ∪ this branch's
# unpushed commits (@{u}..HEAD). On a feature branch that is exactly "what
# this session did"; with no upstream, fall back to HEAD's own change set.
# This is the only robust, session-aligned, time-free proxy available without
# inventing a new session-start tracker.
# KNOWN GAP (by design): work that was committed AND pushed before this Stop
# fired leaves @{u}..HEAD empty and the working tree clean — so this hook stays
# silent on it. The hook catches uncommitted + unpushed work; a fully-pushed
# session is invisible to it. The canonical write-back phase (run by the skill)
# is the primary control; this hook is only the backstop for skipped phases.
# Working-tree changes: strip the 2-char status + space prefix; on a rename
# ("R  old -> new") keep the post-arrow NEW path. core.quotePath=false avoids
# octal-escaped non-ASCII. (awk '{print $2}' grabbed the OLD rename path and
# split space-containing paths — fixed 2026-05-17 per code-council.)
changed=$(git -c core.quotePath=false status --porcelain 2>/dev/null \
            | sed -e 's/^...//' -e 's/^.* -> //')
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  branch_files=$(git log '@{u}..HEAD' --name-only --pretty=format: 2>/dev/null)
else
  branch_files=$(git show HEAD --name-only --pretty=format: 2>/dev/null)
fi
# completion-class signal: this branch has unpushed/HEAD commits (work landed)
branch_has_commits=0
[ -n "$(printf '%s' "$branch_files" | sed '/^$/d')" ] && branch_has_commits=1
all_changes=$(printf '%s\n%s\n' "$changed" "$branch_files" | sed '/^$/d' | sort -u)
[ -z "$all_changes" ] && exit 0   # nothing happened → silent

# (3) roadmap already touched this session? → write-back happened → silent
if printf '%s\n' "$all_changes" | grep -qxF "$MAIN_ROADMAP" 2>/dev/null \
   || printf '%s\n' "$all_changes" | grep -qxF "$BF_ROADMAP" 2>/dev/null; then
  exit 0
fi

# (1) BF-roadmap-relevant surface changed this session?
relevant=$(printf '%s\n' "$all_changes" | grep -E \
  '^(agency/business-foundations/|council/sessions/|supabase/migrations/.*agency_subscription|clients/.*finance|newearthai-operations/)' \
  2>/dev/null | head -20)
[ -z "$relevant" ] && exit 0   # no relevant surface → not our concern → silent

# (2) completion-class signal: this branch landed commits OR completion-language
completion_signal=0
[ "$branch_has_commits" -eq 1 ] && completion_signal=1
if [ "$completion_signal" -eq 0 ]; then
  # transcript path arrives as JSON on stdin; degrade gracefully if absent
  payload=$(cat 2>/dev/null) || payload=""
  tpath=$(printf '%s' "$payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  if [ -n "$tpath" ] && [ -f "$tpath" ]; then
    if tail -c 200000 "$tpath" 2>/dev/null | grep -qiE '(shipped|deployed|merged|resolved|completed|fixed|done\b|verified)'; then
      completion_signal=1
    fi
  fi
fi
[ "$completion_signal" -eq 0 ] && exit 0   # no completion signal → silent (anti alarm-fatigue)

# ── All three hold → WARN (never block) ────────────────────────────────────
{
  echo ""
  echo "⚠️  ROADMAP WRITE-BACK MAY BE MISSING — warn-only, this does NOT block your exit"
  echo "    A BF-roadmap-relevant surface changed this session and shows completion"
  echo "    signal, but neither ROADMAP.md nor the BF ROADMAP was modified."
  echo "    Suspect surfaces this session:"
  printf '%s\n' "$relevant" | sed 's/^/      • /'
  echo ""
  echo "    If work completed: run the canonical Roadmap Write-Back phase"
  echo "    (.claude/skills/_shared/roadmap-writeback-phase.md) — tick ONLY with a"
  echo "    verified-verdict evidence pointer (no blank-template ticks — the 2026-05-16"
  echo "    Evaluation-H failure). No verdict → [~] (evidence-failed: <kind>)."
  echo ""
  echo "    HONESTY: this hook WARNS, it does not BLOCK. A green exit means"
  echo "    'no warning fired on THIS machine', NOT 'roadmap is provably current'."
  echo "    It also cannot see work committed AND pushed before this Stop fired —"
  echo "    it detects uncommitted + unpushed work only. The write-back phase is"
  echo "    the primary control; this hook is only the skipped-phase backstop."
  if [ "$self_registered" -eq 0 ]; then
    echo ""
    echo "    ‼️  ENFORCEMENT NOT INSTALLED ON THIS MACHINE: this hook is not"
    echo "        referenced in .claude/settings.local.json here. settings.local.json"
    echo "        is tracked in this repo, so a normal pull of merged main should"
    echo "        register it — if you see this, your local copy is behind or the"
    echo "        Stop entry was removed. Pull latest / restore the Stop registration."
  fi
  echo ""
} >&2

exit 0
