#!/usr/bin/env bash
# ==============================================================================
# the house UI Design — Restraint & Anti-AI-Tell Audit (WARN tier)
# ------------------------------------------------------------------------------
# The heuristic companion to audit-forbidden-patterns.sh (the hard FAIL gate).
# These checks have legitimate false-positive surfaces, so they WARN (exit 0)
# rather than FAIL — a hard-fail heuristic erodes trust and trains operators to
# ignore the gate (council 2026-06-24, R4). Hard structural bans stay in
# audit-forbidden-patterns.sh.
#
# Usage:
#   bash audit-restraint.sh [project_root]      # scan a project
#   bash audit-restraint.sh --self-test         # prove the checks actually fire
#
# Exclusion: put  // ne-allow: <rule>  (or {/* ne-allow: em-dash */}) on a line
# to suppress a known-legitimate match on that line.
#
# Exit codes:
#   0 = scan complete (warnings are advisory, never fail the build)
#   2 = script error (missing tool, invalid path)
#
# Shell-portability: byte-safe patterns for non-ASCII (em-dash), ASCII-only
# regexes elsewhere, $? captured before any pipe. Safe under the C locale that
# Claude Code's non-interactive shell inherits.
# ==============================================================================

set -uo pipefail

WARNINGS=0

# POSIX grep flags (mirror audit-forbidden-patterns.sh)
GREP_INCLUDES=(
  --include='*.tsx' --include='*.ts' --include='*.jsx' --include='*.js'
  --include='*.css' --include='*.scss' --include='*.html'
)
GREP_EXCLUDES=(
  --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build
  --exclude-dir=.next --exclude-dir=.nuxt --exclude-dir=coverage
  --exclude-dir=.git --exclude-dir=.claude --exclude-dir=supabase
  --exclude='*.min.*' --exclude='*.lock'
)

# Em-dash byte sequence (U+2014 = 0xE2 0x80 0x94). Matched as raw bytes so it
# fires regardless of locale (same technique as the emoji rule in the FAIL gate).
EMDASH=$'\xe2\x80\x94'

# report_warning name description pattern [exclude_regex]
report_warning() {
  local name="$1" description="$2" pattern="$3" excludes="${4:-}"
  local output
  output=$(grep -rEn "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" "$pattern" "$TARGET" 2>/dev/null || true)
  # always drop ne-allow lines
  if [ -n "$output" ]; then output=$(printf '%s\n' "$output" | grep -v 'ne-allow' || true); fi
  if [ -n "$excludes" ] && [ -n "$output" ]; then
    output=$(printf '%s\n' "$output" | grep -vE "$excludes" || true)
  fi
  if [ -n "$output" ]; then
    local count; count=$(printf '%s\n' "$output" | grep -c . || true); count=${count:-0}
    echo "[WARNING] $name ($count to review)"
    echo "          $description"
    printf '%s\n' "$output" | head -10 | sed 's/^/          /'
    [ "$count" -gt 10 ] && echo "          ... and $((count - 10)) more"
    echo ""
    WARNINGS=$((WARNINGS + count))
  else
    echo "[ok] $name"
  fi
}

