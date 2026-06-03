#!/usr/bin/env bash
# ==============================================================================
# NewEarth UI Design — Hover Curve Consistency Audit
# ------------------------------------------------------------------------------
# Verifies that interactive cards use the signature hover curve:
#   transition-all duration-300 hover:shadow-lg hover:-translate-y-0.5
#
# Uses POSIX grep for portability.
#
# Usage:
#   bash audit-hover-consistency.sh [project_root]
#
# Exit codes:
#   0 = clean
#   1 = deviations found
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
  --include='*.tsx' --include='*.jsx'
)
GREP_EXCLUDES=(
  --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build
  --exclude-dir=.next --exclude-dir=.git --exclude-dir=.claude
  --exclude='*.min.*'
)

echo "================================================================"
echo "NewEarth UI Design — Hover Curve Consistency Audit"
echo "================================================================"
echo "Scanning: $TARGET"
echo ""

# -----------------------------------------------------------------------------
# Rule 1: Non-signature durations on transition-all (WARN)
# -----------------------------------------------------------------------------
echo "--- Non-signature transition durations ---"

# Only catch obviously wrong durations used with transition-all
WRONG_DURATION=$(grep -rEn \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  'transition-all[^"'\'']{0,80}duration-(75|100|500|700|1000)' \
  "$TARGET" 2>/dev/null || true)

if [ -n "$WRONG_DURATION" ]; then
  COUNT=$(printf '%s\n' "$WRONG_DURATION" | wc -l | tr -d ' ')
  echo "WARN: $COUNT non-signature transition durations (should be duration-300)"
  printf '%s\n' "$WRONG_DURATION" | head -8 | sed 's/^/      /'
  echo ""
else
  echo "PASS: transitions use duration-300 or compatible (150/200)"
fi

# -----------------------------------------------------------------------------
# Rule 2: Interactive Cards missing translate-y lift (HARD FAIL)
# -----------------------------------------------------------------------------
echo ""
echo "--- Clickable Cards without signature hover lift ---"

# Find Card components with onClick
CARD_ONCLICK=$(grep -rEn \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  '<Card[^>]*onClick' \
  "$TARGET" 2>/dev/null || true)

MISSING_LIFT=""
if [ -n "$CARD_ONCLICK" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    FILE=$(echo "$line" | cut -d: -f1)
    LINE_NUM=$(echo "$line" | cut -d: -f2)

    # Check this line plus next 8 (JSX can span lines)
    END=$((LINE_NUM + 8))
    SNIPPET=$(sed -n "${LINE_NUM},${END}p" "$FILE" 2>/dev/null || echo "")

    # Pass if any of these markers present
    if ! echo "$SNIPPET" | grep -qE 'hover:-translate-y|ne-card-interactive|ne-card-premium|[[:space:]]interactive[[:space:]]|[[:space:]]interactive=|hover:scale'; then
      MISSING_LIFT="${MISSING_LIFT}${line}"$'\n'
    fi
  done <<< "$CARD_ONCLICK"
fi

if [ -n "$MISSING_LIFT" ]; then
  COUNT=$(printf '%s\n' "$MISSING_LIFT" | grep -c . || echo 0)
  echo "FAIL: $COUNT clickable Cards without the signature hover curve"
  echo "      Interactive cards must lift (hover:-translate-y-0.5)"
  echo "      OR use ne-card-interactive / ne-card-premium"
  echo "      OR pass \`interactive\` prop to Card."
  printf '%s\n' "$MISSING_LIFT" | head -10 | sed 's/^/      /'
  VIOLATIONS=$((VIOLATIONS + COUNT))
  echo ""
else
  echo "PASS: clickable Cards use signature hover curve"
fi

# -----------------------------------------------------------------------------
# Rule 3: Large hover:scale values (WARN — reads consumer)
# -----------------------------------------------------------------------------
echo ""
echo "--- Bespoke large hover:scale values ---"

LARGE_SCALE=$(grep -rEn \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  'hover:scale-(105|110|125|150|200)' \
  "$TARGET" 2>/dev/null || true)

if [ -n "$LARGE_SCALE" ]; then
  COUNT=$(printf '%s\n' "$LARGE_SCALE" | wc -l | tr -d ' ')
  echo "WARN: $COUNT large hover:scale values (premium = scale-[1.02] max)"
  printf '%s\n' "$LARGE_SCALE" | head -8 | sed 's/^/      /'
  echo ""
else
  echo "PASS: no bespoke large hover:scale values"
fi

# -----------------------------------------------------------------------------
# Rule 4: Colored hover outlines (HARD FAIL — must be silver)
# -----------------------------------------------------------------------------
echo ""
echo "--- Non-silver hover outlines ---"

COLORED_OUTLINE=$(grep -rEn \
  "${GREP_INCLUDES[@]}" "${GREP_EXCLUDES[@]}" \
  'hover:outline-(red|green|blue|amber|purple|pink|orange|yellow|emerald|teal|cyan|indigo)-[0-9]' \
  "$TARGET" 2>/dev/null || true)

if [ -n "$COLORED_OUTLINE" ]; then
  COUNT=$(printf '%s\n' "$COLORED_OUTLINE" | wc -l | tr -d ' ')
  echo "FAIL: $COUNT colored hover outlines (must be silver)"
  printf '%s\n' "$COLORED_OUTLINE" | head -8 | sed 's/^/      /'
  VIOLATIONS=$((VIOLATIONS + COUNT))
  echo ""
else
  echo "PASS: hover outlines are silver (or none present)"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "================================================================"
if [ "$VIOLATIONS" -eq 0 ]; then
  echo "CLEAN — hover consistency audit passed."
  echo "================================================================"
  exit 0
else
  echo "FAILED — $VIOLATIONS hard violations found."
  echo "================================================================"
  echo ""
  echo "Reference: silver-signature.md (Mode C — hover ring)"
  exit 1
fi
