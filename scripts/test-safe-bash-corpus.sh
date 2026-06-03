#!/usr/bin/env bash
# =============================================================================
# safe-bash test corpus — validates hook regex catches dangerous commands
# and does NOT block routine development operations.
# Usage: ./scripts/test-safe-bash-corpus.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

# The hook regex pattern (must match hookify.safe-bash-enforcer.local.md)
# Uses ERE (grep -E) for macOS compatibility — no -P flag
HOOK_REGEX='rm[[:space:]]+-rf[[:space:]]+[/~.]|dd[[:space:]]+if=|mkfs|chmod[[:space:]]+-?R?[[:space:]]*777|eval[[:space:]]|exec[[:space:]]|:\(\)\{|nc[[:space:]]+-l|ncat[[:space:]]+-l|socat[[:space:]]+TCP-LISTEN'

check_blocked() {
  local desc="$1"
  local cmd="$2"
  local matched=0
  echo "$cmd" | grep -qE "$HOOK_REGEX" && matched=1 || true
  if [ "$matched" -eq 1 ]; then
    echo -e "${GREEN}✓${NC} BLOCKED: ${desc}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} MISSED:  ${desc} — command: ${cmd}"
    FAIL=$((FAIL + 1))
  fi
}

check_allowed() {
  local desc="$1"
  local cmd="$2"
  local matched=0
  echo "$cmd" | grep -qE "$HOOK_REGEX" && matched=1 || true
  if [ "$matched" -eq 1 ]; then
    echo -e "${RED}✗${NC} FALSE POSITIVE: ${desc} — command: ${cmd}"
    FAIL=$((FAIL + 1))
  else
    echo -e "${GREEN}✓${NC} ALLOWED: ${desc}"
    PASS=$((PASS + 1))
  fi
}

echo "============================================"
echo "safe-bash TEST CORPUS"
echo "============================================"
echo ""

# --- BLOCK cases (Layer 3 must catch these) ---
echo "BLOCK CASES (must be caught by hook regex)"
echo "-------------------------------------------"

check_blocked "rm -rf /"          "rm -rf /"
check_blocked "rm -rf ~"          "rm -rf ~"
check_blocked "rm -rf ."          "rm -rf ."
check_blocked "rm -rf /var/data"  "rm -rf /var/data"
check_blocked "dd if=/dev/zero"   "dd if=/dev/zero of=/dev/sda"
check_blocked "mkfs.ext4"         "mkfs.ext4 /dev/sda1"
check_blocked "chmod 777"         "chmod 777 /etc/passwd"
check_blocked "chmod -R 777"      "chmod -R 777 /var/www"
check_blocked "eval injection"    "eval \$USER_INPUT"
check_blocked "exec injection"    "exec /bin/sh"
check_blocked "fork bomb"         ":(){ :|:& };:"
check_blocked "nc listener"       "nc -l 4444"
check_blocked "ncat listener"     "ncat -l 8080"
check_blocked "socat listener"    "socat TCP-LISTEN:1234 -"

echo ""

# --- ALLOW cases (routine dev ops must NOT be blocked) ---
echo "ALLOW CASES (must NOT be caught by hook regex)"
echo "------------------------------------------------"

check_allowed "git status"        "git status"
check_allowed "git diff"          "git diff --stat"
check_allowed "git add"           "git add src/App.tsx"
check_allowed "git commit"        "git commit -m 'fix: update thing'"
check_allowed "git log"           "git log --oneline -10"
check_allowed "git push"          "git push origin main"
check_allowed "npm run dev"       "npm run dev"
check_allowed "npm run build"     "npm run build"
check_allowed "npm run lint"      "npm run lint"
check_allowed "npm install"       "npm install"
check_allowed "npx tsc"           "npx tsc --noEmit"
check_allowed "ls"                "ls -la src/"
check_allowed "node version"      "node -v"
check_allowed "cat file"          "cat package.json"
check_allowed "mkdir"             "mkdir -p src/components/new"
check_allowed "cp file"           "cp src/App.tsx src/App.backup.tsx"
check_allowed "safe rm (file)"    "rm src/temp.txt"
check_allowed "safe rm -r (dir)"  "rm -r node_modules/.cache"
check_allowed "curl (no secrets)" "curl -s https://api.example.com/health"
check_allowed "task: export"      "bash scripts/n8n_export_workflow.sh abc123"
check_allowed "task: commit"      "bash scripts/git_commit_if_changed.sh file.json msg"
check_allowed "task: selfcheck"   "bash scripts/selfcheck-safe-bash.sh"

echo ""

# --- Summary ---
echo "============================================"
echo "TEST CORPUS SUMMARY"
echo "============================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}TEST CORPUS FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}TEST CORPUS PASSED${NC}"
  exit 0
fi
