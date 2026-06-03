#!/usr/bin/env bash
# =============================================================================
# safe-bash task: n8n_import_workflow
# Import workflow JSON to n8n via REST PUT
# Usage: ./n8n_import_workflow.sh <workflow_id> <json_file>
# Requires: N8N_BASE_URL, N8N_API_KEY env vars
# =============================================================================
set -euo pipefail

WORKFLOW_ID="${1:?Usage: $0 <workflow_id> <json_file>}"
JSON_FILE="${2:?Usage: $0 <workflow_id> <json_file>}"
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
if [ ! -f "$JSON_FILE" ]; then
  echo "ERROR: File not found: $JSON_FILE" >&2
  exit 2
fi

# --- Compute pre-import hash ---
PRE_HASH=$(jq -S '.' "$JSON_FILE" | sha256sum | cut -d' ' -f1)

# --- Import via PUT ---
START_MS=$(($(date +%s) * 1000))
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

HTTP_CODE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  -X PUT \
  "${N8N_BASE_URL}/workflows/${WORKFLOW_ID}" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @"$JSON_FILE")

END_MS=$(($(date +%s) * 1000))
DURATION=$((END_MS - START_MS))

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: n8n API returned HTTP $HTTP_CODE" >&2
  cat "$TMPFILE" >&2
  # Audit failure
  mkdir -p "$(dirname "$AUDIT_LOG")"
  cat >> "$AUDIT_LOG" <<AUDIT_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","task":"n8n_import_workflow","args":["${WORKFLOW_ID}","${JSON_FILE}"],"cwd":"$(pwd)","env_keys":["N8N_BASE_URL","N8N_API_KEY"],"exit_code":3,"duration_ms":${DURATION}}
AUDIT_EOF
  exit 3
fi

# --- Audit log ---
mkdir -p "$(dirname "$AUDIT_LOG")"
cat >> "$AUDIT_LOG" <<AUDIT_EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","task":"n8n_import_workflow","args":["${WORKFLOW_ID}","${JSON_FILE}"],"cwd":"$(pwd)","env_keys":["N8N_BASE_URL","N8N_API_KEY"],"exit_code":0,"pre_hash":"${PRE_HASH}","duration_ms":${DURATION}}
AUDIT_EOF

echo "Imported: ${JSON_FILE} → workflow ${WORKFLOW_ID}"
echo "Pre-import SHA256: ${PRE_HASH}"
echo "HTTP: ${HTTP_CODE}"
