#!/usr/bin/env bash
# autovibe/verify-continuation.sh — Pillar D' Verifier (added 2026-05-08)
#
# Structural lint gate for Phase 4.7 MASTER continuations BEFORE Phase 4.8 autofire spawns
# a fresh chat. Lean bash-only V1 per `feedback_d-prime-family-elevated-2026-05-08.md` —
# upgrade to Claude --print subprocess only if structural-only checks miss semantic junk.
#
# Composes with:
#   .claude/skills/autovibe/SKILL.md Phase 4.8 (the firer that calls this script)
#   .claude/skills/autovibe/scripts/post-handoff-writer.sh (canonical filename source-of-truth)
#   .claude/rules/operational-guardrails.md Confident Mode (destructive-keyword scan)
#
# Usage:
#   verify-continuation.sh <path>          → exit 0 PASS; non-zero FAIL with [FAIL] reason on stderr
#   verify-continuation.sh --self-test     → run T1-T11 fixtures; ALL PASS or first FAIL
#
# Exit codes (stable contract — Phase 4.8 reads these to log skip-reason):
#   0  PASS                       — autofire MAY proceed; stdout emits "[PASS] ... sha256=<hex>"
#   1  FAIL_MISSING               — file does not exist
#   2  FAIL_SIZE                  — file < 500 bytes (junk threshold)
#   3  FAIL_FILENAME              — basename does not match AUTOVIBE-{ts}-{slug}-MASTER.md
#   4  FAIL_STRUCTURE             — fewer than 8 numbered sections (MIN_SECTIONS; lowered 12→8 in v3, 2026-05-17)
#   5  FAIL_SLUG_COLLISION        — another AUTOVIBE-*-{slug}-MASTER.md exists in same dir
#   6  FAIL_DESTRUCTIVE_KEYWORD   — destructive ops detected (rm -rf, drop table, etc.)
#   7  FAIL_MISSING_BRANCH        — no "## N. Current Branch" section (added v2 per A8 — SSH-Execute dispatcher reads this to git checkout BEFORE Claude -p runs)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

CANONICAL_RE='^AUTOVIBE-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-[a-z0-9-]+-MASTER\.md$'
# Destructive-keyword regex — expanded per code-council 2026-05-08 finding 3+4 (escape force-push dot,
# add drop database/role/owned, git push --force variants, rm -fr flag transposition).
DESTRUCTIVE_RE='(rm[[:space:]]+-[rRfF]+|drop[[:space:]]+(table|schema|database|role|owned)|truncate[[:space:]]+table|delete[[:space:]]+from|force[-.]push|git[[:space:]]+push[[:space:]]+(-[a-zA-Z]*f|--force)|--no-verify|destroy[[:space:]]+production)'
# v2 / A8: MASTER must include "## N. Current Branch" so the SSH-Execute dispatcher can
# git-checkout the right branch BEFORE invoking Claude -p. Without this, autofired sessions
# may land on stale main and "fix" the wrong tree.
#
# v4 / 2026-05-19 (locale fix): both numbered-header regexes must tolerate an optional
# section-sign prefix ("## §8." as well as "## 13.") AND run correctly under BSD grep
# in the C locale — the locale the autofire hooks' non-interactive shells default to.
# The v3 fix embedded a raw multibyte "§" (UTF-8 bytes c2 a7) as "§?"; BSD grep in the
# C locale parses that byte-wise, so "§?" meant "byte c2 required, byte a7 optional" —
# every plain "## 1." header failed to match → 0 sections counted → exit 4 → autofire
# silently skipped on every repo. The byte-safe replacement "[^0-9 ]{0,2}" (zero to two
# non-digit, non-space bytes) consumes the 2-byte § OR nothing, with no multibyte
# literal in the pattern — identical behaviour under the C and UTF-8 locales.
CURRENT_BRANCH_RE='^## [^0-9 ]{0,2}[0-9]+\.[[:space:]]+Current[[:space:]]+Branch[[:space:]]*$'
MIN_SIZE=500
# v3 / 2026-05-17 (Gate B fix): lowered 12 → 8. Real continuations observed in
# continuations/ run 8-15 numbered sections (hand-authored 8, skill-generated 11-15).
# The 12 floor rejected the 0820 predecessor (11 sections) and every hand-authored file,
# so Phase 4.8 autofire could never find a verifier-passing continuation. 8 is the
# observed floor of genuine continuations; junk stubs (<500B or 0-3 sections) still fail.
MIN_SECTIONS=8

