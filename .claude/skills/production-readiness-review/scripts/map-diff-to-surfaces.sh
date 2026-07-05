#!/usr/bin/env bash
# map-diff-to-surfaces.sh — deterministic diff -> user-facing-surface mapper + coverage classifier.
#
# Part of the `production-readiness-review` skill. READ-ONLY: no git mutation, no network, no writes.
# Given a diff (range, explicit list, or stdin), it classifies every changed file into exactly one of:
#   MAPPED   — matches a surface-map rule -> drive these journey(s)
#   EXEMPT   — non-UI by nature (tests / docs / config / migrations) -> no browser surface expected
#   UNMAPPED — a src/ or supabase/functions/ file matching no rule -> GENUINE coverage gap (-> AMBER)
# It emits the deduped journey set + a COVERAGE line the skill folds into the honest verdict.
# The mapper NEVER decides GREEN — it only reports mapping completeness. RED/GREEN also needs the
# browser-drive + DB-storm results, which the skill orchestrates. This is the anti-theatre boundary.
#
# Usage:
#   map-diff-to-surfaces.sh [--diff-range <range>] [--registry <path>]
#   map-diff-to-surfaces.sh --files-from <file>
#   git diff --name-only A...B | map-diff-to-surfaces.sh --stdin
#   map-diff-to-surfaces.sh --self-test
#
# Exit codes: 0 = ran clean (regardless of coverage verdict); 2 = usage/error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${REGISTRY:-$SCRIPT_DIR/../surface-map.md}"
DIFF_RANGE="origin/main...HEAD"
MODE="diff"          # diff | files | stdin | selftest
FILES_FROM=""

# ---- arg parse ----
while [ $# -gt 0 ]; do
  case "$1" in
    --diff-range) DIFF_RANGE="${2:-}"; MODE="diff"; shift 2 ;;
    --registry)   REGISTRY="${2:-}"; shift 2 ;;
    --files-from) FILES_FROM="${2:-}"; MODE="files"; shift 2 ;;
    --stdin)      MODE="stdin"; shift ;;
    --self-test)  MODE="selftest"; shift ;;
    -h|--help)    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

# ---- glob -> anchored regex (supports ** recursive, * single-segment) ----
glob_to_regex() {
  local g="$1"
  g="${g//\\/\\\\}"          # backslash
  g="${g//./\\.}"            # dot
  g="${g//+/\\+}"            # plus
  g="${g//(/\\(}"; g="${g//)/\\)}"
  g="${g//\*\*/$'\x01'}"     # ** -> sentinel
  g="${g//\*/[^/]*}"         # *  -> single path segment
  g="${g//$'\x01'/.*}"       # sentinel -> .* (recursive)
  printf '^%s$' "$g"
}

# ---- load rules from the registry's fenced RULES block ----
# Rule lines (whitespace-separated):
#   MAP    <glob>   <journey[,journey...]>
#   EXEMPT <glob>
MAP_GLOBS=(); MAP_JOURNEYS=(); EXEMPT_GLOBS=()
load_rules() {
  [ -f "$REGISTRY" ] || { echo "ERROR: registry not found: $REGISTRY" >&2; exit 2; }
  MAP_GLOBS=(); MAP_JOURNEYS=(); EXEMPT_GLOBS=()   # reset — idempotent if called twice
  local in_block=0 line type glob journeys
  while IFS= read -r line; do
    case "$line" in
      "<!-- RULES:START -->") in_block=1; continue ;;
      "<!-- RULES:END -->")   in_block=0; continue ;;
    esac
    [ "$in_block" -eq 1 ] || continue
    line="${line%%#*}"                       # strip trailing comment
    [ -n "${line// /}" ] || continue          # skip blank
    read -r type glob journeys <<<"$line"
    case "$type" in
      MAP)    MAP_GLOBS+=("$glob");    MAP_JOURNEYS+=("$journeys") ;;
      EXEMPT) EXEMPT_GLOBS+=("$glob") ;;
    esac
  done < "$REGISTRY"
}

# ---- classify a single file ----
# EXEMPT is checked FIRST so a test/doc under a mapped dir is exempt, not a gap.
classify() {
  local f="$1" i re
  for ex in "${EXEMPT_GLOBS[@]:-}"; do
    [ -n "$ex" ] || continue
    re="$(glob_to_regex "$ex")"
    [[ "$f" =~ $re ]] && { printf 'EXEMPT\t%s\t%s\n' "$f" "$ex"; return; }
  done
  local matched=0 acc="" seen=" "
  for i in "${!MAP_GLOBS[@]}"; do
    re="$(glob_to_regex "${MAP_GLOBS[$i]}")"
    if [[ "$f" =~ $re ]]; then
      matched=1
      IFS=',' read -ra js <<<"${MAP_JOURNEYS[$i]}"   # dedup journeys across overlapping rules
      for j in "${js[@]}"; do
        case "$seen" in *" $j "*) ;; *) acc="${acc:+$acc,}$j"; seen="$seen$j " ;; esac
      done
    fi
  done
  if [ "$matched" -eq 1 ]; then
    printf 'MAPPED\t%s\t%s\n' "$f" "$acc"
  else
    printf 'UNMAPPED\t%s\t-\n' "$f"
  fi
}

