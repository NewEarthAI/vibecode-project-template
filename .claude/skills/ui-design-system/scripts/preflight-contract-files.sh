#!/usr/bin/env bash
# A6 pre-flight — asserts L1/L2 contract files exist + non-empty.
# Wire into /verify-hooks or run standalone before invoking ui-design-system.
# Exits non-zero with human-readable error if any contract is missing.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fail=0
check() { local p="$1" label="$2"; if [ ! -s "$ROOT/$p" ]; then echo "  MISSING or EMPTY  $label  →  $p"; fail=$((fail+1)); else echo "  OK  $label"; fi; }
echo "═══ the agency Design Suite v2 — Contract Pre-Flight ═══"
check "PRODUCT.md" "L1 identity (PRODUCT.md)"
check "DESIGN.md" "L1 visual system (DESIGN.md)"
check ".claude/skills/design-taste-frontend/SKILL.md" "L2 anti-slop overlay"
if [ "$fail" -gt 0 ]; then
  echo ""; echo "FAIL — $fail contract file(s) missing. ui-design-system will HALT on invocation."; echo "Run 'impeccable teach' (interactive, Justin in the loop) to author PRODUCT.md + DESIGN.md."; echo "Ref: continuations/NEWEARTH-DESIGN-SUITE-V2-MASTER-CONTINUATION-2026-05-13.md §15 (A2, A6)."; exit 1
fi
echo ""; echo "PASS — all contract files present. ui-design-system can apply L1 → L2 → L3 stack."
