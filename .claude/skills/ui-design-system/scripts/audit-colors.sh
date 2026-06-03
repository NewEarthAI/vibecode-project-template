#!/usr/bin/env bash
# ==============================================================================
# the agency UI Design — Color Discipline Audit
# ------------------------------------------------------------------------------
# Flags color usage that isn't semantically justified. Every non-neutral color
# must appear near a state keyword (critical, warning, success, variance, etc.)
# or be explicitly allowed (primary brand color, semantic tokens).
#
# Uses POSIX grep for portability (no ripgrep dependency).
#
# Usage:
#   bash audit-colors.sh [project_root]
#
# Exit codes:
#   0 = clean
#   1 = hard violations found
#   2 = script error
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

GREP_INCLUDES=(
  --include='*.tsx' --include='*.ts' --include='*.jsx' --include='*.js'
)
GREP_EXCLUDES=(
  --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build
  --exclude-dir=.next --exclude-dir=coverage --exclude-dir=.git
  --exclude-dir=.claude --exclude-dir=supabase
  --exclude='*.min.*'
)

# Semantic state keywords that justify color usage (case-insensitive)
STATE_KEYWORDS='critical|warning|success|error|danger|alert|severity|variance|confidence|compliance|positive|negative|resolved|pending|info|primary|destructive|PRIORITY_|STATUS_|SEVERITY_|LEVEL_|state|status|level|approved|rejected|active|inactive|high|medium|low'

echo "================================================================"
echo "the agency UI Design — Color Discipline Audit"
echo "================================================================"
echo "Scanning: $TARGET"
echo ""

# -----------------------------------------------------------------------------
# Pattern 1: Tailwind colored backgrounds on Card/Panel components (HARD FAIL)
# -----------------------------------------------------------------------------
echo "--- Colored backgrounds on Card/Panel components ---"

CARD_COLOR_OUTPUT=$(grep -rEn \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  '<(Card|Panel)[^>]*bg-(red|green|blue|amber|yellow|orange|purple|pink|indigo|violet|fuchsia|rose|emerald|teal|sky|lime)-[0-9]+' \
  "$TARGET" 2>/dev/null || true)

if [ -n "$CARD_COLOR_OUTPUT" ]; then
  COUNT=$(printf '%s\n' "$CARD_COLOR_OUTPUT" | wc -l | tr -d ' ')
  echo "FAIL: $COUNT colored Card backgrounds found"
  echo "      Card backgrounds must be neutral. Color inside the card for state only."
  printf '%s\n' "$CARD_COLOR_OUTPUT" | head -10 | sed 's/^/      /'
  VIOLATIONS=$((VIOLATIONS + COUNT))
  echo ""
else
  echo "PASS: no colored Card backgrounds"
fi

# -----------------------------------------------------------------------------
# Pattern 2: Pastel backgrounds (bg-*-50/100/200) without state context
# -----------------------------------------------------------------------------
echo ""
echo "--- Pastel backgrounds without nearby state keyword ---"

PASTEL_LINES=$(grep -rEn \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  'bg-(red|green|blue|amber|yellow|orange|purple|pink|indigo|violet|fuchsia|rose|emerald|teal|sky|lime)-(50|100|200)' \
  "$TARGET" 2>/dev/null || true)

if [ -n "$PASTEL_LINES" ]; then
  UNJUSTIFIED_PASTELS=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    FILE=$(echo "$line" | cut -d: -f1)
    LINE_NUM=$(echo "$line" | cut -d: -f2)

    START=$((LINE_NUM - 3))
    [ "$START" -lt 1 ] && START=1
    END=$((LINE_NUM + 3))

    CONTEXT=$(sed -n "${START},${END}p" "$FILE" 2>/dev/null || echo "")

    if ! echo "$CONTEXT" | grep -qiE "$STATE_KEYWORDS"; then
      UNJUSTIFIED_PASTELS="${UNJUSTIFIED_PASTELS}${line}"$'\n'
    fi
  done <<< "$PASTEL_LINES"

  if [ -n "$UNJUSTIFIED_PASTELS" ]; then
    COUNT=$(printf '%s\n' "$UNJUSTIFIED_PASTELS" | grep -c . || echo 0)
    echo "FAIL: $COUNT pastel backgrounds without state context"
    echo "      Pastels without nearby state keywords are likely decorative."
    echo "      Use --ne-bg-base or the semantic --ne-*-bg tokens instead."
    printf '%s\n' "$UNJUSTIFIED_PASTELS" | head -10 | sed 's/^/      /'
    VIOLATIONS=$((VIOLATIONS + COUNT))
    echo ""
  else
    echo "PASS: all pastel backgrounds have state context"
  fi
else
  echo "PASS: no pastel backgrounds detected"
fi

# -----------------------------------------------------------------------------
# Pattern 3: Colored text without state context (WARN — not a hard fail)
# -----------------------------------------------------------------------------
echo ""
echo "--- Colored text without nearby state keyword (WARN only) ---"

COLORED_TEXT=$(grep -rEn \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  'text-(red|green|amber|blue|purple|pink|orange|emerald)-[5-9][0-9][0-9]' \
  "$TARGET" 2>/dev/null || true)

if [ -n "$COLORED_TEXT" ]; then
  UNJUSTIFIED_TEXT=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    FILE=$(echo "$line" | cut -d: -f1)
    LINE_NUM=$(echo "$line" | cut -d: -f2)

    START=$((LINE_NUM - 3))
    [ "$START" -lt 1 ] && START=1
    END=$((LINE_NUM + 3))

    CONTEXT=$(sed -n "${START},${END}p" "$FILE" 2>/dev/null || echo "")

    if ! echo "$CONTEXT" | grep -qiE "$STATE_KEYWORDS"; then
      UNJUSTIFIED_TEXT="${UNJUSTIFIED_TEXT}${line}"$'\n'
    fi
  done <<< "$COLORED_TEXT"

  if [ -n "$UNJUSTIFIED_TEXT" ]; then
    COUNT=$(printf '%s\n' "$UNJUSTIFIED_TEXT" | grep -c . || echo 0)
    echo "WARN: $COUNT colored text occurrences without state context"
    echo "      Review each: is it actually carrying a state signal?"
    printf '%s\n' "$UNJUSTIFIED_TEXT" | head -8 | sed 's/^/      /'
    echo ""
  else
    echo "PASS: all colored text has state context"
  fi
else
  echo "PASS: no colored text in [500-900] range without state"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "================================================================"
if [ "$VIOLATIONS" -eq 0 ]; then
  echo "CLEAN — color discipline audit passed (hard rules only)."
  echo "================================================================"
  exit 0
else
  echo "FAILED — $VIOLATIONS hard violations found."
  echo "================================================================"
  echo ""
  echo "Review color-discipline.md:"
  echo "  .claude/skills/ui-design-system/references/color-discipline.md"
  exit 1
fi