# ---- gather changed files ----
gather_files() {
  case "$MODE" in
    diff)  git diff --name-only "$DIFF_RANGE" 2>/dev/null ;;
    files) [ -f "$FILES_FROM" ] && cat "$FILES_FROM" || { echo "ERROR: --files-from not found: $FILES_FROM" >&2; exit 2; } ;;
    stdin) cat ;;
  esac
}

# ---- main report over a file stream on stdin ----
emit_report() {
  load_rules
  local mapped=0 exempt=0 unmapped=0
  local -a journeys_all=() mapped_lines=() exempt_lines=() unmapped_lines=()
  local f res kind file extra
  while IFS= read -r f; do
    [ -n "${f// /}" ] || continue
    res="$(classify "$f")"
    IFS=$'\t' read -r kind file extra <<<"$res"
    case "$kind" in
      MAPPED)   mapped=$((mapped+1)); mapped_lines+=("  $file => $extra")
                IFS=',' read -ra js <<<"$extra"; for j in "${js[@]}"; do journeys_all+=("$j"); done ;;
      EXEMPT)   exempt=$((exempt+1)); exempt_lines+=("  $file [exempt:$extra]") ;;
      UNMAPPED) unmapped=$((unmapped+1)); unmapped_lines+=("  $file  (no surface mapped) [GAP]") ;;
    esac
  done
  # dedup journeys, preserve first-seen order
  local -a uniq=(); local seen=" "
  for j in "${journeys_all[@]:-}"; do
    [ -n "$j" ] || continue
    case "$seen" in *" $j "*) ;; *) uniq+=("$j"); seen="$seen$j " ;; esac
  done

  echo "JOURNEYS: ${uniq[*]:-(none)}"
  echo "MAPPED:"; printf '%s\n' "${mapped_lines[@]:-  (none)}"
  echo "EXEMPT:"; printf '%s\n' "${exempt_lines[@]:-  (none)}"
  echo "UNMAPPED:"; printf '%s\n' "${unmapped_lines[@]:-  (none)}"
  echo "COVERAGE: mapped=$mapped exempt=$exempt unmapped=$unmapped journeys=${#uniq[@]} mapping_source=registry"
  if [ "$unmapped" -gt 0 ]; then
    echo "VERDICT_HINT: PARTIAL ($unmapped changed file(s) map to no surface — coverage incomplete; see UNMAPPED)"
  elif [ "${#uniq[@]}" -eq 0 ]; then
    echo "VERDICT_HINT: NO_SURFACE (only exempt/non-UI files changed — no browser surface to drive; DB-storm check still applies)"
  else
    echo "VERDICT_HINT: COMPLETE (every changed file mapped or exempt; drive the ${#uniq[@]} journey(s) above)"
  fi
}

# ---- self-test ----
run_selftest() {
  # Fixture exercises the GENERIC skeleton rules in surface-map.md (home + login example MAP rules,
  # the project-agnostic EXEMPT block). Replace both together when you customise surface-map.md.
  local tmp; tmp="$(mktemp)"
  cat > "$tmp" <<'EOF'
src/pages/Home.tsx
src/components/auth/Login.tsx
migrations/20260101000000_init.sql
src/components/auth/Login.test.tsx
src/lib/unmapped-helper.ts
docs/README.md
EOF
  local out; out="$(emit_report < "$tmp")"
  rm -f "$tmp"
  echo "$out"
  echo "--- self-test assertions ---"
  local fail=0
  assert() { if echo "$out" | grep -qE "$1"; then echo "  PASS: $2"; else echo "  FAIL: $2"; fail=1; fi; }
  assert '^JOURNEYS:.*home'                   "page file -> home journey"
  assert '^JOURNEYS:.*login'                  "auth file -> login journey"
  assert 'Login\.test\.tsx \[exempt'         "test file under a mapped dir -> EXEMPT (not a gap)"
  assert '20260101000000_init\.sql \[exempt' "migration -> EXEMPT (DB-layer)"
  assert 'unmapped-helper\.ts.*\[GAP\]'      "unmapped src/ file -> UNMAPPED gap (honest)"
  assert 'COVERAGE: mapped=2 exempt=3 unmapped=1' "coverage counts correct"
  assert 'VERDICT_HINT: PARTIAL'             "1 unmapped -> PARTIAL hint (never silent green)"
  if [ "$fail" -eq 0 ]; then echo "SELF-TEST: ALL PASS"; exit 0; else echo "SELF-TEST: FAILURES"; exit 1; fi
}

case "$MODE" in
  selftest) run_selftest ;;
  *)        gather_files | emit_report ;;
esac
