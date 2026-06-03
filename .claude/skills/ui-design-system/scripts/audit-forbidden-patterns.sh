#!/usr/bin/env bash
# ==============================================================================
# the agency UI Design — Forbidden Patterns Audit
# ------------------------------------------------------------------------------
# Scans a project for banned design patterns. Fails (exit 1) on any violation.
#
# Usage:
#   bash audit-forbidden-patterns.sh [project_root]
#
# If project_root is omitted, scans current directory.
#
# Uses POSIX grep (portable to any Unix). Slower than ripgrep but works
# everywhere without external tooling dependencies.
#
# Exit codes:
#   0 = clean
#   1 = violations found
#   2 = script error (missing tool, invalid path)
# ==============================================================================

set -uo pipefail

ROOT="${1:-.}"
VIOLATIONS=0

if [ ! -d "$ROOT" ]; then
  echo "ERROR: project root '$ROOT' does not exist" >&2
  exit 2
fi

if [ -d "$ROOT/src" ]; then
  TARGET="$ROOT/src"
elif [ -d "$ROOT/app" ]; then
  TARGET="$ROOT/app"
else
  TARGET="$ROOT"
fi

# POSIX grep flags for source file scanning
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

echo "================================================================"
echo "the agency UI Design — Forbidden Patterns Audit"
echo "================================================================"
echo "Scanning: $TARGET"
echo ""

# Helper to report a violation class
# Args: $1=rule_name $2=description $3=regex_pattern $4=optional_exclude_regex
report_violation() {
  local name="$1"
  local description="$2"
  local pattern="$3"
  local excludes="${4:-}"

  local output
  output=$(grep -rEn \
    "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
    "$pattern" "$TARGET" 2>/dev/null || true)

  if [ -n "$excludes" ] && [ -n "$output" ]; then
    output=$(echo "$output" | grep -vE "$excludes" || true)
  fi

  if [ -n "$output" ]; then
    local count
    count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
    echo "FAIL: $name ($count violations)"
    echo "      $description"
    printf '%s\n' "$output" | head -15 | sed 's/^/      /'
    if [ "$count" -gt 15 ]; then
      echo "      ... and $((count - 15)) more"
    fi
    echo ""
    VIOLATIONS=$((VIOLATIONS + count))
  else
    echo "PASS: $name"
  fi
}

# -----------------------------------------------------------------------------
# Rule 1: No rounded-2xl or rounded-3xl
# -----------------------------------------------------------------------------
report_violation \
  "rounded-2xl / rounded-3xl ban" \
  "Use rounded-xl (12px) maximum. Larger radii read as chunky iOS consumer." \
  'rounded-(2xl|3xl)'

# -----------------------------------------------------------------------------
# Rule 2: No backdrop-blur on content surfaces
# -----------------------------------------------------------------------------
report_violation \
  "backdrop-blur / glassmorphism ban" \
  "Glassmorphism is banned. Use solid neutral surfaces with two-layer shadows." \
  'backdrop-(blur|filter)' \
  'GuidedTour|guided-tour|driver\.css|tour\.css|\.min\.'

# -----------------------------------------------------------------------------
# Rule 3: No translucent white backgrounds
# -----------------------------------------------------------------------------
report_violation \
  "translucent white bg ban" \
  "bg-white/X is the glassmorphism gateway. Use --ne-bg-base solid." \
  'bg-white/[0-9]+'

# -----------------------------------------------------------------------------
# Rule 4: No colored shadows
# -----------------------------------------------------------------------------
report_violation \
  "colored shadows ban" \
  "Shadows must be grayscale. Colored shadows read as gaming website." \
  'shadow-(red|green|blue|purple|pink|cyan|amber|yellow|orange|indigo|violet|fuchsia|rose|emerald|teal|sky|lime)-[0-9]'

# -----------------------------------------------------------------------------
# Rule 5: No shadow-2xl on cards
# -----------------------------------------------------------------------------
report_violation \
  "shadow-2xl ban" \
  "shadow-2xl is too blurry for premium surfaces." \
  'shadow-2xl'

# -----------------------------------------------------------------------------
# Rule 6: No text-shadow
# -----------------------------------------------------------------------------
report_violation \
  "text-shadow ban" \
  "text-shadow belongs in 2005 PowerPoint." \
  'text-shadow[[:space:]]*:'

# -----------------------------------------------------------------------------
# Rule 7: No Inter / Roboto / Arial as primary font-family
# -----------------------------------------------------------------------------
report_violation \
  "banned primary typeface" \
  "Primary typeface must be DM Sans (or licensed brand font)." \
  "font-family[[:space:]]*:[[:space:]]*['\"]?(Inter|Roboto|Arial)['\"]?[[:space:]]*(,|;|$)" \
  'Inter Tight|Inter Display|DM Sans|JetBrains'

# -----------------------------------------------------------------------------
# Rule 8: No emoji in code / copy
# -----------------------------------------------------------------------------
# POSIX grep doesn't support Unicode ranges cleanly. We scan for common emoji
# code points by looking at the raw bytes in UTF-8. The most common emoji block
# starts with 0xF0 0x9F (4-byte UTF-8 starting with F0 9F).
# This is a practical check — catches 99% of emoji without Unicode awareness.
EMOJI_OUTPUT=$(grep -rEln \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  $'\xF0\x9F' \
  "$TARGET" 2>/dev/null || true)

# Filter out legitimate user-content surfaces
if [ -n "$EMOJI_OUTPUT" ]; then
  EMOJI_OUTPUT=$(echo "$EMOJI_OUTPUT" | grep -vE '(MessageBubble|UserMessage|ChatMessage|whatsapp|WhatsApp|messageText|\.test\.|\.spec\.|__tests__|user-content|UserContent|EvidenceViewer|chat-history|MessageList|description.*emoji)' || true)
fi

if [ -n "$EMOJI_OUTPUT" ]; then
  EMOJI_COUNT=$(printf '%s\n' "$EMOJI_OUTPUT" | wc -l | tr -d ' ')
  echo "FAIL: emoji in code/copy ban ($EMOJI_COUNT files contain emoji)"
  echo "      Emoji in UI copy or component children is banned."
  echo "      User-generated content surfaces are auto-exempted by filename."
  printf '%s\n' "$EMOJI_OUTPUT" | head -15 | sed 's/^/      /'
  if [ "$EMOJI_COUNT" -gt 15 ]; then
    echo "      ... and $((EMOJI_COUNT - 15)) more files"
  fi
  echo ""
  VIOLATIONS=$((VIOLATIONS + EMOJI_COUNT))
else
  echo "PASS: emoji in code/copy ban"
fi

# -----------------------------------------------------------------------------
# Rule 9: No bg-gradient-to-* on content surfaces
# -----------------------------------------------------------------------------
report_violation \
  "gradient background on content surface" \
  "Gradient backgrounds are banned. Only silver gradient border is allowed." \
  'bg-gradient-to-[trbl]+' \
  'ne-silver|hero-marketing|landing-page|MarketingHero|LandingPage'

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "================================================================"
if [ "$VIOLATIONS" -eq 0 ]; then
  echo "CLEAN — no forbidden patterns found."
  echo "================================================================"
  exit 0
else
  echo "FAILED — $VIOLATIONS violations found."
  echo "================================================================"
  echo ""
  echo "Review anti-vibe-coded.md for the full rule reference:"
  echo "  .claude/skills/ui-design-system/references/anti-vibe-coded.md"
  exit 1
fi
