#!/usr/bin/env bash
# =============================================================================
# safe-bash task: n8n_verify_workflow_updated
# Verify workflow hash matches expected hash, with bounded retries + backoff
# Usage: ./n8n_verify_workflow.sh <workflow_id> <expected_sha256> [max_retries]
# Requires: N8N_BASE_URL, N8N_API_KEY env vars
# =============================================================================
set -euo pipefail

WORKFLOW_ID="${1:?Usage: $0 <workflow_id> <expected_sha256> [max_retries]}"
EXPECTED_HASH="${2:?Usage: $0 <workflow_id> <expected_sha256> [max_retries]}"
MAX_RETRIES="${3:-3}"
BACKOFF_BASE="${SAFE_BASH_BACKOFF_MS:-1000}"
AUDIT_LOG="${SAFE_BASH_AUDIT_LOG:-.claude/safe-bash-audit.jsonl}"

# --- Env validation ---
if [ -z "${N8N_BASE_URL:-}" ]; then
  echo "ERROR: N8N_BASE_URL not set" >&2
  exit 1
fi
if [ -z "${N8N_API_KEY:-}" ]; then
  echo "ERROR: N8N_API_KEY not set" >&2
  exit 1
fi

# --- Arg validation ---
if [[ "$WORKFLOW_ID" =~ [\`\$\|\;\>\<\&\(\)\{\}] ]]; then
  echo "ERROR: Invalid characters in workflow_id" >&2
  exit 2
fi
if [[ ! "$EXPECTED_HASH" =~ ^[a-f0-9]{64}$ ]]; then
  echo "ERROR: Invalid sha256 hash format" >&2
  exit 2
fi

# --- Bounded retry loop ---
START_MS=$(($(date +%s) * 1000))
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

ATTEMPT=0
MATCHED=false

while [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; do
  ATTEMPT=$((ATTEMPT + 1))

  HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
    "${N8N_BASE_URL}/workflows/${WORKFLOW_ID}" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "Attempt ${ATTEMPT}/${MAX_RETRIES}: HTTP ${HTTP_CODE}" >&2
  else
    ACTUAL_HASH=$(jq -S '.' "$TMPFILE" | sha256sum | cut -d' ' -f1)
    if [ "$ACTUAL_HASH" = "$EXPECTED_HASH" ]; then
      MATCHED=true
      break
    else
      echo "Attempt ${ATTEMPT}/${MAX_RETRIES}: Hash mismatch" >&2
      echo "  Expected: ${EXPECTED_HASH}" >&2
      echo "  Actual:   ${ACTUAL_HASH}" >&2
    fi
  fi

  if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
    # Exponential backoff: base * 2^(attempt-1)
    SLEEP_MS=$((BACKOFF_BASE * (1 << (ATTEMPT - 1))))
    SLEEP_SEC=$(echo "scale=1; $SLEEP_MS / 1000" | bc)
    echo "Retrying in ${SLEEP_SEC}s..." >&2
    sleep "$SLEEP_SEC"
  fi
done

END_MS=$(($(date +%s) * 1000))
DURATION=$((END_MS - START_MS))

# --- Audit log ---
if [ "$MATCHED" = true ]; then
  EXIT_CODE=0
  echo "VERIFIED: Workflow ${WORKFLOW_ID} matches expected hash after ${ATTEMPT} attempt(s)"
else
  EXIT_CODE=4
  echo "FAILED: Workflow ${WORKFLOW_ID} hash mismatch after ${MAX_RETRIES} attempts" >&2
fi

mkdir -p "$(dirname "$AUDIT_LOG")"
cat >> "$AUDIT_LOG" <<AUDIT_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","task":"n8n_verify_workflow_updated","args":["${WORKFLOW_ID}","${EXPECTED_HASH}","${MAX_RETRIES}"],"cwd":"$(pwd)","env_keys":["N8N_BASE_URL","N8N_API_KEY"],"exit_code":${EXIT_CODE},"attempts":${ATTEMPT},"matched":${MATCHED},"duration_ms":${DURATION}}
AUDIT_EOF

exit $EXIT_CODE
