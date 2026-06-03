#!/usr/bin/env bash
# =============================================================================
# safe-bash selfcheck — validates installation and configuration
# Usage: ./scripts/selfcheck-safe-bash.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "============================================"
echo "safe-bash SELFCHECK"
echo "============================================"
echo "Repo: ${REPO_ROOT}"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
echo ""

# --- 1. Skill file exists and validates ---
echo "SKILL CHECKS"
echo "------------"

SKILL_FILE="${REPO_ROOT}/.claude/skills/safe-bash/SKILL.md"
if [ -f "$SKILL_FILE" ]; then
  echo -e "${GREEN}✓${NC} SKILL.md exists"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} SKILL.md missing at ${SKILL_FILE}"
  FAIL=$((FAIL + 1))
fi

# Run skill-creator validator if available
VALIDATOR="${REPO_ROOT}/.claude/skills/skill-creator/scripts/validate.sh"
if [ -f "$VALIDATOR" ]; then
  echo -n "  Running skill validator... "
  if bash "$VALIDATOR" "${REPO_ROOT}/.claude/skills/safe-bash" > /dev/null 2>&1; then
    echo -e "${GREEN}PASSED${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARNINGS${NC}"
    WARN=$((WARN + 1))
  fi
fi

# --- 2. Task scripts exist and are executable ---
echo ""
echo "SCRIPT CHECKS"
echo "-------------"

SCRIPTS=(
  "scripts/n8n_export_workflow.sh"
  "scripts/n8n_import_workflow.sh"
  "scripts/n8n_verify_workflow.sh"
  "scripts/git_commit_if_changed.sh"
)

for script in "${SCRIPTS[@]}"; do
  FULL_PATH="${REPO_ROOT}/${script}"
  if [ -f "$FULL_PATH" ]; then
    if [ -x "$FULL_PATH" ]; then
      echo -e "${GREEN}✓${NC} ${script} (executable)"
      PASS=$((PASS + 1))
    else
      echo -e "${YELLOW}⚠${NC} ${script} (exists but not executable)"
      WARN=$((WARN + 1))
    fi
  else
    echo -e "${RED}✗${NC} ${script} MISSING"
    FAIL=$((FAIL + 1))
  fi
done

# --- 3. Hook file exists ---
echo ""
echo "HOOK CHECKS"
echo "-----------"

HOOK_FILE="${REPO_ROOT}/.claude/hookify.safe-bash-enforcer.local.md"
if [ -f "$HOOK_FILE" ]; then
  echo -e "${GREEN}✓${NC} Enforcement hook exists"
  PASS=$((PASS + 1))

  # Check it's a block action
  if grep -q "action: block" "$HOOK_FILE"; then
    echo -e "${GREEN}✓${NC} Hook action is 'block'"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}⚠${NC} Hook action is not 'block'"
    WARN=$((WARN + 1))
  fi

  # Check it uses PreToolUse
  if grep -q "event: PreToolUse" "$HOOK_FILE"; then
    echo -e "${GREEN}✓${NC} Hook event is PreToolUse"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} Hook event is not PreToolUse"
    FAIL=$((FAIL + 1))
  fi
else
  echo -e "${RED}✗${NC} Enforcement hook missing at ${HOOK_FILE}"
  FAIL=$((FAIL + 1))
fi

# --- 4. Environment variables ---
echo ""
echo "ENV CHECKS"
echo "----------"

if [ -n "${N8N_BASE_URL:-}" ]; then
  echo -e "${GREEN}✓${NC} N8N_BASE_URL set"
  PASS=$((PASS + 1))
else
  echo -e "${YELLOW}⚠${NC} N8N_BASE_URL not set (n8n tasks will fail deterministically)"
  WARN=$((WARN + 1))
fi

if [ -n "${N8N_API_KEY:-}" ]; then
  echo -e "${GREEN}✓${NC} N8N_API_KEY set (redacted)"
  PASS=$((PASS + 1))
else
  echo -e "${YELLOW}⚠${NC} N8N_API_KEY not set (n8n tasks will fail deterministically)"
  WARN=$((WARN + 1))
fi

# --- 5. Test corpus ---
echo ""
echo "TEST CORPUS"
echo "-----------"

TEST_CORPUS="${REPO_ROOT}/scripts/test-safe-bash-corpus.sh"
if [ -f "$TEST_CORPUS" ] && [ -x "$TEST_CORPUS" ]; then
  echo -n "  Running test corpus... "
  if bash "$TEST_CORPUS" > /dev/null 2>&1; then
    echo -e "${GREEN}ALL PASSED${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAILURES DETECTED${NC}"
    echo "  Re-running with output:"
    bash "$TEST_CORPUS" 2>&1 | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
else
  echo -e "${YELLOW}⚠${NC} test-safe-bash-corpus.sh missing or not executable"
  WARN=$((WARN + 1))
fi

# --- 6. No duplicate hooks ---
echo ""
echo "HOOK UNIQUENESS"
echo "---------------"

HOOK_DIR="${REPO_ROOT}/.claude"
# Check (name+event+matcher+action) combos — same matcher with different conditions is allowed
COMBOS=$(for f in "${HOOK_DIR}"/hookify.*.local.md; do
  NAME=$(grep "^name:" "$f" | head -1)
  EVENT=$(grep "^event:" "$f" | head -1)
  MATCHER=$(grep "^tool_matcher:" "$f" | head -1)
  ACTION=$(grep "^action:" "$f" | head -1)
  echo "${NAME}|${EVENT}|${MATCHER}|${ACTION}"
done | sort)
UNIQUE_COMBOS=$(echo "$COMBOS" | sort -u)

if [ "$(echo "$COMBOS" | wc -l)" = "$(echo "$UNIQUE_COMBOS" | wc -l)" ]; then
  echo -e "${GREEN}✓${NC} All (name+event+matcher+action) combos are unique"
  PASS=$((PASS + 1))
else
  echo -e "${RED}✗${NC} Duplicate hook combos detected!"
  comm -23 <(echo "$COMBOS") <(echo "$UNIQUE_COMBOS")
  FAIL=$((FAIL + 1))
fi

# Note: same tool_matcher with different conditions is intentional (e.g., two SQL checks)
MATCHERS=$(grep -h "^tool_matcher:" "${HOOK_DIR}"/hookify.*.local.md 2>/dev/null | sort)
UNIQUE_MATCHERS=$(echo "$MATCHERS" | sort -u)
DUP_COUNT=$(( $(echo "$MATCHERS" | wc -l) - $(echo "$UNIQUE_MATCHERS" | wc -l) ))
if [ "$DUP_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}⚠${NC} ${DUP_COUNT} shared tool_matcher(s) (OK if different conditions)"
  WARN=$((WARN + 1))
fi

# Check no event: all
if grep -l "event: all" "${HOOK_DIR}"/hookify.*.local.md 2>/dev/null; then
  echo -e "${RED}✗${NC} Found 'event: all' in hooks (should be PreToolUse)"
  FAIL=$((FAIL + 1))
else
  echo -e "${GREEN}✓${NC} No 'event: all' found"
  PASS=$((PASS + 1))
fi

# --- Summary ---
echo ""
echo "============================================"
echo "SELFCHECK SUMMARY"
echo "============================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}SELFCHECK FAILED${NC}"
  exit 1
elif [ "$WARN" -gt 2 ]; then
  echo -e "${YELLOW}PASSED WITH WARNINGS${NC}"
  exit 0
else
  echo -e "${GREEN}SELFCHECK PASSED${NC}"
  exit 0
fi
