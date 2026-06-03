#!/usr/bin/env bash
# verify-writeback-symmetry.sh — proves every daily-plan-class skill in the
# project carries an IDENTICAL, NON-FORKED, canonical Roadmap Write-Back phase.
#
# A silent asymmetry between sibling daily-plan skills (one ticks the roadmap,
# the other does not) is a known done-but-untracked defect class. A one-time
# diff is insufficient — the asymmetry can silently re-open on any future edit.
# This check is re-runnable and is a REQUIRED-ARTEFACT gate in the shipping PR
# (and good as a CI step).
#
# Project-shape aware: discovers whichever daily-plan skills exist.
#   - 0 found  → harness error (exit 2): nothing to verify, misconfigured.
#   - 1 found  → still meaningful: verifies delegation + non-fork.
#   - 2+ found → additionally proves mutual symmetry (identical heading,
#                all delegate to the one canonical spec, none forked).
#
# Exit 0 = symmetric/valid. Exit 1 = asymmetry/fork. Exit 2 = harness error.
#
# Shell-portability: no pipe-eats-$?, numerics normalized before [, locals
# namespaced away from `status`, no GNU-only tools.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || { echo "verify-writeback-symmetry: cannot cd to repo root" >&2; exit 2; }

CANON=".claude/skills/_shared/roadmap-writeback-phase.md"
PHASE_HEADING='## Phase: Roadmap Write-Back'

fail=0
note() { echo "  - $1"; }
echo "verify-writeback-symmetry — $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Gate 0 — canonical deep module must exist.
if [ ! -f "$CANON" ]; then
  echo "HARNESS ERROR: canonical phase spec missing: $CANON" >&2
  echo "  Every daily-plan skill delegates here; without it nothing is symmetric." >&2
  exit 2
fi

# Discover daily-plan-class skills (always daily-plan-generator; optionally a
# second business/ops sibling). Match any .claude/skills/daily-*plan*/SKILL.md.
skills=()
for d in .claude/skills/daily-*plan*/ .claude/skills/*daily-plan*/; do
  [ -f "${d}SKILL.md" ] && skills+=("${d}SKILL.md")
done
# de-dup
if [ "${#skills[@]}" -gt 0 ]; then
  skills=($(printf '%s\n' "${skills[@]}" | sort -u))
fi
n=${#skills[@]}

if [ "$n" -eq 0 ]; then
  echo "HARNESS ERROR: no daily-plan-class skill found under .claude/skills/daily-*plan*/" >&2
  echo "  Expected at least .claude/skills/daily-plan-generator/SKILL.md" >&2
  exit 2
fi
echo "[info] daily-plan skills discovered: $n"
printf '       • %s\n' "${skills[@]}"

# Gate 1 — every discovered skill carries the EXACT canonical heading.
for f in "${skills[@]}"; do
  c=$(grep -cF "$PHASE_HEADING" "$f" 2>/dev/null); c=$(printf '%s' "${c:-0}" | tr -dc '0-9'); c=${c:-0}
  if [ "$c" -lt 1 ]; then fail=1; note "$f is MISSING the heading: '$PHASE_HEADING'"; fi
done
[ "$fail" -eq 0 ] && echo "[ok] all $n skill(s) carry the canonical phase heading"

# Gate 2 — every discovered skill references the canonical spec BY PATH.
for f in "${skills[@]}"; do
  c=$(grep -cF "$CANON" "$f" 2>/dev/null); c=$(printf '%s' "${c:-0}" | tr -dc '0-9'); c=${c:-0}
  if [ "$c" -lt 1 ]; then fail=1; note "$f does NOT reference the canonical spec ($CANON) — forked or dropped the delegation"; fi
done
[ "$fail" -eq 0 ] && echo "[ok] all $n skill(s) delegate to the canonical spec by path"

# Gate 3 — no skill INLINES forked W-step logic. The canonical spec owns
# step ids W0..W6 under headings of the form "## Step W1 — Acquire ...". A
# skill that only delegates has ZERO "## Step W<n>" headings of its own; any
# such heading = an inlined fork. Matches #/##/### + " Step W" + digit.
# (The prior keyword-list regex never matched "Step W1 — Acquire" — it under-
# detected forks; fixed 2026-05-17 per code-council.)
for f in "${skills[@]}"; do
  w=$(grep -cE '^#+[[:space:]]+Step[[:space:]]+W[0-6]' "$f" 2>/dev/null)
  w=$(printf '%s' "${w:-0}" | tr -dc '0-9'); w=${w:-0}
  if [ "$w" -gt 0 ]; then fail=1; note "$f appears to INLINE forked W-step logic ($w match(es)) — W0..W6 must live ONLY in $CANON"; fi
done
[ "$fail" -eq 0 ] && echo "[ok] no forked W-step logic inlined in any skill"

# Gate 4 — canonical spec still owns the contract (regression guard).
canon_missing=""
for anchor in "Step W1" "Step W2" "Step W3" "Step W4" "Step W5" "Step W0" "Step W6"; do
  grep -qF "$anchor" "$CANON" 2>/dev/null || canon_missing="$canon_missing $anchor"
done
if [ -n "$canon_missing" ]; then
  fail=1; note "canonical spec $CANON missing W-step anchors:$canon_missing — deep module gutted"
else
  echo "[ok] canonical spec retains the full W0..W6 contract"
fi

echo "---"
if [ "$fail" -eq 0 ]; then
  if [ "$n" -ge 2 ]; then
    echo "PASS — all $n daily-plan skills carry a symmetric, non-forked, canonical Roadmap Write-Back phase."
  else
    echo "PASS — the single daily-plan skill delegates correctly to the canonical phase (no sibling to be asymmetric with)."
  fi
  exit 0
fi
echo "FAIL — write-back symmetry is BROKEN. The done-but-untracked asymmetry class is reopened."
echo "Fix: ensure EVERY daily-plan skill contains exactly '$PHASE_HEADING' delegating to $CANON, with NO inlined W-step copy."
echo "This is a required-artefact BLOCK for the shipping PR."
exit 1
