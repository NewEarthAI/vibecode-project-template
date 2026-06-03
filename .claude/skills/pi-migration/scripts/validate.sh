#!/bin/bash
# validate.sh — Pi Migration skill validation
# Checks skill structure, content quality, and parameterization.

set -euo pipefail

SKILL_DIR="${1:-.}"
SKILL_FILE="$SKILL_DIR/SKILL.md"
EVAL_FILE="$SKILL_DIR/evals/evals.json"

pass=0
fail=0
warn=0

check() {
  local label="$1" condition="$2"
  if eval "$condition"; then
    pass=$((pass+1))
    echo "  ✓ $label"
  else
    fail=$((fail+1))
    echo "  ✗ $label"
  fi
}

warning() {
  local label="$1" condition="$2"
  if eval "$condition"; then
    warn=$((warn+1))
    echo "  ⚠ $label"
  fi
}

echo "=== Pi Migration Skill Validation ==="
echo ""

# Structure checks
echo "--- Structure ---"
check "SKILL.md exists" "[ -f '$SKILL_FILE' ]"
check "evals/evals.json exists" "[ -f '$EVAL_FILE' ]"
check "scripts/ directory exists" "[ -d '$SKILL_DIR/scripts' ]"

# Content checks
echo ""
echo "--- Content Quality ---"
check "SKILL.md ≤500 lines" "[ \$(wc -l < \"$SKILL_FILE\") -le 500 ]"
check "Description ≤1024 chars" "[ \$(head -20 \"$SKILL_FILE\" | grep -A1 'description:' | tail -1 | wc -c) -le 1024 ]"
check "Has frontmatter" "head -1 \"$SKILL_FILE\" | grep -q '^---'"
check "Has classification" "grep -q 'classification:' \"$SKILL_FILE\""
check "Has parameters" "grep -q 'parameters:' \"$SKILL_FILE\""

# Parameterization checks
echo ""
echo "--- Parameterization ---"
check "No hardcoded home paths" "! grep -q '/Users/cassandrasnyman' \"$SKILL_FILE\""
check "Uses {{parameter}} syntax" "grep -q '{{' \"$SKILL_FILE\""
check "Has anti-patterns section" "grep -q 'Anti-Pattern' \"$SKILL_FILE\""

# Eval checks
echo ""
echo "--- Evals ---"
check "Has ≥3 evals" "[ \$(jq '.evals | length' \"$EVAL_FILE\") -ge 3 ]"
check "Has should_trigger: true cases" "jq -e '.evals[] | select(.should_trigger == true)' \"$EVAL_FILE\" > /dev/null"
check "Has should_trigger: false cases" "jq -e '.evals[] | select(.should_trigger == false)' \"$EVAL_FILE\" > /dev/null"
check "Each eval has expectations" "jq -e '.evals[] | select(.should_trigger == true) | select(.expectations | length > 0)' \"$EVAL_FILE\" > /dev/null"

# Summary
echo ""
echo "=== Results ==="
echo "  Passed: $pass"
echo "  Failed: $fail"
echo "  Warnings: $warn"

if [ "$fail" -gt 0 ]; then
  echo ""
  echo "FAILED — fix issues before storing skill"
  exit 1
else
  echo ""
  echo "PASSED — skill is ready"
  exit 0
fi
