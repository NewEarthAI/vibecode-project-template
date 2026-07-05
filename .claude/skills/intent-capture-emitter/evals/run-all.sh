#!/usr/bin/env bash
# evals/run-all.sh — the intent-capture-emitter formal eval suite (aggregate runner).
# Runs every eval file, prints each summary line, and exits non-zero if any suite failed.
# Portable: bash 3.2.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

SUITES="
intent-store-supersession.sh
parsers.sh
nsf1-staleness.sh
nsf2-falsifier.sh
nsf3-wired-integrity.sh
intent-computed.sh
"

fail_total=0
echo "=== intent-capture-emitter eval suite ==="
for s in $SUITES; do
  f="$SCRIPT_DIR/$s"
  if [ ! -f "$f" ]; then echo "[MISSING] $s"; fail_total=$((fail_total+1)); continue; fi
  out="$(bash "$f" 2>&1)"; rc=$?
  # surface the RESULT line (and any FAIL lines) from each suite
  printf '%s\n' "$out" | grep -E "RESULT|FAIL:" || true
  [ "$rc" -eq 0 ] || fail_total=$((fail_total+1))
done

echo "=========================================="
if [ "$fail_total" -eq 0 ]; then
  echo "ALL SUITES GREEN"
  exit 0
else
  echo "SUITES FAILED: $fail_total"
  exit 1
fi
