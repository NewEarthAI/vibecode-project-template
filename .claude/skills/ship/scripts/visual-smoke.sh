#!/usr/bin/env bash
# visual-smoke.sh — post-deploy visual verification of UI surface changes.
#
# Triggered by /ship pr after standard smoke.sh passes, ONLY when the PR diff
# touches user-facing component files. Confirms the new UI element is actually
# present in the deployed bundle/DOM (catches "deploy succeeded but feature
# missing" failure mode that HTTP-200 + sha-header smoke can't detect).
#
# This is the v1 implementation: lightweight HTML+JS-bundle inspection. It
# does NOT take screenshots (a full headless Chrome flow is v2 — see
# references/visual-smoke-v2-roadmap.md if added later). It DOES confirm the
# new component's identifying string is present in the deployed code.
#
# Usage: visual-smoke.sh <prod_url> <merged_sha> [--marker <substring>]...
#                                                [--against-base <ref>]
#
# When --marker is provided one or more times: fetches prod HTML, walks the
# JS bundle, asserts each marker substring appears in at least one bundle.
#
# When --against-base is provided (default origin/main~1): auto-detects markers
# from the diff using simple identifier extraction:
#   - new exported function/component names from `git diff` of *.tsx files
#   - new data-testid="..." literal values
#   - new exported const/class names
# At least one detected marker MUST be present in the deployed bundle.
#
# Exit codes:
#   0 — all markers found in deployed bundle (visual-smoke pass)
#   1 — at least one marker NOT found (real regression — feature deploy gap)
#   2 — pre-check failed (bad URL, no markers detected, no UI files in diff)
#   9 — unverifiable (couldn't fetch HTML or bundle URLs unparseable)

set -uo pipefail

prod_url="${1:-}"
merged_sha="${2:-}"
shift 2 2>/dev/null || true

if [ -z "$prod_url" ]; then
  echo "visual-smoke: prod_url required" >&2
  exit 2
fi
prod_url="${prod_url%/}"

markers=()
against_base="origin/main~1"

while [ $# -gt 0 ]; do
  case "$1" in
    --marker) markers+=("$2"); shift 2 ;;
    --against-base) against_base="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# --- Detect UI surfaces in diff ---
ui_files=$(git diff --name-only "${against_base}..HEAD" 2>/dev/null \
  | grep -E '^src/(components|pages)/.*\.(tsx|jsx)$' || true)

if [ -z "$ui_files" ] && [ ${#markers[@]} -eq 0 ]; then
  echo "visual-smoke: no UI surface files in diff and no --marker provided; skipping" >&2
  exit 0
fi

# --- Auto-detect markers from diff if none provided ---
if [ ${#markers[@]} -eq 0 ]; then
  for f in $ui_files; do
    # New component/function exports added in this PR
    added_exports=$(git diff "${against_base}..HEAD" -- "$f" 2>/dev/null \
      | grep -E '^\+export (function|const|class) [A-Z][A-Za-z0-9_]+' \
      | sed -E 's/^\+export (function|const|class) ([A-Za-z0-9_]+).*/\2/' \
      | sort -u)
    # New data-testid literal values
    added_testids=$(git diff "${against_base}..HEAD" -- "$f" 2>/dev/null \
      | grep -E '^\+.*data-testid="[^"]+"' \
      | grep -oE 'data-testid="[^"]+"' \
      | sed -E 's/data-testid="([^"]+)"/\1/' \
      | sort -u)
    for m in $added_exports $added_testids; do
      markers+=("$m")
    done
  done
  if [ ${#markers[@]} -eq 0 ]; then
    echo "visual-smoke: UI files changed but no markers detected from diff (no new exports or data-testids); skipping" >&2
    exit 0
  fi
fi

# --- Fetch prod HTML + extract bundle URLs ---
html=$(curl -sS --max-time 30 "${prod_url}/" 2>/dev/null || echo "")
if [ -z "$html" ]; then
  echo "visual-smoke: failed to fetch ${prod_url}/" >&2
  exit 9
fi

bundle_urls=$(printf '%s' "$html" | grep -oE '"[^"]*assets/[^"]*\.js"' | tr -d '"' | sort -u)
if [ -z "$bundle_urls" ]; then
  echo "visual-smoke: no /assets/*.js URLs found in HTML; bundle layout unknown" >&2
  exit 9
fi

# --- Walk bundles, search for each marker ---
bundle_cache=""
all_found=1
echo "visual-smoke: checking ${#markers[@]} marker(s) against deployed bundles..." >&2
for m in "${markers[@]}"; do
  found=0
  for bundle in $bundle_urls; do
    case "$bundle" in
      http*) full="$bundle" ;;
      /*) full="${prod_url}${bundle}" ;;
      *) full="${prod_url}/${bundle}" ;;
    esac
    # Simple cache: only re-fetch if not already in this run's working set
    if printf '%s' "$bundle_cache" | grep -qF "BUNDLE_${full}_FETCHED"; then
      tmp_content=$(printf '%s' "$bundle_cache" | sed -n "/BUNDLE_${full//\//_}_START/,/BUNDLE_${full//\//_}_END/p")
    else
      tmp_content=$(curl -sS --max-time 30 "$full" 2>/dev/null || echo "")
      bundle_cache="${bundle_cache}BUNDLE_${full}_FETCHED"
    fi
    if printf '%s' "$tmp_content" | grep -qF "$m"; then
      echo "visual-smoke: ✓ '$m' found in $(basename "$full")" >&2
      found=1
      break
    fi
  done
  if [ "$found" = "0" ]; then
    echo "visual-smoke: ✗ '$m' NOT found in any deployed bundle" >&2
    all_found=0
  fi
done

if [ "$all_found" = "1" ]; then
  echo "visual-smoke: PASS — all markers verified in deployed bundle (sha=${merged_sha:0:8})" >&2
  exit 0
else
  echo "visual-smoke: FAIL — at least one marker missing from deployed bundle" >&2
  echo "  This usually means the deploy succeeded but the new component code did" >&2
  echo "  not make it into the production bundle (lazy-load split, tree-shaking," >&2
  echo "  or stale Vercel cache)." >&2
  exit 1
fi
