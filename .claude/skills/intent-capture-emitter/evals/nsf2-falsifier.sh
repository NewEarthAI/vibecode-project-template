#!/usr/bin/env bash
# evals/nsf2-falsifier.sh — NSF-2 falsifier-format validator eval (council A7 / Doctrine 04 §6.1.1).
# Tests code-against-spec: FORM (reject prose, require a parsing machine-executable form), REFERENTIAL
# (a type:script path must resolve), COMPLEMENTARITY (the falsifier must differ from binary_test).
# Portable: bash 3.2.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
NSF2="$SCRIPT_DIR/../scripts/nsf2-falsifier-validate.sh"
SELF="$SCRIPT_DIR/nsf2-falsifier.sh"   # a guaranteed-existing absolute file for the script-path case
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

# build a record with a given falsifier (jq value) + binary_test (string)
rec() { jq -nc --argjson f "$1" --arg bt "$2" '{id:"r",binary_test:$bt,falsifier:$f}'; }

chk() { # $1 desc  $2 record-json  $3 expected_code (PASS or a violation code)  $4 expected_rc
  local out rc code
  out="$(bash "$NSF2" "$2" 2>/dev/null)"; rc=$?
  code="$(printf '%s' "$out" | awk '{print $1}' | sed 's/:$//')"
  if [ "$code" = "$3" ] && [ "$rc" = "$4" ]; then ok;
  else bad "$1 — got '$code' rc=$rc, expected '$3' rc=$4 (out: $out)"; fi
}

# 1 null falsifier allowed
chk "null falsifier" "$(rec 'null' 'a test')" PASS 0
# 2 prose string falsifier -> format invalid
chk "prose string falsifier" "$(rec '"the database is enabled"' 'a test')" falsifier_format_invalid 2
# 3 valid jq object
chk "valid jq predicate" "$(rec '{"type":"jq","expr":".enabled==true"}' 'count is positive')" PASS 0
# 4 valid predicate type
chk "valid predicate type" "$(rec '{"type":"predicate","expr":".count > 0"}' 'enabled is true')" PASS 0
# 5 unparseable expr (prose inside expr)
chk "unparseable expr" "$(rec '{"type":"jq","expr":"the database is enabled"}' 'a test')" falsifier_format_invalid 2
# 6 empty expr
chk "empty expr" "$(rec '{"type":"jq","expr":""}' 'a test')" falsifier_format_invalid 2
# 7 broken script path
chk "broken script path" "$(rec "$(jq -nc --arg p "/tmp/nope-$$-does-not-exist.sh" '{type:"script",path:$p}')" 'a test')" falsifier_broken_pointer 2
# 8 existing script path (absolute -> resolves)
chk "existing script path" "$(rec "$(jq -nc --arg p "$SELF" '{type:"script",path:$p}')" 'a test')" PASS 0
# 9 unknown type
chk "unknown falsifier type" "$(rec '{"type":"magic","expr":"x"}' 'a test')" falsifier_format_invalid 2
# 10 non-complementary: identical to binary_test
chk "non-complementary (identical)" "$(rec '{"type":"jq","expr":".enabled==true"}' '.enabled==true')" falsifier_not_complementary 2
# 11 non-complementary: bare negation
chk "non-complementary (bare negation)" "$(rec '{"type":"jq","expr":"(.enabled==true) | not"}' '.enabled==true')" falsifier_not_complementary 2
# 12 complementary, valid (different from binary_test)
chk "complementary valid" "$(rec '{"type":"jq","expr":".rows | length == 0"}' '.enabled==true')" PASS 0
# 13 non-object, non-null (number) -> format invalid
chk "numeric falsifier" "$(rec '42' 'a test')" falsifier_format_invalid 2

echo "== NSF-2 RESULT: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
