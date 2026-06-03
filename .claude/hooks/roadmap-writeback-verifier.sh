#!/bin/bash
# .claude/hooks/roadmap-writeback-verifier.sh
#
# Stop hook — WARN-ONLY backstop for the canonical Roadmap Write-Back phase
# (.claude/skills/_shared/roadmap-writeback-phase.md). Mirrors a verdict-
# downgrade/warn pattern — it NEVER blocks. It is NOT a hard gate.
#
# ───────────────────────────────────────────────────────────────────────────
# HONESTY CLAUSE (verbatim — also embed in the roadmap doctrine):
#   This hook WARNS; it does not BLOCK. A session can still exit with
#   roadmap-relevant work unticked — the warning names the suspect change set
#   but cannot force the write-back. Enforcement is loud-visibility, not a
#   hard gate. Registration lives in settings: if this project TRACKS
#   .claude/settings.local.json, the registration propagates on merge/pull
#   automatically; if it GITIGNORES it (per-machine convention), each machine
#   must register locally and machines without it have NO warning until then.
#   The self-check below covers both cases. Treat a green exit as "no warning
#   fired on THIS machine", not "roadmap is provably current".
# ───────────────────────────────────────────────────────────────────────────
#
# Trigger predicate (ALL must hold — deliberately conservative to avoid the
# alarm-fatigue death that kills warn hooks):
#   (1) a substantive (non-docs, non-roadmap) change exists in this branch's
#       change set, AND
#   (2) a completion-class signal exists (branch landed commits OR
#       completion-language in the transcript), AND
#   (3) NO roadmap markdown file is in the change set.
# Pure read/investigation or docs-only sessions stay silent.
#
# Fail-open: ANY error → exit 0 silently. ALWAYS exit 0 (warn-only, never block).

set -u
trap 'exit 0' ERR EXIT INT TERM   # warn-only: nothing here may block Stop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || exit 0
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd 2>/dev/null)" || exit 0
cd "$ROOT" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Roadmap markdown files this project tracks (repo root + one level deep).
# Default ROADMAP.md; a project may have more than one roadmap surface.
roadmap_files=$(git ls-files 2>/dev/null | grep -E '(^|/)ROADMAP[^/]*\.md$' | head -20)

# Self-check: hook script is in git; registration is per-machine. If the repo
# ships this hook but THIS machine's settings don't reference it, the
# enforcement asymmetry the mechanism exists to kill is reborn invisibly.
self_registered=0
for SF in "$ROOT/.claude/settings.local.json" "$ROOT/.claude/settings.json"; do
  [ -f "$SF" ] && grep -q "roadmap-writeback-verifier.sh" "$SF" 2>/dev/null && self_registered=1
done

# ── This branch's change set (time-window-free) ────────────────────────────
# Signal = uncommitted working tree ∪ this branch's unpushed commits
# (@{u}..HEAD); no upstream → HEAD's own change set. The defect unit is a
# change set that completed work without a roadmap tick, not a time window.
# KNOWN GAP (by design): work committed AND pushed before this Stop fired
# leaves @{u}..HEAD empty and the tree clean — the hook stays silent on it.
# It catches uncommitted + unpushed work only; the canonical write-back phase
# is the primary control, this hook the skipped-phase backstop.
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
branch_has_commits=0
[ -n "$(printf '%s' "$branch_files" | sed '/^$/d')" ] && branch_has_commits=1
all_changes=$(printf '%s\n%s\n' "$changed" "$branch_files" | sed '/^$/d' | sort -u)
[ -z "$all_changes" ] && exit 0

# (3) roadmap already touched this change set? → write-back happened → silent
if [ -n "$roadmap_files" ]; then
  while IFS= read -r rf; do
    [ -z "$rf" ] && continue
    if printf '%s\n' "$all_changes" | grep -qxF "$rf" 2>/dev/null; then exit 0; fi
  done <<EOF
$roadmap_files
EOF
fi

# (1) substantive change = anything that is not pure docs/roadmap/session-meta
substantive=$(printf '%s\n' "$all_changes" | grep -vE \
  '(^|/)(ROADMAP[^/]*\.md|CHANGELOG\.md|.*\.md)$|^\.claude/(sessions|.*last-run)|^continuations/|^council/' \
  2>/dev/null | head -20)
# also count non-trivial .md work that is plausibly completion (specs/skills/src)
md_substantive=$(printf '%s\n' "$all_changes" | grep -E '^(specs/|src/|supabase/|\.claude/skills/|\.claude/hooks/)' 2>/dev/null | grep -vE '(^|/)ROADMAP' | head -20)
relevant=$(printf '%s\n%s\n' "$substantive" "$md_substantive" | sed '/^$/d' | sort -u | head -20)
[ -z "$relevant" ] && exit 0

# (2) completion-class signal: branch landed commits OR completion-language
completion_signal=0
[ "$branch_has_commits" -eq 1 ] && completion_signal=1
if [ "$completion_signal" -eq 0 ]; then
  payload=$(cat 2>/dev/null) || payload=""
  tpath=$(printf '%s' "$payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  if [ -n "$tpath" ] && [ -f "$tpath" ]; then
    tail -c 200000 "$tpath" 2>/dev/null | grep -qiE '(shipped|deployed|merged|resolved|completed|fixed|done\b|verified)' && completion_signal=1
  fi
fi
[ "$completion_signal" -eq 0 ] && exit 0

# ── All three hold → WARN (never block) ────────────────────────────────────
{
  echo ""
  echo "⚠️  ROADMAP WRITE-BACK MAY BE MISSING — warn-only, this does NOT block your exit"
  echo "    Substantive work landed in this change set with a completion signal,"
  echo "    but no roadmap markdown file was modified."
  echo "    Suspect changes this session:"
  printf '%s\n' "$relevant" | sed 's/^/      • /'
  echo ""
  echo "    If work completed: run the canonical Roadmap Write-Back phase"
  echo "    (.claude/skills/_shared/roadmap-writeback-phase.md) — tick ONLY with a"
  echo "    verified-verdict evidence pointer (an artefact that merely EXISTS but"
  echo "    carries no verdict is NOT proof). No verdict → [~] (evidence-failed: <kind>)."
  echo ""
  echo "    HONESTY: this hook WARNS, it does not BLOCK. A green exit means"
  echo "    'no warning fired on THIS machine', NOT 'roadmap is provably current'."
  if [ "$self_registered" -eq 0 ]; then
    echo ""
    echo "    ‼️  ENFORCEMENT NOT INSTALLED ON THIS MACHINE: this hook is not"
    echo "        referenced in this project's settings here. Other machines may"
    echo "        have NO write-back warning at all (the asymmetry this mechanism"
    echo "        exists to kill). Register it in the Stop hooks chain + ensure"
    echo "        the shared settings entry is committed."
  fi
  echo ""
} >&2

exit 0
