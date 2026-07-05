#!/usr/bin/env bash
# intent-capture-emitter/scripts/nsf2-falsifier-validate.sh — NSF-2 (council A7), the direct guard
# against the vacuous-green-light failure (DESTINATION Element 4).
#
# Validates the `falsifier` of an intent record against the Doctrine 04 §6.1.1 machine-executable FORMAT.
# Tests the code AGAINST THE DOCTRINE SPEC (not against itself): the spec lives in §6.1.1; this
# script enforces the three rules it states.
#
# The falsifier, WHEN PRESENT (non-null), MUST be a structured object:
#   { "type": "jq" | "predicate" | "script",
#     "expr": "<jq predicate>"   (required for type jq|predicate),
#     "path": "<file>"           (required for type script),
#     "description": "<human note>"  (optional) }
# A null falsifier is allowed (the field is optional; absence is not a violation — only a PRESENT
# prose/broken/non-complementary falsifier is).
#
# Three rules (§6.1.1):
#   1. FORM        — machine-executable, never prose. A non-object falsifier, or a jq `expr` that
#                    does not parse, is `falsifier_format_invalid` (prose fails to parse as jq).
#   2. REFERENTIAL — a type:script `path` must resolve to an existing file, else `falsifier_broken_pointer`.
#   3. COMPLEMENTARITY — the falsifier must differ from `binary_test` (not a mere negation), else
#                    `falsifier_not_complementary`.
#
# Usage:
#   nsf2-falsifier-validate.sh '<record-json>'        -> validate one record
#   nsf2-falsifier-validate.sh --all                  -> validate every record in INTENT_SUBSTRATE_PATH
# Output: "PASS" (rc 0) or "<code>: <detail>" lines (rc 2). rc 6 on bad input / jq missing.
#
# Portability: set -o pipefail, namespaced locals; no apostrophes inside inline single-quoted jq.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER_PATH="${INTENT_SUBSTRATE_PATH:-$PROJECT_DIR/.understand-anything/intent-ledger.json}"
command -v jq >/dev/null 2>&1 || { echo "nsf2: jq not found" >&2; exit 6; }

# Validate ONE record (passed as JSON on $1). Echoes violation lines; returns 0 clean / 2 violations.
_validate_one() {
  local rec="$1" id fal_type fal_expr fal_path bt viol=0
  if ! printf '%s' "$rec" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "nsf2: input is not a JSON object" >&2; return 6
  fi
  id="$(printf '%s' "$rec" | jq -r '.id // "?"')"
  # Null/absent falsifier is allowed — nothing to validate.
  if printf '%s' "$rec" | jq -e '.falsifier == null' >/dev/null 2>&1; then
    echo "PASS"; return 0
  fi
  # RULE 1a — FORM: must be an object with a known type.
  if ! printf '%s' "$rec" | jq -e '.falsifier | type == "object"' >/dev/null 2>&1; then
    echo "falsifier_format_invalid: record $id falsifier is not a structured object (prose/bare value rejected — D04 §6.1.1)"
    return 2
  fi
  fal_type="$(printf '%s' "$rec" | jq -r '.falsifier.type // ""')"
  case "$fal_type" in
    jq|predicate)
      fal_expr="$(printf '%s' "$rec" | jq -r '.falsifier.expr // ""')"
      if [ -z "$fal_expr" ]; then
        echo "falsifier_format_invalid: record $id type=$fal_type but .falsifier.expr is empty"; viol=1
      else
        # RULE 1b — the expr must PARSE+RUN as jq (prose will not). Run against null input;
        # a parse error is a non-zero jq exit -> prose/garbage rejected.
        if ! printf 'null' | jq "$fal_expr" >/dev/null 2>&1; then
          echo "falsifier_format_invalid: record $id .falsifier.expr is not a valid jq predicate (does not parse — prose rejected)"; viol=1
        fi
      fi
      ;;
    script)
      fal_path="$(printf '%s' "$rec" | jq -r '.falsifier.path // ""')"
      if [ -z "$fal_path" ]; then
        echo "falsifier_format_invalid: record $id type=script but .falsifier.path is empty"; viol=1
      else
        # resolve relative to the project root if not absolute
        case "$fal_path" in /*) : ;; *) fal_path="$PROJECT_DIR/$fal_path";; esac
        if [ ! -f "$fal_path" ]; then
          echo "falsifier_broken_pointer: record $id type=script path does not resolve to a file ($fal_path)"; viol=1
        fi
      fi
      ;;
    *)
      echo "falsifier_format_invalid: record $id has unknown falsifier.type '$fal_type' (one of: jq predicate script)"; viol=1
      ;;
  esac
  # RULE 3 — COMPLEMENTARITY: the falsifier must not be the binary_test verbatim nor its bare
  # negation. Heuristic (v1, structural): compare the falsifier expr/description against binary_test,
  # normalised (lowercased, whitespace-collapsed); reject equality or a `(<bt>) | not` shape.
  bt="$(printf '%s' "$rec" | jq -r '(.binary_test // "") | ascii_downcase | gsub("\\s+";" ") | gsub("^ +| +$";"")')"
  if [ -n "$bt" ]; then
    local fnorm
    fnorm="$(printf '%s' "$rec" | jq -r '((.falsifier.expr // .falsifier.description // "") | ascii_downcase | gsub("\\s+";" ") | gsub("^ +| +$";""))')"
    if [ -n "$fnorm" ]; then
      if [ "$fnorm" = "$bt" ] || [ "$fnorm" = "($bt) | not" ] || [ "$fnorm" = "not ($bt)" ] || [ "$fnorm" = "($bt)|not" ]; then
        echo "falsifier_not_complementary: record $id falsifier is identical to / a bare negation of binary_test (adds no failure mode — D04 §6.1.1 rule 3)"; viol=1
      fi
    fi
  fi
  if [ "$viol" -eq 0 ]; then echo "PASS"; return 0; fi
  return 2
}

main() {
  local arg="${1:-}"
  if [ "$arg" = "--all" ]; then
    [ -f "$LEDGER_PATH" ] || { echo "nsf2: ledger not found at $LEDGER_PATH (run init)" >&2; exit 6; }
    local recs n i rec out rc=0 any=0
    n="$(jq '.records | length' "$LEDGER_PATH" 2>/dev/null || echo 0)"
    i=0
    while [ "$i" -lt "$n" ]; do
      rec="$(jq -c --argjson i "$i" '.records[$i]' "$LEDGER_PATH")"
      out="$(_validate_one "$rec")"; [ "$?" -ne 0 ] && rc=2
      if [ "$out" != "PASS" ]; then echo "$out"; any=1; fi
      i=$((i + 1))
    done
    [ "$any" -eq 0 ] && echo "PASS (all $n records)"
    return "$rc"
  fi
  [ -n "$arg" ] || { echo "nsf2: usage: nsf2-falsifier-validate.sh '<record-json>' | --all" >&2; exit 6; }
  _validate_one "$arg"
}

main "$@"
