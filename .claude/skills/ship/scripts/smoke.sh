#!/usr/bin/env bash
# smoke.sh — post-deploy production smoke with retry+backoff + Vercel auth
# pre-check + bundle-content escalation. Addresses council 2026-04-19 FLAGS 1 + D2
# AND 2026-04-25 user feedback that "unverifiable → exit 9" silently passed when
# the sha header was filtered by Vercel.
#
#   - Vercel cold-start 5–30s warmup → retry 3× w/ 10s backoff before rollback fires
#   - Vercel auth 401 vs real 502 → pre-check with `vercel whoami`; missing
#     x-vercel-git-commit-sha header escalates to bundle-content verify when a
#     --bundle-marker is provided (caller-supplied substring that proves the new
#     code is in the deployed bundle).
#
# Usage: smoke.sh <expected_sha> [--url <url>] [--path <path>]... [--min-wait <sec>]
#                                [--bundle-marker <substring>]
#
# When --bundle-marker is provided AND the sha header is absent, the script
# fetches the entry HTML, parses out /assets/*.js URLs, and curls each one
# looking for the marker substring. A match → smoke passes (verified via
# bundle content); no match in any bundle → exit 9 (real unverifiable, halt).
#
# Exit codes:
#   0 — all paths 200 AND (sha header matches OR bundle-marker found in deployed JS)
#   1 — real failure (non-200 after retries AND auth OK AND sha header present & mismatched)
#   2 — pre-check failed (Vercel auth expired, cannot verify)
#   9 — unverifiable (no sha header AND no bundle-marker provided OR marker not found
#                     in any deployed bundle) — caller decides: halt, don't rollback

set -uo pipefail

expected_sha="${1:-}"
if [ -z "$expected_sha" ]; then
  echo "smoke: expected_sha required (usage: smoke.sh <sha> [--url ...] [--path ...])" >&2
  exit 2
fi
shift

# Defaults
url=""
paths=()
min_wait=10
retries=3
backoff=10
bundle_marker=""

while [ $# -gt 0 ]; do
  case "$1" in
    --url) url="$2"; shift 2 ;;
    --path) paths+=("$2"); shift 2 ;;
    --min-wait) min_wait="$2"; shift 2 ;;
    --retries) retries="$2"; shift 2 ;;
    --backoff) backoff="$2"; shift 2 ;;
    --bundle-marker) bundle_marker="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Default paths if none specified
if [ ${#paths[@]} -eq 0 ]; then
  paths=("/")
fi

# --- Vercel auth pre-check (FLAG 1) ---
if command -v vercel >/dev/null 2>&1; then
  if ! vercel whoami >/dev/null 2>&1; then
    echo "smoke: Vercel auth expired or missing; cannot distinguish 401 from 502" >&2
    echo "  Recovery: vercel login" >&2
    exit 2
  fi
else
  echo "smoke: vercel CLI not found; proceeding without auth pre-check" >&2
fi

# --- Resolve production URL ---
if [ -z "$url" ]; then
  if command -v vercel >/dev/null 2>&1; then
    # Latest production deployment
    url=$(vercel ls --prod --scope teamnewearthaias-projects 2>/dev/null | awk '/https:/ {print $2; exit}' || true)
  fi
  if [ -z "$url" ]; then
    echo "smoke: no URL provided and could not resolve via vercel CLI" >&2
    exit 2
  fi
fi

# Strip trailing slash
url="${url%/}"

# --- Minimum wait for Vercel cold-start propagation ---
if [ "$min_wait" -gt 0 ]; then
  echo "smoke: waiting ${min_wait}s for Vercel deployment propagation..." >&2
  sleep "$min_wait"
fi

# --- Per-path check with retry+backoff ---
any_fail=0
any_unverifiable=0

for path in "${paths[@]}"; do
  target="${url}${path}"
  attempt=1
  success=0
  last_status="?"
  last_sha="?"
  while [ "$attempt" -le "$retries" ]; do
    # Single curl: capture status + x-vercel-git-commit-sha header
    resp=$(curl -sS -o /dev/null -w '%{http_code}|%{header_json}' --max-time 30 "$target" 2>/dev/null || echo "000|{}")
    status="${resp%%|*}"
    headers="${resp#*|}"
    # Extract sha header (case-insensitive; macOS jq has ascii_downcase)
    sha_hdr=$(printf '%s' "$headers" | jq -r '(keys_unsorted | map(ascii_downcase)) as $k | [.[]] as $v | $k | index("x-vercel-git-commit-sha") as $i | if $i then $v[$i][0] else "" end' 2>/dev/null || echo "")
    last_status="$status"
    last_sha="$sha_hdr"

    if [ "$status" = "200" ]; then
      if [ -z "$sha_hdr" ]; then
        # Escalation: when sha header absent AND a bundle-marker was provided,
        # try to verify by fetching the deployed JS bundles and confirming the
        # marker substring is present. This catches the "Vercel filtered the
        # header but the deploy DID complete" silent-pass class (2026-04-25).
        if [ -n "$bundle_marker" ]; then
          html=$(curl -sS --max-time 30 "$target" 2>/dev/null || echo "")
          # Extract /assets/<file>.js URLs (handles relative + absolute)
          asset_urls=$(printf '%s' "$html" | grep -oE '"[^"]*assets/[^"]*\.js"' | tr -d '"' | sort -u)
          marker_found=0
          for asset in $asset_urls; do
            # Resolve relative URLs against the target base
            case "$asset" in
              http*) full_asset="$asset" ;;
              /*) full_asset="${url}${asset}" ;;
              *) full_asset="${url}/${asset}" ;;
            esac
            if curl -sS --max-time 30 "$full_asset" 2>/dev/null | grep -qF "$bundle_marker"; then
              marker_found=1
              echo "smoke: ${path} -> 200 sha-header absent BUT bundle-marker '${bundle_marker}' found in ${asset} (verified via content)" >&2
              break
            fi
          done
          if [ "$marker_found" = "1" ]; then
            success=1
            break
          else
            echo "smoke: ${path} -> 200 sha-header absent AND bundle-marker '${bundle_marker}' NOT found in any deployed JS (UNVERIFIABLE)" >&2
            any_unverifiable=1
            success=1
            break
          fi
        fi
        echo "smoke: ${path} -> 200 but NO x-vercel-git-commit-sha header AND no --bundle-marker provided (UNVERIFIABLE)" >&2
        any_unverifiable=1
        success=1
        break
      elif [ "$sha_hdr" = "$expected_sha" ] || [ "${sha_hdr:0:8}" = "${expected_sha:0:8}" ]; then
        echo "smoke: ${path} -> 200 sha=${sha_hdr:0:8} ✓" >&2
        success=1
        break
      else
        echo "smoke: ${path} -> 200 but sha=${sha_hdr:0:8} != expected=${expected_sha:0:8} (likely CDN propagation lag)" >&2
        # Treat sha mismatch as retryable
      fi
    else
      echo "smoke: ${path} -> ${status} (attempt $attempt/$retries)" >&2
    fi

    attempt=$((attempt + 1))
    [ "$attempt" -le "$retries" ] && sleep "$backoff"
  done

  if [ "$success" = "0" ]; then
    echo "smoke: ${path} FAILED after $retries attempts (last: status=$last_status sha=${last_sha:0:8})" >&2
    any_fail=1
  fi
done

if [ "$any_fail" = "1" ]; then exit 1; fi
if [ "$any_unverifiable" = "1" ]; then exit 9; fi
exit 0