# ─── self-test mode ──────────────────────────────────────────

if [ "${1:-}" = "--self-test" ]; then
  # The autofire hooks run this verifier in non-interactive shells that default to the
  # C locale. Pin LC_ALL=C so the self-test reproduces that environment exactly — an
  # ambient UTF-8 locale otherwise masks C-locale-only regex bugs (see the v4 note).
  export LC_ALL=C
  TMPDIR_ST="$(mktemp -d)"
  cleanup() { rm -rf "$TMPDIR_ST"; }
  trap cleanup EXIT

  pass_count=0
  fail_count=0
  echo "verify-continuation self-test"
  echo "==============================="

  # Build a 12-section body that exceeds 500 bytes, INCLUDING a "Current Branch" section (per A8).
  # Section 7 carries the branch header; the rest are filler.
  _good_body() {
    printf '# Test continuation\n\n'
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
      if [ "$i" = "7" ]; then
        printf '## %s. Current Branch\n\nfeat/test-branch-name\n\nFiller paragraph one. Filler paragraph two.\n\n' "$i"
      else
        printf '## %s. Section %s\n\nFiller content paragraph one. Filler content paragraph two. Filler content paragraph three.\n\n' "$i" "$i"
      fi
    done
  }

  # Build a 12-section body WITHOUT a Current Branch section (for T9 negative test).
  _missing_branch_body() {
    printf '# Test continuation\n\n'
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
      printf '## %s. Section %s\n\nFiller content paragraph one. Filler content paragraph two. Filler content paragraph three.\n\n' "$i" "$i"
    done
  }

  _run() {
    # _run <expected_rc> <test_label> <args...>
    local expected="$1" label="$2"; shift 2
    bash "$SELF" "$@" >/dev/null 2>&1
    local rc=$?
    if [ "$rc" -eq "$expected" ] 2>/dev/null; then
      echo "  PASS  $label"
      pass_count=$((pass_count + 1))
    else
      echo "  FAIL  $label — expected exit $expected, got exit $rc"
      fail_count=$((fail_count + 1))
    fi
  }

  ts1="2026-05-08-1900"
  ts2="2026-05-08-1800"

  # T1: PASS on canonical 12-section file
  good="$TMPDIR_ST/AUTOVIBE-${ts1}-test-slug-MASTER.md"
  _good_body > "$good"
  _run 0 "T1 PASS on canonical 12-section file" "$good"

  # T2: exit 1 on missing file
  _run 1 "T2 exit 1 on missing file" "$TMPDIR_ST/does-not-exist.md"

  # T3: exit 2 on size < 500 bytes (canonical filename pattern but tiny body)
  small="$TMPDIR_ST/AUTOVIBE-${ts1}-tiny-MASTER.md"
  printf '## 1. x\n## 2. x\n## 3. x\n## 4. x\n## 5. x\n## 6. x\n## 7. x\n## 8. x\n## 9. x\n## 10. x\n## 11. x\n## 12. x\n' > "$small"
  _run 2 "T3 exit 2 on size < 500 bytes" "$small"

  # T4: exit 3 on filename pattern mismatch (size + sections OK)
  badname="$TMPDIR_ST/wrong-name-MASTER.md"
  _good_body > "$badname"
  _run 3 "T4 exit 3 on filename pattern mismatch" "$badname"

  # T5: exit 4 on < MIN_SECTIONS sections (size OK, filename OK)
  # v3 2026-05-17: MIN_SECTIONS lowered 12→8, so the fixture uses 5 sections (< 8) to still
  # trip FAIL_STRUCTURE. Previously used 10 sections expecting exit 4 under MIN=12.
  short="$TMPDIR_ST/AUTOVIBE-${ts1}-short-sections-MASTER.md"
  {
    printf '# Short test\n\n'
    for i in 1 2 3 4 5; do
      printf '## %s. Section %s\n\nFiller content paragraph one. Filler content paragraph two. Filler content paragraph three. Extra filler to clear the 500-byte size floor easily.\n\n' "$i" "$i"
    done
  } > "$short"
  _run 4 "T5 exit 4 on < ${MIN_SECTIONS} sections" "$short"

  # T6: exit 5 on slug collision (two AUTOVIBE-*-{slug}-MASTER.md in same dir)
  c1="$TMPDIR_ST/AUTOVIBE-${ts1}-collide-slug-MASTER.md"
  c2="$TMPDIR_ST/AUTOVIBE-${ts2}-collide-slug-MASTER.md"
  _good_body > "$c1"
  _good_body > "$c2"
  _run 5 "T6 exit 5 on slug collision" "$c1"

  # T7: exit 6 on destructive keyword in body
  destruct="$TMPDIR_ST/AUTOVIBE-${ts1}-destruct-MASTER.md"
  _good_body > "$destruct"
  printf '\n\nrm -rf /important/path\n' >> "$destruct"
  _run 6 "T7 exit 6 on destructive keyword (rm -rf)" "$destruct"

  # T8: exit 6 on different destructive keyword (drop table)
  destruct2="$TMPDIR_ST/AUTOVIBE-${ts1}-droptable-MASTER.md"
  _good_body > "$destruct2"
  printf '\n\nDROP TABLE production_users CASCADE;\n' >> "$destruct2"
  _run 6 "T8 exit 6 on destructive keyword (drop table)" "$destruct2"

  # T9 (NEW v2 per A8): exit 7 on missing "## N. Current Branch" section
  no_branch="$TMPDIR_ST/AUTOVIBE-${ts1}-no-branch-MASTER.md"
  _missing_branch_body > "$no_branch"
  _run 7 "T9 exit 7 on missing Current Branch section" "$no_branch"

  # T10 (NEW v2 per A2): sha256 emitted on PASS output (stdout, not stderr)
  sha_test="$TMPDIR_ST/AUTOVIBE-${ts1}-sha-emit-MASTER.md"
  _good_body > "$sha_test"
  STDOUT=$(bash "$SELF" "$sha_test" 2>/dev/null)
  RC=$?
  EXPECTED_SHA=$(shasum -a 256 "$sha_test" 2>/dev/null | awk '{print $1}')
  if [ "$RC" -eq 0 ] && printf '%s' "$STDOUT" | grep -q "sha256=${EXPECTED_SHA}"; then
    echo "  PASS  T10 sha256 emitted on PASS line"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL  T10 — rc=$RC; stdout was: $STDOUT"
    fail_count=$((fail_count + 1))
  fi

  # T11 (v4 locale fix): a "## §N. Current Branch" header (section-sign prefix) must
  # PASS under the C locale — v3's §? regex counted it (and every plain header) as 0.
  sect_branch="$TMPDIR_ST/AUTOVIBE-${ts1}-section-sign-MASTER.md"
  {
    printf '# Test continuation\n\n'
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
      if [ "$i" = "8" ]; then
        printf '## §%s. Current Branch\n\nfeat/test-branch-name\n\nFiller paragraph one. Filler paragraph two.\n\n' "$i"
      else
        printf '## %s. Section %s\n\nFiller content paragraph one. Filler content paragraph two. Filler content paragraph three.\n\n' "$i" "$i"
      fi
    done
  } > "$sect_branch"
  _run 0 "T11 PASS on §-prefixed Current Branch header (C-locale byte-safe)" "$sect_branch"

  echo "==============================="
  total=$((pass_count + fail_count))
  if [ "$fail_count" -eq 0 ] 2>/dev/null; then
    echo "verify-continuation self-test: ALL PASS ($pass_count/$total)"
    exit 0
  else
    echo "verify-continuation self-test: FAILED — $fail_count of $total tests"
    exit 1
  fi
