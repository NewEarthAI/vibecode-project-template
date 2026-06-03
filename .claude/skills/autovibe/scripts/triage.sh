#!/usr/bin/env bash
# autovibe/triage.sh — plan-vs-direct decision per D2 trigger list
# Input:  $1 = user intent string (required)
# Output: stdout = plan|direct|ambiguous (one word)
#         stderr = single-line reason
# Exit:   always 0 (informational, not gating). Caller branches on stdout.
#
# Decision order:
# 1. Mandatory-plan triggers (intent keywords OR diff patterns) → plan
# 2. Never-plan triggers (trivia patterns) → direct
# 3. Fall through → ambiguous (orchestrator escalates to LLM judgment)

set -uo pipefail

INTENT="${1:-}"
if [ -z "$INTENT" ]; then
  echo "ambiguous"
  echo "no intent provided" >&2
  exit 0
fi

# ─── Helpers ─────────────────────────────────────────────────────

_intent_lc="$(echo "$INTENT" | tr '[:upper:]' '[:lower:]')"

_changed_files() {
  # Tracked changes (modified/staged) + untracked
  { git diff --name-only HEAD 2>/dev/null
    git diff --name-only --cached 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
}

_diff_line_count() {
  # Insertions + deletions across tracked changes
  git diff --shortstat HEAD 2>/dev/null | \
    awk '{i=0;d=0; for(k=1;k<=NF;k++){if($k~/insertion/){i=$(k-1)} if($k~/deletion/){d=$(k-1)}} print i+d}'
}

_diff_file_count() {
  _changed_files | grep -c . || true
}

_emit() {
  # $1 = decision, $2 = reason
  echo "$1"
  echo "$2" >&2
  exit 0
}

# ─── 1. Mandatory-plan triggers — INTENT keywords ───────────────

case "$_intent_lc" in
  *"migration"*|*"migrate"*|*"alter table"*|*"create table"*|*"drop table"*|*"rls"*|*"row-level security"*)
    _emit "plan" "intent mentions database migration or RLS"
    ;;
  *"edge function"*|*"supabase function"*|*"deploy_edge"*)
    _emit "plan" "intent mentions edge function (deploys touch prod)"
    ;;
  *"n8n"*|*"workflow"*|*" hook"*|*"hook "*)
    _emit "plan" "intent mentions n8n workflow or hook (multi-system blast radius)"
    ;;
  *"auth"*|*"login"*|*"session"*|*"signin"*|*"signout"*|*"jwt"*|*"oauth"*)
    _emit "plan" "intent mentions auth/session (security-sensitive)"
    ;;
  *"v_seller_pipeline"*|*"dd_property_enriched"*)
    _emit "plan" "intent touches core pipeline view/table"
    ;;
  *"src/integrations"*|*"external api"*|*"batchdata"*|*"rentcast"*|*"realestateapi"*)
    _emit "plan" "intent touches external API integration"
    ;;
  *"refactor"*|*"architectur"*|*"redesign"*|*"rewrite"*)
    _emit "plan" "intent describes refactor/redesign (likely cross-cutting)"
    ;;
esac

# ─── 1b. Mandatory-plan triggers — DIFF patterns ───────────────

CHANGED="$(_changed_files)"
LINE_COUNT="$(_diff_line_count)"
FILE_COUNT="$(_diff_file_count)"
# Defaults: empty → 0 (avoids "integer expression expected" from -le on empty strings)
[ -z "$LINE_COUNT" ] && LINE_COUNT=0
[ -z "$FILE_COUNT" ] && FILE_COUNT=0

if [ -n "$CHANGED" ]; then
  if echo "$CHANGED" | grep -qE '^supabase/(migrations|functions)/|\.sql$'; then
    _emit "plan" "diff touches Supabase migration/function/SQL"
  fi
  if echo "$CHANGED" | grep -qE '^\.claude/(hooks|skills|agents)/|^council/'; then
    _emit "plan" "diff touches hooks/skills/agents/council (meta-tooling change)"
  fi
  if echo "$CHANGED" | grep -qE '^src/integrations/'; then
    _emit "plan" "diff touches src/integrations/ (external API client)"
  fi
  if echo "$CHANGED" | grep -qE '^src/(pages/Auth|hooks/use[A-Z][a-z]*Auth)|auth\.tsx?$'; then
    _emit "plan" "diff touches auth flow"
  fi
  # n8n workflow JSON: a *.json file containing the "nodes": key
  while IFS= read -r f; do
    if [ -f "$f" ] && [[ "$f" == *.json ]] && grep -q '"nodes"[[:space:]]*:' "$f" 2>/dev/null; then
      _emit "plan" "diff touches n8n workflow JSON: $f"
    fi
  done <<< "$CHANGED"
  # File / line caps
  if [ "$FILE_COUNT" -gt 2 ] 2>/dev/null; then
    _emit "plan" "diff touches >2 files ($FILE_COUNT)"
  fi
  if [ "$LINE_COUNT" -gt 200 ] 2>/dev/null; then
    _emit "plan" "diff has >200 lines changed ($LINE_COUNT)"
  fi
fi

# ─── 2. Never-plan triggers ────────────────────────────────────

case "$_intent_lc" in
  *"typo"*|*"fix typo"*|*"fix spelling"*|*"comment"*|*"console.log"*|*"console log"*)
    # Trivia intent: emit direct when nothing's been touched yet OR change is tiny
    if [ -z "$CHANGED" ] || { [ "$FILE_COUNT" -le 1 ] && [ "$LINE_COUNT" -le 5 ]; }; then
      _emit "direct" "trivial typo/comment/console.log change"
    fi
    ;;
  *"reorder"*|*"reorganize roadmap"*|*"sort roadmap"*)
    if [ -z "$CHANGED" ] || echo "$CHANGED" | grep -qvE '\.md$' || true; then
      # ROADMAP-only md edits with no other changes
      if [ -z "$CHANGED" ] || ! echo "$CHANGED" | grep -qvE '^(specs/)?ROADMAP\.md$|\.md$'; then
        _emit "direct" "doc-only reorder (ROADMAP/markdown)"
      fi
    fi
    ;;
esac

# Trivial diff signature (only doc edits, ≤5 lines, single file)
if [ -n "$CHANGED" ] && [ "$FILE_COUNT" -eq 1 ] && [ "$LINE_COUNT" -le 5 ] 2>/dev/null; then
  if echo "$CHANGED" | grep -qE '\.md$'; then
    _emit "direct" "single .md file, $LINE_COUNT line(s) changed"
  fi
fi

# ─── 3. Fall through ──────────────────────────────────────────

if [ -n "$CHANGED" ]; then
  _emit "ambiguous" "medium-size change ($FILE_COUNT files, $LINE_COUNT lines) — judgment required"
else
  _emit "ambiguous" "no diff present; intent string did not match mandatory triggers — judgment required"
fi