run_scan() {
  echo "================================================================"
  echo "the house Restraint & Anti-AI-Tell Audit (WARN tier)"
  echo "================================================================"
  echo "Scanning: $TARGET"
  echo ""

  # 1. Em-dash in visible UI copy (#1 AI-copy tell). Byte-safe pattern.
  report_warning \
    "em-dash in UI copy" \
    "Em-dash (U+2014) is the #1 AI-copy tell. Remove from generated UI copy; mark genuine data/editorial uses with  // ne-allow: em-dash" \
    "$EMDASH" \
    'MessageBubble|ChatMessage|UserMessage|whatsapp|WhatsApp|user-content|UserContent|\.test\.|\.spec\.|__tests__'

  # 2. Space Grotesk — 2026 AI-default tell. Catch CSS decl + Tailwind class + import URL.
  report_warning \
    "Space Grotesk (AI-default font)" \
    "Space Grotesk reads as an AI default. Use DM Sans (or a documented client brand font)." \
    "Space[ _+]Grotesk"

  # 3. Fake-precise marketing numbers (invented stats). Heuristic.
  report_warning \
    "fake-precise number (verify it is real)" \
    "Numbers like 92%, 4.1x, 3,847 read as invented unless sourced. Confirm each is real." \
    '>[^<]*([0-9]{1,3}(\.[0-9]+)?%|[0-9]+(\.[0-9]+)?[xX]\b|[0-9],[0-9]{3})[^<]*<'

  # 4. Marquee (max 1 per page is the restraint cap; flag for a manual count).
  report_warning \
    "marquee (cap: 1 per page)" \
    "Marquees are visual noise above 1 per page. Confirm the count." \
    'marquee|animate-marquee|Marquee'

  # 5. Layout-prop transitions (perf/CLS). ASCII-only, byte-safe (no Unicode ellipsis).
  report_warning \
    "animating layout properties" \
    "Animate transform/opacity only. transition on width/height/top/left/margin causes reflow + CLS." \
    'transition[[:space:]]*:[^;]*(width|height|top|left|margin)'

  # 6. Reduced-motion heuristic: files using GSAP/ScrollTrigger that lack a reduced-motion branch.
  local motion_files rm_missing=""
  motion_files=$(grep -rEl "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
    'gsap\.(to|from|fromTo|timeline)|ScrollTrigger|SplitText' "$TARGET" 2>/dev/null || true)
  if [ -n "$motion_files" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if ! grep -qE 'matchMedia|prefers-reduced-motion' "$f" 2>/dev/null; then
        rm_missing="${rm_missing}${f}"$'\n'
      fi
    done <<< "$motion_files"
  fi
  rm_missing=$(printf '%s' "$rm_missing" | grep -v 'ne-allow' || true)
  if [ -n "$rm_missing" ]; then
    local rc; rc=$(printf '%s\n' "$rm_missing" | grep -c . || true); rc=${rc:-0}
    echo "[WARNING] motion without reduced-motion fallback ($rc files)"
    echo "          GSAP/ScrollTrigger present but no matchMedia / prefers-reduced-motion in the file."
    printf '%s\n' "$rm_missing" | head -10 | sed 's/^/          /'
    echo ""
    WARNINGS=$((WARNINGS + rc))
  else
    echo "[ok] reduced-motion fallback present where motion is used"
  fi

  echo "================================================================"
  if [ "$WARNINGS" -eq 0 ]; then
    echo "CLEAN — no restraint warnings."
  else
    echo "$WARNINGS item(s) to review (advisory — does not fail the build)."
    echo "Reference: .claude/skills/ui-design-system/references/restraint-preflight.md"
  fi
  echo "================================================================"
}

# --------------------------- self-test ---------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  # Fixture with a real em-dash + Space Grotesk + a clean line.
  printf '%s\n' "<h1>Premium results${EMDASH}delivered</h1>" > "$TMP/Bad.tsx"
  printf '%s\n' "font-family: 'Space Grotesk', sans-serif;" >> "$TMP/Bad.tsx"
  printf '%s\n' "<p>All clean copy here.</p>" > "$TMP/Good.tsx"
  TARGET="$TMP"
  echo "SELF-TEST — fixture should produce em-dash + Space Grotesk warnings:"
  echo ""
  run_scan
  echo ""
  if [ "$WARNINGS" -ge 2 ]; then
    echo "SELF-TEST PASS: byte-safe em-dash + Space Grotesk checks fired ($WARNINGS warnings)."
    exit 0
  else
    echo "SELF-TEST FAIL: expected >=2 warnings, got $WARNINGS — a check is silently not firing."
    exit 2
  fi
fi

# --------------------------- normal run --------------------------------------
ROOT="${1:-.}"
if [ ! -d "$ROOT" ] && [ ! -f "$ROOT" ]; then
  echo "ERROR: path '$ROOT' does not exist" >&2
  exit 2
fi
if [ -d "$ROOT/src" ]; then TARGET="$ROOT/src"
elif [ -d "$ROOT/app" ]; then TARGET="$ROOT/app"
else TARGET="$ROOT"; fi

run_scan
exit 0