fi

# ─── main ────────────────────────────────────────────────────

FILE="${1:-}"
if [ -z "$FILE" ]; then
  echo "[FAIL] usage: verify-continuation.sh <path-to-MASTER.md>" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "[FAIL] missing: $FILE" >&2
  exit 1
fi

# Check 1: size >= MIN_SIZE bytes
SIZE=$(wc -c < "$FILE" 2>/dev/null | tr -d ' ')
SIZE=$(printf '%s' "${SIZE:-0}" | tr -dc '0-9' | head -c 12)
SIZE=${SIZE:-0}
if [ "$SIZE" -lt "$MIN_SIZE" ] 2>/dev/null; then
  echo "[FAIL] size $SIZE < ${MIN_SIZE} bytes (junk threshold)" >&2
  exit 2
fi

# Check 2: canonical filename pattern (basename only — path-agnostic)
BASE=$(basename "$FILE")
if ! printf '%s' "$BASE" | grep -qE "$CANONICAL_RE"; then
  echo "[FAIL] filename does not match AUTOVIBE-{YYYY-MM-DD-HHMM}-{slug}-MASTER.md: $BASE" >&2
  exit 3
fi

# Check 3: structural lint — count "## N." headers (N integer, optional § prefix;
# byte-safe pattern — see the v4 locale-fix note next to CURRENT_BRANCH_RE).
SECTIONS=$(grep -cE '^## [^0-9 ]{0,2}[0-9]+\. ' "$FILE" 2>/dev/null || true)
SECTIONS=$(printf '%s' "${SECTIONS:-0}" | tr -dc '0-9' | head -c 4)
SECTIONS=${SECTIONS:-0}
if [ "$SECTIONS" -lt "$MIN_SECTIONS" ] 2>/dev/null; then
  echo "[FAIL] structural lint: $SECTIONS sections found, need >= ${MIN_SECTIONS}" >&2
  exit 4
