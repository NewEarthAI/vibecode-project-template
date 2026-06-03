#!/usr/bin/env bash
# negative-control.sh — proves a NEW e2e spec actually catches the regression
# it claims to test. Runs the spec twice: once green, once with the feature
# under test broken. If both pass, the spec is vacuous and BLOCKS merge.
#
# Background: a new e2e test passing green proves nothing about whether it
# catches future regressions. This is the "Bug 4 negative-control" pattern
# proven in PR #188 (2026-04-21) — without it, tests can ship green and look
# authoritative while testing nothing.
#
# Usage: negative-control.sh <spec_file> [--feature-file <path>] [--marker <substring>]
#                                        [--base-url <url>]
#
# When --feature-file is omitted, the script attempts to auto-detect by:
#   1. Reading the spec's `import` statements for any from src/components or src/pages
#   2. Reading data-testid selectors used in the spec; grep'ing src/ for the
#      file that emits a matching `data-testid="..."` attribute
#
# The "break" is conservative: comment out one line of the feature file that
# emits a known marker (data-testid, exported component name, or distinctive
# string from the spec's assertions). Restored automatically after run.
#
# Exit codes:
#   0 — spec failed when feature broken AND passed when restored (proves catch)
#   1 — spec passed even with feature broken (VACUOUS — blocks merge)
#   2 — couldn't auto-detect feature file or marker (caller must pass --feature-file)
#   3 — Playwright/preview infrastructure error (not a spec verdict)

set -uo pipefail

spec_file="${1:-}"
if [ -z "$spec_file" ] || [ ! -f "$spec_file" ]; then
  echo "negative-control: spec_file required and must exist" >&2
  exit 2
fi
shift

feature_file=""
marker=""
base_url="${BASE_URL:-http://localhost:4173}"

while [ $# -gt 0 ]; do
  case "$1" in
    --feature-file) feature_file="$2"; shift 2 ;;
    --marker) marker="$2"; shift 2 ;;
    --base-url) base_url="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# --- Auto-detect feature file from spec's data-testid assertions ---
if [ -z "$feature_file" ]; then
  # Find data-testid strings the spec asserts on
  testids=$(grep -oE "data-testid=[\"'][^\"']+[\"']|getByTestId\([\"'][^\"']+[\"']" "$spec_file" \
    | sed -E 's/.*[\"'\'']([^\"'\'']+)[\"'\''].*/\1/' \
    | sort -u)
  if [ -z "$testids" ]; then
    # Try imported component names instead
    components=$(grep -E "^import \{ ?[A-Z]" "$spec_file" \
      | sed -E 's/.*\{ *([A-Za-z0-9_]+).*/\1/' \
      | sort -u)
    if [ -z "$components" ]; then
      echo "negative-control: cannot auto-detect feature file from spec (no data-testid or component imports found)" >&2
      echo "  retry with --feature-file <path> --marker <substring>" >&2
      exit 2
    fi
    # Find first source file emitting one of these component names
    for comp in $components; do
      hit=$(grep -rEl "(export (function|const|class) ${comp}\b|export default function ${comp}\b)" src/ 2>/dev/null | head -1)
      if [ -n "$hit" ]; then
        feature_file="$hit"
        marker="${marker:-$comp}"
        break
      fi
    done
  else
    # Find first source file with one of these data-testids
    for tid in $testids; do
      hit=$(grep -rEl "data-testid=[\"']${tid}[\"']" src/ 2>/dev/null | head -1)
      if [ -n "$hit" ]; then
        feature_file="$hit"
        marker="${marker:-$tid}"
        break
      fi
    done
  fi
fi

if [ -z "$feature_file" ] || [ ! -f "$feature_file" ]; then
  echo "negative-control: feature file not detected; pass --feature-file explicitly" >&2
  exit 2
fi
if [ -z "$marker" ]; then
  echo "negative-control: marker not specified or detected; pass --marker explicitly" >&2
  exit 2
fi

echo "negative-control: spec=${spec_file}" >&2
echo "negative-control: feature=${feature_file}" >&2
echo "negative-control: marker='${marker}'" >&2

# --- Step 1: snapshot the feature file ---
backup="${feature_file}.negctl-backup"
cp "$feature_file" "$backup"
trap "[ -f \"$backup\" ] && mv \"$backup\" \"$feature_file\"" INT TERM EXIT

# --- Step 2: run spec against unbroken feature (must pass) ---
echo "negative-control: phase 1 — spec against unbroken feature..." >&2
if ! BASE_URL="$base_url" npx playwright test "$spec_file" --project=chromium --reporter=line 2>&1 | tail -30; then
  echo "negative-control: spec FAILED on unbroken feature — fix the spec first" >&2
  exit 3
fi

# --- Step 3: break the feature by removing/commenting the marker line ---
echo "negative-control: phase 2 — breaking feature (commenting line containing marker)..." >&2
# Find the line emitting the marker and prefix with `// NEGCTL-BROKEN: `
broken=$(awk -v m="$marker" '
  !done && index($0, m) {
    print "// NEGCTL-BROKEN: " $0
    done = 1
    next
  }
  { print }
' "$feature_file")
if [ "$broken" = "$(cat "$feature_file")" ]; then
  echo "negative-control: marker '${marker}' not found in ${feature_file}; cannot break" >&2
  mv "$backup" "$feature_file"
  trap - INT TERM EXIT
  exit 2
fi
printf '%s' "$broken" > "$feature_file"

# Need to rebuild for the broken state to be served by preview. If preview is
# already running, this is a no-op for the running process — but Vite/preview
# serves dist/ which doesn't auto-rebuild. So we run npm run build silently.
echo "negative-control: rebuilding with broken feature..." >&2
if ! npm run build > /dev/null 2>&1; then
  echo "negative-control: build failed with broken feature (TypeScript may be enforcing the marker)" >&2
  mv "$backup" "$feature_file"
  trap - INT TERM EXIT
  exit 3
fi

# --- Step 4: run spec against broken feature (must FAIL to prove catch) ---
echo "negative-control: phase 3 — spec against broken feature (expecting FAIL)..." >&2
if BASE_URL="$base_url" npx playwright test "$spec_file" --project=chromium --reporter=line 2>&1 | tail -30; then
  echo "negative-control: ✗ VACUOUS SPEC — passed even with feature broken" >&2
  echo "  This spec does not catch the regression it claims to test." >&2
  echo "  Either the assertions are too weak, or they're not actually about the feature." >&2
  mv "$backup" "$feature_file"
  npm run build > /dev/null 2>&1 || true
  trap - INT TERM EXIT
  exit 1
else
  echo "negative-control: ✓ spec correctly FAILED when feature broken" >&2
fi

# --- Step 5: restore feature ---
echo "negative-control: phase 4 — restoring feature..." >&2
mv "$backup" "$feature_file"
npm run build > /dev/null 2>&1 || true
trap - INT TERM EXIT

echo "negative-control: PASS — spec proven to catch its claimed regression" >&2
exit 0
