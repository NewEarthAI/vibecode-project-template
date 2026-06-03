#!/bin/bash
# =============================================================================
# SKILL VALIDATION v3.0 — Abstraction-First
# =============================================================================
# Validates skills for proper abstraction, not just format.
#
# Usage: bash validate.sh /path/to/skill/
# =============================================================================

SKILL_PATH="${1:-.}"
SKILL_FILE="$SKILL_PATH/SKILL.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

echo "============================================"
echo "SKILL VALIDATION v3.0 — Abstraction Check"
echo "============================================"
echo "Path: $SKILL_PATH"
echo "============================================"

if [ ! -f "$SKILL_FILE" ]; then
    echo -e "${RED}✗ No SKILL.md found${NC}"
    exit 1
fi

# -----------------------------------------------------------------------------
# FORMAT CHECKS
# -----------------------------------------------------------------------------

echo ""
echo "FORMAT CHECKS"
echo "-------------"

# Name check
NAME=$(grep "^name:" "$SKILL_FILE" | head -1 | sed 's/name:[[:space:]]*//')
if [ -n "$NAME" ] && [ ${#NAME} -le 64 ] && [[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo -e "${GREEN}✓${NC} Name valid: $NAME"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Name invalid or missing"
    ((FAIL++))
fi

# Line count
LINES=$(wc -l < "$SKILL_FILE")
if [ "$LINES" -le 500 ]; then
    echo -e "${GREEN}✓${NC} Length: $LINES lines (≤500)"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Too long: $LINES lines (max 500)"
    ((FAIL++))
fi

# Description length (~100 tokens ≈ 400 chars for discovery)
DESC_LEN=$(grep -A5 "^description:" "$SKILL_FILE" | head -6 | wc -c)
if [ "$DESC_LEN" -le 500 ]; then
    echo -e "${GREEN}✓${NC} Description concise for discovery"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} Description may be too long for efficient discovery"
    ((WARN++))
fi

# -----------------------------------------------------------------------------
# ABSTRACTION CHECKS (Critical)
# -----------------------------------------------------------------------------

echo ""
echo "ABSTRACTION CHECKS"
echo "------------------"

# Check for hardcoded record IDs
RECORD_IDS=$(grep -oE "rec[A-Z][A-Za-z0-9_]{4,}" "$SKILL_FILE" | wc -l)
if [ "$RECORD_IDS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No hardcoded record IDs"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Found $RECORD_IDS hardcoded record ID(s)"
    grep -oE "rec[A-Z][A-Za-z0-9_]{4,}" "$SKILL_FILE" | head -3
    ((FAIL++))
fi

# Check for hardcoded workflow IDs
WORKFLOW_IDS=$(grep -oE "wf_[A-Za-z0-9_]+" "$SKILL_FILE" | wc -l)
if [ "$WORKFLOW_IDS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No hardcoded workflow IDs"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Found $WORKFLOW_IDS hardcoded workflow ID(s)"
    grep -oE "wf_[A-Za-z0-9_]+" "$SKILL_FILE" | head -3
    ((FAIL++))
fi

# Check for hardcoded table names (common patterns)
TABLE_NAMES=$(grep -oE "tbl[A-Z][A-Za-z]+" "$SKILL_FILE" | wc -l)
if [ "$TABLE_NAMES" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No hardcoded table names (tbl* pattern)"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Found $TABLE_NAMES hardcoded table name(s)"
    grep -oE "tbl[A-Z][A-Za-z]+" "$SKILL_FILE" | head -3
    ((FAIL++))
fi

# Check for hardcoded user IDs
USER_IDS=$(grep -oE "user_[A-Za-z0-9_]+" "$SKILL_FILE" | wc -l)
if [ "$USER_IDS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No hardcoded user IDs"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Found $USER_IDS hardcoded user ID(s)"
    grep -oE "user_[A-Za-z0-9_]+" "$SKILL_FILE" | head -3
    ((FAIL++))
fi

# Check for project-specific URLs (excluding docs/examples)
SPECIFIC_URLS=$(grep -oE "https?://[a-zA-Z0-9.-]+\.(com|io|dev|app)/[^ ]*" "$SKILL_FILE" | \
                grep -v "github.com\|docs\.\|example\." | wc -l)
if [ "$SPECIFIC_URLS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No project-specific URLs"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} Found $SPECIFIC_URLS potentially specific URL(s)"
    grep -oE "https?://[a-zA-Z0-9.-]+\.(com|io|dev|app)/[^ ]*" "$SKILL_FILE" | \
        grep -v "github.com\|docs\.\|example\." | head -3
    ((WARN++))
fi

# Check for parameterization (should have {{placeholders}})
PARAMS=$(grep -oE "\{\{[a-z_]+\}\}" "$SKILL_FILE" | wc -l)
if [ "$PARAMS" -ge 1 ]; then
    echo -e "${GREEN}✓${NC} Uses parameterization ($PARAMS placeholders)"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} No {{parameters}} found — may be too specific"
    ((WARN++))
fi

# -----------------------------------------------------------------------------
# CONTENT CHECKS
# -----------------------------------------------------------------------------

echo ""
echo "CONTENT CHECKS"
echo "--------------"

# Anti-patterns
AP_COUNT=$(grep -c "| .* | .* | .* |" "$SKILL_FILE" 2>/dev/null || echo 0)
AP_COUNT=$((AP_COUNT > 2 ? AP_COUNT - 2 : 0)) # subtract headers
if [ "$AP_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✓${NC} Anti-patterns: $AP_COUNT documented"
    ((PASS++))
elif [ "$AP_COUNT" -ge 1 ]; then
    echo -e "${YELLOW}⚠${NC} Anti-patterns: $AP_COUNT (recommend 3+)"
    ((WARN++))
else
    echo -e "${RED}✗${NC} No anti-patterns documented"
    ((FAIL++))
fi

# Check for vague terms
VAGUE=$(grep -ciE "\breasonable\b|\bappropriate\b|\badequate\b|\bsufficient\b" "$SKILL_FILE" || echo "0")
VAGUE=$(echo "$VAGUE" | tr -d '[:space:]')
if [ "$VAGUE" -eq 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓${NC} No vague terms"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Found $VAGUE vague term(s) — use concrete values"
    ((FAIL++))
fi

# Check for defaults section
if grep -qiE "default|Default" "$SKILL_FILE"; then
    echo -e "${GREEN}✓${NC} Has defaults documentation"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} No defaults section — parameters need defaults"
    ((WARN++))
fi

# Check for validated_on (held-out test evidence)
if grep -qiE "validated.on|tested.on|works.for" "$SKILL_FILE"; then
    echo -e "${GREEN}✓${NC} Has validation evidence"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} No held-out validation documented"
    ((WARN++))
fi

# -----------------------------------------------------------------------------
# ABSTRACTION QUALITY ASSESSMENT
# -----------------------------------------------------------------------------

echo ""
echo "ABSTRACTION QUALITY"
echo "-------------------"

# Count mechanisms vs instances
MECHANISM_WORDS=$(grep -ciE "because|causes|mechanism|pattern|type|category|structure" "$SKILL_FILE" || echo 0)
INSTANCE_WORDS=$(grep -ciE "specific|particular|this one|exact|precisely" "$SKILL_FILE" || echo 0)

if [ "$MECHANISM_WORDS" -gt "$INSTANCE_WORDS" ]; then
    echo -e "${GREEN}✓${NC} Pattern-focused language ($MECHANISM_WORDS mechanism vs $INSTANCE_WORDS instance)"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} May be too instance-focused (review language)"
    ((WARN++))
fi

# Check for WHY explanations
WHY_COUNT=$(grep -ciE "\bwhy\b|because|reason|cause" "$SKILL_FILE" || echo 0)
if [ "$WHY_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✓${NC} Explains mechanisms ($WHY_COUNT WHY explanations)"
    ((PASS++))
else
    echo -e "${YELLOW}⚠${NC} Limited WHY explanations — add more mechanism context"
    ((WARN++))
fi

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------

echo ""
echo "============================================"
echo "VALIDATION SUMMARY"
echo "============================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}VALIDATION FAILED${NC}"
    echo ""
    echo "Common fixes:"
    echo "• Replace hardcoded IDs with {{parameters}}"
    echo "• Use error TYPES not exact messages"
    echo "• Add mechanism explanations (WHY)"
    echo "• Document defaults for all parameters"
    exit 1
elif [ "$WARN" -gt 3 ]; then
    echo -e "${YELLOW}PASSED WITH WARNINGS${NC}"
    echo "Consider addressing warnings for better reusability."
    exit 0
else
    echo -e "${GREEN}VALIDATION PASSED${NC}"
    echo "Skill is properly abstracted for reuse."
    exit 0
fi