fi

# Check 4: slug uniqueness in same directory
# Code-council 2026-05-08 finding 1: glob `AUTOVIBE-*-${SLUG}-MASTER.md` over-matches because `*`
# can include `-` (e.g., slug "bar" matches "AUTOVIBE-X-foo-bar-MASTER.md"). Anchor via regex
# match on the canonical timestamp segment to scope `*` to JUST the {YYYY-MM-DD-HHMM} field.
SLUG=$(printf '%s' "$BASE" | sed -E 's/^AUTOVIBE-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-(.+)-MASTER\.md$/\1/')
DIR=$(dirname "$FILE")
COLLISIONS=$(find "$DIR" -maxdepth 1 -type f -name 'AUTOVIBE-*-MASTER.md' 2>/dev/null \
  | while IFS= read -r f; do basename "$f"; done \
  | grep -cE "^AUTOVIBE-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-${SLUG}-MASTER\.md$" 2>/dev/null || true)
COLLISIONS=$(printf '%s' "${COLLISIONS:-0}" | tr -dc '0-9' | head -c 4)
COLLISIONS=${COLLISIONS:-0}
if [ "$COLLISIONS" -gt 1 ] 2>/dev/null; then
  echo "[FAIL] slug collision: $COLLISIONS files match AUTOVIBE-*-${SLUG}-MASTER.md in $DIR" >&2
  exit 5
fi

# Check 5: destructive-keyword scan (Reliability Engineer veto layer)
if grep -qiE "$DESTRUCTIVE_RE" "$FILE" 2>/dev/null; then
  HIT=$(grep -iE -m1 "$DESTRUCTIVE_RE" "$FILE" 2>/dev/null | head -c 80)
  echo "[FAIL] destructive keyword detected — refusing autofire (hit: ${HIT}...)" >&2
  exit 6
fi

# Check 6 (v2 / A8): Current Branch section MUST be present — dispatcher git-checkouts before claude -p
if ! grep -qE "$CURRENT_BRANCH_RE" "$FILE" 2>/dev/null; then
  echo "[FAIL] missing '## N. Current Branch' section — SSH-Execute dispatcher needs branch to checkout" >&2
  exit 7
fi

# v2 / A2: emit sha256 on PASS so Phase 4.8 captures-at-verify and re-checks at dispatch (TOCTOU guard)
SHA256=$(shasum -a 256 "$FILE" 2>/dev/null | awk '{print $1}')
echo "[PASS] $BASE: size=${SIZE}B sections=${SECTIONS} slug=${SLUG} sha256=${SHA256}"
exit 0
